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
SOURCE_TRANSLATIONS="$MAINUAN_ROOT/tools/calamares-slides/lang"

TARGET_BRANDING="$REPO_ROOT/rootfs/etc/calamares/branding/vendor"
TARGET_TOOLS="$REPO_ROOT/tools/calamares-slides"
TARGET_TRANSLATIONS="$TARGET_TOOLS/lang"
TARGET_CALAMARES_LANG="$REPO_ROOT/rootfs/usr/share/calamares/lang"

[[ -s "$SOURCE_QML" ]] || { echo "Erro: QML aprovado ausente: $SOURCE_QML" >&2; exit 1; }
[[ -d "$SOURCE_QM_DIR" ]] || { echo "Erro: catálogos compilados ausentes: $SOURCE_QM_DIR" >&2; exit 1; }
[[ -d "$SOURCE_TRANSLATIONS" ]] || { echo "Erro: catálogos-fonte ausentes: $SOURCE_TRANSLATIONS" >&2; exit 1; }
[[ -s "$TEST_CHROOT/usr/share/calamares/lang/calamares_pt_BR.qm" ]] || {
    echo "Erro: catálogo pt_BR do Calamares corrigido não encontrado no chroot." >&2
    exit 1
}

shopt -s nullglob
ts_files=("$SOURCE_TRANSLATIONS"/calamares-vendor_*.ts)
qm_files=("$SOURCE_QM_DIR"/calamares-vendor_*.qm)
if (( ${#ts_files[@]} != 34 )); then
    echo "Erro: esperados 34 catálogos-fonte; encontrados ${#ts_files[@]}." >&2
    exit 1
fi
if (( ${#qm_files[@]} != 34 )); then
    echo "Erro: esperados 34 catálogos compilados; encontrados ${#qm_files[@]}." >&2
    exit 1
fi

for n in 1 2 3 4 5; do
    [[ -s "$SOURCE_IMAGES/slide-$n.png" ]] || {
        echo "Erro: imagem aprovada ausente: $SOURCE_IMAGES/slide-$n.png" >&2
        exit 1
    }
done

# Confirm the TS and QM catalog sets match before copying anything.
python3 - "$SOURCE_TRANSLATIONS" "$SOURCE_QM_DIR" <<'PY'
from pathlib import Path
import sys

ts_dir, qm_dir = map(Path, sys.argv[1:])
ts = {p.stem.removeprefix("calamares-vendor_") for p in ts_dir.glob("calamares-vendor_*.ts")}
qm = {p.stem.removeprefix("calamares-vendor_") for p in qm_dir.glob("calamares-vendor_*.qm")}
if ts != qm:
    raise SystemExit(f"ERRO: idiomas divergentes entre TS e QM. TS sem QM: {sorted(ts-qm)}; QM sem TS: {sorted(qm-ts)}")
if len(ts) != 34:
    raise SystemExit(f"ERRO: conjunto esperado de 34 idiomas; encontrados {len(ts)}.")
print(f"OK: {len(ts)} idiomas presentes nos catálogos TS e QM.")
PY

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_DIR:-$HOME/Downloads}"
BACKUP="$BACKUP_DIR/dot-files-calamares-backup-$STAMP"
mkdir -p "$BACKUP"

# Preserve the old repository state before replacing anything.
for item in \
    "$TARGET_BRANDING/show.qml" \
    "$TARGET_BRANDING/images" \
    "$TARGET_BRANDING/lang" \
    "$TARGET_TOOLS/show.qml" \
    "$TARGET_TRANSLATIONS" \
    "$TARGET_CALAMARES_LANG/calamares_pt_BR.qm"; do
    if [[ -e "$item" ]]; then
        rel="${item#"$REPO_ROOT"/}"
        mkdir -p "$BACKUP/$(dirname "$rel")"
        cp -a -- "$item" "$BACKUP/$rel"
    fi
done

# Copy only from the approved local chroot, not from historical repository assets.
mkdir -p "$TARGET_BRANDING/images" "$TARGET_BRANDING/lang" \
         "$TARGET_TRANSLATIONS" "$TARGET_CALAMARES_LANG"
install -m 0644 "$SOURCE_QML" "$TARGET_BRANDING/show.qml"
install -m 0644 "$SOURCE_QML" "$TARGET_TOOLS/show.qml"

for n in 1 2 3 4 5; do
    install -m 0644 "$SOURCE_IMAGES/slide-$n.png" "$TARGET_BRANDING/images/slide-$n.png"
done

# Keep the TS sources in tools/ and the compiled catalogs beside the branding.
install -m 0644 "${ts_files[@]}" "$TARGET_TRANSLATIONS/"
install -m 0644 "${qm_files[@]}" "$TARGET_BRANDING/lang/"
install -m 0644 "$TEST_CHROOT/usr/share/calamares/lang/calamares_pt_BR.qm" \
    "$TARGET_CALAMARES_LANG/calamares_pt_BR.qm"

python3 "$TARGET_TOOLS/validate-translations.py"

cmp -s "$SOURCE_QML" "$TARGET_BRANDING/show.qml"
cmp -s "$SOURCE_QML" "$TARGET_TOOLS/show.qml"
for n in 1 2 3 4 5; do
    cmp -s "$SOURCE_IMAGES/slide-$n.png" "$TARGET_BRANDING/images/slide-$n.png"
done
for qm in "${qm_files[@]}"; do
    cmp -s "$qm" "$TARGET_BRANDING/lang/$(basename "$qm")"
done
cmp -s "$TEST_CHROOT/usr/share/calamares/lang/calamares_pt_BR.qm" \
    "$TARGET_CALAMARES_LANG/calamares_pt_BR.qm"

echo "SUCESSO: QML aprovado sincronizado em rootfs/ e tools/."
echo "SUCESSO: cinco imagens e 34 catálogos TS/QM sincronizados."
echo "SUCESSO: catálogo pt_BR do Calamares com 'Boas-vindas' incluído em rootfs/."
echo "Backup da versão anterior: $BACKUP"
echo
echo "Revise git status e git diff; depois crie o commit e envie ao GitHub."
