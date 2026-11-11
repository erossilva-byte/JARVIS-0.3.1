# Relatório — Fase 2, ajuste 008: cofre Obsidian com escrita e leitura reais em disco

## 1. O que já existia

`memoria.js` converte o cofre local para Markdown no formato do Obsidian de duas maneiras: um
arquivo **por nota** (`arquivosMarkdown()`) ou um arquivo **por tópico** (`arquivosPorTopico()`,
gravado em `Memoria/Gostos.md`, `Memoria/Projetos.md`, …). A volta é feita por
`importarMarkdown()`, que reconhece o `jarvis_id` de cada nota, atualiza quando a versão do arquivo
é mais nova e **preserva** o que diverge em vez de sobrescrever.

No PC, a pasta do cofre é escolhida pelo usuário, guardada em `jarvis-cofre.json` e usada por
`main.js` para gravar e ler os `.md`. No Android isso depende do SAF (Fase 7B), que não existe.

## 2. O que passou a estar provado (disco de verdade)

`tests/test_memoria_md.js` ganhou uma seção que não trabalha com string em memória: cria uma pasta
temporária, grava os arquivos de tópico com `fs`, **relê do disco** e importa o conteúdo lido.

O que a verificação comprova:

- **Escrita real**: `Memoria/Gostos.md` e `Memoria/Projetos.md` existem no disco depois da gravação.
- **Leitura real**: os arquivos voltam como UTF-8 e o texto é idêntico ao que foi guardado —
  `prefiro café sem açúcar` e `atuador de 12 V no portão` atravessam a ida e a volta sem perder acento.
- **Reconstrução**: com a memória apagada, importar o que veio do disco recria as duas notas.
- **Idempotência**: importar o mesmo disco outra vez devolve `repetidas: 2` e nenhuma duplicata.

## 3. Nomes de arquivo

Testado com título hostil (`Projeto Beta/2026`) e com acento (`Álgebra Linear`):

```
estudos/algebra-linear-15h23.md
projetos/projeto-beta-2026-ozdtx.md
```

A barra **não** cria subpasta e o acento é normalizado — o nome é estável e previsível, com o fim do
id para diferenciar notas de mesmo título.

## 4. Defeito encontrado e corrigido: linha `---` no corpo apagava o resto

Reprodução (nota vinda do Obsidian com um separador horizontal, uso comum em Markdown):

```
---
title: "Com separador"
tema: gostos
---

# Com separador

antes

---

depois
```

**Antes:** `criadas: 1, ignoradas: 0, conflitos: 0` e a nota ficava só com `antes` — o trecho depois
do `---` era descartado em silêncio, sem conflito, sem aviso, sem contagem de ignoradas.

**Causa:** o recorte de blocos de `importarMarkdown()` usava uma expressão regular que encerrava o
corpo no primeiro `---` do texto. Como o resto do arquivo também não casava com o padrão de
frontmatter, era simplesmente perdido.

**Correção:** o recorte passou a ser por linhas. Um `---` só abre frontmatter quando o bloco entre
ele e o próximo `---` tem linhas `chave: valor` (ou itens/continuações indentados); qualquer outro
`---` é conteúdo. O corpo vai até o próximo frontmatter **de verdade** ou o fim do arquivo, então
separadores horizontais no meio da nota são preservados, e dois arquivos colados continuam virando
duas notas.

**Depois**, na mesma entrada: `{"criadas":1,"texto":"antes\n\n---\n\ndepois"}`.

Regressões travadas em `tests/test_memoria_md.js`: nota com frontmatter e separador no corpo, nota
sem frontmatter com separador, e dois arquivos em sequência com separador em cada um.

## 5. O que continua sem prova

- **Ponte de pasta do Electron** (`main.js`: escolher pasta, gravar, ler do cofre escolhido): exige
  Electron com janela; não foi executada aqui.
- **SAF do Android**: não implementado; o cofre em disco não existe no aparelho.
- **Sincronização automática bidirecional**: `memoria.js` sincroniza quando chamado; não há vigia de
  pasta nem observador de arquivos.

## 6. Evidência

- `node tests/test_memoria_md.js` → passa, incluindo as seções de separador `---` e de disco
  (`memoria.md: cofre em disco ok — 2 arquivo(s) gravado(s) e relido(s)`).
- `npm run test:all` → exit 0 com as verificações novas dentro da suíte.
- Reimportação do caso do separador após a correção: `{"criadas":1,"texto":"antes\n\n---\n\ndepois"}`.
