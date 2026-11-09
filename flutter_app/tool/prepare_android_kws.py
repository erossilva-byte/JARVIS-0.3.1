#!/usr/bin/env python3
"""Prepara runner Android Flutter com o motor KWS sherpa-onnx do projeto legado."""
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[2]
APP = Path(sys.argv[1]).resolve()
PACKAGE_DIR = APP / "src/main/kotlin/com/jarvis/nova"
JAVA_DIR = APP / "src/main/java/com/jarvis/nova"
MANIFEST = APP / "src/main/AndroidManifest.xml"
GRADLE = APP / "build.gradle.kts"

def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f"Não foi possível aplicar patch: {label}; trecho-base ausente.")
    return text.replace(old, new, 1)

if not APP.is_dir() or not MANIFEST.is_file() or not GRADLE.is_file():
    raise SystemExit(f"Runner Android Flutter incompleto: {APP}")

PACKAGE_DIR.mkdir(parents=True, exist_ok=True)
JAVA_DIR.mkdir(parents=True, exist_ok=True)
shutil.copy2(ROOT / "JarvisKwsEngine.java", JAVA_DIR / "JarvisKwsEngine.java")
shutil.copy2(ROOT / "flutter_app/android/KwsForegroundService.kt", PACKAGE_DIR / "KwsForegroundService.kt")
shutil.copy2(ROOT / "flutter_app/android/MainActivity.kt", PACKAGE_DIR / "MainActivity.kt")

gradle = GRADLE.read_text(encoding="utf-8")
# O template do Flutter pode gerar o build.gradle.kts sem bloco dependencies.
# Inserimos as dependências de forma idempotente, sem presumir um trecho-base.
dependencias = [
    '    implementation(files("libs/sherpa-onnx-1.13.8.aar"))',
    '    implementation("androidx.core:core:1.15.0")',
]
faltantes = [linha for linha in dependencias if linha not in gradle]
if faltantes:
    inicio = gradle.find("dependencies {")
    if inicio >= 0:
        abertura = inicio + len("dependencies {")
        gradle = gradle[:abertura] + "\\n" + "\\n".join(faltantes) + gradle[abertura:]
    else:
        gradle = gradle.rstrip() + "\\n\\ndependencies {\\n" + "\\n".join(dependencias) + "\\n}\\n"
if "minSdk = 26" not in gradle:
    if "minSdk = flutter.minSdkVersion" in gradle:
        gradle = gradle.replace("minSdk = flutter.minSdkVersion", "minSdk = 26", 1)
    elif "minSdkVersion 26" not in gradle:
        raise SystemExit("Não reconheci a configuração minSdk do runner Flutter; não vou alterar o build às cegas.")
GRADLE.write_text(gradle, encoding="utf-8")

manifest = MANIFEST.read_text(encoding="utf-8")
permissions = [
    "android.permission.RECORD_AUDIO",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_MICROPHONE",
    "android.permission.POST_NOTIFICATIONS",
]
for permission in permissions:
    marker = f'    <uses-permission android:name="{permission}" />'
    if marker not in manifest:
        manifest = manifest.replace("<application", marker + "\n    <application", 1)

service = """        <service
            android:name=".KwsForegroundService"
            android:exported="false"
            android:stopWithTask="false"
            android:foregroundServiceType="microphone" />\n"""
if ".KwsForegroundService" not in manifest:
    manifest = manifest.replace("</application>", service + "    </application>", 1)
MANIFEST.write_text(manifest, encoding="utf-8")

assets = APP / "src/main/assets/kws"
required = [
    "encoder-epoch-12-avg-2-chunk-16-left-64.int8.onnx",
    "decoder-epoch-12-avg-2-chunk-16-left-64.onnx",
    "joiner-epoch-12-avg-2-chunk-16-left-64.int8.onnx",
    "tokens.txt",
    "keywords.txt",
]
missing = [name for name in required if not (assets / name).is_file() or (assets / name).stat().st_size == 0]
if missing:
    raise SystemExit("Modelo KWS incompleto: " + ", ".join(missing))
print("Runner Android preparado com sherpa-onnx, assets KWS e serviço foreground.")
