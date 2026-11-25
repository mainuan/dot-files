#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
    echo "Uso: $0 /caminho/para/Mainuan/build/base/chroot" >&2
    exit 2
fi

CHROOT="$(realpath -- "$1")"
QM="$CHROOT/usr/share/calamares/lang/calamares_pt_BR.qm"

if [[ ! -s "$QM" ]]; then
    echo "Erro: catálogo pt_BR do Calamares não encontrado: $QM" >&2
    exit 1
fi

LCONVERT="${LCONVERT:-/usr/lib/qt6/bin/lconvert}"
LRELEASE="${LRELEASE:-/usr/lib/qt6/bin/lrelease}"
for tool in "$LCONVERT" "$LRELEASE"; do
    [[ -x "$tool" ]] || { echo "Erro: ferramenta Qt não encontrada: $tool" >&2; exit 1; }
done

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
TS="$TMP_DIR/calamares_pt_BR.ts"
NEW_QM="$TMP_DIR/calamares_pt_BR.qm"
VERIFY_TS="$TMP_DIR/verificado.ts"

"$LCONVERT" -i "$QM" -o "$TS"

python3 - "$TS" <<'PY'
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

path = Path(sys.argv[1])
tree = ET.parse(path)
root = tree.getroot()

updates = {
    "Config": {
        "<h1>Welcome to %1 setup</h1>": "<h1>Boas-vindas à configuração de %1</h1>",
        "<h1>Welcome to the Calamares installer for %1</h1>": "<h1>Boas-vindas ao instalador Calamares para %1</h1>",
        "<h1>Welcome to the %1 installer</h1>": "<h1>Boas-vindas ao instalador de %1</h1>",
        "<h1>Welcome to the Calamares setup program for %1</h1>": "<h1>Boas-vindas ao programa de configuração Calamares para %1</h1>",
    },
    "WelcomeViewStep": {"Welcome": "Boas-vindas"},
    "WelcomeQmlViewStep": {"Welcome": "Boas-vindas"},
}

for context_name, entries in updates.items():
    contexts = [c for c in root.findall("context") if c.findtext("name", "") == context_name]
    if len(contexts) != 1:
        raise SystemExit(f"ERRO: contexto {context_name} encontrado {len(contexts)} vezes.")
    context = contexts[0]
    for source, wanted in entries.items():
        messages = [m for m in context.findall("message") if m.findtext("source", "") == source]
        if len(messages) != 1:
            raise SystemExit(f"ERRO: mensagem {source!r} encontrada {len(messages)} vezes em {context_name}.")
        translation = messages[0].find("translation")
        if translation is None:
            raise SystemExit(f"ERRO: tradução ausente para {source!r}.")
        current = translation.text or ""
        if current == wanted:
            print(f"Já corrigido: {context_name} / {source}")
        elif "Bem-vindo" in current:
            translation.text = wanted
            print(f"Corrigido: {context_name} / {source}")
        else:
            raise SystemExit(f"ERRO: tradução inesperada em {context_name}: {current!r}")

tree.write(path, encoding="utf-8", xml_declaration=True)
PY

"$LRELEASE" "$TS" -qm "$NEW_QM"
"$LCONVERT" -i "$NEW_QM" -o "$VERIFY_TS"

python3 - "$VERIFY_TS" <<'PY'
import sys
import xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
expected = {
    "Config": {
        "<h1>Boas-vindas à configuração de %1</h1>",
        "<h1>Boas-vindas ao instalador Calamares para %1</h1>",
        "<h1>Boas-vindas ao instalador de %1</h1>",
        "<h1>Boas-vindas ao programa de configuração Calamares para %1</h1>",
    },
    "WelcomeViewStep": {"Boas-vindas"},
    "WelcomeQmlViewStep": {"Boas-vindas"},
}
for name, values in expected.items():
    contexts = [c for c in root.findall("context") if c.findtext("name", "") == name]
    if len(contexts) != 1:
        raise SystemExit(f"FALHA: contexto {name} ausente.")
    translations = {m.findtext("translation", "") for m in contexts[0].findall("message")}
    missing = values - translations
    if missing:
        raise SystemExit(f"FALHA: traduções não verificadas em {name}: {sorted(missing)}")
print("SUCESSO: as seis entradas estão presentes no catálogo recompilado.")
PY

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_DIR:-$HOME/Downloads}"
mkdir -p "$BACKUP_DIR"
BACKUP="$BACKUP_DIR/calamares_pt_BR.qm.backup-$STAMP"
OWNER_UID="$(stat -c '%u' "$QM")"
OWNER_GID="$(stat -c '%g' "$QM")"
MODE="$(stat -c '%a' "$QM")"
cp -a -- "$QM" "$BACKUP"
sudo install -o "$OWNER_UID" -g "$OWNER_GID" -m "$MODE" -- "$NEW_QM" "$QM"

echo "SUCESSO: título e etapa inicial do Calamares agora usam 'Boas-vindas'."
echo "Backup: $BACKUP"
