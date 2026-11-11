# Relatório — Fase 2, ajuste 009: arquivos e sandbox do motor do PC

## 1. O que foi sondado

O motor de arquivos do app (`arquivos_dev.js`) foi exercitado de ponta a ponta contra disco real:
criar, ler, mover, copiar, apagar, compactar e descompactar, com arquivos de verdade em diretório
temporário próprio, e não com objetos simulados.

O que a sondagem mostrou:

- **caminho fora da raiz é recusado** — `../../fora.txt` não é gravado e nada aparece fora da pasta do
  app;
- **nada é criado fora da raiz** depois de uma tentativa recusada;
- **nenhum `.tmp` sobra** no diretório após as operações.

Isso é o essencial do ajuste: o sandbox do PC barra a saída da raiz e não deixa lixo para trás.

## 2. Cobertura que faltava: o formato dos arquivos gerados

O que **não** estava coberto era o conteúdo dos arquivos que o motor produz. Gerar um PDF, DOCX,
XLSX, CSV ou ZIP e o arquivo abrir no programa de destino é uma afirmação que nunca havia sido
testada. Um arquivo gerado com estrutura errada passa em qualquer teste que só verifique se o
retorno existe.

Criei `tests/test_arquivos_dev.js` com verificação independente do próprio motor:

- **leitor de ZIP próprio**, escrito no teste: localiza o diretório central (EOCD), lê cada
  cabeçalho, descompacta o que está comprimido e **recalcula o CRC32** de cada entrada. Não usa
  nenhuma função do módulo para isso — se o módulo produzir um ZIP quebrado, o leitor do teste
  recusa;
- **parser de CSV próprio**, com suporte a aspas, aspas escapadas (`""`) e quebra de linha dentro
  do campo. O CSV gerado é reprocessado por esse parser e comparado célula a célula;
- **PDF**: assinatura `%PDF-1.4`, tabela `xref` e `%%EOF` no fim;
- **DOCX**: é ZIP válido, tem `[Content_Types].xml`, `_rels/.rels` e `word/document.xml`, o texto
  aparece escapado no XML (`&lt;tags&gt;`, `&amp;`);
- **XLSX**: é ZIP válido, tem `xl/workbook.xml` e `xl/worksheets/sheet1.xml`, nome de aba com
  escape, células `A1`/`B1` na primeira linha;
- **CSV de JSON**: vírgula dentro do campo, aspas e quebra de linha sobrevivem à ida e volta;
- **ZIP do motor**: abre no leitor independente e devolve os arquivos com acento no nome e no
  conteúdo;
- **ZIP truncado é recusado** em vez de devolver lixo;
- **`nomeSeguro`**: não deixa subir pasta (`../..`), tira caractere proibido, aplica padrão a nome
  vazio e não duplica a extensão;
- **`instrucao`**: separa ação, alvo e formato do pedido em linguagem natural.

Dez verificações, todas com disco e bytes reais. Para entrar na suíte sem alterar o `package.json`
(uma linha única que não pode ser reconstruída com segurança por aqui), o teste novo é chamado por
`execFileSync` de dentro de `tests/test_dev_analise.js`.

## 3. O que continua sem prova

- **Navegador**: o sandbox dentro da interface (arrastar arquivo, baixar resultado) não foi
executado; o que está provado é o motor em disco.
- **Windows e Android**: a ponte Electron e o acesso a arquivos pelo SAF não foram exercitados —
não há Windows nem Android SDK neste ambiente.
- **PDF em leitor externo**: a estrutura está verificada byte a byte, mas o arquivo não foi aberto
nem no Acrobat nem em navegador.

## 4. Evidência

- `node tests/test_arquivos_dev.js` → exit 0, "Motor de arquivos do app validado."
- `npm run test:all` → exit 0, 2352 verificações aprovadas, nenhuma falha.
