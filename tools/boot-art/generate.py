#!/usr/bin/env python3
"""Generate the Mainuan boot artwork (GRUB, Plymouth, Plasma splash).

Every image of the boot experience comes from this script and the official
logo (logo.svg next to it), so the three stages share the same palette,
geometry and animation. Run it after changing a token below and commit the
results:

    python3 tools/boot-art/generate.py

Needs python3 and rsvg-convert (librsvg). Text is rendered with the
"Ubuntu" family through fontconfig.
"""
import argparse
import math
import os
import shutil
import subprocess
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
LOGO = os.path.join(HERE, "logo.svg")

# --- Design tokens (see docs/boot/02-design-system.md) -----------------------
BG_TOP = "#121a1e"        # graphite, top of the vertical gradient
BG_BOTTOM = "#0a0f12"     # graphite, bottom
TEAL = "#00828c"          # logo gradient, dark end
CYAN = "#0dd8e3"          # logo gradient, light end; accent colour
TEXT = "#e8f1f3"          # primary text
TEXT_MUTED = "#8fa3ab"    # secondary text, icons
LINE = "#ffffff"          # hairlines (used with low opacity)

LOGO_SIZE = 96            # logo diameter at 1x (Plymouth, splash)
RING_CANVAS = 160         # ring image size at 1x
RING_RADIUS = 66          # 15 px of air between the logo and the ring
RING_STROKE = 4
RING_SWEEP = 300          # degrees covered by the gradient tail
RING_PERIOD_FRAMES = 48   # Plymouth throbber frames per turn (about 1.6 s)

GRUB = os.path.join(ROOT, "rootfs/usr/share/grub/themes/mainuan")
PLYMOUTH = os.path.join(ROOT, "rootfs/usr/share/plymouth/themes/mainuan")
SPLASH = os.path.join(ROOT, "rootfs/usr/share/plasma/look-and-feel/org.mainuan.desktop/contents")


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    ra, rb = hex_rgb(a), hex_rgb(b)
    return "#%02x%02x%02x" % tuple(round(x + (y - x) * t) for x, y in zip(ra, rb))


def render(svg, out, width=None, height=None):
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False) as f:
        f.write(svg)
        src = f.name
    cmd = ["rsvg-convert", "-o", out]
    if width:
        cmd += ["-w", str(width)]
    if height:
        cmd += ["-h", str(height)]
    subprocess.run(cmd + [src], check=True)
    os.unlink(src)


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def svg_doc(w, h, body, defs=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
            f'width="{w}" height="{h}" viewBox="0 0 {w} {h}"><defs>{defs}</defs>{body}</svg>')


# --- Ring: the shared loading indicator ---------------------------------------
def ring_svg(rotation=0.0):
    c = RING_CANVAS / 2
    r = RING_RADIUS
    segs = 120
    body = [f'<circle cx="{c}" cy="{c}" r="{r}" fill="none" stroke="{LINE}" '
            f'stroke-opacity="0.07" stroke-width="{RING_STROKE}"/>']
    step = RING_SWEEP / segs
    for i in range(segs):
        t = (i + 1) / segs
        a0 = math.radians(-90 + i * step)
        a1 = math.radians(-90 + (i + 1) * step + 0.6)  # small overlap, no seams
        x0, y0 = c + r * math.cos(a0), c + r * math.sin(a0)
        x1, y1 = c + r * math.cos(a1), c + r * math.sin(a1)
        color = mix(TEAL, CYAN, t)
        body.append(f'<path d="M{x0:.3f},{y0:.3f} A{r},{r} 0 0 1 {x1:.3f},{y1:.3f}" fill="none" '
                    f'stroke="{color}" stroke-opacity="{t ** 1.6:.3f}" stroke-width="{RING_STROKE}"/>')
    ah = math.radians(-90 + RING_SWEEP)
    hx, hy = c + r * math.cos(ah), c + r * math.sin(ah)
    body.append(f'<circle cx="{hx:.3f}" cy="{hy:.3f}" r="{RING_STROKE / 2}" fill="{CYAN}"/>')
    return svg_doc(RING_CANVAS, RING_CANVAS,
                   f'<g transform="rotate({rotation:.3f} {c} {c})">{"".join(body)}</g>')


