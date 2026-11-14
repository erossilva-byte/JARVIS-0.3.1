# Ajuste 039 — núcleo de streaming da conversa (2026-11-14)

## Por que

A Seção 3D exige que a resposta da IA apareça progressivamente, mas com a tela sendo atualizada
em intervalos de 16 a 50 ms — não a cada token. Sem esse agrupamento, um provedor rápido emite
centenas de fragmentos por segundo e a conversa reconstrói a lista inteira a cada um, perdendo
quadros.

## O que foi feito

### `flutter_app/lib/core/stream_buffer.dart`

Dart puro, sem dependência do Flutter:

- `adicionar(fragmento)` acumula o token e agenda **uma** entrega pela janela (32 ms padrão);
- `concluir()` entrega o restante na hora, sem esperar a janela;
- `limpar()` zera o texto e avisa a interface (nova geração ou troca de conversa);
- token que chega depois de `concluir()` é ignorado;
- o agendador é injetável, para o teste controlar o tempo sem `sleep`.

### Teste executável sem Flutter

`flutter_app/tool/stream_buffer_test.dart` cobre cinco casos e roda com
`dart run tool/stream_buffer_test.dart`:

1. três tokens dentro da janela viram **uma** atualização com o texto concatenado;
2. a janela entregue é de 32 ms e o texto chega ao callback;
3. `concluir()` entrega imediatamente e a entrega agendada depois vira no-op;
4. `limpar()` zera o texto e volta a aceitar streaming;
5. token depois do fim não altera o texto.

O arquivo fica em `tool/`, não em `test/`, de propósito: `flutter test` exige o formato de
`package:test`, e este teste é Dart puro para rodar em qualquer lugar.

### Verificação da sintaxe Dart

O SDK do Dart foi baixado numa pasta temporária (fora do repositório) e os 20 arquivos Dart do
app passaram por `dart format --output=none`: nenhum erro de sintaxe. O comando também mostrou
que o código não segue o formato canônico — é estilo do projeto, não defeito, e não foi
alterado.

### Ligação com a suíte e o CI

- `tests/test_dart_core.py` procura o Dart (`PATH`, `DART_SDK` ou `/tmp/dart-sdk`) e roda o
  teste puro. Sem Dart, imprime `AVISO` e **não** finge aprovação.
- `npm run test:all` ganhou esse passo, com teste de empacotamento garantindo a presença.
- `flutter-native.yml` roda `dart run tool/stream_buffer_test.dart` nos dois trabalhos que já
  têm Flutter.

## Verificação

- `dart run tool/stream_buffer_test.dart` — exit 0, cinco casos.
- `python3 tests/test_dart_core.py` — exit 0.
- `dart format --output=none lib test` — 20 arquivos analisados, zero erro de sintaxe.
- `npm run verificar` — exit 0, 4 de 4 etapas, 2.367 verificações OK.

## Limites

O buffer **não está ligado à tela de conversa**: a interface continua com a resposta simples.
A peça testada é a lógica de agrupamento; a integração visual, o botão de parar e a citação de
fontes são o próximo item da Fase 5. Nada disso foi compilado com Flutter: `flutter analyze` e
`flutter test` só rodam no CI, e a medição de jank continua dependendo do Poco X7.
