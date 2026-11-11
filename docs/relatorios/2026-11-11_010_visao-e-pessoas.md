# Relatório — Fase 2, ajuste 010: eixo visão e pessoas

## 1. O que já existia

- `visao.js` — geometria dos balões na imagem, plano de quadros do vídeo e o texto do relato.
- `visao_contexto.js` — memória da sessão visual: registra a análise, resolve perguntas de
  acompanhamento ("ele serve para quê?"), separa procedência (confirmado / loja / estimado),
  monta consultas de pesquisa, compara objetos e liga componentes à base elétrica.
- `pessoas.js` — perfis locais por nome digitado, sem biometria: salvar, buscar, resolver nomes
  (inclusive ambíguos), descrever, exportar e importar.

Todos os testes do eixo já passavam antes desta rodada: `test_visao_nova.js`,
`test_visao_contexto.js`, `test_pessoas.js`, `test_pessoas_voz.js`, `test_visao_integracao.py` e
`test_pessoas_ui.py`, com exit 0.

## 2. Defeito encontrado: a análise perdia todos os atributos

A análise do modelo traz atributos do objeto — tensão, corrente, material, medida. Em
`visao_contexto.js`, `objetoBasico()` criava o objeto com `atributos: {}` fixo: **nada do que veio
na análise era guardado**.

Reprodução, com dois objetos que têm atributos de verdade:

```
atributos do objeto 1: {}
atributos do objeto 2: {}
comparar: {"ok":true,"a":"contator","b":"disjuntor","diferencas":[],
           "resumo":"contator e disjuntor não têm atributos diferentes registrados; sem dados, não há conclusão."}
```

Consequência: `comparar()` — que existe justamente para dizer o que difere entre dois objetos da
mesma foto — **nunca** encontrava diferença, em nenhum uso real. A resposta sempre caía em "sem
dados, não há conclusão".

Por que o teste não pegava: no grupo de comparação, o teste **injetava** os atributos à mão
(`multi.contexto.objetos[0].atributos = {...}`) antes de comparar. Ou seja, exercitava a comparação
com dados que o registro nunca produz. É o mesmo tipo de falha que o teste de arquivos tinha: verde
sem passar pelo caminho real.

## 3. Correção

- `atributosDe()` copia os atributos da análise com saneamento: chave até 40 caracteres, valor até
  120, só texto/número/booleano, no máximo 12 por objeto. Nulo, lista, objeto aninhado e chave vazia
  são ignorados em vez de entrar crus.
- A regra da marca passou a valer para atributo também: **sem evidência legível na análise, os
  atributos não são mantidos**. Um "tensão: 24 V" sem etiqueta lida é palpite, e palpite não vira
  diferença afirmada na comparação.

Depois da correção, com a mesma entrada:

```
atributos 1: {"tensao":"24 V","corrente":"9 A"}
comparar: "contator × disjuntor: tensao (24 V / 220 V)."
```

## 4. Teste que trava o caso

Em `tests/test_visao_contexto.js`, três grupos novos:

- **atributos da análise chegam à comparação**: registra dois objetos com atributos e compara
  **sem injeção manual**; exige que a diferença de tensão apareça.
- **atributo sem evidência é descartado**: mesma entrada sem evidência deixa `atributos` vazio.
- **atributos estranhos são saneados e limitados**: tag HTML não passa, número vira texto, nulo,
  objeto e lista são ignorados, e a quantidade fica no teto de 12.

O teste saiu de 13 para 16 grupos de verificação aprovados.

## 5. Pessoas: o que foi sondado e o que ficou como está

Sondei `pessoas.js` com armazenamento injetado: nome com acento e caixa (`João da Silva` ×
`joao da silva`) **não** é fundido, como manda o comentário do módulo; `resolver('silva')` devolve
ambíguo com os dois candidatos em vez de escolher sozinho; apelido resolve exato (`jota`);
nome vazio é recusado; nome gigante é cortado em 60; exportar → limpar → importar devolve os cinco
perfis. Nenhum defeito encontrado aqui — e sem defeito não há correção: o que fica registrado é a
sondagem.

Um ponto observado, **não** alterado por ser decisão de produto: `salvar()` com um `id` que não
existe mais cria um perfil novo em silêncio, em vez de avisar que aquele perfil foi apagado. Fica
anotado para a fase de interface decidir.

## 6. O que continua sem prova

- **Câmera e modelo de visão**: nada aqui foi executado com imagem real; o que está provado é o
  tratamento dos dados que a análise entrega.
- **Ponte com a base elétrica** em aparelho: `tecnico()` foi exercitado com a base real em Node,
  não na interface.
- **Android**: perfis de pessoas, exportação e importação não foram exercitados no aparelho.

## 7. Evidência

- `node tests/test_visao_contexto.js` → 16 grupos aprovados, exit 0.
- `node tests/test_visao_nova.js`, `node tests/test_pessoas.js`, `node tests/test_pessoas_voz.js`,
  `python3 tests/test_visao_integracao.py`, `python3 tests/test_pessoas_ui.py` → exit 0.
- `npm run test:all` → exit 0, 2352 verificações aprovadas e nenhuma falha.
