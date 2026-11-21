"""Confere por leitura estática o importador .cad somente leitura da interface Flutter.

O teste puro de Dart cobre a gramática e a ida e volta; aqui se prova o contrato da fase 10A:
escolher um arquivo pelo seletor do sistema, ler ISO-8859-1, mostrar inventário e geometria e não
oferecer edição, simulação, exportação nem envio do arquivo a provedor.
"""
from __future__ import annotations

import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
SERVICO = RAIZ / "flutter_app" / "lib" / "services" / "cadesimu_cad.dart"
PAGINA = RAIZ / "flutter_app" / "lib" / "services" / "cadesimu_page.dart"
PAGES = RAIZ / "flutter_app" / "lib" / "pages.dart"
MAIN = RAIZ / "flutter_app" / "android" / "MainActivity.kt"
TESTE = RAIZ / "flutter_app" / "test" / "cadesimu_cad_test.dart"
TESTE_PAGINA = RAIZ / "flutter_app" / "test" / "cadesimu_page_test.dart"


def problemas() -> list[str]:
    falhas: list[str] = []
    for caminho in (SERVICO, PAGINA, PAGES, MAIN, TESTE, TESTE_PAGINA):
        if not caminho.is_file():
            return [f"{caminho.name} não encontrado"]

    servico = SERVICO.read_text(encoding="utf-8")
    pagina = PAGINA.read_text(encoding="utf-8")
    pages = PAGES.read_text(encoding="utf-8")
    main = MAIN.read_text(encoding="utf-8")

    # 1. Gramática mínima e preservação byte a byte.
    for termo in ("CADe_SIMU", "#$$$", "DocumentoCad", "escrever()", "redesGeometricas"):
        if termo not in servico:
            falhas.append(f"leitor sem {termo}")
    if "String.fromCharCodes" not in servico:
        falhas.append("bytes Latin-1 não são decodificados")
    if "analisarArquivoCad" not in servico:
        falhas.append("confirmação de ida e volta ausente")

    # 2. Somente leitura: nada de edição, simulação ou exportação.
    for proibido in ("exportar", "salvarCad", "writeAsBytes", "writeAsString", "simular"):
        if proibido in servico or proibido in pagina:
            falhas.append(f"caminho de escrita/simulação encontrado: {proibido}")
    for termo in ("Somente leitura", "não edita, não simula", "não gera netlist"):
        if termo not in pagina:
            falhas.append(f"aviso de somente leitura ausente: {termo}")

    # 3. Seleção pelo sistema, sem permissão ampla e com limite de tamanho.
    for termo in ("abrirCad", "ACTION_OPEN_DOCUMENT", "EXTRA_MIME_TYPES", "limiteCadBytes"):
        if termo not in main:
            falhas.append(f"seletor Android sem {termo}")
    for proibido in ("READ_EXTERNAL_STORAGE", "MANAGE_EXTERNAL_STORAGE"):
        if proibido in main:
            falhas.append(f"permissão ampla de armazenamento: {proibido}")
    if "2 * 1024 * 1024" not in main:
        falhas.append("limite de 2 MB não declarado no Android")

    # 4. Inventário e geometria visíveis, sem prometer netlist.
    for termo in ("SÍMBOLOS", "FIOS", "JUNÇÕES", "GEOMETRIA", "TEXTOS DO DESENHO"):
        if termo not in pagina:
            falhas.append(f"inventário sem {termo}")
    if "CustomPaint" not in pagina:
        falhas.append("geometria sem desenho")
    if "netlist" not in pagina:
        falhas.append("tela não declara que não gera netlist")

    # 5. Entrada real no catálogo.
    if "CadesimuPage" not in pages or "abrir-importador-cad" not in pages:
        falhas.append("catálogo não abre o importador")

    return falhas


def main() -> int:
    falhas = problemas()
    if falhas:
        for falha in falhas:
            print(f"FALHOU: {falha}")
        print(f"CADeSIMU Flutter: {len(falhas)} problema(s).")
        return 1
    print("OK: CADeSIMU — leitura ISO-8859-1, inventário/geometria e nenhuma edição ou simulação")
    return 0


if __name__ == "__main__":
    sys.exit(main())
