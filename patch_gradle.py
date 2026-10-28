"""Configura dependências Android verificadas do J.A.R.V.I.S. Nova."""
import re
import sys
from pathlib import Path

app_gradle = Path(sys.argv[1])
app_text = app_gradle.read_text(encoding="utf-8")
local_ai_coordinate = 'implementation "com.google.mediapipe:tasks-genai:0.10.14"'

# O detector de ativação é próprio (JarvisAtivacao + reconhecimento do Android): nenhum SDK de
# palavra de ativação entra no APK. A integração de IA local e o resto do código nativo miram Android 8.0+.
# MediaPipe 0.10.14 é fixado por compatibilidade com Java 17/Gradle 8.2; artefatos mais novos podem
# exigir bytecode/runtime mais recentes.
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

sherpa_aar_dep = "implementation files('libs/sherpa-onnx-1.13.8.aar')"
commons_dep = "implementation 'org.apache.commons:commons-compress:1.26.2'"
biometric_dep = 'implementation "androidx.biometric:biometric:1.1.0"'


def injetar_dependencia(texto, linha):
    """Acrescenta uma dependência no fim do bloco dependencies."""
    if linha in texto:
        return texto, False
    achado = re.search(r"\bdependencies\s*\{", texto)
    if not achado:
        raise SystemExit("Bloco dependencies não encontrado no build.gradle")
    nivel = 0
    fim = None
    for i in range(achado.end() - 1, len(texto)):
        if texto[i] == "{":
            nivel += 1
        elif texto[i] == "}":
            nivel -= 1
            if nivel == 0:
                fim = i
                break
    if fim is None:
        raise SystemExit("Bloco dependencies incompleto no build.gradle")
    return texto[:fim] + "    " + linha + "\n" + texto[fim:], True


# Voz neural offline: o AAR traz o sherpa-onnx e o ONNX Runtime já compilados
# (baixado por baixar_sherpa.py); o commons-compress lê os pacotes .tar.bz2 das vozes.
app_text, mudou = injetar_dependencia(app_text, sherpa_aar_dep)
if mudou:
    print(f"Dependência de voz neural adicionada: {app_gradle}")
else:
    print(f"Dependência de voz neural já presente: {app_gradle}")
app_text, mudou = injetar_dependencia(app_text, commons_dep)
if mudou:
    print(f"Dependência commons-compress adicionada: {app_gradle}")
else:
    print(f"Dependência commons-compress já presente: {app_gradle}")
# Biometria do bloqueio opcional do app (BiometricPrompt com credencial do aparelho).
app_text, mudou = injetar_dependencia(app_text, biometric_dep)
if mudou:
    print(f"Dependência androidx.biometric adicionada: {app_gradle}")
else:
    print(f"Dependência androidx.biometric já presente: {app_gradle}")

# Só ARM: as bibliotecas nativas somam ~53 MB e nenhum aparelho x86 roda este APK.
# Sem o filtro, o pacote carregaria também as ABIs de emulador sem uso.
if "abiFilters" not in app_text:
    achado = re.search(r"\bdefaultConfig\s*\{", app_text)
    if not achado:
        raise SystemExit("Bloco defaultConfig não encontrado no build.gradle")
    nivel = 0
    fim = None
    for i in range(achado.end() - 1, len(app_text)):
        if app_text[i] == "{":
            nivel += 1
        elif app_text[i] == "}":
            nivel -= 1
            if nivel == 0:
                fim = i
                break
    if fim is None:
        raise SystemExit("Bloco defaultConfig incompleto no build.gradle")
    ndk = """        ndk {
            abiFilters 'arm64-v8a', 'armeabi-v7a'
        }
"""
    app_text = app_text[:fim] + ndk + app_text[fim:]
    print(f"ABIs ARM fixadas (arm64-v8a, armeabi-v7a): {app_gradle}")
else:
    print(f"ABIs já fixadas: {app_gradle}")

# Fixa a assinatura de debug no keystore do repositório.
# Sem isso o CI gerava um keystore novo a cada build (o cp para ~/.android não era o
# que o Gradle usava em todos os casos) e cada release saía com uma assinatura
# diferente — o Android recusava a atualização por cima do app instalado.
signing_block = """    signingConfigs {
        debug {
            def ciKey = file('../../ci/debug.keystore')
            if (ciKey.exists()) {
                storeFile ciKey
                storePassword 'android'
                keyAlias 'androiddebugkey'
                keyPassword 'android'
            }
        }
    }
"""
if "ci/debug.keystore" not in app_text:
    android_block = re.search(r"(?m)^android\s*\{", app_text)
    if not android_block:
        raise SystemExit(f"Bloco android {{ não encontrado em {app_gradle}")
    app_text = app_text[:android_block.end()] + "\n" + signing_block + app_text[android_block.end():]
    print(f"Assinatura de debug fixada em ci/debug.keystore: {app_gradle}")
else:
    print(f"Assinatura de debug já fixada: {app_gradle}")

# Persist both the SDK-floor adjustment and dependency changes on every run.
app_gradle.write_text(app_text, encoding="utf-8")

settings = app_gradle.parent.parent / "settings.gradle"
if not settings.exists():
    settings = app_gradle.parent.parent / "settings.gradle.kts"
if not settings.exists():
    raise SystemExit(f"Não encontrei settings.gradle(.kts) junto de {app_gradle}")
settings_text = settings.read_text(encoding="utf-8")
# MediaPipe e o AAR do sherpa-onnx vêm do Maven Central/Google Maven. Do not add
# JitPack: a coordenada do detector de palavra de ativação de terceiro usado antes não resolvia no CI.
settings.write_text(settings_text, encoding="utf-8")
print(f"Repositórios Gradle preservados/corrigidos: {settings}")
