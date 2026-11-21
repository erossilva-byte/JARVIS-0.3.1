#!/usr/bin/env python3
"""Prepara a integração da interface Flutter com o Android.

O runner Android é gerado pelo `flutter create` no CI; este script aplica, de forma
idempotente, o que o app precisa para aparecer no sistema:

- atalhos estáticos do ícone (falar, nova conversa, histórico);
- widget da tela inicial com estado e dois botões;
- recepção de texto compartilhado por outros apps;
- canal `com.jarvis.nova/sistema` no `MainActivity` (compartilhar e atualizar widget).

Uso: python3 tool/prepare_android_sistema.py android/app
"""
from __future__ import annotations

import shutil
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
ANDROID = RAIZ / "flutter_app" / "android"
PACOTE = "com.jarvis.nova"

ACOES = (
    "com.jarvis.nova.ACAO_VOZ",
    "com.jarvis.nova.ACAO_CONVERSA",
    "com.jarvis.nova.ACAO_HISTORICO",
)

# O runner gerado pelo Flutter declara INTERNET apenas no manifesto de debug.
# Sem estas permissões no manifesto principal, o APK de release não resolve DNS
# e a conversa falha com "Failed host lookup" mesmo com Wi-Fi/5G ativos.
PERMISSOES = (
    ("android.permission.INTERNET", ""),
    ("android.permission.ACCESS_NETWORK_STATE", ""),
    ("android.permission.CAMERA", ""),
    ("android.permission.READ_MEDIA_IMAGES", ""),
    ("android.permission.READ_MEDIA_VIDEO", ""),
    ("android.permission.READ_EXTERNAL_STORAGE", ' android:maxSdkVersion="32"'),
    ("android.permission.RECEIVE_BOOT_COMPLETED", ""),
    # Exceção documentada pelo Android para abrir apps a partir do segundo plano.
    ("android.permission.SYSTEM_ALERT_WINDOW", ""),
    # Biometria da tela de bloqueio; a digital antiga só existe até o Android 8.1.
    ("android.permission.USE_BIOMETRIC", ""),
    ("android.permission.USE_FINGERPRINT", ' android:maxSdkVersion="27"'),
    # Localização pedida na tela de status, sempre com ação explícita do usuário.
    ("android.permission.ACCESS_FINE_LOCATION", ""),
    ("android.permission.ACCESS_COARSE_LOCATION", ""),
    # Atualização OTA: sem esta permissão o Android não deixa o app pedir a
    # autorização de instalar APK e o instalador nunca abre.
    ("android.permission.REQUEST_INSTALL_PACKAGES", ""),
)

CAMERA_FEATURE = '    <uses-feature android:name="android.hardware.camera" android:required="false" />\n'

# Android 11 esconde TTS e os apps com ícone sem estas consultas explícitas.
TTS_QUERY = """    <queries>
        <intent>
            <action android:name="android.intent.action.TTS_SERVICE" />
        </intent>
        <intent>
            <action android:name="android.intent.action.MAIN" />
            <category android:name="android.intent.category.LAUNCHER" />
        </intent>
    </queries>
"""

NS = "{http://schemas.android.com/apk/res/android}"

ATALHOS_META = '            <meta-data android:name="android.app.shortcuts" android:resource="@xml/shortcuts" />\n'

FILTROS = """            <intent-filter>
                <action android:name="com.jarvis.nova.ACAO_VOZ" />
                <action android:name="com.jarvis.nova.ACAO_CONVERSA" />
                <action android:name="com.jarvis.nova.ACAO_HISTORICO" />
                <category android:name="android.intent.category.DEFAULT" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="text/plain" />
            </intent-filter>
"""

RECEPTOR_AGENDA = """        <receiver
            android:name=".JarvisAgendaReceiver"
            android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
            </intent-filter>
        </receiver>
"""

RECEPTOR = """        <receiver
            android:name=".JarvisWidgetProvider"
            android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/jarvis_widget_info" />
        </receiver>
"""

# FileProvider do atualizador: entrega ao instalador do Android só o APK da pasta
# privada `files/updates/`. Nada de armazenamento externo nem de permissão ampla.
PROVEDOR_ATUALIZACAO = """        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/jarvis_arquivos" />
        </provider>
"""


