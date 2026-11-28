#!/usr/bin/env python3
"""Validate the complete Mainuan GRUB theme and its generated PFF2 fonts."""
from __future__ import annotations

import argparse
import glob
import re
import struct
import sys
import zlib
from pathlib import Path

EXPECTED_FONTS = {
    "DejaVu Sans Regular 14": (
        "dejavu_sans_regular_14.pf2", "DejaVu Sans", 14, "normal", "normal",
    ),
    "DejaVu Sans Regular 18": (
        "dejavu_sans_regular_18.pf2", "DejaVu Sans", 18, "normal", "normal",
    ),
    "DejaVu Sans Bold 18": (
        "dejavu_sans_bold_18.pf2", "DejaVu Sans", 18, "bold", "normal",
    ),
    "DejaVu Sans Mono Regular 16": (
        "dejavu_sans_mono_regular_16.pf2", "DejaVu Sans Mono", 16, "normal",
        "normal",
    ),
}
SLICE_PARTS = {"nw", "n", "ne", "w", "c", "e", "sw", "s", "se"}
SLICE_PREFIXES = {
    "menu_", "select_", "scrollbar_thumb_", "progress_bar_",
    "progress_highlight_",
}
JOINED_FLAGS = 0x80000000 | 0x40000000
PNG_SIGNATURE =b"\x89PNG\r\n\x1a\n"
PORTUGUESE_GLYPHS = set(map(ord, "áãâàçéêíóôõúÀÁÂÃÇÉÊÍÓÔÕÚ"))


class ValidationError(Exception):
    pass


def fail(message: str) -> None:
    raise ValidationError(message)


def read_pff2(path: Path) -> tuple[dict[str, list[bytes]], int, int]:
    """Read PFF2 sections; DATA terminates section scanning with length -1."""
    try:
        data = path.read_bytes()
    except OSError as exc:
        fail(f"{path}: não foi possível ler a fonte: {exc}")

    sections: dict[str, list[bytes]] = {}
    offset = 0
    first = True
    data_payload_start = -1
    saw_data = False

    while offset < len(data):
        if len(data) - offset < 8:
            fail(f"{path}: cabeçalho PFF2 truncado no byte {offset}")
        try:
            tag = data[offset:offset + 4].decode("ascii")
        except UnicodeDecodeError:
            fail(f"{path}: identificador de seção inválido no byte {offset}")
        length = struct.unpack(">I", data[offset + 4:offset + 8])[0]
        start = offset + 8

        if first:
            if tag != "FILE" or length != 4 or data[start:start + 4] != b"PFF2":
                fail(f"{path}: assinatura PFF2 ausente ou inválida")
            first = False

        if tag == "DATA":
            if length != 0xFFFFFFFF:
                fail(f"{path}: marcador DATA deveria ter comprimento 0xFFFFFFFF")
            if start >= len(data):
                fail(f"{path}: área DATA vazia")
            sections.setdefault(tag, []).append(data[start:])
            data_payload_start = start
            saw_data = True
            offset = len(data)
            break

        if length == 0xFFFFFFFF:
            fail(f"{path}: seção {tag} usa comprimento reservado 0xFFFFFFFF")
        end = start + length
        if end > len(data):
            fail(f"{path}: seção {tag} ultrapassa o fim do arquivo")
        sections.setdefault(tag, []).append(data[start:end])
        offset = end

    if not saw_data:
        fail(f"{path}: marcador terminal DATA ausente")

    required = {
        "FILE", "NAME", "FAMI", "WEIG", "SLAN", "PTSZ",
        "MAXW", "MAXH", "CHIX", "DATA",
    }
    missing = required.difference(sections)
    if missing:
        fail(f"{path}: seções PFF2 ausentes: {', '.join(sorted(missing))}")
    for tag in required:
        if len(sections[tag]) != 1:
            fail(f"{path}: seção PFF2 {tag} duplicada ou ausente")
    if not sections["DATA"][0]:
        fail(f"{path}: área de dados vazia")

    return sections, data_payload_start, len(data)


def section_text(sections: dict[str, list[bytes]], tag: str, path: Path) -> str:
    try:
        return sections[tag][0].rstrip(b"\0").decode("ascii")
    except (KeyError, UnicodeDecodeError):
        fail(f"{path}: seção {tag} não contém texto ASCII válido")
    raise AssertionError("unreachable")


