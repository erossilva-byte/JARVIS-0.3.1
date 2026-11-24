# Bloco 111 — regras de enquadramento do palco, com prévia sem internet

Data: 2026-11-24 · versão **1.89.1**

## 1. Regras editáveis no núcleo (`core/palco.dart`)

- `RegraMoldura`: altura em fração da tela (0,15 a 0,62) e `cabeInteira`
  (inteira ou recorte), com `copiarCom`, JSON e leitura tolerante.
- `RegrasPalco`: uma regra para cada moldura — capa larga, retrato, quase
  quadrada, capa de vídeo e capa de notícia — mais `limiarLargo` e
  `limiarEstreito`. `comRegra` troca uma regra sem tocar nas outras;
  `copiarCom` contém os limiares na faixa e impede que o largo fique abaixo do
  estreito; `deJson` aceita texto ou mapa e volta ao padrão quando o conteúdo
  está estragado.
- `molduraDoItem(item, {regras})` passou a usar as regras; o padrão reproduz
  exatamente o enquadramento da 1.89.0, então nada muda para quem não editar.

## 2. Editor com prévia offline (`services/palco_regras_page.dart`)

- `PreviaMoldura` desenha a caixa com a altura e a proporção efetivas e um
  retângulo interno com gradiente e ícone; em "inteira" usa `AspectRatio`, em
  "recorta" preenche. Nenhuma chamada de rede.
- Controles: chips por tipo de moldura, `Slider` de altura, chips de recorte e,
  para as molduras de foto, os dois limiares. Legenda ao vivo com percentual,
  recorte e tipo; "Salvar regras" devolve as regras; "Voltar ao padrão" reseta.

## 3. Ligação e armazenamento

- `services/palco_regras_store.dart`: chave `jarvis.palco.regras.v1`, limite de
  4 kB, `carregar`, `salvar` e `voltarAoPadrao`.
- `services/palco_page.dart`: carrega as regras ao abrir, botão "Regras do
  palco", passa as regras para `_PalcoDeMidia` e avisa se a gravação falhou.

## Verificação

- `python3 tests/test_bloco_111.py` — OK.
- `tool/palco_regras_test.dart` (regras, limiares, JSON e moldura) e os testes
  de tela/armazenamento do editor entram no CI.
- `flutter analyze`, `flutter test` e os demais contratos rodam no CI do commit.

## Limites

- A prévia é relativa à tela do aparelho; não substitui ver a mídia real.
- Sem teste em aparelho físico nesta sessão.