# --- Assinatura de release ---------------------------------------------------
# A chave de release vive FORA do repositório, em key.properties. Este bloco é
# aplicado sempre, de forma idempotente, porque o build.gradle.kts do runner
# Android nasce do `flutter create` e não entra no controle de versão.
MARCA_ASSINATURA = "JARVIS_KEY_PROPERTIES"

IMPORTS_ASSINATURA = """import java.io.FileInputStream
import java.util.Properties

"""

CABECALHO_ASSINATURA = """// Assinatura de release (ver docs/GUIA-ASSINATURA-RELEASE.md).
// Ordem de procura do key.properties: variável JARVIS_KEY_PROPERTIES,
// android/key.properties, ~/.jarvis/key.properties. As propriedades -P do
// Gradle (usadas pelo CI a partir dos secrets) completam o que faltar.
val chaveRelease: Properties = Properties().apply {
    val externo = System.getenv("JARVIS_KEY_PROPERTIES")
    val arquivo = when {
        !externo.isNullOrBlank() -> File(externo)
        rootProject.file("key.properties").isFile -> rootProject.file("key.properties")
        else -> File(System.getProperty("user.home") ?: ".", ".jarvis/key.properties")
    }
    if (arquivo.isFile) FileInputStream(arquivo).use { load(it) }
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword").forEach { nome ->
        val doGradle = project.findProperty(nome) as String?
        if (getProperty(nome).isNullOrBlank() && !doGradle.isNullOrBlank()) {
            setProperty(nome, doGradle)
        }
    }
}
val temChaveRelease = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .all { !chaveRelease.getProperty(it).isNullOrBlank() }
// Teste local consciente de APK sem chave: -PJARVIS_PERMITIR_DEBUG=true ou a
// variável de ambiente JARVIS_PERMITIR_DEBUG=true.
val permitirDebug = ((project.findProperty("JARVIS_PERMITIR_DEBUG") as String?)
    ?: System.getenv("JARVIS_PERMITIR_DEBUG"))?.toBoolean() ?: false
"""

BLOCO_CONFIG = """    signingConfigs {
        // Release assina com a chave do projeto, nunca com a de debug.
        create("release") {
            if (temChaveRelease) {
                storeFile = file(chaveRelease.getProperty("storeFile"))
                storePassword = chaveRelease.getProperty("storePassword")
                keyAlias = chaveRelease.getProperty("keyAlias")
                keyPassword = chaveRelease.getProperty("keyPassword")
            }
        }
    }
"""

BLOCO_RELEASE = """        release {
            signingConfig = if (temChaveRelease) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // Sem chave de release o build de release para: um APK assinado em
            // debug tem outra assinatura e não instala por cima do anterior.
            // Para um teste local consciente: -PJARVIS_PERMITIR_DEBUG=true.
            gradle.taskGraph.whenReady {
                if (!temChaveRelease && !permitirDebug &&
                    allTasks.any { it.name.contains("Release") }) {
                    throw GradleException(
                        "APK de release sem chave de assinatura. Crie key.properties " +
                        "com storeFile, storePassword, keyAlias e keyPassword " +
                        "(docs/GUIA-ASSINATURA-RELEASE.md) ou passe " +
                        "-PJARVIS_PERMITIR_DEBUG=true para um teste local."
                    )
                }
            }
        }"""

RELEASE_ANTIGO = """        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }"""

# Serviço de acessibilidade de escopo estreito (ajuste 095). Fica sem efeito
# enquanto o usuário não autoriza nas configurações do Android E liga o
# interruptor dentro do app. A configuração @xml/jarvis_acessibilidade diz o que
# ele pode ver: janela ativa, sem teclas e sem gestos.
SERVICO_ACESSIBILIDADE = """        <service
            android:name=".JarvisAcessibilidade"
            android:exported="true"
            android:label="JARVIS Nova — Ler a tela"
            android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">
            <intent-filter>
                <action android:name="android.accessibilityservice.AccessibilityService" />
            </intent-filter>
            <meta-data
                android:name="android.accessibilityservice"
                android:resource="@xml/jarvis_acessibilidade" />
        </service>
"""


