package com.jarvis.nova

import android.content.Context
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.speech.tts.Voice
import java.util.Locale
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Voz de resposta do JARVIS usando o mecanismo de síntese já instalado no
 * aparelho. O texto nunca sai do dispositivo; só o áudio sintetizado é tocado.
 *
 * O timbre é ajustado para grave e pausado, uma aproximação do JARVIS dublado
 * em português do Brasil. A voz exata depende do mecanismo instalado no Android.
 */
class JarvisVoz(context: Context) : TextToSpeech.OnInitListener {
    private val appContext = context.applicationContext
    private var tts: TextToSpeech? = null
    private var pronto = false
    private var pendente: String? = null
    private var erro = ""
    private var vozEscolhida = ""
    private val principal = Handler(Looper.getMainLooper())
    /** MP3 da voz externa em reprodução; nulo quando a voz local é a que fala. */
    private var mp3: MediaPlayer? = null

    /** Quem espera o fim do MP3 atual (a fala em fluxo espera para não cortar). */
    private var audioPendente: (() -> Unit)? = null

    /** Rede de segurança: MP3 travado não segura a fala para sempre. */
    private var limiteAudio: Runnable? = null
    /** Quem avisar quando a fala terminar (o microfone volta depois disso). */
    private val aoTerminar = ConcurrentHashMap<String, () -> Unit>()

    init {
        tts = TextToSpeech(appContext, this)
    }

    override fun onInit(status: Int) {
        if (status != TextToSpeech.SUCCESS) {
            erro = "A síntese de voz do Android não iniciou."
            pendente = null
            return
        }
        val motor = tts ?: return
        val ptBr = Locale("pt", "BR")
        val disponivel = motor.isLanguageAvailable(ptBr)
        if (disponivel >= TextToSpeech.LANG_AVAILABLE) {
            motor.language = ptBr
        } else {
            motor.language = Locale.getDefault()
        }
        // O timbre escolhido na tela (grave, natural ou ágil) vale já na abertura.
        aplicarTimbre(motor)
        escolherVoz(motor)?.let { voz ->
            motor.voice = voz
            vozEscolhida = voz.name
        }
        // O microfone só volta a ouvir a palavra de ativação depois que a resposta
        // termina; sem isso o próprio JARVIS se escutava e se ativava de novo.
        motor.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) = Unit

            override fun onDone(utteranceId: String?) {
                concluir(utteranceId)
            }

