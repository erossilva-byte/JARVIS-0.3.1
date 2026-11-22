# Ajuste 020 — cabeçalho do cartão do núcleo em tela pequena

Data: 2026-11-13
Branch: `work/1.48.0-fase2-consolidacao`

## Defeito

No Ajustes ▸ Voz, o cartão "Aparência do núcleo" tinha o selo de texto e o título na mesma
linha: `APARÊNCIA DO NÚCLEO` era um `span` inline com `letter-spacing` de 0,28 em, e o
`<b>Estilo do núcleo central</b>` continuava na mesma caixa de linha. Em 360 px os dois se
sobrepunham: medido, selo em y=740 (12 px de altura) e título começando em y=734.

## Correção

Em `nucleo_v3.css` (carregado por último): selo e título passam a ser blocos, cada um na sua
linha, com `min-width: 0` no contêiner e tamanhos levemente menores em telas de até 420 px.
Nada mais do cartão mudou — o seletor de estilo, a prévia e o selo HUD continuam iguais.

## Medição depois

| Medida | 360×740 | 320×700 |
|---|---|---|
| Selo (y, altura) | 733, 12 px | 749, 12 px |
| Título (y, altura) | 748, 18 px | 764, 18 px |
| Sobreposição (interseção de retângulos) | não | não |
| Selo HUD fora da borda | não | não |
| Texto cortado | 0 | 0 |
| Rolagem horizontal da página | nenhuma | nenhuma |

## O que não foi verificado

- Só viewport de navegador (WebView), não aparelho físico.
- Outros cartões com o mesmo padrão de selo + título não foram alterados nem medidos além da
  varredura do ajuste 018, que já rodou em 360 e 320.
