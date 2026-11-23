package com.jarvis.nova

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
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
import java.io.ByteArrayOutputStream
import kotlin.math.min

class MainActivity : FlutterActivity(), MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    companion object {
        const val ACAO_VOZ = "com.jarvis.nova.ACAO_VOZ"
        const val ACAO_CONVERSA = "com.jarvis.nova.ACAO_CONVERSA"
        const val ACAO_HISTORICO = "com.jarvis.nova.ACAO_HISTORICO"
        const val CANAL_SISTEMA = "com.jarvis.nova/sistema"
        const val CANAL_MEMORIA = "com.jarvis.nova/memoria"
        const val CANAL_SENSORES = "com.jarvis.nova/sensores"
        const val CANAL_VIDEO = "com.jarvis.nova/visao-video"
        const val CANAL_VOZ = "com.jarvis.nova/voz"

        private const val PREFS_SAF = "jarvis_saf"
        private const val CHAVE_PASTA = "pasta"
        /** Prazo para o AudioRecord do detector fechar de verdade. */
        private const val ESPERA_LIBERAR_MICROFONE_MS = 1_500L
        /** Folga depois de soltar o microfone, antes de abrir o reconhecedor. */
        private const val FOLGA_DEPOIS_DO_MICROFONE_MS = 180L
        /** Quando o microfone não fechou no prazo, abre mais devagar. */
        private const val FOLGA_LONGA_DO_MICROFONE_MS = 600L
        private val VIES_DE_DOMINIO = listOf(
            "Jarvis", "CADeSIMU", "disjuntor", "contator", "ladder", "CLP",
            "motor", "trifásico", "resistor", "circuito", "código", "função",
            "Python", "Dart", "Kotlin", "teste", "notícia", "vídeo", "imagem",
            "microfone", "volume", "lanterna",
        )
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

