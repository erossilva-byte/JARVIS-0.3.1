# Gate A — ensaio do patch (2026-11-14)

## Por que esta fase

A Fase 4B foi encerrada em `docs/FASE-4B-ACEITE.md`. O que falta para o app deixar de ser
código revisado e virar app instalado depende de duas coisas que esta máquina não tem: um JDK
com o SDK Android (compilar) e um aparelho (medir). São o Gate A e o Gate B já descritos em
`docs/STATUS-IMPLEMENTACAO-1.47.md`.

Este ensaio nasceu antes de a Fase 5 (interface Flutter) começar; ele continua sendo o portão
do caminho de publicação. O único trecho do Gate A que dá para exercitar aqui é esse: o GitHub recusa
os arquivos grandes, então tudo sai como patch (`files/interface-v3.patch`). Se esse patch
não aplicar limpo ou não contiver algum arquivo, a rodada de CI inteira é perdida. Foi isso
que a Fase 5 atacou primeiro.

## O que foi entregue

`ci/rehearsal_gate_a.py` — ensaio repetível:

1. exporta o `HEAD` para um diretório temporário (`git archive HEAD | tar -x`), sem `.git`;
2. `git apply --check` e `git apply` do patch nessa cópia limpa;
3. compara byte a byte cada arquivo citado no patch com a árvore de trabalho;
4. roda `ci/preflight_android.py` no código vindo do patch (não no código atual);
5. avisa quantos arquivos alterados ficaram fora do escopo declarado do patch.

## Defeito que o ensaio encontrou

Na primeira execução o patch não aplicava no `HEAD`: ele tinha sido gerado com `git diff`, que
compara a árvore com o **índice** — e o índice deste repositório carrega arquivos preparados
de sessões anteriores. Corrigido gerando com `git diff HEAD`.

Na segunda execução o patch aplicou, mas a pré-checagem no código vindo dele reprovou:
`index.html carrega modo_dev.js, que não existe`. O arquivo existia na árvore, mas era novo e
nunca tinha sido marcado com `git add -N`, então o `git diff` não o incluía. O mesmo valia para
`tests/test_modo_dev.js` e `tests/test_arquivos_dev.js`.

Ou seja: o patch publicado até aqui teria produzido um app sem o modo dev e sem dois testes.
O ensaio pegou isso antes do CI.

## Evidência final

```
$ python3 ci/rehearsal_gate_a.py ../files/interface-v3.patch
AVISO: 13 arquivo(s) alterado(s) fora do escopo deste patch (não avaliados pelo ensaio).
Gate A (ensaio): patch aplica no HEAD limpo, 94 arquivo(s) conferidos e pré-checagem aprovada no código vindo do patch.
exit 0
```

O aviso é esperado: o repositório tem trabalho de outras frentes (Flutter, arquivos grandes)
que não pertencem a este patch; ele é informativo e não reprova.

## O que continua em aberto (e não pode ser declarado concluído)

- **Compilar de verdade**: `./gradlew assembleDebug` no CI com as mudanças deste patch. Nunca
  rodou nesta máquina (sem JDK/SDK). É o critério de saída do Gate A.
- **Suíte no CI**: `npm run verificar` no runner, não só local.
- **Gate B**: instalar no Poco X7 e preencher `docs/FASE-4B-FICHA-MEDICAO.md`.
- **Riscos só confirmáveis em compilação** listados em `docs/REVISAO-JAVA-COMPILACAO.md`.

Enquanto o CI não compilar e o aparelho não medir, a Fase 5 fica em andamento — o ensaio do
patch é o primeiro item marcado, não a fase inteira.

## Passo no GitHub Actions (ajuste 037)

O ensaio passou a rodar em todos os workflows que compilam, antes de qualquer uso do código:
`build-apk.yml`, `ci.yml` (regressão e compilação) e `release-apk.yml`. O passo procura
`*.patch` na raiz, roda `ci/rehearsal_gate_a.py <patch> --aplicar` (aplica e roda a
pré-checagem) e só então deixa a compilação seguir. Sem patch na raiz, ele avisa e continua:
o fluxo normal do repositório não mudou.

Relatório: `docs/relatorios/2026-11-14_037-ensaio-no-workflow.md`.
