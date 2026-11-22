"""Confere por leitura estática os arquivos de texto da interface Flutter.

A fase pedia arquivos e sandbox. O recorte entregue é arquivo de texto confinado à pasta privada do
app; execução de código não existe e não é anunciada. Este teste trava as duas coisas: as proteções
de caminho e a ausência de promessa de sandbox.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
CORE = RAIZ / "flutter_app" / "lib" / "core" / "arquivos.dart"
SANDBOX = RAIZ / "flutter_app" / "lib" / "services" / "arquivo_sandbox.dart"
PAGINA = RAIZ / "flutter_app" / "lib" / "services" / "arquivos_page.dart"
HOME = RAIZ / "flutter_app" / "lib" / "home_screen.dart"
PUBSPEC = RAIZ / "flutter_app" / "pubspec.yaml"
CATALOGO = RAIZ / "flutter_app" / "lib" / "catalog.dart"
PAGES = RAIZ / "flutter_app" / "lib" / "pages.dart"
DRAWER = RAIZ / "flutter_app" / "lib" / "drawer.dart"


def problemas() -> list[str]:
    falhas: list[str] = []
    for caminho in (CORE, SANDBOX, PAGINA, HOME, PUBSPEC):
        if not caminho.is_file():
            return [f"{caminho.name} não encontrado"]

    core = CORE.read_text(encoding="utf-8")
    sandbox = SANDBOX.read_text(encoding="utf-8")
    pagina = PAGINA.read_text(encoding="utf-8")
    home = HOME.read_text(encoding="utf-8")
    pubspec = PUBSPEC.read_text(encoding="utf-8")

    # 1. Nome e caminho são validados no núcleo.
    for termo in ("validarNomeArquivo", "caminhoSeguroNaPasta", "limiteBytesArquivo", "limiteArquivos"):
        if termo not in core:
            falhas.append(f"proteção ausente no núcleo: {termo}")
    if "512 * 1024" not in core:
        falhas.append("limite de 512 kB ausente")
    for proibido in ("../", "..\\\\", "RegExp"):
        if proibido not in core and proibido == "RegExp":
            falhas.append("núcleo sem validação por expressão regular")

    # 2. O sandbox só toca a própria pasta, não executa processo e não acessa rede.
    if "caminhoSeguroNaPasta" not in sandbox:
        falhas.append("sandbox não confina o caminho")
    for proibido in ("Process.run", "Process.start", "HttpClient", "package:http", "Socket"):
        if proibido in sandbox:
            falhas.append(f"sandbox não deveria usar {proibido}")
    if "followLinks: false" not in sandbox:
        falhas.append("listagem segue links simbólicos")

    # 3. A tela declara o recorte e não promete execução.
    if "Sem acesso a Downloads" not in pagina:
        falhas.append("tela não declara que não abre pasta externa")
    if "Execução de código não existe" not in pagina:
        falhas.append("tela não declara ausência de sandbox de código")
    if "nada é enviado para a rede" not in pagina:
        falhas.append("tela não declara que nada vai para a rede")
    for proibido in ("Process.run", "package:http", "HttpClient"):
        if proibido in pagina:
            falhas.append(f"tela de arquivos usa {proibido}")

    # 4. Menu abre a tela real.
    if "name == 'Arquivos'" not in home or "ArquivosPage" not in home:
        falhas.append("menu de Arquivos não abre a tela real")

    # 5. Dependências declaradas e testes registrados.
    for dependencia in ("path_provider:", "path:"):
        if dependencia not in pubspec:
            falhas.append(f"dependência ausente: {dependencia}")
    package = json.loads((RAIZ / "package.json").read_text(encoding="utf-8"))
    if "tests/test_arquivos_flutter.py" not in package["scripts"]["test:all"]:
        falhas.append("teste estático de arquivos fora da suíte")
    if "arquivos_test.dart" not in (RAIZ / "tests" / "test_dart_core.py").read_text(encoding="utf-8"):
        falhas.append("teste puro de arquivos fora do núcleo Dart")

    # 6. Nem o catálogo nem a tela prometem execução isolada.
    catalogo = CATALOGO.read_text(encoding="utf-8")
    pages = PAGES.read_text(encoding="utf-8")
    drawer = DRAWER.read_text(encoding="utf-8")
    if "Assistência de código e execução isolada" in catalogo:
        falhas.append("catálogo ainda promete execução isolada")
    if "sandbox e execução não disponíveis" not in catalogo:
        falhas.append("catálogo não declara a ausência de execução")
    # 099: o aviso genérico virou catálogo de estado por módulo; pages.dart
    # renderiza o texto que hoje mora em core/estado_modulos.dart.
    estado = (RAIZ / "flutter_app" / "lib" / "core" /
              "estado_modulos.dart").read_text(encoding="utf-8")
    tela_modulo = pages + estado
    if "Execução de código não disponível" not in tela_modulo:
        falhas.append("tela do módulo não declara a ausência de execução")
    if "Não há sandbox, terminal" not in tela_modulo:
        falhas.append("tela do módulo não explica a ausência")
    if "Código sem execução" not in drawer:
        falhas.append("gaveta ainda rotula o módulo como sandbox")

    return falhas


def main() -> int:
    falhas = problemas()
    if falhas:
        for falha in falhas:
            print(f"FALHOU: {falha}")
        print(f"Arquivos Flutter: {len(falhas)} problema(s).")
        return 1
    print("OK: arquivos — pasta isolada, caminho confinado, sem rede e sem promessa de sandbox de código")
    return 0


if __name__ == "__main__":
    sys.exit(main())
