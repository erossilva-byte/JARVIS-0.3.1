# Ajuste 050 — revisar e limpar backups de conflito (2026-11-15)

## Por que

Cada conflito resolvido guardava a versão perdedora como nota separada, mas não havia onde vê-las
nem como se livrar delas. Sem isso, o cofre acumularia cópias invisíveis para sempre.

## Como ficou

- `BackupsPage` (“Backups de conflito”) lista só as notas de backup, com data e três linhas de
  prévia. O atalho fica na barra da tela de memória, com contador no ícone quando há backups.
- **Abrir backup** leva ao editor normal, para ler ou copiar o texto.
- **Restaurar como nota** cria uma nota comum com o texto e o título sem o sufixo, e remove o
  backup. Nada vai para a pasta sozinho; a sincronização seguinte trata a nota como local.
- **Apagar backup** pede confirmação e remove só do aparelho — a pasta do Obsidian não é tocada.
- **Apagar todos os backups** pede confirmação com a contagem e não encosta nas notas atuais.
- Os backups agora carregam a marca `origem: backup-conflito` nas chaves extras. Backups criados
  antes da marca continuam reconhecidos pelo prefixo de id `conflito-`, então nada fica órfão.

## Verificação

```
flutter test test/backups_page_test.dart       → 5 testes, All tests passed!
flutter test test/resolvedor_conflito_test.dart → 3 testes, All tests passed!
flutter test                                   → 79 testes, All tests passed!
flutter analyze                                → No issues found!
npm run verificar                              → ver relatório do ajuste
```

Os testes cobrem: reconhecimento por marca e por prefixo antigo, restauração que vira nota normal
e remove o backup, exclusão com confirmação que preserva a nota oficial, limpeza total que mexe só
nos backups e o atalho com contador na tela de memória.

## Limites

- Nada foi visto num aparelho: a tela não foi inspecionada visualmente e o APK não foi compilado
  aqui.
- Não há expurgo automático por idade nem limite de quantidade: backups só saem por ação do
  usuário, o que é intencional para não apagar versão sem pedido.
- Restaurar não tenta reenviar o texto ao caminho original; isso fica para a sincronização normal,
  que cria arquivo novo em vez de sobrescrever.