            @Deprecated("Assinatura antiga exigida pelo Android")
            override fun onError(utteranceId: String?) {
                concluir(utteranceId)
            }
        })
        pronto = true
        pendente?.let {
            pendente = null
            falar(it)
        }
    }

    /** Prefere uma voz masculina local em pt-BR; se não houver, usa a melhor disponível. */
    private fun escolherVoz(motor: TextToSpeech): Voice? {
        val vozes = try {
            motor.voices
        } catch (_: Exception) {
            null
        } ?: return null
        val brasileiras = vozes.filter {
            it.locale.language.equals("pt", ignoreCase = true) &&
                (it.locale.country.equals("BR", ignoreCase = true) || it.locale.country.isEmpty())
        }
        if (brasileiras.isEmpty()) return null
        return brasileiras.firstOrNull {
            it.name.contains("male", ignoreCase = true) &&
                !it.name.contains("female", ignoreCase = true)
        } ?: brasileiras.firstOrNull {
            !it.name.contains("female", ignoreCase = true) && !it.isNetworkConnectionRequired
        } ?: brasileiras.firstOrNull {
            !it.name.contains("female", ignoreCase = true)
        } ?: brasileiras.first()
    }

    private fun concluir(utteranceId: String?) {
        val retorno = aoTerminar.remove(utteranceId) ?: return
        principal.post { retorno() }
    }

    /**
     * Fala uma frase do fluxo sem cortar a anterior: entra no fim da fila do
     * sintetizador. É o caminho da voz do aparelho quando a resposta é falada
     * por partes.
     */
    fun falarEmFila(texto: String): Boolean {
        val limpo = texto.trim()
        if (limpo.isEmpty()) return false
        if (!pronto) {
            pendente = limpo
            return erro.isEmpty()
        }
        val motor = tts ?: return false
        val volume = if (JarvisSensores.modoNoturno(appContext)) {
            JarvisSensores.VOLUME_NOTURNO
        } else {
            1f
        }
        val parametros = android.os.Bundle().apply {
            putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, volume)
        }
        return motor.speak(
            limpo,
            TextToSpeech.QUEUE_ADD,
            parametros,
            "jarvis-" + UUID.randomUUID().toString()
        ) == TextToSpeech.SUCCESS
    }

    /**
     * Fala o texto e, opcionalmente, avisa quando o áudio termina de sair.
     * `aoTerminar` roda na thread principal e também é chamado quando a síntese
     * falha, para o serviço nunca ficar parado esperando.
     */
    fun falar(texto: String, aoTerminar: (() -> Unit)? = null): Boolean {
        val limpo = texto.trim()
        if (limpo.isEmpty()) {
            aoTerminar?.invoke()
            return false
        }
        if (!pronto) {
            pendente = limpo
            if (erro.isNotEmpty()) aoTerminar?.invoke()
            return erro.isEmpty()
        }
        val motor = tts ?: run {
            aoTerminar?.invoke()
            return false
        }
        motor.stop()
        val id = "jarvis-" + UUID.randomUUID().toString()
        if (aoTerminar != null) this.aoTerminar[id] = aoTerminar
        // Modo noturno: a mesma resposta sai mais baixa, sem silenciar de vez.
        val volume = if (JarvisSensores.modoNoturno(appContext)) {
            JarvisSensores.VOLUME_NOTURNO
        } else {
            1f
        }
        val parametros = android.os.Bundle().apply {
            putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, volume)
        }
        val falou =
            motor.speak(limpo, TextToSpeech.QUEUE_FLUSH, parametros, id) == TextToSpeech.SUCCESS
        if (!falou) {
            this.aoTerminar.remove(id)?.invoke()
        }
        return falou
    }

    /**
     * Aplica o perfil de timbre gravado no aparelho ao motor de síntese.
     *
     * Devolve `false` quando a síntese ainda não ficou pronta; a próxima fala
     * usa o perfil porque ele é lido de novo na abertura.
     */
    fun aplicarTimbre(): Boolean {
        val motor = tts ?: return false
        return aplicarTimbre(motor)
    }

    private fun aplicarTimbre(motor: TextToSpeech): Boolean {
        val perfil = JarvisTimbre.perfil(JarvisTimbre.id(appContext))
        return try {
            motor.setPitch(perfil.pitch)
            motor.setSpeechRate(perfil.velocidade)
            true
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Toca um MP3 já baixado pelo serviço de voz externa.
     *
     * A voz externa gera um arquivo temporário; aqui ele é apenas reproduzido,
     * no mesmo volume da voz local (o modo noturno vale para os dois). Falha
     * fechada: devolve `false` e não deixa o aparelho mudo — quem chamou decide
     * voltar para a voz do aparelho.
     */
    fun falarAudio(caminho: String, aoTerminar: (() -> Unit)? = null): Boolean {
        val arquivo = java.io.File(caminho)
        if (!arquivo.isFile || arquivo.length() <= 0L) return false
        return try {
            // Um MP3 por vez: parar o anterior também avisa quem o esperava.
            pararAudio()
            val player = MediaPlayer()
            player.setDataSource(arquivo.absolutePath)
            val volume = if (JarvisSensores.modoNoturno(appContext)) {
                JarvisSensores.VOLUME_NOTURNO
            } else {
                1f
            }
            player.setVolume(volume, volume)
            audioPendente = aoTerminar
            player.setOnCompletionListener { encerrarAudio() }
            player.setOnErrorListener { _, _, _ ->
                encerrarAudio()
                true
            }
            player.prepare()
            player.start()
            mp3 = player
            val duracao = try {
                player.duration.toLong()
            } catch (_: Exception) {
                0L
            }
            cancelarLimiteAudio()
            val limite = Runnable { pararAudio() }
            limiteAudio = limite
            principal.postDelayed(limite, (if (duracao > 0L) duracao else 60_000L) + 5_000L)
            true
        } catch (_: Exception) {
            encerrarAudio()
            false
        }
    }

    private fun encerrarAudio() {
        cancelarLimiteAudio()
        try {
            mp3?.release()
        } catch (_: Exception) {
        }
        mp3 = null
        // Quem esperava o fim recebe agora: a fala em fluxo não fica travada.
        val pendente = audioPendente
        audioPendente = null
        pendente?.invoke()
    }

    private fun cancelarLimiteAudio() {
        limiteAudio?.let(principal::removeCallbacks)
        limiteAudio = null
    }

    fun pararAudio() {
        try {
            mp3?.stop()
        } catch (_: Exception) {
        }
        encerrarAudio()
    }

    fun parar() {
        pendente = null
        aoTerminar.clear()
        pararAudio()
        try {
            tts?.stop()
        } catch (_: Exception) {
        }
    }

    fun status(): Map<String, Any> = mapOf(
        "available" to (tts != null),
        "ready" to pronto,
        "engine" to (tts?.defaultEngine ?: ""),
        "voice" to vozEscolhida,
        "error" to erro,
        "timbre" to JarvisTimbre.id(appContext),
    )

    fun shutdown() {
        pendente = null
        aoTerminar.clear()
        pararAudio()
        try {
            tts?.stop()
            tts?.shutdown()
        } catch (_: Exception) {
        }
        tts = null
        pronto = false
    }
}
