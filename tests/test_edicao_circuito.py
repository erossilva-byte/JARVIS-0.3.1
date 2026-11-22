#!/usr/bin/env python3
"""Contrato do ajuste 101 (versão 1.87.0).

O bloco 100 montava circuito do zero. Este ajuste edita o que **já está no
simulador**: “troca o R1 por 470 ohms”, “muda a fonte para 24 V”, “abre o S1”,
“simula de novo”. A conversa muda a peça no aparelho, refaz a simulação e mostra
o antes e o depois.

O contrato prende:

1. o núcleo puro que interpreta a edição e recusa o que não sabe fazer;
2. o circuito em uso publicado pelo simulador;
3. a ordem no chat: montar primeiro, editar depois, provedor por último;
4. a recusa honesta (sem circuito aberto, peça ambígua, valor faltando);
5. a voz de fundo pelo mesmo núcleo;
6. versão, testes e documentação registrados.

Nada disto foi compilado nem executado em aparelho nesta sessão.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"
LIB = APP / "lib"

falhas: list[str] = []


def exigir(condicao: bool, mensagem: str) -> None:
    if not condicao:
        falhas.append(mensagem)


def ler(caminho: Path) -> str:
    if not caminho.is_file():
        falhas.append(f"{caminho.relative_to(RAIZ)} não encontrado")
        return ""
    return caminho.read_text(encoding="utf-8")


# 1. Versão e registro na suíte.
exigir("version: 1.88.0+18800" in ler(APP / "pubspec.yaml"),
       "pubspec sem 1.87.0+18700")
pacote = ler(RAIZ / "package.json")
exigir("tests/test_edicao_circuito.py" in pacote,
       "contrato fora do npm run test:all")
exigir("tool/edicao_circuito_test.dart" in ler(RAIZ / "tests" / "test_dart_core.py"),
       "test_dart_core.py sem o teste da edição")

# 2. Núcleo da edição.
edicao = ler(LIB / "core" / "edicao_circuito.dart")
for termo in ("bool pedidoDeEdicao(", "RespostaEdicao? responderEdicaoDeCircuito(",
              "MudancaCircuito", "_verbosEdicao", "_reSimular",
              "textoFalado", "acrescenta nem remove"):
    exigir(termo in edicao, f"edicao_circuito.dart sem {termo}")
exigir(".simular()" in edicao, "a edição não refaz a simulação")
exigir("atualizar(" in edicao, "a edição não aplica a peça no circuito")
for rede in ("package:http", "dart:io"):
    exigir(rede not in edicao, f"a edição não pode usar {rede}")

# 3. Circuito em uso, publicado pelo simulador.
em_uso = ler(LIB / "core" / "circuito_em_uso.dart")
for termo in ("CircuitoEmUso", "static Circuito? get atual", "definir(", "limpar("):
    exigir(termo in em_uso, f"circuito_em_uso.dart sem {termo}")
pagina = ler(LIB / "services" / "circuito_page.dart")
exigir(pagina.count("CircuitoEmUso.definir(") >= 2,
       "o simulador não publica o circuito ao abrir e ao mudar")

# 4. Chat: ordem e cartão.
conversa = ler(LIB / "services" / "voice_conversation_page.dart")
i_montar = conversa.find("responderPedidoDeCircuito(texto)")
i_editar = conversa.find("responderEdicaoDeCircuito(texto, CircuitoEmUso.atual)")
i_provedor = conversa.find("selecionado = provedor")
exigir(0 <= i_montar < i_editar,
       "editar deveria ser decidido depois de montar")
exigir(i_editar < i_provedor or i_provedor == -1,
       "editar deveria ser decidido antes do provedor")
for termo in ("_concluirEdicao(", "circuito editado", "edição recusada",
              "_circuitoPronto = resposta.circuito"):
    exigir(termo in conversa, f"voice_conversation_page.dart sem {termo}")
exigir("CircuitoEmUso.definir(resposta.circuito)" in conversa,
       "a conversa não publica o circuito editado")

# 5. Voz de fundo.
ponte = ler(LIB / "services" / "ponte_ia_fundo.dart")
i_ponte_montar = ponte.find("responderPedidoDeCircuito(texto)")
i_ponte_editar = ponte.find("responderEdicaoDeCircuito(texto")
exigir(0 <= i_ponte_montar < i_ponte_editar,
       "na ponte, editar deveria vir depois de montar")
exigir(i_ponte_editar < ponte.find("firstConfiguredProvider()"),
       "na ponte, editar deveria vir antes do provedor")
exigir("edicao.textoFalado" in ponte, "a ponte não usa o texto falável")

# 6. Testes.
exigir((APP / "tool" / "edicao_circuito_test.dart").is_file(),
       "tool/edicao_circuito_test.dart não existe")
teste = ler(APP / "test" / "conversa_edicao_test.dart")
for termo in ("Refiz a simulação", "conversa-circuito-pronto",
              "Não tenho um circuito aberto", "conversa-abrir-simulador"):
    exigir(termo in teste, f"teste da conversa sem “{termo}”")

# 7. Documentação.
changelog = ler(RAIZ / "CHANGELOG.md")
exigir("## 1.87.0" in changelog, "CHANGELOG sem o bloco 1.87.0")
exigir("editar" in changelog.lower(), "CHANGELOG sem a edição por prompt")
inventario = ler(RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md").lower()
exigir("edição por prompt" in inventario, "inventário sem a edição por prompt")
exigir("Bloco 101" in ler(RAIZ / "docs" / "COMPARATIVO-ULTRON.md"),
       "comparativo sem o bloco 101")
relatorio = (RAIZ / "docs" / "relatorios" /
             "2026-11-22_101-editar-circuito-por-prompt.md")
exigir(relatorio.is_file(), "relatório do bloco 101 não existe")
texto = ler(relatorio)
for termo in ("## 5. Limites declarados", "Nada foi compilado",
              "depois dos comandos", "antes do provedor",
              "não acrescenta nem remove"):
    exigir(termo in texto, f"relatório sem “{termo}”")

# 8. Proibições do projeto nos arquivos tocados.
proibido = re.compile(r"(GlobalScope|Process\.run|Runtime\.getRuntime)")
for arquivo in (LIB / "core" / "edicao_circuito.dart",
                LIB / "core" / "circuito_em_uso.dart",
                LIB / "services" / "voice_conversation_page.dart",
                LIB / "services" / "ponte_ia_fundo.dart",
                LIB / "services" / "circuito_page.dart"):
    exigir(not proibido.search(ler(arquivo)),
           f"{arquivo.relative_to(RAIZ)} usa construção proibida")

if falhas:
    print("FALHAS no contrato do ajuste 101:")
    for falha in falhas:
        print(" -", falha)
    sys.exit(1)

print("OK: ajuste 101 — edição do circuito em uso, simulação refeita e "
      "resultado no chat e na voz.")
