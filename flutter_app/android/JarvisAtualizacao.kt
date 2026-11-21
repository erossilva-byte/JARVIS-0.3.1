package com.jarvis.nova

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.Locale
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Canal `com.jarvis.nova/atualizacao`.
 *
 * O APK que se distribui é o release assinado pela chave do projeto. Esta ponte:
 *
 * 1) lista os releases publicados e escolhe o primeiro com um `.apk` anexado;
 * 2) baixa o `.apk.sha256` publicado junto e o APK para a pasta privada do app,
 *    medindo o SHA-256 durante a cópia;
 * 3) descarta o arquivo quando o digesto calculado não é o publicado — nesse
 *    caso nada é oferecido para instalar;
 * 4) abre o instalador do Android pelo FileProvider. A confirmação final é
 *    sempre do sistema: não existe instalação silenciosa.
 */
class JarvisAtualizacao(private val activity: Activity) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val CANAL = "com.jarvis.nova/atualizacao"
        const val CANAL_EVENTOS = "com.jarvis.nova/atualizacao/eventos"

        private const val REPOSITORIO = "erossilva-byte/JARVIS-0.3.1"
        private const val API_RELEASES =
            "https://api.github.com/repos/erossilva-byte/JARVIS-0.3.1/releases?per_page=10"
        private const val URL_RELEASES =
            "https://github.com/erossilva-byte/JARVIS-0.3.1/releases"
        private const val PASTA = "updates"
        private const val NOME_ARQUIVO = "jarvis-update.apk"
        private const val TIMEOUT_MS = 20000
        private const val TIMEOUT_DOWNLOAD_MS = 60000
        private const val MAX_APK_BYTES = 400L * 1024L * 1024L
        private const val MAX_SHA_BYTES = 8192L
        private const val HEX = "[0-9a-fA-F]{64}"
    }

    private val worker: ExecutorService = Executors.newSingleThreadExecutor()
    private var eventos: EventChannel.EventSink? = null

    fun registrar(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CANAL)
            .setMethodCallHandler(this)
        EventChannel(engine.dartExecutor.binaryMessenger, CANAL_EVENTOS)
            .setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventos = events
    }

    override fun onCancel(arguments: Any?) {
        eventos = null
    }

    /** Erro HTTP com o código preservado, para explicar a falha ao usuário. */
    private class ErroHttp(val codigo: Int, detalhe: String) :
        RuntimeException("HTTP $codigo" + if (detalhe.isEmpty()) "" else " — $detalhe")

    private fun arquivoBaixado(): File {
        val dir = File(activity.filesDir, PASTA)
        if (!dir.exists()) dir.mkdirs()
        return File(dir, NOME_ARQUIVO)
    }

    private fun infoInstalada(): PackageInfo? = try {
        @Suppress("DEPRECATION")
        activity.packageManager.getPackageInfo(activity.packageName, 0)
    } catch (e: Exception) {
        null
    }

    private fun versaoInstalada(info: PackageInfo?): String =
        info?.versionName.orEmpty()

    private fun codigoInstalado(info: PackageInfo?): Long {
        if (info == null) return -1
        return if (Build.VERSION.SDK_INT >= 28) info.longVersionCode
        else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
    }

    private fun podeInstalar(): Boolean =
        Build.VERSION.SDK_INT < 26 || activity.packageManager.canRequestPackageInstalls()

    private fun httpGetTexto(endereco: String, limiteBytes: Long): String {
        val conexao = URL(endereco).openConnection() as HttpURLConnection
        conexao.connectTimeout = TIMEOUT_MS
        conexao.readTimeout = TIMEOUT_MS
        conexao.setRequestProperty("User-Agent", "JARVIS-Nova-Updater")
        conexao.setRequestProperty("Accept", "application/vnd.github+json")
        try {
            val codigo = conexao.responseCode
            if (codigo < 200 || codigo >= 300) {
                var detalhe = ""
                try {
                    val erro = conexao.errorStream
                    if (erro != null) {
                        detalhe = erro.readBytes().toString(Charsets.UTF_8).trim()
                        if (detalhe.length > 160) detalhe = detalhe.substring(0, 160)
                        erro.close()
                    }
                } catch (ignorado: Exception) {
                }
                throw ErroHttp(codigo, detalhe)
            }
            val entrada = conexao.inputStream
            val texto = StringBuilder()
            val buffer = ByteArray(8192)
            var total = 0L
            var lidos: Int
            while (true) {
                lidos = entrada.read(buffer)
                if (lidos <= 0) break
                total += lidos
                if (total > limiteBytes) {
                    entrada.close()
                    throw RuntimeException("resposta maior que o esperado")
                }
                texto.append(String(buffer, 0, lidos, Charsets.UTF_8))
            }
            entrada.close()
            return texto.toString()
        } finally {
            conexao.disconnect()
        }
    }

    /** Explica o erro sem chamar de “conexão” o que foi recusa do servidor. */
    private fun explicar(erro: Exception): String {
        if (erro is ErroHttp) {
            return when (erro.codigo) {
                403 -> "o GitHub recusou a consulta (HTTP 403): limite de requisições desta rede ou acesso bloqueado. Tente mais tarde ou abra a página de releases"
                404 -> "o repositório ou a lista de releases não foi encontrada (HTTP 404)"
                401 -> "o repositório exige autenticação (HTTP 401)"
                else -> "o GitHub respondeu HTTP ${erro.codigo}"
            }
        }
        val mensagem = erro.message.orEmpty().trim()
        return if (mensagem.isEmpty()) "erro desconhecido" else mensagem
    }

    private fun partesDaVersao(texto: String?): List<Int>? {
        if (texto == null) return null
        val achado = Regex("(\\d+)(?:\\.(\\d+))?(?:\\.(\\d+))?").find(texto) ?: return null
        val partes = achado.groupValues.drop(1).map { if (it.isEmpty()) 0 else it.toInt() }
        return partes + List(3 - partes.size) { 0 }
    }

    private fun versaoMaior(nova: String, atual: String): Boolean {
        val a = partesDaVersao(nova) ?: return false
        val b = partesDaVersao(atual) ?: return nova.isNotEmpty()
        for (i in 0 until 3) {
            if (a[i] != b[i]) return a[i] > b[i]
        }
        return false
    }

    /** Lê o primeiro SHA-256 de um arquivo no formato `hash  arquivo.apk`. */
    private fun hashPublicado(texto: String): String {
        val achado = Regex(HEX).find(texto)
        return achado?.value?.lowercase(Locale.US).orEmpty()
    }

    /** Consulta a lista de releases e descreve o primeiro com APK anexado. */
    private fun consultar(): Map<String, Any?> {
        val info = infoInstalada()
        val atual = versaoInstalada(info)
        val base = mutableMapOf<String, Any?>(
            "disponivel" to false,
            "versaoInstalada" to atual,
            "versionCodeInstalado" to codigoInstalado(info),
            "repositorio" to REPOSITORIO,
            "urlReleases" to URL_RELEASES,
        )
        val lista = JSONArray(httpGetTexto(API_RELEASES, MAX_SHA_BYTES * 128))
        for (i in 0 until lista.length()) {
            val release = lista.optJSONObject(i) ?: continue
            if (release.optBoolean("draft", false)) continue
            val assets = release.optJSONArray("assets") ?: continue
            var apk: JSONObject? = null
            var sha: JSONObject? = null
            for (a in 0 until assets.length()) {
                val item = assets.optJSONObject(a) ?: continue
                val nome = item.optString("name", "")
                if (apk == null && nome.endsWith(".apk", ignoreCase = true)) apk = item
                if (sha == null && nome.endsWith(".sha256", ignoreCase = true)) sha = item
            }
            val arquivo = apk ?: continue
            val endereco = arquivo.optString("browser_download_url", "")
            if (!endereco.startsWith("https://")) continue

            val tag = release.optString("tag_name", "")
            val versao = partesDaVersao(tag)?.joinToString(".") ?: tag
            var digesto = arquivo.optString("digest", "")
            if (digesto.startsWith("sha256:")) digesto = digesto.removePrefix("sha256:")

            val urlSha = sha?.optString("browser_download_url", "").orEmpty()
            return base + mapOf(
                "disponivel" to versaoMaior(versao, atual),
                "motivo" to if (versaoMaior(versao, atual)) "disponivel" else "atualizado",
                "versao" to versao,
                "tag" to tag,
                "urlApk" to endereco,
                "nomeArquivo" to arquivo.optString("name", ""),
                "tamanho" to arquivo.optLong("size", -1L),
                "urlSha256" to urlSha,
                "nomeSha256" to sha?.optString("name", "").orEmpty(),
                "digesto" to digesto,
                "notas" to release.optString("body", "").replace('\n', ' ').trim(),
                "urlRelease" to release.optString("html_url", ""),
            )
        }
        return base + mapOf("motivo" to "nenhum-release")
    }

    private fun motivoFalha(release: Map<String, Any?>): String =
        when (release["motivo"]) {
            "nenhum-release" ->
                "Ainda não há release publicado com APK. Publique pela esteira do GitHub Actions ou abra a página de releases."
            "atualizado" -> "A versão instalada já é a mais recente publicada."
            else -> "Nenhum release com APK disponível para baixar."
        }

    private fun emitirProgresso(pct: Int, bytes: Long) {
        val destino = eventos ?: return
        activity.runOnUiThread {
            destino.success(mapOf("pct" to pct, "bytes" to bytes))
        }
    }

    private fun responder(visivel: Boolean, acao: () -> Unit) {
        if (visivel) activity.runOnUiThread(acao) else acao()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> {
                val info = infoInstalada()
                val arquivo = arquivoBaixado()
                result.success(
                    mapOf(
                        "versao" to versaoInstalada(info),
                        "versionCode" to codigoInstalado(info),
                        "pacote" to activity.packageName,
                        "repositorio" to REPOSITORIO,
                        "urlReleases" to URL_RELEASES,
                        "instaladorAutorizado" to podeInstalar(),
                        "baixado" to (arquivo.exists() && arquivo.length() > 0),
                        "baixadoBytes" to if (arquivo.exists()) arquivo.length() else 0L,
                    )
                )
            }

            "verificar" -> worker.execute {
                try {
                    val release = consultar()
                    responder(true) { result.success(release) }
                } catch (e: Exception) {
                    responder(true) {
                        result.error(
                            "consulta",
                            "Não consegui consultar as atualizações no GitHub: " + explicar(e) + ".",
                            null,
                        )
                    }
                }
            }

            "baixar" -> worker.execute {
                try {
                    val release = consultar()
                    if (release["disponivel"] != true) {
                        throw RuntimeException(motivoFalha(release))
                    }
                    val urlApk = release["urlApk"] as? String ?: throw RuntimeException("release sem APK")
                    val urlSha = (release["urlSha256"] as? String).orEmpty()
                    val digestoGithub = (release["digesto"] as? String).orEmpty()

                    val publicado = when {
                        urlSha.startsWith("https://") ->
                            hashPublicado(httpGetTexto(urlSha, MAX_SHA_BYTES))
                        digestoGithub.matches(Regex(HEX)) -> digestoGithub.lowercase(Locale.US)
                        else -> ""
                    }
                    if (publicado.isEmpty()) {
                        throw RuntimeException(
                            "o release não publica o SHA-256 do APK (arquivo .sha256 ausente ou ilegível); " +
                                "sem o digesto publicado nada é baixado"
                        )
                    }

                    val destino = arquivoBaixado()
                    var conexao: HttpURLConnection? = null
                    var entrada: InputStream? = null
                    var saida: FileOutputStream? = null
                    try {
                        conexao = URL(urlApk).openConnection() as HttpURLConnection
                        conexao.connectTimeout = TIMEOUT_MS
                        conexao.readTimeout = TIMEOUT_DOWNLOAD_MS
                        conexao.setRequestProperty("User-Agent", "JARVIS-Nova-Updater")
                        val codigo = conexao.responseCode
                        if (codigo < 200 || codigo >= 300) throw ErroHttp(codigo, "download")
                        val total = conexao.contentLengthLong
                        entrada = conexao.inputStream
                        saida = FileOutputStream(destino)
                        val sha = MessageDigest.getInstance("SHA-256")
                        val buffer = ByteArray(16384)
                        var lidos = 0L
                        var ultimoPasso = -1
                        while (true) {
                            val n = entrada.read(buffer)
                            if (n <= 0) break
                            lidos += n
                            if (lidos > MAX_APK_BYTES) {
                                throw RuntimeException("arquivo maior que o limite de segurança")
                            }
                            saida.write(buffer, 0, n)
                            sha.update(buffer, 0, n)
                            if (total > 0) {
                                val pct = (lidos * 100 / total).toInt()
                                if (pct / 5 != ultimoPasso / 5) {
                                    ultimoPasso = pct
                                    emitirProgresso(pct, lidos)
                                }
                            }
                        }
                        saida.flush()
                        saida.close()
                        saida = null
                        entrada.close()
                        entrada = null

                        val calculado = sha.digest().joinToString("") {
                            String.format(Locale.US, "%02x", it)
                        }
                        if (!calculado.equals(publicado, ignoreCase = true)) {
                            destino.delete()
                            throw RuntimeException(
                                "o SHA-256 do arquivo baixado não confere com o publicado " +
                                    "($calculado ≠ $publicado); o download foi descartado"
                            )
                        }
                        val resposta = mapOf(
                            "sha256" to calculado,
                            "bytes" to destino.length(),
                            "versao" to (release["versao"] ?: ""),
                            "nomeArquivo" to (release["nomeArquivo"] ?: destino.name),
                            "conferido" to true,
                        )
                        responder(true) { result.success(resposta) }
                    } catch (e: Exception) {
                        if (destino.exists()) destino.delete()
                        throw e
                    } finally {
                        try {
                            saida?.close()
                        } catch (ignorado: Exception) {
                        }
                        try {
                            entrada?.close()
                        } catch (ignorado: Exception) {
                        }
                        conexao?.disconnect()
                    }
                } catch (e: Exception) {
                    responder(true) {
                        result.error(
                            "download",
                            "Não consegui baixar a atualização: " + explicar(e) + ".",
                            null,
                        )
                    }
                }
            }

            "instalar" -> {
                val apk = arquivoBaixado()
                if (!apk.exists() || apk.length() < 1024) {
                    result.success(
                        mapOf(
                            "ok" to false,
                            "mensagem" to "Nenhuma atualização baixada ainda. Baixe e confira o SHA-256 antes de instalar.",
                        )
                    )
                    return
                }
                if (!podeInstalar()) {
                    try {
                        val permissao = Intent(
                            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:" + activity.packageName),
                        )
                        permissao.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        activity.startActivity(permissao)
                    } catch (ignorado: Exception) {
                    }
                    result.success(
                        mapOf(
                            "ok" to false,
                            "mensagem" to
                                "O Android exige autorizar a instalação por esta origem: a tela de permissão já abriu. Autorize e toque em Instalar de novo.",
                        )
                    )
                    return
                }
                try {
                    val uri = FileProvider.getUriForFile(
                        activity,
                        activity.packageName + ".fileprovider",
                        apk,
                    )
                    val instalar = Intent(Intent.ACTION_VIEW)
                    instalar.setDataAndType(uri, "application/vnd.android.package-archive")
                    instalar.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    instalar.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    try {
                        activity.startActivity(instalar)
                    } catch (semInstalador: android.content.ActivityNotFoundException) {
                        result.success(
                            mapOf(
                                "ok" to false,
                                "mensagem" to
                                    "Este aparelho não expôs um instalador de APK. Confira em Configurações → Apps se a instalação por esta origem está liberada.",
                            )
                        )
                        return
                    }
                    result.success(
                        mapOf(
                            "ok" to true,
                            "mensagem" to
                                "Instalador aberto. Confira a versão na tela do Android e toque em Instalar; ele mantém seus dados porque a assinatura é a mesma.",
                        )
                    )
                } catch (e: Exception) {
                    result.success(
                        mapOf(
                            "ok" to false,
                            "mensagem" to
                                "Não consegui abrir o instalador: " +
                                (e.message ?: "erro desconhecido") + ".",
                        )
                    )
                }
            }

            "abrirReleases" -> {
                try {
                    val abrir = Intent(Intent.ACTION_VIEW, Uri.parse(URL_RELEASES))
                    abrir.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    activity.startActivity(abrir)
                    result.success(true)
                } catch (e: Exception) {
                    result.error(
                        "navegador",
                        "Não consegui abrir o navegador: " + (e.message ?: "erro desconhecido"),
                        null,
                    )
                }
            }

            else -> result.notImplemented()
        }
    }

    fun encerrar() {
        eventos = null
        worker.shutdownNow()
    }
}
