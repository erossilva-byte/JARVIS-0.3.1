# Bloco 122 — ligação no segundo plano e paridade das ações

**Versão:** 1.99.0+19900
**Data:** 25 de novembro de 2026

## O que a varredura mostrou (e corrigiu da anterior)

A varredura do bloco anterior disse que ligação não funcionava com o app fechado.
Estava errada: `JarvisMensagens.kt` já tem `Tipo.LIGACAO`, resolve o contato pelo
`JarvisContatos` (com apelidos), usa `ACTION_CALL` quando há permissão e cai no
discador quando não há, avisando qual dos dois aconteceu. O `KwsForegroundService`
já chama esse caminho antes de gastar provedor de IA.

O que faltava era menor e mais difícil de ver: **um verbo**. O app aberto aceita
“chama a Ana” e “chamar o Murilo” (`interpretarLigacao`); o segundo plano só
aceitava `liga|ligar|ligue|disca|discar`. Resultado: “chama a Ana” com o app
fechado não ligava — virava pergunta livre.

Corrigido em `JarvisMensagens.VERBO_LIGACAO`, agora igual ao Dart:

```
\b(liga|ligar|ligue|disca|discar|chama|chamar)\b
```

O teste puro `flutter_app/tool/ligacao_paridade_test.dart` prende o lado Dart
(todos os verbos, destino limpo, e o que **não** é ligação: desligar, lanterna,
volume, pergunta) e o contrato compara as duas listas.

## O contrato de paridade

`tests/test_bloco_122.py` mantém uma tabela explícita, em quatro grupos:

**Ambos** (15): abrir tela, abrir app, app já na ação, mensagem, ligação, agir na
tela por acessibilidade, palco, apelido, mapa da voz, lanterna, volume, alarme,
mídia, núcleo, — cada uma precisa do marcador real nos dois arquivos.

**Só na tela** (4): ficha de pessoa, circuito por prompt, localização e música por
nome. O contrato exige que continuem **ausentes** do segundo plano; quem
implementar precisa mover a linha para “ambos”.

**Só no segundo plano** (1): hora e data. O fundo responde no aparelho; com a tela
aberta a pergunta vai para a IA. O contrato exige que o app continue sem
`ComandoHora` — a pendência é declarada, não esquecida.

**Sem voz** (5): anotar na memória, notificações, visão, tarefas e arquivos. O
contrato falha se alguma delas entrar no caminho de voz sem atualizar a tabela.

Ainda: todo `lib/core/pedido_*.dart` precisa estar classificado (um pedido novo
não entra sem aparecer na tabela), e os verbos de ligação e mensagem são
comparados conjunto a conjunto entre Dart e Kotlin.

## Verificações feitas

- `dart run tool/ligacao_paridade_test.dart` — OK.
- `python3 tests/test_bloco_122.py` — OK, depois de corrigir os marcadores reais
  (`ComandoDeTela`, `RespostaCircuito`) e a leitura de verbos em declaração
  quebrada.
- `flutter analyze`, `flutter test`, suíte Python inteira e as duas
  pré-checagens.

## Limites

- Kotlin não compila nesta máquina: o verbo novo foi conferido por leitura e
  pelo contrato, não por execução.
- Nada em aparelho físico: ligação real, permissão `CALL_PHONE`, discador de
  fallback e retorno ao serviço depois da chamada continuam por testar no
  celular.
- Hora e data com a tela aberta seguem gastando provedor; foi declarado nesta
  tabela como próximo ajuste.
