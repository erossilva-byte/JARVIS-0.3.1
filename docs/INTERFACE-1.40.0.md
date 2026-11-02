# 1.40.0 — Interface do núcleo, áreas e abertura

## Objetivo

Renovar a experiência visual sem reescrever o núcleo: o menu passa a ser uma central de comando
com o núcleo no centro, a conversa deixa de ser uma opção independente e as áreas voltam a abrir
suas funções reais. A abertura deixa de mostrar o menu antes da hora.

## Identidade visual

- Paleta preto profundo (`#02060c`), ciano (`#42e8ff`), azul (`#2d7dff`) e grafite.
- Núcleo com HUD, plasma, órbitas, varredura, grade e telemetria; estados `idle`, `listening`,
  `thinking`, `speaking`, `processing`, além dos estados de conclusão/erro usados pelo app.
- Cartão de última resposta abaixo do núcleo; a transcrição completa fica na tela secundária.
- Painéis com cabeçalho, retorno fixo, rolagem própria e alvos de toque maiores.
- Modos Completo, Discreto, Silencioso e Holográfico preservados.
- `prefers-reduced-motion` e `body.efeitos-reduzidos` reduzem animações; o layout responsivo
  cobre 820, 600, 380 px e alturas menores.

## Conversa

O botão `Conversa` foi removido do menu. O sistema de conversação **não** foi removido:

- chat, histórico, mensagens, transcrição e campo de texto continuam em `#chat-area`;
- `#btn-transcricao`, o botão “Transcrição completa” e o cartão de acessos abrem a tela secundária;
- comandos digitados e voz continuam funcionando; a resposta aparece no cartão central;
- o microfone, TTS, anexos, histórico e provedores não foram alterados.

## Correção das áreas

**Causa raiz:** `aplicarModo()` gravava `data-modo` no `<body>`. A delegação de cliques fazia
`alvo.closest('[data-modo]')`; como todo elemento está dentro do `body`, qualquer toque era
interpretado como troca de modo e a função retornava antes de executar a ação. O cartão abria
porque tinha um listener direto com `stopPropagation`, mas os botões internos não.

**Correções:**

1. o seletor passou a ser `.modo-btn[data-modo]`, tanto para pintar quanto para clicar;
2. o cartão mantém listener direto, além da delegação;
3. o alvo de texto da WebView sobe para `parentElement` antes de `closest`;
4. a ação (`data-area-acao`) tem prioridade sobre abrir a área;
5. `init()` é idempotente, evitando listeners duplicados quando `DOMContentLoaded` e chamada
   tardia acontecem;
6. o retorno limpa o detalhe, rola ao topo e restaura o mapa.

O teste `tests/test_interface_dom.js` usa jsdom e clica nos 10 cartões, em todas as 44 ações e no
retorno de cada área: **80 verificações de DOM**.

## Origem do flash de abertura

Antes, `#boot` começava com `hidden`, o menu aparecia e `iniciarSequenciaBoot()` só era chamado
700 ms depois; o bloqueio era aberto 520 ms depois de o boot sumir. Isso produzia a sequência de
menu e telas escuras.

Agora:

- `#boot` nasce visível e o `<body>` nasce com `class="travado"`;
- o boot roda em `setTimeout(..., 0)` e tem `z-index: 150`, acima do bloqueio (`120`);
- o bloqueio é montado **antes** de o corpo ser destravado;
- com bloqueio ativo, o corpo continua travado até `fecharBloqueio()`;
- a tela de boot só sai depois da preparação; não há menu antes do bloqueio.

## Testes executados

- `node tests/test_interface_dom.js`: 10 áreas, 44 ações, retorno e boot inicial.
- `python3 tests/test_v1_40_0.py`: contrato estático da versão, seletores, boot e preservação.
- `npm run test:all`: suíte completa (resultado registrado no relatório de entrega).
- `node --check app.js`, `node --check interface.js`.

## Limitações

Não houve aparelho/emulador/ADB nesta máquina. Portanto **não** foram validados: instalação real,
toque em WebView Android, microfone, wake word, TTS, câmera, acessibilidade, segundo plano,
minimizar/retornar, reinício do processo Android, FPS e consumo de bateria/RAM. O teste jsdom
prova o fluxo de eventos e o DOM, não o comportamento do WebView do Poco X7. A conferência visual
também não foi feita por screenshot nesta rodada.

## Classificação

| Item | Estado |
|---|---|
| Identidade visual e responsividade no CSS | APROVADO (estático) |
| Núcleo protagonista e resposta central | APROVADO (DOM/estático) |
| Conversa fora do menu e transcrição preservada | APROVADO (DOM/estático) |
| Clique nos 10 cartões e 44 ações | APROVADO (jsdom) |
| Boot sem menu antes do bloqueio | APROVADO (estático) |
| Toque real, microfone, voz e instalação | NÃO TESTADO (sem aparelho) |
| Desempenho/FPS no Poco X7 | NÃO TESTADO (sem medição) |

## Build 1.40.0

- Arquivo: `jarvis-nova-1.40.0-10400.apk`.
- Tamanho: 81.404.118 bytes.
- SHA-256: `307245cfcde586f92dc4122d24a539996ad7be8afe237226da075b0c6796dffb`.
- `aapt`: `com.jarvis.nova`, 1.40.0, versionCode 10400, minSdk 26, targetSdk 34, compileSdk 35.
- `apksigner`: assinatura debug/CI verificada.
- Assets no APK: `VERSAO_APP = '1.40.0'`, `v1.40.0` e `.modo-btn[data-modo]`.
- O APK não foi instalado nem executado em aparelho físico.