def configurar_assinatura(app: Path) -> None:
    """Liga a chave de release ao build, sem guardar segredo no repositório."""
    build = app / "build.gradle.kts"
    if not build.is_file():
        falhar(f"build.gradle.kts ausente em {app}")
    texto = build.read_text(encoding="utf-8")
    if MARCA_ASSINATURA in texto:
        print("Assinatura de release já configurada.")
        return
    if "import java.util.Properties" not in texto:
        texto = IMPORTS_ASSINATURA + texto
    if "android {" not in texto:
        falhar("bloco android { não encontrado no build.gradle.kts")
    # O bloco plugins { } precisa continuar sendo o primeiro do arquivo.
    fim = texto.find("\n}", texto.find("plugins {"))
    if "plugins {" not in texto or fim < 0:
        falhar("bloco plugins { } não encontrado no build.gradle.kts")
    texto = texto[:fim + 2] + "\n" + CABECALHO_ASSINATURA + texto[fim + 2:]
    if "import java.util.Properties" not in texto:
        texto = IMPORTS_ASSINATURA + texto
    texto = texto.replace("android {", "android {\n" + BLOCO_CONFIG, 1)
    if RELEASE_ANTIGO not in texto:
        falhar("buildType release do runner Android mudou; revise a assinatura")
    texto = texto.replace(RELEASE_ANTIGO, BLOCO_RELEASE, 1)
    build.write_text(texto, encoding="utf-8")
    print("Assinatura de release configurada por key.properties.")


def falhar(mensagem: str) -> None:
    raise SystemExit(f"Integração com o sistema não aplicada: {mensagem}")


def copiar_recursos(app: Path) -> None:
    destino = app / "src" / "main" / "res"
    origem = ANDROID / "sistema" / "res"
    if not origem.is_dir():
        falhar(f"recursos ausentes em {origem}")
    for arquivo in sorted(origem.rglob("*")):
        if not arquivo.is_file():
            continue
        alvo = destino / arquivo.relative_to(origem)
        alvo.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(arquivo, alvo)


def copiar_codigo(app: Path) -> None:
    kotlin = app / "src" / "main" / "kotlin" / "com" / "jarvis" / "nova"
    kotlin.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ANDROID / "MainActivity.kt", kotlin / "MainActivity.kt")
    shutil.copy2(ANDROID / "JarvisWidgetProvider.kt", kotlin / "JarvisWidgetProvider.kt")
    shutil.copy2(ANDROID / "JarvisVoz.kt", kotlin / "JarvisVoz.kt")
    shutil.copy2(ANDROID / "JarvisComandos.kt", kotlin / "JarvisComandos.kt")
    shutil.copy2(ANDROID / "JarvisFundo.kt", kotlin / "JarvisFundo.kt")
    shutil.copy2(ANDROID / "JarvisFundoCanal.kt", kotlin / "JarvisFundoCanal.kt")
    shutil.copy2(ANDROID / "JarvisEscutaFundo.kt", kotlin / "JarvisEscutaFundo.kt")
    shutil.copy2(ANDROID / "JarvisBiometria.kt", kotlin / "JarvisBiometria.kt")
    shutil.copy2(ANDROID / "JarvisLocalizacao.kt", kotlin / "JarvisLocalizacao.kt")
    shutil.copy2(ANDROID / "JarvisAparelho.kt", kotlin / "JarvisAparelho.kt")
    shutil.copy2(ANDROID / "JarvisNotificacaoListener.kt",
                 kotlin / "JarvisNotificacaoListener.kt")
    shutil.copy2(ANDROID / "JarvisPonteIa.kt", kotlin / "JarvisPonteIa.kt")
    shutil.copy2(ANDROID / "JarvisSensores.kt", kotlin / "JarvisSensores.kt")
    shutil.copy2(ANDROID / "JarvisTimbre.kt", kotlin / "JarvisTimbre.kt")
    shutil.copy2(ANDROID / "JarvisAtualizacao.kt", kotlin / "JarvisAtualizacao.kt")
    shutil.copy2(ANDROID / "JarvisAcessibilidade.kt", kotlin / "JarvisAcessibilidade.kt")


def garantir_permissoes(texto: str) -> str:
    """Acrescenta permissões que o release não herda do manifesto de debug."""
    for permissao, extra in PERMISSOES:
        marcador = f'android:name="{permissao}"'
        if marcador in texto:
            continue
        linha = f'    <uses-permission android:name="{permissao}"{extra} />\n'
        if "<application" not in texto:
            falhar("manifesto sem <application>")
        texto = texto.replace("<application", linha + "    <application", 1)
    return texto


