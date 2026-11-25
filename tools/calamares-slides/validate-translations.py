#!/usr/bin/env python3
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent / "lang"
FILES = sorted(ROOT.glob("calamares-vendor_*.ts"))
EXPECTED_LOCALES = {
    "ar", "bn", "cs", "da", "de", "el", "es", "fa", "fi", "fr", "he", "hi", "hu",
    "id", "it", "ja", "ko", "nb", "nl", "pl", "pt", "pt_BR", "pt_PT", "ro", "ru",
    "sv", "sw", "th", "tr", "uk", "ur", "vi", "zh_CN", "zh_TW",
}
EXPECTED_SOURCES = {
    "Welcome to Mainuan!",
    "A modern and secure operating system, designed to boost your productivity.\n\nBuilt to meet the demands of the corporate world with excellence, while also being suited to personal use.",
    "Proven long-term stability",
    "Mainuan stands for predictability and solidity. It builds on the legacy, solidity, security and technical maturity developed over 19 years of TigerOS development, offering a robust platform ready for the future.\n\n• Continuity first: A system strategically designed so your team’s workflow or activities at home never suffer interruptions.\n\n• Secure updates: A predictable maintenance cycle that ensures long-term stability, free from unexpected system failures.",
    "Easy adaptation, without barriers",
    "A familiar, refined interface, designed specifically to eliminate the learning curve. Whether at the office or at home, the transition to Mainuan is natural, smooth and immediate.\n\n• Intuitive navigation: An intelligently organised applications menu, with essential tools always just a few clicks away.\n\n• High-performance environment: A clean, elegant design that minimises visual distractions, supporting concentration and mental clarity during use.",
    "Economic efficiency",
    "Mainuan maximises the return on your technology investment. It gets the most performance from the hardware you already own, smoothly extending the useful life of computers considered obsolete.\n\n• Real sustainability: We fight digital waste and electronic waste by avoiding artificial hardware requirements, such as TPM 2 or Secure Boot.\n\n• Intelligent resource use: Optimised memory and processor management generates real savings in energy and infrastructure, both for your home and your company.",
    "Absolute privacy",
    "Strong protection against digital threats, combined with an uncompromising ethical stance on your data. In Mainuan, the security of your business and the privacy of your home are treated as top priorities.\n\n• Zero telemetry: Completely free from hidden tracking, data collection and intrusive advertisements. Mainuan respects you! Your information belongs exclusively to you.",
}

locales = {p.stem.removeprefix("calamares-vendor_") for p in FILES}
assert locales == EXPECTED_LOCALES, f"Conjunto de idiomas incorreto: {sorted(locales ^ EXPECTED_LOCALES)}"
for path in FILES:
    root = ET.parse(path).getroot()
    messages = root.findall(".//message")
    assert len(messages) == 10, f"{path.name}: esperadas 10 mensagens, encontradas {len(messages)}"
    sources = {m.findtext("source", default="") for m in messages}
    assert sources == EXPECTED_SOURCES, f"{path.name}: fontes divergentes do show.qml"
    for message in messages:
        source = message.findtext("source", default="")
        translation = message.findtext("translation", default="")
        assert source.strip(), f"{path.name}: string-fonte vazia"
        assert translation.strip(), f"{path.name}: tradução vazia para {source[:50]!r}"
    print(f"OK {path.name}: 10 mensagens completas")
print(f"OK: {len(FILES)} idiomas, {len(FILES) * 10} mensagens. Inglês permanece como idioma-fonte/fallback.")
