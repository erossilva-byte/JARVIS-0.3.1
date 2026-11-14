# Fase 5 — entrega para aprovação (2026-11-14)

**Branch:** `work/1.48.0-fase2-consolidacao`
**Estado:** entregue o que o ambiente permite verificar; **não** declarada concluída — as
pendências abaixo dependem de CI com Flutter e de medição no Poco X7.

## Critérios da Seção 3D / Fase 5

| # | Critério | Estado | Evidência |
|---|---|---|---|
| 1 | Nenhuma WebView ou tela web (busca automatizada) | **Atendido** | `ci/preflight_interface.py` + teste negativo |
| 2 | Navegação com as doze seções | **Atendido** | pré-checagem confere a gaveta |
| 3 | Toda tela com carregando, vazio e erro | **Parcial** | conversa tem os três, com “tentar de novo”; telas de módulo ainda são aviso de auditoria |
| 4 | App usável por texto sem permissão, rede ou modelo | **Atendido no código** | conversa abre mesmo sem provedor configurado e explica o motivo |
| 5 | Streaming com atualização em 16–50 ms | **Atendido no núcleo e na tela** | `StreamBuffer` (32 ms) testado; parser SSE testado; tela usa os dois |
| 6 | Parar geração, manter o texto recebido | **Atendido no código** | botão de parar cancela a assinatura e preserva o parcial |
| 7 | Citação das notas usadas | **Preparado, sem fonte ainda** | campo `fontes` na mensagem; a memória da Fase 7 é quem vai preencher |
| 8 | Histórico de conversas com busca e fixar | **Pendente** | exige persistência local |
| 9 | Modo voz em tela cheia | **Pendente** | — |
| 10 | Persistência após morte do processo | **Pendente** | exige armazenamento local |
| 11 | Integração com o sistema (atalhos, widget, compartilhar) | **Pendente** | — |
| 12 | Fluidez, inicialização e jank medidos no Poco X7 | **Pendente** | sem aparelho |
| 13 | `flutter analyze` e `flutter test` verdes | **Pendente** | sem Flutter nesta máquina; roda no CI |

## O que foi entregue nesta fase

- Portão automático contra WebView/HTML e conferência das doze seções.
- Navegação completa (Segurança e Personalização entraram).
- Animação reduzida e `RepaintBoundary` no núcleo.
- `StreamBuffer`: agrupamento de tokens com janela de 32 ms (testado).
- `SseParser`: leitura de streaming compatível com OpenAI, tolerante a pedaço cortado (testado).
- `ProviderService.streamComplete`: requisição em streaming, cancelável.
- Tela de conversa com resposta progressiva, parar geração, estados vazio/processando/erro e
  “tentar de novo”.
- Testes Dart puros na suíte local e no workflow nativo.

## O que impede declarar a fase concluída

1. **Compilação**: sem Flutter/Dart de interface aqui, `flutter analyze` e `flutter test` nunca
   rodaram com estas mudanças. O Dart puro foi testado, mas tipos e widgets não.
2. **Medição**: nenhuma métrica de fps, jank ou inicialização no Poco X7.
3. **Funcionalidades da própria fase**: histórico, voz em tela cheia, persistência e integração
   com o sistema continuam pendentes — não há como marcá-las como entregues.

## Como aprovar ou recusar

- Aprovar a fase como **parcial**, seguindo para a Fase 6 com as pendências registradas; ou
- manter a Fase 5 aberta e atacar os itens 8 a 11 antes de avançar.

Nenhuma das opções dispensa a rodada de CI: a primeira compilação é que valida o que está aqui.