        /**
         * A tela está na frente? O serviço de palavra de ativação usa isto para
         * distinguir "chamado com o app aberto" de "chamado em segundo plano".
         * Com a tela aberta o comando é reconhecido e respondido na conversa,
         * mesmo sem a autorização de "Exibir sobre outros apps".
         */
        @Volatile private var visivel = false
        @JvmStatic fun marcarVisivel(ativo: Boolean) { visivel = ativo }
        @JvmStatic fun estaVisivel() = visivel
    }

    private var sistemaCanal: MethodChannel? = null
    private var intencaoInicial: Map<String, Any>? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingTestSeconds: Int? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var voz: JarvisVoz? = null
    private var recognitionInProgress = false
    private var wakeIntentPending = false
    // Uma nova tentativa automática depois de "não entendi": o usuário não precisa
    // chamar o JARVIS de novo só porque falou baixo na primeira vez.
    private var tentativasComando = 0
    // O reconhecedor offline costuma entregar parte da frase antes de falhar;
    // guardar o melhor parcial evita perder o comando no fim do áudio.
    private var melhorParcialComando = ""
    private val requestAudioCode = 47147
    private val requestPastaCode = 47150
    private var pendingPasta: MethodChannel.Result? = null
    private val requestCadCode = 47151
    private var pendingCad: MethodChannel.Result? = null
    private val limiteCadBytes = 2 * 1024 * 1024
    private var aparelho: JarvisAparelho? = null
    // Atualizador OTA: consulta o release, confere o SHA-256 e abre o instalador.
    private var atualizacao: JarvisAtualizacao? = null
    private var vigiaSensores: JarvisSensores.Vigia? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.jarvis.nova/kws")
            .setMethodCallHandler(this)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.jarvis.nova/kws/events")
            .setStreamHandler(this)
        JarvisComandos(this).registrar(flutterEngine)
        // Automação de tela: só age com o interruptor do app ligado e o serviço
        // autorizado nas configurações do Android.
        JarvisAcessibilidadeCanal(this).registrar(flutterEngine)
        JarvisFundoCanal(this).registrar(flutterEngine)
        // Perguntas livres ouvidas em segundo plano são respondidas pelo
        // provedor de IA configurado no app, por esta ponte.
        JarvisPonteIa.registrar(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL_SENSORES)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "estado" -> result.success(JarvisSensores.estado(this))
                    "definirCalarAoVirar" -> {
                        JarvisSensores.definirCalarAoVirar(
                            this, call.argument<Boolean>("ativo") == true)
                        rearmarVigia()
                        result.success(JarvisSensores.estado(this))
                    }
                    "definirModoNoturno" -> {
                        JarvisSensores.definirModoNoturno(
                            this, call.argument<Boolean>("ativo") == true)
                        aplicarBrilho()
                        result.success(JarvisSensores.estado(this))
                    }
                    "definirBrilho" -> {
                        val valor = call.argument<Number>("brilho")?.toInt()
                            ?: JarvisSensores.brilho(this)
                        JarvisSensores.definirBrilho(this, valor)
                        aplicarBrilho()
                        result.success(JarvisSensores.estado(this))
                    }
                    // Fallback da tela e do gesto: cala a voz agora.
                    "calar" -> {
                        calarTudo()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        JarvisBiometria(this).registrar(flutterEngine)
        aparelho = JarvisAparelho(this).also { it.registrar(flutterEngine) }
        atualizacao = JarvisAtualizacao(this).also { it.registrar(flutterEngine) }
        voz = JarvisVoz(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL_VOZ)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "falar" -> {
                        val texto = call.argument<String>("texto").orEmpty().trim()
                        if (texto.isEmpty()) {
                            result.success(false)
                        } else {
                            result.success(voz?.falar(texto) == true)
                        }
                    }
                    "parar" -> {
                        voz?.parar()
                        result.success(true)
                    }
                    // Voz externa: o MP3 já gerado é tocado pelo MediaPlayer.
                    "falarAudio" -> {
                        val caminho = call.argument<String>("caminho").orEmpty()
                        result.success(voz?.falarAudio(caminho) == true)
                    }
                    "pararAudio" -> {
                        voz?.pararAudio()
                        result.success(true)
                    }
                    "status" -> result.success(voz?.status() ?: mapOf("available" to false))
                    // Perfis de timbre: grave, natural e ágil.
                    "timbre" -> result.success(JarvisTimbre.estado(this))
                    "definirTimbre" -> {
                        val salvo = JarvisTimbre.definir(
                            this, call.argument<String>("id"))
                        val aplicado = voz?.aplicarTimbre() == true
                        result.success(
                            JarvisTimbre.estado(this) + mapOf("aplicado" to aplicado)
                        )
                    }
                    else -> result.notImplemented()
                }
            }
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
                "abrirUrl" -> {
                    val url = call.argument<String>("url").orEmpty().trim()
                    // Só http/https: o palco nunca abre outro esquema.
                    if (!url.startsWith("http://") && !url.startsWith("https://")) {
                        result.success(false)
                    } else {
                        result.success(abrirNoNavegador(url))
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL_VIDEO)
            .setMethodCallHandler { call, result ->
                if (call.method != "extrairQuadros") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val caminho = call.argument<String>("caminho").orEmpty().trim()
                if (caminho.isEmpty()) {
                    result.error("caminho_vazio", "O vídeo não tem um caminho válido.", null)
                    return@setMethodCallHandler
                }
                val maximo = (call.argument<Number>("max")?.toInt() ?: 6).coerceIn(1, 8)
                val larguraMax = (call.argument<Number>("larguraMax")?.toInt() ?: 1024).coerceIn(320, 1600)
                Thread {
                    try {
                        val dados = extrairQuadrosVideo(caminho, maximo, larguraMax)
                        runOnUiThread { result.success(dados) }
                    } catch (erro: Exception) {
                        runOnUiThread {
                            result.error(
                                "falha_video",
                                "Não foi possível ler o vídeo: ${erro.message ?: erro.javaClass.simpleName}",
                                null
                            )
                        }
                    }
                }.start()
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL_MEMORIA)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pastaAtual" -> result.success(pastaAtual())
                    "escolherPasta" -> escolherPasta(result)
                    "abrirCad" -> abrirCad(result)
                    "listarNotas" -> listarNotas(result)
                    "escreverNota" -> {
                        val caminho = call.argument<String>("caminho").orEmpty()
                        val conteudo = call.argument<String>("conteudo").orEmpty()
                        escreverNota(caminho, conteudo, result)
                    }
                    "esquecerPasta" -> {
                        esquecerPasta()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Extrai até [maximo] quadros distribuídos e devolve JPEG reduzido para análise. */
    private fun extrairQuadrosVideo(caminho: String, maximo: Int, larguraMax: Int): Map<String, Any> {
        val retriever = MediaMetadataRetriever()
        try {
            if (caminho.startsWith("content://")) {
                retriever.setDataSource(this, Uri.parse(caminho))
            } else {
                retriever.setDataSource(caminho)
            }
            val duracaoMs = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull() ?: 0L
            if (duracaoMs <= 0L) {
                throw IllegalStateException("A duração do vídeo não foi informada.")
            }
            val quantidade = if (duracaoMs < 1000L) 1 else maximo
            val passo = duracaoMs / (quantidade + 1)
            val quadros = mutableListOf<Map<String, Any>>()
            for (indice in 1..quantidade) {
                val tempoMs = (passo * indice).coerceIn(0L, (duracaoMs - 1).coerceAtLeast(0L))
                val bitmap = try {
                    retriever.getFrameAtTime(tempoMs * 1000L, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                } catch (_: Exception) {
                    null
                } ?: continue
                val escala = min(1f, larguraMax.toFloat() / bitmap.width.toFloat())
                val ajustado = if (escala < 1f) {
                    Bitmap.createScaledBitmap(
                        bitmap,
                        (bitmap.width * escala).toInt().coerceAtLeast(1),
                        (bitmap.height * escala).toInt().coerceAtLeast(1),
                        true
                    )
                } else {
                    bitmap
                }
                val saida = ByteArrayOutputStream()
                ajustado.compress(Bitmap.CompressFormat.JPEG, 80, saida)
                quadros.add(
                    mapOf(
                        "tempoMs" to tempoMs,
                        "largura" to ajustado.width,
                        "altura" to ajustado.height,
                        "bytes" to saida.toByteArray()
                    )
                )
                if (ajustado !== bitmap) ajustado.recycle()
                bitmap.recycle()
            }
            if (quadros.isEmpty()) {
                throw IllegalStateException("Nenhum quadro pôde ser extraído do vídeo.")
            }
            return mapOf("duracaoMs" to duracaoMs, "quadros" to quadros)
        } finally {
            retriever.release()
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
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
            )
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

    /** Abre um .cad do CADe_SIMU somente para leitura; nada é gravado de volta. */
    private fun abrirCad(result: MethodChannel.Result) {
        if (pendingCad != null) {
            result.error("em_andamento", "Já existe uma escolha de arquivo .cad em andamento.", null)
            return
        }
        pendingCad = result
        val seletor = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("text/plain", "application/octet-stream", "application/x-cad"))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
            startActivityForResult(seletor, requestCadCode)
        } catch (erro: Exception) {
            pendingCad = null
            result.error("sem_seletor", "Este aparelho não abriu o seletor de arquivos: ${erro.message ?: erro.javaClass.simpleName}", null)
        }
    }

    private fun lerCad(uri: Uri, result: MethodChannel.Result) {
        val nome = try {
            contentResolver.query(uri, arrayOf(android.provider.OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            }
        } catch (_: Exception) {
            null
        } ?: uri.lastPathSegment.orEmpty()
        if (!nome.lowercase().endsWith(".cad")) {
            result.error("formato", "Escolha um arquivo com extensão .cad do CADe_SIMU.", null)
            return
        }
        val bytes = try {
            contentResolver.openInputStream(uri)?.use { entrada ->
                val saida = ByteArrayOutputStream()
                val bloco = ByteArray(64 * 1024)
                var total = 0
                while (true) {
                    val lido = entrada.read(bloco)
                    if (lido <= 0) break
                    total += lido
                    if (total > limiteCadBytes) {
                        result.error("grande", "O arquivo .cad passou do limite de 2 MB para leitura.", null)
                        return
                    }
                    saida.write(bloco, 0, lido)
                }
                saida.toByteArray()
            }
        } catch (erro: Exception) {
            result.error("leitura", "Não foi possível ler o arquivo .cad: ${erro.message ?: erro.javaClass.simpleName}", null)
            return
        }
        if (bytes == null || bytes.isEmpty()) {
            result.error("vazio", "O arquivo .cad está vazio.", null)
            return
        }
        result.success(mapOf("nome" to nome, "bytes" to bytes))
    }

    @Deprecated("FlutterActivity usa onActivityResult para o seletor de pasta do SAF")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        // A credencial do aparelho (recuperação do PIN) volta por aqui.
        if (JarvisBiometria.tratarResultado(requestCode, resultCode)) return
        if (requestCode == requestCadCode) {
            val pendente = pendingCad ?: return
            pendingCad = null
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) {
                pendente.success(null)
                return
            }
            lerCad(uri, pendente)
            return
        }
        if (requestCode != requestPastaCode) return
        val pendente = pendingPasta ?: return
        pendingPasta = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pendente.success(null)
            return
        }
        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
        } catch (erro: SecurityException) {
            // Alguns provedores só concedem leitura: a pasta serve para importar, não para enviar.
            try {
                contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } catch (erroLeitura: SecurityException) {
                pendente.error("sem_permissao", "O sistema não concedeu permissão duradoura para esta pasta.", null)
                return
            }
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
        val permissao = contentResolver.persistedUriPermissions.firstOrNull { it.uri == uri }
        return mapOf(
            "uri" to uri.toString(),
            "nome" to nome,
            "podeEscrever" to (permissao?.isWritePermission == true),
        )
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

    /** Escreve uma nota na pasta, criando subpastas e o arquivo quando necessário. */
    private fun escreverNota(caminho: String, conteudo: String, result: MethodChannel.Result) {
        val pasta = pastaAtual()
        if (pasta == null) {
            result.error("sem_pasta", "Nenhuma pasta do Obsidian conectada.", null)
            return
        }
        if (pasta["podeEscrever"] != true) {
            result.error(
                "sem_escrita",
                "A pasta foi conectada somente para leitura. Conecte de novo e permita editar para enviar notas.",
                null
            )
            return
        }
        val partes = caminho.replace('\\', '/').split('/').filter { it.isNotBlank() }
        if (partes.isEmpty() || !partes.last().endsWith(".md", ignoreCase = true)) {
            result.error("caminho_invalido", "O destino precisa ser um arquivo .md.", null)
            return
        }
        val raiz = Uri.parse(pasta["uri"] as String)
        try {
            var paiId = DocumentsContract.getTreeDocumentId(raiz)
            for (nomePasta in partes.dropLast(1)) {
                val existente = procurarFilho(raiz, paiId, nomePasta, DocumentsContract.Document.MIME_TYPE_DIR)
                paiId = existente?.first ?: (
                    DocumentsContract.createDocument(
                        contentResolver,
                        DocumentsContract.buildDocumentUriUsingTree(raiz, paiId),
                        DocumentsContract.Document.MIME_TYPE_DIR,
                        nomePasta
                    ) ?: throw IllegalStateException("Não foi possível criar a pasta $nomePasta")
                    ).let { DocumentsContract.getDocumentId(it) }
            }
            val nomeArquivo = partes.last()
            val existente = procurarFilho(raiz, paiId, nomeArquivo, null)
            val alvo = if (existente != null) {
                DocumentsContract.buildDocumentUriUsingTree(raiz, existente.first)
            } else {
                DocumentsContract.createDocument(
                    contentResolver,
                    DocumentsContract.buildDocumentUriUsingTree(raiz, paiId),
                    "text/markdown",
                    nomeArquivo
                ) ?: throw IllegalStateException("Não foi possível criar $nomeArquivo")
            }
            contentResolver.openOutputStream(alvo, "wt")?.use { saida ->
                saida.write(conteudo.toByteArray(Charsets.UTF_8))
                saida.flush()
            } ?: throw IllegalStateException("Não foi possível abrir $nomeArquivo para escrita")
            result.success(mapOf("caminho" to caminho, "criado" to (existente == null)))
        } catch (erro: Exception) {
            result.error(
                "falha_escrita",
                "Não foi possível gravar $caminho: ${erro.message ?: erro.javaClass.simpleName}",
                null
            )
        }
    }

    /** Procura um filho pelo nome (e tipo, quando informado) e devolve id + mime. */
    private fun procurarFilho(raiz: Uri, paiId: String, nome: String, tipo: String?): Pair<String, String>? {
        val filhos = DocumentsContract.buildChildDocumentsUriUsingTree(raiz, paiId)
        val colunas = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
        )
        contentResolver.query(filhos, colunas, null, null, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                val nomeFilho = cursor.getString(1) ?: continue
                val mime = cursor.getString(2).orEmpty()
                if (nomeFilho.equals(nome, ignoreCase = true) && (tipo == null || mime == tipo)) {
                    return cursor.getString(0) to mime
                }
            }
        }
        return null
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
        // A palavra é lida antes porque a intenção é consumida na entrega.
        val palavra = intent.getStringExtra("jarvis_wake_keyword")
        despacharIntencao(intent)
        if (!palavra.isNullOrBlank()) {
            wakeIntentPending = true
            startCommandRecognitionWhenResumed()
        }
    }

    override fun onResume() {
        super.onResume()
        marcarVisivel(true)
        aplicarBrilho()
        rearmarVigia()
        if (wakeIntentPending) startCommandRecognitionWhenResumed()
    }

    override fun onPause() {
        // Sensor só enquanto a tela está na frente: sem isso ele gastaria bateria.
        vigiaSensores?.parar()
        vigiaSensores = null
        marcarVisivel(false)
        super.onPause()
    }

    /**
     * Aplica o brilho do modo noturno na janela do app.
     *
     * BRIGHTNESS_OVERRIDE_NONE devolve o controle ao sistema; mudar o brilho do
     * aparelho exigiria WRITE_SETTINGS e não é pedido aqui.
     */
    private fun aplicarBrilho() {
        val atributos = window.attributes
        atributos.screenBrightness = if (JarvisSensores.modoNoturno(this)) {
            JarvisSensores.brilho(this) / 100f
        } else {
            android.view.WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
        }
        window.attributes = atributos
    }

    /** Liga o vigia do acelerômetro só com a opção ativa e a tela na frente. */
    private fun rearmarVigia() {
        vigiaSensores?.parar()
        vigiaSensores = null
        if (!JarvisSensores.calarAoVirar(this)) return
        val vigia = JarvisSensores.Vigia(this) { calarTudo() }
        if (vigia.iniciar()) vigiaSensores = vigia
    }

    /** Para a fala do JARVIS (tela e serviço) quando o celular é virado. */
    private fun calarTudo() {
        voz?.parar()
        val pedido = Intent(this, KwsForegroundService::class.java).apply {
            action = KwsForegroundService.ACTION_CALAR
        }
        try {
            ContextCompat.startForegroundService(this, pedido)
        } catch (_: Exception) {
            // Sem serviço ativo não há voz de segundo plano para calar.
        }
        emitEvent(
            mapOf(
                "type" to "calou",
                "message" to "JARVIS calado pelo gesto do aparelho.",
            )
        )
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
        // Pedido de palco reconhecido na fala com o app fechado: a tela abre a
        // pesquisa já com o tipo e o assunto que o serviço ouviu.
        val palcoConsulta = intent.getStringExtra(JarvisPalco.EXTRA_CONSULTA)
            ?.trim().orEmpty()
        if (palcoConsulta.isNotEmpty()) {
            val tipo = intent.getStringExtra(JarvisPalco.EXTRA_TIPO).orEmpty()
            intent.removeExtra(JarvisPalco.EXTRA_CONSULTA)
            intent.removeExtra(JarvisPalco.EXTRA_TIPO)
            intent.action = Intent.ACTION_MAIN
            return mapOf("acao" to "palco", "texto" to palcoConsulta, "tipo" to tipo)
        }
        // Palavra de ativação detectada em segundo plano: a tela avisa que o
        // Jarvis está ativo e o reconhecimento segue no onResume.
        val palavra = intent.getStringExtra("jarvis_wake_keyword")
        if (!palavra.isNullOrBlank()) {
            intent.removeExtra("jarvis_wake_keyword")
            intent.action = Intent.ACTION_MAIN
            return mapOf("acao" to "ativo", "texto" to palavra)
        }
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

    /** Abre o endereço no navegador; `false` quando nenhum app aceita o link. */
    private fun abrirNoNavegador(url: String): Boolean = try {
        startActivity(
            Intent(Intent.ACTION_VIEW, Uri.parse(url))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        true
    } catch (_: Exception) {
        false
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
        tentativasComando = 0
        iniciarTentativaComando()
    }

    /**
     * Abre o microfone para o comando. O detector de palavra fica pausado e o estado
     * "comando em andamento" é publicado para a interface não religar o KWS por cima do
     * reconhecedor — dois microfones ao mesmo tempo devolvem silêncio e o Android
     * responde ERROR_NO_MATCH.
     */
    private fun iniciarTentativaComando() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED) {
            emitEvent(mapOf("type" to "command_error", "message" to "Permissão de microfone não concedida para capturar o comando."))
            encerrarComando()
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            !SpeechRecognizer.isOnDeviceRecognitionAvailable(this)) {
            emitEvent(mapOf(
                "type" to "command_error",
                "message" to "Este aparelho não disponibilizou reconhecimento de fala offline em português. Nenhum serviço de nuvem será usado como fallback."
            ))
            encerrarComando()
            return
        }

        KwsForegroundService.marcarComandoAtivo(true)
        // Libera o AudioRecord do detector antes de abrir o reconhecedor.
        if (KwsForegroundService.isServiceRunning()) KwsForegroundService.pausarMotor(this)
        abrirMicrofoneDoComando()
    }

    /**
     * Espera o detector fechar o microfone de verdade antes de abrir o reconhecedor.
     *
     * Antes o pedido de pausa era só um Intent, entregue depois: o reconhecedor abria
     * a captura com o AudioRecord do detector ainda gravando. Dois microfones ao mesmo
     * tempo devolvem silêncio, e o Android respondia "não entendi" mesmo com a fala
     * clara. A espera é confirmada, fora da thread principal e com prazo fixo.
     */
    private fun abrirMicrofoneDoComando() {
        Thread {
            val livre = KwsForegroundService.liberarMicrofone(ESPERA_LIBERAR_MICROFONE_MS)
            // Folga curta depois de soltar: o Android precisa reabrir a captura.
            val folga =
                if (livre) FOLGA_DEPOIS_DO_MICROFONE_MS else FOLGA_LONGA_DO_MICROFONE_MS
            mainHandler.postDelayed({
                if (isFinishing || isDestroyed) return@postDelayed
                if (!KwsForegroundService.isCommandActive()) return@postDelayed
                iniciarEscutaDoComando()
            }, folga)
        }.start()
    }

    /** Cria o reconhecedor offline e começa a ouvir o comando. */
    private fun iniciarEscutaDoComando() {
        melhorParcialComando = ""
        try {
            destroySpeechRecognizer()
            speechRecognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
            val recognizer = speechRecognizer ?: throw IllegalStateException("Não foi possível criar o reconhecedor offline.")
            recognitionInProgress = true
            recognizer.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {
                    emitEvent(mapOf("type" to "command_status", "message" to "Ouvindo sua pergunta ou comando em português…"))
                }
                override fun onBeginningOfSpeech() = Unit
                override fun onRmsChanged(rmsdB: Float) = Unit
                override fun onBufferReceived(buffer: ByteArray?) = Unit
                override fun onEndOfSpeech() {
                    emitEvent(mapOf("type" to "command_status", "message" to "Processando transcrição local…"))
                }
                override fun onError(error: Int) {
                    if (!recognitionInProgress) return
                    recognitionInProgress = false
                    destroySpeechRecognizer()
                    val parcial = melhorParcialComando.trim()
                    melhorParcialComando = ""
                    // O reconhecedor já entendeu parte do pedido: usar o que foi
                    // ouvido é melhor do que pedir a frase inteira de novo.
                    if (parcial.length >= 3) {
                        tentativasComando = 0
                        emitEvent(mapOf("type" to "command_result", "text" to parcial, "language" to "pt-BR", "engine" to "Android On-device SpeechRecognizer"))
                        encerrarComando()
                        return
                    }
                    if (tentativaValeRepetir(error) && tentativasComando < 1) {
                        tentativasComando++
                        emitEvent(mapOf("type" to "command_status", "message" to "Não entendi. Fale de novo, por favor…"))
                        mainHandler.postDelayed({
                            if (isFinishing || isDestroyed) return@postDelayed
                            iniciarTentativaComando()
                        }, atrasoRepeticao(error))
                        return
                    }
                    emitEvent(mapOf("type" to "command_error", "message" to recognitionError(error)))
                    encerrarComando()
                }
                override fun onResults(results: Bundle?) {
                    if (!recognitionInProgress) return
                    recognitionInProgress = false
                    val text = melhorTranscricaoDoComando(results)
                    if (text.isEmpty()) {
                        emitEvent(mapOf("type" to "command_error", "message" to "O reconhecimento offline não identificou palavras. Tente novamente."))
                    } else {
                        tentativasComando = 0
                        emitEvent(mapOf("type" to "command_result", "text" to text, "language" to "pt-BR", "engine" to "Android On-device SpeechRecognizer"))
                    }
                    destroySpeechRecognizer()
                    encerrarComando()
                }
                override fun onPartialResults(partialResults: Bundle?) {
                    val partial = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()
                    if (!partial.isNullOrBlank()) {
                        if (partial.length > melhorParcialComando.length) melhorParcialComando = partial
                        emitEvent(mapOf("type" to "command_partial", "text" to partial))
                    }
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
                // Folga maior entre falar e concluir: comando curto ("abre o WhatsApp")
                // era cortado cedo demais e voltava como ERROR_NO_MATCH. A mesma folga
                // deixa a pergunta longa chegar inteira, com pausa no meio da frase.
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 2600L)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 2000L)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 1200L)
                aplicarViesDeDominio(request)
            }
            recognizer.startListening(request)
        } catch (error: Exception) {
            recognitionInProgress = false
            emitEvent(mapOf("type" to "command_error", "message" to "Falha ao iniciar reconhecimento offline: ${error.message ?: error.javaClass.simpleName}"))
            destroySpeechRecognizer()
            encerrarComando()
        }
    }

    /**
     * Vocabulário de domínio como pista do reconhecedor, só no Android 13+.
     *
     * Os termos vêm do que o app faz: elétrica/CADeSIMU, programação, palco e os comandos
     * do dia a dia. Nada de áudio sai do aparelho; a pista só ajuda o modelo local.
     */
    private fun aplicarViesDeDominio(pedido: Intent) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        try {
            pedido.putStringArrayListExtra(
                RecognizerIntent.EXTRA_BIASING_STRINGS,
                ArrayList(VIES_DE_DOMINIO)
            )
        } catch (_: Exception) {
            // Sem a pista a escuta continua; não vale derrubar o comando.
        }
    }

    /**
     * Melhor alternativa devolvida pelo Android, pela nota de confiança.
     *
     * O primeiro item nem sempre é o mais fiel. Nota negativa é "não informada": aí vale a
     * hipótese mais completa. Sem lista, devolve vazio (o chamador já trata).
     */
    private fun melhorTranscricaoDoComando(results: Bundle?): String {
        val lista = results
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.map { it.trim() }
            ?.filter { it.isNotEmpty() }
            .orEmpty()
        if (lista.isEmpty()) return ""
        val notas = results?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)
        if (notas == null || notas.size != lista.size) {
            return lista.maxByOrNull { it.length }.orEmpty()
        }
        var melhor = ""
        var melhorNota = -1f
        for (i in lista.indices) {
            val nota = if (notas[i] < 0f) lista[i].length / 1000f else notas[i]
            if (nota > melhorNota) {
                melhorNota = nota
                melhor = lista[i]
            }
        }
        return melhor
    }

    /** Microfone ocupado precisa de mais folga que silêncio. */
    private fun atrasoRepeticao(error: Int): Long = when (error) {
        SpeechRecognizer.ERROR_AUDIO,
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY,
        SpeechRecognizer.ERROR_CLIENT -> 800L
        else -> 350L
    }

    /** Silêncio e "não entendi" merecem outra escuta; falta de microfone não. */
    private fun tentativaValeRepetir(code: Int): Boolean = when (code) {
        SpeechRecognizer.ERROR_NO_MATCH,
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT,
        SpeechRecognizer.ERROR_SERVER_DISCONNECTED,
        // Microfone ocupado ou captura vazia: quase sempre é o detector ainda
        // soltando o AudioRecord; com a folga maior a segunda tentativa ouve.
        SpeechRecognizer.ERROR_AUDIO,
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY,
        SpeechRecognizer.ERROR_CLIENT -> true
        else -> false
    }

    /** Fecha o comando e devolve o microfone ao detector de palavra de ativação. */
    private fun encerrarComando() {
        tentativasComando = 0
        KwsForegroundService.marcarComandoAtivo(false)
        destroySpeechRecognizer()
        retomarKws()
    }

    /** O serviço KWS fica vivo; depois do comando, volta a ouvir a palavra. */
    private fun retomarKws() {
        if (KwsForegroundService.isServiceRunning()) KwsForegroundService.rearm(this)
    }

    private fun recognitionError(code: Int): String = when (code) {
        SpeechRecognizer.ERROR_AUDIO -> "Falha na captura de áudio. Verifique o microfone."
        SpeechRecognizer.ERROR_CLIENT -> "O reconhecedor offline encerrou a captura."
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Permissão de microfone insuficiente."
        SpeechRecognizer.ERROR_NETWORK, SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "O mecanismo offline não concluiu a transcrição; nenhuma alternativa online foi acionada."
        SpeechRecognizer.ERROR_NO_MATCH -> "Não consegui entender o comando. Tente falar novamente."
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "O reconhecedor de fala já está ocupado."
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "Nenhuma fala foi detectada após a ativação."
        SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED, SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE ->
            "O Android não tem o pacote offline de português neste aparelho. Instale em Configurações → Google → Voz → Reconhecimento de fala offline, ou escreva o comando na conversa. Nada é enviado para a nuvem."
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
            // Enquanto o comando está sendo ouvido o microfone é dele: iniciar o
            // detector agora roubaria a captura e o reconhecimento voltaria vazio.
            "start" -> if (KwsForegroundService.isCommandActive()) {
                result.success(statusMap())
            } else {
                ensurePermissionAndStart(result, null)
            }
            "test" -> {
                val seconds = (call.argument<Number>("seconds")?.toInt() ?: 20).coerceIn(10, 60)
                ensurePermissionAndStart(result, seconds)
            }
            "stop" -> {
                stopService(Intent(this, KwsForegroundService::class.java))
                KwsForegroundService.clearState()
                result.success(statusMap())
            }
            // Sensibilidade da palavra de ativação (0–100), guardada no aparelho.
            "sensibilidade" -> result.success(KwsForegroundService.sensibilidadeDe(this))
            "definirSensibilidade" -> {
                val valor = call.argument<Number>("valor")?.toInt()
                    ?: KwsForegroundService.sensibilidadeDe(this)
                result.success(KwsForegroundService.definirSensibilidade(this, valor))
            }
            // Frases em português: o Flutter já gravou as linhas tokenizadas; aqui
            // só religamos o detector para valer agora.
            "aplicarHotword" -> {
                KwsForegroundService.aplicarHotword(this)
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
        if (aparelho?.onRequestPermissionsResult(requestCode, grantResults) == true) return
        if (requestCode != requestAudioCode) return
        val result = pendingPermissionResult ?: return
        val testSeconds = pendingTestSeconds
        pendingPermissionResult = null
        pendingTestSeconds = null
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            startAndAwaitEngine(result, testSeconds)
        } else {
            result.success(mapOf("available" to true, "listening" to false, "engine" to KwsForegroundService.ENGINE,
                "ok" to false, "error" to "Permissão de microfone negada. O KWS não foi iniciado.",
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
            val detalhe = "Não foi possível iniciar o serviço KWS: ${error.message ?: error.javaClass.simpleName}"
            result.success(mapOf("available" to true, "listening" to false, "engine" to KwsForegroundService.ENGINE,
                "ok" to false, "error" to detalhe, "detail" to detalhe))
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

    private fun statusMap(): Map<String, Any> {
        val erro = KwsForegroundService.lastError()
        val comandoAtivo = KwsForegroundService.isCommandActive()
        val sensibilidade = KwsForegroundService.sensibilidadeDe(this)
        return mapOf(
            "available" to true,
            "listening" to KwsForegroundService.isListening(),
            "sensibilidade" to sensibilidade,
            "limiar" to JarvisKwsEngine.limiarPara(sensibilidade).toDouble(),
            "hotword" to KwsForegroundService.quantasHotwordsDe(this),
            "engine" to KwsForegroundService.ENGINE,
            "ok" to erro.isEmpty(),
            "error" to erro,
            "comandoAtivo" to comandoAtivo,
            "detail" to erro.ifEmpty {
                if (comandoAtivo) "O microfone está com o seu comando; a palavra de ativação volta em seguida."
                else if (KwsForegroundService.isListening()) "Detector sherpa-onnx ativo; áudio processado localmente."
                else if (KwsForegroundService.isServiceRunning()) "Serviço ativo; aguardando confirmação de captura e inferência."
                else "Plugin Android carregado; serviço KWS parado."
            }
        )
    }

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
        if (pendingCad != null) {
            pendingCad?.error("activity_destroyed", "A tela foi encerrada durante a escolha do arquivo .cad.", null)
            pendingCad = null
        }
        KwsForegroundService.marcarComandoAtivo(false)
        // Sem isso a próxima ativação acharia que ainda existe comando em curso.
        recognitionInProgress = false
        melhorParcialComando = ""
        destroySpeechRecognizer()
        voz?.shutdown()
        voz = null
        atualizacao?.encerrar()
        atualizacao = null
        retomarKws()
        super.onDestroy()
    }
}
