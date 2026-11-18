#!/usr/bin/env python3
"""Render the Calamares slideshow offscreen to PNG files, in one language.

    tools/calamares-slides/preview.py <calamares-qml-dir> <lang> <out-dir> [WxH]

<calamares-qml-dir> holds calamares/slideshow (Presentation.qml, Slide.qml…),
from /usr/share/calamares/qml of the installer. <lang> is a translation name
(pt_BR, es, ar…) or "en" for the source text. Needs PySide6 and lrelease6
(or lrelease) to compile lang/calamares-vendor_<lang>.ts on the fly.
"""
import os
import shutil
import subprocess
import sys
import tempfile

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
from PySide6.QtCore import QLocale, QTimer, QTranslator, QUrl, Qt  # noqa: E402
from PySide6.QtGui import QGuiApplication  # noqa: E402
from PySide6.QtQuick import QQuickView  # noqa: E402

here = os.path.dirname(os.path.abspath(__file__))
branding = os.path.normpath(os.path.join(here, "../../rootfs/etc/calamares/branding/vendor"))
qml_dir, lang, out = sys.argv[1], sys.argv[2], sys.argv[3]
width, height = (int(v) for v in (sys.argv[4] if len(sys.argv) > 4 else "1100x560").split("x"))
os.makedirs(out, exist_ok=True)

app = QGuiApplication(sys.argv)
translator = QTranslator()
if lang != "en":
    tmp = tempfile.mkdtemp()
    qm = os.path.join(tmp, "show.qm")
    lrelease = shutil.which("lrelease6") or shutil.which("lrelease") or "/usr/lib/qt6/bin/lrelease"
    subprocess.run([lrelease, "-silent", os.path.join(here, "lang", f"calamares-vendor_{lang}.ts"), "-qm", qm], check=True)
    translator.load(qm)
    app.installTranslator(translator)
if QLocale(lang).textDirection() == Qt.RightToLeft:
    app.setLayoutDirection(Qt.RightToLeft)

view = QQuickView()
view.engine().addImportPath(qml_dir)
view.setResizeMode(QQuickView.SizeRootObjectToView)
view.resize(width, height)
view.setSource(QUrl.fromLocalFile(os.path.join(branding, "show.qml")))
if view.status() == QQuickView.Error:
    for error in view.errors():
        print(error.toString(), file=sys.stderr)
    sys.exit(1)
view.show()
root = view.rootObject()
count = root.property("slides").property("length").toInt()
state = {"i": 0}


def shoot():
    i = state["i"]
    view.grabWindow().save(os.path.join(out, f"{lang}-{i + 1}.png"))
    state["i"] += 1
    if state["i"] >= count:
        app.quit()
        return
    root.setProperty("currentSlide", state["i"])
    QTimer.singleShot(700, shoot)


QTimer.singleShot(1200, shoot)
app.exec()
print(f"{count} slides")