def check_character_index(
    payload: bytes, path: Path, data_start: int, file_size: int,
    require_portuguese: bool,
) -> None:
    # GRUB's CHIX payload is a flat array of 9-byte records:
    # Unicode codepoint (4), storage flags (1), file offset (4).
    if not payload or len(payload) % 9:
        fail(f"{path}: comprimento do índice CHIX não é múltiplo de 9")

    codepoints: set[int] = set()
    for position in range(0, len(payload), 9):
        record = payload[position:position + 9]
        codepoint = struct.unpack(">I", record[:4])[0]
        flags = record[4]
        glyph_offset = struct.unpack(">I", record[5:9])[0]
        # grub-mkfont stores Arabic joined forms as the base codepoint plus
        # GRUB_FONT_CODE_LEFT_JOINED/RIGHT_JOINED (include/grub/font.h).
        if codepoint & ~(JOINED_FLAGS | 0x1FFFFF):
            fail(f"{path}: bits de ponto de código inválidos 0x{codepoint:08X}")
        base = codepoint & 0x1FFFFF
        if base > 0x10FFFF or 0xD800 <= base <= 0xDFFF:
            fail(f"{path}: ponto de código Unicode inválido U+{codepoint:04X}")
        if codepoint in codepoints:
            fail(f"{path}: ponto de código duplicado U+{codepoint:04X}")
        if flags & 0xF8 or (flags & 0x07) not in (0, 1):
            fail(f"{path}: flags CHIX inválidas para U+{codepoint:04X}")
        if not data_start <= glyph_offset < file_size:
            fail(f"{path}: offset de glifo fora da área DATA para U+{codepoint:04X}")
        codepoints.add(codepoint)

    required = set(range(0x20, 0x7F))
    if require_portuguese:
        required |= PORTUGUESE_GLYPHS
    missing = required - codepoints
    if missing:
        chars = ", ".join(f"U+{cp:04X}" for cp in sorted(missing))
        fail(f"{path}: glifos necessários ausentes: {chars}")


def check_font(font_dir: Path, font_name: str) -> None:
    filename, family, points, weight, slant = EXPECTED_FONTS[font_name]
    path = font_dir / filename
    if path.is_symlink() or not path.is_file() or path.stat().st_size == 0:
        fail(f"fonte ausente, vazia ou link simbólico: {path}")
    sections, data_start, file_size = read_pff2(path)

    actual_name = section_text(sections, "NAME", path)
    actual_family = section_text(sections, "FAMI", path)
    actual_weight = section_text(sections, "WEIG", path)
    actual_slant = section_text(sections, "SLAN", path)
    ptsz = sections["PTSZ"][0]
    if len(ptsz) != 2:
        fail(f"{path}: PTSZ deveria conter exatamente 2 bytes")
    actual_points = struct.unpack(">H", ptsz)[0]

    expected = {
        "NAME": (actual_name, font_name),
        "FAMI": (actual_family, family),
        "WEIG": (actual_weight, weight),
        "SLAN": (actual_slant, slant),
        "PTSZ": (actual_points, points),
    }
    for tag, (actual, wanted) in expected.items():
        if actual != wanted:
            fail(f"{path}: {tag}={actual!r}; esperado {wanted!r}")

    check_character_index(
        sections["CHIX"][0], path, data_start, file_size,
        require_portuguese=True,
    )


def check_png(path: Path) -> None:
    if path.is_symlink() or not path.is_file():
        fail(f"imagem ausente, não regular ou link simbólico: {path}")
    try:
        data = path.read_bytes()
    except OSError as exc:
        fail(f"{path}: erro de leitura: {exc}")
    if len(data) < 45 or data[:8] != PNG_SIGNATURE:
        fail(f"{path}: PNG inválido ou truncado")

    offset = 8
    chunks = 0
    saw_ihdr = False
    saw_idat = False
    saw_iend = False

    while offset < len(data):
        if len(data) - offset < 12:
            fail(f"{path}: cabeçalho de bloco PNG truncado")
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        payload_start = offset + 8
        payload_end = payload_start + length
        crc_end = payload_end + 4
        if crc_end > len(data):
            fail(f"{path}: bloco PNG {kind!r} ultrapassa o fim do arquivo")

        payload = data[payload_start:payload_end]
        stored_crc = struct.unpack(">I", data[payload_end:crc_end])[0]
        actual_crc = zlib.crc32(kind + payload) & 0xFFFFFFFF
        if actual_crc != stored_crc:
            fail(f"{path}: CRC inválido no bloco PNG {kind.decode('ascii', 'replace')}")

        if chunks == 0 and (kind != b"IHDR" or length != 13):
            fail(f"{path}: IHDR ausente ou inválido como primeiro bloco")
        if kind == b"IHDR":
            if saw_ihdr or chunks != 0 or length != 13:
                fail(f"{path}: bloco IHDR duplicado ou malformado")
            width, height = struct.unpack(">II", payload[:8])
            if not width or not height or width > 16384 or height > 16384:
                fail(f"{path}: dimensões PNG inválidas: {width}x{height}")
            saw_ihdr = True
        elif kind == b"IDAT":
            if not saw_ihdr or saw_iend:
                fail(f"{path}: bloco IDAT fora de ordem")
            saw_idat = True
        elif kind == b"IEND":
            if length != 0 or not saw_idat:
                fail(f"{path}: bloco IEND inválido ou sem dados IDAT")
            saw_iend = True
            if crc_end != len(data):
                fail(f"{path}: dados extras depois do bloco IEND")
            offset = crc_end
            break

        chunks += 1
        offset = crc_end

    if not (saw_ihdr and saw_idat and saw_iend):
        fail(f"{path}: sequência PNG incompleta (IHDR/IDAT/IEND)")

    # Valid CRCs do not prove the compressed pixel stream is decodable.
    # Pillow fully decodes the image and catches corrupted or truncated IDAT.
    try:
        from PIL import Image
        Image.MAX_IMAGE_PIXELS = 64_000_000
        with Image.open(path) as image:
            if image.format != "PNG":
                fail(f"{path}: Pillow não reconheceu o formato PNG")
            image.verify()
        with Image.open(path) as image:
            image.load()
    except ImportError:
        fail("Pillow (python3-pil) é obrigatório para validar os dados PNG")
    except Exception as exc:
        fail(f"{path}: decodificação PNG inválida: {exc}")


