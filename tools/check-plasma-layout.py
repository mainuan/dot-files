#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Valida o leiaute padrão do Plasma e os provedores dos widgets externos."""

from __future__ import annotations

import argparse
import configparser
import json
import sys
from pathlib import Path

EXPECTED_WALLPAPER = "file:///usr/share/wallpapers/01ciano.png"

# IDs que não são applets padrão do Plasma precisam ter um provedor conhecido.
# Os três primeiros são empacotados por este repositório.
EXTERNAL_PROVIDERS = {
    "ChatAI-Plasmoid": "mainuan-desktop-defaults (incluído neste repositório)",
    "com.mike.desktop": "mainuan-desktop-defaults (incluído neste repositório)",
    "org.kde.plasma.powershowdesktop": "mainuan-desktop-defaults (incluído neste repositório)",
    "local.laetum.controlcenter": "painel-de-controle (>= 1.1.1)",
    "Chaac.Complete.Weather": "KDE Store (instalado pelo processo de composição da ISO)",
}
BUNDLED = {
    "ChatAI-Plasmoid",
    "com.mike.desktop",
    "org.kde.plasma.powershowdesktop",
}


def read_config(path: Path) -> configparser.ConfigParser:
    cfg = configparser.ConfigParser(
        interpolation=None, strict=False, allow_no_value=True
    )
    cfg.optionxform = str
    with path.open(encoding="utf-8") as stream:
        cfg.read_file(stream)
    return cfg


def is_containment(section: str) -> bool:
    parts = section.split("][")
    return len(parts) == 2 and parts[0] == "Containments" and parts[1].isdigit()


def is_applet(section: str) -> bool:
    parts = section.split("][")
    if (
        len(parts) < 4
        or len(parts) % 2
        or parts[0] != "Containments"
        or not parts[1].isdigit()
    ):
        return False
    return all(
        parts[index] == "Applets" and parts[index + 1].isdigit()
        for index in range(2, len(parts), 2)
    )


def validate(layout: Path, plasmoid_root: Path | None) -> list[str]:
    cfg = read_config(layout)
    containments = [s for s in cfg.sections() if is_containment(s)]
    desktops = [
        section
        for section in containments
        if cfg.get(section, "plugin", fallback="") == "org.kde.plasma.folder"
    ]
    if len(desktops) != 1:
        raise ValueError(
            "esperado exatamente um containment de desktop "
            f"(plugin=org.kde.plasma.folder); encontrados: {desktops}"
        )

    desktop = desktops[0]
    desktop_id = desktop.split("][", 1)[1]
    if cfg.get(desktop, "wallpaperplugin", fallback="") != "org.kde.image":
        raise ValueError(
            f"containment de desktop {desktop_id} não usa org.kde.image"
        )

    wallpaper_group = (
        f"Containments][{desktop_id}][Wallpaper][org.kde.image][General"
    )
    for key in ("Image", "PreviewImage"):
        actual = cfg.get(wallpaper_group, key, fallback="")
        if actual != EXPECTED_WALLPAPER:
            raise ValueError(
                f"papel de parede do desktop ({key}) incorreto: {actual!r}; "
                f"esperado {EXPECTED_WALLPAPER!r}"
            )

    applet_sections = [s for s in cfg.sections() if is_applet(s)]
    plugins = set()
    for section in applet_sections:
        plugin = cfg.get(section, "plugin", fallback="").strip()
        if not plugin:
            raise ValueError(f"applet sem plugin declarado: [{section}]")
        plugins.add(plugin)

    known_external = set(EXTERNAL_PROVIDERS)
    unknown = sorted(
        plugin
        for plugin in plugins
        if not plugin.startswith("org.kde.") and plugin not in known_external
    )
    if unknown:
        raise ValueError(
            "widgets externos sem provedor documentado em "
            f"EXTERNAL_PROVIDERS: {', '.join(unknown)}"
        )

    missing_bundled = sorted(BUNDLED - plugins)
    if missing_bundled:
        raise ValueError(
            "widgets empacotados que não aparecem no leiaute: "
            + ", ".join(missing_bundled)
        )

    if plasmoid_root is not None:
        for plugin in sorted(BUNDLED):
            metadata_path = plasmoid_root / plugin / "metadata.json"
            ui_path = plasmoid_root / plugin / "contents" / "ui" / "main.qml"
            if not metadata_path.is_file() or not ui_path.is_file():
                raise ValueError(
                    f"widget empacotado incompleto: {plugin} "
                    "(metadata.json ou contents/ui/main.qml ausente)"
                )
            with metadata_path.open(encoding="utf-8") as stream:
                metadata = json.load(stream)
            kplugin = metadata.get("KPlugin", {})
            if kplugin.get("Id") != plugin or not kplugin.get("Name"):
                raise ValueError(
                    f"metadata.json inválido ou ID divergente para {plugin}"
                )

    external = sorted(plugin for plugin in plugins if plugin in EXTERNAL_PROVIDERS)
    print(
        f"leiaute válido: desktop={desktop_id}; "
        f"{len(applet_sections)} applets; papel de parede conferido"
    )
    for plugin in external:
        print(f"widget: {plugin} -> {EXTERNAL_PROVIDERS[plugin]}")
    return external


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("layout", type=Path, help="plasma-org.kde.plasma.desktop-appletsrc")
    parser.add_argument(
        "--plasmoid-root",
        type=Path,
        help="diretório dos widgets instalados; valida metadata e QML dos widgets empacotados",
    )
    args = parser.parse_args()
    try:
        validate(args.layout, args.plasmoid_root)
    except (OSError, ValueError, configparser.Error, json.JSONDecodeError) as error:
        print(f"erro: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
