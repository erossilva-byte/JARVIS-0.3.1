# Ajuste 036 — Fase 5: ensaio do patch (2026-11-14)

## Por que

O app só sai do repositório como patch (`files/interface-v3.patch`), porque a integração
recusa arquivos grandes. Um patch incompleto ou que não aplica custa uma rodada inteira de CI
— e, pior, pode gerar um APK sem um arquivo e ninguém perceber até o teste no aparelho.

## O que foi feito

`ci/rehearsal_gate_a.py` exporta o `HEAD` para um diretório temporário, aplica o patch com
`git apply`, confere byte a byte os 94 arquivos citados e roda a pré-checagem Android no
código que veio do patch. Arquivos alterados fora do escopo declarado do patch são apenas
avisados (o repositório carrega trabalho de outras frentes).

## Defeitos encontrados

1. O patch era gerado com `git diff`, que compara com o índice, não com o `HEAD`. Como o
   índice tem arquivos preparados de sessões anteriores, o patch não aplicava no `HEAD` limpo.
   Passou a ser gerado com `git diff HEAD`.
2. `modo_dev.js`, `tests/test_modo_dev.js` e `tests/test_arquivos_dev.js` eram arquivos novos
   nunca marcados com `git add -N`, logo ficavam fora do patch. A pré-checagem no código
   vindo do patch reprovou com `index.html carrega modo_dev.js, que não existe` — prova de
   que o patch publicado até aqui geraria um app sem o modo dev.

## Evidência

```
$ python3 ci/rehearsal_gate_a.py ../files/interface-v3.patch
AVISO: 13 arquivo(s) alterado(s) fora do escopo deste patch (não avaliados pelo ensaio).
Gate A (ensaio): patch aplica no HEAD limpo, 94 arquivo(s) conferidos e pré-checagem aprovada no código vindo do patch.
exit 0
```

O patch tem 530 KB. `npm run verificar` continua exit 0 (2364 verificações, 3 de 3 etapas).

## O que a fase ainda deve

Compilar no CI (`assembleDebug`) e medir no aparelho. Sem JDK/SDK e sem Poco X7 nesta
máquina, esses dois critérios continuam abertos e não são declarados aqui. Ver
`docs/FASE-5-GATE-A.md`.
