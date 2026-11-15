# Ajuste 045 — memória local com citação na conversa (Fase 6)

## Por que

A Fase 5 deixou o campo `fontes` pronto, mas nada o preenchia: a conversa não tinha de onde
lembrar. Esta entrega traz o cofre local de notas, a busca com motivo e a citação real.

## O que foi construído

### Núcleo puro (testável sem Flutter)

- `core/memoria.dart`: modelo da nota (título, texto, tema, tags, importância, datas, usos,
  chaves extras), JSON tolerante e Markdown com frontmatter.
- `lerMarkdown`: só o primeiro bloco entre `---` é frontmatter; um `---` no corpo não come o texto
  seguinte — a perda corrigida no legado em 1.42 não volta.
- `escreverMarkdown`: gera frontmatter estável e preserva chaves desconhecidas de outros editores.
- `importarMarkdowns`: título repetido com texto igual conta como repetição; com texto diferente
  vira conflito e **não sobrescreve**.
- `core/memoria_busca.dart`: normalização, sinônimos fechados, embedding determinístico de 128
  dimensões por FNV-1a, cosseno, pontuação composta (similaridade, literal, importância, recência,
  uso), corte relativo, motivo do resultado e contexto com orçamento.
- `montarMensagens`: injeta as notas como mensagem de sistema com a instrução de dizer quando não
  bastarem; sem contexto, o histórico vai intacto.

### Interface

- `services/memoria_store.dart`: persistência em `shared_preferences`, uso registrado só nas notas
  enviadas e sem mexer na data de atualização.
- `services/memoria_page.dart`: lista, busca com motivo, editor (título, texto, tema, tags,
  importância), exclusão com confirmação, cópia do Markdown e importação colando Markdown.
- A gaveta passou a abrir a memória de verdade em vez do aviso de módulo não migrado.
- A conversa busca a memória a cada envio, cita as notas usadas em “O que lembrei” e registra uso.

## Verificação

- `dart run tool/memoria_test.dart` — 11 blocos: frontmatter, `---` no corpo, round-trip com chave
  desconhecida, repetição/conflito, busca com acento/caixa/sinônimo, motivo, orçamento, envio ao
  provedor e JSON inválido.
- `flutter test` — 53 testes (10 novos: 6 do cofre e 4 de widget).
- `flutter analyze` — nenhum problema.
- `npm run verificar` — 4 de 4 etapas.
- O wrapper `tests/test_dart_core.py` agora roda os quatro testes puros (buffer, SSE, conversa,
  memória) e também procura o Dart dentro do Flutter em `/tmp`; antes ele avisava “não encontrado”
  e a suíte passava sem executar o núcleo.

## Limites

- A busca é lexical, não neural: paráfrase distante pode escapar. A tela diz isso e mostra o
  motivo de cada resultado.
- Não há leitura da pasta do Obsidian (SAF) nem sincronização automática; a importação é por
  colagem de Markdown. Isso continua como pendência 7B.
- Versionamento/restauração de nota do legado não foi portado.
- Nenhuma nota real de um cofre grande foi medida; a busca foi exercitada com notas sintéticas.
