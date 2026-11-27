#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 2 ]]; then
    echo "Uso: $0 /caminho/para/dot-files /caminho/para/Mainuan" >&2
    exit 2
fi

REPO_ROOT="$(realpath -- "$1")"
MAINUAN_ROOT="$(realpath -- "$2")"
TEST_CHROOT="$MAINUAN_ROOT/build/base/chroot"
TEST_BRANDING="$TEST_CHROOT/etc/calamares/branding/vendor"
SOURCE_QML="$TEST_BRANDING/show.qml"
SOURCE_IMAGES="$TEST_BRANDING/images"
SOURCE_QM_DIR="$TEST_BRANDING/lang"
SOURCE_CALAMARES_QM="$TEST_CHROOT/usr/share/calamares/lang/calamares_pt_BR.qm"

TARGET_BRANDING="$REPO_ROOT/rootfs/etc/calamares/branding/vendor"
TARGET_TOOLS="$REPO_ROOT/tools/calamares-slides"
TARGET_TRANSLATIONS="$TARGET_TOOLS/lang"
TARGET_CALAMARES_LANG="$REPO_ROOT/rootfs/usr/share/calamares/lang"

path_has_symlink() {
    local candidate=$1
    while [[ "$candidate" != "/" ]]; do
        [[ ! -L "$candidate" ]] || return 0
        candidate="${candidate%/*}"
        [[ -n "$candidate" ]] || candidate="/"
    done
    return 1
}
for path in "$TARGET_BRANDING" "$TARGET_BRANDING/images" "$TARGET_BRANDING/lang" \
            "$TARGET_TOOLS" "$TARGET_TRANSLATIONS" "$TARGET_CALAMARES_LANG"; do
    if path_has_symlink "$path"; then
        echo "Erro: caminho de destino contém componente simbólico: $path" >&2
        exit 1
    fi
done
for path in "$TARGET_BRANDING/show.qml" "$TARGET_TOOLS/show.qml" \
            "$TARGET_CALAMARES_LANG/calamares_pt_BR.qm"; do
    [[ ! -L "$path" ]] || {
        echo "Erro: arquivo de destino é link simbólico: $path" >&2
        exit 1
    }
done

[[ -s "$SOURCE_QML" && ! -L "$SOURCE_QML" ]] || { echo "Erro: QML aprovado ausente, vazio ou simbólico: $SOURCE_QML" >&2; exit 1; }
[[ ! -L "$SOURCE_QM_DIR" ]] || { echo "Erro: diretório de catálogos-fonte é simbólico: $SOURCE_QM_DIR" >&2; exit 1; }
[[ -d "$SOURCE_QM_DIR" ]] || { echo "Erro: diretório de catálogos compilados ausente: $SOURCE_QM_DIR" >&2; exit 1; }
[[ -s "$SOURCE_CALAMARES_QM" ]] || { echo "Erro: catálogo pt_BR do Calamares corrigido não encontrado: $SOURCE_CALAMARES_QM" >&2; exit 1; }

LCONVERT="${LCONVERT:-/usr/lib/qt6/bin/lconvert}"
[[ -x "$LCONVERT" ]] || { echo "Erro: lconvert do Qt 6 não encontrado: $LCONVERT" >&2; exit 1; }

