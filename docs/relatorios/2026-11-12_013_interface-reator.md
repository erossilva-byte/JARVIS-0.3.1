# Ajuste 013 — Interface nova com núcleo de reator

Data: 2026-11-12
Branch: `work/1.48.0-fase2-consolidacao`

## O que mudou

Duas camadas novas, carregadas por último, sem tocar no que já existia:

- `nucleo_v3.js` — motor de desenho próprio (Canvas 2D, sem dependência) que anima um reator
  de arco: esfera de malha em wireframe com rotação em três eixos, três anéis giroscópicos
  com marcações radiais, satélites em órbita, varredura de radar e miolo luminoso que cresce
  com o nível do microfone (lido de `--nv`, a mesma medida que já alimenta as ondas de voz).
- `nucleo_v3.css` — pele visual da tela inteira: fundo preto-azulado com grade fina, painéis
  de vidro, tipografia espaçada, botões com foco visível, cartões de transcrição e a
  transcrição reorganizada em coluna (antes o cabeçalho e a lista ficavam lado a lado e
  espremiam o texto num bloco estreito).

Escolhas de desempenho, porque o pedido era "sem travamentos":

| Medida | Valor no código |
|---|---|
| Teto de quadros | 60 fps (descarta passo menor que 15,5 ms) |
| Passo de tempo máximo | 64 ms por quadro (engasgo não salta o desenho) |
| Densidade de pixels | limitada a 2 |
| Aba em segundo plano | animação suspensa por `visibilitychange` |
| Movimento reduzido | respeita `prefers-reduced-motion` (sem rotação, só respiração) |
| Tela estreita | menos meridianos, menos satélites, sem marcações finas |
| Dependências | nenhuma (sem three.js, sem download) |

Os estados do assistente já existentes (`body[data-state]`) mudam a cor e a velocidade do
núcleo: `idle` ciano, `listening` azul, `thinking`/`processing` âmbar, `speaking` verde,
`error` vermelho. Um `MutationObserver` acompanha a troca de estado, sem polling.

## Dois defeitos encontrados e corrigidos no próprio trabalho

1. **Núcleo não iniciava sozinho.** O `arrancar()` dependia de um único `DOMContentLoaded`;
   quando a tela era montada depois, o canva ficava parado e o diagnóstico dizia
   "núcleo não iniciado". Corrigido com tentativas idempotentes (`load`, 120/400/1200/2600 ms
   e um observador de mutação do `body`). Medido na tela real: `ativo: true`.
2. **Brilho lavava a malha.** O primeiro desenho usava um gradiente branco de raio 3,2× que
   apagava o wireframe. Reduzido para 2,8× com paradas de cor por estado, contorno do miolo e
   ponto de luz pequeno; a malha passou a ler como instrumento e não como mancha clara.

O teste de empacotamento (`tests/test_empacotamento.py`) também apontou o que faltava: os
arquivos novos precisavam entrar no workflow Android e no pacote Windows. Foram incluídos em
`.github/workflows/{ci,ci-android-auditoria,build-apk,release-apk}.yml` e em
`package.json` (`build.files`).

## Evidência

| Verificação | Resultado |
|---|---|
| `npm run test:all` | **exit 0**, 2.353 verificações aprovadas |
| `node tests/test_interface_dom.js` | exit 0, 80 verificações de DOM |
| `node tests/test_botoes_honestos.js` | exit 0 |
| `node tests/test_diag_dom.js` / `test_utilidades_dom.js` | exit 0 |
| `python3 tests/test_empacotamento.py` | exit 0 (4 grupos, inclui workflow e pacote Windows) |
| `node --check nucleo_v3.js` | sintaxe válida |
| Tela real (navegador, servidor local) | núcleo `ativo: true`, 284×284, estado `listening`, ~27 fps no navegador de nuvem (limitado por ele, não pela página) |
| Transcrição aberta na tela real | `modo-conversa: true`, área 820×575, cabeçalho em cima e lista abaixo |

Nenhum identificador foi renomeado e nenhum elemento foi removido: os 80 testes de DOM que
dependem de `#hud`, `#chat`, `#btn-transcricao`, `#resposta-atual` e das dez `.area-card`
continuam passando, e os botões seguem ligados aos mesmos ouvintes.

## O que não foi verificado

- **Aparelho físico:** sem Android SDK nem o Poco X7, nada foi medido em celular. Os 60 fps e
  o consumo são limites impostos em código, não medidos em hardware. Gate B continua não feito.
- **Flutter nativo:** o prompt pede interface 100% Flutter com WebView proibida. Esta entrega
  é a camada visual do app que existe hoje, que roda em WebView. Migrar a interface para
  Flutter nativo é outro projeto, com outro escopo e outro risco — não foi feito e não pode
  ser declarado feito.
- **Publicação:** os arquivos grandes (`index.html`, `style.css`, `app.js`) não puderam ser
  reenviados pela integração do GitHub nesta sessão; a mudança de `index.html` (duas linhas:
  folha de estilo, canva e script) está aplicada localmente.

## Revisão em celular (mesma data)

Revisão feita nos quatro estados principais (espera, ouvindo, pensando, falando) e no erro,
com 390×844 e 360×740:

| O que foi medido | Antes | Depois |
|---|---|---|
| Núcleo em 390 px de largura | 270 px | 234 px (`min(60vw, 250px)`) |
| Núcleo em 360 px de largura | 270 px | 209 px (`min(58vw, 250px)`) |
| Transbordo horizontal | nenhum | nenhum (390 e 360) |
| Transcrição em 360 px | coluna estreita | 344×521, cartões de largura cheia |
| Botões visíveis abaixo de 30 px de altura | 2 | 0 (`min-height: 32px`) |
| Rótulo em inglês na tela inicial | `QUICK COMMANDS` | `COMANDOS RÁPIDOS` |

Cores por estado, medidas no `chip-estado` pela cor computada: espera `rgb(127,158,179)`,
ouvindo `rgb(147,197,253)`, pensando `rgb(252,211,77)`, falando `rgb(110,231,183)`, erro
`rgb(252,165,165)`. No núcleo, cada estado também tem paleta e velocidade próprias
(`PALETAS` em `nucleo_v3.js`), e não só o rótulo.

Espaçamentos apertados no celular: topo em 10 px, relógio a 2,5 rem (2,1 rem abaixo de 381 px),
chips com 4–9 px de respiro, botões de modo menores, rodapé com `env(safe-area-inset-bottom)`
e campo de texto a 15,5 px (evita o zoom automático do navegador em iOS).

O que continua valendo: nada disso foi visto em aparelho físico; as larguras foram conferidas
no navegador com viewport de celular, não no Poco X7.
