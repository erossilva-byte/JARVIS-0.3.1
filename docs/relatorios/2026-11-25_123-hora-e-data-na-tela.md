# Bloco 123 — hora e data respondidas no aparelho com o app aberto

**Versão:** 1.100.0+110000
**Data:** 25 de novembro de 2026

## O que faltava

A tabela de paridade do bloco 122 mostrou o único item “só no segundo plano”:
hora e data. Com o app fechado, `JarvisFundo` respondia pelo relógio do aparelho;
com a tela aberta, a mesma pergunta ia para o provedor de IA — chave gasta,
espera de rede e risco de a resposta vir com números em vez de fala natural.

## O que foi feito

- `lib/core/hora_data.dart`: espelho Dart das frases e das falas do Kotlin
  (`JarvisFundo.HORAS`, `DATA`, `horaFalada`, `dataFalada`). Devolve
  `RespostaRelogio` com a fala e o rótulo do histórico, ou `null` quando a frase
  é outra coisa.
- Normalização igual à do Kotlin: minúsculas, sem acento, pontuação vira espaço.
  “que horas sao” e “que horas são” caem na mesma regra.
- `voice_conversation_page`: a regra roda antes dos comandos do Android e antes
  do provedor, e a resposta entra na conversa, é falada e vai para o histórico
  como “informar as horas” / “informar a data de hoje” — o mesmo rótulo do fundo.
- Falas idênticas: “Agora são 14 horas e 5 minutos.”, “Agora são 9 horas em
  ponto.”, “Hoje é domingo, 4 de janeiro de 2026.”

## Tabela de paridade atualizada

- **Ambos (16)**: a lista anterior mais hora e data.
- **Só na tela (4)**: ficha, circuito, localização, música por nome.
- **Sem voz (5)**: memória, notificações, visão, tarefas, arquivos.
- “Só no segundo plano” deixou de existir.

O contrato do bloco 122 ganhou duas travas: exige `respostaHoraData(` no caminho
de voz (arquivo existir não basta) e continua exigindo o marcador `Tipo.HORA` no
Kotlin, comparando os dois lados da ação.

## Comportamento declarado

“Que horas você abre o mapa da voz?” contém “que horas” e, por isso, é respondida
como hora — exatamente como o segundo plano já fazia. A regra é a mesma dos dois
lados; separar pergunta de metalinguagem exigiria uma regra nova nos dois
arquivos, e ficou fora deste bloco. O teste puro registra esse caso de propósito.

## Verificações feitas

- `dart run tool/hora_data_test.dart` — falas de hora (com minutos, em ponto,
  meia-noite), data com dia da semana, cinco frases de hora, quatro de data,
  duas ações de histórico e negativos (“por que”, conversa comum).
- `python3 tests/test_bloco_122.py` — tabela atualizada e contrato OK.
- `flutter analyze`, `flutter test`, suíte Python inteira e pré-checagens.

## Limites

- Sem aparelho: a resposta falada e o tempo de resposta real não foram medidos.
- A fala usa o mesmo caminho de voz das outras respostas locais; nada novo de
  áudio foi introduzido.