def logo_svg():
    with open(LOGO, encoding="utf-8") as f:
        return f.read()


# --- Plymouth (two-step) ------------------------------------------------------
def plymouth():
    render(logo_svg(), os.path.join(PLYMOUTH, "watermark.png"), LOGO_SIZE, LOGO_SIZE)
    for i in range(RING_PERIOD_FRAMES):
        render(ring_svg(360.0 * i / RING_PERIOD_FRAMES),
               os.path.join(PLYMOUTH, "throbber-%04d.png" % (i + 1)))
    # Password prompt: entry field, bullet, lock, caps lock, keyboard icon.
    render(svg_doc(320, 40, f'<rect x="1" y="1" width="318" height="38" rx="10" fill="{LINE}" '
                   f'fill-opacity="0.06" stroke="{CYAN}" stroke-opacity="0.55" stroke-width="1.5"/>'),
           os.path.join(PLYMOUTH, "entry.png"))
    render(svg_doc(14, 14, f'<circle cx="7" cy="7" r="5" fill="{TEXT}"/>'),
           os.path.join(PLYMOUTH, "bullet.png"))
    render(svg_doc(28, 40, f'<path d="M8,18 V12 a6,6 0 0 1 12,0 V18" fill="none" stroke="{TEXT_MUTED}" '
                   f'stroke-width="2.5"/><rect x="4" y="18" width="20" height="16" rx="3" fill="{CYAN}"/>'),
           os.path.join(PLYMOUTH, "lock.png"))
    render(svg_doc(28, 28, f'<path d="M14,4 L24,15 H18 V22 H10 V15 H4 Z" fill="none" stroke="{CYAN}" '
                   f'stroke-width="2" stroke-linejoin="round"/>'),
           os.path.join(PLYMOUTH, "capslock.png"))
    keys = "".join(f'<rect x="{6 + 6 * k}" y="12" width="4" height="3" fill="{TEXT_MUTED}"/>' for k in range(5))
    render(svg_doc(44, 28, f'<rect x="2" y="6" width="40" height="18" rx="3" fill="none" '
                   f'stroke="{TEXT_MUTED}" stroke-width="2"/>{keys}'
                   f'<rect x="12" y="18" width="20" height="3" fill="{TEXT_MUTED}"/>'),
           os.path.join(PLYMOUTH, "keyboard.png"))


# --- GRUB ---------------------------------------------------------------------
def grub_background(w=1920, h=1080):
    defs = (f'<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{BG_TOP}"/><stop offset="1" stop-color="{BG_BOTTOM}"/></linearGradient>'
            f'<radialGradient id="glow" cx="0.5" cy="0.2" r="0.55">'
            f'<stop offset="0" stop-color="{CYAN}" stop-opacity="0.10"/>'
            f'<stop offset="1" stop-color="{CYAN}" stop-opacity="0"/></radialGradient>')
    arcs = "".join(f'<circle cx="{w * 0.92:.0f}" cy="{h * 1.05:.0f}" r="{rr}" fill="none" stroke="{CYAN}" '
                   f'stroke-opacity="{op}" stroke-width="2"/>'
                   for rr, op in ((420, 0.06), (520, 0.04), (620, 0.025)))
    body = (f'<rect width="{w}" height="{h}" fill="url(#bg)"/>'
            f'<rect width="{w}" height="{h}" fill="url(#glow)"/>{arcs}')
    return svg_doc(w, h, body, defs)


def nine_slice(prefix, radius, fill, fill_op, stroke, stroke_op):
    """Write prefix_{nw,n,ne,w,c,e,sw,s,se}.png for a rounded rectangle."""
    size = radius * 2 + 4
    full = svg_doc(size, size, f'<rect x="0.5" y="0.5" width="{size - 1}" height="{size - 1}" rx="{radius}" '
                   f'fill="{fill}" fill-opacity="{fill_op}" stroke="{stroke}" stroke-opacity="{stroke_op}"/>')
    tmp = tempfile.mkdtemp()
    whole = os.path.join(tmp, "whole.png")
    render(full, whole)
    from PIL import Image
    im = Image.open(whole)
    r = radius
    boxes = {"nw": (0, 0, r, r), "n": (r, 0, size - r, r), "ne": (size - r, 0, size, r),
             "w": (0, r, r, size - r), "c": (r, r, size - r, size - r), "e": (size - r, r, size, size - r),
             "sw": (0, size - r, r, size), "s": (r, size - r, size - r, size), "se": (size - r, size - r, size, size)}
    for name, box in boxes.items():
        im.crop(box).save(os.path.join(GRUB, f"{prefix}_{name}.png"), optimize=True)
    shutil.rmtree(tmp)


