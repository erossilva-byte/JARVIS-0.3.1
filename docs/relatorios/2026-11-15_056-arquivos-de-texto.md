# Ajuste 056 — Fase 9: arquivos de texto (2026-11-15)

## Por que

O Flutter não tinha nenhuma tela de arquivos; o módulo abria o catálogo genérico. A Fase 9 pede
arquivos **e** sandbox. Comecei pelo recorte que dá para provar: texto confinado à pasta privada.

## Como ficou

- **Pasta isolada** dentro dos documentos do app (`JarvisArquivos`), criada na abertura da tela.
- **Operações reais**: criar, ler, editar, renomear e apagar `.txt`. A extensão é acrescentada
  quando falta; nomes repetidos são recusados.
- **Caminho confinado**: o nome passa por validação (sem `/`, `\`, `:`, `*`, `?`, `"`, `<`, `>` ou
  `|`) e o caminho final é normalizado e conferido com `isWithin` contra a raiz. `../fora.txt`,
  `a/../../fora.txt` e caminho absoluto externo são recusados antes de tocar no disco.
- **Limites**: 200 arquivos e 512 kB por texto, medidos em bytes UTF-8. Texto acima disso é recusado
  com o tamanho atual.
- **Edição com proteção**: sair do editor com texto não salvo abre “Descartar alterações?”; salvar
  informa sucesso; erro de escrita aparece na tela, não é engolido.
- **Nada de rede**: a tela não importa `http` nem socket; a lista não abre pasta externa e segue
  links simbólicos como `false`.
- **Sem sandbox de código**: a tela diz explicitamente que não há execução, terminal ou permissão
  para rodar programas. O motivo está no aceite: Dart não oferece isolamento de SO, e chamar isso de
  sandbox seria mentira.

## Verificação

```
dart run tool/arquivos_test.dart           → OK
flutter test test/arquivos_page_test.dart  → 8 testes, All tests passed!
python3 tests/test_arquivos_flutter.py     → OK (estático)
flutter test                               → 103 testes, All tests passed!
flutter analyze                            → No issues found!
npm run verificar                          → 4 de 4 etapas, 2.380 verificações
```

O teste puro usa uma pasta temporária real: cria, lê com acentuação, lista, atualiza, renomeia,
apaga, ignora `.md` e prova que `../` não cria arquivo fora. Os testes de widget cobrem lista vazia,
criação com `.txt`, recusa de nome com caminho, edição, renomeação, exclusão com confirmação,
indisponibilidade da pasta e saída com texto não salvo.

## Limites

- `path_provider` não rodou no aparelho; a pasta real do Android não foi criada nem inspecionada.
- Sem SAF: não abre Downloads, Obsidian ou pasta escolhida pelo usuário.
- Sem lixeira, backup, sincronização ou exportação.
- Sandbox de código não existe; a Fase 9 continua parcial.
