# Ajuste 053 — transparência das fichas na conversa (2026-11-15)

## Por que

O ajuste 052 passou a enviar o bloco seguro de pessoas, mas a conversa não mostrava que uma ficha
tinha sido usada nem o que exatamente saiu do aparelho. Sem isso, o usuário precisava confiar na
palavra do app — o oposto da regra do projeto.

## Como ficou

- `contextoPessoasParaConsulta` (núcleo) devolve um resultado estruturado: o texto do bloco, os nomes
  citados e o tipo (`detalhe`, `ambiguo`, `ausente` ou `nenhum`). `blocoPessoasParaConsulta` continua
  existindo como atalho para o texto puro, então nada de quem já consumia quebrou.
- A resposta do assistente passou a guardar `fichas` (nomes citados) e `contextoPessoas` (o bloco
  **literal** enviado), inclusive quando a geração é interrompida. Os campos são opcionais no JSON:
  conversa antiga sem eles abre normalmente.
- Na bolha, abaixo do texto, aparece “Ficha usada: Ana” (uma), “Fichas citadas: Ana, Ana Paula”
  (ambiguidade) ou “Fichas: nenhuma correspondência” (ausência). Tocar abre o bloco literal em texto
  selecionável — não é um resumo, é o mesmo conteúdo enviado ao provedor.
- Pergunta sem ficha não ganha o bloco: nada é exibido e nada é enviado.
- “O que lembrei” da memória continua na mesma bolha; os dois avisos convivem.

## Verificação

```
dart run tool/pessoas_conversa_test.dart      → 11 grupos, OK (tipo, nomes e persistência do bloco)
flutter test test/conversa_pessoas_test.dart  → 3 testes, All tests passed!
flutter test                                  → 87 testes, All tests passed!
python3 tests/test_pessoas_privacidade.py     → OK (estático, inclui a transparência)
flutter analyze                               → No issues found!
npm run verificar                             → 4 de 4 etapas
```

Os três testes de widget provam: o nome usado aparece e o bloco só abre ao tocar; sem
correspondência a bolha diz isso sem inventar nome; resposta sem ficha não ganha o aviso. O teste
puro prova que o bloco e os nomes sobrevivem a `paraJson`/`deJson` e que uma conversa antiga, sem os
campos novos, continua sendo lida.

## Limites

- Sem chave real de provedor, **a resposta do modelo não foi exercitada**: o bloco exibido é o que o
  app enviou, não uma confirmação de como a IA o usou.
- Sem aparelho, a bolha expansível não foi vista em tela; em 320 px o texto do bloco pode exigir
  rolagem, o que só se confirma no CI/aparelho.
- A ficha usada é decidida pela pergunta (nome/apelido); perguntas indiretas (“e a irmã dela?”) não
  resolvem a pessoa e, portanto, não mostram ficha.
