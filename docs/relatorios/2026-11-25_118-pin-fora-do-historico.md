# Bloco 118 — PIN dito em voz alta fora do histórico

**Versão:** 1.95.0+19500
**Data:** 25 de novembro de 2026

## Onde o texto do pedido era gravado

O histórico de execuções é do Android; o Flutter só mostra e pede o registro.
O caminho era este:

1. **No app** — `HistoricoVozService.registrar` (`lib/services/historico_voz_service.dart`)
   enviava o pedido pelo canal `com.jarvis.nova/fundo`, método
   `registrarExecucao`, no campo `pedido`. Chamado da conversa em quatro pontos
   (`voice_conversation_page`), com texto e voz.
2. **No Android** — `JarvisFundoCanal` recebia `registrarExecucao` e chamava
   `JarvisFundo.registrarHistorico`, que cai em `JarvisFundo.anotar`
   (`android/JarvisFundo.kt`). Ali o JSON é montado e salvo em
   `SharedPreferences`:
   - arquivo **`jarvis_fundo`**
   - chave **`historico_acoes`**
   - campo **`pedido`** (até 300 caracteres)
3. **No segundo plano** — `KwsForegroundService` chamava
   `JarvisFundo.registrar` / `registrarHistorico` em 12 pontos, sempre com o
   texto ouvido em `pedido`; todos passam pelo mesmo `anotar`.

Ou seja: um único funil de gravação (`anotar`) e uma única saída no app (o canal).

## O que mudou

- `lib/core/segredo_pedido.dart`: `protegerPinNoPedido` troca sequência isolada
  de **4 a 8 dígitos** por `[oculto]` (regex `(?<!\d)\d{4,8}(?!\d)`).
- `HistoricoVozService.registrar` aplica a máscara **antes** de montar o
  argumento do canal: o PIN não sai do processo do app.
- `android/JarvisSegredo.kt`: a mesma regra e o mesmo marcador.
- `JarvisFundo.anotar` aplica `JarvisSegredo.ocultarPin` no `pedido` antes de
  `put("pedido", …)`: cobre o serviço de segundo plano e qualquer chamador novo.
- `prepare_android_sistema.py` copia a classe nova para o build.

## O que fica de fora (de propósito)

- **3 dígitos ou menos** (hora, “às 9”) e **9 ou mais** (telefone, CEP, número
  de documento) não são mascarados: não cabem num PIN deste app (4 a 8) e
  apagá-los só tiraria a explicação do comando.
- A **conversa visível** continua com o texto dito: é outra gravação
  (`ConversaStore`), e mascarar ali mudaria o que a pessoa leu na tela.
- O campo de mensagem do registro (resultado da ação) não é mascarado; ele é
  gerado pelo app, não pelo que foi ouvido.

## Verificações feitas

- `dart run tool/segredo_pedido_test.dart` — faixa completa (4, 6 e 8 dígitos),
  PIN no meio da frase, duas sequências, telefone de 11 dígitos preservado,
  “às 9” preservado, idempotência e casos de borda.
- `flutter analyze` — sem problemas.
- `flutter test` — suíte completa.
- `python3 tests/test_bloco_118.py` — contrato (regra nos dois lados, aplicação
  nas duas pontas, nenhuma gravação crua, empacotamento, versão e registros).
- Suíte Python inteira.

## Limites

- Não há aparelho nesta sessão: a máscara foi conferida na regra e nos testes,
  não lendo o `SharedPreferences` de um celular real.
- PIN falado ainda pode ser ouvido por quem está perto e continua aparecendo na
  conversa da tela; o modo visita segue sem abertura por voz, como recomendado.
