package com.jarvis.nova

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.os.Build

/**
 * Escuta o comando curto depois da palavra de ativação, sem abrir a tela.
 *
 * Usa exclusivamente o reconhecedor **offline** do Android (`createOnDeviceSpeechRecognizer`),
 * o mesmo caminho da tela. O áudio não sai do aparelho e não existe fallback de nuvem: se o
 * pacote offline de português não estiver instalado, a resposta é o erro, não uma alternativa
 * silenciosa.
 */
class JarvisEscutaFundo(private val context: Context) {

    interface Listener {
        fun onStatus(mensagem: String)
        fun onTexto(texto: String)
        fun onErro(mensagem: String)

        /**
         * Erro que vale uma nova escuta (silêncio, “não entendi”, microfone
         * ocupado). Por padrão vira [onErro]; o serviço sobrescreve para repetir
         * uma vez antes de desistir.
         */
        fun onErroRepetivel(codigo: Int, mensagem: String) {
            onErro(mensagem)
        }
    }

    companion object {
        /** Limite para o comando inteiro; depois disso o microfone é liberado. */
        const val LIMITE_MS = 12_000L

        /** Erros em que insistir resolve: silêncio, “não entendi” e microfone ocupado. */
        fun valeRepetir(codigo: Int): Boolean = when (codigo) {
            SpeechRecognizer.ERROR_NO_MATCH,
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT,
            SpeechRecognizer.ERROR_SERVER_DISCONNECTED,
            SpeechRecognizer.ERROR_AUDIO,
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY,
            SpeechRecognizer.ERROR_CLIENT -> true
            else -> false
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var recognizer: SpeechRecognizer? = null
    private var limite: Runnable? = null
    private var ativo = false
    private var entregou = false
    // O reconhecedor offline costuma entregar boa parte da frase antes de falhar;
    // usar o parcial evita perder o comando por causa do fim do áudio.
    private var melhorParcial = ""

    val ouvindo: Boolean get() = ativo

    /** Reconhecimento offline disponível neste aparelho (Android 12+). */
    fun disponivel(): Boolean = try {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
    } catch (_: Exception) {
        false
    }

    /**
     * Devolve `false` quando o reconhecedor não pôde ser criado. Nesse caso nenhum
     * callback é chamado e o serviço segue livre para rearmar.
     */
    fun ouvir(listener: Listener): Boolean {
        cancelar()
        ativo = true
        entregou = false
        melhorParcial = ""
        val reconhecedor = try {
            SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
        } catch (_: Exception) {
            ativo = false
            return false
        }
        recognizer = reconhecedor
        reconhecedor.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                listener.onStatus("Ouvindo seu comando em português…")
            }

            override fun onBeginningOfSpeech() = Unit
            override fun onRmsChanged(rmsdB: Float) = Unit
            override fun onBufferReceived(buffer: ByteArray?) = Unit

            override fun onEndOfSpeech() {
                listener.onStatus("Processando o comando no aparelho…")
            }

            override fun onError(error: Int) {
                if (entregou) return
                entregou = true
                val parcial = melhorParcial.trim()
                encerrar()
                if (parcial.length >= 3) {
                    listener.onTexto(parcial)
                    return
                }
                if (valeRepetir(error)) {
                    listener.onErroRepetivel(error, mensagemErro(error))
                } else {
                    listener.onErro(mensagemErro(error))
                }
            }

            override fun onResults(results: Bundle?) {
                if (entregou) return
                entregou = true
                val texto = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull()?.trim().orEmpty()
                encerrar()
                if (texto.isEmpty()) {
                    listener.onErro("O reconhecimento não identificou palavras. Tente novamente.")
                } else {
                    listener.onTexto(texto)
                }
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val parcial = partialResults
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull()
                if (!parcial.isNullOrBlank()) {
                    if (parcial.length > melhorParcial.length) melhorParcial = parcial
                    listener.onStatus("Reconhecendo: $parcial")
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) = Unit
        })
        return try {
            val pedido = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, "pt-BR")
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "pt-BR")
                putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
                putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
                // Comando curto precisa de folga: cortar cedo devolvia "não entendi"
                // mesmo com a fala clara.
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 2000L)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 1500L)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 1000L)
            }
            reconhecedor.startListening(pedido)
            agendarLimite(listener)
            true
        } catch (erro: Exception) {
            encerrar()
            listener.onErro(
                "Falha ao abrir o microfone: ${erro.message ?: erro.javaClass.simpleName}"
            )
            false
        }
    }

    private fun agendarLimite(listener: Listener) {
        cancelarLimite()
        val parar = Runnable {
            limite = null
            if (entregou) return@Runnable
            entregou = true
            encerrar()
            listener.onErro("Nenhum comando foi ouvido em 12 segundos.")
        }
        limite = parar
        handler.postDelayed(parar, LIMITE_MS)
    }

    private fun cancelarLimite() {
        limite?.let(handler::removeCallbacks)
        limite = null
    }

    /** Libera o microfone sem chamar callback. */
    fun cancelar() {
        entregou = true
        encerrar()
    }

    private fun encerrar() {
        ativo = false
        cancelarLimite()
        try {
            recognizer?.cancel()
        } catch (_: Exception) {
        }
        try {
            recognizer?.destroy()
        } catch (_: Exception) {
        }
        recognizer = null
    }

    private fun mensagemErro(codigo: Int): String = when (codigo) {
        SpeechRecognizer.ERROR_AUDIO -> "Falha na captura de áudio. Verifique o microfone."
        SpeechRecognizer.ERROR_CLIENT -> "O reconhecedor offline encerrou a captura."
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Permissão de microfone insuficiente."
        SpeechRecognizer.ERROR_NETWORK, SpeechRecognizer.ERROR_NETWORK_TIMEOUT ->
            "O mecanismo offline não concluiu a transcrição; nada foi enviado para a nuvem."
        SpeechRecognizer.ERROR_NO_MATCH ->
            "Não consegui entender o comando. Chame o JARVIS e fale de novo."
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "O reconhecedor de fala já está ocupado."
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "Nenhuma fala foi detectada após a ativação."
        SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED, SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE ->
            "O Android não tem o pacote offline de português neste aparelho; nada foi enviado " +
                "para a nuvem. Instale em Configurações → Google → Voz → Reconhecimento de " +
                "fala offline ou use o app aberto."
        else -> "Erro no reconhecimento offline (código $codigo)."
    }
}
