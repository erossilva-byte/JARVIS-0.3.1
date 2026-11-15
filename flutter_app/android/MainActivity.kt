package com.jarvis.nova

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
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
        const val ACAO_VOZ = "com.jarvis.nova.ACAO_VOZ"
        const val ACAO_CONVERSA = "com.jarvis.nova.ACAO_CONVERSA"
        const val ACAO_HISTORICO = "com.jarvis.nova.ACAO_HISTORICO"
        const val CANAL_SISTEMA = "com.jarvis.nova/sistema"
        const val CANAL_MEMORIA = "com.jarvis.nova/memoria"

        private const val PREFS_SAF = "jarvis_saf"
        private const val CHAVE_PASTA = "pasta"
        private const val LIMITE_NOTAS = 400
        private const val LIMITE_BYTES = 256 * 1024

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

    private var sistemaCanal: MethodChannel? = null
    private var intencaoInicial: Map<String, Any>? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingTestSeconds: Int? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var recognitionInProgress = false
    private var wakeIntentPending = false
    private val requestAudioCode = 47147
    private val requestPastaCode = 47150
    private var pendingPasta: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.jarvis.nova/kws")
            .setMethodCallHandler(this)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.jarvis.nova/kws/events")
            .setStreamHandler(this)
        val sistema = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL_SISTEMA)
        sistema.setMethodCallHandler { call, result ->
            when (call.method) {
                "compartilhar" -> {
                    val texto = call.argument<String>("texto").orEmpty().trim()
                    if (texto.isEmpty()) {
                        result.error("texto_vazio", "Nada para compartilhar.", null)
                    } else {
                        compartilharTexto(texto)
                        result.success(true)
                    }
                }
                "atualizarWidget" -> {
                    JarvisWidgetProvider.atualizar(this, call.argument<String>("texto").orEmpty())
                    result.success(true)
                }
                "intencaoPendente" -> {
                    result.success(intencaoInicial)
                    intencaoInicial = null
                }
                else -> result.notImplemented()
            }
        }
        sistemaCanal = sistema

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL_MEMORIA)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pastaAtual" -> result.success(pastaAtual())
                    "escolherPasta" -> escolherPasta(result)
                    "listarNotas" -> listarNotas(result)
                    "esquecerPasta" -> {
                        esquecerPasta()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Abre o seletor do sistema; a permissão é pedida de forma durável (SAF). */
    private fun escolherPasta(result: MethodChannel.Result) {
        if (pendingPasta != null) {
            result.error("em_andamento", "Já existe uma escolha de pasta em andamento.", null)
            return
        }
        pendingPasta = result
        val seletor = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        try {
            startActivityForResult(seletor, requestPastaCode)
        } catch (erro: Exception) {
            pendingPasta = null
            result.error(
                "sem_seletor",
                "Este aparelho não abriu o seletor de pasta: ${erro.message ?: erro.javaClass.simpleName}",
                null
            )
        }
    }

    @Deprecated("FlutterActivity usa onActivityResult para o seletor de pasta do SAF")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != requestPastaCode) return
        val pendente = pendingPasta ?: return
        pendingPasta = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pendente.success(null)
            return
        }
        try {
            contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } catch (erro: SecurityException) {
            pendente.error("sem_permissao", "O sistema não concedeu permissão duradoura para esta pasta.", null)
            return
        }
        prefPasta().edit().putString(CHAVE_PASTA, uri.toString()).apply()
        pendente.success(mapaPasta(uri))
    }

    private fun prefPasta() = getSharedPreferences(PREFS_SAF, MODE_PRIVATE)

    /** Só devolve a pasta se a permissão durável continua concedida; senão, esquece. */
    private fun pastaAtual(): Map<String, Any>? {
        val salva = prefPasta().getString(CHAVE_PASTA, null) ?: return null
        val uri = Uri.parse(salva)
        val permitida = contentResolver.persistedUriPermissions.any { it.uri == uri && it.isReadPermission }
        if (!permitida) {
            esquecerPasta()
            return null
        }
        return mapaPasta(uri)
    }

    private fun mapaPasta(uri: Uri): Map<String, Any> {
        val nome = try {
            contentResolver.query(uri, arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            }
        } catch (_: Exception) {
            null
        } ?: uri.lastPathSegment.orEmpty()
        return mapOf("uri" to uri.toString(), "nome" to nome)
    }

    private fun esquecerPasta() {
        val salva = prefPasta().getString(CHAVE_PASTA, null)
        if (salva != null) {
            try {
                contentResolver.releasePersistableUriPermission(Uri.parse(salva), Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } catch (_: Exception) {
                // Permissão já revogada pelo sistema: só limpar a preferência.
            }
        }
        prefPasta().edit().remove(CHAVE_PASTA).apply()
    }

    /** Lê .md da pasta escolhida, com limite de notas, profundidade e tamanho por arquivo. */
    private fun listarNotas(result: MethodChannel.Result) {
        val pasta = pastaAtual()
        if (pasta == null) {
            result.error("sem_pasta", "Nenhuma pasta do Obsidian conectada.", null)
            return
        }
        val raiz = Uri.parse(pasta["uri"] as String)
        val notas = mutableListOf<Map<String, Any>>()
        var ignoradas = 0
        var truncadas = 0

        fun lerTexto(documento: Uri): String? = try {
            contentResolver.openInputStream(documento)?.use { entrada ->
                val saida = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                var total = 0
                while (true) {
                    val lidos = entrada.read(buffer)
                    if (lidos <= 0) break
                    total += lidos
                    if (total > LIMITE_BYTES) return@use null
                    saida.write(buffer, 0, lidos)
                }
                String(saida.toByteArray(), Charsets.UTF_8)
            }
        } catch (_: Exception) {
            null
        }

        fun visitar(pastaUri: Uri, prefixo: String, profundidade: Int) {
            if (notas.size >= LIMITE_NOTAS || profundidade > 3) return
            val idPasta = if (DocumentsContract.isTreeUri(pastaUri)) {
                DocumentsContract.getTreeDocumentId(pastaUri)
            } else {
                DocumentsContract.getDocumentId(pastaUri)
            }
            val filhos = DocumentsContract.buildChildDocumentsUriUsingTree(raiz, idPasta)
            val colunas = arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
                DocumentsContract.Document.COLUMN_SIZE,
            )
            contentResolver.query(filhos, colunas, null, null, null)?.use { cursor ->
                while (cursor.moveToNext() && notas.size < LIMITE_NOTAS) {
                    val id = cursor.getString(0) ?: continue
                    val nome = cursor.getString(1) ?: continue
                    val tipo = cursor.getString(2).orEmpty()
                    if (tipo == DocumentsContract.Document.MIME_TYPE_DIR) {
                        val caminho = if (prefixo.isEmpty()) nome else "$prefixo/$nome"
                        visitar(DocumentsContract.buildDocumentUriUsingTree(raiz, id), caminho, profundidade + 1)
                        continue
                    }
                    if (!nome.endsWith(".md", ignoreCase = true)) {
                        ignoradas++
                        continue
                    }
                    val tamanho = if (cursor.isNull(3)) 0L else cursor.getLong(3)
                    if (tamanho > LIMITE_BYTES) {
                        truncadas++
                        continue
                    }
                    val conteudo = lerTexto(DocumentsContract.buildDocumentUriUsingTree(raiz, id))
                    if (conteudo == null) {
                        ignoradas++
                        continue
                    }
                    notas.add(mapOf(
                        "nome" to nome,
                        "caminho" to (if (prefixo.isEmpty()) nome else "$prefixo/$nome"),
                        "conteudo" to conteudo,
                    ))
                }
            }
        }

        try {
            visitar(raiz, "", 0)
        } catch (erro: Exception) {
            result.error("falha_leitura", "Não foi possível ler a pasta: ${erro.message ?: erro.javaClass.simpleName}", null)
            return
        }
        result.success(mapOf("notas" to notas, "ignoradas" to ignoradas, "truncadas" to truncadas))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        wakeIntentPending = intent?.getStringExtra("jarvis_wake_keyword") != null
        // Atalho, widget ou compartilhamento que abriu o app: o Flutter busca ao iniciar.
        intencaoInicial = lerIntencao(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        despacharIntencao(intent)
        if (intent.getStringExtra("jarvis_wake_keyword") != null) {
            wakeIntentPending = true
            startCommandRecognitionWhenResumed()
        }
    }

    override fun onResume() {
        super.onResume()
        if (wakeIntentPending) startCommandRecognitionWhenResumed()
    }

    /** Entrega a intenção ao Flutter quando ele já está ouvindo; senão guarda para a abertura. */
    private fun despacharIntencao(intent: Intent?) {
        val intencao = lerIntencao(intent) ?: return
        val canal = sistemaCanal
        if (canal == null) {
            intencaoInicial = intencao
        } else {
            canal.invokeMethod("intencao", intencao)
        }
    }

    /** Traduz a ação Android em um pedido conhecido pelo Flutter; consome a intenção. */
    private fun lerIntencao(intent: Intent?): Map<String, Any>? {
        if (intent == null) return null
        val texto = intent.getStringExtra(Intent.EXTRA_TEXT)?.trim().orEmpty()
        val dados = when (intent.action) {
            ACAO_VOZ -> mapOf("acao" to "voz", "texto" to "")
            ACAO_CONVERSA -> mapOf("acao" to "conversa", "texto" to "")
            ACAO_HISTORICO -> mapOf("acao" to "historico", "texto" to "")
            Intent.ACTION_SEND -> if (texto.isEmpty()) null else mapOf("acao" to "compartilhar", "texto" to texto)
            else -> null
        }
        if (dados != null) {
            // Sem isso, girar a tela ou voltar ao app repetiria o mesmo pedido.
            intent.action = Intent.ACTION_MAIN
            intent.removeExtra(Intent.EXTRA_TEXT)
        }
        return dados
    }

    private fun compartilharTexto(texto: String) {
        val envio = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, texto)
        }
        startActivity(Intent.createChooser(envio, "Compartilhar conversa"))
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
        if (pendingPasta != null) {
            pendingPasta?.error("activity_destroyed", "A tela foi encerrada durante a escolha da pasta.", null)
            pendingPasta = null
        }
        destroySpeechRecognizer()
        super.onDestroy()
    }
}
