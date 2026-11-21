# Ajuste 085 — o JARVIS responde em qualquer modo, e o resumo tático das mensagens

Data: 2026-11-21 · Versão: 1.72.0+17200 · Branch: `work/1.48.0-fase2-consolidacao`

## 1. Pedido do usuário

Dois pedidos na mesma conversa:

1. resumo tático das mensagens por IA: filtrar o que é ruído de grupo, destacar o
   urgente e sugerir resposta, usando os provedores que o app já tem;
2. fazer o JARVIS diferenciar o app aberto do segundo plano — ao chamar por
   "Jarvis" pelo app ele dizia estar em segundo plano e que não tinha a função,
   quando a pergunta era simples como "que horas são".

## 2. O que estava errado

- Com o app aberto e **sem** "Exibir sobre outros apps" autorizado, o serviço
  tratava a ativação como segundo plano e falava a recusa fixa
  "Não reconheci esse comando em segundo plano. Posso abrir um app…". O comando
  era ouvido, mas a resposta era essa — para qualquer pergunta.
- O segundo plano só conhecia quatro comandos (app, lanterna, volume, alarme).
  Nenhuma pergunta livre chegava ao provedor de IA.
- As notificações eram listadas uma a uma, sem separar grupo de recado direto e
  sem destacar o que é urgente; responder exigia abrir cada mensagem.

## 3. O que foi feito

### Resposta em qualquer modo

- **A tela aberta muda a rota.** `MainActivity` marca `visivel` em `onResume` e
  `onPause`; o serviço só entra no caminho de segundo plano quando a tela **não**
  está na frente. Chamado pelo app, o comando volta para a conversa.
- **Hora e data no aparelho.** `JarvisFundo` ganhou `Tipo.HORA` e `Tipo.DATA` e
  responde em frase falável ("Agora são 14 horas e 32 minutos.", "Hoje é
  sexta-feira, 21 de novembro de 2026.") — sem provedor, sem rede e sem espera.
- **Pergunta livre vai para o provedor configurado.** `JarvisPonteIa.kt` abre um
  `MethodChannel` com o Flutter (`com.jarvis.nova/fundo_ia`); o serviço manda o
  texto ouvido, `PonteIaFundo` (Dart) usa o `ProviderService` já existente, com a
  personalidade escolhida, e devolve o texto limpo para a síntese de voz falar.
- **Resposta honesta quando não dá.** Sem motor do Flutter vivo ou sem chave, a
  voz diz "Não consegui consultar a IA agora. O app precisa estar aberto e com um
  provedor configurado…" — e o histórico registra a tentativa como não concluída.
- **Texto falado sem markdown.** `respostaFalada` tira asteriscos, listas, links
  e cercas de código antes de ir para o alto-falante.

### Resumo tático das mensagens

- **Regra local pura** (`core/resumo_tatico.dart`): palavras de urgência, sinais
  de grupo ("grupo", "12 mensagens", "e mais") e uma triagem que classifica cada
  notificação uma única vez.
- **Pedido curto e fechado** ao provedor: no máximo 24 notificações, 220
  caracteres por item, resposta obrigatoriamente em JSON com `resumo`,
  `urgentes`, `ruido` e `respostas`; a instrução proíbe inventar remetente,
  valor ou horário.
- **Leitura tolerante**: cerca de código e texto em volta são descartados; JSON
  inválido ou resumo vazio devolve `null` em vez de resumo inventado.
- **Tela** (`aparelho_page.dart`): botão "Resumo tático por IA" no cartão das
  notificações; o cartão resultado mostra o resumo, a lista URGENTE, o ruído de
  grupo filtrado e as respostas sugeridas com o botão "Usar", que abre a resposta
  da notificação já preenchida (`textoInicial`).
- **Sem provedor, nada de silêncio**: aparece a triagem local (urgência e ruído
  por regra) com o motivo escrito.

## 4. Evidência

- `flutter analyze` → `No issues found!`
- `flutter test` → `+201: All tests passed!` (inclui `test/aparelho_resumo_test.dart`)
- Testes puros com asserções ligadas: `dart --enable-asserts run
  tool/pergunta_livre_test.dart`, `tool/resumo_tatico_test.dart`,
  `tool/fundo_test.dart` → OK
- Contratos novos: `tests/test_resposta_qualquer_modo_flutter.py` e
  `tests/test_resumo_tatico_flutter.py` em `package.json` `test:all`
- APK release arm64: `JARVIS-Nova-1.72.0-resposta-e-resumo.apk`, 117 908 184
  bytes, SHA-256 `d20434c195538e829f9ba5003abdc9159ecb7414431025fd594062f85212404e`
  (https://files.catbox.moe/5rid9q.apk).

## 5. Arquivos

- `flutter_app/android/JarvisFundo.kt`: `Tipo.HORA`/`Tipo.DATA`, `horaFalada`,
  `dataFalada`, recusa sem a frase de segundo plano.
- `flutter_app/android/JarvisPonteIa.kt` (novo): ponte com o Flutter, prazo de
  35 s e resposta única.
- `flutter_app/android/KwsForegroundService.kt`: rota por visibilidade e
  `responderPerguntaLivre`.
- `flutter_app/android/MainActivity.kt`: `marcarVisivel`/`estaVisivel`, registro
  da ponte.
- `flutter_app/lib/core/pergunta_livre.dart`, `lib/services/ponte_ia_fundo.dart`:
  pedido de voz e ponte Dart.
- `flutter_app/lib/core/resumo_tatico.dart`, `lib/services/resumo_ia_service.dart`:
  triagem, pedido, leitura e triagem local.
- `flutter_app/lib/services/aparelho_page.dart`: botão, cartão e sugestão.
- `flutter_app/lib/core/fundo.dart`: ações e limites atualizados.
- `flutter_app/tool/prepare_android_sistema.py`: copia `JarvisPonteIa.kt`.
- Testes: `tool/pergunta_livre_test.dart`, `tool/resumo_tatico_test.dart`,
  `test/aparelho_resumo_test.dart`; contratos em `tests/`.

## 6. Não verificado

- **Nenhum aparelho físico nesta sessão**: a fala real do segundo plano, o tempo
  de resposta do provedor por voz e o comportamento do microfone com o app
  aberto continuam sem medição.
- Se o Android encerrar o app, a ponte de IA cai: o JARVIS avisa, mas a resposta
  só volta depois de abrir o app uma vez.
- A classificação de grupo e urgência é heurística + IA; grupos sem os sinais
  previstos podem não ser filtrados.
- O `RemoteInput` do WhatsApp/Telegram continua dependendo do aplicativo, como no
  ajuste 084.
- Nada foi commitado nem enviado.
