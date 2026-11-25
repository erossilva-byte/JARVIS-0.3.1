package com.jarvis.nova

import android.Manifest
import android.app.Activity
import android.app.ActivityManager
import android.app.NotificationManager
import android.app.SearchManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.BatteryManager
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.Build
import android.os.StatFs
import android.os.SystemClock
import android.provider.ContactsContract
import android.provider.MediaStore
import android.provider.Settings
import android.telephony.SmsManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * Canal `com.jarvis.nova/aparelho`.
 *
 * Cada método faz uma coisa do aparelho e devolve o que realmente aconteceu.
 * Nenhum app de terceiro aceita enviar mensagem sem confirmação: o Jarvis abre
 * a conversa com o texto exato e informa isso na resposta. O SMS é o único envio
 * direto, e só depois da permissão explícita.
 */
class JarvisAparelho(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        const val CANAL = "com.jarvis.nova/aparelho"
        private const val PEDIDO_CONTATOS = 48201
        private const val PEDIDO_SMS = 48202
        private const val PEDIDO_TELEFONE = 48203
        private const val PEDIDO_MICROFONE = 48204
        private const val PEDIDO_LOCALIZACAO = 48205
        private const val PACOTE_SPOTIFY = "com.spotify.music"
    }

    private val pendentes = mutableMapOf<Int, Pair<MethodChannel.Result, String>>()

    fun registrar(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CANAL)
            .setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(status())
            "dispositivoInfo" -> result.success(dispositivoInfo())
            "abrirApp" -> result.success(
                abrirPacote(call.argument<String>("pacote")?.trim().orEmpty())
            )
            "agendarLembrete" -> result.success(
                JarvisAgenda.agendar(
                    activity,
                    call.argument<Number>("id")?.toInt() ?: -1,
                    call.argument<Number>("quando")?.toLong() ?: 0L,
                    call.argument<String>("titulo").orEmpty(),
                    call.argument<String>("texto").orEmpty(),
                    call.argument<Boolean>("repetirDiario") == true,
                    call.argument<String>("repeticao").orEmpty()
                )
            )
            "cancelarLembrete" -> {
                val id = call.argument<Number>("id")?.toInt() ?: -1
                if (id < 1) {
                    result.success(erro("Identificador de lembrete inválido."))
                } else {
                    JarvisAgenda.cancelar(activity, id)
                    result.success(ok("Lembrete cancelado."))
                }
            }
            "notificacoesAcesso" -> result.success(
                mapOf("ativo" to notificacoesAutorizadas())
            )
            "localizacaoEstado" -> result.success(JarvisLocalizacao.estado(activity))
            "localizacao" -> JarvisLocalizacao.obter(activity, result)
            "abrirAjustesNotificacoes" -> {
                val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                result.success(abrir(intent, "Abri o acesso a notificações; autorize o JARVIS Nova."))
            }
            "notificacoes" -> {
                val limite = (call.argument<Number>("limite")?.toInt() ?: 30).coerceIn(1, 80)
                result.success(mapOf(
                    "itens" to JarvisNotificacaoListener.lista().take(limite),
                    "acesso" to notificacoesAutorizadas()
                ))
            }
            "limparNotificacoes" -> {
                JarvisNotificacaoListener.limpar()
                result.success(ok("Leitura de notificações limpa."))
            }
            // Resposta direta na notificação, sem abrir o aplicativo.
            "responderNotificacao" -> result.success(
                JarvisNotificacaoListener.responder(
                    call.argument<String>("chave").orEmpty(),
                    call.argument<String>("texto").orEmpty(),
                    call.argument<String>("pacote")
                )
            )
            "appsMensagem" -> result.success(mapOf("ids" to appsInstalados()))
            // Abrir app já na ação: conversa, rascunho, busca, rota, câmera.
            "abrirComAcao" -> abrirComAcao(
                JarvisAbrirApp.Pedido(
                    app = call.argument<String>("app").orEmpty(),
                    acao = call.argument<String>("acao").orEmpty(),
                    alvo = call.argument<String>("alvo").orEmpty(),
                    texto = call.argument<String>("texto").orEmpty(),
                ),
                result
            )
            "enviarMensagem" -> enviarMensagem(
                call.argument<String>("app").orEmpty(),
                call.argument<String>("destino").orEmpty(),
                call.argument<String>("texto").orEmpty(),
                result
            )
            "buscarContatos" -> result.success(
                mapOf("itens" to buscarContatos(call.argument<String>("nome").orEmpty()))
            )
            "exportarContatos" -> result.success(exportarContatos())
            "compartilharArquivo" -> result.success(
                compartilharArquivo(call.argument<String>("caminho").orEmpty())
            )
            "ligar" -> ligar(call.argument<String>("destino").orEmpty(), result)
            "spotifyEstado" -> result.success(mapOf("estado" to estadoMidia()))
            "spotify" -> spotify(
                call.argument<String>("acao").orEmpty(),
                call.argument<String>("faixa").orEmpty(),
                call.argument<String>("uri").orEmpty(),
                result
            )
            "ativarEmSegundoPlano" -> result.success(ativarEmSegundoPlano())
            "pedirPermissao" -> pedirPermissao(
                call.argument<String>("recurso").orEmpty(), result
            )
            "abrirAjustes" -> result.success(
                abrirAjustes(call.argument<String>("ajuste").orEmpty())
            )
            else -> result.notImplemented()
        }
    }

    /* ---------------- Status ---------------- */

    @Suppress("DEPRECATION")
    private fun dispositivoInfo(): Map<String, Any> {
        val mapa = mutableMapOf<String, Any>()
        try {
            val am = activity.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val memoria = ActivityManager.MemoryInfo()
            am.getMemoryInfo(memoria)
            mapa["memoriaTotalMb"] = memoria.totalMem / (1024 * 1024)
            mapa["memoriaLivreMb"] = memoria.availMem / (1024 * 1024)
            mapa["memoriaBaixa"] = memoria.lowMemory
        } catch (_: Exception) { }
        try {
            val stat = StatFs(Environment.getDataDirectory().path)
            mapa["armazenamentoTotalGb"] =
                stat.blockCountLong * stat.blockSizeLong / 1073741824.0
            mapa["armazenamentoLivreGb"] =
                stat.availableBlocksLong * stat.blockSizeLong / 1073741824.0
        } catch (_: Exception) { }
        try {
            mapa["uptimeMin"] = SystemClock.elapsedRealtime() / 60000L
        } catch (_: Exception) { }
        try {
            val bateria = activity.registerReceiver(
                null, android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED)
            )
            if (bateria != null) {
                val nivel = bateria.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                val escala = bateria.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                if (nivel >= 0 && escala > 0) mapa["bateria"] = nivel * 100 / escala
                val carregando = bateria.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
                mapa["carregando"] = carregando == BatteryManager.BATTERY_STATUS_CHARGING ||
                    carregando == BatteryManager.BATTERY_STATUS_FULL
            }
        } catch (_: Exception) { }
        try {
            val cm = activity.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val caps = cm.activeNetwork?.let { cm.getNetworkCapabilities(it) }
            mapa["rede"] = when {
                caps == null -> "offline"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "movel"
                else -> "offline"
            }
        } catch (_: Exception) { }
        try {
            val pm = activity.packageManager
            val intencao = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
            val vistos = mutableSetOf<String>()
            val apps = mutableListOf<Map<String, String>>()
            for (info in pm.queryIntentActivities(intencao, 0)) {
                val pacote = info.activityInfo?.packageName ?: continue
                if (pacote == activity.packageName) continue
                if (!vistos.add(pacote)) continue
                val nome = try {
                    pm.getApplicationLabel(info.activityInfo.applicationInfo).toString()
                } catch (_: Exception) {
                    pacote
                }
                apps.add(mapOf("pacote" to pacote, "nome" to nome))
            }
            apps.sortBy { it["nome"]?.lowercase(Locale.ROOT) ?: "" }
            mapa["apps"] = apps.take(120)
        } catch (_: Exception) { }
        return mapa
    }

    private fun abrirPacote(pacote: String): Map<String, Any> {
        if (pacote.isBlank()) return erro("Diga qual app abrir.")
        return try {
            val intencao = activity.packageManager.getLaunchIntentForPackage(pacote)
                ?: return erro("O app $pacote não está instalado ou não tem tela inicial.")
            intencao.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            activity.startActivity(intencao)
            ok("App aberto.")
        } catch (e: Exception) {
            erro("Não consegui abrir o app: ${e.message ?: e.javaClass.simpleName}")
        }
    }

    private fun status(): Map<String, Any> {
        val mapa = mutableMapOf<String, Any>()
        try {
            val bateria = activity.registerReceiver(
                null, android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED)
            )
            if (bateria != null) {
                val nivel = bateria.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                val escala = bateria.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                if (nivel >= 0 && escala > 0) {
                    mapa["bateria"] = (nivel * 100 / escala)
                }
                val carregando = bateria.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
                mapa["carregando"] = carregando == BatteryManager.BATTERY_STATUS_CHARGING ||
                    carregando == BatteryManager.BATTERY_STATUS_FULL
            }
        } catch (_: Exception) { }
        try {
            val audio = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val maximo = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val atual = audio.getStreamVolume(AudioManager.STREAM_MUSIC)
            if (maximo > 0) mapa["volume"] = atual * 100 / maximo
            mapa["mudo"] = audio.ringerMode == AudioManager.RINGER_MODE_SILENT
            mapa["fones"] = audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS).any {
                val tipo = it.type
                tipo == AudioDeviceInfo.TYPE_WIRED_HEADPHONES ||
                    tipo == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
                    tipo == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                    tipo == AudioDeviceInfo.TYPE_USB_HEADSET
            }
        } catch (_: Exception) { }
        try {
            val brilho = Settings.System.getInt(
                activity.contentResolver, Settings.System.SCREEN_BRIGHTNESS, -1
            )
            if (brilho >= 0) mapa["brilho"] = brilho * 100 / 255
        } catch (_: Exception) { }
        try {
            val cm = activity.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val rede = cm.activeNetwork
            val caps = rede?.let { cm.getNetworkCapabilities(it) }
            mapa["rede"] = when {
                caps == null -> "sem conexão"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "Wi-Fi"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "dados móveis"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "cabo"
                else -> "outra"
            }
        } catch (_: Exception) { }
        try {
            val nm = activity.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            mapa["naoPerturbe"] = nm.isNotificationPolicyAccessGranted &&
                nm.currentInterruptionFilter != NotificationManager.INTERRUPTION_FILTER_ALL
        } catch (_: Exception) { }
        mapa["modelo"] = Build.MODEL.orEmpty()
        mapa["android"] = Build.VERSION.RELEASE.orEmpty()
        return mapa
    }

    /* ---------------- Notificações ---------------- */

    private fun notificacoesAutorizadas(): Boolean = try {
        val ativos = Settings.Secure.getString(
            activity.contentResolver, "enabled_notification_listeners"
        ).orEmpty()
        ativos.contains(activity.packageName)
    } catch (_: Exception) {
        false
    }

    /* ---------------- Mensagens ---------------- */

    private fun appsInstalados(): List<String> {
        val mapa = mapOf(
            "whatsapp" to "com.whatsapp",
            "whatsapp_business" to "com.whatsapp.w4b",
            "gmail" to "com.google.android.gm",
            "discord" to "com.discord",
            "instagram" to "com.instagram.android",
            "telegram" to "org.telegram.messenger",
            "messenger" to "com.facebook.orca",
            "signal" to "org.thoughtcrime.securesms",
        )
        val ids = mutableListOf("sms", "email")
        for ((id, pacote) in mapa) {
            try {
                activity.packageManager.getPackageInfo(pacote, 0)
                ids.add(id)
            } catch (_: PackageManager.NameNotFoundException) { }
        }
        return ids
    }

    private fun enviarMensagem(
        app: String, destino: String, texto: String, result: MethodChannel.Result
    ) {
        if (destino.isBlank() || texto.isBlank()) {
            result.success(erro("Informe o destinatário e o texto exato da mensagem."))
            return
        }
        try {
            when (app) {
                "sms" -> enviarSms(destino, texto, result)
                "whatsapp", "whatsapp_business" -> {
                    val numero = telefoneDe(destino)
                    val uri = if (numero.isNotBlank()) {
                        Uri.parse("https://wa.me/$numero?text=${Uri.encode(texto)}")
                    } else {
                        Uri.parse("whatsapp://send?text=${Uri.encode(texto)}")
                    }
                    val pacote = if (app == "whatsapp_business") "com.whatsapp.w4b" else "com.whatsapp"
                    val intent = Intent(Intent.ACTION_VIEW, uri).setPackage(pacote)
                    abrirConversa(intent, "WhatsApp", destino, texto, result, pacote)
                }
                "telegram" -> {
                    val usuario = destino.trim().removePrefix("@")
                    val uri = if (usuario.isNotBlank() && !usuario.any { it.isDigit() })
                        Uri.parse("https://t.me/$usuario") else
                        Uri.parse("https://t.me/share/url?url=${Uri.encode(texto)}")
                    abrirConversa(
                        Intent(Intent.ACTION_VIEW, uri), "Telegram", destino, texto, result,
                        "org.telegram.messenger"
                    )
                }
                "gmail" -> {
                    val endereco = emailDe(destino).ifBlank { if (destino.contains("@")) destino else "" }
                    val intent = Intent(Intent.ACTION_SENDTO).apply {
                        data = Uri.parse("mailto:$endereco")
                        putExtra(Intent.EXTRA_TEXT, texto)
                    }
                    abrirConversa(intent, "Gmail", destino, texto, result, "com.google.android.gm")
                }
                else -> {
                    val pacote = pacoteDoApp(app)
                    if (pacote.isBlank()) {
                        result.success(erro("Esse app de mensagem não está instalado."))
                        return
                    }
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, texto)
                        setPackage(pacote)
                    }
                    abrirConversa(intent, nomeDoApp(app), destino, texto, result)
                }
            }
        } catch (e: Exception) {
            result.success(erro("Não consegui abrir a mensagem: ${e.message ?: e.javaClass.simpleName}"))
        }
    }

    /**
     * Abre a conversa e, se o envio assistido estiver ligado, toca em Enviar
     * pelo serviço de acessibilidade. A resposta só volta depois de o toque
     * acontecer ou do prazo acabar — é ela que diz a verdade ao alto-falante.
     */
    private fun abrirConversa(
        intent: Intent, nome: String, destino: String, texto: String,
        result: MethodChannel.Result, pacote: String = ""
    ) {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val abriu = try {
            activity.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
        if (!abriu) {
            result.success(erro("$nome não aceitou abrir a conversa com esse destinatário."))
            return
        }
        Thread {
            val envio = JarvisEnvioSemToque.tentar(activity, pacote, texto)
            val mensagem = when {
                envio.enviado ->
                    "Mensagem enviada para $destino no $nome, sem toque."
                envio.tentou ->
                    "Abri o $nome para $destino com o texto exato. " +
                        JarvisEnvioSemToque.explicar(envio) + " Falta tocar em enviar."
                else ->
                    "Abri o $nome para $destino com o texto exato. " +
                        "Falta tocar em enviar — $nome não aceita envio silencioso."
            }
            Handler(Looper.getMainLooper()).post {
                result.success(mapOf(
                    "ok" to true,
                    "enviado" to envio.enviado,
                    "mensagem" to mensagem,
                    "texto" to texto,
                    "destino" to destino
                ))
            }
        }.start()
    }

    /** Abre o app de terceiro já na ação pedida, pelo link do próprio app. */
    private fun abrirComAcao(pedido: JarvisAbrirApp.Pedido, result: MethodChannel.Result) {
        if (pedido.app.isBlank() || pedido.acao.isBlank()) {
            result.success(erro("Faltou dizer qual app abrir e o que fazer nele."))
            return
        }
        val resposta = JarvisAbrirApp.executar(activity, pedido)
        result.success(mapOf(
            "ok" to resposta.ok,
            "mensagem" to resposta.mensagem,
            "acao" to resposta.acao
        ))
    }

    private fun enviarSms(destino: String, texto: String, result: MethodChannel.Result) {
        val numero = telefoneDe(destino).ifBlank { if (destino.any { it.isDigit() }) destino else "" }
        if (numero.isBlank()) {
            result.success(erro("Não achei um número de telefone para $destino."))
            return
        }
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.SEND_SMS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            pedir(Manifest.permission.SEND_SMS, PEDIDO_SMS, "sms", result)
            return
        }
        try {
            val gerenciador = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                activity.getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
            gerenciador.sendTextMessage(numero, null, texto, null, null)
            result.success(mapOf(
                "ok" to true,
                "mensagem" to "SMS enviado para $numero com o texto pedido."
            ))
        } catch (e: Exception) {
            result.success(erro("O SMS não saiu: ${e.message ?: e.javaClass.simpleName}"))
        }
    }

    private fun pacoteDoApp(app: String): String = when (app) {
        "whatsapp" -> "com.whatsapp"
        "whatsapp_business" -> "com.whatsapp.w4b"
        "gmail" -> "com.google.android.gm"
        "discord" -> "com.discord"
        "instagram" -> "com.instagram.android"
        "telegram" -> "org.telegram.messenger"
        "messenger" -> "com.facebook.orca"
        "signal" -> "org.thoughtcrime.securesms"
        else -> ""
    }

    private fun nomeDoApp(app: String): String = when (app) {
        "discord" -> "Discord"
        "instagram" -> "Instagram"
        "messenger" -> "Messenger"
        "signal" -> "Signal"
        else -> app
    }

    /* ---------------- Contatos ---------------- */

    private fun buscarContatos(nome: String): List<Map<String, Any>> {
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_CONTACTS) !=
            PackageManager.PERMISSION_GRANTED
        ) return emptyList()
        // Nome falado do jeito que ele é dito: apelido, emoji e letra repetida
        // já foram resolvidos por JarvisContatos antes do LIKE exato.
        val parecidos = JarvisContatos.buscar(activity, nome, 20)
        if (parecidos.isNotEmpty()) {
            return parecidos.map {
                mapOf(
                    "nome" to it.nome,
                    "telefones" to it.telefones,
                    "emails" to it.emails,
                )
            }
        }
        val lista = mutableListOf<Map<String, Any>>()
        val projecao = arrayOf(
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER,
            ContactsContract.CommonDataKinds.Phone.NORMALIZED_NUMBER
        )
        val selecao = if (nome.isBlank()) null
        else "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} LIKE ?"
        val argumentos = if (nome.isBlank()) null else arrayOf("%${nome.trim()}%")
        try {
            activity.contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                projecao, selecao, argumentos,
                "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC"
            )?.use { cursor ->
                val nomes = mutableMapOf<String, MutableList<String>>()
                while (cursor.moveToNext() && nomes.size < 20) {
                    val nomeContato = cursor.getString(0)?.trim().orEmpty()
                    if (nomeContato.isEmpty()) continue
                    val telefone = cursor.getString(1)?.trim().orEmpty()
                    val listaTelefones = nomes.getOrPut(nomeContato) { mutableListOf() }
                    if (telefone.isNotEmpty() && !listaTelefones.contains(telefone)) {
                        listaTelefones.add(telefone)
                    }
                }
                for ((n, telefones) in nomes) {
                    lista.add(mapOf("nome" to n, "telefones" to telefones))
                }
            }
        } catch (_: Exception) { }
        return lista
    }

    /**
     * Todos os contatos do aparelho em vCard 3.0, gravados em
     * `Android/data/<pacote>/files/exports`. Nada sai do telefone sem o usuário
     * escolher o app no compartilhamento.
     */
    private fun exportarContatos(): Map<String, Any> {
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_CONTACTS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return mapOf(
                "ok" to false,
                "mensagem" to "Sem permissão para ler os contatos. Autorize o acesso e tente de novo."
            )
        }
        val contatos = listarTodosContatos()
        if (contatos.isEmpty()) {
            return mapOf("ok" to false, "mensagem" to "Nenhum contato no aparelho para exportar.")
        }
        return try {
            val pasta = java.io.File(activity.getExternalFilesDir(null), "exports")
            pasta.mkdirs()
            val carimbo = java.text.SimpleDateFormat("yyyyMMdd-HHmm", java.util.Locale.US)
                .format(java.util.Date())
            val nome = "contatos-jarvis-$carimbo.vcf"
            val arquivo = java.io.File(pasta, nome)
            arquivo.writeText(montarVCard(contatos), Charsets.UTF_8)
            mapOf(
                "ok" to true,
                "quantidade" to contatos.size,
                "nome" to nome,
                "caminho" to arquivo.absolutePath,
                "bytes" to arquivo.length(),
                "mensagem" to "${contatos.size} contato(s) exportado(s)."
            )
        } catch (erro: Exception) {
            mapOf(
                "ok" to false,
                "mensagem" to "Não foi possível gravar o arquivo: ${erro.message ?: "erro"}"
            )
        }
    }

    /** Nomes com telefones e e-mails, sem duplicar o mesmo contato. */
    private fun listarTodosContatos(): List<Map<String, Any>> {
        val porNome = linkedMapOf<String, MutableMap<String, Any>>()
        fun registro(nome: String): MutableMap<String, Any> =
            porNome.getOrPut(nome) {
                mutableMapOf(
                    "nome" to nome,
                    "telefones" to mutableListOf<String>(),
                    "emails" to mutableListOf<String>()
                )
            }

        fun acrescentar(nome: String, chave: String, valor: String) {
            if (nome.isEmpty() || valor.isEmpty()) return
            val item = registro(nome)
            @Suppress("UNCHECKED_CAST")
            val lista = item[chave] as MutableList<String>
            if (!lista.contains(valor)) lista.add(valor)
        }

        try {
            activity.contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER
                ),
                null, null,
                "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC"
            )?.use { cursor ->
                while (cursor.moveToNext() && porNome.size < 2000) {
                    acrescentar(
                        cursor.getString(0)?.trim().orEmpty(),
                        "telefones",
                        cursor.getString(1)?.trim().orEmpty()
                    )
                }
            }
            activity.contentResolver.query(
                ContactsContract.CommonDataKinds.Email.CONTENT_URI,
                arrayOf(
                    ContactsContract.CommonDataKinds.Email.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Email.ADDRESS
                ),
                null, null, null
            )?.use { cursor ->
                while (cursor.moveToNext() && porNome.size < 2000) {
                    acrescentar(
                        cursor.getString(0)?.trim().orEmpty(),
                        "emails",
                        cursor.getString(1)?.trim().orEmpty()
                    )
                }
            }
        } catch (_: Exception) {
            // Devolve o que já foi lido em vez de fingir uma lista completa.
        }
        return porNome.values.toList()
    }

    /** vCard 3.0, com os caracteres que quebrariam o formato escapados. */
    private fun montarVCard(contatos: List<Map<String, Any>>): String {
        fun limpar(valor: String): String = valor
            .replace("\\", "\\\\")
            .replace("\n", " ")
            .replace("\r", " ")
            .replace(";", "\\;")
            .replace(",", "\\,")

        val texto = StringBuilder()
        for (contato in contatos) {
            val nome = limpar(contato["nome"]?.toString().orEmpty())
            if (nome.isEmpty()) continue
            texto.append("BEGIN:VCARD\r\n")
            texto.append("VERSION:3.0\r\n")
            texto.append("FN:").append(nome).append("\r\n")
            texto.append("N:").append(nome).append(";;;;\r\n")
            val telefones = contato["telefones"] as? List<*> ?: emptyList<Any>()
            for (telefone in telefones) {
                val numero = limpar(telefone?.toString().orEmpty())
                if (numero.isNotEmpty()) texto.append("TEL;TYPE=CELL:").append(numero).append("\r\n")
            }
            val emails = contato["emails"] as? List<*> ?: emptyList<Any>()
            for (email in emails) {
                val endereco = limpar(email?.toString().orEmpty())
                if (endereco.isNotEmpty()) texto.append("EMAIL;TYPE=OTHER:").append(endereco).append("\r\n")
            }
            texto.append("END:VCARD\r\n")
        }
        return texto.toString()
    }

    /** Abre a folha de compartilhamento com o .vcf exportado. */
    private fun compartilharArquivo(caminho: String): Map<String, Any> {
        val arquivo = java.io.File(caminho)
        if (!arquivo.isFile) {
            return mapOf("ok" to false, "mensagem" to "O arquivo exportado não foi encontrado.")
        }
        return try {
            val uri = androidx.core.content.FileProvider.getUriForFile(
                activity,
                "${activity.packageName}.fileprovider",
                arquivo
            )
            val envio = Intent(Intent.ACTION_SEND).apply {
                type = "text/x-vcard"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_SUBJECT, arquivo.name)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            activity.startActivity(Intent.createChooser(envio, "Compartilhar contatos"))
            mapOf("ok" to true, "mensagem" to "Escolha o app que vai receber os contatos.")
        } catch (erro: Exception) {
            mapOf(
                "ok" to false,
                "mensagem" to "O Android não abriu o compartilhamento: ${erro.message ?: "erro"}"
            )
        }
    }

    /** Telefone do contato entendendo apelido, emoji e erro de fala. */
    private fun telefoneDe(destino: String): String =
        JarvisContatos.resolver(activity, destino).contato?.primeiroTelefone.orEmpty()

    private fun emailDe(destino: String): String {
        if (destino.contains("@")) return destino.trim()
        return JarvisContatos.resolver(activity, destino).contato?.primeiroEmail.orEmpty()
    }

    private fun ligar(destino: String, result: MethodChannel.Result) {
        if (destino.isBlank()) {
            result.success(erro("Diga para quem ligar."))
            return
        }
        val numero = telefoneDe(destino)
        if (numero.isBlank()) {
            result.success(erro("Não achei o número de $destino nos contatos."))
            return
        }
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.CALL_PHONE) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            pedir(Manifest.permission.CALL_PHONE, PEDIDO_TELEFONE, "telefone", result)
            return
        }
        try {
            val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:${Uri.encode(numero)}"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            activity.startActivity(intent)
            result.success(mapOf(
                "ok" to true,
                "mensagem" to "Discando para $destino ($numero)."
            ))
        } catch (e: Exception) {
            result.success(erro("A ligação não começou: ${e.message ?: e.javaClass.simpleName}"))
        }
    }

    /* ---------------- Spotify e mídia ---------------- */

    private fun controladorSpotify(): MediaController? {
        val gerenciador = activity.getSystemService(Context.MEDIA_SESSION_SERVICE) as? MediaSessionManager
            ?: return null
        val componente = ComponentName(activity, JarvisNotificacaoListener::class.java)
        return try {
            val sessoes = gerenciador.getActiveSessions(componente)
            sessoes.firstOrNull { it.packageName.contains("spotify") }
                ?: sessoes.firstOrNull { it.playbackState?.state == PlaybackState.STATE_PLAYING }
        } catch (_: SecurityException) {
            null
        }
    }

    /**
     * Toca a faixa pedida pelo caminho que o Android oferece de verdade.
     *
     * Ordem: (1) URI exata pela sessão de mídia, quando o usuário deu um link
     * `spotify:track:…`; (2) `MEDIA_PLAY_FROM_SEARCH`, que é o canal oficial
     * para "tocar <faixa>" — o app de mídia escolhe o melhor resultado e
     * começa a tocar; (3) o link de busca, que só exibe a lista. Depois de
     * mandar, o Jarvis acompanha a sessão por até 8 s e só responde "tocando"
     * quando o título confere com o pedido.
     */
    private fun tocarFaixa(alvo: String, uri: String, result: MethodChannel.Result) {
        if (alvo.isBlank() && uri.isBlank()) {
            result.success(erro("Diga qual música tocar."))
            return
        }
        var enviouUri = false
        if (uri.isNotBlank()) {
            val controlador = controladorSpotify()
            if (controlador != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                try {
                    controlador.transportControls.playFromUri(Uri.parse(uri), null)
                    enviouUri = true
                } catch (_: Exception) { }
            }
            // O app também recebe o link: é ele quem enfileira a faixa exata.
            try {
                activity.startActivity(
                    Intent(Intent.ACTION_VIEW, Uri.parse(uri))
                        .setPackage(PACOTE_SPOTIFY)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            } catch (_: Exception) { }
        }

        val abriuBusca = tentarBuscaDeMidia(alvo)
        var abriuBuscaApp = false
        if (!abriuBusca && uri.isBlank() && alvo.isNotBlank()) {
            abriuBuscaApp = try {
                activity.startActivity(
                    Intent(
                        Intent.ACTION_VIEW,
                        Uri.parse("spotify:search:${Uri.encode(alvo)}")
                    ).setPackage(PACOTE_SPOTIFY)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                true
            } catch (_: Exception) {
                false
            }
        }

        val base = when {
            abriuBusca -> "Mandei o Spotify tocar \"$alvo\" pela busca de mídia do Android"
            enviouUri -> "Enviei a URI $uri à sessão do Spotify"
            abriuBuscaApp -> "O Spotify não aceitou a busca de mídia; abri a busca por \"$alvo\""
            else -> ""
        }
        if (base.isEmpty()) {
            result.success(erro("O Spotify não está instalado ou não aceitou o pedido."))
            return
        }
        verificarFaixa(alvo, base, result)
    }

    /** `Intent` de busca de mídia: o app de música escolhe e toca o resultado. */
    private fun tentarBuscaDeMidia(alvo: String): Boolean {
        if (alvo.isBlank()) return false
        val intent = Intent(MediaStore.INTENT_ACTION_MEDIA_PLAY_FROM_SEARCH).apply {
            setPackage(PACOTE_SPOTIFY)
            putExtra(SearchManager.QUERY, alvo)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            activity.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Acompanha a sessão de mídia por até 8 s e compara título/artista com o
     * pedido. Sem confirmação, a resposta diz o que está tocando de fato.
     */
    private fun verificarFaixa(
        alvo: String, base: String, result: MethodChannel.Result
    ) {
        Thread {
            var confirmada: Map<String, Any>? = null
            val limite = System.currentTimeMillis() + 8000
            while (System.currentTimeMillis() < limite) {
                val estado = estadoMidia()
                val titulo = estado["titulo"]?.toString().orEmpty()
                if (estado["tocando"] == true && titulo.isNotBlank() &&
                    (alvo.isBlank() ||
                        confereFaixa(alvo, titulo, estado["artista"]?.toString().orEmpty()))
                ) {
                    confirmada = estado
                    break
                }
                try { Thread.sleep(400) } catch (_: InterruptedException) { break }
            }
            val atual = estadoMidia()
            val resposta: Map<String, Any> = if (confirmada != null) {
                mapOf(
                    "ok" to true,
                    "mensagem" to "Tocando \"${confirmada["titulo"]}\" — " +
                        "${confirmada["artista"]}, no Spotify.",
                    "estado" to confirmada,
                    "titulo" to confirmada["titulo"].toString(),
                    "artista" to confirmada["artista"].toString(),
                )
            } else {
                val titulo = atual["titulo"]?.toString().orEmpty()
                val tocando = atual["tocando"] == true
                val detalhe = if (titulo.isBlank()) {
                    "nenhuma sessão de mídia do Spotify apareceu em 8 s"
                } else {
                    "o Spotify está ${if (tocando) "tocando" else "com pausa em"} \"$titulo\""
                }
                mapOf(
                    "ok" to false,
                    "mensagem" to "$base, mas $detalhe. O Android não permite enfileirar " +
                        "uma faixa arbitrária por fora do app: o app de música escolhe o " +
                        "melhor resultado da busca. Para a faixa exata, mande o link " +
                        "spotify:track:… que o Jarvis entrega a URI pela sessão.",
                    "estado" to atual,
                    "titulo" to titulo,
                )
            }
            activity.runOnUiThread { result.success(resposta) }
        }.start()
    }

    /** Mesma comparação do Dart: título, título contido ou todas as palavras. */
    private fun confereFaixa(pedido: String, titulo: String, artista: String): Boolean {
        val alvo = normalizarFaixa(pedido)
        val achado = normalizarFaixa(titulo)
        if (alvo.isEmpty() || achado.isEmpty()) return false
        if (achado == alvo || achado.contains(alvo) || alvo.contains(achado)) return true
        val conjunto = "$achado ${normalizarFaixa(artista)}"
        return alvo.split(" ").all { conjunto.contains(it) }
    }

    private fun normalizarFaixa(texto: String): String {
        val semAcento = java.text.Normalizer.normalize(texto, java.text.Normalizer.Form.NFD)
            .replace("\\p{M}+".toRegex(), "")
        return semAcento.lowercase(Locale.ROOT)
            .replace("[^a-z0-9]+".toRegex(), " ")
            .trim()
            .replace("\\s+".toRegex(), " ")
    }

    private fun estadoMidia(): Map<String, Any> {
        val controlador = controladorSpotify() ?: return mapOf(
            "tocando" to false,
            "disponivel" to false,
            "mensagem" to "Nenhuma sessão de mídia ativa. Abra o Spotify e toque algo uma vez."
        )
        val metadados = controlador.metadata
        val estado = controlador.playbackState
        return mapOf(
            "disponivel" to true,
            "tocando" to (estado?.state == PlaybackState.STATE_PLAYING),
            "titulo" to (metadados?.getString(android.media.MediaMetadata.METADATA_KEY_TITLE) ?: ""),
            "artista" to (metadados?.getString(android.media.MediaMetadata.METADATA_KEY_ARTIST) ?: ""),
            "posicao" to (estado?.position ?: 0L),
            "pacote" to controlador.packageName
        )
    }

    private fun spotify(
        acao: String, faixa: String, uri: String, result: MethodChannel.Result
    ) {
        if (acao == "tocar") {
            tocarFaixa(faixa.trim(), uri.trim(), result)
            return
        }
        val controlador = controladorSpotify()
        if (controlador == null) {
            result.success(erro(
                "Nenhuma sessão do Spotify ativa. Abra o app e toque uma música para o Jarvis controlar."
            ))
            return
        }
        try {
            val transporte = controlador.transportControls
            when (acao) {
                "pausar" -> transporte.pause()
                "continuar" -> transporte.play()
                "proxima" -> transporte.skipToNext()
                "anterior" -> transporte.skipToPrevious()
                "reiniciar" -> transporte.seekTo(0)
                else -> {
                    result.success(erro("Controle de música desconhecido: $acao"))
                    return
                }
            }
            val rotulo = when (acao) {
                "pausar" -> "Pausei o Spotify."
                "continuar" -> "Mandei continuar o Spotify."
                "proxima" -> "Avancei para a próxima música."
                "anterior" -> "Voltei para a música anterior."
                else -> "Reiniciei a música do começo."
            }
            result.success(mapOf("ok" to true, "mensagem" to rotulo, "estado" to estadoMidia()))
        } catch (e: Exception) {
            result.success(erro("O Spotify recusou o controle: ${e.message ?: e.javaClass.simpleName}"))
        }
    }

    /* ---------------- Segundo plano e permissões ---------------- */

    private fun ativarEmSegundoPlano(): Map<String, Any> {
        val detalhes = mutableListOf<String>()
        try {
            val abrir = activity.packageManager.getLaunchIntentForPackage(activity.packageName)
            if (abrir != null) {
                abrir.addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                )
                activity.startActivity(abrir)
                detalhes.add("tela do Jarvis trazida para a frente")
            }
        } catch (_: Exception) { }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                activity.setShowWhenLocked(true)
                activity.setTurnScreenOn(true)
                detalhes.add("tela acesa sobre o bloqueio")
            }
        } catch (_: Exception) { }
        try {
            if (ContextCompat.checkSelfPermission(activity, Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED
            ) {
                val servico = Intent(activity, KwsForegroundService::class.java).apply {
                    action = KwsForegroundService.ACTION_START
                }
                ContextCompat.startForegroundService(activity, servico)
                detalhes.add("microfone ativo pelo serviço em primeiro plano")
            } else {
                detalhes.add("microfone sem permissão")
            }
        } catch (_: Exception) { }
        return mapOf(
            "ok" to detalhes.contains("microfone ativo pelo serviço em primeiro plano"),
            "mensagem" to if (detalhes.isEmpty())
                "Não consegui trazer o Jarvis para a frente neste aparelho."
            else "Jarvis ativo: ${detalhes.joinToString(", ")}."
        )
    }

    private fun pedirPermissao(recurso: String, result: MethodChannel.Result) {
        when (recurso) {
            "contatos" -> pedir(Manifest.permission.READ_CONTACTS, PEDIDO_CONTATOS, recurso, result)
            "sms" -> pedir(Manifest.permission.SEND_SMS, PEDIDO_SMS, recurso, result)
            "telefone" -> pedir(Manifest.permission.CALL_PHONE, PEDIDO_TELEFONE, recurso, result)
            "microfone" -> pedir(Manifest.permission.RECORD_AUDIO, PEDIDO_MICROFONE, recurso, result)
            "notificacoes" -> result.success(
                abrirAjustes("notificacoes")
            )
            "localizacao" -> pedirVarias(
                arrayOf(JarvisLocalizacao.PERMISSAO_FINA, JarvisLocalizacao.PERMISSAO_GROSSA),
                PEDIDO_LOCALIZACAO,
                recurso,
                result
            )
            else -> result.success(erro("Permissão desconhecida: $recurso"))
        }
    }

    private fun pedirVarias(
        permissoes: Array<String>, codigo: Int, recurso: String, result: MethodChannel.Result
    ) {
        val todas = permissoes.all {
            ContextCompat.checkSelfPermission(activity, it) == PackageManager.PERMISSION_GRANTED
        }
        if (todas) {
            result.success(ok("A permissão de $recurso já estava concedida."))
            return
        }
        pendentes[codigo] = result to recurso
        activity.requestPermissions(permissoes, codigo)
    }

    private fun pedir(
        permissao: String, codigo: Int, recurso: String, result: MethodChannel.Result
    ) {
        if (ContextCompat.checkSelfPermission(activity, permissao) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(ok("A permissão de $recurso já estava concedida."))
            return
        }
        pendentes[codigo] = result to recurso
        activity.requestPermissions(arrayOf(permissao), codigo)
    }

    fun onRequestPermissionsResult(
        requestCode: Int, grantResults: IntArray
    ): Boolean {
        val pendente = pendentes.remove(requestCode) ?: return false
        val (result, recurso) = pendente
        val concedida = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        result.success(
            if (concedida) ok("Permissão de $recurso concedida.")
            else erro("Permissão de $recurso negada. Sem ela essa tarefa não roda.")
        )
        return true
    }

    private fun abrirAjustes(ajuste: String): Map<String, Any> {
        val intent = when (ajuste) {
            "notificacoes" -> Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
            "spotify" -> activity.packageManager.getLaunchIntentForPackage("com.spotify.music")
            "wifi" -> Intent(Settings.ACTION_WIFI_SETTINGS)
            "dados" -> Intent(Settings.ACTION_DATA_ROAMING_SETTINGS)
            "som" -> Intent(Settings.ACTION_SOUND_SETTINGS)
            "tela" -> Intent(Settings.ACTION_DISPLAY_SETTINGS)
            else -> Intent(Settings.ACTION_SETTINGS)
        }
        if (intent == null) {
            return erro("Esse ajuste não está disponível neste aparelho.")
        }
        return abrir(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK), "Abri o ajuste de $ajuste.")
    }

    private fun abrir(intent: Intent, mensagem: String): Map<String, Any> = try {
        activity.startActivity(intent)
        ok(mensagem)
    } catch (e: Exception) {
        erro("Não consegui abrir: ${e.message ?: e.javaClass.simpleName}")
    }

    private fun ok(mensagem: String) = mapOf("ok" to true, "mensagem" to mensagem)
    private fun erro(mensagem: String) = mapOf("ok" to false, "mensagem" to mensagem)
}
