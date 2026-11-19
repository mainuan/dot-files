#!/usr/bin/python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Atualiza o sha256 das entradas de identity/files/manifest.json e gera
identity/files/checksums.sha256 (todos os arquivos da pasta, manifesto
incluído). Com --check, só confere e falha se algo estiver desatualizado.

Também confere que cada recurso tem a mesma cópia instalada pelos outros
pacotes (rootfs/) e que o serviço libera escrita em todos os destinos."""

import hashlib
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
FILES = HERE / "files"
REPO = HERE.parent
# Recursos que os outros pacotes do dot-files instalam com o mesmo conteúdo.
SAME_AS = {
    "logo/mainuan-logo.png": ["rootfs/usr/share/plasma/avatars/logoMainuan.png",
                              "rootfs/usr/share/plasma/avatars/kubuntu-bug.png"],
    "icons/mainuan.svg": ["rootfs/usr/share/icons/hicolor/scalable/apps/mainuan.svg"],
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    check = "--check" in sys.argv[1:]
    errors = []
    manifest_path = FILES / "manifest.json"
    text = manifest_path.read_text(encoding="utf-8")
    manifest = json.loads(text)
    for entry in manifest["entries"]:
        entry["sha256"] = sha(FILES / entry["source"])
    new_text = json.dumps(manifest, indent=2, ensure_ascii=False) + "\n"
    if new_text != text:
        errors.append("manifest.json desatualizado")
        if not check:
            manifest_path.write_text(new_text, encoding="utf-8")

    names = sorted(str(p.relative_to(FILES)) for p in FILES.rglob("*")
                   if p.is_file() and p.name != "checksums.sha256")
    for p in FILES.rglob("*"):
        if p.is_symlink() or (p.is_file() and p.stat().st_mode & 0o111):
            errors.append(f"{p.relative_to(REPO)}: link simbólico ou executável")
    sums = "".join(f"{sha(FILES / n)}  {n}\n" for n in names)
    sums_path = FILES / "checksums.sha256"
    if not sums_path.exists() or sums_path.read_text(encoding="utf-8") != sums:
        errors.append("checksums.sha256 desatualizado")
        if not check:
            sums_path.write_text(sums, encoding="utf-8")

    for source, copies in SAME_AS.items():
        for copy in copies:
            if sha(REPO / copy) != sha(FILES / source):
                errors.append(f"{copy} difere de identity/files/{source}")

    unit = (HERE / "mainuan-identity-restore.service").read_text(encoding="utf-8")
    writable = [w.lstrip("-") for line in unit.splitlines()
                if line.startswith("ReadWritePaths=") for w in line.split("=", 1)[1].split()]
    for entry in manifest["entries"]:
        parent = entry["destination"].rsplit("/", 1)[0]
        if parent not in writable:
            errors.append(f"ReadWritePaths não libera {parent} ({entry['destination']})")

    fatal = [e for e in errors if not e.endswith("desatualizado")] if not check else errors
    for e in errors:
        print(("erro: " if e in fatal else "atualizado: ") + e, file=sys.stderr)
    return 1 if fatal else 0


if __name__ == "__main__":
    sys.exit(main())
