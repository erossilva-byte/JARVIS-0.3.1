# Ajuste 032 — pré-checagem Android dentro de `npm run test:all`

Data: 2026-11-13
Branch: `work/1.48.0-fase2-consolidacao`

## Por que este ajuste

A pré-checagem só rodava no CI e quando alguém lembrava de chamá-la à mão. Um erro mecânico
(classe fora da lista, API de sistema, permissão não declarada) podia passar por uma sessão
inteira de testes local sem ninguém ver.

## O que mudou

- `python3 ci/preflight_android.py` passou a ser o **primeiro** passo de `npm run test:all`.
  Falhou ali, a suíte para na hora, sem gastar dois minutos nos outros testes.
- `tests/test_empacotamento.py` ganhou a verificação "pré-checagem Android roda na suíte": se
  alguém remover o passo do `package.json` ou apagar o script, a suíte reprova.

## Evidência

| Prova | Resultado |
|---|---|
| Rodada normal da suíte | exit 0 — 2362 linhas OK, pré-checagem no início |
| `WRITE_SECURE_SETTINGS` injetada no manifesto e `npm run test:all` | exit 1 imediato, com a mensagem da permissão de sistema |
| Manifesto restaurado | suíte exit 0 |
| `python3 tests/test_empacotamento.py` | OK, incluindo o check novo |

## Limites

Continua sendo análise estática: não compila e não mede. E o check do empacotamento protege a
presença do passo, não o conteúdo dele — quem apagar uma verificação de dentro do script ainda
precisa ser pego em revisão.
