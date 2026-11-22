# Ajuste 018 — Painéis em telas pequenas (360 e 320 px)

Data: 2026-11-13
Branch: `work/1.48.0-fase2-consolidacao`

## O que foi conferido

Os 14 painéis do app, abertos pelo caminho real (botões laterais, botão de registro,
atalho de utilidades) com viewport de navegador em **360×740** e **320×700** — medida, não
impressão. Para cada painel, quatro verificações automáticas:

1. elementos visíveis ultrapassando a borda do painel (descontando trilhos que rolam de
   propósito, como as abas);
2. texto cortado: `scrollWidth` maior que `clientWidth` em títulos, botões, rótulos e parágrafos;
3. selo do cabeçalho sobre o título (interseção de retângulos);
4. botões com menos de 30 px de altura ou largura;
5. rolagem horizontal da página.

Além disso, os painéis foram olhados em captura: áreas, core, informações, memória, pessoas,
arquivos, registro, sistema, tarefas, visão, configurações (IA, voz, celular, rotinas,
diagnóstico, atualização), desenvolvimento e utilidades.

## Defeitos encontrados e corrigidos

| Defeito | Onde | Correção |
|---|---|---|
| Abas não filtravam: as sete seções apareciam empilhadas | Utilidades | `display:grid` vencia o atributo `hidden`; regra `.util-secao[hidden]{display:none}` |
| Texto e campos encostando na borda do painel | Utilidades | seções sem respiro lateral; `padding: 12px 13px` em tela estreita |
| Abas encolhiam até o texto transbordar sobre a aba vizinha | Utilidades | `flex: 0 0 auto` nas abas; o trilho rola na horizontal |
| "Identificação e reconhecimento" quebrava no meio da palavra em botão de 90 px | Pessoas | botões da faixa empilhados com largura cheia em telas ≤420 px |
| Selo do cabeçalho virava uma faixa vazia de largura total | Todos os painéis | selo volta a ter a largura do próprio texto, descendo para a linha de baixo |
| Selo sobre o título e rótulo em duas linhas | Todos os painéis | corrigido no ajuste anterior (017), mantido |

## Medições depois das correções

| Medida | 360×740 | 320×700 |
|---|---|---|
| Painéis testados | 18 aberturas | 16 aberturas |
| Elementos fora da borda | 0 | 0 |
| Textos cortados | 0 | 0 |
| Selo sobre o título | 0 | 0 |
| Botões menores que 30 px | 0 | 0 |
| Rolagem horizontal da página | 0 | 0 |
| Abas de utilidades | 65–87 px, uma linha, trilho rolável | idem |
| Botões de pessoas | 334×40, uma linha cada | 294×40 |

## O que não foi verificado

- Nada em aparelho físico: a conferência é no WebView do navegador, em viewport de 360 e 320
  px. O Gate B continua não feito.
- Não foram conferidos estados com dados reais (muitas tarefas, muitos perfis, fila longa):
  as listas vazias foram as testadas.
- Painel `#painel-pc` não abriu pelo botão lateral nesta build (abriu o de memória); ficou
  fora da medição, como antes.
