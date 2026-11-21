# Ajuste 073 — tocar a faixa pedida de verdade no Spotify

## 1. Identificação

- **Versão:** 1.61.0+16100 (`flutter_app/pubspec.yaml`).
- **Data:** 2026-11-19.
- **Branch:** `work/1.48.0-fase2-consolidacao`.
- **Commit:** nenhum — tudo no disco, sem commit, push ou PR.
- **Plataformas afetadas:** app Android em Flutter (Dart + Kotlin).

## 2. Pedido

O comando de música deve **tocar a faixa pedida de verdade** no Spotify, em vez de só abrir a busca,
usando a sessão de mídia — e explicando o que o Android permite.

## 3. O que o Android permite (e o que não permite)

- **Sessão de mídia (`MediaController`)**: controla o app que já está tocando — play, pause, próxima,
  anterior e posição. Ela **não tem busca no catálogo** e não enfileira uma faixa arbitrária.
- **`MediaStore.INTENT_ACTION_MEDIA_PLAY_FROM_SEARCH`**: é o canal oficial para "tocar \<faixa\>".
  O Jarvis manda a consulta com o pacote do Spotify; **o app escolhe o melhor resultado e começa a
  tocar**. É o mesmo mecanismo que o Google Assistente usa.
- **URI exata (`playFromUri` + `spotify:track:…`)**: quando o usuário dita um link do Spotify, a
  sessão recebe a URI exata e o app recebe o mesmo link. Aí não existe adivinhação de resultado.
- **Sem SDK/API do Spotify (App Remote/Web API)** o Android não deixa listar o catálogo, escolher a
  faixa exata a partir de um nome nem montar fila. Foi por isso que a versão 1.60.0 só abria a
  busca — agora ela usa o canal de busca de mídia e **confere** o que está tocando.

## 4. Feito

- **Dart (`core/aparelho.dart`)**
  - `uriSpotify()` reconhece `spotify:track:…` e links `open.spotify.com/track/…`, convertendo o
    link em URI.
  - `PedidoSpotify` ganhou `uri`; o pedido "toca Bohemian Rhapsody <link> no Spotify" leva a URI
    exata e o nome limpo.
  - `faixaConfere()` compara o pedido com o que a sessão informa (título igual, contido ou todas as
    palavras no título/artista), sem falso positivo.
- **Kotlin (`JarvisAparelho.kt`)**
  - `tocarFaixa()` tenta, nesta ordem: (1) `playFromUri` na sessão ativa quando há link;
    (2) `MEDIA_PLAY_FROM_SEARCH` para `com.spotify.music`; (3) o link de busca, só como último
    recurso. O app também recebe o link, que é quem enfileira a faixa exata.
  - `verificarFaixa()` acompanha a sessão por até **8 s** e só responde "Tocando \"…\" — …" quando o
    título confere e o estado é `PLAYING`. Sem confirmação, a resposta diz o que está tocando de
    fato e repete o limite do Android.
- **Tela**: o painel do Spotify explica o caminho usado e o limite, em vez de prometer o que o
  Android não entrega.

## 5. Evidência

- `flutter analyze` — **limpo** (0 issues).
- `dart run tool/aparelho_test.dart` — **18 grupos** aprovados (4 novos: URI, pedido com link,
  conferência positiva e conferência negativa).
- `flutter test` — suíte completa aprovada, incluindo os testes de tela do painel.
- APK release arm64 compilado: `JARVIS-Nova-1.61.0-spotify-toca-a-faixa.apk`, 117.348.676 bytes,
  `versionCode 16100`, `versionName 1.61.0`, SHA-256
  `9652e152284d77d28f85ddc2ad5ca71a13c98833798c3bb288e1cd47b7fa9fa7`. Dentro do APK:
  `android.media.action.MEDIA_PLAY_FROM_SEARCH` presente no `classes.dex`.
- Publicado em `https://litter.catbox.moe/xof18c.apk` (temporário, 72 h) e baixado de volta: mesmo
  tamanho e mesmo SHA-256.

## 6. Critérios de aceite

- [x] O comando de música chama a busca de mídia do Android, que faz o Spotify **tocar**.
- [x] Link/URI do Spotify é entregue à sessão e ao app, sem inventar identificador.
- [x] O Jarvis só declara "tocando" quando o título confere com o pedido.
- [x] A resposta explica o que o Android permite quando a confirmação não vem.
- [x] Testes puros cobrem URI, pedido com link e os dois lados da conferência.

## 7. Não verificado

- **Nada foi instalado ou aberto em aparelho físico.** Não foi possível confirmar em campo:
  o Spotify aceitar `MEDIA_PLAY_FROM_SEARCH` nesta versão/aparelho, o `playFromUri` com
  `spotify:track:…`, o tempo real de confirmação (8 s) e o comportamento do app aberto/fechado.
- A conferência de faixa foi provada no Dart; o espelho em Kotlin compilou no APK, mas não rodou em
  sessão de mídia real.

## 8. Limitações

- Sem `spotify:track:…`, quem escolhe o resultado é o Spotify; o Jarvis confere e informa o que
  tocou.
- Faixa exata por nome depende de o app aceitar a busca de mídia e do catálogo da conta.
- Sem SDK/API do Spotify não existe fila, seleção de dispositivo nem controle de "tocar a seguir".
- O controle contínuo (pausar, avançar, voltar, reiniciar) continua dependendo de uma sessão ativa
  e do acesso a notificações concedido.
