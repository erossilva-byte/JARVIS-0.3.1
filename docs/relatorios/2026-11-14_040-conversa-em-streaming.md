# Ajuste 040 — conversa em streaming, parar e estados (2026-11-14)

## Por que

A tela de conversa esperava a resposta inteira e mostrava um indicador genérico. A Seção 3D
pede resposta progressiva, botão de parar, estados completos e atualização em janela — o
`StreamBuffer` do ajuste 039 existia, mas não estava ligado a nada.

## O que foi feito

### Parser SSE (`flutter_app/lib/core/sse.dart`)

Lê o fluxo `data: {...}` dos provedores compatíveis com OpenAI, guarda linha cortada entre
pedaços, ignora `[DONE]`, comentários e eventos, aceita resposta sem streaming (envelope
`message`) e reporta linha inválida sem derrubar a leitura.

### `ProviderService.streamComplete`

Requisição POST com `stream: true`, `Accept: text/event-stream`, timeout de 30 s para o
cabeçalho e emissão de cada fragmento. Cancelar a assinatura fecha a conexão — é o que o botão
de parar usa.

### Tela de conversa

- resposta aparece aos poucos, agrupada pelo `StreamBuffer` (32 ms);
- botão **parar** durante a geração: cancela a assinatura e mantém o texto já recebido, com
  aviso de que foi interrompido;
- estado **vazio** explicando como a conversa funciona;
- estado **processando** com indicador;
- estado **erro** com botão “tentar de novo”;
- campo bloqueado durante a geração;
- cada resposta aceita `fontes` e mostra “O que lembrei” quando houver — hoje vazio, porque a
  memória da Fase 7 ainda não alimenta a interface.

### Testes

`flutter_app/tool/sse_test.dart` — cinco casos: deltas simples, pedaço cortado no meio da
linha, `[DONE]`/eventos ignorados, resposta sem streaming e linha inválida reportada.
`tests/test_dart_core.py` passou a rodar os dois testes puros (buffer e SSE).

## Verificação

- `dart run tool/stream_buffer_test.dart` — exit 0.
- `dart run tool/sse_test.dart` — exit 0.
- `dart format --output=none` nos arquivos alterados — sem erro de sintaxe.
- `npm run verificar` — exit 0 (números no fechamento).

## Limites

Nada foi compilado com Flutter: `flutter analyze` e `flutter test` continuam pendentes e podem
apontar erro de tipo ou de widget. A tela não foi aberta em aparelho nem medida. O caminho de
fallback para provedor que ignora `stream` está coberto pelo parser (envelope `message`), mas
não foi exercitado contra API real — não há chave neste ambiente.
