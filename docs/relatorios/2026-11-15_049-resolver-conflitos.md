# Ajuste 049 — tela para resolver conflitos (2026-11-15)

## Por que

O conflito era preservado, mas o usuário só via uma lista de nomes e precisava editar um dos lados
por fora. Faltava mostrar as duas versões lado a lado e deixar a escolha explícita — sem que a
perdedora fosse descartada.

## Como ficou

- `ConflitosPage` abre ao tocar em “Sincronizar” quando há conflito. Cada conflito mostra o caminho,
  o motivo e as duas versões: **Neste aparelho** e **Na pasta do Obsidian** (lado a lado em tela
  larga, empilhadas no celular), com o texto selecionável e rolagem própria.
- Dois botões: “Manter a do aparelho” e “Manter a da pasta”. Antes de aplicar, um diálogo explica o
  que vai acontecer.
- A versão escolhida passa a valer. A outra **nunca é apagada**: vira uma nota de backup no cofre,
  sem caminho, com título “(versão do conflito)”. Como não tem caminho, a sincronização seguinte a
  envia à pasta como arquivo novo — em vez de sobrescrever o caminho que estava em disputa.
- Escolher o aparelho grava o arquivo na pasta antes de mexer no cofre. Se a escrita falhar, nada
  muda, nenhuma nota é salva e o aviso diz que as duas versões continuam como estavam.
- Resolver o mesmo conflito de novo reaproveita o mesmo id de backup (derivado do caminho e do
  conteúdo), então não acumula cópias iguais.
- Ao voltar da tela, o cofre relê a pasta em silêncio e atualiza o cartão, mesmo que o usuário tenha
  resolvido só parte dos conflitos.

## Verificação

```
dart run tool/memoria_conflito_test.dart      → OK (escolha, backup, ids estáveis)
flutter test test/resolvedor_conflito_test.dart → 3 testes, All tests passed!
flutter test test/conflitos_page_test.dart      → 1 teste, All tests passed!
flutter test                                   → 74 testes, All tests passed!
flutter analyze                                → No issues found!
npm run verificar                              → ver relatório do ajuste
```

O teste de widget abre a tela pelo fluxo real de navegação, confere que as duas versões aparecem,
escolhe a do aparelho, confirma e verifica que o arquivo foi gravado **e** que o texto da pasta
continua no cofre como backup. Os testes de serviço cobrem a escolha da pasta e a falha de escrita
sem efeito colateral.

## Limites

- Sem aparelho: a tela nunca foi vista num celular de verdade. O layout lado a lado é decidido pela
  largura (620 px), mas telas estreitas não foram inspecionadas visualmente.
- O backup cresce como nota separada a cada conflito distinto; não há expurgo automático nem tela
  para gerenciar backups.
- A escolha é por conflito; não existe “aplicar a todos”.
