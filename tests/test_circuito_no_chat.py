#!/usr/bin/env python3
"""Contrato do ajuste 100 (versão 1.86.0).

O bloco 099 entregou o projetista, mas ele só era alcançável por dentro do
módulo de CADeSIMU. Este ajuste leva o circuito por prompt para o caminho
natural: a conversa (digitada ou falada) e a voz de fundo.

O contrato prende o que é verificável sem aparelho:

1. a decisão “isto é pedido de circuito?” é conservadora: exige verbo de
   montagem e substantivo de circuito, e poupa pergunta pura;
2. a interceptação acontece **depois** dos comandos do aparelho e **antes** de
   qualquer provedor de IA — montar circuito não gasta chave;
3. o resultado só é oferecido com simulação fechada, e recusa traz motivo;
4. a conversa mostra o cartão com o atalho para o simulador;
5. a voz de fundo responde pelo mesmo núcleo, com texto falável;
6. as ferramentas Dart, os testes de tela e a documentação estão registrados.

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


# 1. Versão e registro no pacote de testes.
exigir("version: 1.88.4+18804" in ler(APP / "pubspec.yaml"),
       "pubspec sem 1.87.0+18700")
pacote = ler(RAIZ / "package.json")
exigir("tests/test_circuito_no_chat.py" in pacote,
       "contrato fora do npm run test:all")
dart_core = ler(RAIZ / "tests" / "test_dart_core.py")
exigir("tool/circuito_no_chat_test.dart" in dart_core,
       "test_dart_core.py sem o teste do circuito no chat")

# 2. Núcleo da decisão.
nucleo = ler(LIB / "core" / "circuito_no_chat.dart")
for termo in ("bool pedidoDeCircuito(", "RespostaCircuito? responderPedidoDeCircuito(",
              "_verbosDeMontagem", "_substantivosDeCircuito",
              "_aberturaDePergunta", "textoFalado"):
    exigir(termo in nucleo, f"circuito_no_chat.dart sem {termo}")
exigir("montarProjetoDe(" in nucleo, "o núcleo não usa o projetista")
exigir(".simular()" in nucleo, "o núcleo não confere a simulação")
for rede in ("package:http", "http.post", "dart:io"):
    exigir(rede not in nucleo, f"o núcleo do chat não pode usar {rede}")

# 3. Conversa: ordem da interceptação, cartão e atalho.
conversa = ler(LIB / "services" / "voice_conversation_page.dart")
exigir("responderPedidoDeCircuito(texto)" in conversa,
       "a conversa não intercepta o pedido de circuito")
i_comando = conversa.find("_comandos.executar(texto)")
i_circuito = conversa.find("responderPedidoDeCircuito(texto)")
i_provedor = conversa.find("selecionado = provedor")
exigir(0 <= i_comando < i_circuito,
       "o circuito deveria ser decidido depois dos comandos do aparelho")
exigir(i_circuito < i_provedor or i_provedor == -1,
       "o circuito deveria ser decidido antes de qualquer provedor")
for termo in ("_concluirCircuito(", "conversa-circuito-pronto",
              "conversa-abrir-simulador", "CircuitoPage(inicial: pronto)",
              "circuito por prompt", "circuito recusado"):
    exigir(termo in conversa, f"voice_conversation_page.dart sem {termo}")
exigir("_circuitoPronto = resposta.ok ? resposta.projeto.circuito : null"
       in conversa,
       "a conversa guarda circuito mesmo quando a montagem falhou")

# 4. Voz de fundo responde pelo mesmo núcleo.
ponte = ler(LIB / "services" / "ponte_ia_fundo.dart")
exigir("responderPedidoDeCircuito(texto)" in ponte,
       "a ponte de fundo não intercepta circuito")
i_ponte_circuito = ponte.find("responderPedidoDeCircuito(texto)")
i_ponte_provedor = ponte.find("firstConfiguredProvider()")
exigir(i_ponte_circuito < i_ponte_provedor,
       "na ponte de fundo o circuito vem depois do provedor")
exigir("circuito.textoFalado" in ponte, "a ponte não usa o texto falável")

# 5. Testes.
exigir((APP / "tool" / "circuito_no_chat_test.dart").is_file(),
       "tool/circuito_no_chat_test.dart não existe")
exigir((APP / "test" / "conversa_circuito_test.dart").is_file(),
       "test/conversa_circuito_test.dart não existe")
teste = ler(APP / "test" / "conversa_circuito_test.dart")
for termo in ("conversa-circuito-pronto", "conversa-abrir-simulador",
              "circuito-tabuleiro"):
    exigir(termo in teste, f"teste da conversa sem {termo}")

# 6. Documentação.
changelog = ler(RAIZ / "CHANGELOG.md")
exigir("## 1.86.0" in changelog, "CHANGELOG sem o bloco 1.86.0")
exigir("chat" in changelog.lower() and "circuito" in changelog.lower(),
       "CHANGELOG sem o circuito no chat")
inventario = ler(RAIZ / "docs" / "INVENTARIO_DE_FUNCOES.md").lower()
exigir("circuito no chat" in inventario, "inventário sem o circuito no chat")
comparativo = ler(RAIZ / "docs" / "COMPARATIVO-ULTRON.md")
exigir("Bloco 100" in comparativo, "comparativo sem o bloco 100")
relatorio = (RAIZ / "docs" / "relatorios" /
             "2026-11-22_100-circuito-no-chat.md")
exigir(relatorio.is_file(), "relatório do bloco 100 não existe")
texto_relatorio = ler(relatorio)
for termo in ("## 5. Limites declarados", "Nada foi compilado",
              "depois dos comandos", "antes do provedor"):
    exigir(termo in texto_relatorio, f"relatório sem “{termo}”")

# 7. Proibições do projeto nos arquivos tocados.
proibido = re.compile(r"(GlobalScope|Process\.run|Runtime\.getRuntime)")
for arquivo in (LIB / "core" / "circuito_no_chat.dart",
                LIB / "services" / "voice_conversation_page.dart",
                LIB / "services" / "ponte_ia_fundo.dart"):
    exigir(not proibido.search(ler(arquivo)),
           f"{arquivo.relative_to(RAIZ)} usa construção proibida")

if falhas:
    print("FALHAS no contrato do ajuste 100:")
    for falha in falhas:
        print(" -", falha)
    sys.exit(1)

print("OK: ajuste 100 — circuito por prompt no chat e na voz, decidido depois "
      "dos comandos e antes do provedor.")
