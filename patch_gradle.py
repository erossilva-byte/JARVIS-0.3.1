"""Configura dependências Android verificadas do J.A.R.V.I.S. Nova."""
import re
import sys
from pathlib import Path

app_gradle = Path(sys.argv[1])
app_text = app_gradle.read_text(encoding="utf-8")
local_ai_coordinate = 'implementation "com.google.mediapipe:tasks-genai:0.10.24"'

# O detector de ativação é próprio (JarvisAtivacao + reconhecimento do Android): nenhum SDK de
# palavra de ativação entra no APK. A integração de IA local e o resto do código nativo miram Android 8.0+.
# MediaPipe 0.10.14 NÃO suporta Gemma 3: o runtime antigo aborta o processo ao abrir o .task
# (SIGABRT nativo, impossível de capturar em Java). 0.10.24 suporta Gemma 3, mas o AAR é
# compilado para Java 21 (class file 65): exige JDK 21 + AGP 8.7 + Gradle 8.9 + compileSdk 35.
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
documentfile_dep = 'implementation "androidx.documentfile:documentfile:1.0.1"'


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
app_text, mudou = injetar_dependencia(app_text, documentfile_dep)
if mudou:
    print(f"Dependência androidx.documentfile adicionada: {app_gradle}")
else:
    print(f"Dependência androidx.documentfile já presente: {app_gradle}")
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

# ---------------------------------------------------------------------------
# Assinatura do APK
#
# debug: keystore fixo do repositório. Sem isso o CI gerava um keystore novo a
#        cada build e o Android recusava a atualização por cima do app instalado.
# release: credenciais vêm do ambiente (CI) ou de android/app/keystore.properties
#        (local, não versionado). Sem credenciais o release sai SEM assinatura e
#        o workflow falha de propósito: publicar um APK assinado com a chave de
#        debug é pior do que não publicar.
# ---------------------------------------------------------------------------


def _fim_bloco(texto, pos_chave):
    """Índice da '}' que fecha o bloco aberto em pos_chave (ou -1)."""
    nivel = 0
    for i in range(pos_chave, len(texto)):
        if texto[i] == "{":
            nivel += 1
        elif texto[i] == "}":
            nivel -= 1
            if nivel == 0:
                return i
    return -1


assinatura_topo = """// Assinatura de release: ambiente (CI) ou keystore.properties local (não versionado).
def jarvisAssinatura = [:]
def jarvisProps = file('keystore.properties')
if (jarvisProps.exists()) {
    def p = new Properties()
    jarvisProps.withInputStream { p.load(it) }
    jarvisAssinatura.storeFile = p.getProperty('storeFile')
    jarvisAssinatura.storePassword = p.getProperty('storePassword')
    jarvisAssinatura.keyAlias = p.getProperty('keyAlias')
    jarvisAssinatura.keyPassword = p.getProperty('keyPassword')
}
[['JARVIS_KEYSTORE_PATH', 'storeFile'], ['JARVIS_KEYSTORE_PASSWORD', 'storePassword'],
 ['JARVIS_KEY_ALIAS', 'keyAlias'], ['JARVIS_KEY_PASSWORD', 'keyPassword']].each { par ->
    def valor = System.getenv(par[0])
    if (valor) jarvisAssinatura[par[1]] = valor
}
def jarvisTemAssinatura = (jarvisAssinatura.storeFile && file(jarvisAssinatura.storeFile).exists() &&
    jarvisAssinatura.storePassword && jarvisAssinatura.keyAlias && jarvisAssinatura.keyPassword)
"""

assinatura_bloco = """    signingConfigs {
        debug {
            def ciKey = file('../../ci/debug.keystore')
            if (ciKey.exists()) {
                storeFile ciKey
                storePassword 'android'
                keyAlias 'androiddebugkey'
                keyPassword 'android'
            }
        }
        if (jarvisTemAssinatura) {
            release {
                storeFile file(jarvisAssinatura.storeFile)
                storePassword jarvisAssinatura.storePassword
                keyAlias jarvisAssinatura.keyAlias
                keyPassword jarvisAssinatura.keyPassword
            }
        }
    }
"""

if "jarvisTemAssinatura" not in app_text:
    ancora = re.search(r"(?m)^apply plugin:.*$", app_text)
    pos = ancora.end() if ancora else 0
    app_text = app_text[:pos] + "\n\n" + assinatura_topo + app_text[pos:]
    print(f"Variáveis de assinatura de release adicionadas: {app_gradle}")
else:
    print(f"Variáveis de assinatura de release já presentes: {app_gradle}")

