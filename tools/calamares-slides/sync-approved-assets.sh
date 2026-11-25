#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 2 ]]; then
    echo "Uso: $0 /caminho/para/dot-files /caminho/para/Mainuan" >&2
    exit 2
fi

REPO_ROOT="$(realpath -- "$1")"
BUILD_ROOT="$(realpath -- "$2")"
SOURCE_QML="$REPO_ROOT/tools/calamares-slides/show.qml"
TEST_BRANDING="$BUILD_ROOT/build/base/chroot/etc/calamares/branding/vendor"
TARGET_BRANDING="$REPO_ROOT/rootfs/etc/calamares/branding/vendor"

[[ -s "$SOURCE_QML" ]] || { echo "Erro: fonte QML ausente: $SOURCE_QML" >&2; exit 1; }
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
if [[ -f "$TARGET_BRANDING/show.qml" ]]; then
    cp -a "$TARGET_BRANDING/show.qml" "$BACKUP/show.qml"
fi
if [[ -d "$TARGET_BRANDING/images" ]]; then
    cp -a "$TARGET_BRANDING/images" "$BACKUP/images"
fi

mkdir -p "$TARGET_BRANDING/images"
install -m 0644 "$SOURCE_QML" "$TARGET_BRANDING/show.qml"
for n in 1 2 3 4 5; do
    install -m 0644 "$TEST_BRANDING/images/slide-$n.png" "$TARGET_BRANDING/images/slide-$n.png"
done

cmp -s "$SOURCE_QML" "$TARGET_BRANDING/show.qml"
for n in 1 2 3 4 5; do
    cmp -s "$TEST_BRANDING/images/slide-$n.png" "$TARGET_BRANDING/images/slide-$n.png"
done

echo "SUCESSO: os arquivos aprovados foram sincronizados em rootfs/."
echo "Backup da versão anterior: $BACKUP"
echo "Próximo passo: revisar git diff e adicionar os cinco PNGs e show.qml ao commit."
