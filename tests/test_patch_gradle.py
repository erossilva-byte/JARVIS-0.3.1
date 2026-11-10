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
    assert result.count("com.google.mediapipe:tasks-genai:0.10.24") == 1, "Dependência IA local duplicada ou ausente"
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

# Cenário com buildTypes.release e variables.gradle: o SDK precisa ir a 36 (Android 16) e a
# assinatura de release precisa ser anexada — nunca reaproveitar a chave de debug.
with tempfile.TemporaryDirectory(prefix="jarvis-gradle-release-") as tmp:
    android = Path(tmp) / "android"
    app = android / "app"
    (android / "gradle" / "wrapper").mkdir(parents=True)
    app.mkdir(parents=True)
    gradle = app / "build.gradle"
    gradle.write_text('''android {
    defaultConfig {
        applicationId "com.jarvis.nova"
    }
    buildTypes {
        release {
            minifyEnabled false
        }
    }
}
dependencies {
}
''', encoding="utf-8")
    (android / "build.gradle").write_text('classpath "com.android.tools.build:gradle:8.2.1"\n', encoding="utf-8")
    (android / "variables.gradle").write_text('ext {\n    compileSdkVersion = 35\n    minSdkVersion = 24\n    targetSdkVersion = 34\n}\n', encoding="utf-8")
    (android / "gradle" / "wrapper" / "gradle-wrapper.properties").write_text(
        'distributionUrl=https\\://services.gradle.org/distributions/gradle-8.2.1-all.zip\n', encoding="utf-8")
    (android / "settings.gradle").write_text(
        'dependencyResolutionManagement { repositories { google(); mavenCentral() } }\n', encoding="utf-8")
    for _ in range(2):
        subprocess.run([sys.executable, str(PATCH), str(gradle)], check=True, capture_output=True, text=True)
    resultado = gradle.read_text(encoding="utf-8")
    variaveis = (android / "variables.gradle").read_text(encoding="utf-8")
    raiz_gradle = (android / "build.gradle").read_text(encoding="utf-8")
    wrapper = (android / "gradle" / "wrapper" / "gradle-wrapper.properties").read_text(encoding="utf-8")
    assert "signingConfig signingConfigs.release" in resultado, "BuildType release não recebeu a assinatura de release"
    assert resultado.count("signingConfig signingConfigs.release") == 1, "Assinatura de release duplicada"
    assert "compileSdkVersion = 36" in variaveis and "targetSdkVersion = 36" in variaveis, "SDK não foi para 36"
    assert "minSdkVersion = 26" in variaveis, "minSdk não foi para 26"
    assert "com.android.tools.build:gradle:8.13.0" in raiz_gradle, "AGP não foi para 8.13.0"
    assert "gradle-8.13-all.zip" in wrapper, "Gradle Wrapper não foi para 8.13"
    assert "storePassword 'android'" in resultado, "Assinatura de debug do CI foi removida"

print("Patch Gradle validado: API mínima 26, compile/target 36, AGP 8.13, assinatura de release separada da de debug, MediaPipe/IA local idempotente, sem SDK de palavra de ativação de terceiro e sem dependência openWakeWord não resolvida.")
