# Bloco 121 — limpeza dos registros anteriores à máscara

**Versão:** 1.98.0+19800
**Data:** 25 de novembro de 2026

## O que foi feito

Nada foi apagado. Os registros antigos foram **relidos e regravados pela
máscara**, uma vez só, preservando conversas, datas, origens e ações — apenas a
sequência de 4 a 8 dígitos virou `[oculto]`.

### Conversas e rascunho

`ConversaStore.abrir()` chama `_sanearAntigos()`:

- se a marca `jarvis.mascara.antigos.v1` já existe, não faz nada;
- senão relê todas as conversas salvas (`jarvis.conversas.v1`) e as regrava pela
  mesma rotina de gravação de hoje, que mascara título e mensagens;
- mascara também o rascunho (`jarvis.rascunho.v1`);
- grava a marca para não repetir.

Como `abrir()` é o caminho de toda tela que lê conversas (início, conversa,
histórico), a limpeza acontece na primeira abertura do app depois da
atualização.

### Histórico de execuções

`JarvisFundo.sanearHistorico(context)`, chamado no `onCreate` do `MainActivity`:

- percorre `jarvis_fundo` / `historico_acoes` e reescreve cada registro com
  `JarvisSegredo.ocultarRegistro` (pedido e mensagem sem PIN);
- mascara também `ultima_acao` e `ultimo_resultado`;
- marca `mascara_pin_v1` para não repetir.

Além disso, `JarvisFundo.anotar` agora reescreve cada registro antigo ao copiar
a lista, então mesmo que a abertura do app não aconteça, o primeiro comando
novo já limpa os anteriores.

## Por que mascarar em vez de apagar

- O histórico serve para explicar o que foi feito; apagar tudo perderia essa
  explicação sem ganho de privacidade — o PIN sai nos dois casos.
- As conversas são conteúdo seu: apagar seria irreversível e não foi pedido com
  essa clareza (“apague ou limpe”). A limpeza entrega o objetivo — nenhum PIN
  antigo no disco — sem destruir o resto.
- Se você preferir apagar de fato, os caminhos continuam existindo: “limpar
  histórico” na tela do histórico de voz e apagar conversa no histórico.

## Verificações feitas

- `flutter test test/conversa_store_test.dart` — dois testes novos: conversa e
  rascunho antigos com PIN saem mascarados **no disco** (o JSON gravado não
  contém mais `4321` nem `87654321`), e a limpeza não repete nem mexe em
  conversa salva depois da marca.
- `flutter analyze` — sem problemas.
- `flutter test` — suíte completa.
- `python3 tests/test_bloco_121.py` — contrato (limpeza nas duas pontas, marcas,
  ausência de apagamento, testes, versão e docs).
- Suíte Python inteira.

## Limites

- Sem aparelho nesta sessão: a limpeza do Android foi conferida por leitura de
  código e contrato; a das conversas, por teste com armazenamento simulado.
- A limpeza roda uma vez. Se algum registro antigo for restaurado de um backup
  feito antes da 1.95.0, ele não passa pela limpeza de novo — a máscara vale na
  próxima gravação.
