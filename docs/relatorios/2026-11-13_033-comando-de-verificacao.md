# Ajuste 033 — comando único de verificação

Data: 2026-11-13
Branch: `work/1.48.0-fase2-consolidacao`

## Por que este ajuste

Pré-checagem, suíte e empacotamento já rodavam, mas espalhados: era preciso lembrar três comandos
e ler três saídas para saber se o projeto estava inteiro. Pior: quando a suíte falhava, não ficava
claro qual barreira tinha caído.

## O que foi feito

`npm run verificar` executa, nesta ordem:

1. `python3 ci/preflight_android.py` — análise estática do Android;
2. `npm run test:all` — suíte completa;
3. `python3 tests/test_empacotamento.py` — pacote Android/Windows.

Cada etapa roda mesmo se a anterior falhar, para mostrar o estado inteiro de uma vez. No fim, um
resumo com estado, tempo e contagem de verificações; em caso de falha, as últimas linhas da saída
da etapa aparecem antes do resumo. Sai com código diferente de zero se qualquer etapa falhar.

A pré-checagem e o empacotamento aparecem duas vezes na prática (também rodam dentro da suíte).
Isso é intencional: o resumo precisa apontar a barreira exata, e o custo é de décimos de segundo.

## Evidência

| Prova | Resultado |
|---|---|
| `npm run verificar` | exit 0 — 3 de 3 etapas; 2363 verificações OK, 1 aviso |
| `WRITE_SECURE_SETTINGS` injetada e `npm run verificar` | exit 1 — "Falhou: 2 de 3 — Pré-checagem Android, Suíte completa" |
| Manifesto restaurado | exit 0 |
| `python3 tests/test_empacotamento.py` | OK, incluindo "comando único de verificação existe" |
| Tempo observado | pré-checagem 0,1 s · suíte 27,5 s · empacotamento 0,0 s |

## Limites

O resumo conta linhas `OK:` da suíte; testes que imprimem outro formato entram como etapa
aprovada, mas não na contagem. E o comando não compila nem mede: ele só reúne as barreiras que
existem na máquina.
