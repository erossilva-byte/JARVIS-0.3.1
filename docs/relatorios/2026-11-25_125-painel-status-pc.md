# Bloco 125 — Etapa 2: painel do PC com os dois status

**Versão:** 1.102.0+110200
**Data:** 25 de novembro de 2026

## O que foi feito

- **`index.html`**: dentro da categoria “celular” (a que o botão “Status do
  celular” abre) entraram duas seções com título próprio:
  - **Status do PC**: `#sp-linhas` recebe os cartões e `#sp-alerta` explica o
    estado; no app do celular a seção avisa onde ver os dados do computador.
  - **Status do celular**: `#sc-pareamento` diz “Sem conexão com o celular” e
    explica que o pareamento chega na Etapa 3; os cartões antigos passam a
    mostrar “Sem conexão” em vez de “Disponível apenas no app Android”.
- **`status_plataforma.js`**: regra única de formatação, espelho de
  `lib/core/status_plataforma.dart`. Formata memória e disco como “8 GB de 16 GB
  em uso (50%)”, valor redondo sem decimal, bateria com “(carregando)”,
  temperatura com vírgula, tempo ligado em min/h/dia, e marca `semDados` quando
  nada veio.
- **`app.js`**: `atualizarStatusPc()` consulta `nativo('status_pc')` no desktop e
  preenche a seção; `renderStatusPlataforma()` desenha os cartões ou a frase
  “Sem conexão: nada foi lido deste lado.”; `atualizarStatusCelular()` agora
  atualiza os dois lados e é o ponto de entrada dos dois botões existentes.
- **`tests/test_status_pc_painel.js`**: 33 verificações em jsdom — as duas
  seções, a regra carregada antes do app, a formatação do PC e do celular, o
  estado vazio, o renderizador de verdade (extraído do `app.js`) e a ligação no
  código.

## Um achado importante no caminho

Ao rodar o teste da Etapa 1 com `--enable-asserts`, apareceu que **`dart run`
executa com asserts desligados**. O executor `tests/test_dart_core.py` chama
`dart run tool/*_test.dart` sem a flag, então os testes puros de `tool/` estavam
passando sem executar nenhuma verificação. Com a flag ligada, 17 arquivos falham
— a maioria por expectativa antiga, mas três são dos blocos recentes:

- `pin_sem_colisao_test.dart`: um contato com apelido “Murilo 2” empata com
  “Murilo” e a desempata escolhe o mais curto.
- `ligacao_paridade_test.dart`: “liga o volume” é interpretado como ligação pela
  regra do Dart (o guarda só cobre “ligar o”).
- `segredo_pedido_test.dart`: “12345abc” é mascarado (o lookahead só olha
  dígitos), e o teste esperava o contrário.

Esses três não foram corrigidos nesta entrega para não misturar escopo; ficam
como prioridade da próxima rodada, junto com ligar a flag no executor.

## Verificações feitas

- `node tests/test_status_pc_painel.js` — 33 verificações, OK.
- `node --check app.js` e `node --check status_plataforma.js` — OK.
- `dart run --enable-asserts tool/status_plataforma_test.dart` — OK (formato
  “8 GB” e estado vazio).
- `python3 tests/test_bloco_125.py` — OK.
- Suíte Python inteira, `flutter analyze`, `flutter test`.

## O que não foi feito

- O app Electron não foi aberto: a prova é jsdom + contrato.
- O pareamento PC ↔ celular é a Etapa 3 e não começou.
