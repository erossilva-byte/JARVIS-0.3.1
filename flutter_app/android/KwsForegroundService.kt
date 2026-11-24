package com.jarvis.nova

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Serviço foreground dedicado ao KWS Flutter. A captura só começa após permissão
 * explícita e após o Android aceitar o serviço do tipo microphone.
 */
class KwsForegroundService : Service() {
    companion object {
        const val ENGINE = "sherpa-onnx-kws-gigaspeech-en"
        const val ACTION_START = "com.jarvis.nova.KWS_START"
        const val ACTION_REARM = "com.jarvis.nova.KWS_REARM"
        const val ACTION_PAUSE = "com.jarvis.nova.KWS_PAUSE"
        const val ACTION_REINICIAR = "com.jarvis.nova.KWS_REINICIAR"
        const val ACTION_CALAR = "com.jarvis.nova.KWS_CALAR"
        const val EXTRA_TEST_SECONDS = "test_seconds"
        // Depois de abrir a tela, o comando assume o microfone e o guarda pelo
        // estado de comando ativo; assim o detector volta rápido. Antes eram 35 s
        // de surdez se a tela não devolvesse o microfone.
        private const val REARM_DELAY_MS = 8_000L
        /** Tentativas de religar o detector sozinho depois de uma falha do motor. */
        private const val MAX_TENTATIVAS_FALHA = 3
        /** Intervalo do vigia que religa o detector se ele morrer em silêncio. */
        private const val VIGIA_MS = 20_000L
        /** Janela em que o vigia não interfere: a ativação acabou de acontecer. */
        private const val JANELA_POS_DETECCAO_MS = 20_000L

        /** Tempo para confirmar um toque de tela antes de descartar o pedido. */
        private const val PRAZO_CONFIRMACAO_MS = 20_000L

        // Frases de ativação escolhidas na tela do Flutter. As linhas já chegam
        // tokenizadas e ficam nas preferências do app; o serviço lê o mesmo
        // arquivo direto, como já faz com o consentimento de acessibilidade,
        // porque com o app fechado não há Flutter para consultar.
        private const val PREFS_FLUTTER = "FlutterSharedPreferences"
        private const val CHAVE_HOTWORD_LINHAS = "flutter.jarvis.hotword.linhas"

        // Sensibilidade da palavra de ativação, guardada no aparelho.
        private const val PREFS_ATIVACAO = "jarvis_kws"
        private const val CHAVE_SENSIBILIDADE = "sensibilidade"
        const val SENSIBILIDADE_PADRAO = 75
        const val SENSIBILIDADE_MINIMA = 0
        const val SENSIBILIDADE_MAXIMA = 100
        /** Folga depois de soltar o microfone, antes de abrir o reconhecedor. */
        private const val ESPERA_MICROFONE_MS = 180L
        /** Quando o AudioRecord não fechou no prazo, espera mais antes de tentar. */
        private const val ESPERA_MICROFONE_LONGO_MS = 600L
        /** Prazo para o AudioRecord do detector fechar de verdade. */
        private const val LIBERAR_MICROFONE_MS = 1_500L
        private const val NOTIFICATION_ID_AUTORIZAR = 14703
        private const val CHANNEL_ID = "jarvis_kws_local"
        private const val CHANNEL_ATIVO = "jarvis_ativo_aviso"
        private const val NOTIFICATION_ID = 14701
        private const val NOTIFICATION_ID_ATIVO = 14702

        @Volatile private var running = false
        @Volatile private var listening = false
        @Volatile private var error = ""
        @Volatile private var comandoAtivo = false
        /** Detector que está com o microfone agora (inclusive enquanto encerra). */
        @Volatile private var motorAtual: JarvisKwsEngine? = null

        @JvmStatic fun isServiceRunning() = running
        @JvmStatic fun isListening() = listening
        @JvmStatic fun lastError() = error
        @JvmStatic fun clearError() { error = "" }
        /** Verdadeiro enquanto o reconhecedor do comando está com o microfone. */
        @JvmStatic fun isCommandActive() = comandoAtivo
        @JvmStatic fun marcarComandoAtivo(ativo: Boolean) { comandoAtivo = ativo }
        @JvmStatic fun clearState() {
            running = false
            listening = false
            error = ""
            comandoAtivo = false
        }

        /** Sensibilidade da palavra de ativação guardada no aparelho (0–100). */
        @JvmStatic fun sensibilidadeDe(context: Context): Int {
            val valor = context.getSharedPreferences(PREFS_ATIVACAO, Context.MODE_PRIVATE)
                .getInt(CHAVE_SENSIBILIDADE, SENSIBILIDADE_PADRAO)
            return valor.coerceIn(SENSIBILIDADE_MINIMA, SENSIBILIDADE_MAXIMA)
        }

        /**
         * Linhas tokenizadas das frases escolhidas na tela.
         * Vazio significa “usar o conjunto empacotado no APK”.
         */
        @JvmStatic fun linhasHotwordDe(context: Context): String =
            context.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
                .getString(CHAVE_HOTWORD_LINHAS, "") ?: ""

        /** Quantas frases o detector aceita agora (para o diagnóstico). */
        @JvmStatic fun quantasHotwordsDe(context: Context): Int =
            linhasHotwordDe(context).split("\n").count { it.trim().isNotEmpty() }

        /** A tela mudou as frases: reinicia o detector para valer já. */
        @JvmStatic fun aplicarHotword(context: Context) {
            if (!running) return
            val intent = Intent(context, KwsForegroundService::class.java).apply {
                action = ACTION_REINICIAR
            }
            try {
                ContextCompat.startForegroundService(context, intent)
            } catch (_: Exception) {
                // Se o Android recusar, o próximo start já usa as frases novas.
            }
        }

        /**
         * Guarda a sensibilidade e reinicia o detector para valer já.
         * Devolve o valor realmente gravado (já limitado a 0–100).
         */
        @JvmStatic fun definirSensibilidade(context: Context, valor: Int): Int {
            val seguro = valor.coerceIn(SENSIBILIDADE_MINIMA, SENSIBILIDADE_MAXIMA)
            context.getSharedPreferences(PREFS_ATIVACAO, Context.MODE_PRIVATE)
                .edit().putInt(CHAVE_SENSIBILIDADE, seguro).apply()
            if (running) {
                val intent = Intent(context, KwsForegroundService::class.java).apply {
                    action = ACTION_REINICIAR
                }
                try {
                    ContextCompat.startForegroundService(context, intent)
                } catch (_: Exception) {
                    // Se o Android recusar, o próximo start já usa o valor novo.
                }
            }
            return seguro
        }

        /**
         * Encerra o detector e **espera** o AudioRecord fechar de verdade.
         *
         * Antes bastava pedir a pausa por Intent: o pedido era assíncrono e o
         * reconhecedor abria o microfone enquanto o detector ainda gravava. Dois
         * AudioRecord ao mesmo tempo devolvem silêncio, e o Android responde
         * "não entendi"/ERROR_AUDIO mesmo com a fala clara. Agora quem vai ouvir o
         * comando espera a confirmação de que o microfone ficou livre.
         *
         * Pode ser chamado de qualquer thread e mais de uma vez: o encerramento é
         * idempotente e a espera é limitada por [esperaMs].
         *
         * @return true quando o microfone ficou livre dentro do prazo.
         */
        @JvmStatic fun liberarMicrofone(esperaMs: Long = LIBERAR_MICROFONE_MS): Boolean {
            listening = false
            val motor = motorAtual ?: return true
            return motor.pararEAguardar(esperaMs)
        }

        /** Pede ao serviço que solte o microfone antes de ouvir o comando. */
        @JvmStatic fun pausarMotor(context: Context) {
            val intent = Intent(context, KwsForegroundService::class.java).apply {
                action = ACTION_PAUSE
            }
            try {
                ContextCompat.startForegroundService(context, intent)
            } catch (_: Exception) {
                // Se o Android recusar, o reconhecedor ainda tenta abrir o microfone.
            }
        }

        /** Volta a ouvir a palavra de ativação depois que o comando terminou. */
        @JvmStatic fun rearm(context: Context) {
            if (!running) return
            val intent = Intent(context, KwsForegroundService::class.java).apply {
                action = ACTION_REARM
            }
            try {
                ContextCompat.startForegroundService(context, intent)
            } catch (_: Exception) {
                // Se o Android recusar o serviço, a próxima abertura do app rearma.
            }
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var engine: JarvisKwsEngine? = null
    private var testStop: Runnable? = null
    private var rearmeForcado: Runnable? = null
    private var voz: JarvisVoz? = null
    private var escuta: JarvisEscutaFundo? = null
    private var comandoEmAndamento = false
    private var tentativasFundo = 0

    /** Toque aguardando “confirmar”; nulo quando não há nada pendente. */
    private var telaPendente: JarvisTelaVoz.Pedido.Tocar? = null
    private var pedidoTelaPendente = ""
    private var falhasMotor = 0
    private var ultimaDeteccao = 0L
    private var vigia: Runnable? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        voz = JarvisVoz(applicationContext)
        // A mesma voz toca o MP3 do Fish Audio quando o motor sem tela responde.
        JarvisPonteIa.usarVoz(voz)
        val notification = buildNotification("Preparando detector acústico local…")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        running = true
        iniciarVigia()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Sensibilidade nova na tela: solta o motor atual e religa com o limiar novo.
        if (intent?.action == ACTION_REINICIAR) {
            cancelarRearme()
            val motor = engine
            engine = null
            Thread {
                motor?.pararEAguardar(LIBERAR_MICROFONE_MS)
                handler.post {
                    if (running && !comandoAtivo && !comandoEmAndamento) iniciarMotor(0)
                }
            }.start()
            return START_STICKY
        }
        if (intent?.action == ACTION_REARM) {
            cancelarRearme()
            if (engine?.isRunning != true) iniciarMotor(0)
            return START_STICKY
        }
        // Comando por voz a caminho: solta o microfone e fica quieto até o rearme.
        if (intent?.action == ACTION_PAUSE) {
            cancelarRearme()
            testStop?.let(handler::removeCallbacks)
            testStop = null
            engine = null
            listening = false
            // Encerra fora da thread principal: a tela não pode ficar travada
            // esperando o AudioRecord fechar.
            Thread { liberarMicrofone(LIBERAR_MICROFONE_MS) }.start()
            updateNotification("Microfone liberado para o seu comando")
            return START_STICKY
        }
        // Celular virado para baixo: para a fala e devolve o microfone ao detector.
        if (intent?.action == ACTION_CALAR) {
            cancelarRearme()
            comandoEmAndamento = false
            tentativasFundo = 0
            escuta?.cancelar()
            escuta = null
            voz?.parar()
            updateNotification("Calado pelo gesto do aparelho")
            scheduleRearme(700L)
            return START_STICKY
        }
        if (intent?.action != ACTION_START) {
            stopSelf(startId)
            return START_NOT_STICKY
        }
        val testSeconds = intent.getIntExtra(EXTRA_TEST_SECONDS, 0).coerceIn(0, 60)
        cancelarRearme()

        // Um pedido "Ativar" recebido durante o teste deve transformar a sessão
        // temporária em escuta contínua, não ser ignorado e deixar o timer desligá-la.
        if (engine?.isRunning == true) {
            testStop?.let(handler::removeCallbacks)
            testStop = null
            if (testSeconds > 0) scheduleTestStop(testSeconds)
            else updateNotification("Ouvindo palavra de ativação localmente")
            return START_STICKY
        }

        iniciarMotor(testSeconds)
        return START_STICKY
    }

    private fun iniciarMotor(testSeconds: Int) {
        // O comando tem prioridade: religar o detector agora roubaria o microfone.
        if (comandoAtivo || comandoEmAndamento) {
            scheduleRearme(1_200)
            return
        }
        testStop?.let(handler::removeCallbacks)
        testStop = null
        error = ""
        listening = false
        engine?.stop()
        val sensibilidade = sensibilidadeDe(applicationContext)
        engine = JarvisKwsEngine(
            applicationContext,
            object : JarvisKwsEngine.Listener {
                override fun onDetected(keyword: String) {
                    handler.post {
                        listening = false
                        ultimaDeteccao = SystemClock.uptimeMillis()
                        // Solta o AudioRecord fora da thread principal e só abre o
                        // ouvinte depois de confirmar que o microfone está livre.
                        val motor = engine
                        engine = null
                        Thread {
                            val livre = motor?.pararEAguardar(LIBERAR_MICROFONE_MS) ?: true
                            val espera =
                                if (livre) ESPERA_MICROFONE_MS else ESPERA_MICROFONE_LONGO_MS
                            handler.postDelayed({
                                MainActivity.emitWake(keyword)
                                // Segundo plano de verdade: o comando é ouvido e
                                // executado aqui, sem abrir a tela. Com a tela aberta a
                                // rota é sempre a conversa, mesmo sem a autorização de
                                // "Exibir sobre outros apps" — era isso que fazia o
                                // JARVIS responder "estou em segundo plano" ao ser
                                // chamado pelo app.
                                if (!MainActivity.estaVisivel() &&
                                    (JarvisFundo.modoSemTela(applicationContext) ||
                                        !JarvisFundo.podeAbrirApps(applicationContext))
                                ) {
                                    iniciarComandoEmSegundoPlano(keyword)
                                    return@postDelayed
                                }
                                updateNotification("Palavra detectada · ouvindo sua fala")
                                // Reabre o app em primeiro plano para o reconhecimento
                                // do comando. O serviço segue vivo e volta a ouvir.
                                val launch = packageManager.getLaunchIntentForPackage(packageName)
                                launch?.addFlags(
                                    Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                                )
                                launch?.putExtra("jarvis_wake_keyword", keyword)
                                if (launch != null) startActivity(launch)
                                // Se o reconhecedor não devolver resultado, o detector
                                // não fica desligado para sempre.
                                scheduleRearme(REARM_DELAY_MS)
                            }, espera)
                        }.start()
                    }
                }

                override fun onError(message: String) {
                    handler.post {
                        listening = false
                        error = message
                        engine = null
                        falhasMotor++
                        // Uma falha passageira do motor não pode deixar o JARVIS
                        // surdo até o app ser aberto de novo: tenta religar sozinho.
                        if (falhasMotor <= MAX_TENTATIVAS_FALHA &&
                            !comandoAtivo && !comandoEmAndamento
                        ) {
                            updateNotification(
                                "Detector caiu: $message · religando " +
                                    "($falhasMotor/$MAX_TENTATIVAS_FALHA)"
                            )
                            scheduleRearme(atrasoFalha(falhasMotor))
                            return@post
                        }
                        updateNotification("Detector parado: falha")
                        stopSelf()
                    }
                }

                override fun onState(state: String) {
                    handler.post {
                        listening = state.startsWith("KWS local ativo")
                        // Motor de pé: a contagem de falhas recomeça.
                        if (listening) falhasMotor = 0
                        updateNotification(if (listening) "Ouvindo palavra de ativação localmente" else state)
                    }
                }
            },
            sensibilidade,
            "",
            linhasHotwordDe(applicationContext)
        )
        motorAtual = engine
        engine?.start()
        if (testSeconds > 0) scheduleTestStop(testSeconds)
    }

    /**
     * Palavra ouvida com o app fechado: mostra que está ativo, escuta a fala,
     * executa o que é permitido e responde falando. Pergunta livre vai para o
     * provedor de IA já configurado; o áudio continua no aparelho até aqui.
     */
    private fun iniciarComandoEmSegundoPlano(palavra: String) {
        if (comandoEmAndamento) {
            scheduleRearme(1_500)
            return
        }
        comandoEmAndamento = true
        tentativasFundo = 0
        // Com a voz externa ligada, o motor sobe enquanto você fala: a resposta
        // já sai pelo Fish Audio, sem depender de o app estar aberto.
        JarvisPonteIa.preparar(applicationContext)
        ouvirComandoFundo()
    }

    /**
     * Abre o reconhecedor offline para o comando com o app fechado. Na primeira
     * falha que vale repetir (silêncio, “não entendi”, microfone ocupado) tenta mais
     * uma vez antes de desistir — o usuário não precisa chamar de novo.
     */
    private fun ouvirComandoFundo() {
        updateNotification("JARVIS ativo · ouvindo sua pergunta ou comando")
        avisarAtivo("JARVIS ativo", "Pergunte ou dê um comando…")
        escuta?.cancelar()
        val escutaComando = JarvisEscutaFundo(applicationContext)
        escuta = escutaComando
        if (!escutaComando.disponivel()) {
            finalizarComando(
                "Este aparelho não oferece reconhecimento de fala offline em português. "
                    + "Abra o app para falar comigo por escrito."
            )
            return
        }
        val iniciou = escutaComando.ouvir(object : JarvisEscutaFundo.Listener {
            override fun onStatus(mensagem: String) {
                updateNotification(mensagem)
                avisarAtivo("JARVIS ativo", mensagem)
            }

            override fun onTexto(texto: String) {
                // Resposta de um toque pendente vem antes de qualquer outro comando.
                val aguardando = telaPendente
                if (aguardando != null) {
                    telaPendente = null
                    val pedidoOriginal = pedidoTelaPendente.ifEmpty { texto }
                    pedidoTelaPendente = ""
                    when (JarvisTelaVoz.confirmar(texto)) {
                        true -> {
                            escuta?.cancelar()
                            escuta = null
                            executarTela(aguardando, pedidoOriginal)
                        }
                        false -> finalizarComando("Cancelado. Nada foi tocado na tela.")
                        null -> finalizarComando(
                            "Não entendi a confirmação. Nada foi tocado na tela."
                        )
                    }
                    return
                }
                // Comando de tela tem prioridade sobre a pergunta livre.
                val pedidoTela = JarvisTelaVoz.interpretar(texto)
                if (pedidoTela != null) {
                    escuta?.cancelar()
                    escuta = null
                    atenderPedidoDeTela(pedidoTela, texto)
                    return
                }
                // Palco: “mostra fotos de…”, “me mostra um vídeo sobre…” e
                // “traz as últimas notícias de…” abrem o app já pesquisando.
                val palco = JarvisPalco.interpretar(texto)
                if (palco != null) {
                    escuta?.cancelar()
                    escuta = null
                    abrirPalco(palco, texto)
                    return
                }
                // Tela do próprio JARVIS: “abre o modo visão”, “exibe o modo
                // palco”, “abre a memória”. Vem antes de abrir app para o
                // Android não procurar um aplicativo chamado “visão”.
                val telaJarvis = JarvisAbrirTela.interpretar(texto)
                if (telaJarvis != null) {
                    escuta?.cancelar()
                    escuta = null
                    abrirTelaJarvis(telaJarvis, texto)
                    return
                }
                val comando = JarvisFundo.interpretar(texto)
                // Pergunta livre (“que horas são”, “quem descobriu o Brasil”):
                // hora e data são respondidas no aparelho; o resto vai para o
                // provedor de IA já configurado, pela ponte com o Flutter.
                if (comando.tipo == JarvisFundo.Tipo.DESCONHECIDO) {
                    // Mensagem e ligação também valem com o app fechado: têm
                    // caminho próprio antes de gastar provedor de IA.
                    val mensagem = JarvisMensagens.interpretar(texto)
                    if (mensagem != null) {
                        escuta?.cancelar()
                        escuta = null
                        executarMensagem(mensagem, texto)
                        return
                    }
                    escuta?.cancelar()
                    escuta = null
                    responderPerguntaLivre(texto)
                    return
                }
                val resultado = JarvisFundo.executar(applicationContext, comando)
                // O histórico guarda o que foi ouvido, a ação e o resultado real.
                JarvisFundo.registrar(
                    applicationContext,
                    comando,
                    resultado,
                    origem = JarvisFundo.ORIGEM_SEGUNDO_PLANO,
                    pedido = texto,
                )
                finalizarComando(resultado.mensagem)
            }

            override fun onErro(mensagem: String) {
                finalizarComando(mensagem)
            }

            override fun onErroRepetivel(codigo: Int, mensagem: String) {
                if (tentativasFundo < 1 && comandoEmAndamento) {
                    tentativasFundo++
                    // Sem falar junto: a resposta do alto-falante seria ouvida pelo
                    // próprio microfone e viraria comando.
                    updateNotification("Não entendi. Fale de novo, por favor…")
                    avisarAtivo("JARVIS ativo", "Não entendi. Fale de novo, por favor…")
                    handler.postDelayed({
                        if (comandoEmAndamento) ouvirComandoFundo()
                    }, 900L)
                } else {
                    finalizarComando(mensagem)
                }
            }
        })
        if (!iniciou && comandoEmAndamento) {
            finalizarComando("Não consegui abrir o microfone para ouvir o comando.")
        }
    }

    /**
     * Comando de tela ouvido com o app fechado. Leitura e rolagem executam na
     * hora; toque só depois de uma confirmação falada.
     */
    private fun atenderPedidoDeTela(pedido: JarvisTelaVoz.Pedido, texto: String) {
        if (!JarvisTelaVoz.consentido(applicationContext)) {
            val recusa = "A automação de tela está desligada neste app. Abra o JARVIS, " +
                "ligue “Ler a tela e tocar por mim” e autorize o serviço em Configurações " +
                "de Acessibilidade."
            JarvisFundo.registrarHistorico(
                applicationContext,
                origem = JarvisFundo.ORIGEM_SEGUNDO_PLANO,
                pedido = texto,
                acao = "comando de tela sem consentimento",
                ok = false,
                mensagem = recusa,
            )
            finalizarComando(recusa)
            return
        }
        if (pedido is JarvisTelaVoz.Pedido.Tocar) {
            perguntarConfirmacaoTela(pedido, texto)
            return
        }
        executarTela(pedido, texto)
    }

    /**
     * Pergunta antes do toque e escuta a resposta. Sem “confirmar” dentro do
     * prazo, o toque é descartado — o microfone não fica esperando para sempre.
     */
    private fun perguntarConfirmacaoTela(
        pedido: JarvisTelaVoz.Pedido.Tocar,
        texto: String,
    ) {
        telaPendente = pedido
        pedidoTelaPendente = texto
        val pergunta = JarvisTelaVoz.confirmacaoPara(pedido)
        updateNotification("Confirmação: tocar em ${pedido.texto}?")
        avisarAtivo("JARVIS ativo", "Confirme o toque: diga confirmar ou cancelar.")
        // O microfone só abre quando a pergunta termina; ouvir junto faria o
        // próprio JARVIS se ativar com a própria voz.
        val falou = voz?.falar(pergunta) { ouvirConfirmacaoTela() } ?: false
        if (!falou) {
            handler.postDelayed(
                { if (telaPendente != null) ouvirConfirmacaoTela() },
                atrasoResposta(pergunta),
            )
        }
        handler.postDelayed({
            if (telaPendente === pedido) {
                telaPendente = null
                pedidoTelaPendente = ""
                finalizarComando("Ninguém confirmou o toque. Nada foi tocado na tela.")
            }
        }, PRAZO_CONFIRMACAO_MS)
    }

    private fun ouvirConfirmacaoTela() {
        if (telaPendente == null || !comandoEmAndamento) return
        ouvirComandoFundo()
    }

    /** Executa fora da thread principal: percorrer a árvore da tela custa tempo. */
    private fun executarTela(pedido: JarvisTelaVoz.Pedido, texto: String) {
        updateNotification("Executando na tela…")
        avisarAtivo("JARVIS ativo", "Agindo na tela…")
        Thread {
            val resposta = JarvisTelaVoz.executar(pedido)
            JarvisFundo.registrarHistorico(
                applicationContext,
                origem = JarvisFundo.ORIGEM_SEGUNDO_PLANO,
                pedido = texto,
                acao = resposta.acao,
                ok = resposta.ok,
                mensagem = resposta.mensagem,
            )
            handler.post { finalizarComando(resposta.mensagem) }
        }.start()
    }

    /**
     * Abre o app no modo palco, com o pedido já reconhecido.
     *
     * Abrir atividade a partir do segundo plano depende de “Exibir sobre outros
     * apps”; sem isso o Android bloqueia e o JARVIS diz o que falta, em vez de
     * afirmar que abriu. O histórico registra o pedido e o resultado real.
     */
    private fun abrirPalco(pedido: JarvisPalco.Pedido, texto: String) {
        if (!JarvisFundo.podeAbrirApps(applicationContext)) {
            val aviso = "Para abrir o palco com o app fechado, autorize “Exibir sobre " +
                "outros apps” no Android. O pedido foi entendido; só falta essa autorização."
            JarvisFundo.registrarHistorico(
                applicationContext,
                origem = JarvisFundo.ORIGEM_SEGUNDO_PLANO,
                pedido = texto,
                acao = "abrir o palco",
                ok = false,
                mensagem = aviso,
            )
            finalizarComando(aviso)
            return
        }
        updateNotification("Abrindo o palco: ${pedido.consulta}")
        avisarAtivo("JARVIS ativo", "Abrindo o palco com ${pedido.tipo.rotulo}…")
        val abertura = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(JarvisPalco.EXTRA_TIPO, pedido.tipo.chave)
            putExtra(JarvisPalco.EXTRA_CONSULTA, pedido.consulta)
        }
        val abriu = try {
            if (abertura == null) false else {
                startActivity(abertura)
                true
            }
        } catch (_: Exception) {
            false
        }
        val frase = if (abriu) {
            JarvisPalco.fraseDeAbertura(pedido)
        } else {
            "Não consegui abrir o app para mostrar o palco. Abra o JARVIS e peça de novo."
        }
        JarvisFundo.registrarHistorico(
            applicationContext,
            origem = JarvisFundo.ORIGEM_SEGUNDO_PLANO,
            pedido = texto,
            acao = "abrir o palco",
            ok = abriu,
            mensagem = frase,
        )
        finalizarComando(frase)
    }

