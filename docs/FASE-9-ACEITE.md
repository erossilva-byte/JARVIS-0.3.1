# Fase 9 — Arquivos de texto (entrega parcial declarada)

**Branch:** `work/1.48.0-fase2-consolidacao`
**Escopo desta entrega:** arquivos de texto na **pasta privada do app** — criar, ler, editar,
renomear e apagar, com caminho confinado e sem rede. **Execução de código não foi entregue** e não é
anunciada em lugar nenhum. Esta é uma entrega parcial da Fase 9, não a fase inteira.

## O que existe de verdade

| # | Item | Estado | Evidência |
|---|---|---|---|
| 1 | Pasta isolada nos documentos do app | **Atendido no código** | `path_provider` + `JarvisArquivos`; plugin não exercitado no aparelho |
| 2 | Criar, ler, editar, renomear e apagar `.txt` | **Atendido** | teste puro com pasta temporária real; 8 testes de widget |
| 3 | Nome seguro, sem barra, caminho ou nome reservado | **Atendido no núcleo** | `validarNomeArquivo`; `../` e `a/b` recusados antes do disco |
| 4 | Caminho final confinado à raiz | **Atendido no núcleo** | `caminhoSeguroNaPasta`; tentativa fora da pasta recusada |
| 5 | Limites de 200 arquivos e 512 kB por texto | **Atendido no núcleo** | `limiteArquivos`, `limiteBytesArquivo` |
| 6 | Sem acesso a Downloads, Obsidian ou pasta escolhida | **Atendido no código** | só a pasta privada; tela declara; teste estático |
| 7 | Sem envio para a rede | **Atendido no código** | nenhum `http`/socket; tela declara |
| 8 | Aviso ao sair com texto não salvo | **Atendido** | diálogo “Descartar alterações?”; teste de widget |
| 9 | Sandbox de execução de código | **Não entregue, e a promessa foi removida** | Dart não oferece isolamento de SO; catálogo, gaveta e tela declaram a ausência |
| 10 | Pasta externa via SAF / Downloads | **Não entregue** | exigiria seletor de pasta e permissão durável; fica para outra entrega |
| 11 | Pasta e arquivos no Poco X7 | **Pendente** | `path_provider` nunca rodou neste ambiente |

## Por que o sandbox de código não foi entregue

A Fase 9 pede “execução isolada”. Rodar código arbitrário dentro do próprio app **não é isolamento**:
não há processo separado, limite de memória, tempo máximo ou bloqueio de sistema de arquivos em Dart
puro. Entregar um botão que executasse código e chamasse isso de sandbox seria uma promessa falsa —
exatamente o que o projeto proíbe. O recorte útil e verificável é o arquivo de texto; o sandbox de
código continua pendente e declarado.

## Verificação

```
dart run tool/arquivos_test.dart           → OK (pasta temporária real)
flutter test test/arquivos_page_test.dart  → 8 testes, All tests passed!
python3 tests/test_arquivos_flutter.py     → OK (estático)
flutter test                               → 107 testes, All tests passed!
flutter analyze                            → No issues found!
npm run verificar                          → 4 de 4 etapas, 2.380 verificações
```

## Limites

- **O plugin de pasta não foi exercitado**: criar a pasta nos documentos do app só se confirma no
  aparelho; aqui o teste usa uma pasta temporária real, mas não o `path_provider`.
- Texto puro, sem Markdown renderizado, anexos, PDF, DOCX ou planilha.
- Não há lixeira: apagar remove na hora, com confirmação.
- Não há backup, sincronização nem exportação; os arquivos ficam só neste aparelho.
- A tela não foi inspecionada visualmente; os testes cobrem o comportamento, não o layout.

## Correção de promessa (ajuste 057)

O catálogo dizia “Assistência de código e execução isolada”. Foi corrigido para **“Programação (sem
execução)”**, a gaveta para **“Código sem execução”** e a tela do módulo passou a dizer **“Execução
de código não disponível”**, explicando que não há sandbox, terminal ou permissão para rodar
programas. Um teste de widget e a verificação estática impedem a frase antiga de voltar.