ICONS = {
    # Generic operating system: a screen with a stand.
    "os": f'<rect x="4" y="6" width="24" height="16" rx="2.5" fill="none" stroke="{TEXT_MUTED}" stroke-width="2"/>'
          f'<path d="M12,27 H20 M16,22 V27" stroke="{TEXT_MUTED}" stroke-width="2" stroke-linecap="round"/>',
    # Memory test: a chip.
    "memtest": f'<rect x="8" y="8" width="16" height="16" rx="2" fill="none" stroke="{TEXT_MUTED}" stroke-width="2"/>'
               + "".join(f'<path d="M{p},4 V8 M{p},24 V28 M4,{p} H8 M24,{p} H28" stroke="{TEXT_MUTED}" '
                         f'stroke-width="2" stroke-linecap="round"/>' for p in (12, 16, 20)),
    # Firmware settings: a gear-like dial.
    "efi": f'<circle cx="16" cy="16" r="5" fill="none" stroke="{TEXT_MUTED}" stroke-width="2"/>'
           + "".join(f'<path d="M{16 + 8 * math.cos(math.radians(a)):.2f},{16 + 8 * math.sin(math.radians(a)):.2f} '
                     f'L{16 + 12 * math.cos(math.radians(a)):.2f},{16 + 12 * math.sin(math.radians(a)):.2f}" '
                     f'stroke="{TEXT_MUTED}" stroke-width="2.5" stroke-linecap="round"/>' for a in range(0, 360, 45)),
    # Restart: an open circle with an arrow head.
    "restart": f'<path d="M24.5,11 A10,10 0 1 0 26,16" fill="none" stroke="{TEXT_MUTED}" stroke-width="2.2" '
               f'stroke-linecap="round"/><path d="M26,5 V11.5 H19.5" fill="none" stroke="{TEXT_MUTED}" '
               f'stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>',
    # Shut down: the power symbol.
    "shutdown": f'<path d="M10.5,9 A10,10 0 1 0 21.5,9" fill="none" stroke="{TEXT_MUTED}" stroke-width="2.2" '
                f'stroke-linecap="round"/><path d="M16,4 V15" stroke="{TEXT_MUTED}" stroke-width="2.2" '
                f'stroke-linecap="round"/>',
}


def grub_icons():
    d = os.path.join(GRUB, "icons")
    render(logo_svg(), os.path.join(d, "mainuan.png"), 64, 64)
    for name, body in ICONS.items():
        render(svg_doc(32, 32, body), os.path.join(d, f"{name}.png"), 64, 64)
    # Same artwork for classes used by other entries.
    for alias, src in (("gnu-linux", "os"), ("uefi-firmware", "efi"), ("recovery", "os")):
        shutil.copyfile(os.path.join(d, f"{src}.png"), os.path.join(d, f"{alias}.png"))


def underline(prefix, color, opacity, thick=3):
    """9-slice pieces of a box that is transparent except for a bottom line.

    GRUB sizes the countdown bar after its text, so the bar is drawn as a
    thin line under the (centred) countdown text.
    """
    from PIL import Image
    rgba = hex_rgb(color) + (round(255 * opacity),)
    for name in ("nw", "n", "ne", "w", "c", "e", "sw", "s", "se"):
        im = Image.new("RGBA", (thick, thick), (0, 0, 0, 0))
        if name in ("sw", "s", "se"):
            im = Image.new("RGBA", (thick, thick), rgba)
        im.save(os.path.join(GRUB, f"{prefix}_{name}.png"), optimize=True)


def keycap(x, label_svg, w=30):
    return (f'<rect x="{x}" y="4" width="{w}" height="26" rx="6" fill="{LINE}" fill-opacity="0.05" '
            f'stroke="{LINE}" stroke-opacity="0.28"/><g transform="translate({x + w / 2},17)">{label_svg}</g>')


