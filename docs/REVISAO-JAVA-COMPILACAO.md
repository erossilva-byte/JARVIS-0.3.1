# Revisão de compilação e ciclo de vida — Java da Fase 4B

Data: 2026-11-13 · Revisor: leitura integral dos arquivos + documentação oficial do Android
Escopo: `JarvisService.java`, `JarvisPrefs.java`, `JarvisManutencaoWorker.java`,
`JarvisKwsEngine.java` (método novo), `JarvisBackgroundPlugin.java` e `JarvisBootReceiver.java`.

**Sem Android SDK nesta máquina:** nada aqui foi compilado. A revisão é de código e de API,
não substitui o CI.

## 1. Defeitos encontrados e corrigidos

### 1.1 A detecção de "outro app no microfone" nunca funcionava (grave)

O código comparava `getClientPackageName()` com o pacote do app. A documentação do AOSP diz
que esse método **só devolve o nome com a permissão `MODIFY_AUDIO_ROUTING`**, que é de sistema;
sem ela o retorno é string vazia
([fonte](https://android.googlesource.com/platform/frameworks/base/+/master/media/java/android/media/AudioRecordingConfiguration.java)).
Como o app é comum, a lista vinha sempre com pacote vazio e a condição nunca era verdadeira:
o microfone ocupado passava batido e o painel dizia "livre" mesmo com o gravador aberto.

Correção: a lista de gravações continua disponível (não exige permissão), então a detecção agora
usa a **sessão de áudio do nosso próprio `AudioRecord`** (`getClientAudioSessionId()`), que é
pública, para ignorar a nossa captura. Qualquer outra sessão ativa bloqueia a escuta. Enquanto
gravamos, uma entrada sem nome é a nossa; duas indicam outro app. O nome do pacote só é citado
quando o Android realmente o entrega.

### 1.2 O aviso de fone sobrescrevia a pausa manual (médio)

`pausarPorFone()` não consultava `pausadoManual`. Quem pausava pelo botão e depois tirava o fone
via a notificação dizer "pausada: o fone foi desconectado" — e, como o laço de 1 s estava parado,
nada voltava em 5 s. Agora a pausa manual vence e o aviso do fone é ignorado nesse estado.

### 1.3 O teste dizia "diga Jarvis" com o microfone bloqueado (médio)

`ACAO_TESTE_ON` escrevia a mensagem logo depois de pedir a escuta, antes de saber se o motor
abriu. Com perfil "Somente carregando", bateria baixa ou microfone tomado, o teste exibia a
instrução e terminava com 0 detecções, parecendo falha do detector. A mensagem passou para o
`onState`, e só aparece quando o estado confirma a captura ativa.

### 1.4 `Result.retry()` sem limite no WorkManager (baixo)

Um erro permanente (permissão, arquivo) faria o Worker repetir para sempre com backoff. Agora
são no máximo duas tentativas por ciclo; o erro continua registrado e o ciclo de 6 h cobre a
próxima.

## 2. Riscos de compilação que o CI precisa confirmar

| Ponto | Risco | Avaliação |
|---|---|---|
| `ContextCompat.registerReceiver(..., RECEIVER_NOT_EXPORTED)` | depende de `androidx.core` ≥ 1.9 | Capacitor 6.1 traz core 1.12 — deve compilar |
| `AUDIO_BECOMING_NOISY` com receiver não-exportado | Android 14 dispensa a flag para broadcast de sistema | `AUDIO_BECOMING_NOISY` é broadcast protegido; deve ser entregue — confirmar no aparelho |
| `registerReceiver(null, ACTION_BATTERY_CHANGED)` | exigência de flag no Android 14 | consulta "sticky" com receiver nulo é isenta; sem flag no código |
| `Notification.Builder(Context, String)` no 2º fallback | construtor só existe na API 26 | `minSdk 26` — dentro da faixa |
| `androidx.annotation.NonNull` no Worker | pode faltar no classpath | vem transitivamente com `androidx.core`; se faltar, o CI acusa |
| WorkManager sem init manual | precisa do `InitializationProvider` no manifesto final | `patch_manifest.py` não o remove — conferir no APK |
| `getActiveRecordingConfigurations()` | OEM pode devolver lista vazia ou parcial | vazio é tratado como "livre"; não trava a escuta |

## 3. Ciclo de vida — o que está correto e o que é comportamento esperado

- **Receptor do fone**: registrado em `onCreate` com `try/catch` e desregistrado em `onDestroy`
  apenas se o registro ocorreu. Recomeço do serviço cria instância nova — sem registro duplicado.
- **Primeiro plano**: `promoverPrimeiroPlano()` roda em `onCreate` e em `onStartCommand`, antes de
  qualquer ramo, com segunda tentativa mínima e `stopSelf()` se as duas falharem. Cobre o prazo
  de 5 s em todos os caminhos, inclusive "parar" e "sem permissão".
- **Perfil bloqueando**: `aplicarPerfil` desliga `querEscuta` e remove o laço; a reavaliação
  seguinte fica por conta do vigia (até 15 min) ou de uma nova ação do usuário. É latência
  aceitável, mas **precisa estar na ficha de medição** — não é retomada instantânea.
- **Pausa manual**: sobrevive a `START_STICKY`, reinício e vigia; o serviço continua em primeiro
  plano com a notificação "Retomar". Nenhum caminho religa o microfone por cima dela.
- **Teste**: ao terminar, retoma a escuta normal só se `desejaOuvir` e não houver pausa manual.
- **Falha fatal**: desliga o desejo, cancela o vigia, registra o erro e encerra o serviço em 2 min
  se ninguém religar — sem laço de reinício.
- **Worker**: roda em thread de background, só usa `SharedPreferences` e APIs de contexto; não
  toca em `Handler`, `WebView` nem no motor de áudio.

## 4. Limites desta revisão

Não foram verificados: tipos genéricos de ponta a ponta, versões reais das dependências no
classpath do Gradle, comportamento em HyperOS, entrega do broadcast de fone no aparelho e
`getActiveRecordingConfigurations()` com outros apps gravando. Tudo isso depende do CI e do Poco
X7, e está no checklist de `FASE-4B-ACEITE.md`.

---

# Segunda parte — música, acessibilidade, atualização e voz

Data: 2026-11-13 · Mesmo critério: leitura integral, documentação da API e ciclo de vida.
Arquivos: `JarvisMusicaService.java`, `JarvisMusicaPlugin.java`, `JarvisAcessibilidade.java`,
`JarvisAcessibilidadePlugin.java`, `JarvisUpdatePlugin.java`, `JarvisVozPlugin.java`.

## 6. Defeitos corrigidos

### 6.1 `MediaPlayer` vazado quando o arquivo é inválido (médio)

Em `JarvisMusicaService.tocarIndice`, o `MediaPlayer` era criado dentro do `try`; se
`setDataSource` falhasse (URI revogada, arquivo apagado), o `catch` pulava para a próxima faixa
sem soltar o player nativo. Uma fila com vários arquivos inválidos acumulava players. Agora o
`catch` faz `release()` antes de seguir.

### 6.2 Serviço de música seguia "tocando" sem primeiro plano (grave)

`iniciarPrimeiroPlano()` engolia as duas falhas de `startForeground` e continuava. Como o serviço
nasce de `startForegroundService()`, o Android encerra o processo em segundos com
`ForegroundServiceDidNotStartInTimeException` — o mesmo defeito já corrigido no serviço de escuta.
Agora a função devolve `boolean`, e o `onStartCommand` encerra em vez de tocar sem notificação.

### 6.3 `esperar` de acessibilidade travava a interface (grave)

Métodos de plugin do Capacitor rodam na thread principal. `JarvisAcessibilidade.esperar` dorme em
laço de 180 ms por até 8 s — tempo suficiente para um ANR — e `arvore`/`clicar`/`digitar`/`rolar`
percorrem a árvore inteira na mesma thread. As cinco operações passaram para uma fila própria
(`ExecutorService` de thread única, encerrada no `handleOnDestroy`); `resolve`/`reject` do
Capacitor funcionam de qualquer thread.

### 6.4 Motor de voz liberado durante a síntese (grave)

`JarvisVozPlugin.handleOnDestroy` chamava `liberarMotor()` e só depois parava a fila. Se uma
síntese estivesse em curso, o `OfflineTts` nativo era liberado debaixo do `generate()` — erro de
memória nativa, que mata o processo sem exceção Java. Agora: para a fila, espera até 1,5 s e só
libera se ela terminou; se não terminou, não libera (o processo está saindo). Além disso,
`generate()` roda sob o mesmo cadeado de `liberarMotor()`, e `motor`/`motorId` são `volatile`.

### 6.5 `InputStream` do download de atualização vazado (baixo)

Em `JarvisUpdatePlugin.baixarAtualizacao`, o stream só era fechado no caminho feliz. Falha no meio
da leitura deixava o stream aberto até o `disconnect()`. Agora fecha em `finally`.

## 7. Riscos de compilação que o CI precisa confirmar

| Ponto | Risco | Avaliação |
|---|---|---|
| `java.util.function.Supplier` no plugin de acessibilidade | desugaring | API 24+, `minSdk 26` — ok |
| `TimeUnit` no `awaitTermination` | nenhum | classe padrão |
| `Notification.Action.Builder` no player | API 23+ | `minSdk 26` |
| FileProvider da atualização | autoridade precisa casar com o manifesto | `com.jarvis.nova.fileprovider`; conferir no APK |
| `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | tipo do serviço de música | declarado em `patch_manifest.py` |

## 8. Ciclo de vida — o que está correto e o que é esperado

- **Música**: player, `MediaSession` e `WakeLock` são soltos no `onDestroy`; estado estático é
  zerado para a tela não mostrar faixa fantasma. `onTaskRemoved` não interrompe a reprodução.
- **Música, pausa durante buffering**: `pausar()` só age com `isPlaying()`; antes do primeiro
  áudio o botão não faz nada. É cosmético, não trava.
- **Música, wake lock**: cada faixa rearma 3 h; uma faixa única com mais de 3 h perderia a trava.
- **Acessibilidade**: `parar()` marca a ação em curso; a próxima começa limpa — é um freio, não um
  interruptor geral. Nós filhos não são reciclados (API 33+ já ignora `recycle`); o limite de 220
  nós por consulta contém o custo.
- **Atualização**: `shutdownNow()` no meio de um download pode deixar a promessa sem resposta; não
  derruba nada. A instalação continua dependendo da confirmação do Android.
- **Voz**: `parar()` interrompe a trilha; o worker a solta no `finally`. `falar` só responde depois
  do fim do áudio — é o comportamento esperado pelo app.
- **Voz, memória do buffer**: o `AudioTrack` é dimensionado para a frase inteira (4 bytes por
  amostra); texto muito longo pode falhar ao inicializar, e a falha é devolvida como erro.

## 9. Limites desta segunda parte

Sem SDK e sem aparelho, não foram verificados: compilação, entrega de áudio em HyperOS, ANR real
sob `esperar`, reciclagem de nós de acessibilidade em Android 8–12 e instalação via FileProvider.
Nada aqui foi medido.

## 10. Terceira parte — plugins restantes (2026-11-14)

Lidos por inteiro nesta rodada: `JarvisSeguranca`, `JarvisNotificationListener`,
`JarvisWatchdog`, `JarvisAlarmReceiver`, `JarvisAtivacao`, `JarvisUtilPlugin`.

Defeitos corrigidos:

- **NFC**: a promessa de `lerTag` ficava pendente se o plugin fosse destruído sem tag.
  `cancelarLeitura()` a resolve com `{cancelado: true}`.
- **Notificações**: faltava `onNotificationRemoved`; a lista estática não era limpa no
  `onDestroy`; havia import duplicado.
- **Watchdog**: reativava o serviço mesmo com pausa manual do usuário.
- **Util, thread**: `cofreStatus`, `cofreListar` e `lerContatos` faziam E/S de SAF e
  `ContentResolver` na thread principal do WebView. Agora usam um executor único (`fundo`) e
  o auxiliar `emFundo`, que devolve a resposta na thread principal e transforma exceção em
  `reject`.
- **Util, streams**: `cofreLer`/`cofreEscrever` fechavam só no caminho feliz; agora em
  `finally`. `listFiles()` tolera `null` de pasta revogada.

Riscos que só a compilação ou o aparelho esclarecem:

- **Concorrência do executor**: `emFundo` recebe um `Supplier<JSObject>`; se o plugin for
  destruído no meio, `shutdownNow` interrompe a tarefa e a promessa pode ficar sem resposta —
  mesmo padrão já aceito em atualização. Um `call` resolvido depois do destroy é ignorado pelo
  Capacitor, não derruba o app.
- **Permissão de contatos**: `aposPermissaoContatos` agora agenda a leitura no executor; o
  callback do Capacitor roda na thread principal, então a ordem (permissão → leitura) se
  mantém, mas isso não foi observado em aparelho.
- **Watchdog**: a consulta a `pausadoManual` usa a mesma preferência do botão de pausa; se o
  nome da chave divergir, a pausa continuaria sendo desfeita. Conferido por leitura, não por
  execução.
- **Listener de notificações**: `onNotificationRemoved` é chamado em versões antigas com
  assinatura diferente; usar `@Override` garante que o método casa com a API compilada, o que
  só o `javac` confirma.
- **Pré-checagem de primeiro plano**: heurística estática. Não cobre laço de nova tentativa
  que termina em `return` sem parar o serviço, nem prova que o caminho feliz promove.

## 11. Limites desta terceira parte

Nada foi compilado nem executado em aparelho: sem JDK, sem SDK Android e sem Poco X7 nesta
máquina. As correções são de leitura e de documentação oficial da API, verificadas pela suíte
JavaScript e pela pré-checagem estática — não por `javac` nem por medição.