existente = re.search(r"(?m)^[ \t]*signingConfigs\s*\{", app_text)
if existente:
    fim = _fim_bloco(app_text, existente.end() - 1)
    if fim < 0:
        raise SystemExit(f"Bloco signingConfigs incompleto em {app_gradle}")
    app_text = app_text[:existente.start()] + assinatura_bloco + app_text[fim + 1:]
    print(f"Bloco signingConfigs normalizado (debug + release): {app_gradle}")
else:
    android_block = re.search(r"(?m)^android\s*\{", app_text)
    if not android_block:
        raise SystemExit(f"Bloco android {{ não encontrado em {app_gradle}")
    app_text = app_text[:android_block.end()] + "\n" + assinatura_bloco + app_text[android_block.end():]
    print(f"Assinatura de debug fixada e release configurado: {app_gradle}")

# Liga o release à chave de assinatura apenas quando as credenciais existirem.
build_types = re.search(r"\bbuildTypes\s*\{", app_text)
if build_types:
    fim_bt = _fim_bloco(app_text, build_types.end() - 1)
    if fim_bt < 0:
        raise SystemExit(f"Bloco buildTypes incompleto em {app_gradle}")
    trecho = app_text[build_types.start():fim_bt + 1]
    release_type = re.search(r"\brelease\s*\{", trecho)
    if release_type and "signingConfig signingConfigs.release" not in trecho:
        fim_rel = _fim_bloco(trecho, release_type.end() - 1)
        if fim_rel < 0:
            raise SystemExit(f"Bloco release incompleto em {app_gradle}")
        linha = trecho.rfind("\n", 0, fim_rel) + 1
        trecho = (trecho[:linha]
                  + "            if (jarvisTemAssinatura) {\n"
                  + "                signingConfig signingConfigs.release\n"
                  + "            }\n"
                  + trecho[linha:])
        app_text = app_text[:build_types.start()] + trecho + app_text[fim_bt + 1:]
        print(f"Release ligado à chave de assinatura quando configurada: {app_gradle}")
else:
    # Templates mais antigos do Capacitor podem não trazer buildTypes; cria um release
    # mínimo para que a chave configurada realmente seja usada.
    android_block = re.search(r"(?m)^android\s*\{", app_text)
    if not android_block:
        raise SystemExit(f"Bloco android {{ não encontrado em {app_gradle}")
    fim_android = _fim_bloco(app_text, android_block.end() - 1)
    if fim_android < 0:
        raise SystemExit(f"Bloco android incompleto em {app_gradle}")
    bloco_release = """    buildTypes {
        release {
            if (jarvisTemAssinatura) {
                signingConfig signingConfigs.release
            }
        }
    }
"""
    app_text = app_text[:fim_android] + bloco_release + app_text[fim_android:]
    print(f"buildTypes criado com release assinável: {app_gradle}")

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


def alinhar_toolchain():
    """Gemma 3 só existe em tasks-genai >= 0.10.22, e esses AARs são Java 21 (class file 65).

    A cadeia antiga (AGP 8.2.1/Gradle 8.2.1/compileSdk 34) não lê esse bytecode e o Gradle 8.2
    nem inicia em JDK 21. O CI regenera android/ com `cap add`, então o ajuste precisa ser
    aplicado aqui, não apenas na pasta local.
    """
    raiz = app_gradle.parent.parent
    build = raiz / "build.gradle"
    if build.exists():
        t = build.read_text(encoding="utf-8")
        novo = re.sub(r"com\.android\.tools\.build:gradle:[0-9.]+", "com.android.tools.build:gradle:8.7.3", t)
        if novo != t:
            build.write_text(novo, encoding="utf-8")
            print(f"AGP atualizado para 8.7.3: {build}")
    variaveis = raiz / "variables.gradle"
    if variaveis.exists():
        t = variaveis.read_text(encoding="utf-8")
        novo = re.sub(r"(?m)^(\s*compileSdkVersion\s*=\s*)\d+", r"\g<1>35", t)
        novo = re.sub(r"(?m)^(\s*minSdkVersion\s*=\s*)\d+", r"\g<1>26", novo)
        novo = re.sub(r"(?m)^(\s*targetSdkVersion\s*=\s*)\d+", r"\g<1>34", novo)
        if novo != t:
            variaveis.write_text(novo, encoding="utf-8")
            print(f"SDKs atualizados (min 26, compile 35, target 34): {variaveis}")
    wrapper = raiz / "gradle/wrapper/gradle-wrapper.properties"
    if wrapper.exists():
        t = wrapper.read_text(encoding="utf-8")
        novo = re.sub(r"gradle-[0-9.]+-(?:all|bin)\.zip", "gradle-8.9-all.zip", t)
        if novo != t:
            wrapper.write_text(novo, encoding="utf-8")
            print(f"Gradle Wrapper atualizado para 8.9: {wrapper}")


alinhar_toolchain()
