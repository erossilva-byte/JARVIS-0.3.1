"""Confere por leitura estática o simulador de circuitos do app Flutter.

O cálculo é provado em Dart (`tool/circuito_test.dart`) e a tela em
`test/circuito_page_test.dart`. Aqui se prova o contrato: o motor é Dart puro e
offline, a tela é nativa (sem WebView), os limites estão escritos no app e o
teste está na suíte.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"
CORE = APP / "lib" / "core" / "circuito.dart"
PAGINA = APP / "lib" / "services" / "circuito_page.dart"
PAGES = APP / "lib" / "pages.dart"
CAD = APP / "lib" / "services" / "cadesimu_page.dart"
TESTE_PURO = APP / "tool" / "circuito_test.dart"
TESTE_TELA = APP / "test" / "circuito_page_test.dart"
DART_CORE = RAIZ / "tests" / "test_dart_core.py"
PACKAGE = RAIZ / "package.json"
CHANGELOG = RAIZ / "CHANGELOG.md"
INVENTARIO = RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md"
RELATORIO = RAIZ / "docs" / "relatorios" / "2026-11-18_061-simulador-de-circuitos.md"
RELATORIO_SELO = RAIZ / "docs" / "relatorios" / "2026-11-18_062-botoeira-contator-e-selo.md"
RELATORIO_REVERSAO = RAIZ / "docs" / "relatorios" / "2026-11-18_063-intertravamento-e-reversao.md"
RELATORIO_MOTOR = RAIZ / "docs" / "relatorios" / "2026-11-18_064-contato-de-potencia-e-motor-dc.md"
RELATORIO_RELE = RAIZ / "docs" / "relatorios" / "2026-11-18_065-rele-de-sobrecarga.md"
RELATORIO_TEMPO = RAIZ / "docs" / "relatorios" / "2026-11-18_066-temporizador-com-retardo.md"
RELATORIO_TEMPO_NF = RAIZ / "docs" / "relatorios" / "2026-11-19_067-contato-nf-temporizado.md"
RELATORIO_QUEDA = RAIZ / "docs" / "relatorios" / "2026-11-19_068-retardo-na-queda.md"
RELATORIO_DOIS = RAIZ / "docs" / "relatorios" / "2026-11-19_069-dois-contatos.md"
RELATORIO_ATRASO_CONTATO = RAIZ / "docs" / "relatorios" / "2026-11-19_070-atraso-por-contato.md"
RELATORIO_QUEDA_CONTATO = RAIZ / "docs" / "relatorios" / "2026-11-19_071-queda-por-contato.md"
RELATORIO_RELOGIO_CONTATO = RAIZ / "docs" / "relatorios" / "2026-11-19_072-relogios-e-aparelho.md"


def problemas() -> list[str]:
    falhas: list[str] = []
    for caminho in (CORE, PAGINA, PAGES, CAD, TESTE_PURO, TESTE_TELA,
                    DART_CORE, PACKAGE, CHANGELOG, INVENTARIO, RELATORIO,
                    RELATORIO_SELO, RELATORIO_REVERSAO, RELATORIO_MOTOR,
                    RELATORIO_RELE, RELATORIO_TEMPO, RELATORIO_TEMPO_NF, RELATORIO_QUEDA, RELATORIO_DOIS,
                    RELATORIO_ATRASO_CONTATO, RELATORIO_QUEDA_CONTATO,
                    RELATORIO_RELOGIO_CONTATO):
        if not caminho.is_file():
            return [f"{caminho.name} não encontrado"]

    core = CORE.read_text(encoding="utf-8")
    pagina = PAGINA.read_text(encoding="utf-8")
    pages = PAGES.read_text(encoding="utf-8")
    cad = CAD.read_text(encoding="utf-8")
    teste_puro = TESTE_PURO.read_text(encoding="utf-8")
    teste_tela = TESTE_TELA.read_text(encoding="utf-8")
    dart_core = DART_CORE.read_text(encoding="utf-8")
    package = json.loads(PACKAGE.read_text(encoding="utf-8"))
    changelog = CHANGELOG.read_text(encoding="utf-8")
    inventario = INVENTARIO.read_text(encoding="utf-8")
    relatorio = RELATORIO.read_text(encoding="utf-8")
    relatorio_selo = RELATORIO_SELO.read_text(encoding="utf-8")
    relatorio_reversao = RELATORIO_REVERSAO.read_text(encoding="utf-8")
    relatorio_motor = RELATORIO_MOTOR.read_text(encoding="utf-8")
    relatorio_rele = RELATORIO_RELE.read_text(encoding="utf-8")
    relatorio_tempo = RELATORIO_TEMPO.read_text(encoding="utf-8")
    relatorio_tempo_nf = RELATORIO_TEMPO_NF.read_text(encoding="utf-8")
    relatorio_queda = RELATORIO_QUEDA.read_text(encoding="utf-8")
    relatorio_dois = RELATORIO_DOIS.read_text(encoding="utf-8")
    relatorio_atraso_contato = RELATORIO_ATRASO_CONTATO.read_text(encoding="utf-8")
    relatorio_queda_contato = RELATORIO_QUEDA_CONTATO.read_text(encoding="utf-8")
    relatorio_relogio_contato = RELATORIO_RELOGIO_CONTATO.read_text(encoding="utf-8")

    # 1. Motor Dart puro, offline e com solução numérica real (MNA).
    for termo in ("TipoElemento", "class Circuito", "simular(", "_resolver",
                  "matriz", "vetor", "pivoteamento" if "pivoteamento" in core else "pivo"):
        if termo not in core:
            falhas.append(f"motor sem {termo}")
    for proibido in ("package:flutter", "package:http", "dart:io",
                     "WebView", "webview", "dart:html"):
        if proibido in core:
            falhas.append(f"motor com dependência indevida: {proibido}")

    # 2. Proteção e diagnósticos exigidos pelo prompt.
    for termo in ("Curto-circuito", "Circuito aberto", "fora da malha",
                  "queimou", "vai queimar", "dissipa", "Fusível"):
        if termo not in core:
            falhas.append(f"motor sem diagnóstico: {termo}")
    if "fusiveisQueimados" not in core:
        falhas.append("fusível não registra rompimento")

    # 2B. Comando por contator: botoeira, bobina, selo e iteração.
    for termo in ("botoeira", "bobina", "contatoSelo", "ativaEm",
                  "bobinasLigadas", "_comandar", "Partida direta com selo",
                  "contatoNf", "Reversão com intertravamento",
                  "contatoPotencia", "motor", "Partida direta de motor DC",
                  "releTermico", "contatoRele", "desarmado",
                  "rearmarReles", "Partida com relé de sobrecarga",
                  "temporizador", "contatoTemporizado", "atraso",
                  "temporizadoresAtivos", "Sequência com temporizador",
                  "contatoTemporizadoNf", "Desligamento em sequência",
                  "atrasoQueda", "temposQueda", "temporizadoresAcionados",
                  "Desligamento temporizado", "Dois contatos do temporizador",
                  "rotulo = '$rotulo ($indice)'", "atrasoDoContato",
                  "Contatos com tempos diferentes",
                  "Quedas diferentes no temporizador",
                  "atrasoQuedaDoContato", "relogioDoContato",
                  "relogioQuedaDoContato", "temposContato",
                  "temposQuedaContato",
                  "Relógios independentes no temporizador"):
        if termo not in core:
            falhas.append(f"motor sem comando por contator: {termo}")
    if "0.7" not in core or "0.5" not in core:
        falhas.append("bobina sem limiar de puxar e soltar")

    # 3. Tela nativa, sem WebView, com tabuleiro, paleta e resultado.
    for termo in ("circuito-tabuleiro", "GeometriaCircuito", "ferramenta-${f.name}",
                  "Ferramenta.apagar", "RESULTADO DA SIMULAÇÃO",
                  "resultado-circuito", "alternar-interruptor",
                  "remover-elemento", "CustomPaint", "apertar-botoeira",
                  "bobina-do-selo-", "contatoSelo", "contatoNf",
                  "contatoPotencia", "motor", "rearmar-rele",
                  "Relé térmico", "Contato 95/96", "Temporizador",
                  "Contato 67/68", "avancar-tempo",
                  "Contato 67/68 NF", "contatoTemporizadoNf",
                  "campo-atraso-queda", "aplicar-atraso-queda",
                  "relogio-queda", "retardo na queda",
                  "contato-tipo-na", "contato-tipo-nf",
                  "_trocarTipoContato", "campo-atraso-contato",
                  "aplicar-atraso-contato", "atrasoDoContato",
                  "campo-queda-contato", "aplicar-queda-contato",
                  "atrasoQuedaDoContato", "temposContato",
                  "temposQuedaContato"):
        if termo not in pagina:
            falhas.append(f"tela sem {termo}")
    for proibido in ("WebView", "webview", "InAppWebView", "HtmlElementView",
                     "package:http"):
        if proibido in pagina:
            falhas.append(f"tela com WebView/HTTP: {proibido}")

    # 4. Limites declarados dentro do app (não prometer o CADeSIMU).
    for termo in ("não é o ", "CADeSIMU", "corrente alternada",
                  "motor de indução", "carga resistiva", "CLP", "1 µΩ", "DC",
                  "bobina", "relé térmico", "sem curva", "temporizador",
                  "Avançar 1 s"):
        if termo not in pagina:
            falhas.append(f"tela sem o limite declarado: {termo}")

    # 5. Entradas na interface: módulo e tela de importação .cad.
    if "abrir-simulador-circuitos" not in pages or "CircuitoPage" not in pages:
        falhas.append("módulo CADeSIMU sem botão do simulador")
    if "abrir-simulador-do-cad" not in cad:
        falhas.append("tela do .cad sem atalho para o simulador")

    # 6. Testes de verdade: cálculo em Dart e interação na tela.
    for termo in ("0.4166666", "0.06", "fusiveisQueimados", "fora da malha",
                  "bobinasLigadas", "Partida direta com selo", "0.1",
                  "Reversão com intertravamento", "contatoNf",
                  "não se estabiliza", "Partida direta de motor DC", "sobreaquece",
                  "Partida com relé de sobrecarga", "desarmou",
                  "Sequência com temporizador", "tempos:",
                  "Desligamento em sequência", "contatoTemporizadoNf",
                  "67/68 NF", "Desligamento temporizado", "atrasoQueda",
                  "temposQueda", "Dois contatos do temporizador", "tipo:",
                  "Contatos com tempos diferentes", "atrasoDoContato",
                  "Quedas diferentes no temporizador"):
        if termo not in teste_puro:
            falhas.append(f"teste puro sem verificação: {termo}")
    for termo in ("tapAt", "alternar-interruptor", "0,417 A", "queimou",
                  "apertar-botoeira", "Partida direta com selo",
                  "Reversão com intertravamento", "colunas: 8",
                  "Partida direta de motor DC", "colunas: 6",
                  "Partida com relé de sobrecarga", "rearmar-rele",
                  "Sequência com temporizador", "avancar-tempo",
                  "Desligamento em sequência", "Relógio: 0 s de 3 s",
                  "Desligamento temporizado", "relogio-queda",
                  "Queda: 2 s de 3 s", "Dois contatos do temporizador",
                  "contato-tipo-nf", "Contatos com tempos diferentes",
                  "campo-atraso-contato",
                  "Quedas diferentes no temporizador",
                  "campo-queda-contato"):
        if termo not in teste_tela:
            falhas.append(f"teste de tela sem verificação: {termo}")

    # 7. Registro nas suítes e documentação do ajuste.
    if "tool/circuito_test.dart" not in dart_core:
        falhas.append("teste puro fora do núcleo Dart")
    if "tests/test_circuito_flutter.py" not in package["scripts"]["test:all"]:
        falhas.append("teste estático fora da suíte")
    if "simulador de circuitos" not in changelog.lower():
        falhas.append("CHANGELOG sem o simulador")
    if "simulador" not in inventario.lower():
        falhas.append("inventário sem o simulador")
    for nome, texto in (("061", relatorio), ("062", relatorio_selo),
                        ("063", relatorio_reversao), ("064", relatorio_motor),
                        ("065", relatorio_rele), ("066", relatorio_tempo),
                        ("067", relatorio_tempo_nf), ("068", relatorio_queda), ("069", relatorio_dois),
                        ("070", relatorio_atraso_contato),
                        ("071", relatorio_queda_contato)):
        for termo in ("Feito", "Evidência", "Não verificado", "Limitações"):
            if termo not in texto:
                falhas.append(f"relat\u00f3rio {nome} sem a se\u00e7\u00e3o {termo}")

    return falhas


def main() -> int:
    falhas = problemas()
    if falhas:
        for falha in falhas:
            print(f"FALHOU: {falha}")
        print(f"Simulador de circuitos: {len(falhas)} problema(s).")
        return 1
    print("OK: simulador de circuitos — motor MNA puro, tela nativa, limites declarados e testes na suíte")
    return 0


if __name__ == "__main__":
    sys.exit(main())
