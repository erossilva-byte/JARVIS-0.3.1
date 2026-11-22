"""Revisa o workflow Flutter: a ordem das etapas e a checagem do conteúdo do APK.

O CI é o único lugar onde o APK é compilado. Este teste garante que o workflow continua
preparando atalhos, widget e compartilhamento antes de compilar e que falha quando o pacote
sai sem essas peças — inclusive com casos negativos, para provar que a regra reprova.
"""
from __future__ import annotations

import io
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
WORKFLOW = RAIZ / ".github" / "workflows" / "flutter-native.yml"

MARCADORES = (
    "flutter create --project-name jarvis_nova --platforms=android,windows .",
    "Set the production Android application identity",
    "tool/prepare_android_kws.py android/app",
    "tool/prepare_android_sistema.py android/app",
    "../tests/test_sistema_android.py",
    "flutter pub get",
    "flutter analyze",
    "flutter test",
    "flutter build apk --debug",
    "Verify the APK carries shortcuts, widget and share target",
    "Publish debug APK artifact",
)


def problemas(texto: str) -> list[str]:
    android = texto.split("\n  flutter-windows:")[0]
    achados: list[str] = []

    posicoes: list[int] = []
    for marcador in MARCADORES:
        posicao = android.find(marcador)
        if posicao < 0:
            achados.append(f"etapa ausente no workflow: {marcador}")
        posicoes.append(posicao)
    if achados:
        return achados
    if posicoes != sorted(posicoes):
        achados.append("etapas fora de ordem: preparar antes de compilar e conferir depois")

    sistema = android[android.find("tool/prepare_android_sistema.py"):]
    if "working-directory: flutter_app" not in sistema:
        achados.append("preparação do sistema sem working-directory flutter_app")

    verificacao = android[android.find("Verify the APK carries"):android.find("Verify APK identity")]
    for marca in ("shortcuts.xml", "jarvis_widget_info.xml", "jarvis_widget.xml",
                  "JarvisWidgetProvider", "android.app.shortcuts", "ACAO_VOZ",
                  "android.intent.action.SEND", "com.jarvis.nova/sistema", "com.jarvis.nova/memoria"):
        if marca not in verificacao:
            achados.append(f"checagem do APK não confere: {marca}")
    if "exit 1" not in verificacao:
        achados.append("checagem do APK não reprova quando falta alguma peça")
    if "aapt2" not in verificacao or "strings" not in verificacao:
        achados.append("checagem do APK sem aapt2 nem alternativa por strings")
    if "if: runner.os == 'Linux'" not in verificacao:
        achados.append("checagem do APK deveria rodar no job Android")

    publicacao = android[android.find("Publish debug APK artifact"):]
    if "build/app/outputs/flutter-apk/app-debug.apk" not in publicacao:
        achados.append("artefato publicado não é o APK debug")
    if "if-no-files-found: error" not in publicacao:
        achados.append("publicação sem falha explícita quando o APK não existe")
    return achados


def test_workflow_atual() -> None:
    texto = io.open(WORKFLOW, encoding="utf-8").read()
    achados = problemas(texto)
    assert not achados, "\n".join(achados)


def test_calibracao() -> None:
    base = io.open(WORKFLOW, encoding="utf-8").read()
    mutacoes = {
        "sem preparação do sistema": base.replace("tool/prepare_android_sistema.py", "tool/outro.py"),
        "sem checagem do APK": base.replace("Verify the APK carries shortcuts, widget and share target", "Checar"),
        "sem atalhos na checagem": base.replace("res/xml/shortcuts.xml", "res/xml/outro.xml"),
        "sem falha explícita": base.replace("if-no-files-found: error", "if-no-files-found: warn"),
        "compilar antes de preparar": base.replace(
            "tool/prepare_android_sistema.py android/app",
            "tool/prepare_android_sistema.py android/app\n# mover",
        ),
    }
    for nome, texto in mutacoes.items():
        if nome == "compilar antes de preparar":
            # Troca a ordem: compila antes de preparar o sistema.
            antes = texto.find("flutter build apk --debug")
            prep = texto.find("tool/prepare_android_sistema.py android/app")
            texto = texto[:prep] + "# preparo depois\n" + texto[prep:]
            texto = texto.replace("flutter build apk --debug", "# build adiado")
            texto = texto.replace("# preparo depois\n", "flutter build apk --debug\n", 1)
        assert problemas(texto), f"calibração falhou: {nome} passou sem ser detectado"


def main() -> int:
    test_workflow_atual()
    print("ok — workflow prepara e confere o APK na ordem certa")
    test_calibracao()
    print("ok — calibração: cinco defeitos diferentes são detectados")
    print("OK: workflow Flutter — integração Android compilada, conferida e publicada")
    return 0


if __name__ == "__main__":
    sys.exit(main())
