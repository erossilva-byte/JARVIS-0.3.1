"""Confere por leitura estática os comandos Android de baixo risco.

O interpretador puro é testado em Dart; aqui se prova o contrato de segurança: canal fechado,
ações nomeadas, confirmação do estado, nenhuma permissão proibida e nenhuma intent arbitrária.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
CORE = RAIZ / "flutter_app" / "lib" / "core" / "comandos_android.dart"
SERVICO = RAIZ / "flutter_app" / "lib" / "services" / "comandos_android_service.dart"
PAGINA = RAIZ / "flutter_app" / "lib" / "services" / "comandos_android_page.dart"
CONVERSA = RAIZ / "flutter_app" / "lib" / "services" / "voice_conversation_page.dart"
NATIVO = RAIZ / "flutter_app" / "android" / "JarvisComandos.kt"
MAIN = RAIZ / "flutter_app" / "android" / "MainActivity.kt"
PREPARO = RAIZ / "flutter_app" / "tool" / "prepare_android_sistema.py"
PACKAGE = RAIZ / "package.json"


def problemas() -> list[str]:
    falhas: list[str] = []
    for caminho in (CORE, SERVICO, PAGINA, CONVERSA, NATIVO, MAIN, PREPARO, PACKAGE):
        if not caminho.is_file():
            return [f"{caminho.name} não encontrado"]

    core = CORE.read_text(encoding="utf-8")
    servico = SERVICO.read_text(encoding="utf-8")
    pagina = PAGINA.read_text(encoding="utf-8")
    conversa = CONVERSA.read_text(encoding="utf-8")
    nativo = NATIVO.read_text(encoding="utf-8")
    main = MAIN.read_text(encoding="utf-8")
    preparo = PREPARO.read_text(encoding="utf-8")
    package = json.loads(PACKAGE.read_text(encoding="utf-8"))

    # 1. Registro fechado, com risco e permissão para cada ação.
    for termo in ("AcaoAndroid", "RiscoComando", "acoesAndroid", "permissao"):
        if termo not in core:
            falhas.append(f"registro sem {termo}")
    for acao in ("lanterna", "volume", "abrir_app", "alarme"):
        if f"nome: '{acao}'" not in core:
            falhas.append(f"ação ausente do registro: {acao}")

    # 2. Interpretador local, sem provedor, e sem capturar perguntas.
    for termo in ("InterpretadorComandos", "ComandoLanterna", "ComandoVolume",
                  "ComandoAbrirApp", "ComandoAlarme"):
        if termo not in core:
            falhas.append(f"interpretador sem {termo}")
    if "como " not in core or "por que" not in core:
        falhas.append("interpretador pode capturar perguntas")

    # 3. Execução por canal nomeado e recusa sem a ponte Android.
    if "com.jarvis.nova/comandos" not in servico or "invokeMapMethod" not in servico:
        falhas.append("serviço não usa o canal nativo")
    if "MissingPluginException" not in servico:
        falhas.append("serviço não trata ausência da ponte Android")
    if "com.jarvis.nova/comandos" not in nativo:
        falhas.append("canal nativo ausente")

    # 4. Verificação pós-execução e nenhuma intent arbitrária.
    for termo in ("setTorchMode", "onTorchModeChanged", "getStreamVolume",
                  "setStreamVolume", "queryIntentActivities", "AlarmClock.ACTION_SET_ALARM"):
        if termo not in nativo:
            falhas.append(f"execução nativa sem {termo}")
    for proibido in ("Runtime.getRuntime", "ProcessBuilder", "su ", "adb ", "Shizuku"):
        if proibido in nativo or proibido in servico:
            falhas.append(f"caminho proibido encontrado: {proibido}")
    if "ACTION_SET_ALARM" in nativo and "EXTRA_SKIP_UI, false" not in nativo:
        falhas.append("alarme pode ser criado sem confirmação")

    # 5. Nenhuma permissão proibida ou ampla.
    for proibido in ("MANAGE_EXTERNAL_STORAGE", "BIND_ACCESSIBILITY_SERVICE",
                     "SEND_SMS", "CALL_PHONE", "WRITE_SETTINGS"):
        if proibido in nativo or proibido in preparo:
            falhas.append(f"permissão proibida nesta etapa: {proibido}")

    # 6. Interface e conversa por texto/voz.
    for termo in ("ComandosAndroidPage", "comando-android-campo", "REGISTRO DE AÇÕES"):
        if termo not in pagina:
            falhas.append(f"tela sem {termo}")
    for termo in ("_comandos.executar", "_concluirComando", "_sequenciaComandos"):
        if termo not in conversa:
            falhas.append(f"conversa sem {termo}")
    if "JarvisComandos" not in main:
        falhas.append("MainActivity não registra o executor")
    if "JarvisComandos.kt" not in preparo:
        falhas.append("preparo Android não copia o executor")

    # 7. Testes na suíte.
    if "tests/test_comandos_android.py" not in package["scripts"]["test:all"]:
        falhas.append("teste estático fora da suíte")
    if "comandos_android_test.dart" not in (RAIZ / "tests" / "test_dart_core.py").read_text(encoding="utf-8"):
        falhas.append("teste puro fora do núcleo Dart")

    return falhas


def main() -> int:
    falhas = problemas()
    if falhas:
        for falha in falhas:
            print(f"FALHOU: {falha}")
        print(f"Comandos Android: {len(falhas)} problema(s).")
        return 1
    print("OK: comandos Android — registro, execução local, confirmação e sem permissões proibidas")
    return 0


if __name__ == "__main__":
    sys.exit(main())
