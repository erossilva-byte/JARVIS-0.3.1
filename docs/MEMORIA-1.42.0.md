# Memória semântica e Obsidian — núcleo 1.42.0 (não lançado)

## Status

O núcleo local de busca semântica, RAG, prioridade, histórico e conflito de importação
foi implementado e testado. O módulo completo de memória ainda é **parcial**: relações
entre entidades, memória de curto prazo separada, detecção de contradições e
sincronização automática bidirecional do Obsidian não estão concluídas.

Este código não substitui `memoria.js`: ele amplia o módulo existente. O formato do
cofre, os temas, as tags, a exportação Markdown e o painel continuam compatíveis.

## Como a recuperação funciona

1. O texto é normalizado (minúsculas, sem acentos e pontuação).
2. Um dicionário fechado de sinônimos em português expande termos como
   `programa`/`código`/`aplicativo` e `casa`/`residência`/`apartamento`.
3. Cada termo e seus trigramas são projetados em um vetor de 128 dimensões por
   hash FNV-1a. O vetor é normalizado; a similaridade é o cosseno.
4. A pontuação combina cosseno, correspondência literal (título, tag e corpo),
   tema provável, importância, recência e frequência de uso.
5. Resultados sem nenhuma palavra em comum só entram com cosseno alto; um corte
   relativo impede que uma nota forte arraste notas fracas para o prompt.
6. `contextoRelevante()` monta o bloco de RAG com orçamento de caracteres e registra
   o uso das notas efetivamente incluídas. Se a busca não encontrar nada, usa no
   máximo três notas recentes do tema provável; nunca manda o cofre inteiro.

O embedding é **lexical e determinístico**, não uma rede neural. Essa escolha mantém
o recurso local e sem dependência paga, mas limita a compreensão de paráfrases
complexas. Um modelo neural local pode ser adicionado depois como camada opcional,
sem alterar o contrato de `buscarSemantica()`.

## Prioridade e ciclo de vida

- `importancia`: 0 a 3, definida na nota.
- `atualizado`: recência entra na pontuação com decaimento de 30 dias.
- `usos`: incrementado quando a nota é usada pelo RAG; entra na pontuação.
- `versoes`: até três versões anteriores, com título, texto, tags e data.
- `restaurar(id, indice)`: restaura uma versão e guarda a versão substituída.
- `podar(tema, bytes)`: remove as notas mais antigas do tema até caber no orçamento,
  mediante chamada explícita.
- `apagar`/`apagarTudo`: continuam explícitos; a interface pede confirmação/PIN.

## Obsidian

- **Jarvis → Obsidian:** `arquivosPorTopico()` gera um `.md` por tema em `Memoria/`,
  com frontmatter, títulos `##`, tags e data de atualização. `main.js` grava com
  backup `.bak` antes de alterações importantes.
- **Obsidian → Jarvis:** `importarMarkdown()` aceita frontmatter opcional, arquivos
  por tópico e notas comuns. Notas com mesmo título e mesmo conteúdo são repetidas;
  mesmo título com conteúdo diferente gera um item em `conflitos` e **não sobrescreve**
  a nota interna.
- O painel informa quantos conflitos foram preservados. A resolução assistida de
  conflitos e o agendamento de sincronização automática ainda não foram implementados.
- O cofre funciona sem Obsidian; o armazenamento local continua sendo a fonte de
  verdade quando não há pasta conectada.

## Testes

```bash
node tests/test_memoria_md.js
node tests/test_memoria_semantica.js
npm run test:all
```

`test_memoria_semantica.js` verifica:

- paráfrases e sinônimos;
- remoção de stopwords e ausência de notas irrelevantes no RAG;
- determinismo do embedding e similaridade;
- registro de uso no RAG; ranking composto por importância, recência e uso;
- atualização, histórico e restauração;
- conflito de mesmo título no Obsidian sem sobrescrita;
- ausência de `eval`, `Function` e `fetch` no módulo.

## Limitações e pendências

- Sem modelo neural de embeddings nesta etapa.
- Relações entre pessoas, projetos, dispositivos e conversas ainda não formam um grafo.
- Não há detecção automática de contradições; só conflito de título na importação.
- Sincronização automática bidirecional com resolução de conflitos está pendente.
- Nenhum teste com cofre real do Obsidian, aparelho físico ou grande volume de notas
  foi executado nesta máquina.
- O APK 1.41.0 existente **não contém** estas alterações; uma nova build só deve ser
  gerada depois de decidir a versão e repetir a suíte completa.
