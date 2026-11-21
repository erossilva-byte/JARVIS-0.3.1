# Ajuste 072 — relógio por contato e aparelho conectado (Fase 10/11)

## 1. Identificação

- **Versão:** 1.60.0+16000 (`flutter_app/pubspec.yaml`).
- **Data:** 2026-11-19.
- **Branch:** `work/1.48.0-fase2-consolidacao`.
- **Commit:** nenhum — tudo no disco, sem commit, push ou PR.
- **Plataformas afetadas:** app Android em Flutter (Dart + Kotlin). O núcleo web, o Electron, os
  plugins Java antigos e o importador `.cad` não mudaram.

## 2. Pedido

1. Cada contato do temporizador contar o **próprio relógio**, sem depender do relógio do
   temporizador, com exemplo calculado de **dois tempos independentes**.
2. Ao chamar por Jarvis em segundo plano, **mostrar na tela que está ativo** e ativar o microfone.
3. Acesso a **todas as notificações** do aparelho.
4. Mandar mensagem por **qualquer app** (WhatsApp, Discord, Instagram, Gmail, SMS e outros) com o
   texto exato pedido.
5. Controlar o **Spotify**: pausar, avançar, voltar, reiniciar e trocar para a música pedida.
6. Acesso aos **contatos** para realizar ligações.
7. Acesso ao **status e às configurações básicas** do celular.
8. Ter noção de **pessoas e contatos**: buscar na ficha, criar quando não existir e pedir as
   informações básicas.

## 3. Feito

### 3.1 Relógio próprio de cada contato (Dart)

- `simular()` ganhou `temposContato` e `temposQuedaContato`: mapas por **id de contato**, não por
  temporizador. `Circuito.relogioDoContato` e `Circuito.relogioQuedaDoContato` leem o contador do
  contato; só quando ele não é informado caem no relógio do temporizador (compatibilidade).
- `_solucionar` usa o relógio do contato para decidir o 67/68 NA e o NF; o relógio do KT1 deixou de
  ser a fonte do tempo dos contatos.
- A tela mantém `temposContato`/`temposQuedaContato` e o botão **Avançar 1 s** anda cada contato
  separadamente. O contador de cada contato zera quando o temporizador volta a energizar e continua
  na queda enquanto o contato estiver segurando.
- Exemplo novo **Relógios independentes no temporizador**, em 24 V: KT1 com ajuste base de 12 s
  (que **não** é usado por ninguém), 67/68 NA com relógio próprio de 2 s (L1) e 67/68 NF com
  relógio próprio de 7 s (L2). L1 acende aos 2 s e L2 apaga aos 7 s.

### 3.2 Segundo plano com tela ativa e microfone

- Quando a palavra de ativação é detectada com o app em segundo plano, o serviço já trazia a tela
  para a frente e iniciava o reconhecimento. Agora a intenção `jarvis_wake_keyword` também chega ao
  Flutter como `acao: ativo`: a tela mostra a faixa **JARVIS ATIVO · microfone aberto, pode falar**
  (`ValueKey('jarvis-ativo')`) por 25 s ou até o comando ser transcrito.
- O evento `wake` do KWS entrou no barramento de comandos, então a faixa aparece mesmo quando o app
  já estava aberto.
- `AparelhoService.ativarEmSegundoPlano()` chama o Kotlin, que traz a atividade para a frente,
  acende a tela sobre o bloqueio (`setShowWhenLocked`/`setTurnScreenOn`, Android 8.1+) e garante o
  serviço de microfone em primeiro plano.

### 3.3 Notificações

- `JarvisNotificacaoListener` (NotificationListenerService) guarda em memória até 80 notificações
  (app, título, texto, hora), sem gravar em disco e sem enviar para a rede.
- O painel mostra se o acesso está concedido, abre `Configurações → Acesso a notificações`, lista as
  últimas notificações e permite limpar a leitura.

### 3.4 Mensagens por qualquer app

- Registro fixo em `core/aparelho.dart`: WhatsApp, WhatsApp Business, SMS, Gmail, Discord,
  Instagram, Telegram, Messenger, Signal e E-mail.
- `interpretarMensagem` entende "manda mensagem para Ana no WhatsApp dizendo que chego às 9",
  "envia um sms para 11999998888 dizendo estou chegando" e "manda no Instagram para joao o texto:
  bora treinar" — separando app, destinatário e **texto exato**.
- Kotlin: WhatsApp por `https://wa.me/<numero>?text=` (número resolvido nos contatos quando o
  destinatário é um nome) ou `whatsapp://send?text=`; Gmail por `mailto:`; Discord, Instagram,
  Telegram, Messenger e Signal por `ACTION_SEND` com o pacote do app; SMS enviado direto pelo
  `SmsManager` depois da permissão.
- Limite declarado no app e na resposta: os apps de terceiros **não aceitam envio silencioso** — o
  Jarvis abre a conversa com o texto exato e o usuário toca em enviar.