shopt -s nullglob
qm_files=("$SOURCE_QM_DIR"/calamares-vendor_*.qm)
if (( ${#qm_files[@]} != 34 )); then
    echo "Erro: esperados 34 catálogos compilados do slideshow; encontrados ${#qm_files[@]}." >&2
    exit 1
fi
for qm in "${qm_files[@]}"; do
    [[ -s "$qm" && ! -L "$qm" ]] || {
        echo "Erro: catálogo aprovado ausente, vazio ou simbólico: $qm" >&2
        exit 1
    }
done

for n in 1 2 3 4 5; do
    [[ -s "$SOURCE_IMAGES/slide-$n.png" && ! -L "$SOURCE_IMAGES/slide-$n.png" ]] || {
        echo "Erro: imagem aprovada ausente, vazia ou simbólica: $SOURCE_IMAGES/slide-$n.png" >&2
        exit 1
    }
done

TMP_DIR="$(mktemp -d)"
SYNC_STARTED=0
BACKUP=""
declare -a ROLLBACK_RELS=()
cleanup() {
    local rc=$? restore_failed=0 rel target
    if (( rc != 0 && SYNC_STARTED == 1 )); then
        echo "Falha na sincronização; restaurando o estado anterior..." >&2
        for rel in "${ROLLBACK_RELS[@]}"; do
            target="$REPO_ROOT/$rel"
            rm -rf -- "$target" || restore_failed=1
            if [[ -e "$BACKUP/$rel" || -L "$BACKUP/$rel" ]]; then
                mkdir -p -- "$(dirname -- "$target")" || restore_failed=1
                cp -a -- "$BACKUP/$rel" "$target" || restore_failed=1
            fi
        done
        if (( restore_failed )); then
            echo "ERRO CRÍTICO: rollback incompleto; preserve e inspecione o backup: $BACKUP" >&2
        else
            echo "Rollback concluído; backup integral preservado em: $BACKUP" >&2
        fi
    elif (( rc != 0 )) && [[ -n "$BACKUP" && -d "$BACKUP" ]]; then
        echo "Falha antes da sincronização; backup preservado em: $BACKUP" >&2
    fi
    rm -rf -- "$TMP_DIR"
    return "$rc"
}
trap cleanup EXIT
STAGED_TS="$TMP_DIR/lang"
mkdir -p "$STAGED_TS"

echo "=== Recuperando os 34 catálogos-fonte a partir dos QM aprovados ==="
for qm in "${qm_files[@]}"; do
    locale="${qm##*calamares-vendor_}"
    locale="${locale%.qm}"
    ts="$STAGED_TS/calamares-vendor_${locale}.ts"
    echo "Extraindo $locale..."
    "$LCONVERT" -i "$qm" -o "$ts"
    [[ -s "$ts" ]] || { echo "Erro: lconvert não gerou $ts" >&2; exit 1; }
done

# Confirm that the recovered sources preserve exactly the locale set and
# message keys of the approved QML before touching the repository files.
python3 - "$SOURCE_QML" "$STAGED_TS" <<'PY'
from pathlib import Path
import ast
import re
import sys
import xml.etree.ElementTree as ET

qml_path, ts_dir = Path(sys.argv[1]), Path(sys.argv[2])
qml_text = qml_path.read_text(encoding="utf-8")
pattern = re.compile(r'qsTr\("((?:\\.|[^"\\])*)"\)', re.DOTALL)
qml_sources = {ast.literal_eval('"' + m.group(1) + '"') for m in pattern.finditer(qml_text)}
if len(qml_sources) != 10:
    raise SystemExit(f"ERRO: esperadas 10 chamadas qsTr() no QML; encontradas {len(qml_sources)}.")

files = sorted(ts_dir.glob("calamares-vendor_*.ts"))
expected_locales = {
    "ar", "bn", "cs", "da", "de", "el", "es", "fa", "fi", "fr", "he", "hi", "hu",
    "id", "it", "ja", "ko", "nb", "nl", "pl", "pt", "pt_BR", "pt_PT", "ro", "ru",
    "sv", "sw", "th", "tr", "uk", "ur", "vi", "zh_CN", "zh_TW",
}
locales = {p.stem.removeprefix("calamares-vendor_") for p in files}
if locales != expected_locales:
    raise SystemExit(f"ERRO: conjunto de idiomas divergente: {sorted(locales ^ expected_locales)}.")

for path in files:
    root = ET.parse(path).getroot()
    messages = root.findall(".//message")
    if len(messages) != 10:
        raise SystemExit(f"ERRO: {path.name}: esperadas 10 mensagens, encontradas {len(messages)}.")
    sources = {m.findtext("source", default="") for m in messages}
    if sources != qml_sources:
        raise SystemExit(f"ERRO: as chaves de {path.name} não correspondem ao QML aprovado.")
    for message in messages:
        if not message.findtext("translation", default="").strip():
            raise SystemExit(f"ERRO: tradução vazia em {path.name}: {message.findtext('source', default='')[:60]}")
print(f"OK: {len(files)} idiomas e {len(files) * 10} traduções recuperadas e conferidas.")
PY

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_DIR:-$HOME/Downloads}"
mkdir -p "$BACKUP_DIR"
BACKUP="$(mktemp -d "$BACKUP_DIR/dot-files-calamares-backup-$STAMP.XXXXXX")"

# Preserve every path touched below. Missing paths are recorded too, so a
# failed first-time sync removes newly created files/directories on rollback.
backup_items=(
    "$TARGET_BRANDING/show.qml"
    "$TARGET_BRANDING/images"
    "$TARGET_BRANDING/lang"
    "$TARGET_TOOLS/show.qml"
    "$TARGET_TRANSLATIONS"
    "$TARGET_CALAMARES_LANG/calamares_pt_BR.qm"
)
for old in "$TARGET_BRANDING"/slides_*.png; do
    [[ -e "$old" || -L "$old" ]] || continue
    backup_items+=("$old")
done
for item in "${backup_items[@]}"; do
    rel="${item#"$REPO_ROOT"/}"
    ROLLBACK_RELS+=("$rel")
    if [[ -e "$item" || -L "$item" ]]; then
        [[ ! -L "$item" ]] || {
            echo "Erro: não sincronizo sobre link simbólico: $item" >&2
            exit 1
        }
        mkdir -p "$BACKUP/$(dirname "$rel")"
        cp -a -- "$item" "$BACKUP/$rel"
    fi
done
SYNC_STARTED=1

mkdir -p "$TARGET_BRANDING/images" "$TARGET_BRANDING/lang" \
         "$TARGET_TRANSLATIONS" "$TARGET_CALAMARES_LANG"

# Remove obsolete slide assets before copying the approved set. The backup
# above preserves the previous state if a later validation needs recovery.
find "$TARGET_BRANDING/images" -maxdepth 1 \( -type f -o -type l \) -name 'slide-*.png' -delete
find "$TARGET_BRANDING/lang" -maxdepth 1 \( -type f -o -type l \) -name 'calamares-vendor_*.qm' -delete
find "$TARGET_TRANSLATIONS" -maxdepth 1 \( -type f -o -type l \) -name 'calamares-vendor_*.ts' -delete
for old in "$TARGET_BRANDING"/slides_*.png; do
    [[ -e "$old" || -L "$old" ]] || continue
    rm -rf -- "$old"
done

echo "=== Instalando recursos aprovados em rootfs/ e tools/ ==="
install -m 0644 "$SOURCE_QML" "$TARGET_BRANDING/show.qml"
install -m 0644 "$SOURCE_QML" "$TARGET_TOOLS/show.qml"

for n in 1 2 3 4 5; do
    install -m 0644 "$SOURCE_IMAGES/slide-$n.png" "$TARGET_BRANDING/images/slide-$n.png"
done

install -m 0644 "$STAGED_TS"/calamares-vendor_*.ts "$TARGET_TRANSLATIONS/"
install -m 0644 "${qm_files[@]}" "$TARGET_BRANDING/lang/"
install -m 0644 "$SOURCE_CALAMARES_QM" "$TARGET_CALAMARES_LANG/calamares_pt_BR.qm"

echo "=== Validando catálogos no repositório ==="
python3 "$TARGET_TOOLS/validate-translations.py"

cmp -s "$SOURCE_QML" "$TARGET_BRANDING/show.qml"
cmp -s "$SOURCE_QML" "$TARGET_TOOLS/show.qml"
for n in 1 2 3 4 5; do
    cmp -s "$SOURCE_IMAGES/slide-$n.png" "$TARGET_BRANDING/images/slide-$n.png"
done
for qm in "${qm_files[@]}"; do
    cmp -s "$qm" "$TARGET_BRANDING/lang/$(basename "$qm")"
done
cmp -s "$SOURCE_CALAMARES_QM" "$TARGET_CALAMARES_LANG/calamares_pt_BR.qm"
test "$(find "$TARGET_BRANDING/images" -maxdepth 1 -type f -name 'slide-*.png' | wc -l)" -eq 5
test "$(find "$TARGET_BRANDING/lang" -maxdepth 1 -type f -name 'calamares-vendor_*.qm' | wc -l)" -eq 34
test "$(find "$TARGET_TRANSLATIONS" -maxdepth 1 -type f -name 'calamares-vendor_*.ts' | wc -l)" -eq 34
if compgen -G "$TARGET_BRANDING/slides_*.png" >/dev/null; then
    echo "Erro: recursos antigos slides_*.png ainda estão no branding." >&2
    exit 1
fi

echo
echo "SUCESSO: QML aprovado sincronizado em rootfs/ e tools/."
echo "SUCESSO: cinco imagens e 34 catálogos TS/QM sincronizados."
echo "SUCESSO: catálogo pt_BR do Calamares com 'Boas-vindas' incluído em rootfs/."
echo "Backup da versão anterior: $BACKUP"
echo
echo "Revise git status e git diff; depois crie o commit e envie ao GitHub."
