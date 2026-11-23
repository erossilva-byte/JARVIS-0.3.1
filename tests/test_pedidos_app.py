"""Bloco 106 — pedidos de app por voz: ficha de pessoa e interruptor duplo.

Confere o caminho estático: o leitor da ficha, o executor que grava no mesmo
cofre da tela de Pessoas, a conversa e a ponte de segundo plano chamando o
mesmo executor, e a família nova do projetista. Como sempre, contrato não é
teste de aparelho: compilar e rodar no celular continua fora daqui.
"""

from __future__ import annotations

from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "flutter_app"
LIB = APP / "lib"
CORE = LIB / "core"
SERVICOS = LIB / "services"


def ler(caminho: Path) -> str:
    assert caminho.is_file(), f"arquivo ausente: {caminho}"
    return caminho.read_text(encoding="utf-8")


def exigir(condicao: bool, mensagem: str) -> None:
    assert condicao, mensagem


ficha = ler(CORE / "pedido_ficha.dart")
executor = ler(SERVICOS / "executor_app.dart")
conversa = ler(SERVICOS / "voice_conversation_page.dart")
ponte = ler(SERVICOS / "ponte_ia_fundo.dart")
projetista = ler(CORE / "projetista.dart")
pacote = ler(RAIZ / "package.json")

# 1. O leitor puro reconhece os campos do pedido sem inventar nada.
for termo in ("class PedidoFicha", "pedidoDeFicha(", "confirmacaoDeFicha(",
              "cancelamentoDeFicha(", "apelido", "relacao", "idade",
              "observacoes"):
    exigir(termo in ficha, f"pedido_ficha.dart sem {termo}")
exigir("crie|cria|criar" in ficha, "verbos de criação ausentes")
exigir("confirmo" in ficha, "confirmação de consentimento ausente")

# 2. O executor usa o mesmo cofre da tela de Pessoas e só grava com consentimento.
for termo in ("class ExecutorApp", "static Future<AcaoApp?> executar(",
              "PessoasStore.abrir()", "consentimento: true", "pedidoDeFicha("):
    exigir(termo in executor, f"executor_app.dart sem {termo}")
exigir("http" not in executor, "executor não pode falar com a rede")
exigir("Nada foi guardado" in executor or "Nada foi salvo" in executor,
       "executor não avisa que nada foi guardado")
exigir(executor.index("pedidoDeFicha(") < executor.index("_salvar("),
       "executor grava antes de entender o pedido")

# 3. Conversa e segundo plano usam o mesmo executor, antes do provedor.
exigir("ExecutorApp.executar(texto)" in conversa,
       "conversa não executa o pedido de app")
exigir(conversa.index("ExecutorApp.executar(texto)")
       < conversa.index("_comandos.executar(texto)"),
       "pedido de app avaliado depois dos comandos")
exigir("ExecutorApp.executar(texto)" in ponte,
       "segundo plano não executa o pedido de app")

# 4. Interruptor duplo é família de verdade, com duas teclas e duas lâmpadas.
for termo in ("interruptorDuplo", "_interruptorDuplo(",
              "interruptor duplo|duplo interruptor"):
    exigir(termo in projetista, f"projetista.dart sem {termo}")
inicio = projetista.index("ResultadoProjeto _interruptorDuplo(")
fim = projetista.index("ResultadoProjeto _led(", inicio)
trecho = projetista[inicio:fim]
exigir(trecho.count("_interruptor(") == 2,
       "interruptor duplo sem as duas teclas")
exigir(trecho.count("_lampada(") == 2,
       "interruptor duplo sem as duas lâmpadas")

# 5. Testes existem e estão na esteira.
for caminho in ("tool/pedido_ficha_test.dart", "test/executor_ficha_test.dart",
                "test/conversa_ficha_test.dart"):
    exigir((APP / caminho).is_file(), f"teste ausente: {caminho}")
exigir("python3 tests/test_pedidos_app.py" in pacote,
       "contrato fora do test:all")

print("OK: bloco 106 — ficha por voz com consentimento e interruptor duplo "
      "montado com duas teclas e duas lâmpadas.")