def grub_hints():
    """Language-neutral key hints: navigate, boot, edit, console."""
    m = TEXT_MUTED
    up = f'<path d="M0,-6 L5,1 H-5 Z" fill="{TEXT}"/>'
    down = f'<path d="M0,6 L5,-1 H-5 Z" fill="{TEXT}"/>'
    enter = f'<path d="M6,-6 V2 H-5 M-2,-2 L-6,2 L-2,6" fill="none" stroke="{TEXT}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>'
    letter = lambda ch: (f'<text x="0" y="5" text-anchor="middle" font-family="Ubuntu" font-weight="500" '
                         f'font-size="14" fill="{TEXT}">{ch}</text>')
    nav = f'<path d="M0,-7 V7 M-4,-3 L0,-7 L4,-3 M-4,3 L0,7 L4,3" fill="none" stroke="{m}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>'
    play = f'<path d="M-4,-6 L6,0 L-4,6 Z" fill="{m}"/>'
    pencil = f'<path d="M-6,6 L-5,1 L3,-7 L7,-3 L-1,5 Z M-6,6 L-1,5" fill="none" stroke="{m}" stroke-width="1.6" stroke-linejoin="round"/>'
    term = f'<path d="M-7,-5 L-2,0 L-7,5 M0,6 H7" fill="none" stroke="{m}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>'
    parts, x = [], 0
    for caps, icon in (([up, down], nav), ([enter], play), ([letter("E")], pencil), ([letter("C")], term)):
        for cap in caps:
            parts.append(keycap(x, cap))
            x += 34
        parts.append(f'<g transform="translate({x + 10},17)">{icon}</g>')
        x += 50
    width = x - 26
    render(svg_doc(width, 34, "".join(parts)), os.path.join(GRUB, "hints.png"))


def grub():
    render(grub_background(), os.path.join(GRUB, "background.png"))
    nine_slice("select", 8, CYAN, 0.16, CYAN, 0.55)
    nine_slice("menu", 14, LINE, 0.035, LINE, 0.09)
    nine_slice("scrollbar_thumb", 2, CYAN, 0.7, CYAN, 0.0)
    underline("progress_bar", LINE, 0.10)
    underline("progress_highlight", CYAN, 1.0)
    grub_icons()
    grub_hints()


# --- Plasma splash --------------------------------------------------------------
def splash():
    images = os.path.join(SPLASH, "splash/images")
    os.makedirs(images, exist_ok=True)
    shutil.copyfile(LOGO, os.path.join(images, "logo.svg"))
    write(os.path.join(images, "ring.svg"), ring_svg(0))
    # Preview shown in System Settings (Splash Screen).
    tmp = tempfile.mkdtemp()
    ring_png, logo_png = os.path.join(tmp, "ring.png"), os.path.join(tmp, "logo.png")
    render(ring_svg(0), ring_png, 80, 80)
    render(logo_svg(), logo_png, 48, 48)
    w, h = 400, 225
    defs = (f'<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{BG_TOP}"/>'
            f'<stop offset="1" stop-color="{BG_BOTTOM}"/></linearGradient>')
    body = (f'<rect width="{w}" height="{h}" fill="url(#bg)"/>'
            f'<image x="{(w - 80) / 2}" y="{(h - 80) / 2}" width="80" height="80" xlink:href="file://{ring_png}"/>'
            f'<image x="{(w - 48) / 2}" y="{(h - 48) / 2}" width="48" height="48" xlink:href="file://{logo_png}"/>')
    render(svg_doc(w, h, body, defs), os.path.join(SPLASH, "previews/splash.png"))
    shutil.rmtree(tmp)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--only", choices=("all", "grub"), default="all",
        help="gera toda a arte de boot (padrão) ou apenas os recursos do GRUB",
    )
    parser.add_argument(
        "--grub-dir", type=str,
        help="diretório de saída do tema GRUB (usado com --only grub)",
    )
    args = parser.parse_args()

    if args.grub_dir and args.only != "grub":
        parser.error("--grub-dir só pode ser usado com --only grub")

    global GRUB
    if args.grub_dir:
        GRUB = os.path.abspath(args.grub_dir)
        os.makedirs(GRUB, exist_ok=True)

    if args.only == "all":
        plymouth()
    grub()
    if args.only == "all":
        splash()
    print("ok")


if __name__ == "__main__":
    main()