    /**
     * Abre o app já na tela do JARVIS pedida (“abre o modo visão”, “abre a
     * memória”). Mesma exigência do palco: abrir atividade a partir do segundo
     * plano depende de “Exibir sobre outros apps”.
     */
    private fun abrirTelaJarvis(pedido: JarvisAbrirTela.Pedido, texto: String) {
        val acao = "abrir ${pedido.rotulo}"
        if (!JarvisFundo.podeAbrirApps(applicationContext)) {
            val aviso = "Para abrir ${pedido.rotulo} com o app fechado, autorize “Exibir sobre " +
                "outros apps” no Android. O pedido foi entendido; só falta essa autorização."
            JarvisFundo.registrarHistorico(
                applicationContext,
                origem = JarvisFundo.ORIGEM_SEGUNDO_PLANO,
                pedido = texto,
                acao = acao,
                ok = false,
                mensagem = aviso,
            )
            finalizarComando(aviso)
            return
        }
        updateNotification("Abrindo ${pedido.rotulo}…")
        avisarAtivo("JARVIS ativo", "Abrindo ${pedido.rotulo}…")
        val abertura = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(JarvisAbrirTela.EXTRA_TELA, pedido.chave)
        }
        val abriu = try {
            if (abertura == null) false else {
                startActivity(abertura)
                true
            }
        } catch (_: Exception) {
            false
        }
        val frase = if (abriu) {
            JarvisAbrirTela.fraseDeAbertura(pedido)
        } else {
            "Não consegui abrir o app para mostrar ${pedido.rotulo}. Abra o JARVIS e peça de novo."
        }
        JarvisFundo.registrarHistorico(
            applicationContext,
            origem = JarvisFundo.ORIGEM_SEGUNDO_PLANO,
            pedido = texto,
            acao = acao,
            ok = abriu,
            mensagem = frase,
        )
        finalizarComando(frase)
    }

    /**
     * Mensagem e ligação com o app fechado. Roda fora da thread principal
     * porque a busca de contato consulta o Android; o resultado real é dito em
     * voz alta em vez de o JARVIS afirmar que enviou sem ter enviado.
     */
    private fun executarMensagem(pedido: JarvisMensagens.Pedido, texto: String) {
        val acao = when (pedido.tipo) {
            JarvisMensagens.Tipo.MENSAGEM -> "mensagem para ${pedido.destino} via ${pedido.app}"
            JarvisMensagens.Tipo.LIGACAO -> "ligar para ${pedido.destino}"
        }
        if (!JarvisFundo.podeAbrirApps(applicationContext)) {
            val aviso = "Para mandar mensagem ou ligar com o app fechado, autorize “Exibir sobre " +
                "outros apps” no Android. O pedido foi entendido; só falta essa autorização."
            JarvisFundo.registrarHistorico(
                applicationContext,
                origem = JarvisFundo.ORIGEM_SEGUNDO_PLANO,
                pedido = texto,
                acao = acao,
                ok = false,
                mensagem = aviso,
            )
            finalizarComando(aviso)
            return
        }
        updateNotification("Executando: $acao…")
        avisarAtivo("JARVIS ativo", "Preparando: $acao…")
        Thread {
            val resultado = JarvisMensagens.executar(applicationContext, pedido)
            JarvisFundo.registrarHistorico(
                applicationContext,
                origem = JarvisFundo.ORIGEM_SEGUNDO_PLANO,
                pedido = texto,
                acao = acao,
                ok = resultado.ok,
                mensagem = resultado.mensagem,
            )
            handler.post { finalizarComando(resultado.mensagem) }
        }.start()
    }

    /**
     * Responde uma pergunta livre pela ponte de IA. Com o app aberto quem
     * responde é o motor da tela; com o app encerrado a ponte sobe o motor sem
     * tela (`mainFundo`), que usa o mesmo provedor e a mesma personalidade.
     * Só quando nem isso funciona a resposta é honesta — e o motivo muda a
     * frase: falta de provedor não é a mesma coisa que falha de tempo.
     */
    private fun responderPerguntaLivre(texto: String) {
        updateNotification("Consultando o provedor de IA…")
        avisarAtivo("JARVIS ativo", "Pensando na resposta…")
        JarvisPonteIa.perguntar(applicationContext, texto) { resposta, motivo ->
            if (!comandoEmAndamento) return@perguntar
            val aviso = resposta?.takeIf { it.isNotBlank() }
            val falado = aviso ?: when (motivo) {
                "sem_provedor" -> "Nenhum provedor de IA está configurado. Abra o JARVIS, cadastre a chave do provedor e pergunte de novo."
                "tempo" -> "O provedor de IA demorou demais para responder. Tente de novo em instantes."
                else -> "Não consegui consultar a IA agora. Verifique a conexão e tente de novo em instantes."
                }
            JarvisFundo.registrarHistorico(
                applicationContext,
                origem = JarvisFundo.ORIGEM_SEGUNDO_PLANO,
                pedido = texto,
                acao = "pergunta livre",
                ok = aviso != null,
                mensagem = falado,
            )
            finalizarComando(falado)
        }
    }

    private fun finalizarComando(mensagem: String) {
        comandoEmAndamento = false
        tentativasFundo = 0
        // Confirmação não sobrevive ao fim do comando: nada fica armado.
        telaPendente = null
        pedidoTelaPendente = ""
        escuta?.cancelar()
        escuta = null
        updateNotification("JARVIS: $mensagem")
        avisarAtivo("JARVIS", mensagem)
        // Com a voz externa ligada, o Fish Audio fala primeiro — inclusive com o
        // app fechado. Se ele não puder falar, a voz do aparelho assume.
        if (JarvisPonteIa.vozExternaLigada(applicationContext)) {
            JarvisPonteIa.falarFundo(mensagem) { falou ->
                if (falou) {
                    // O MediaPlayer não avisa o fim: espera proporcional ao texto.
                    handler.postDelayed(
                        { if (!comandoEmAndamento) scheduleRearme(700L) },
                        atrasoResposta(mensagem)
                    )
                } else {
                    falarLocal(mensagem)
                }
            }
        } else {
            falarLocal(mensagem)
        }
    }

    /**
     * Voz do aparelho com o microfone devolvido no fim da fala.
     *
     * O microfone volta só quando a resposta termina: ouvir enquanto o próprio
     * JARVIS fala fazia ele se ativar com a própria voz.
     */
    private fun falarLocal(mensagem: String) {
        val falou = voz?.falar(mensagem) {
            if (!comandoEmAndamento) scheduleRearme(700L)
        } ?: false
        if (!falou) scheduleRearme(atrasoResposta(mensagem))
    }

    /** Sem confirmação da síntese, espera proporcional ao tamanho da resposta. */
    private fun atrasoResposta(mensagem: String): Long =
        (900L + mensagem.length * 90L).coerceIn(1_200L, 8_000L)

    /** Aviso de alta prioridade: aparece sobre outros apps quando o JARVIS é chamado. */
    private fun avisarAtivo(titulo: String, texto: String) {
        val abertura = packageManager.getLaunchIntentForPackage(packageName)
        val destino = abertura?.let {
            it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            PendingIntent.getActivity(
                this,
                NOTIFICATION_ID_ATIVO,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
        val construtor = NotificationCompat.Builder(this, CHANNEL_ATIVO)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle(titulo)
            .setContentText(texto)
            .setStyle(NotificationCompat.BigTextStyle().bigText(texto))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(Notification.CATEGORY_STATUS)
            .setAutoCancel(true)
            .setTimeoutAfter(9_000)
            .apply { if (destino != null) setContentIntent(destino) }
        // Sem "Exibir sobre outros apps" o Android bloqueia abrir apps a partir do
        // segundo plano. O botão leva direto ao ajuste, em um toque.
        if (!JarvisFundo.podeAbrirApps(this)) {
            val ajuste = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            val pendente = PendingIntent.getActivity(
                this,
                NOTIFICATION_ID_AUTORIZAR,
                ajuste,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            construtor.addAction(0, "Autorizar abrir apps", pendente)
        }
        getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID_ATIVO, construtor.build())
    }

    private fun atrasoFalha(tentativa: Int): Long =
        (2_000L * tentativa).coerceAtMost(15_000L)

    /**
     * Vigia: se o motor morrer sem comando em curso, o detector volta sozinho.
     * Sem isso, uma falha silenciosa do JNI deixava o JARVIS surdo até reabrir o app.
     */
    private fun iniciarVigia() {
        pararVigia()
        val tarefa = object : Runnable {
            override fun run() {
                if (!running) return
                val ocupado = comandoAtivo || comandoEmAndamento
                val ativacaoRecente =
                    SystemClock.uptimeMillis() - ultimaDeteccao < JANELA_POS_DETECCAO_MS
                if (!ocupado && !ativacaoRecente && rearmeForcado == null &&
                    engine?.isRunning != true
                ) {
                    falhasMotor = 0
                    iniciarMotor(0)
                }
                handler.postDelayed(this, VIGIA_MS)
            }
        }
        vigia = tarefa
        handler.postDelayed(tarefa, VIGIA_MS)
    }

    private fun pararVigia() {
        vigia?.let(handler::removeCallbacks)
        vigia = null
    }

    private fun scheduleRearme(delayMs: Long) {
        cancelarRearme()
        val rearme = Runnable {
            rearmeForcado = null
            if (engine?.isRunning != true) iniciarMotor(0)
        }
        rearmeForcado = rearme
        handler.postDelayed(rearme, delayMs)
    }

    private fun cancelarRearme() {
        rearmeForcado?.let(handler::removeCallbacks)
        rearmeForcado = null
    }

    private fun scheduleTestStop(seconds: Int) {
        testStop?.let(handler::removeCallbacks)
        val stopTest = Runnable {
            testStop = null
            engine?.stop()
            listening = false
            updateNotification("Teste de ativação concluído")
            stopSelf()
        }
        testStop = stopTest
        handler.postDelayed(stopTest, seconds * 1000L)
    }

    override fun onDestroy() {
        testStop?.let(handler::removeCallbacks)
        testStop = null
        pararVigia()
        cancelarRearme()
        escuta?.cancelar()
        escuta = null
        comandoEmAndamento = false
        tentativasFundo = 0
        comandoAtivo = false
        voz?.shutdown()
        voz = null
        JarvisPonteIa.usarVoz(null)
        engine = null
        // O motor sem tela da ponte de IA não deve sobreviver ao serviço.
        JarvisPonteIa.encerrar()
        // Solta o AudioRecord sem travar a thread principal.
        Thread { liberarMicrofone(LIBERAR_MICROFONE_MS) }.start()
        listening = false
        running = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val gerenciador = getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Palavra de ativação do J.A.R.V.I.S.",
                NotificationManager.IMPORTANCE_LOW
            ).apply { description = "Estado do detector acústico local sherpa-onnx." }
            gerenciador.createNotificationChannel(channel)
            // Canal separado, de alta prioridade, para o aviso "JARVIS ativo"
            // aparecer na tela por cima do app em uso.
            val ativo = NotificationChannel(
                CHANNEL_ATIVO,
                "JARVIS ativo em segundo plano",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Mostra na tela quando o JARVIS acorda e o que ele executou."
            }
            gerenciador.createNotificationChannel(ativo)
        }
    }

    private fun buildNotification(message: String): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle("J.A.R.V.I.S. Nova")
            .setContentText(message)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()

    private fun updateNotification(message: String) {
        getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, buildNotification(message))
    }
}
