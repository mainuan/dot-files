#!/usr/bin/env python3
from pathlib import Path
import ast
import re
import xml.etree.ElementTree as ET

BASE = Path(__file__).resolve().parent
ROOT = BASE / "lang"
QML = BASE / "show.qml"
PACKAGED_QM_DIR = BASE.parents[1] / "rootfs/etc/calamares/branding/vendor/lang"
EXPECTED_LOCALES = {
    "ar", "bn", "cs", "da", "de", "el", "es", "fa", "fi", "fr", "he", "hi", "hu",
    "id", "it", "ja", "ko", "nb", "nl", "pl", "pt", "pt_BR", "pt_PT", "ro", "ru",
    "sv", "sw", "th", "tr", "uk", "ur", "vi", "zh_CN", "zh_TW",
}

if not QML.is_file():
    raise SystemExit(f"ERRO: QML fonte não encontrado: {QML}")

qml_text = QML.read_text(encoding="utf-8")
# QML strings used by qsTr() are ordinary quoted literals. Decode their
# escaped newline sequences so they can be compared with Qt Linguist keys.
pattern = re.compile(r'qsTr\("((?:\\.|[^"\\])*)"\)', re.DOTALL)
qml_sources = {ast.literal_eval('"' + match.group(1) + '"') for match in pattern.finditer(qml_text)}
if len(qml_sources) != 10:
    raise SystemExit(
        f"ERRO: esperadas 10 chamadas qsTr() no QML aprovado; encontradas {len(qml_sources)}."
    )

files = sorted(ROOT.glob("calamares-vendor_*.ts"))
locales = {p.stem.removeprefix("calamares-vendor_") for p in files}
if locales != EXPECTED_LOCALES:
    raise SystemExit(f"ERRO: conjunto de idiomas incorreto: {sorted(locales ^ EXPECTED_LOCALES)}")

# The package must ship exactly the same 34 compiled catalogs as the sources.
expected_qm = {f"calamares-vendor_{locale}.qm" for locale in EXPECTED_LOCALES}
if not PACKAGED_QM_DIR.is_dir():
    raise SystemExit(f"ERRO: diretório de catálogos compilados ausente: {PACKAGED_QM_DIR}")
actual_qm = {
    p.name for p in PACKAGED_QM_DIR.glob("calamares-vendor_*.qm")
    if p.is_file() and p.stat().st_size > 0
}
if actual_qm != expected_qm:
    missing = sorted(expected_qm - actual_qm)
    extra = sorted(actual_qm - expected_qm)
    raise SystemExit(f"ERRO: catálogos QM divergentes. Ausentes: {missing}; extras: {extra}")

for path in files:
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError as exc:
        raise SystemExit(f"ERRO: XML inválido em {path.name}: {exc}") from exc

    messages = root.findall(".//message")
    if len(messages) != 10:
        raise SystemExit(f"ERRO: {path.name}: esperadas 10 mensagens, encontradas {len(messages)}")

    sources = {m.findtext("source", default="") for m in messages}
    if sources != qml_sources:
        missing = qml_sources - sources
        extra = sources - qml_sources
        raise SystemExit(
            f"ERRO: chaves divergentes em {path.name}. "
            f"Ausentes: {len(missing)}; extras: {len(extra)}."
        )

    for message in messages:
        source = message.findtext("source", default="")
        translation = message.findtext("translation", default="")
        if not source.strip():
            raise SystemExit(f"ERRO: {path.name}: string-fonte vazia")
        if not translation.strip() or message.find("translation") is None:
            raise SystemExit(f"ERRO: {path.name}: tradução vazia para {source[:50]!r}")

    print(f"OK {path.name}: 10 mensagens correspondentes ao QML")

print(
    f"OK: {len(files)} idiomas, {len(files) * 10} mensagens. "
    "As chaves foram comparadas diretamente com qsTr() do QML aprovado."
)
