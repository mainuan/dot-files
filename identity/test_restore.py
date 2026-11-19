#!/usr/bin/python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Testes do mainuan-identity-restore numa raiz temporária (--root).

Precisam do root (contêiner do CI, ou `unshare -r` localmente): o script
confere e corrige o dono root:root. MAINUAN_IDENTITY_RESTORE escolhe o script
testado (padrão: o do repositório)."""

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.environ.get("MAINUAN_IDENTITY_RESTORE", os.path.join(HERE, "mainuan-identity-restore"))
FILES = os.path.join(HERE, "files")
IDENTITY = "usr/share/mainuan/identity"
SKEL_FACE = "etc/skel/.face"
BUG = "usr/share/plasma/avatars/kubuntu-bug.png"
LOGO = "usr/share/plasma/avatars/logoMainuan.png"
ICON = "usr/share/icons/hicolor/scalable/apps/mainuan.svg"
DESTS = (SKEL_FACE, BUG, LOGO, ICON)
HOME_FACE = "home/ana/.face"


def sha(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


class RestoreTest(unittest.TestCase):

    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="mainuan-identity-test-")
        os.chmod(self.root, 0o755)
        shutil.copytree(FILES, self.p(IDENTITY))
        with open(self.p(IDENTITY, "manifest.json"), encoding="utf-8") as f:
            self.manifest = json.load(f)
        self.expected = {e["destination"].lstrip("/"): e["sha256"] for e in self.manifest["entries"]}
        for d in ("etc/skel", "usr/share/plasma/avatars", "usr/share/icons/hicolor/scalable/apps",
                  "var/lib/dpkg/info", "home/ana"):
            os.makedirs(self.p(d), exist_ok=True)
        with open(self.p("var/lib/dpkg/diversions"), "w", encoding="utf-8") as f:
            f.write("/etc/skel/.face\n/var/lib/mainuan-user-avatar/diverted/skel.face\nmainuan-user-avatar\n"
                    "/usr/share/plasma/avatars/kubuntu-bug.png\n"
                    "/var/lib/mainuan-user-avatar/diverted/kubuntu-bug.png\nmainuan-user-avatar\n")
        with open(self.p("var/lib/dpkg/info/mainuan-desktop-defaults.list"), "w", encoding="utf-8") as f:
            f.write("/.\n/usr/share/plasma/avatars/logoMainuan.png\n"
                    "/usr/share/icons/hicolor/scalable/apps/mainuan.svg\n")
        # Arquivo pessoal com o mesmo nome do destino do skel: nunca tocado.
        with open(self.p(HOME_FACE), "wb") as f:
            f.write(b"foto pessoal")
        os.chown(self.p("home/ana"), 1000, 1000)
        os.chown(self.p(HOME_FACE), 1000, 1000)
        self.home_before = self.stat(HOME_FACE)

    def tearDown(self):
        self.assertEqual(self.stat(HOME_FACE), self.home_before, "~/.face pessoal foi alterado")
        shutil.rmtree(self.root)

    def p(self, *parts):
        return os.path.join(self.root, *parts)

    def stat(self, rel):
        st = os.lstat(self.p(rel))
        return (st.st_ino, st.st_mode, st.st_uid, st.st_gid, st.st_size, st.st_mtime_ns, st.st_ctime_ns,
                sha(self.p(rel)) if os.path.isfile(self.p(rel)) and not os.path.islink(self.p(rel)) else None)

    def snapshot(self):
        tree = {}
        for base, dirs, files in os.walk(self.root):
            for name in dirs + files:
                full = os.path.join(base, name)
                tree[os.path.relpath(full, self.root)] = self.stat(os.path.relpath(full, self.root))
        return tree

    def run_restore(self, *args):
        env = {k: v for k, v in os.environ.items() if k != "JOURNAL_STREAM"}
        r = subprocess.run([sys.executable, "-I", SCRIPT, "--root", self.root, *args],
                           capture_output=True, text=True, env=env, timeout=60)
        self.last_output = r.stdout + r.stderr
        return r.returncode

    def assertRestored(self, rel):
        path = self.p(rel)
        st = os.lstat(path)
        self.assertTrue(os.path.isfile(path) and not os.path.islink(path), rel)
        self.assertEqual(sha(path), self.expected[rel], rel)
        self.assertEqual(st.st_mode & 0o7777, 0o644, rel)
        self.assertEqual((st.st_uid, st.st_gid), (0, 0), rel)

    def write_manifest(self, mutate):
        manifest = json.loads(json.dumps(self.manifest))
        mutate(manifest)
        with open(self.p(IDENTITY, "manifest.json"), "w", encoding="utf-8") as f:
            json.dump(manifest, f)

    # --- casos -------------------------------------------------------------

    def test_absent_files_are_restored(self):
        self.assertEqual(self.run_restore(), 0, self.last_output)
        for rel in DESTS:
            self.assertRestored(rel)
        self.assertIn("4 restauradas", self.last_output)
        self.assertEqual([n for n in os.listdir(self.p("etc/skel")) if n.startswith(".mainuan-identity-")], [])

    def test_intact_files_are_not_written_and_second_run_is_noop(self):
        self.assertEqual(self.run_restore(), 0, self.last_output)
        before = self.snapshot()
        self.assertEqual(self.run_restore(), 0, self.last_output)
        self.assertIn("4 conformes, 0 restauradas", self.last_output)
        self.assertEqual(self.snapshot(), before, "a segunda execução escreveu algo")
        self.assertEqual(self.run_restore("--check"), 0, self.last_output)

    def test_corrupted_file_is_replaced(self):
        self.run_restore()
        with open(self.p(SKEL_FACE), "wb") as f:
            f.write(b"<svg>kubuntu</svg>")
        self.assertEqual(self.run_restore("--check"), 1)
        self.assertEqual(self.run_restore(), 0, self.last_output)
        self.assertRestored(SKEL_FACE)
        self.assertIn("conteúdo diferente", self.last_output)

    def test_wrong_mode_and_owner_are_fixed_in_place(self):
        self.run_restore()
        os.chmod(self.p(BUG), 0o666)
        os.chown(self.p(LOGO), 1000, 1000)
        inodes = (os.lstat(self.p(BUG)).st_ino, os.lstat(self.p(LOGO)).st_ino)
        self.assertEqual(self.run_restore("--check"), 1)
        self.assertEqual(self.run_restore(), 0, self.last_output)
        self.assertRestored(BUG)
        self.assertRestored(LOGO)
        self.assertEqual((os.lstat(self.p(BUG)).st_ino, os.lstat(self.p(LOGO)).st_ino), inodes)
        self.assertIn("modo ou dono diferente", self.last_output)

    def test_symlink_destination_is_refused(self):
        os.makedirs(self.p("outside"))
        with open(self.p("outside/target"), "wb") as f:
            f.write(b"alvo")
        os.symlink(self.p("outside/target"), self.p(SKEL_FACE))
        before = self.stat("outside/target")
        self.assertEqual(self.run_restore(), 2, self.last_output)
        self.assertTrue(os.path.islink(self.p(SKEL_FACE)))
        self.assertEqual(self.stat("outside/target"), before)
        self.assertIn("link simbólico", self.last_output)
        for rel in (BUG, LOGO, ICON):  # as outras entradas seguem
            self.assertRestored(rel)
        self.assertEqual(self.run_restore("--check"), 2)

    def test_symlink_parent_directory_is_refused(self):
        os.makedirs(self.p("evil"))
        shutil.rmtree(self.p("usr/share/plasma/avatars"))
        os.symlink(self.p("evil"), self.p("usr/share/plasma/avatars"))
        self.assertEqual(self.run_restore(), 2, self.last_output)
        self.assertEqual(os.listdir(self.p("evil")), [])
        self.assertRestored(SKEL_FACE)
        self.assertRestored(ICON)

    def test_symlink_higher_up_is_refused(self):
        os.rename(self.p("etc"), self.p("etc.real"))
        os.symlink("etc.real", self.p("etc"))
        self.assertEqual(self.run_restore(), 2, self.last_output)
        self.assertFalse(os.path.lexists(self.p("etc.real/skel/.face")))

    def test_group_writable_directory_is_refused(self):
        os.chmod(self.p("etc/skel"), 0o777)
        self.assertEqual(self.run_restore(), 2, self.last_output)
        self.assertFalse(os.path.lexists(self.p(SKEL_FACE)))

    def test_missing_directory_is_created(self):
        shutil.rmtree(self.p("usr/share/icons"))
        self.assertEqual(self.run_restore("--check"), 1, self.last_output)
        self.assertFalse(os.path.exists(self.p("usr/share/icons")))
        self.assertEqual(self.run_restore(), 0, self.last_output)
        self.assertRestored(ICON)
        st = os.lstat(self.p("usr/share/icons/hicolor"))
        self.assertEqual((st.st_mode & 0o7777, st.st_uid), (0o755, 0))

    def test_check_mode_never_writes(self):
        before = self.snapshot()
        self.assertEqual(self.run_restore("--check"), 1, self.last_output)
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(self.run_restore(), 0)
        self.assertEqual(self.run_restore("--check"), 0, self.last_output)

    def test_condition_not_met_is_skipped(self):
        os.unlink(self.p("var/lib/dpkg/diversions"))
        os.unlink(self.p("var/lib/dpkg/info/mainuan-desktop-defaults.list"))
        with open(self.p(BUG), "wb") as f:
            f.write(b"png do kubuntu")
        self.assertEqual(self.run_restore(), 0, self.last_output)
        self.assertIn("4 ignoradas", self.last_output)
        self.assertFalse(os.path.lexists(self.p(SKEL_FACE)))
        with open(self.p(BUG), "rb") as f:
            self.assertEqual(f.read(), b"png do kubuntu")

    def test_tampered_source_is_refused(self):
        with open(self.p(IDENTITY, "avatars/cyan.svg"), "ab") as f:
            f.write(b"<!-- alterado -->")
        self.assertEqual(self.run_restore(), 2, self.last_output)
        self.assertFalse(os.path.lexists(self.p(SKEL_FACE)))
        self.assertIn("não confere com o sha256", self.last_output)

    def test_invalid_manifests_are_refused_without_writing(self):
        bad_destinations = [
            "/etc/passwd", "/etc/skel/../shadow", "etc/skel/.face", "/home/ana/.face",
            "/usr/share/plasma/avatars/../../../etc/x", "/usr/share/plasma//avatars/x",
            "/root/.face", "/etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc",
            "/usr/share/wallpapers/01ciano.png", "/etc/skel/.face/",
        ]
        cases = [lambda m, d=d: m["entries"][0].update(destination=d) for d in bad_destinations]
        cases += [
            lambda m: m["entries"][0].update(source="../../../../etc/shadow"),
            lambda m: m["entries"][0].update(source="/etc/shadow"),
            lambda m: m["entries"][0].update(mode="4755"),
            lambda m: m["entries"][0].update(mode="0666"),
            lambda m: m["entries"][0].update(owner="ana"),
            lambda m: m["entries"][0].update(policy="overwrite"),
            lambda m: m["entries"][0].update(condition={"owned_by": "kubuntu-settings-desktop"}),
            lambda m: m["entries"][0].update(extra=1),
            lambda m: m["entries"].append(dict(m["entries"][0])),
            lambda m: m.update(format=2),
        ]
        before = self.snapshot()
        for i, mutate in enumerate(cases):
            with self.subTest(case=i):
                self.write_manifest(mutate)
                self.assertEqual(self.run_restore(), 2, self.last_output)
                self.assertIn("manifesto recusado", self.last_output)
                self.assertEqual(self.run_restore("--check"), 2)
                now = self.snapshot()
                now.pop(os.path.join(IDENTITY, "manifest.json"))
                ref = dict(before)
                ref.pop(os.path.join(IDENTITY, "manifest.json"))
                self.assertEqual(now, ref)

    def test_stale_temporary_is_cleaned(self):
        stale = self.p("etc/skel/.mainuan-identity-0123456789abcdef.tmp")
        with open(stale, "wb") as f:
            f.write(b"resto")
        self.assertEqual(self.run_restore(), 0, self.last_output)
        self.assertFalse(os.path.exists(stale))

    def test_shipped_manifest_matches_files(self):
        for entry in self.manifest["entries"]:
            self.assertEqual(sha(os.path.join(FILES, entry["source"])), entry["sha256"])


if __name__ == "__main__":
    if os.geteuid() != 0:
        sys.exit("os testes precisam do root (contêiner do CI ou `unshare -r`)")
    unittest.main(verbosity=2)
