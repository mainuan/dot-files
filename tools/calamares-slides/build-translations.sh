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

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
for ts in "${catalogues[@]}"; do
    locale="${ts##*calamares-vendor_}"
    locale="${locale%.ts}"
    echo "Compilando $locale..."
    "$LRELEASE" "$ts" -qm "$TMP_DIR/calamares-vendor_${locale}.qm"
done

# Never remove current catalogs until every replacement has compiled.
mkdir -p "$TARGET_DIR"
find "$TARGET_DIR" -maxdepth 1 -type f -name 'calamares-vendor_*.qm' -delete
install -m 0644 "$TMP_DIR"/calamares-vendor_*.qm "$TARGET_DIR"/
echo "Concluído: $(find "$TARGET_DIR" -maxdepth 1 -type f -name 'calamares-vendor_*.qm' | wc -l) catálogos instalados em $TARGET_DIR"
