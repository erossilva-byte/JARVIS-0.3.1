#!/usr/bin/env python3
"""Smoke-test the native Gradle patch without needing an Android SDK/network."""
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATCH = ROOT / "patch_gradle.py"

with tempfile.TemporaryDirectory(prefix="jarvis-gradle-patch-") as tmp:
    android = Path(tmp) / "android"
    app = android / "app"
    app.mkdir(parents=True)
    gradle = app / "build.gradle"
    settings = android / "settings.gradle"
    gradle.write_text('''android {\n    defaultConfig {\n        applicationId "com.jarvis.nova"\n        minSdkVersion rootProject.ext.minSdkVersion\n        targetSdkVersion rootProject.ext.targetSdkVersion\n    }\n}\ndependencies {\n    implementation "existing:dependency:1.0"\n}\n''', encoding="utf-8")
    settings.write_text('''dependencyResolutionManagement {\n    repositoriesMode.set(RepositoriesMode.PREFER_PROJECT)\n    repositories {\n        google()\n        mavenCentral()\n    }\n}\n''', encoding="utf-8")
    for _ in range(2):
        subprocess.run([sys.executable, str(PATCH), str(gradle)], check=True, capture_output=True, text=True)
    result = gradle.read_text(encoding="utf-8")
    repos = settings.read_text(encoding="utf-8")
    assert "minSdkVersion 26" in result, "minSdkVersion 26 não aplicado"
    assert "com.github.msnilsen:openwakeword-android:0.1.0" not in result, "Dependência openWakeWord não resolvida continua no Gradle"
    assert result.count("ai.picovoice:porcupine-android:4.0.2") == 1, "Dependência Porcupine duplicada ou ausente"
    assert result.count("com.google.mediapipe:tasks-genai:0.10.14") == 1, "Dependência IA local duplicada ou ausente"
    assert "https://jitpack.io" not in repos, "JitPack desnecessário continua sendo adicionado"
    # A assinatura de debug precisa estar fixada no keystore do repo: sem isso o CI
    # gerava um keystore novo a cada build e cada release saía com assinatura diferente.
    assert result.count("ci/debug.keystore") == 1, "Assinatura de debug não está fixada (ou está duplicada)"
    assert "keyAlias 'androiddebugkey'" in result and "storePassword 'android'" in result, "Credenciais do keystore de CI ausentes"

with tempfile.TemporaryDirectory(prefix="jarvis-gradle-kts-") as tmp:
    android = Path(tmp) / "android"
    app = android / "app"
    app.mkdir(parents=True)
    gradle = app / "build.gradle"
    settings = android / "settings.gradle.kts"
    gradle.write_text('android { defaultConfig { minSdkVersion 24 } }\ndependencies {}\n', encoding="utf-8")
    settings.write_text('dependencyResolutionManagement { repositories { google(); mavenCentral() } }\n', encoding="utf-8")
    subprocess.run([sys.executable, str(PATCH), str(gradle)], check=True, capture_output=True, text=True)
    assert "minSdkVersion 26" in gradle.read_text(encoding="utf-8")
    assert "jitpack.io" not in settings.read_text(encoding="utf-8")

print("Patch Gradle validado: API mínima 26, Porcupine/MediaPipe idempotentes e sem dependência openWakeWord não resolvida.")