def check_theme(theme_dir: Path, font_dir: Path) -> int:
    if theme_dir.is_symlink() or not theme_dir.is_dir():
        fail(f"diretório do tema ausente, inválido ou link simbólico: {theme_dir}")
    if font_dir.is_symlink() or not font_dir.is_dir():
        fail(f"diretório das fontes ausente, inválido ou link simbólico: {font_dir}")
    theme_file = theme_dir / "theme.txt"
    if theme_file.is_symlink() or not theme_file.is_file():
        fail(f"theme.txt ausente ou não regular: {theme_file}")
    text = theme_file.read_text(encoding="utf-8")

    references = set(re.findall(
        r'(?m)^\s*(?:terminal-font|item_font|selected_item_font|font)\s*[:=]\s*"([^"]+)"',
        text,
    ))
    expected_names = set(EXPECTED_FONTS)
    if references != expected_names:
        fail(
            "fontes declaradas em theme.txt divergem do conjunto esperado; "
            f"ausentes={sorted(expected_names - references)}, "
            f"inesperadas={sorted(references - expected_names)}"
        )

    expected_files = {spec[0] for spec in EXPECTED_FONTS.values()}
    actual_files = {p.name for p in font_dir.glob("*.pf2")}
    if actual_files != expected_files:
        fail(
            f"conjunto PFF2 incorreto em {font_dir}; "
            f"ausentes={sorted(expected_files - actual_files)}, "
            f"extras={sorted(actual_files - expected_files)}"
        )
    for name in sorted(expected_names):
        check_font(font_dir, name)

    png_references = re.findall(r'"([^"]+\.png)"', text)
    if not png_references:
        fail("theme.txt não contém referências PNG")
    checked: set[Path] = set()
    for reference in png_references:
        if Path(reference).is_absolute() or ".." in Path(reference).parts:
            fail(f"caminho PNG inseguro em theme.txt: {reference}")
        if "*" in reference or "?" in reference or "[" in reference:
            matches = [Path(p) for p in glob.glob(str(theme_dir / reference))]
            if not matches:
                fail(f"padrão de imagem sem correspondência: {reference}")
            prefix = Path(reference).name.split("*", 1)[0]
            if prefix in SLICE_PREFIXES:
                suffixes = {p.stem[len(prefix):] for p in matches}
                if suffixes != SLICE_PARTS or len(matches) != 9:
                    fail(
                        f"conjunto 9-slice inválido para {reference}: "
                        f"{sorted(suffixes)}"
                    )
        else:
            matches = [theme_dir / reference]
        for path in matches:
            if path not in checked:
                check_png(path)
                checked.add(path)

    for path in theme_dir.rglob("*"):
        if path.is_symlink():
            fail(f"link simbólico não permitido no tema: {path}")

    # Validate every PNG shipped in the theme, including class icons that
    # GRUB loads implicitly and therefore are not named in theme.txt.
    for path in theme_dir.rglob("*.png"):
        if path not in checked:
            check_png(path)
            checked.add(path)

    for relative in {"background.png", "hints.png", "wordmark.png", "icons/mainuan.png"}:
        if theme_dir / relative not in checked:
            fail(f"imagem obrigatória não foi validada: {relative}")

    return len(expected_files)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--theme-dir", required=True, type=Path)
    parser.add_argument("--font-dir", type=Path,
                        help="diretório dos PFF2 (padrão: --theme-dir)")
    args = parser.parse_args()
    font_dir = args.font_dir or args.theme_dir
    try:
        count = check_theme(args.theme_dir, font_dir)
    except (OSError, ValidationError) as exc:
        print(f"ERRO: {exc}", file=sys.stderr)
        return 1
    print(
        f"OK: tema GRUB validado; {count} fontes PFF2, "
        "índices de glifos, referências PNG e conjuntos 9-slice íntegros."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
