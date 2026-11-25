#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 2 ]]; then
    echo "Uso: $0 /caminho/para/dot-files /caminho/para/Mainuan" >&2
    exit 2
fi

REPO_ROOT="$(realpath -- "$1")"
MAINUAN_ROOT="$(realpath -- "$2")"
SOURCE_QML="$REPO_ROOT/tools/calamares-slides/show.qml"
TEST_BRANDING="$MAINUAN_ROOT/build/base/chroot/etc/calamares/branding/vendor"
SOURCE_TRANSLATIONS="$MAINUAN_ROOT/tools/calamares-slides/lang"
TARGET_BRANDING="$REPO_ROOT/rootfs/etc/calamares/branding/vendor"
TARGET_TRANSLATIONS="$REPO_ROOT/tools/calamares-slides/lang"

[[ -s "$SOURCE_QML" ]] || { echo "Erro: fonte QML ausente: $SOURCE_QML" >&2; exit 1; }
[[ -d "$SOURCE_TRANSLATIONS" ]] || { echo "Erro: catálogos-fonte não encontrados: $SOURCE_TRANSLATIONS" >&2; exit 1; }

shopt -s nullglob
catalogues=("$SOURCE_TRANSLATIONS"/calamares-vendor_*.ts)
if (( ${#catalogues[@]} != 34 )); then
    echo "Erro: esperados 34 catálogos-fonte; encontrados ${#catalogues[@]} em $SOURCE_TRANSLATIONS" >&2
    exit 1
fi

for n in 1 2 3 4 5; do
    [[ -s "$TEST_BRANDING/images/slide-$n.png" ]] || {
        echo "Erro: imagem aprovada ausente no chroot: $TEST_BRANDING/images/slide-$n.png" >&2
        exit 1
    }
done

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_DIR:-$HOME/Downloads}"
BACKUP="$BACKUP_DIR/dot-files-calamares-backup-$STAMP"
mkdir -p "$BACKUP"

# Preserve the previous repository branding and source translations.
[[ ! -f "$TARGET_BRANDING/show.qml" ]] || cp -a "$TARGET_BRANDING/show.qml" "$BACKUP/show.qml"
[[ ! -d "$TARGET_BRANDING/images" ]] || cp -a "$TARGET_BRANDING/images" "$BACKUP/images"
[[ ! -d "$TARGET_TRANSLATIONS" ]] || cp -a "$TARGET_TRANSLATIONS" "$BACKUP/lang"

# Copy the final approved artwork, the already-committed QML, and all catalogs.
mkdir -p "$TARGET_BRANDING/images" "$TARGET_TRANSLATIONS"
install -m 0644 "$SOURCE_QML" "$TARGET_BRANDING/show.qml"
for n in 1 2 3 4 5; do
    install -m 0644 "$TEST_BRANDING/images/slide-$n.png" "$TARGET_BRANDING/images/slide-$n.png"
done
install -m 0644 "${catalogues[@]}" "$TARGET_TRANSLATIONS/"

python3 "$REPO_ROOT/tools/calamares-slides/validate-translations.py"

cmp -s "$SOURCE_QML" "$TARGET_BRANDING/show.qml"
for n in 1 2 3 4 5; do
    cmp -s "$TEST_BRANDING/images/slide-$n.png" "$TARGET_BRANDING/images/slide-$n.png"
done

echo "SUCESSO: QML, cinco imagens e 34 catálogos-fonte sincronizados."
echo "Backup da versão anterior: $BACKUP"
echo "Revise git status e git diff; depois adicione os arquivos ao commit."
