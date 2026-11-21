# 059 — Fase 10A: importador `.cad` do CADeSIMU (somente leitura)

**Data:** 2026-11-17 · **Versão:** 1.48.0 · **Branch:** `work/1.48.0-fase2-consolidacao`

## O que foi entregue

O módulo **CADeSIMU e elétrica** agora abre um arquivo `.cad` escolhido pelo seletor do Android e
mostra:

- nome, tamanho, quantidade de registros e presença do rodapé `#$$$`;
- contagem de símbolos, fios, junções, textos e redes geométricas;
- a geometria dos fios e as junções `4001` desenhadas em escala;
- os textos livres e a lista dos símbolos, com tipo, rótulo e posição.

A tela repete o limite em três lugares: **somente leitura; não edita, não simula e não gera netlist
elétrica**. Não existe botão de salvar, exportar ou simular. O arquivo não é enviado a nenhum
provedor nem gravado de volta.

## Como foi feito

- `flutter_app/lib/services/cadesimu_cad.dart`: porte da sonda de referência
  (`tools/cadesimu_sonda.py`) para Dart. Lê o texto ISO-8859-1, separa registros normais, texto tipo
  `8` sem `#` inicial e rodapé, e confere a **ida e volta byte a byte** antes de aceitar o arquivo.
  Campos desconhecidos são preservados, não interpretados.
- `flutter_app/lib/services/cadesimu_page.dart`: tela nativa, com aviso, métricas, geometria e
  inventário limitado aos primeiros 100 símbolos.
- `flutter_app/android/MainActivity.kt`: método `abrirCad` no canal já existente
  `com.jarvis.nova/memoria`, usando `ACTION_OPEN_DOCUMENT` com leitura temporária. Não pede
  `READ_EXTERNAL_STORAGE` nem `MANAGE_EXTERNAL_STORAGE`; recusa arquivo sem extensão `.cad`, vazio
  ou acima de **2 MB**.
- `flutter_app/lib/pages.dart`: botão “Abrir importador .cad (somente leitura)” no módulo.

## O que foi verificado

| Verificação | Resultado |
|---|---|
| `flutter analyze` | Sem problemas |
| `flutter test test/cadesimu_cad_test.dart test/cadesimu_page_test.dart` | 9 testes passaram |
| `python3 tests/test_cadesimu_flutter.py` | OK |
| `python3 tests/test_cadesimu_sonda.py` | OK (sonda de referência preservada) |
| Ida e volta da amostra sintética | Byte a byte idêntica |
| Latin-1 e campo desconhecido | Preservados |
| Arquivo malformado | Recusado com mensagem |
| Cancelar o seletor | Sem erro e sem resumo |
| Permissão ampla de armazenamento | Ausente no código Android |

## O que não foi testado

- **Aparelho Android físico**: o seletor real, a leitura de um `.cad` de verdade e a renderização
  da geometria não foram vistos em tela. O APK foi construído e o código nativo foi conferido por
  leitura e compilação, não executado.
- **CADeSIMU oficial**: nenhum arquivo real foi aberto no programa nesta fase. A importação não
  altera o arquivo, então não há resultado para o CADeSIMU abrir.
- **Netlist elétrica**: não é gerada. As “redes geométricas” ligam fios por extremidade exata e
  junção `4001`; pinos de símbolos não entram porque dependem da classe e da orientação.
- **Exportação `.cad` (Fase 10B)**: continua bloqueada. Falta a tabela completa de pinos por classe
  e orientação e a prova de abertura no CADeSIMU oficial, como o estudo 058 concluiu.

## Próximo gate

Fase 10B só começa quando existir tabela de pinos validada e um corpus fixo aberto e simulado no
CADeSIMU oficial (Windows/Wine). Até lá, o app permanece dizendo que **não gera** `.cad` nativo.
