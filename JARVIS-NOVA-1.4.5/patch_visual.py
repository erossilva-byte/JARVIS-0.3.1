"""Visual nativo do Android: abertura escura e ícone do Jarvis.

Uso:  python3 patch_visual.py <pasta android>            aplica
      python3 patch_visual.py <pasta android> desfazer   volta ao original do Capacitor

Se algo aqui der problema na compilação, o workflow chama "desfazer" e compila de novo,
mas a compilação ainda pode falhar e precisa ser investigada.
"""
import os
import re
import shutil
import sys

base = sys.argv[1]
desfazer = len(sys.argv) > 2 and sys.argv[2] == "desfazer"
res = os.path.join(base, "app", "src", "main", "res")
COR = "#FF060A12"
# Cópias de segurança ficam FORA da pasta res (o Android recusa arquivos estranhos lá dentro).
BKP = os.path.join(base, ".jvbak")

ICONE_FG = """<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:pathData="M25,54 a29,29 0 1,0 58,0 a29,29 0 1,0 -58,0"
        android:fillColor="#00000000"
        android:strokeColor="#665EE2FF"
        android:strokeWidth="1.4" />
    <path
        android:pathData="M54,32 a22,22 0 1,1 -22,22"
        android:fillColor="#00000000"
        android:strokeColor="#FF5EE2FF"
        android:strokeWidth="2.4"
        android:strokeLineCap="round" />
    <path
        android:pathData="M42,54 a12,12 0 1,0 24,0 a12,12 0 1,0 -24,0"
        android:fillColor="#FF5EE2FF" />
    <path
        android:pathData="M49.5,54 a4.5,4.5 0 1,0 9,0 a4.5,4.5 0 1,0 -9,0"
        android:fillColor="#FFFFFFFF" />
</vector>
"""
ICONE_ADAPTIVO = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/jv_icon_bg" />
    <foreground android:drawable="@drawable/jv_icon_fg" />
</adaptive-icon>
"""
CORES = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="jv_icon_bg">#FF060A12</color>
</resources>
"""

# (caminho relativo, texto) dos arquivos que criamos ou substituímos
ARQUIVOS = [
    ("values/jarvis_icon.xml", CORES),
    ("drawable/jv_icon_fg.xml", ICONE_FG),
    ("mipmap-anydpi-v26/ic_launcher.xml", ICONE_ADAPTIVO),
    ("mipmap-anydpi-v26/ic_launcher_round.xml", ICONE_ADAPTIVO),
]
ESTILOS = os.path.join(res, "values", "styles.xml")


def caminho(rel):
    return os.path.join(res, *rel.split("/"))


def copia(rel):
    return os.path.join(BKP, rel.replace("/", "__"))


TODOS = [rel for rel, _ in ARQUIVOS] + ["values/styles.xml"]

if desfazer:
    for rel in TODOS:
        p = caminho(rel)
        if os.path.exists(copia(rel)):
            shutil.copyfile(copia(rel), p)      # existia: volta ao original
        elif os.path.exists(p) and rel != "values/styles.xml":
            os.remove(p)                        # foi criado por nós: remove
    print("visual nativo desfeito")
    sys.exit(0)

os.makedirs(BKP, exist_ok=True)

# 1) Abertura (splash) escura, sem clarão branco
if os.path.exists(ESTILOS):
    s = open(ESTILOS, encoding="utf-8").read()
    if not os.path.exists(copia("values/styles.xml")):
        shutil.copyfile(ESTILOS, copia("values/styles.xml"))
    if "@drawable/splash" in s:
        s = s.replace("@drawable/splash", COR)
    if 'parent="Theme.SplashScreen"' in s and "windowSplashScreenBackground" not in s:
        s = re.sub(
            r'(<style name="AppTheme\.NoActionBarLaunch"[^>]*>)',
            r'\1\n        <item name="windowSplashScreenBackground">%s</item>' % COR,
            s, count=1)
    open(ESTILOS, "w", encoding="utf-8").write(s)

# 2) Ícone do app (adaptativo, Android 8+)
for rel, texto in ARQUIVOS:
    p = caminho(rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    if os.path.exists(p) and not os.path.exists(copia(rel)):
        shutil.copyfile(p, copia(rel))
    open(p, "w", encoding="utf-8").write(texto)

print("visual nativo aplicado")
