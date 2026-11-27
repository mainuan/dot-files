#!/bin/sh
# Deploy a complete GRUB theme without removing the currently working copy
# until the replacement has been copied and validated.
set -eu

if [ "$#" -ne 2 ]; then
    echo "uso: $0 <tema-origem> <destino>" >&2
    exit 2
fi

src=$1
dest=$2
parent=$(dirname "$dest")
stage="${dest}.dpkg-new"
backup="${dest}.dpkg-old"

die() {
    echo "mainuan-grub-theme: $*" >&2
    exit 1
}

validate_theme() {
    dir=$1
    [ -d "$dir" ] || return 1
    [ ! -L "$dir" ] || return 1
    [ -s "$dir/theme.txt" ] || return 1
    [ -s "$dir/background.png" ] || return 1
    [ -s "$dir/hints.png" ] || return 1
    [ -s "$dir/icons/mainuan.png" ] || return 1
    for font in \
        barlow_bold_40.pf2 \
        ubuntu_derivative_mainuan_regular_14.pf2 \
        ubuntu_derivative_mainuan_regular_18.pf2 \
        ubuntu_derivative_mainuan_medium_regular_18.pf2 \
        ubuntu_mono_derivative_mainuan_regular_16.pf2; do
        [ -s "$dir/$font" ] || return 1
        [ ! -L "$dir/$font" ] || return 1
    done
    count=$(find "$dir" -maxdepth 1 -type f -name '*.pf2' | wc -l)
    [ "$count" -eq 5 ] || return 1
    if find "$dir" -type l -print | grep -q .; then
        return 1
    fi
    return 0
}

[ -d "$src" ] && [ ! -L "$src" ] || die "origem inválida: $src"
validate_theme "$src" || die "tema de origem incompleto ou inválido: $src"
mkdir -p "$parent"

if [ -L "$dest" ]; then
    die "destino inesperado é um link simbólico: $dest"
fi
if [ -L "$backup" ]; then
    die "backup inesperado é um link simbólico: $backup"
fi

# Recover an interrupted transaction. If both paths exist, only discard the
# backup when the live destination is itself a complete current theme.
if [ -e "$backup" ]; then
    [ -d "$backup" ] || die "backup inesperado não é diretório: $backup"
    if [ -e "$dest" ]; then
        if validate_theme "$dest"; then
            rm -rf "$backup"
        else
            rm -rf "$dest" || die "não foi possível remover a cópia incompleta"
            mv "$backup" "$dest" || die "não foi possível restaurar o backup anterior"
        fi
    else
        mv "$backup" "$dest" || die "não foi possível recuperar o tema anterior"
    fi
fi

if [ -e "$dest" ] && [ ! -d "$dest" ]; then
    die "destino não é um diretório regular: $dest"
fi

# Copy and validate beside the destination; this keeps the final rename on
# the same filesystem and leaves the current theme untouched on copy errors.
rm -rf "$stage"
mkdir -p "$stage"
if cp -a "$src/." "$stage/"; then
    :
else
    rc=$?
    rm -rf "$stage"
    die "falha ao copiar o novo tema (código $rc)"
fi
if ! validate_theme "$stage"; then
    rm -rf "$stage"
    die "a cópia temporária falhou na validação; tema anterior preservado"
fi

had_old=no
if [ -e "$dest" ]; then
    mv "$dest" "$backup" || {
        rm -rf "$stage"
        die "não foi possível preservar o tema anterior"
    }
    had_old=yes
fi

if mv "$stage" "$dest"; then
    :
else
    rc=$?
    if [ "$had_old" = yes ] && [ -e "$backup" ]; then
        rm -rf "$dest"
        if ! mv "$backup" "$dest"; then
            echo "mainuan-grub-theme: FALHA CRÍTICA: não foi possível restaurar $backup para $dest" >&2
            exit 1
        fi
    fi
    rm -rf "$stage"
    die "falha ao publicar o novo tema (código $rc); cópia anterior restaurada"
fi

if [ "$had_old" = yes ] && [ -e "$backup" ]; then
    if ! rm -rf "$backup"; then
        echo "mainuan-grub-theme: novo tema instalado; backup residual em $backup" >&2
    fi
fi

exit 0
