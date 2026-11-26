package com.jarvis.nova

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.provider.AlarmClock
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Executa um conjunto fechado de ações do Android. Não recebe código, shell ou intents arbitrárias:
 * cada método do canal corresponde a uma ação do registro da Fase 10B e devolve o estado lido
 * depois da execução, para a interface não dizer "feito" sem conferir.
 */
class JarvisComandos(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CANAL = "com.jarvis.nova/comandos"
    }

    private val handler = Handler(Looper.getMainLooper())
    private val cameraManager by lazy {
        activity.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    }
    private var idLanterna: String? = null
    private var luzLigada = false
    private var pendenteLuz: Pair<Boolean, MethodChannel.Result>? = null

    fun registrar(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CANAL)
            .setMethodCallHandler(this)
        try {
            cameraManager.registerTorchCallback(object : CameraManager.TorchCallback() {
                override fun onTorchModeChanged(cameraId: String, enabled: Boolean) {
                    if (cameraId != idLanterna) return
                    luzLigada = enabled
                    val pendente = pendenteLuz ?: return
                    if (pendente.first == enabled) {
                        pendenteLuz = null
                        pendente.second.success(
                            mapOf(
                                "ligada" to enabled,
                                "mensagem" to if (enabled) "Lanterna ligada." else "Lanterna desligada."
                            )
                        )
                    }
                }

                override fun onTorchModeUnavailable(cameraId: String) {
                    if (cameraId != idLanterna) return
                    val pendente = pendenteLuz ?: return
                    pendenteLuz = null
                    pendente.second.error(
                        "lanterna_indisponivel",
                        "A lanterna está em uso por outro app ou indisponível agora.",
                        null
                    )
                }
            }, handler)
        } catch (_: Exception) {
            // Sem lanterna física o método responde o motivo quando for chamado.
        }
        idLanterna = try {
            cameraManager.cameraIdList.firstOrNull { id ->
                cameraManager.getCameraCharacteristics(id)
                    .get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
            }
        } catch (_: Exception) {
            null
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "lanterna" -> lanterna(call.argument<Boolean>("ligar"), result)
            "volume" -> volume(
                call.argument<String>("canal") ?: "musica",
                call.argument<Int>("percentual"),
                call.argument<Int>("delta"),
                result
            )
            "abrirApp" -> abrirApp(call.argument<String>("nome").orEmpty(), result)
            // "onde estou": a resposta sai quando o Android entrega um ponto.
            "localizacao" -> JarvisLocalizacao.obter(activity, result)
            "alarme" -> alarme(
                call.argument<Int>("hora") ?: -1,
                call.argument<Int>("minuto") ?: -1,
                result
            )
            "estado" -> result.success(
                mapOf(
                    "lanterna" to (idLanterna != null),
                    "ligada" to luzLigada,
                    "volume" to volumeAtual()
                )
            )
            else -> result.notImplemented()
        }
    }

    private fun lanterna(ligar: Boolean?, result: MethodChannel.Result) {
        val id = idLanterna
        if (id == null) {
            result.error("sem_lanterna", "Este aparelho não informou uma lanterna disponível.", null)
            return
        }
        if (pendenteLuz != null) {
            result.error("em_andamento", "Já existe um comando de lanterna em andamento.", null)
            return
        }
        val desejado = ligar ?: !luzLigada
        pendenteLuz = desejado to result
        try {
            cameraManager.setTorchMode(id, desejado)
        } catch (erro: Exception) {
            pendenteLuz = null
            result.error(
                "lanterna_falhou",
                "O Android recusou a lanterna: ${erro.message ?: erro.javaClass.simpleName}",
                null
            )
            return
        }
        // Alguns aparelhos não chamam o callback: confere o estado depois e falha com transparência.
        handler.postDelayed({
            val pendente = pendenteLuz ?: return@postDelayed
            pendenteLuz = null
            if (luzLigada == desejado) {
                pendente.second.success(
                    mapOf(
                        "ligada" to desejado,
                        "mensagem" to if (desejado) "Lanterna ligada." else "Lanterna desligada."
                    )
                )
            } else {
                pendente.second.error(
                    "nao_confirmado",
                    "O comando foi enviado, mas o Android não confirmou o estado da lanterna.",
                    null
                )
            }
        }, 900)
    }

    private fun canalDeAudio(nome: String): Int = when (nome) {
        "alarme" -> AudioManager.STREAM_ALARM
        "toque" -> AudioManager.STREAM_RING
        "notificacao" -> AudioManager.STREAM_NOTIFICATION
        else -> AudioManager.STREAM_MUSIC
    }

    private fun volumeAtual(): Map<String, Any> {
        val audio = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val canal = AudioManager.STREAM_MUSIC
        val atual = audio.getStreamVolume(canal)
        val maximo = audio.getStreamMaxVolume(canal).coerceAtLeast(1)
        return mapOf(
            "atual" to atual,
            "maximo" to maximo,
            "percentual" to (atual * 100.0 / maximo).roundToInt()
        )
    }

    private fun volume(
        nomeCanal: String,
        percentual: Int?,
        delta: Int?,
        result: MethodChannel.Result
    ) {
        val audio = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val canal = canalDeAudio(nomeCanal)
        val maximo = audio.getStreamMaxVolume(canal).coerceAtLeast(1)
        val atual = audio.getStreamVolume(canal)
        val alvo = when {
            percentual != null -> (percentual.coerceIn(0, 100) * maximo / 100.0).roundToInt()
            delta != null -> (atual + delta * maximo / 100.0).roundToInt().coerceIn(0, maximo)
            else -> atual
        }
        if (percentual == null && delta == null) {
            result.error("sem_valor", "Informe o percentual ou o ajuste de volume.", null)
            return
        }
        try {
            audio.setStreamVolume(canal, alvo, 0)
        } catch (erro: Exception) {
            result.error(
                "volume_falhou",
                "O Android recusou alterar o volume: ${erro.message ?: erro.javaClass.simpleName}",
                null
            )
            return
        }
        val lido = audio.getStreamVolume(canal)
        if (abs(lido - alvo) > 1) {
            result.error(
                "nao_confirmado",
                "O volume pedido era $alvo, mas o Android informou $lido.",
                null
            )
            return
        }
        val lidoPercentual = (lido * 100.0 / maximo).roundToInt()
        result.success(
            mapOf(
                "percentual" to lidoPercentual,
                "atual" to lido,
                "maximo" to maximo,
                "mensagem" to "Volume de mídia em $lidoPercentual%."
            )
        )
    }

    /** Apelidos de fala → pacote, para abrir mesmo quando o rótulo é outro. */
    private val pacotesConhecidos = mapOf(
        "zap" to "com.whatsapp",
        "whats" to "com.whatsapp",
        "whatsapp" to "com.whatsapp",
        "wpp" to "com.whatsapp",
        "whatsapp business" to "com.whatsapp.w4b",
        "wpp business" to "com.whatsapp.w4b",
        "insta" to "com.instagram.android",
        "instagram" to "com.instagram.android",
        "telegram" to "org.telegram.messenger",
        "youtube" to "com.google.android.youtube",
        "you tube" to "com.google.android.youtube",
        "spotify" to "com.spotify.music",
        "gmail" to "com.google.android.gm",
        "maps" to "com.google.android.apps.maps",
        "mapa" to "com.google.android.apps.maps",
        "mapas" to "com.google.android.apps.maps",
        "facebook" to "com.facebook.katana",
        "face" to "com.facebook.katana",
        "messenger" to "com.facebook.orca",
        "discord" to "com.discord",
        "signal" to "org.thoughtcrime.securesms",
        "ifood" to "br.com.brainweb.ifood",
        "uber" to "com.ubercab",
        "waze" to "com.waze",
    )

    private fun semAcento(texto: String): String {
        val de = "áàâãäéèêëíìîïóòôõöúùûüç"
        val para = "aaaaaeeeeiiiiooooouuuuc"
        val saida = StringBuilder()
        for (c in texto.lowercase()) {
            val i = de.indexOf(c)
            saida.append(if (i < 0) c else para[i])
        }
        return saida.toString().trim()
    }

    private fun abrirApp(nome: String, result: MethodChannel.Result) {
        val termo = semAcento(nome)
        if (termo.isEmpty()) {
            result.error("sem_app", "Diga o nome do app que devo abrir.", null)
            return
        }
        // Apelido conhecido tem prioridade: "abre o zap" não depende do rótulo.
        val porApelido = pacotesConhecidos[termo]
        if (porApelido != null) {
            val abertura = try {
                activity.packageManager.getLaunchIntentForPackage(porApelido)
            } catch (_: Exception) {
                null
            }
            if (abertura != null) {
                abertura.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                return try {
                    activity.startActivity(abertura)
                    result.success(
                        mapOf(
                            "ambiguo" to false,
                            "app" to nome,
                            "pacote" to porApelido,
                            "mensagem" to "Abertura de $nome enviada ao Android."
                        )
                    )
                } catch (erro: Exception) {
                    result.error(
                        "app_falhou",
                        "O Android recusou abrir \"$nome\": ${erro.message ?: erro.javaClass.simpleName}",
                        null
                    )
                }
            }
        }
        val consulta = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val apps = try {
            activity.packageManager.queryIntentActivities(consulta, 0).mapNotNull { info ->
                val rotulo = info.loadLabel(activity.packageManager)?.toString().orEmpty()
                val pacote = info.activityInfo?.packageName.orEmpty()
                if (rotulo.isBlank() || pacote.isBlank()) null
                else mapOf("rotulo" to rotulo, "pacote" to pacote)
            }.distinctBy { it["pacote"] }
        } catch (_: Exception) {
            emptyList()
        }
        val exatos = apps.filter {
            semAcento(it["rotulo"].toString()) == termo ||
                it["pacote"].toString().lowercase() == termo
        }
        val encontrados = if (exatos.isNotEmpty()) {
            exatos
        } else {
            // Rótulo que começa pelo termo vem antes de rótulo que só o contém:
            // "whatsapp" não deve perder para "WhatsApp Business" nem para
            // um app cujo nome apenas cite a palavra.
            val comecam = apps.filter { semAcento(it["rotulo"].toString()).startsWith(termo) }
            val contem = apps.filter { semAcento(it["rotulo"].toString()).contains(termo) }
            (comecam + contem).distinctBy { it["pacote"] }
        }
        if (encontrados.isEmpty()) {
            result.error("app_nao_encontrado", "Nenhum app instalado corresponde a \"$nome\".", null)
            return
        }
        if (encontrados.size > 1) {
            result.success(
                mapOf(
                    "ambiguo" to true,
                    "opcoes" to encontrados.take(6).map { it["rotulo"].toString() },
                    "mensagem" to "Encontrei mais de um app: ${
                        encontrados.take(6).joinToString(", ") { it["rotulo"].toString() }
                    }. Diga o nome completo."
                )
            )
            return
        }
        val escolhido = encontrados.first()
        val pacote = escolhido["pacote"].toString()
        val rotulo = escolhido["rotulo"].toString()
        val abertura = activity.packageManager.getLaunchIntentForPackage(pacote)
        if (abertura == null) {
            result.error("app_sem_abertura", "\"$rotulo\" está instalado, mas não abre uma tela.", null)
            return
        }
        abertura.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            activity.startActivity(abertura)
        } catch (erro: Exception) {
            result.error(
                "app_falhou",
                "O Android recusou abrir \"$rotulo\": ${erro.message ?: erro.javaClass.simpleName}",
                null
            )
            return
        }
        result.success(
            mapOf(
                "ambiguo" to false,
                "app" to rotulo,
                "pacote" to pacote,
                "mensagem" to "Abertura de $rotulo enviada ao Android."
            )
        )
    }

    private fun alarme(hora: Int, minuto: Int, result: MethodChannel.Result) {
        if (hora !in 0..23 || minuto !in 0..59) {
            result.error("horario_invalido", "Informe um horário entre 00:00 e 23:59.", null)
            return
        }
        // Abre o relógio com o horário já preenchido e deixa a confirmação para
        // a pessoa (EXTRA_SKIP_UI = false): criar alarme sem confirmação é uma
        // ação que o app não toma sozinho. O que faltava antes era a permissão
        // com.android.alarm.permission.SET_ALARM no manifesto — sem ela o Android
        // responde "Permission Denial" e nem a tela abria.
        val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
            putExtra(AlarmClock.EXTRA_HOUR, hora)
            putExtra(AlarmClock.EXTRA_MINUTES, minuto)
            putExtra(AlarmClock.EXTRA_SKIP_UI, false)
            putExtra(AlarmClock.EXTRA_MESSAGE, "J.A.R.V.I.S.")
        }
        if (intent.resolveActivity(activity.packageManager) == null) {
            result.error("sem_relogio", "Este aparelho não tem um app de relógio que aceite alarmes.", null)
            return
        }
        try {
            activity.startActivity(intent)
        } catch (erro: SecurityException) {
            // Sem a permissão de alarme o sistema recusa; a mensagem diz o motivo.
            result.error(
                "sem_permissao_alarme",
                "O Android recusou abrir o alarme por falta da permissão de alarme. " +
                    "Reinstale a versão atual do app e tente de novo.",
                null
            )
            return
        } catch (erro: Exception) {
            result.error(
                "alarme_falhou",
                "O Android recusou abrir o alarme: ${erro.message ?: erro.javaClass.simpleName}",
                null
            )
            return
        }
        val formatado = "%02d:%02d".format(hora, minuto)
        result.success(
            mapOf(
                "mensagem" to "Abri o relógio em $formatado. Confirme na tela para criar o alarme.",
                "hora" to hora,
                "minuto" to minuto,
                "criado" to false
            )
        )
    }
}
