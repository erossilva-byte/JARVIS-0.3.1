"""Configura dependências Android verificadas do J.A.R.V.I.S. Nova."""
import re
import sys
from pathlib import Path

app_gradle = Path(sys.argv[1])
app_text = app_gradle.read_text(encoding="utf-8")
pico_coordinate = 'implementation "ai.picovoice:porcupine-android:4.0.2"'
local_ai_coordinate = 'implementation "com.google.mediapipe:tasks-genai:0.10.14"'

# Porcupine and the native local AI integration target Android 8.0+ in this build. MediaPipe 0.10.14 is pinned for Java 17/Gradle 8.2 compatibility; newer MediaPipe artifacts may require newer bytecode/runtime.
# Override the Capacitor template default so the APK does not install on unsupported devices.
default_config = re.search(r"\bdefaultConfig\s*\{", app_text)
if not default_config:
    raise SystemExit(f"Bloco defaultConfig {{ não encontrado em {app_gradle}")
start_cfg = default_config.end() - 1
level_cfg = 0
end_cfg = None
for i in range(start_cfg, len(app_text)):
    if app_text[i] == "{": level_cfg += 1
    elif app_text[i] == "}":
        level_cfg -= 1
        if level_cfg == 0:
            end_cfg = i
            break
if end_cfg is None:
    raise SystemExit(f"Bloco defaultConfig incompleto em {app_gradle}")
config_block = app_text[start_cfg:end_cfg + 1]
if re.search(r"(?m)^\s*minSdkVersion\s+26\s*$", config_block):
    print("minSdkVersion 26 já configurado")
elif re.search(r"(?m)^\s*minSdkVersion(?:\s*=)?\s+[^\n]+", config_block):
    config_block = re.sub(r"(?m)^(\s*)minSdkVersion(?:\s*=)?\s+[^\n]+", r"\g<1>minSdkVersion 26", config_block, count=1)
    app_text = app_text[:start_cfg] + config_block + app_text[end_cfg + 1:]
    print("minSdkVersion ajustado para 26 (Android 8.0+)")
else:
    config_block = config_block[:-1] + "    minSdkVersion 26\n}"
    app_text = app_text[:start_cfg] + config_block + app_text[end_cfg + 1:]
    print("minSdkVersion 26 adicionado (Android 8.0+)")
if pico_coordinate not in app_text:
    match = re.search(r"\bdependencies\s*\{", app_text)
    start = match.end() - 1
    level = 0
    end = None
    for i in range(start, len(app_text)):
        if app_text[i] == "{": level += 1
        elif app_text[i] == "}":
            level -= 1
            if level == 0:
                end = i
                break
    if end is None: raise SystemExit(f"Bloco dependencies incompleto em {app_gradle}")
    app_text = app_text[:end] + "    " + pico_coordinate + "\n" + app_text[end:]
    print(f"Dependência Porcupine adicionada: {app_gradle}")
if local_ai_coordinate not in app_text:
    match = re.search(r"\bdependencies\s*\{", app_text)
    start = match.end() - 1
    level = 0
    end = None
    for i in range(start, len(app_text)):
        if app_text[i] == "{": level += 1
        elif app_text[i] == "}":
            level -= 1
            if level == 0:
                end = i
                break
    if end is None: raise SystemExit(f"Bloco dependencies incompleto em {app_gradle}")
    app_text = app_text[:end] + "    " + local_ai_coordinate + "\n" + app_text[end:]
    print(f"Dependência IA local adicionada: {app_gradle}")
else:
    print(f"Dependência IA local já presente: {app_gradle}")

# Persist both the SDK-floor adjustment and dependency changes on every run.
app_gradle.write_text(app_text, encoding="utf-8")

settings = app_gradle.parent.parent / "settings.gradle"
if not settings.exists():
    settings = app_gradle.parent.parent / "settings.gradle.kts"
if not settings.exists():
    raise SystemExit(f"Não encontrei settings.gradle(.kts) junto de {app_gradle}")
settings_text = settings.read_text(encoding="utf-8")
# Porcupine and MediaPipe are resolved from Google Maven/Maven Central. Do not add
# JitPack: the previous openWakeWord coordinate failed resolution in CI.
settings.write_text(settings_text, encoding="utf-8")
print(f"Repositórios Gradle preservados/corrigidos: {settings}")
