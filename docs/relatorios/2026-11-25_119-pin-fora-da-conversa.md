# Bloco 119 — PIN ditado fora do histórico de conversas

**Versão:** 1.96.0+19600
**Data:** 25 de novembro de 2026

## Onde a conversa era gravada

- **Modelo e formato** — `lib/core/conversa.dart`: `Conversa.paraJson()` monta
  `titulo` e a lista de `mensagens` (cada uma com `texto`).
- **Gravação** — `ConversaStore._gravar` serializa a lista e salva em
  `SharedPreferences`, chave **`jarvis.conversas.v1`**. É o único ponto de
  escrita do histórico de conversas (usado por `salvar`, `apagar` e
  `alternarFixada`).
- **Rascunho** — `ConversaStore.salvarRascunho`, chave **`jarvis.rascunho.v1`**,
  guardava o texto digitado/falado pela metade.
- **Quem chama** — `voice_conversation_page` salva a cada mensagem nova.

## O que mudou

- `_gravar` passou a serializar uma **cópia** da conversa
  (`_paraJsonArmazenado`), com `titulo` e o `texto` de cada mensagem passando por
  `protegerPinNoPedido` — a mesma regra do bloco 118.
- `salvarRascunho` mascara o texto antes de guardar.
- A conversa aberta na tela **não** é alterada: a máscara existe só na cópia que
  vai para o disco. Durante a sessão você continua vendo o que disse; ao reabrir
  o app, o que estava salvo aparece como `[oculto]`.
- `fontes`, `fichas` e `habilidades` não passam pela máscara: são nomes e notas,
  não texto falado.

## Exemplo

Dito: “meu pin é 4321” → salvo como “meu pin é [oculto]”, e o título automático
da conversa fica “meu pin é [oculto]”.

Telefone continua inteiro: “liga para 11999998888” não perde nada, porque 11
dígitos não cabem num PIN deste app.

## Verificações feitas

- `flutter test test/conversa_store_test.dart` — três testes novos: PIN no título
  e nas duas mensagens (pergunta e resposta), sessão intacta, telefone
  preservado e rascunho mascarado.
- `flutter analyze` — sem problemas.
- `flutter test` — suíte completa.
- `python3 tests/test_bloco_119.py` — contrato (mesma regra, máscara na cópia,
  título/mensagens/rascunho, testes registrados, versão e docs).
- Suíte Python inteira, incluindo os contratos 117 e 118.

## Limites

- Não há aparelho nesta sessão: o comportamento foi provado em teste de
  armazenamento simulado, não lendo o `SharedPreferences` de um celular.
- Conversas salvas **antes** desta versão continuam com o texto antigo no disco;
  a máscara vale para o que for salvo daqui em diante. Limpar conversas antigas
  é decisão sua.
- O PIN dito ainda pode ser ouvido por quem está perto, e a conversa em memória
  continua mostrando o texto durante a sessão.
