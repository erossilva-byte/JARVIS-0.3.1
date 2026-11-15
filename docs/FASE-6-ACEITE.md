# Fase 6 — memória e Obsidian (entrega para aprovação)

**Branch:** `work/1.48.0-fase2-consolidacao`
**Estado:** núcleo entregue e verificado no que este ambiente permite. Falta o cofre via SAF e a
sincronização bidirecional real com o Obsidian, que dependem de aparelho e de seletor de pasta.

## O que existe de verdade

| # | Item | Estado | Evidência |
|---|---|---|---|
| 1 | Cofre local de notas com título, tema, tags, importância e datas | **Atendido** | `core/memoria.dart`, `services/memoria_store.dart` |
| 2 | Leitura de Markdown com frontmatter e corpo | **Atendido** | `lerMarkdown`; teste cobre `---` no corpo |
| 3 | Ida e volta Markdown preservando chaves desconhecidas | **Atendido** | `escreverMarkdown` + teste de round-trip |
| 4 | Importação com repetição, conflito e nota nova | **Atendido** | `importarMarkdowns`; conflito não sobrescreve |
| 5 | Busca lexical com motivo explicado | **Atendido** | `buscarNotas`; motivo no resultado e na tela |
| 6 | Recência, importância e uso entram na pontuação | **Atendido** | pesos fixos em `memoria_busca.dart` |
| 7 | Contexto com orçamento de caracteres | **Atendido** | `contextoRelevante`; teste de orçamento |
| 8 | Citação das notas usadas na conversa | **Atendido** | campo `fontes` preenchido; “O que lembrei” na bolha |
| 9 | Uso registrado só nas notas enviadas | **Atendido** | `registrarUso`; teste garante que a data não muda |
| 10 | Tela de memória com busca, edição, exclusão e importação | **Atendido** | `MemoriaPage` + testes de widget |
| 11 | Busca semântica neural / paráfrase ampla | **Não entregue** | hoje é lexical determinística; a tela diz isso |
| 12 | Cofre via SAF (pasta do Obsidian no Android) | **Atendido no código** | `ACTION_OPEN_DOCUMENT_TREE` + permissão durável + leitura `.md`; teste estático e de widget |
| 13 | Sincronização bidirecional com Obsidian | **Atendido no código** | envio/recebimento por hash do corpo, escrita via SAF, conflito preservado; 13 casos puros + 8 de serviço |
| 14 | Versionamento de nota e restauração | **Não entregue** | o legado tem; a interface ainda não |

## Como a busca funciona

1. Texto normalizado (minúsculas, sem acento e sem pontuação).
2. Palavras vazias removidas; um dicionário fechado de sinônimos comuns em português agrupa
   termos equivalentes.
3. Cada termo e seus trigramas são projetados em 128 dimensões por hash FNV-1a — determinístico,
   sem rede e sem custo.
4. A pontuação combina similaridade de cosseno (50%), correspondência literal em título, tag ou
   texto (28%), importância (7%), recência de 30 dias (10%) e uso (5%).
5. Resultado sem palavra em comum só entra com similaridade alta; um corte relativo impede que
   uma nota forte arraste notas fracas para o envio.
6. O envio à IA inclui as notas como mensagem de sistema com a instrução de dizer quando elas não
   bastarem — nunca o cofre inteiro e nunca “notas recentes” sem relação com a pergunta.

## Limites que a interface declara

- A busca é por palavra, não por significado: paráfrase distante pode não encontrar a nota. O
  motivo do resultado fica visível justamente para isso não parecer magia.
- No Android a pasta do Obsidian pode ser conectada com permissão do sistema (SAF) e importada
  quantas vezes quiser. Fora do Android, a importação é colar Markdown.
- A sincronização é uma ação explícita (“Sincronizar”), não um observador em tempo real; conflito
  nunca é sobrescrito e nota apagada na pasta continua no aparelho até o usuário decidir.
- Sem apagar nota alheia: conflito de título com texto diferente é reportado e preservado.
- Nada de sincronização automática: quem move arquivo hoje é o usuário.

## Verificação

```
dart run tool/memoria_test.dart   → OK (Markdown, importação, busca, motivo, orçamento, envio, JSON)
flutter analyze                   → No issues found!
flutter test                      → 53 testes, All tests passed!
npm run verificar                 → 4 de 4 etapas (ver relatório 045)
```

## Como aprovar

- Aprovar a Fase 6 como **parcial**, com SAF e sincronização registrados como pendência 7B; ou
- manter a fase aberta até existir cofre em pasta real e sincronização testada.

Nenhuma das opções dispensa rodar no aparelho: importar um cofre real e conferir a citação numa
conversa de verdade ainda é a prova que falta.
