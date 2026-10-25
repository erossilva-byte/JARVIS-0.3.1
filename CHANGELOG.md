## 1.10.1 — 2026-10-25
Revisão do segundo plano. Nada de funcionalidade nova: são os defeitos que impediam a escuta de continuar viva e o player de rodar sem derrubar o processo.
- **Player de música derrubava o processo em alguns comandos.** "Pausar", "próxima" e "parar" chamavam `startForegroundService()`, mas o serviço tratava o comando sem chamar `startForeground()` — o Android encerra o processo com `ForegroundServiceDidNotStartInTimeException`. Agora toda ação promove o serviço a primeiro plano e, sem player, ele encerra em vez de ficar pendurado.
- **O "tenta de novo em 8 s" do vigia nunca acontecia.** `JarvisWatchdog.agendar()` usava o mesmo `PendingIntent` do alarme periódico, então cada agendamento sobrescrevia o anterior: fechar o app pelos recentes caía no ciclo de 15 minutos. O alarme rápido ganhou request code próprio (`90211`) e `cancelar()` limpa os dois.
- **Escuta presa em "Escuta em espera" ao fechar o app no meio de um comando.** A interface pausa a escuta para gravar o comando; se ela morresse antes de religar (app fechado pelos recentes, WebView morto), o serviço continuava vivo e o vigia não fazia nada, porque só reinicia serviço parado. Agora `onTaskRemoved` retoma a escuta na hora e ainda agenda a recuperação rápida.
- **Falha fatal deixava primeiro plano e notificação para sempre.** Sem escuta e com o app fechado ninguém religava, mas o serviço seguia em primeiro plano. Ele agora sai sozinho depois de dois minutos se ninguém religar.
- **Lembretes não voltavam depois de reiniciar o celular.** `JarvisAlarmScheduler.restaurar()` abortava no Android 12+ sem `SCHEDULE_EXACT_ALARM`, mas `setAlarmClock()` é isento dessa permissão (é tratado como alarme do usuário). A checagem saiu e a restauração volta a acontecer.
- **Interface e serviço discordavam quando o Android recusava o primeiro plano.** O plugin agora desfaz `desejaOuvir` e cancela o vigia quando o serviço não sobe, e o app não desliga mais a ativação por uma falha temporária de primeiro plano — ele avisa e tenta de novo em 20 s.
- **Evento "a escuta parou" com o app fechado** agora também desliga a chave na interface, em vez de abrir o app dizendo "ligado" com o microfone já liberado.
- Versão 1.10.1 (versionCode 10101), mesma assinatura de CI: instala por cima da 1.10.0.