def ajustar_manifesto(app: Path) -> None:
    manifest_path = app / "src" / "main" / "AndroidManifest.xml"
    if not manifest_path.is_file():
        falhar(f"manifesto ausente em {manifest_path}")
    texto = manifest_path.read_text(encoding="utf-8")
    if "</activity>" not in texto:
        falhar("manifesto sem </activity>; o runner não é o esperado")

    texto = garantir_permissoes(texto)
    if "android.hardware.camera" not in texto:
        texto = texto.replace("<application", CAMERA_FEATURE + "    <application", 1)
    if "android.intent.action.TTS_SERVICE" not in texto:
        texto = texto.replace("<application", TTS_QUERY + "    <application", 1)

    if "com.jarvis.nova.ACAO_VOZ" not in texto:
        texto = texto.replace("</activity>", FILTROS + "        </activity>", 1)
    if "android.app.shortcuts" not in texto:
        texto = texto.replace("</activity>", ATALHOS_META + "        </activity>", 1)

    if ".JarvisAgendaReceiver" not in texto:
        if "</application>" not in texto:
            falhar("manifesto sem </application>")
        texto = texto.replace("</application>", RECEPTOR_AGENDA + "    </application>", 1)

    if ".JarvisWidgetProvider" not in texto:
        if "</application>" not in texto:
            falhar("manifesto sem </application>")
        texto = texto.replace("</application>", RECEPTOR + "    </application>", 1)

    if ".JarvisAcessibilidade" not in texto:
        if "</application>" not in texto:
            falhar("manifesto sem </application>")
        texto = texto.replace(
            "</application>", SERVICO_ACESSIBILIDADE + "    </application>", 1)

    if "fileprovider" not in texto:
        if "</application>" not in texto:
            falhar("manifesto sem </application>")
        texto = texto.replace(
            "</application>", PROVEDOR_ATUALIZACAO + "    </application>", 1)

    try:
        ET.fromstring(texto)
    except ET.ParseError as erro:
        falhar(f"manifesto inválido após a alteração: {erro}")
    manifest_path.write_text(texto, encoding="utf-8")


