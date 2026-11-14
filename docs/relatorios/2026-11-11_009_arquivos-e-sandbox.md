# Relatório — Fase 2, ajuste 009: eixo arquivos e sandbox

## 1. O que já existia

Dois motores de arquivo, com papéis diferentes:

- `platforms/desktop/arquivos.js` — motor do PC (Electron). Recebe um caminho e devolve dados;
  `resolver()` recusa qualquer caminho fora da pasta do usuário, a gravação é atômica (`.tmp` +
  `rename`), confere o hash depois de gravar e mantém cópia de segurança antes de substituir.
- `arquivos_dev.js` — motor que roda dentro do app (Android e PC): gera PDF, DOCX, XLSX, CSV, JSON,
  HTML e ZIP; analisa um conjunto de arquivos (JSON inválido, segredo no código, importação
  ausente, marcador de conflito, duplicata, desequilíbrio) e aplica correções seguras.

O sandbox (`sandbox.js`) executa JavaScript em `iframe` com `sandbox` sem same-origin, dentro de um
Worker, com limites de código (20 000), entrada (10 000) e tempo (500 ms–10 s).

## 2. Verificação de borda feita antes de mexer em qualquer coisa

Sondei o motor do PC com chamadas reais em pasta temporária:

```
salvar ../../fora.txt        -> recusado: "Caminho fora da pasta do usuário."
salvar /tmp/fora-abs.txt     -> recusado: mesmo motivo
ler    ../../etc/passwd      -> recusado: mesmo motivo
pesquisar em ../../etc       -> recusado: mesmo motivo
apagar ~                     -> recusado: "Não apago a pasta do usuário."
limparTemporarios            -> 0 restos
```

Nada foi criado fora da raiz (a pasta temporária terminou só com `home`). Duas respostas estranhas
no primeiro teste — `mover` e `criarPasta` — eram **erro da minha chamada**: as funções recebem
`{ de, para }` e `{ pasta, nome }`, e eu passei strings. Corrigida a chamada, o comportamento é o
correto; registro aqui para não virar acusação falsa no histórico.

No sandbox, os limites também respondem: código vazio recusado, código acima de 20 000 recusado,
entrada acima de 10 000 recusada, tempo fora da faixa é preso entre 500 ms e 10 s.

## 3. O que passou a estar provado

`tests/test_arquivos_dev.js` foi criado para o motor de dentro do app, e a validação **não confia no
próprio módulo**:

- **PDF**: assinatura `%PDF-1.4`, contagem de páginas declaradas, tabela `xref` e `%%EOF` final.
- **DOCX**: os bytes são reabertos por um leitor de ZIP escrito no próprio teste, com CRC
  recalculado por uma implementação independente; confere `[Content_Types].xml`, `_rels/.rels`,
  `word/document.xml`, o texto com acento preservado e o escape de `<tags>` e `&`.
- **XLSX**: mesma leitura independente; confere aba nomeada com escape (`Dados &amp; Cia`), células
  `A1`/`B1` e valores escapados.
- **CSV vindo de JSON**: o texto é reprocessado por um parser de CSV independente; vírgula, aspas e
  quebra de linha dentro do campo voltam idênticas, e `;` no campo não parte a linha.
- **JSON inválido**: recusado com erro, em vez de gerar arquivo quebrado.
- **ZIP**: pacote gerado abre no leitor independente e volta pelo `descompactar()` com acento no
  nome e no conteúdo; ZIP truncado é recusado em vez de devolver lixo.
- **Nomes e instruções**: `nomeSeguro()` não deixa barra nem caractere proibido passar, não duplica
  extensão; `instrucao()` separa ação, alvo e formato do pedido em linguagem natural.

## 4. Falha no meu próprio teste, corrigida antes de publicar

A primeira versão registrava as verificações de ZIP como assíncronas e chamava `process.exit()` no
fim do arquivo — o processo morria **antes** delas rodarem. O teste aparecia verde sem nunca ter
aberto um ZIP. A correção foi rodar as pendências em sequência e só então decidir o código de saída;
agora as duas verificações aparecem na saída e rodam de fato. Fica registrado porque a mesma falha
(verde sem executar) é justamente o que esta fase precisa evitar.

## 5. O que continua sem prova

- **Janela do Electron**: escolher arquivo pelo diálogo do sistema e salvar pelo painel não foi
  executado; o motor foi exercitado direto, em Node, com raiz temporária.
- **Sandbox em navegador**: `executar()` depende de `document`/`iframe`; em Node ele responde
  "precisa ser executado dentro do aplicativo". O isolamento real (Worker + timeout + `cancel`) não
  foi exercitado em navegador nesta sessão.
- **Aparelho Android**: as ações de arquivo expostas ao modelo têm teste de fiação, não de execução
  no aparelho.

## 6. Evidência

- `node tests/test_arquivos_dev.js` → 10 verificações, todas OK.
- `node tests/test_pc_arquivos.js`, `node tests/test_sandbox.js`,
  `python3 tests/test_arquivos_sistema.py`, `python3 tests/test_fileprovider.py`,
  `python3 tests/test_ia_arquivos.py` → todos exit 0.
- `npm run test:all` → exit 0, 2339 verificações aprovadas com o teste novo dentro da suíte.
