"""Pré-checagem da interface Flutter antes de compilar (Fase 5, Seção 3D).

O prompt mestre proíbe tela web: nada de WebView, HTML embutido, PWA ou Electron na
interface. Também exige navegação com as seções da Fase 5, modo de animação reduzida e
isolamento do núcleo animado com `RepaintBoundary`.

Este script verifica o que é estrutural e mecanico no código Dart:

- nenhum pacote de webview nem HTML no `pubspec.yaml`;
- nenhum uso de WebView, `dart:html`, `IFrameElement` ou `loadUrl(` no `lib/`;
- a gaveta oferece as doze seções pedidas;
- a tela principal respeita `MediaQuery.disableAnimations`;
- a central de comando isola o núcleo animado com `RepaintBoundary`.

Ele não compila nem mede quadros: `flutter analyze`, fps e jank continuam dependendo do CI e
do aparelho. A interface legada em WebView (Capacitor) é o objeto que a Fase 5 substitui; a
regra vale para o app Flutter, que é a interface nova.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"

# Seções exigidas pela Fase 5 do prompt mestre. Cada uma aceita os rótulos que a gaveta usa
# hoje; o nome pedido é o conceito, não a etiqueta.
SECOES = (
    ("IA", ("'IA'", "'IA Core'")),
    ("Voz", ("'Voz'",)),
    ("Memória", ("'Memória'",)),
    ("Visão", ("'Visão'",)),
    ("Pessoas", ("'Pessoas'",)),
    ("Arquivos", ("'Arquivos'",)),
    ("CADeSIMU", ("'CADeSIMU'",)),
    ("Tarefas", ("'Tarefas'",)),
    ("Celular", ("'Celular'",)),
    ("Segurança", ("'Segurança'",)),
    ("Personalização", ("'Personalização'",)),
    ("Configurações", ("'Configurações'",)),
)

PACOTES_PROIBIDOS = (
    "webview_flutter",
    "flutter_inappwebview",
    "flutter_webview_plugin",
    "webviewx",
    "flutter_html",
)

# Padrões que denunciam tela web dentro do app nativo.
USOS_PROIBIDOS = (
    (re.compile(r"\bWebView\b"), "WebView"),
    (re.compile(r"\bWebViewController\b"), "WebViewController"),
    (re.compile(r"\bInAppWebView\b"), "InAppWebView"),
    (re.compile(r"\bloadUrl\s*\("), "loadUrl("),
    (re.compile(r"\bIFrameElement\b"), "IFrameElement"),
    (re.compile(r"\bplatformViewRegistry\b"), "platformViewRegistry"),
    (re.compile(r"\bHtml\s*\("), "Html("),
    (re.compile(r"dart:html"), "dart:html"),
)


def arquivos_dart(raiz: Path) -> list[Path]:
    return sorted((raiz / "flutter_app" / "lib").rglob("*.dart"))


def verificar(raiz: Path = RAIZ) -> list[str]:
    """Devolve a lista de problemas; vazia significa interface consistente."""
    problemas: list[str] = []
    app = raiz / "flutter_app"
    pubspec = app / "pubspec.yaml"
    if not pubspec.is_file():
        return ["flutter_app/pubspec.yaml não encontrado"]
    texto_pubspec = pubspec.read_text(encoding="utf-8")
    for pacote in PACOTES_PROIBIDOS:
        if re.search(rf"^\s*{re.escape(pacote)}\s*:", texto_pubspec, re.M):
            problemas.append(f"pubspec.yaml declara {pacote}, proibido pela Seção 3D")

    dart = arquivos_dart(raiz)
    if not dart:
        return problemas + ["nenhum arquivo Dart encontrado em flutter_app/lib"]
    for arquivo in dart:
        texto = arquivo.read_text(encoding="utf-8")
        for padrao, rotulo in USOS_PROIBIDOS:
            if padrao.search(texto):
                problemas.append(f"{arquivo.relative_to(raiz)} usa {rotulo} (interface web proibida)")

    gaveta = app / "lib" / "drawer.dart"
    if not gaveta.is_file():
        problemas.append("flutter_app/lib/drawer.dart não encontrado")
    else:
        texto_gaveta = gaveta.read_text(encoding="utf-8")
        for secao, rotulos in SECOES:
            if not any(rotulo in texto_gaveta for rotulo in rotulos):
                problemas.append(f"a gaveta não oferece a seção {secao}")

    principal = app / "lib" / "home_screen.dart"
    texto_principal = principal.read_text(encoding="utf-8") if principal.is_file() else ""
    if "disableAnimations" not in texto_principal:
        problemas.append("home_screen.dart não respeita a preferência de animação reduzida")

    centro = app / "lib" / "command_center.dart"
    texto_centro = centro.read_text(encoding="utf-8") if centro.is_file() else ""
    if "RepaintBoundary" not in texto_centro:
        problemas.append("command_center.dart não isola o núcleo animado com RepaintBoundary")

    return problemas


def main() -> int:
    problemas = verificar()
    if problemas:
        for problema in problemas:
            print(f"FALHA: {problema}")
        print(f"\nPré-checagem da interface: {len(problemas)} problema(s).")
        return 1
    total = len(arquivos_dart(RAIZ))
    print(
        f"Pré-checagem da interface: {total} arquivo(s) Dart, {len(SECOES)} seções, "
        "sem WebView e com animação reduzida — tudo consistente."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
