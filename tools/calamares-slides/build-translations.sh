#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/lang"

if [[ $# -ne 1 ]]; then
    echo "Uso: $0 /caminho/para/branding/vendor/lang" >&2
    echo "Informe o diretório lang do branding do Calamares no chroot ou rootfs." >&2
    exit 2
fi
TARGET_DIR="$(realpath -m -- "$1")"
if [[ "$TARGET_DIR" == "/" || "$TARGET_DIR" == "$SOURCE_DIR" || "$(basename -- "$TARGET_DIR")" != "lang" ]]; then
    echo "Erro: o destino deve ser um diretório 'lang' dedicado, diferente da pasta de fontes: $TARGET_DIR" >&2
    exit 2
fi

find_lrelease() {
    local candidate
    for candidate in /usr/lib/qt6/bin/lrelease /usr/lib/qt6/libexec/lrelease lrelease-qt6 lrelease6 lrelease; do
        if [[ "$candidate" == */* ]]; then
            [[ -x "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
        else
            command -v "$candidate" >/dev/null 2>&1 && { command -v "$candidate"; return 0; }
        fi
    done
    return 1
}

LRELEASE="${LRELEASE:-$(find_lrelease || true)}"
if [[ -z "$LRELEASE" ]]; then
    echo "Erro: lrelease do Qt 6 não encontrado. Instale as ferramentas Qt Linguist do Qt 6 e tente novamente." >&2
    exit 1
fi

shopt -s nullglob
catalogues=("$SOURCE_DIR"/calamares-vendor_*.ts)
if (( ${#catalogues[@]} != 34 )); then
    echo "Erro: esperados 34 catálogos; encontrados ${#catalogues[@]} em $SOURCE_DIR" >&2
    exit 1
fi

# Validate source keys/translations and the exact packaged QM locale set first.
python3 "$SCRIPT_DIR/validate-translations.py"

TMP_DIR="$(mktemp -d)"
TARGET_PARENT="$(dirname -- "$TARGET_DIR")"
TARGET_NAME="$(basename -- "$TARGET_DIR")"
STAGE_DIR=""
BACKUP_DIR=""

cleanup() {
    local rc=$?
    # If the staged replacement failed after moving the old directory aside,
    # put the previous catalogs back before cleaning temporary files.
    if (( rc != 0 )) && [[ -n "$BACKUP_DIR" && -d "$BACKUP_DIR" && ! -e "$TARGET_DIR" ]]; then
        mv -- "$BACKUP_DIR" "$TARGET_DIR" || true
    fi
    [[ -z "$STAGE_DIR" ]] || rm -rf -- "$STAGE_DIR"
    rm -rf -- "$TMP_DIR"
}
trap cleanup EXIT

for ts in "${catalogues[@]}"; do
    locale="${ts##*calamares-vendor_}"
    locale="${locale%.ts}"
    echo "Compilando $locale..."
    "$LRELEASE" "$ts" -qm "$TMP_DIR/calamares-vendor_${locale}.qm"
done

# Stage beside the destination so the final directory rename stays on one
# filesystem. Preserve unrelated files, but replace the complete catalog set.
mkdir -p "$TARGET_PARENT"
if [[ -L "$TARGET_DIR" || ( -e "$TARGET_DIR" && ! -d "$TARGET_DIR" ) ]]; then
    echo "Erro: o destino precisa ser um diretório real: $TARGET_DIR" >&2
    exit 1
fi
STAGE_DIR="$(mktemp -d "$TARGET_PARENT/.${TARGET_NAME}.new.XXXXXX")"
if [[ -d "$TARGET_DIR" ]]; then
    cp -a -- "$TARGET_DIR/." "$STAGE_DIR/"
fi
find "$STAGE_DIR" -maxdepth 1 -name 'calamares-vendor_*.qm' -delete
install -m 0644 "$TMP_DIR"/calamares-vendor_*.qm "$STAGE_DIR"/
test "$(find "$STAGE_DIR" -maxdepth 1 -type f -name 'calamares-vendor_*.qm' | wc -l)" -eq 34

if [[ -e "$TARGET_DIR" ]]; then
    BACKUP_DIR="$(mktemp -d "$TARGET_PARENT/.${TARGET_NAME}.old.XXXXXX")"
    rmdir -- "$BACKUP_DIR"
    mv -- "$TARGET_DIR" "$BACKUP_DIR"
fi
mv -- "$STAGE_DIR" "$TARGET_DIR"
STAGE_DIR=""
if [[ -n "$BACKUP_DIR" ]]; then
    rm -rf -- "$BACKUP_DIR"
    BACKUP_DIR=""
fi

echo "Concluído: 34 catálogos instalados em $TARGET_DIR"