## 1.10.0 — 2026-10-25
- **Personalidade num único ponto.** O tom do assistente passou a viver no objeto `PERSONALIDADE` (app.js): identidade, papel, traços, lealdade, tratamento, conversa, humor e limites. O prompt de sistema da nuvem e o do modelo local são montados a partir dele, então mudar o jeito do J.A.R.V.I.S. é editar um bloco — sem mexer na palavra de ativação, no perfil de voz ou nos comandos. O texto agora diz o que se espera dele: **formal, espirituoso e leal**, com humor seco e respeito formal sem servilismo.
- **A voz agora é conferida em voz alta, e vem ligada.** Com um perfil cadastrado (3 amostras) a conferência já começa ativa; dá para desmarcar. Na ativação, ele **fala** “Analisando sua voz, senhor. Um instante.”, só depois grava os 4 segundos e compara com o perfil salvo; se não reconhecer, recusa com uma frase e volta a esperar “Jarvis”.
- **Menos cobrança para o usuário.** Além do botão de desligar a escuta, a conferência de voz passou a ser exigida **uma vez por sessão** — no primeiro acesso e depois de ligar o celular (o `JarvisBootReceiver` avança o token em `JarvisPrefs`). Quem quiser em toda ativação troca em Ajustes ▸ Voz, no seletor “Quando conferir a voz”.
- **“Ligue para X” liga de verdade.** Antes o app montava `tel:` e caía no discador. Agora `JarvisUtilPlugin.ligar` usa `Intent.ACTION_CALL` com a permissão `CALL_PHONE` (pedida na hora), completando a chamada; se o Android negar ou o aparelho não tiver telefonia, abre o discador e **diz** que a ligação não foi completada, em vez de dar a entender que ligou.
- **“Coloque a música This I Love” começa a tocar.** A ação `tocar_musica` procura o arquivo na biblioteca do aparelho (`MediaStore`, ignorando acentos, pontuação e a ordem das palavras, com tolerância a erro de transcrição) e inicia a reprodução num **serviço em primeiro plano** com notificação, controles de tela bloqueada e `MediaSession` — continua tocando com o app fechado. As ações “pausar/continuar/próxima/anterior” passam a obedecer esse player antes de tentar a sessão de mídia do Android. Se a faixa **não existe no aparelho**, o app abre a busca de um app de streaming e diz com todas as letras que ali é preciso tocar no resultado: nenhum aplicativo de streaming aceita iniciar uma faixa sem conta autenticada, então prometer isso seria mentira.
- **O comando de voz de música deixou de abrir só a busca.** “Toca aquela música”, “coloca a música …” e “põe a faixa …” agora limpam o artigo e o substantivo do pedido (“a música”) e vão para o player local.
- **Economia em segundo plano.** Com o app fora da tela, o reconhecimento do WebView é encerrado e a fala em andamento é cancelada; quem continua escutando é só o serviço nativo, esperando a palavra de ativação. Nada de microfone aberto à toa.
- **Uma exceção não fecha mais o app.** `window.onerror` e `unhandledrejection` viraram um aviso no chat e uma linha no registro (até três avisos, para não virar enxurrada). A IA local, antes de carregar o modelo, confere a memória livre e transforma um `OutOfMemoryError` nativo — que fechava o processo sem explicação — em mensagem com o número de MB que faltam.
- **Permissões novas, todas justificadas:** `CALL_PHONE` (completar a ligação), `READ_MEDIA_AUDIO`/`READ_EXTERNAL_STORAGE` até o Android 12 (achar a música no aparelho) e `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (tocar com o app fechado). O player só lê áudio; nenhum arquivo é enviado para fora.
- Versão 1.10.0 (versionCode 10100), mesmo pacote `com.jarvis.nova` e mesma assinatura de CI: instala por cima da 1.9.0.

## 1.9.0 — 2026-10-24
- **Voz neural no próprio aparelho (offline, sem chave).** O APK passou a embarcar o **sherpa-onnx 1.13.8** (Next-gen Kaldi, Apache-2.0): um AAR de ~50 MB com ONNX Runtime e espeak-ng compilados, baixado no build e conferido por SHA-256 (`baixar_sherpa.py`). Os **modelos de voz não vão dentro do APK** — somariam 200 MB por atualização. Cada voz é baixada uma vez, extraída para o armazenamento privado do app e depois usada sem internet; dá para apagar quando quiser.
- **Três vozes, com número medido e não com promessa.** Rodei as três neste mesmo sherpa-onnx, sintetizando “Boa noite, senhor. Todos os sistemas estão operacionais”:
  - **Cadu** (`vits-piper-pt_BR-cadu-medium`, 67 MB, 22,05 kHz, licença CC0): voz masculina brasileira, frequência fundamental mediana **127 Hz** (a mais grave das brasileiras) e **RTF 0,06** — ou seja, ~17× mais rápida que o tempo real nesta máquina. É a recomendada.
  - **Faber** (`vits-piper-pt_BR-faber-medium`, 67 MB, CC0): timbre mais claro, **155 Hz**, mesmo RTF. Fica como alternativa para quem achar a Cadu grave demais.
  - **Kokoro** (`kokoro-int8-multi-lang-v1_0`, 132 MB, Apache-2.0, 24 kHz): as vozes britânicas masculinas do Kokoro-82M. Medido: `bm_fable` **129 Hz**, `bm_george` **145 Hz**, `bm_lewis` **86 Hz**; **RTF 1,2–1,5** nesta máquina, isto é, mais lento que o tempo real — por isso a interface diz que essa voz é para respostas curtas e que num celular ela demora alguns segundos. É o timbre mais parecido com o do filme, mas **só fala inglês**.
- **O que não deu para fazer com o Kokoro, dito na cara.** `en-gb` **não existe** no espeak-ng empacotado com este modelo: com `lang=en-gb` a síntese volta **vazia** (testado). Com `lang=en` funciona, então o sotaque é americano e o timbre britânico vem do falante. O app usa `en` e explica isso na tela.
- **Tom e cadência ajustáveis.** O slider “Profundidade da voz neural” (0,70–1,10, padrão 0,90) reamostra o áudio gerado: abaixo de 1,00 a fala fica mais grave **e** mais lenta, que é exatamente a cadência arrastada do J.A.R.V.I.S. do cinema. A voz Piper já sai de fábrica com o `length_scale` neutro; o “peso” vem do tom.
- **Download com progresso, cancelamento e limpeza.** Barra com MB baixados/total, aviso de extração, botão de apagar a voz e “Liberar memória” (descarta o modelo da RAM sem apagar o arquivo). Falha de rede apaga o que ficou pela metade para não deixar um modelo corrompido no aparelho.
- **Queda automática para o TTS do Android.** Se o motor não estiver no aparelho, se a voz não estiver baixada ou se a síntese falhar, a resposta sai pela voz do sistema e o registro guarda o motivo. A voz neural nunca é obrigatória: o seletor começa em “Desligada — usar a voz do Android”.
- **Por que o detector de palavra-chave do sherpa-onnx continua desligado.** O único modelo público de KWS do projeto é o `kws-zipformer-gigaspeech` (17 MB), treinado em inglês; a 1.7.0 mediu **1 de 4** acertos em “Jarvis” falado em português e nenhum no limiar padrão. Além disso a palavra precisa ser codificada à mão em tokens BPE (`▁JA R VI S`) e um segundo laço de microfone brigaria com o detector atual. Então ele fica **opcional e fora**, com o motivo escrito na própria aba Voz — em vez de um botão que promete e não entrega.
- **APK maior, e por quê.** As bibliotecas nativas (arm64-v8a + armeabi-v7a) somam ~53 MB. Para não crescer mais, `abiFilters` corta as ABIs de emulador (x86/x86_64), que nenhum aparelho real usa. A assinatura de CI é a mesma: instala por cima da 1.8.0.
- Versão 1.9.0 (versionCode 1900), mesmo pacote `com.jarvis.nova`.

## 1.8.0 — 2026-10-24
- **Por que a palavra de ativação “não detectava” (causa medida, não suposição).** Rodei o Vosk de português com voz masculina brasileira (Piper Faber, 12 frases com “Jarvis” e 8 sem): a frase inteira é transcrita, mas “Jarvis” sai como **“já vi”**, **“aviso”**, **“javis”** ou **“charvis”** — a palavra não existe no vocabulário do transcritor. O detector grátis do Android usa esse mesmo tipo de transcritor, então ele abria o microfone, não achava a palavra e fechava. O laço não estava “quebrado”; o motor é que era surdo ao nome.
- **Detector grátis mais tolerante.** Agora pede **5 hipóteses** ao Android e confere **todas** (a palavra costuma aparecer numa delas), aceita mais variantes fonéticas (`javis`, `jarvy`, `jarves`, `charves`, `jar vis`…) e usa **sessões de até 15 s** com mais silêncio tolerado. Isso também acaba com o “pisca-pisca” do ícone de microfone, que antes abria e fechava a cada 200 ms.
- **Fim do religa-e-falha.** Quando a escuta falhava de forma fatal (idioma offline ausente, permissão negada, rede), o vigia continuava religando a cada 15 minutos para falhar de novo — microfone ligando e desligando sem nunca responder. Agora a falha desliga a preferência e cancela o vigia; só você religa.
- **Botão “Desligar escuta em segundo plano”** em Ajustes ▸ Voz, além do toggle do topo e do botão da notificação (agora “Desligar escuta”). Ele encerra o serviço, solta o microfone e cancela o vigia — nada volta sozinho. “Pausar” continua sendo a pausa momentânea.
- **A voz salva não muda mais sozinha.** A escolha era recalculada a cada abertura do app e podia trocar quando o motor de voz mudava. Agora é fixada; só é substituída se a voz realmente não estiver mais instalada, com aviso no registro. Se você escolher uma voz de outro idioma, o texto é falado nesse idioma em vez de misturar voz e idioma.
- **Perfil “Jarvis completo”** (tom 0,55 e velocidade 0,88) e busca de voz masculina ampliada (nomes brasileiros e britânicos, além de `pt_BR-faber`, `pt_BR-cadu` e `pt_BR-jeff`). A aba Voz explica como instalar uma voz masculina brasileira offline via Piper/SherpaTTS — é o caminho honesto para um timbre mais próximo do filme, porque o app não inventa um timbre que o motor do aparelho não tenha.
- **IA mais conversadora e com mais humor.** O prompt ganhou regras explícitas de fio da conversa, pergunta de esclarecimento quando o pedido é ambíguo, explicação causa/efeito, pesquisa com fontes primárias e o que não foi confirmado, e opinião própria. O humor seco/irônico entra a partir de 40% e fica mais afiado em 70%+. “Respostas curtas” deixou de vir ligado por padrão (era o que deixava tudo em 1 frase e sem personalidade).
- **Substitutos do Picovoice pesquisados e não embarcados, com motivo.** `sherpa-onnx`: o runtime Android tem KWS, mas **não existe modelo oficial de português** (só chinês, inglês e zh-en) — testado antes, erra a pronúncia brasileira. `openWakeWord`: treinado em inglês e os pesos prontos são **CC BY-NC-SA** (não comercial). `Voicute`: modelo “Jarvis” em inglês, download de modelo customizado é pago. `DaVoice`: modelo `.dm` licenciado pelo fornecedor, preço não público. `Rhino`/`Cheetah`: são intent/STT, não wake word, e também pedem AccessKey. Sem modelo pt-BR livre e confiável, embarcar 50 MB de engine que erra a palavra seria pior que dizer isso com clareza.
- Versão 1.8.0 (versionCode 1800), mesmo pacote `com.jarvis.nova` e mesma assinatura de CI: instala por cima da 1.7.2.

## 1.7.2 — 2026-10-23
- **“Baixar e instalar” consertado.** O erro `Failed to find configured root that contains /data/data/com.jarvis.nova/files/updates/jarvis-update.apk` vinha de **dois** `FileProvider` com a mesma authority: o template do Capacitor já declara um apontando para `@xml/file_paths` (sem `files/`), e o patch adicionava outro. O Android ficava com o do template e recusava o APK baixado. `patch_manifest.py` agora remove qualquer `FileProvider` existente e deixa **um só**, apontando para `@xml/jarvis_paths` (`files-path updates/`), com teste de regressão em `tests/test_fileprovider.py`.
- Quem está na 1.5.1 precisa instalar esta versão uma vez pelo release (o botão interno ainda está quebrado nessa versão); da 1.7.2 em diante a atualização pelo app funciona.
- Versão 1.7.2 (versionCode 1702).

## 1.7.1 — 2026-10-23
- **Assinatura de release agora é fixa de verdade.** O workflow copiava `ci/debug.keystore` para `~/.android/debug.keystore`, mas o Gradle não usava esse arquivo em todos os casos: cada build de CI gerava uma chave de debug nova e as releases 1.6.0 (`40f8280e…`) e 1.7.0 (`b45d3f43…`) saíram com assinaturas diferentes entre si — o Android recusaria a atualização por cima. `patch_gradle.py` passou a declarar `signingConfigs.debug` apontando para `ci/debug.keystore` com as credenciais do keystore, e um teste garante que isso não se perca. Verificado com `HOME` limpo, sem `~/.android/debug.keystore`: o APK sai com o certificado `04e04712…`, o mesmo do app já instalado.
- Versão 1.7.1 (versionCode 1701). Nada de comportamento mudou em relação à 1.7.0.

## 1.7.0 — 2026-10-23
- **Motor da palavra de ativação escolhível** em Ajustes ▸ Voz: `Automático` (Porcupine quando há AccessKey, senão Android), `Android (grátis)` e `Porcupine`. A escolha fica em `JarvisPrefs`, sobrevive ao reinício e o serviço a respeita; se o Porcupine estiver selecionado sem chave, o app avisa em vez de cair calado no outro detector. Trocar o motor com a escuta ligada reinicia o detector na hora.
- **Sherpa-ONNX avaliado e descartado com medição, não por opinião.** O modelo oficial `sherpa-onnx-kws-zipformer-gigaspeech-3.3M` (Apache 2.0, int8 ≈ 5,4 MB, AAR de 50 MB) foi executado aqui: reconhece “Jarvis”/“Hey Jarvis” em inglês, mas em português acertou 1 de 4 frases com limiar 0,10 e 0 de 4 no limiar padrão (0,25) — mesmo com voz masculina brasileira. O `hey_jarvis` do openWakeWord é treinado em inglês e o modelo é **CC BY-NC-SA** (não comercial). Por isso a 1.7.0 não embute 50 MB de engine que erraria a sua pronúncia: o motor gratuito continua sendo o reconhecedor do Android, agora selecionável e diagnosticável.
- **Voz estilo filme.** Perfis prontos em Ajustes ▸ Voz — `JARVIS do filme` (tom 0,60 e velocidade 0,90), `Ultra grave` (0,50/0,85) e `Padrão` — que ajustam tom e cadência de uma vez, sem travar o ajuste fino dos sliders. A busca por voz masculina ganhou nomes britânicos e brasileiros (Arthur, George, James, Joaquim, Duarte…).
- **Sinal do HUD:** duas notas curtas antes de cada resposta falada, opcional (desligado por padrão). É gerado por WebAudio, sem arquivo de áudio, e nunca impede a fala.
- **Comandos de voz:** “voz do filme”, “voz ultra grave”, “voz normal”, “liga/desliga o sinal do HUD”.
- **Mídia pelo player de verdade.** `controleMidia` passou a usar a sessão de mídia do Android (`MediaSessionManager`), que funciona com Spotify e YouTube Music; o envio de teclas virou fallback para quem não deu acesso às notificações. Antes só existiam as teclas, que o Android moderno ignora na maioria dos aparelhos. Novo `midiaAtual` responde app, faixa e artista.
- **Spotify:** novo `tocarNoSpotify` abre a busca (`spotify:search:`), as curtidas (`spotify:collection`) ou o player, com fallback para o player web. Comandos: “toca Evidências”, “toca Bohemian Rhapsody no Spotify”, “abre minhas curtidas”, “o que está tocando”, além de pausar/continuar/próxima/anterior. O app diz com clareza que o Spotify não aceita iniciar a faixa sozinho — o toque no resultado é seu.
- Versão 1.7.0 (versionCode 1700), mesmo pacote `com.jarvis.nova` e mesma assinatura de CI: instala por cima da 1.6.0.

## 1.6.0 — 2026-10-22
- **Escuta que sobrevive ao app fechado e ao reinício.** O estado desejado saiu do `localStorage` e foi para `JarvisPrefs` (armazenamento privado), com a AccessKey do Porcupine cifrada em AES/GCM no Android Keystore. O serviço voltou a ser `START_STICKY`: ao ser reiniciado sem comando, lê o estado e retoma com o mesmo detector. Se o Keystore for invalidado, a chave é descartada em vez de cair para texto puro.
- **Vigia de recuperação (`JarvisWatchdog`).** Alarme inexato (`setAndAllowWhileIdle`) a cada 15 minutos reinicia o serviço quando o fabricante o encerra; o alarme concede a isenção que o Android 12+ exige para subir um serviço de microfone a partir do fundo. Também é agendado em `onTaskRemoved`, na falha do serviço e ~20 s após o boot (o Android 14+ bloqueia microfone direto do BOOT_COMPLETED).
- **Auto-rearme de 9 s** quando o Android bloqueia a abertura da tela na ativação, para a escuta não ficar muda até o próximo alarme — respeitando a pausa pedida pela interface.
- **Notificação acionável:** botões “Ouvir agora” (abre o app e começa a ouvir, mesmo com o processo morto, via `JarvisOuvirReceiver`) e “Parar”.
- **Diagnóstico do segundo plano** em Ajustes ▸ Voz: microfone, notificações, isenção de bateria, sobreposição, acesso às notificações, serviço/detector, última ativação, último erro e dica do fabricante — cada linha com o botão que resolve. Comandos: “Jarvis, diagnóstico do segundo plano” e “por que a escuta parou”.
- **Teste da palavra de ativação (20 s)** que conta acertos sem abrir o app, com resumo de calibração e falsos positivos.
- **Atalho de início automático por fabricante** (Xiaomi, Samsung, Motorola, Huawei, Oppo/Realme/OnePlus, Vivo, Asus), com fallback para as informações do app.
- **Lembretes de tarefas:** prazo agenda aviso às 09:00 do dia pelo agendador persistente; concluir ou excluir cancela.
- **Removido o checkbox “Serviço em segundo plano”**, que podia parar o serviço com a escuta ligada — uma das causas de a ativação morrer em silêncio.
- Versão 1.6.0 (versionCode 1600), mesmo pacote e mesma assinatura de CI da 1.5.1.

## 1.5.0 — 2026-10-21
- Código-fonte movido para a raiz do repositório (fim do ZIP obrigatório) e removidos relatórios/checklists/auditorias obsoletos, `__pycache__` e LEIA-MEs duplicados. O workflow continua compatível com `JARVIS-NOVA-*-fonte.zip`.
- **Palavra de ativação sem Picovoice:** detector livre no `JarvisBackgroundPlugin` — sessões curtas do `SpeechRecognizer` do Android (preferindo o reconhecimento no dispositivo do Android 12+, offline) com backoff progressivo e pausa durante música; Porcupine continua sendo o detector preferido quando há AccessKey. A interface deixa de exigir AccessKey para escutar e informa qual detector está ativo.
- **Reconhecimento do dono:** após a ativação, o perfil acústico (3 amostras) é comparado com quem falou; sem correspondência ele recusa com humor e volta a esperar “Jarvis”. Controle em Ajustes ▸ Voz (experimental, não é autenticação).
- **Novas ações:** lanterna (permissão de câmera), brilho (Modificar configurações), painel de notificações/quick settings com fallback honesto, volume por stream e percentual, e-mail pelo app do aparelho, fechar app pela tela de detalhes, versão instalada e atualização; novos apps Configurações/Galeria/Play/Relógio com fallback por fabricante; comandos rápidos correspondentes.
- **Atualizador (Atualizador + ApkProvider + release no GitHub):** plugin `JarvisUpdate` consulta o release mais novo, baixa o APK para `files/updates/`, verifica SHA-256 quando o GitHub informa o digesto e instala via FileProvider com `REQUEST_INSTALL_PACKAGES`; aba “Atualização” na interface; workflow `release-apk.yml` publica o APK por tag `v*`; assinatura de CI fixa em `ci/debug.keystore` para manter a atualização por cima viável.
- **Cérebro local básico:** sem chave e sem modelo `.task`, hora/data/contas/versão/comandos ainda respondem (chip “IA: local básica”) nos três fallbacks (sem chave, APIs falhando e modo offline).
- **Humor:** piadas próprias por comando, saudação variada conforme o nível de humor e bordões discretos, suspensos em assuntos sensíveis.
- **Interface:** central de comando lateral (telas largas), dashboard com medidores de bateria/RAM/armazenamento, tira de comandos rápidos no celular, marca central e varredura no HUD, acabamento sci-fi (cantos acesos e scanline sutil).
- Testes: suíte ampliada com `tests/test_novos_recursos.py` (34 verificações); versão 1.5.0/versionCode 1500 em `VERSAO.json`, `package.json` e workflows. Compilação Android e testes físicos das funções novas permanecem pendentes de validação.

## 1.5.0 — HUD refinado — 2026-10-21
- Núcleo central no estilo reator: centro escuro com aro aceso, coroa pontilhada, anel interno girando em sentido inverso e marca “JARVIS” legível sobre o miolo.
- Grade radial de 30 setores, eixos cardinais com arco de canto e anel duplo de marcas (finas + quatro marcas fortes).
- Satélites luminosos orbitando em duas velocidades opostas, mantendo a varredura de arco na borda.
- Telemetria curta em volta do anel (AUDIO / LINK / SYS / CORE) e subtítulo de versão dentro do núcleo; escondidas em telas estreitas ou baixas.
- Cores continuam reagindo ao estado (ouvindo/processando/falando) via `--rgb`, e todas as animações novas respeitam `prefers-reduced-motion`.

## 1.5.0 — revisão de correções — 2026-10-21
- Detector livre agora pausa **durante chamadas telefônicas e VoIP** (antes só a mídia pausava), devolvendo o microfone ao usuário e retomando a escuta sozinho quando a chamada termina.
- Instalador do atualizador deixa de recusar instalação por engano em Android 11+: `resolveActivity` retornava nulo sem `<queries>`; foi adicionada a visibilidade da intent `application/vnd.android.package-archive` e o código passa a tratar somente `ActivityNotFoundException`.
- Corrigido “deste origem” → “desta origem” na mensagem de permissão de instalação.
- `JarvisService` não lança mais NPE quando o pacote não expõe intent de lançamento.
- Pedido de notificação só é feito com Activity disponível (evita crash ao iniciar em segundo plano).
- Fala de “verificar atualização” mostra o tamanho do APK em MB (antes exibia um `build ?` sem sentido).
- Interface explica que o detector livre mantém o microfone em uso e o indicador verde do Android visível, e que chamadas têm prioridade.

## 1.2.7 — auditoria final pré-repositório — 2026-10-16
- Corrigido escape do comando `find -exec` no workflow, que poderia interromper a extração da fonte no GitHub Actions.
- Ajustados os rótulos visuais para “Hey Jarvis”, correspondentes ao modelo openWakeWord configurado.
- O salvamento de novas chaves no Android agora falha de forma explícita se o cofre nativo não estiver disponível, em vez de gravar silenciosamente em texto puro.
- Chaves legadas em texto puro no Android são migradas para o cofre quando possível; se a migração falhar, a cópia insegura é removida e o usuário é avisado.
- Tornado idempotente o patch de versão Android e adicionados testes de prontidão de release.
- Build debug real concluído com sucesso no GitHub Actions em 2026-10-16; testes físicos continuam pendentes.

## 1.2.5 — 16/10/2026
- Corrigidas definições duplicadas de métodos Java no plugin nativo de ativação por voz.
- Validador agora procura assinaturas Java duplicadas.
- Workflow e metadados atualizados para versionCode 1205.
- Build Android e testes físicos continuam pendentes.

## 1.2.3 — 2026-10-15 (fonte em revisão; sem APK)

- Habilitada como opção manual a ativação experimental pela palavra “Jarvis”, usando o `SpeechRecognizer` do Android e podendo reconhecer a palavra seguida do comando.
- O modo permanece desligado por padrão e a interface explica que não é detector dedicado de baixo consumo.
- O serviço em primeiro plano só é iniciado para a escuta experimental quando a preferência de segundo plano está ativa; alarmes/lembretes continuam independentes.
- Removido o `PARTIAL_WAKE_LOCK` incondicional de até 12 horas, reduzindo consumo desnecessário quando a escuta não está ativa.
- Ajustados os textos da notificação, a declaração de tipo do serviço e a documentação para não sugerir reprodução de mídia nem eficiência de bateria não medida.
- Pendente: detector local dedicado (ex.: engine compatível/licença validada), execução robusta com processo encerrado/tela bloqueada, testes em dispositivos reais, bateria e conflito com música.

# Changelog

## 1.5.1 — 2026-10-22

- **Segundo plano real:** a detecção da palavra “Jarvis” foi movida do plugin (que morria junto da
  Activity) para o `JarvisService`, com notificação de estado, ponte `JarvisWakeBus`, parada
  explicada por falha e tentativa de reabrir o app quando o nome é chamado.
- **Atualizador:** `/releases/latest` com 404 deixou de ser tratado como erro de conexão; há busca
  na lista de releases, mensagens por código HTTP (401/403/404) e botão “Ver releases no navegador”.
- **Reconhecimento de voz:** `EXTRA_PREFER_OFFLINE` só é usado no modo local; troca automática entre
  reconhecedor local e de rede (códigos 12/13/14, sem rede) e mensagens específicas. Sem chave de
  transcrição, o Android é usado direto, sem gravar duas vezes. O detector livre para com explicação
  depois de falhas seguidas, em vez de repetir em silêncio.
- **Perfil acústico:** vetor de 6 características calculado apenas sobre quadros com fala, DFT
  corrigida (bins pares não são mais ignorados) e comparação por distância normalizada. Silêncio e
  ruído são recusados; a exigência de voz passou a vir desligada (limiar 60%).
- **Medidor de áudio:** a barra passou a usar escala em decibéis; antes `rms * 6` saturava em
  100% com qualquer som acima de 0,17, então o medidor não distinguia voz de ruído.
- **Ajustes:** botões “Impedir suspensão pela bateria” e “Permitir abrir na tela”; permissão
  `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` no manifesto.
- Versão 1.5.1 (versionCode 1501), mesmo pacote e mesma assinatura de CI da 1.5.0.

## 1.2.2 — 2026-10-15
- Adicionada importação explícita e consentida de contatos do Android para a lista local.
- A permissão READ_CONTACTS é solicitada apenas ao tocar em “Importar contatos do Android”.
- Importação limitada a 500 entradas por execução; números e nomes não são enviados automaticamente ao provedor de IA.
- Abertura do WhatsApp já existente via atalho nativo; mensagens continuam exigindo revisão/envio manual.
- Palavra de ativação dedicada de baixo consumo continua pendente; o SpeechRecognizer contínuo não é apresentado como detector equivalente ao “Ok Google”.


## 1.2.1 — 2026-10-15 (fonte em desenvolvimento; sem APK validado)

- Contatos: normaliza emojis, pontuação, acentos e letras repetidas em nomes ditados (ex.: “Biaa🩵🩵” pode corresponder a “Bia”). Correspondência por prefixo só é aceita quando há um único resultado; em casos ambíguos, não escolhe um contato automaticamente.
- Personalidade: instruções mais consistentes para competência, humor seco e ironia leve inspirados no arquétipo de assistente tecnológico; evita imitar falas de filmes e reduz humor em situações sensíveis.
- Bateria/rede: removidas chamadas extras de pré-aquecimento à API que ocorriam na inicialização e antes de iniciar a escuta.
- Privacidade/bateria: ativação experimental por fala desligada por padrão. O mecanismo atual continua baseado em `SpeechRecognizer` e não satisfaz o requisito de um detector dedicado de baixo consumo semelhante ao “Ok Google”.
- PENDENTE: integrar detector local de palavra-chave com modelo/licença verificados, áudio de baixa potência quando suportado, ciclo de vida Android e testes físicos. Não declarar essa função concluída nem gerar release até validar.
- Voz, calibração de microfone, chamadas, SMS/WhatsApp, notificações, alarmes, temporizadores, tarefas, rotinas, provedores de IA e diagnóstico já possuem partes implementadas na base 1.2.0; precisam de testes de regressão e validação por aparelho antes de serem considerados totalmente confiáveis.

## 1.2.0 — 2026-10-15 (patch de escuta; requer compilação e teste físico)

- Adicionada opção “Priorizar música e vídeos”: quando ativada, a escuta experimental da palavra “Jarvis” é suspensa enquanto o Android reporta reprodução de mídia e retomada quando ela termina. Durante a reprodução, o usuário deve tocar no microfone para dar um comando.
- Corrigido o agendamento de reinício da escuta para usar uma única tarefa pendente, evitando acumular reinícios concorrentes.
- Limitação conhecida: isto é uma proteção intermediária, não o comportamento completo do “Ok Google”. A detecção por palavra ainda usa `SpeechRecognizer`; para ativação por voz enquanto a música toca sem disputa de áudio, falta integrar um detector local de palavra-chave dedicado e validá-lo em aparelhos reais.
- O APK não foi recompilado nem testado em aparelho físico nesta alteração.

- Revalidação estática completa do pacote-fonte; testes automatizados e sintaxe JavaScript aprovados.
- Corrigida a inicialização da voz TTS no listener de notificações, que impedia o anúncio de chamadas.
- Adicionada verificação e solicitação de acesso especial para alarmes exatos no Android 12 ou posterior.
- A restauração de alarmes preserva lembretes válidos quando o sistema bloqueia temporariamente o agendamento e tenta restaurá-los novamente ao abrir o app.
- Adicionado `.gitignore` para excluir dependências locais, builds e cache Python do controle de versão.
- APK não foi compilado nem testado em aparelho físico neste ambiente.

## 1.1.0 — 2026-10-14 (código-fonte; APK depende de compilação/teste)

- Mantém Groq como prioridade e as opções de chave Gemini, Cerebras e Mistral existentes, com fallback já presente no projeto.
- Adiciona modo offline que bloqueia chamadas de IA e testes de rede; comandos locais continuam disponíveis.
- Usa reconhecimento de voz nativo em modo estritamente local quando o Android oferece esse recurso. Palavra de ativação offline exige reconhecimento on-device; se indisponível, a função não deve recorrer silenciosamente à rede.
- Adiciona comandos locais para pausar/retomar mídia, faixa seguinte/anterior, volume, status de bateria/conexão, sair para a tela inicial e reabrir aplicativos conhecidos.
- Adiciona composição de SMS com texto preparado; o usuário revisa e toca em enviar. Mensagens de WhatsApp continuam abrindo com texto preparado, sem envio silencioso.
- Adiciona leitura de até dez resumos de notificações recentes após autorização explícita do Android e tentativa de resposta rápida à última notificação que exponha RemoteInput.
- Adiciona anúncio opcional de chamadas apenas quando o Android classifica a notificação como chamada e o usuário ativa a opção.
- Adiciona abertura da agenda e criação de evento por meio do editor de calendário do Android, para revisão e salvamento pelo usuário.
- Mantém alarmes e lembretes persistentes, rotinas, memória configurável, diagnóstico e modo de conversa ampliada.
- Ações sensíveis continuam sujeitas ao modo seguro e à confirmação. O modo seguro pode bloquear ligações e mensagens até ser desligado em Ajustes; a confirmação permanece obrigatória.
- O encerramento forçado de outros apps não é oferecido: o comando de saída volta à tela inicial e o comando de retorno tenta reabrir o app conhecido.

### Limitações conhecidas a testar no aparelho

- A disponibilidade de reconhecimento local em português varia conforme versão do Android, serviço de voz e pacotes instalados.
- Leitura de notificações exige ativação manual do acesso especial. O conteúdo lido é apenas o que aparece na notificação, não o histórico completo de conversas.
- Resposta por voz só funciona se a notificação ativa fornecer ação de resposta rápida compatível.
- Anúncio de chamada depende de o aplicativo de telefone emitir notificação categorizada como chamada; fabricantes podem variar.
- Controles de mídia dependem do aplicativo de reprodução.
- O evento de calendário é aberto para revisão e precisa ser salvo pelo usuário.
- O Android pode impedir o reinício automático de serviço com microfone após reinicialização; alarmes são restaurados, mas o usuário pode precisar abrir o J.A.R.V.I.S. novamente para reativar escuta.
- Ainda não há validação física de chamadas, notificações, mídia, voz offline ou build Android nesta etapa.


## 1.2.4 — 16/10/2026
- Substituída a detecção contínua por `SpeechRecognizer` por um detector local dedicado Porcupine 4.0.2 para a palavra integrada JARVIS.
- O reconhecimento completo começa somente depois da palavra de ativação; o fluxo orienta o usuário a aguardar o bipe antes de falar o comando.
- Adicionado campo para AccessKey Picovoice com armazenamento no cofre nativo do Android quando disponível e ação para apagar a chave.
- Pausa opcional do detector durante música/vídeo para reduzir conflito de áudio.
- Refinada a personalidade: cortesia impecável, calma, humor seco e sarcasmo sutil e ocasional, sem reproduzir diálogos dos filmes.
- Incluída dependência nativa Porcupine no workflow de build e verificações estáticas específicas.
- Pendente: compilação Gradle no CI, validação com AccessKey, testes em aparelho Android e medição de bateria.


## 1.2.6 — evolução baseada na fonte 1.2.5

- Detector local openWakeWord sem AccessKey, com modelo “Hey Jarvis” (inglês); precisa de teste físico e verificação da licença do modelo antes de distribuição comercial.
- Mini-interface compacta de ativação ao detectar a palavra de ativação.
- Aba “Celular” com bateria, temperatura reportada pela bateria, armazenamento, RAM, conectividade, dados do aparelho e atalhos para configurações do Android.
- Avisos básicos quando armazenamento/bateria estão baixos ou a temperatura reportada está elevada.
- Links oficiais para cadastro de chaves de IA e avisos de cotas/limites.
- Mantidos os limites de segurança do Android: mensagens e chamadas não são enviadas silenciosamente e controle irrestrito de outros apps não é prometido.
- Build Gradle e validação em aparelho ainda pendentes.


## 1.2.7 — personalidade configurável e fluxo WhatsApp
- Corrigida a resposta falada do status do aparelho para não anunciar “Bateria: -1%” quando a leitura não está disponível.

- Adicionados controles de intensidade de humor e estilo de resposta (equilibrado, formal, amigável ou técnico).
- Preferências de personalidade são salvas localmente e usadas na instrução de sistema da IA.
- Adicionado comando para abrir a conversa do WhatsApp com um contato cadastrado.
- Comandos que mencionam chamada de voz/vídeo pelo WhatsApp abrem a conversa e explicam que o usuário precisa confirmar e tocar no controle de chamada dentro do WhatsApp; não há chamada silenciosa.
- Atualizados versão, validador e workflow de compilação para 1.2.7.
- Build debug confirmado como concluído com sucesso no GitHub Actions em 2026-10-16.
- Limitações mantidas explicitamente: “Hey Jarvis” em inglês; não há controle universal de qualquer app nem leitura automática do app em primeiro plano sem permissão especial. Testes físicos continuam pendentes.


## Ajuste de preparação do APK (1.2.7)

- Definida API mínima Android 26 no patch Gradle, necessária para openWakeWord Android.
- Adicionado teste automatizado de idempotência para dependência, JitPack e API mínima.
- Build debug confirmado como compilado com sucesso no GitHub Actions; a validação física continua pendente.

## Revisão incremental pós-1.2.7 — status rápido e Picovoice
- Adicionado atalho clicável “Status do celular” na tela principal para abrir diretamente o painel de estado.
- Painel de status agora separa a conexão ativa, Wi-Fi e dados móveis, além de bateria, temperatura da bateria, armazenamento com alertas, RAM, modelo/Android e último app iniciado pelo próprio JARVIS.
- Adicionado campo de AccessKey Picovoice com link oficial, instruções e opção para apagar; no Android, a chave é guardada pelo mesmo cofre nativo.
- Importante: guardar a AccessKey não ativa Picovoice. O detector desta versão continua sendo openWakeWord (“Hey Jarvis”); integração nativa Porcupine, modelo de wake word e testes em dispositivo são trabalhos separados.
- Testes estáticos `npm run test:all` aprovados após as mudanças. O APK existente não contém estas alterações; é necessária uma nova execução do GitHub Actions.


## 1.2.9 — integração de wake word e inteligência comportamental

- Integra SDK Porcupine Android 4.0.2 e usa a palavra integrada “Jarvis” quando há AccessKey.
- Mantém openWakeWord “Hey Jarvis” como fallback sem AccessKey.
- O estado visual e a orientação falada refletem qual detector está selecionado.
- Personalidade/humor têm prévia e orientação explícita para salvar as preferências.
- Build Android e testes de microfone/AccessKey ainda precisam ser confirmados no GitHub Actions e em aparelho físico.


## 1.3.0 — Base de segurança e configurações
- Desktop Electron: migração de chaves de API e Picovoice para o `safeStorage` do sistema operacional, com arquivo cifrado no diretório privado do aplicativo.
- Falha fechada se o cofre do sistema não estiver disponível; o app não grava novas chaves em texto puro no navegador comum.
- Migração de chaves legadas em texto puro: tenta protegê-las e remove a cópia antiga; se a proteção falhar, remove a cópia insegura e pede recadastro.
- Interface de AccessKey Picovoice esclarece que a chave é salva ao sair do campo, separadamente do botão geral de configurações.
- Adicionados testes estáticos para as regras de armazenamento de segredos.
- Ainda pendente: integração real de inferência de modelo de linguagem local no Android, build Android desta versão e validação em dispositivo físico.


## 1.3.1 — IA local Android experimental
- Adicionada integração nativa experimental com MediaPipe LLM Inference para gerar texto no próprio aparelho a partir de um modelo `.task` compatível importado pelo usuário.
- Adicionada tela de importação, teste e exclusão do modelo local. O modelo fica no armazenamento privado do aplicativo e não é incluído no APK.
- Adicionado fallback local quando nenhuma API está configurada ou quando os provedores configurados falham; o modo offline tenta o modelo local e mantém comandos locais como prioridade.
- A inferência local não recebe chaves de API. O runtime MediaPipe usado nesta etapa está em manutenção; avaliar migração para LiteRT-LM após prova de conceito e build real.
- Build Android e teste em aparelho ainda pendentes.

## 1.4.2 — 2026-10-20
- Adicionado perfil acústico experimental local, com captura iniciada pelo usuário, comparação indicativa e exclusão do vetor salvo.
- Melhorada a troca de modelo MediaPipe com arquivo temporário e tentativa de rollback.
- Workflow agora registra checksum e metadados de compilação no artefato.
- Criados auditoria técnica e checklist específico para validação no POCO X7.
- Limitações mantidas explícitas: Porcupine exige AccessKey; IA local depende de modelo .task compatível; perfil acústico não é autenticação biométrica; APK e dispositivo físico ainda precisam ser validados.