### 3.5 Spotify

- `interpretarSpotify` entende pausar, continuar, avançar, voltar, reiniciar e "toca <música>".
- Kotlin usa a sessão de mídia ativa (`MediaSessionManager` + `MediaController`): `pause()`,
  `play()`, `skipToNext()`, `skipToPrevious()` e `seekTo(0)` para reiniciar. "Tocar a música pedida"
  abre `spotify:search:<faixa>` — escolher a faixa exata por fora do app não é permitido pelo
  Android, e a resposta diz isso.

### 3.6 Contatos e ligações

- `buscarContatos` lê `ContactsContract` (nome + telefones), com permissão `READ_CONTACTS`.
- `ligar` resolve o nome no contato e disca por `ACTION_CALL` com `CALL_PHONE`; sem permissão, o
  pedido é feito na hora e a resposta diz se foi negado.

### 3.7 Status e configurações básicas

- `status` lê bateria e carga, volume de mídia, mudo, fone conectado, brilho, rede ativa (Wi-Fi,
  dados, cabo), Não Perturbe, modelo e versão do Android. `EstadoAparelho.descrever()` mostra só o
  que foi lido.
- `abrirAjustes` abre notificações, som, tela, Wi-Fi, dados ou o próprio app; `pedirPermissao`
  cobre microfone, contatos, SMS, telefone e acesso a notificações.

### 3.8 Pessoas e fichas

- `fichaDeContato` cria a ficha a partir do contato do aparelho **sem consentimento e sem preencher
  nada sozinho**; `perguntasBasicasPessoa` traz as cinco perguntas (nome/apelido, relação,
  preferências, observações e consentimento).
- O painel busca o contato no aparelho, oferece "Criar ficha", mostra as perguntas e salva no
  `PessoasStore` (armazenamento seguro do aparelho), respeitando `validarPessoa`.

## 4. Evidência

- `flutter analyze` — **limpo** (0 issues).
- `dart run tool/circuito_test.dart` — **66 grupos** aprovados (5 novos, 53–57).
- `dart run tool/aparelho_test.dart` — **14 grupos** aprovados.
- `flutter test` — **163 testes** aprovados, incluindo `test/circuito_page_test.dart` (16) e
  `test/aparelho_page_test.dart` (5).
- APK release arm64 compilado: `JARVIS-Nova-1.60.0-relogios-e-aparelho.apk`, 117.348.680 bytes,
  `versionCode 16000`, `versionName 1.60.0`, SHA-256
  `4bf91b18c1c6a71b27cbd4a248a7b4c4c640519a435f1e2aab229a4afa64ebc1`. Conferido por dentro:
  permissões `READ_CONTACTS`, `CALL_PHONE` e `SEND_SMS` no manifesto final, serviço
  `com.jarvis.nova.JarvisNotificacaoListener` declarado e os textos `com.jarvis.nova/aparelho`,
  `spotify:search` e `whatsapp://send` presentes no `classes.dex`.
- Publicado em `https://litter.catbox.moe/e25bah.apk` (temporário, 72 h) e baixado de volta: mesmo
  tamanho e mesmo SHA-256.

## 5. Critérios de aceite

- [x] Dois contatos com relógios diferentes no mesmo temporizador, provados no cálculo puro.
- [x] O contato fecha pelo relógio próprio mesmo com o relógio do temporizador em 0 s.
- [x] Circuito antigo sem relógio de contato continua igual (fallback testado).
- [x] Faixa de "JARVIS ATIVO" aparece quando a palavra é detectada.
- [x] Painel único com status, notificações, mensagens, Spotify, contatos e fichas.
- [x] Interpretadores de mensagem, Spotify e ligação testados sem Android.
- [x] Nenhum envio é declarado sem a resposta nativa; texto exato preservado.
- [x] Ficha de contato nasce vazia, sem consentimento e com as perguntas básicas.

## 6. Não verificado

- **Nada foi instalado ou aberto em aparelho físico** (não há aparelho conectado nesta sessão).
- Não foi possível confirmar em aparelho: acesso real às notificações, envio em cada app de
  mensagem, controle do Spotify com sessão ativa, discagem, leitura de contatos, permissões
  concedidas/negadas e a faixa "JARVIS ATIVO" com o app fechado.
- O Kotlin compilou no build do APK; os caminhos que dependem de apps de terceiros não foram
  exercitados.

## 7. Limitações

- Apps de terceiros não aceitam envio silencioso: o toque final em "enviar" é do usuário; só o SMS
  sai direto.
- "Tocar a música pedida" abre a busca do Spotify; tocar a faixa exata exige o toque na lista.
- Os controles de mídia dependem de uma sessão ativa e do acesso a notificações concedido.
- Não há root, ADB, Shizuku, leitura de todos os arquivos, nem envio de notificações para a rede.
- O relógio do simulador continua em passos de 1 s; sem corrente alternada, motor de indução, curva
  térmica ou CLP.
