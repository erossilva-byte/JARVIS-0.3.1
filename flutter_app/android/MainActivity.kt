package com.jarvis.nova

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    companion object {
        private var eventSink: EventChannel.EventSink? = null
        private val pendingEvents = ArrayDeque<Map<String, Any>>()
        private val mainHandler = Handler(Looper.getMainLooper())

        @JvmStatic
        fun emitEvent(event: Map<String, Any>) {
            mainHandler.post {
                val sink = eventSink
                if (sink != null) sink.success(event) else {
                    if (pendingEvents.size >= 8) pendingEvents.removeFirst()
                    pendingEvents.addLast(event)
                }
            }
        }

        @JvmStatic
        fun emitWake(keyword: String) = emitEvent(mapOf("type" to "wake", "keyword" to keyword))
    }

    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingTestSeconds: Int? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var recognitionInProgress = false
    private var wakeIntentPending = false
    private val requestAudioCode = 47147

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.jarvis.nova/kws")
            .setMethodCallHandler(this)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.jarvis.nova/kws/events")
            .setStreamHandler(this)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        wakeIntentPending = intent?.getStringExtra("jarvis_wake_keyword") != null
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getStringExtra("jarvis_wake_keyword") != null) {
            wakeIntentPending = true
            startCommandRecognitionWhenResumed()
        }
    }

    override fun onResume() {
        super.onResume()
        if (wakeIntentPending) startCommandRecognitionWhenResumed()
    }

    private fun startCommandRecognitionWhenResumed() {
        if (!wakeIntentPending || recognitionInProgress || isFinishing) return
        mainHandler.postDelayed({
            if (!wakeIntentPending || isFinishing || isDestroyed || recognitionInProgress) return@postDelayed
            wakeIntentPending = false
            beginOnDeviceCommandRecognition()
        }, 450L)
    }

    private fun beginOnDeviceCommandRecognition() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED) {
            emitEvent(mapOf("type" to "command_error", "message" to "Permissão de microfone não concedida para capturar o comando."))
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            !SpeechRecognizer.isOnDeviceRecognitionAvailable(this)) {
            emitEvent(mapOf(
                "type" to "command_error",
                "message" to "Este aparelho não disponibilizou reconhecimento de fala offline em português. Nenhum serviço de nuvem será usado como fallback."
            ))
            return
        }

        try {
            speechRecognizer?.destroy()
            speechRecognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
            val recognizer = speechRecognizer ?: throw IllegalStateException("Não foi possível criar o reconhecedor offline.")
            recognitionInProgress = true
            recognizer.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {
                    emitEvent(mapOf("type" to "command_status", "message" to "Ouvindo seu comando em português…"))
                }
                override fun onBeginningOfSpeech() = Unit
                override fun onRmsChanged(rmsdB: Float) = Unit
                override fun onBufferReceived(buffer: ByteArray?) = Unit
                override fun onEndOfSpeech() {
                    emitEvent(mapOf("type" to "command_status", "message" to "Processando transcrição local…"))
                }
                override fun onError(error: Int) {
                    recognitionInProgress = false
                    emitEvent(mapOf("type" to "command_error", "message" to recognitionError(error)))
                    destroySpeechRecognizer()
                }
                override fun onResults(results: Bundle?) {
                    recognitionInProgress = false
                    val text = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        ?.firstOrNull()?.trim().orEmpty()
                    if (text.isEmpty()) {
                        emitEvent(mapOf("type" to "command_error", "message" to "O reconhecimento offline não identificou palavras. Tente novamente."))
                    } else {
                        emitEvent(mapOf("type" to "command_result", "text" to text, "language" to "pt-BR", "engine" to "Android On-device SpeechRecognizer"))
                    }
                    destroySpeechRecognizer()
                }
                override fun onPartialResults(partialResults: Bundle?) {
                    val partial = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()
                    if (!partial.isNullOrBlank()) emitEvent(mapOf("type" to "command_partial", "text" to partial))
                }
                override fun onEvent(eventType: Int, params: Bundle?) = Unit
            })
            val request = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, "pt-BR")
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "pt-BR")
                putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
                putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
            }
            recognizer.startListening(request)
        } catch (error: Exception) {
            recognitionInProgress = false
            emitEvent(mapOf("type" to "command_error", "message" to "Falha ao iniciar reconhecimento offline: ${error.message ?: error.javaClass.simpleName}"))
            destroySpeechRecognizer()
        }
    }

    private fun recognitionError(code: Int): String = when (code) {
        SpeechRecognizer.ERROR_AUDIO -> "Falha na captura de áudio. Verifique o microfone."
        SpeechRecognizer.ERROR_CLIENT -> "O reconhecedor offline encerrou a captura."
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Permissão de microfone insuficiente."
        SpeechRecognizer.ERROR_NETWORK, SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "O mecanismo offline não concluiu a transcrição; nenhuma alternativa online foi acionada."
        SpeechRecognizer.ERROR_NO_MATCH -> "Não consegui entender o comando. Tente falar novamente."
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "O reconhecedor de fala já está ocupado."
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "Nenhuma fala foi detectada após a ativação."
        else -> "Erro no reconhecimento offline (código $code)."
    }

    private fun destroySpeechRecognizer() {
        try { speechRecognizer?.cancel() } catch (_: Exception) { }
        try { speechRecognizer?.destroy() } catch (_: Exception) { }
        speechRecognizer = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(statusMap())
            "start" -> ensurePermissionAndStart(result, null)
            "test" -> {
                val seconds = (call.argument<Number>("seconds")?.toInt() ?: 20).coerceIn(10, 60)
                ensurePermissionAndStart(result, seconds)
            }
            "stop" -> {
                stopService(Intent(this, KwsForegroundService::class.java))
                KwsForegroundService.clearState()
                result.success(statusMap())
            }
            else -> result.notImplemented()
        }
    }

    private fun ensurePermissionAndStart(result: MethodChannel.Result, testSeconds: Int?) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
            == PackageManager.PERMISSION_GRANTED) {
            startAndAwaitEngine(result, testSeconds)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("request_in_progress", "Já existe uma solicitação de microfone em andamento.", null)
            return
        }
        pendingPermissionResult = result
        pendingTestSeconds = testSeconds
        requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), requestAudioCode)
    }

    @Deprecated("Deprecated in Android API; retained for FlutterActivity compatibility")
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != requestAudioCode) return
        val result = pendingPermissionResult ?: return
        val testSeconds = pendingTestSeconds
        pendingPermissionResult = null
        pendingTestSeconds = null
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            startAndAwaitEngine(result, testSeconds)
        } else {
            result.success(mapOf("available" to true, "listening" to false, "engine" to KwsForegroundService.ENGINE,
                "detail" to "Permissão de microfone negada. O KWS não foi iniciado."))
        }
    }

    private fun startAndAwaitEngine(result: MethodChannel.Result, testSeconds: Int?) {
        KwsForegroundService.clearError()
        val intent = Intent(this, KwsForegroundService::class.java).apply {
            action = KwsForegroundService.ACTION_START
            if (testSeconds != null) putExtra(KwsForegroundService.EXTRA_TEST_SECONDS, testSeconds)
        }
        try {
            ContextCompat.startForegroundService(this, intent)
        } catch (error: Exception) {
            result.success(mapOf("available" to true, "listening" to false, "engine" to KwsForegroundService.ENGINE,
                "detail" to "Não foi possível iniciar o serviço KWS: ${error.message ?: error.javaClass.simpleName}"))
            return
        }
        awaitEngineState(result, System.currentTimeMillis() + 10000L)
    }

    private fun awaitEngineState(result: MethodChannel.Result, deadline: Long) {
        val listening = KwsForegroundService.isListening()
        val error = KwsForegroundService.lastError()
        if (listening || error.isNotEmpty() || System.currentTimeMillis() >= deadline) {
            result.success(statusMap())
            return
        }
        mainHandler.postDelayed({ awaitEngineState(result, deadline) }, 120L)
    }

    private fun statusMap(): Map<String, Any> = mapOf(
        "available" to true,
        "listening" to KwsForegroundService.isListening(),
        "engine" to KwsForegroundService.ENGINE,
        "detail" to KwsForegroundService.lastError().ifEmpty {
            if (KwsForegroundService.isListening()) "Detector sherpa-onnx ativo; áudio processado localmente."
            else if (KwsForegroundService.isServiceRunning()) "Serviço ativo; aguardando confirmação de captura e inferência."
            else "Plugin Android carregado; serviço KWS parado."
        }
    )

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        while (pendingEvents.isNotEmpty()) events?.success(pendingEvents.removeFirst())
    }

    override fun onCancel(arguments: Any?) { eventSink = null }

    override fun onDestroy() {
        if (pendingPermissionResult != null) {
            pendingPermissionResult?.error("activity_destroyed", "A tela foi encerrada durante a permissão do microfone.", null)
            pendingPermissionResult = null
        }
        destroySpeechRecognizer()
        super.onDestroy()
    }
}
