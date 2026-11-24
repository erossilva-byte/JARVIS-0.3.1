# 114 — Abrir tudo por voz, no app e no segundo plano

## Pedido

Fazer o JARVIS abrir apps e executar as funções que já existem por comando de
voz, "independente de onde": pelo app ou pelo segundo plano. Exemplos citados:
abrir o WhatsApp, abrir WhatsApp/SMS/Gmail e mandar mensagens de acordo com o
comando, abrir o modo visão e exibir o modo palco.

## O que faltava

- As telas do próprio JARVIS não tinham voz: "abre a memória" caía no comando de
  abrir app e o Android procurava um aplicativo chamado "memória" (ou devolvia
  "não encontrei o app"). Só o palco com assunto, o núcleo e algumas tarefas
  tinham caminho próprio.
- No segundo plano, só abrir app, lanterna, volume, alarme, música, núcleo e
  palco eram reconhecidos. Mensagem e ligação com o app fechado iam para a IA,
  que não envia nada.

## O que foi feito

1. `lib/core/pedido_abrir.dart` — regra pura de "abrir tela do JARVIS": 31 telas
   com chave fixa (`visao`, `palco`, `memoria`, `pessoas`, `tarefas`,
   `segundo_plano`, `voz_externa`…), aliases de fala, exigência de verbo de abrir
   (ou "modo X"), guarda de pergunta e bloqueio de mensagem/ligação. Abrir app de
   terceiro, conversa comum e pergunta continuam fora.
2. `lib/services/abrir_tela.dart` — abre a tela pelo navegador único do app,
   abrindo os cofres (memória, pessoas, personalidade, histórico) antes de
   montar a página e devolvendo o resultado em texto falável.
3. `lib/main.dart` — `AbrirTela.navegador` no `MaterialApp`: a tela pedida abre
   por cima de qualquer outra.
4. `lib/services/voice_conversation_page.dart` — o pedido de tela vem depois do
   palco com assunto e antes do comando de abrir app; fala, registra no
   histórico e entra na conversa como as demais tarefas locais.
5. `android/JarvisAbrirTela.kt` — o mesmo reconhecedor no serviço, com as mesmas
   chaves, sem depender do motor do Flutter.
6. `android/KwsForegroundService.kt` — reconhece a tela antes de abrir app e
   antes da IA, confere "Exibir sobre outros apps" e abre o app com a chave no
   `Intent`; mensagem e ligação vêm antes da pergunta livre.
7. `android/JarvisMensagens.kt` — mensagem e ligação com o app fechado:
   WhatsApp/WhatsApp Business/Telegram/SMS/Gmail/e-mail/Discord/Instagram/
   Messenger/Signal, contato por nome no Android, SMS direto só com permissão,
   `ACTION_CALL` com permissão e discador com número quando falta, e a recusa
   honesta do toque em enviar nos apps de terceiro.
8. `android/MainActivity.kt` + `lib/services/sistema_android.dart` +
   `lib/home_screen.dart` — a chave da tela chega ao Flutter como intenção
   `tela`, é traduzida para `TelaJarvis` e aberta pelo mesmo serviço.

## Evidência

- `tool/pedido_abrir_test.dart` — 32 frases de tela, "voz externa" fora de
  "voz", app de terceiro e conversa comum preservados, mensagem/ligação
  preservadas, perguntas recusadas, chave do Android de volta na tela certa.
- `test/abrir_tela_test.dart` — a tela abre por cima da atual e a anterior
  continua embaixo.
- `test/sistema_android_test.dart` — intenção `tela` vira `TelaJarvis` e chave
  desconhecida não abre nada.
- `tests/test_bloco_114.py` — paridade das chaves entre Dart e Kotlin, ordem dos
  caminhos no app e no serviço, permissões e frases honestas, versão e registro.

## O que não foi verificado

- Nada em aparelho físico: abrir tela com o app fechado (precisa de "Exibir
  sobre outros apps"), mensagem e ligação no segundo plano e o SMS direto.
- Kotlin não foi compilado nesta máquina (sem `kotlinc`); as mudanças foram
  conferidas por contrato e leitura, não por build.
- O toque final em enviar nos apps de terceiro continua sendo do usuário — é
  regra dos apps, não uma escolha desta entrega.