def verificar(app: Path) -> None:
    manifesto = ET.parse(app / "src" / "main" / "AndroidManifest.xml").getroot()
    atividades = [n for n in manifesto.iter("activity") if n.get(NS + "name") == ".MainActivity"]
    if not atividades:
        falhar("MainActivity não declarada no manifesto")
    atividade = atividades[0]
    acoes_manifesto = {a.get(NS + "name") for a in atividade.iter("action")}
    faltando = [acao for acao in ACOES if acao not in acoes_manifesto]
    if faltando:
        falhar("ações de atalho ausentes no manifesto: " + ", ".join(faltando))
    if "android.intent.action.SEND" not in acoes_manifesto:
        falhar("filtro de compartilhamento (ACTION_SEND) ausente")
    if not any(m.get(NS + "name") == "android.app.shortcuts" for m in atividade.iter("meta-data")):
        falhar("meta-data de atalhos ausente")
    receptores = [n for n in manifesto.iter("receiver") if n.get(NS + "name") == ".JarvisWidgetProvider"]
    if not receptores:
        falhar("receiver do widget ausente")

    permissoes = {n.get(NS + "name") for n in manifesto.iter("uses-permission")}
    for permissao, _ in PERMISSOES:
        if permissao not in permissoes:
            falhar(f"permissão ausente no manifesto principal: {permissao}")
    if not any(n.get(NS + "name") == "android.hardware.camera" for n in manifesto.iter("uses-feature")):
        falhar("declaração opcional da câmera ausente no manifesto")

    atalhos = ET.parse(app / "src" / "main" / "res" / "xml" / "shortcuts.xml").getroot()
    if len(atalhos.findall("shortcut")) != 3:
        falhar("shortcuts.xml precisa declarar três atalhos")
    info = ET.parse(app / "src" / "main" / "res" / "xml" / "jarvis_widget_info.xml").getroot()
    if info.get(NS + "initialLayout") != "@layout/jarvis_widget":
        falhar("widget sem layout inicial")
    if not (app / "src" / "main" / "res" / "layout" / "jarvis_widget.xml").is_file():
        falhar("layout do widget não copiado")

    kotlin = app / "src" / "main" / "kotlin" / "com" / "jarvis" / "nova"
    for nome in ("MainActivity.kt", "JarvisWidgetProvider.kt", "JarvisVoz.kt", "JarvisComandos.kt",
                 "JarvisFundo.kt", "JarvisFundoCanal.kt", "JarvisEscutaFundo.kt",
                 "JarvisBiometria.kt", "JarvisLocalizacao.kt", "JarvisAparelho.kt",
                 "JarvisNotificacaoListener.kt", "JarvisPonteIa.kt",
                 "JarvisSensores.kt", "JarvisTimbre.kt", "JarvisAtualizacao.kt",
                 "JarvisAcessibilidade.kt"):
        if not (kotlin / nome).is_file():
            falhar(f"{nome} não copiado")
    provedores = [n for n in manifesto.iter("provider")
                  if (n.get(NS + "authorities") or "").endswith(".fileprovider")]
    if not provedores:
        falhar("FileProvider do atualizador ausente no manifesto")
    if not any(m.get(NS + "resource") == "@xml/jarvis_arquivos"
               for m in provedores[0].iter("meta-data")):
        falhar("FileProvider sem o caminho do APK baixado (@xml/jarvis_arquivos)")
    if not (app / "src" / "main" / "res" / "xml" / "jarvis_arquivos.xml").is_file():
        falhar("jarvis_arquivos.xml não copiado")
    servicos_acessibilidade = [n for n in manifesto.iter("service")
                              if n.get(NS + "name") == ".JarvisAcessibilidade"]
    if not servicos_acessibilidade:
        falhar("serviço de acessibilidade não declarado no manifesto")
    servico_acessibilidade = servicos_acessibilidade[0]
    if servico_acessibilidade.get(NS + "permission") != "android.permission.BIND_ACCESSIBILITY_SERVICE":
        falhar("serviço de acessibilidade sem a permissão de vínculo do Android")
    if not any(m.get(NS + "resource") == "@xml/jarvis_acessibilidade"
               for m in servico_acessibilidade.iter("meta-data")):
        falhar("serviço de acessibilidade sem a configuração @xml/jarvis_acessibilidade")
    if not (app / "src" / "main" / "res" / "xml" / "jarvis_acessibilidade.xml").is_file():
        falhar("jarvis_acessibilidade.xml não copiado")
    if "android.permission.REQUEST_INSTALL_PACKAGES" not in permissoes:
        falhar("manifesto sem permissão de instalar APK")
    if not any(n.get(NS + "name") == "android.intent.action.TTS_SERVICE"
               for n in manifesto.iter("action")):
        falhar("consulta de síntese de voz (TTS_SERVICE) ausente no manifesto")
    texto = (kotlin / "MainActivity.kt").read_text(encoding="utf-8")
    if '"com.jarvis.nova/sistema"' not in texto:
        falhar("MainActivity sem canal do sistema")
    if "JarvisAtualizacao(this)" not in texto:
        falhar("MainActivity sem registrar o canal de atualização")
    atualizacao = (kotlin / "JarvisAtualizacao.kt").read_text(encoding="utf-8")
    if '"com.jarvis.nova/atualizacao"' not in atualizacao:
        falhar("JarvisAtualizacao.kt sem o canal de atualização")
    if ".fileprovider" not in atualizacao:
        falhar("JarvisAtualizacao.kt sem a autoridade do FileProvider")
    gradle = (app / "build.gradle.kts").read_text(encoding="utf-8")
    if MARCA_ASSINATURA not in gradle or "JARVIS_PERMITIR_DEBUG" not in gradle:
        falhar("build.gradle.kts sem a assinatura de release por key.properties")
    provedor = (kotlin / "JarvisWidgetProvider.kt").read_text(encoding="utf-8")
    if "R.layout.jarvis_widget" not in provedor:
        falhar("widget provider não usa o layout copiado")


def main() -> int:
    if len(sys.argv) != 2:
        print("uso: prepare_android_sistema.py android/app", file=sys.stderr)
        return 2
    app = Path(sys.argv[1]).resolve()
    if not app.is_dir():
        falhar(f"diretório do app inexistente: {app}")
    copiar_recursos(app)
    copiar_codigo(app)
    ajustar_manifesto(app)
    configurar_assinatura(app)
    verificar(app)
    print("Integração Android preparada: atalhos, widget, compartilhamento e canal do sistema.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
