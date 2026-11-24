package com.jarvis.nova

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.provider.AlarmClock
import android.provider.Settings
import java.util.Calendar
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Comandos executados sem abrir a tela do JARVIS.
 *
 * O interpretador é um conjunto fechado (abrir app, lanterna, volume, alarme,
 * hora, data, música e núcleo flutuante). Nada aqui recebe código, shell ou
 * intent arbitrária: o texto reconhecido é comparado com regras fixas e cada
 * ação é conferida depois de executada.
 *
 * Abrir outro app a partir do segundo plano é bloqueado pelo Android desde a
 * versão 10, exceto quando o app tem "Exibir sobre outros apps" autorizado. Por
 * isso a checagem de [podeAbrirApps] vem antes de qualquer `startActivity` e a
 * recusa é dita ao usuário, em vez de falhar em silêncio.
 */
object JarvisFundo {
    const val PREFS = "jarvis_fundo"
    const val CHAVE_MODO_SEM_TELA = "modo_sem_tela"
    const val CHAVE_ULTIMA_ACAO = "ultima_acao"
    const val CHAVE_ULTIMO_RESULTADO = "ultimo_resultado"
    const val CHAVE_ULTIMO_OK = "ultimo_ok"
    const val CHAVE_ULTIMO_EM = "ultimo_em"
    const val CHAVE_HISTORICO = "historico_acoes"

    /** Registros guardados no aparelho; o mais antigo sai quando o limite é atingido. */
    const val LIMITE_HISTORICO = 100

    const val ORIGEM_VOZ = "voz"
    const val ORIGEM_SEGUNDO_PLANO = "segundo_plano"
    const val ORIGEM_DIGITADO = "digitado"
    const val ORIGEM_TESTE = "teste"

    enum class Tipo {
        ABRIR_APP, LANTERNA, VOLUME, ALARME, HORA, DATA, MIDIA, NUCLEO, DESCONHECIDO
    }

    /** Controles de música enviados ao app que estiver tocando. */
    enum class AcaoMidia { PAUSAR, CONTINUAR, PROXIMA, ANTERIOR }

    data class Comando(
        val tipo: Tipo,
        val nome: String = "",
        val ligar: Boolean? = null,
        val percentual: Int? = null,
        val delta: Int? = null,
        val hora: Int = -1,
        val minuto: Int = -1,
        val acaoMidia: AcaoMidia = AcaoMidia.PAUSAR,
    ) {
        /** Texto curto para o histórico e para o aviso na tela. */
        fun resumo(): String = when (tipo) {
            Tipo.ABRIR_APP -> "abrir app $nome"
            Tipo.LANTERNA -> when (ligar) {
                true -> "ligar a lanterna"
                false -> "desligar a lanterna"
                null -> "alternar a lanterna"
            }
            Tipo.VOLUME -> percentual?.let { "volume em $it%" }
                ?: "ajustar o volume em ${delta ?: 0}%"
            Tipo.ALARME -> "alarme para %02d:%02d".format(hora, minuto)
            Tipo.HORA -> "informar as horas"
            Tipo.DATA -> "informar a data de hoje"
            Tipo.MIDIA -> when (acaoMidia) {
                AcaoMidia.PAUSAR -> "pausar a música"
                AcaoMidia.CONTINUAR -> "continuar a música"
                AcaoMidia.PROXIMA -> "passar para a próxima música"
                AcaoMidia.ANTERIOR -> "voltar para a música anterior"
            }
            Tipo.NUCLEO -> if (ligar == false) "desativar o núcleo" else "ativar o núcleo"
            Tipo.DESCONHECIDO -> "pergunta livre"
        }
    }

    data class Resultado(
        val ok: Boolean,
        val mensagem: String,
        val ambiguidade: List<String> = emptyList(),
    )

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** Quando ligado, a palavra de ativação não abre o app: o serviço executa o comando. */
    fun modoSemTela(context: Context): Boolean =
        prefs(context).getBoolean(CHAVE_MODO_SEM_TELA, false)

    fun definirModoSemTela(context: Context, ativo: Boolean) {
        prefs(context).edit().putBoolean(CHAVE_MODO_SEM_TELA, ativo).apply()
    }

    /**
     * Autorização de "Exibir sobre outros apps". É a exceção documentada pelo
     * Android para abrir uma tela a partir do segundo plano; sem ela, abrir apps
     * seria bloqueado pelo sistema.
     */
    fun podeAbrirApps(context: Context): Boolean = try {
        Settings.canDrawOverlays(context)
    } catch (_: Exception) {
        false
    }

    /**
     * Guarda a última ação (usada pela tela de segundo plano) e acrescenta o registro
     * completo ao histórico, com horário, o que foi pedido e o resultado real.
     */
    fun registrar(
        context: Context,
        comando: Comando,
        resultado: Resultado,
        origem: String = ORIGEM_SEGUNDO_PLANO,
        pedido: String = "",
    ) {
        prefs(context).edit()
            .putString(CHAVE_ULTIMA_ACAO, comando.resumo())
            .putString(CHAVE_ULTIMO_RESULTADO, resultado.mensagem)
            .putBoolean(CHAVE_ULTIMO_OK, resultado.ok)
            .putLong(CHAVE_ULTIMO_EM, System.currentTimeMillis())
            .apply()
        anotar(
            context,
            origem = origem,
            pedido = pedido.ifBlank { comando.resumo() },
            acao = comando.resumo(),
            ok = resultado.ok,
            mensagem = resultado.mensagem,
        )
    }

    /** Registro vindo do Flutter (comando executado com a tela aberta). */
    fun registrarHistorico(
        context: Context,
        origem: String,
        pedido: String,
        acao: String,
        ok: Boolean,
        mensagem: String,
    ) = anotar(context, origem, pedido, acao, ok, mensagem)

    private fun anotar(
        context: Context,
        origem: String,
        pedido: String,
        acao: String,
        ok: Boolean,
        mensagem: String,
    ) {
        val prefs = prefs(context)
        val anterior = try {
            JSONArray(prefs.getString(CHAVE_HISTORICO, "[]") ?: "[]")
        } catch (_: Exception) {
            JSONArray()
        }
        val registro = JSONObject().apply {
            put("em", System.currentTimeMillis())
            put("origem", origem.take(24))
            put("pedido", pedido.trim().take(300))
            put("acao", acao.trim().take(160))
            put("ok", ok)
            put("mensagem", mensagem.trim().take(600))
        }
        val proximo = JSONArray()
        proximo.put(registro)
        var i = 0
        // Mais recente primeiro; o excedente antigo é descartado.
        while (i < anterior.length() && proximo.length() < LIMITE_HISTORICO) {
            proximo.put(anterior.get(i))
            i++
        }
        prefs.edit().putString(CHAVE_HISTORICO, proximo.toString()).apply()
    }

    /** Histórico do que foi executado, do mais recente para o mais antigo. */
    fun historico(context: Context): List<Map<String, Any>> {
        val bruto = try {
            JSONArray(prefs(context).getString(CHAVE_HISTORICO, "[]") ?: "[]")
        } catch (_: Exception) {
            return emptyList()
        }
        val lista = mutableListOf<Map<String, Any>>()
        for (i in 0 until bruto.length()) {
            val item = bruto.optJSONObject(i) ?: continue
            val em = item.optLong("em", 0L)
            val pedido = item.optString("pedido", "").trim()
            if (em <= 0L || pedido.isEmpty()) continue
            lista.add(
                mapOf(
                    "em" to em,
                    "origem" to item.optString("origem", ORIGEM_VOZ),
                    "pedido" to pedido,
                    "acao" to item.optString("acao", ""),
                    "ok" to item.optBoolean("ok", false),
                    "mensagem" to item.optString("mensagem", ""),
                )
            )
        }
        return lista
    }

    fun limparHistorico(context: Context) {
        prefs(context).edit()
            .remove(CHAVE_ULTIMA_ACAO)
            .remove(CHAVE_ULTIMO_RESULTADO)
            .remove(CHAVE_ULTIMO_OK)
            .remove(CHAVE_ULTIMO_EM)
            .remove(CHAVE_HISTORICO)
            .apply()
    }

    fun estado(context: Context): Map<String, Any> {
        val p = prefs(context)
        return mapOf(
            "modoSemTela" to modoSemTela(context),
            "podeAbrirApps" to podeAbrirApps(context),
            "servicoAtivo" to KwsForegroundService.isServiceRunning(),
            "ouvindo" to KwsForegroundService.isListening(),
            "ultimaAcao" to (p.getString(CHAVE_ULTIMA_ACAO, "") ?: ""),
            "ultimoResultado" to (p.getString(CHAVE_ULTIMO_RESULTADO, "") ?: ""),
            "ultimoOk" to p.getBoolean(CHAVE_ULTIMO_OK, false),
            "ultimoEm" to p.getLong(CHAVE_ULTIMO_EM, 0L),
        )
    }

    // ------------------------------------------------------------------ texto

    private fun semAcento(texto: String): String {
        val de = "áàâãäéèêëíìîïóòôõöúùûüç"
        val para = "aaaaaeeeeiiiiooooouuuuc"
        val saida = StringBuilder()
        for (c in texto.lowercase()) {
            val indice = de.indexOf(c)
            saida.append(if (indice < 0) c else para[indice])
        }
        return saida.toString()
    }

    private fun limpar(texto: String): String =
        semAcento(texto).replace(Regex("\\s+"), " ").trim()

    private val ALARME =
        Regex("\\b(?:alarme|despertador)\\b.*?\\b(\\d{1,2})\\s*(?::|h)\\s*(\\d{2})\\b")
    private val VOLUME_NUMERO = Regex("\\bvolume\\b.*?\\b(\\d{1,3})\\s*%?")
    private val VOLUME_PORCENTO = Regex("\\b(\\d{1,3})\\s*%\\s*(?:de\\s+)?volume\\b")
    private val ABRIR = Regex(
        "^(?:abrir|abre|iniciar|executar)\\s+(?:o\\s+|a\\s+|os\\s+|as\\s+)?(?:app\\s+(?:do\\s+|da\\s+)?)?(.+)$"
    )
    private val LIGAR = Regex("\\b(ligar|liga|ligue|acender|acende|acenda|ativar|ativa|ative)\\b")
    private val DESLIGAR =
        Regex("\\b(desligar|desliga|desligue|apagar|apaga|apague|desativar|desativa|desative)\\b")
    private val AUMENTAR = Regex("\\b(aumentar|aumenta|aumente|subir|sobe|suba)\\b.*\\bvolume\\b")
    private val HORAS = Regex(
        "\\b(?:que|quantas)\\s+horas\\b|\\bhoras\\s+(?:sao|agora)\\b|\\bhora\\s+agora\\b|^horas$"
    )
    private val DATA = Regex(
        "\\b(?:que|qual)\\s+dia\\b|\\bdata\\s+de\\s+hoje\\b|\\bqual\\s+(?:e\\s+)?a\\s+data\\b|"
            + "\\bdia\\s+da\\s+semana\\b|^data$"
    )
    private val DIMINUIR =
        Regex("\\b(diminuir|diminui|diminua|baixar|baixa|abaixar|abaixa|abaixe)\\b.*\\bvolume\\b")
    private val NUCLEO = Regex("\\bnucleo\\b")
    private val NUCLEO_LIGAR = Regex(
        "\\b(ativar|ativa|ative|ligar|liga|ligue|abrir|abre|abra|mostrar|mostra|" +
            "mostre|chamar|chama|chame|aparecer|aparece)\\b"
    )
    private val MIDIA_PAUSAR =
        Regex("\\b(pausa|pausar|pause|para a musica|parar a musica)\\b")
    private val MIDIA_CONTINUAR =
        Regex("\\b(continua|continuar|retoma|retomar|despausa|volta a tocar)\\b")
    private val MIDIA_PROXIMA =
        Regex("\\b(proxima|proximo|avanca|avancar|pula|pular|passa a musica)\\b")
    private val MIDIA_ANTERIOR =
        Regex("\\b(anterior|volta a musica|voltar a musica|volta uma)\\b")
    private val FALA_DE_MUSICA =
        Regex("\\b(musica|spotify|faixa|som|playlist|album|tocando|tocar)\\b")

    /** Decide o que foi pedido. Texto vazio ou fora do registro vira [Tipo.DESCONHECIDO]. */
    fun interpretar(frase: String): Comando {
        val limpo = limpar(frase)
        if (limpo.isEmpty()) return Comando(Tipo.DESCONHECIDO)

        ALARME.find(limpo)?.let { achado ->
            val hora = achado.groupValues[1].toIntOrNull() ?: -1
            val minuto = achado.groupValues[2].toIntOrNull() ?: -1
            if (hora in 0..23 && minuto in 0..59) {
                return Comando(Tipo.ALARME, hora = hora, minuto = minuto)
            }
        }

        // Hora e data são perguntas do dia a dia: respondidas no aparelho, sem
        // provedor e sem demora, tanto com o app aberto quanto em segundo plano.
        if (HORAS.containsMatchIn(limpo) && !limpo.contains("por que")) {
            return Comando(Tipo.HORA)
        }
        if (DATA.containsMatchIn(limpo) && !limpo.contains("por que")) {
            return Comando(Tipo.DATA)
        }

        if (Regex("\\blanterna\\b").containsMatchIn(limpo) &&
            !limpo.contains("como ") && !limpo.contains("por que")
        ) {
            if (DESLIGAR.containsMatchIn(limpo)) return Comando(Tipo.LANTERNA, ligar = false)
            if (LIGAR.containsMatchIn(limpo)) return Comando(Tipo.LANTERNA, ligar = true)
            if (Regex("^(a |minha )?lanterna$").matches(limpo)) return Comando(Tipo.LANTERNA)
        }

        val numero = VOLUME_NUMERO.find(limpo) ?: VOLUME_PORCENTO.find(limpo)
        if (numero != null) {
            val valor = numero.groupValues[1].toIntOrNull() ?: -1
            if (valor in 0..100) return Comando(Tipo.VOLUME, percentual = valor)
        }
        if (!limpo.contains("como ") && !limpo.contains("por que")) {
            if (AUMENTAR.containsMatchIn(limpo)) return Comando(Tipo.VOLUME, delta = 10)
            if (DIMINUIR.containsMatchIn(limpo)) return Comando(Tipo.VOLUME, delta = -10)
            if (Regex("\\b(silenciar|mudo|mutar)\\b").containsMatchIn(limpo) && limpo.length <= 24) {
                return Comando(Tipo.VOLUME, percentual = 0)
            }
        }

        // Núcleo flutuante antes de abrir app: “abrir o núcleo” não é um app.
        if (NUCLEO.containsMatchIn(limpo) &&
            !limpo.contains("como ") && !limpo.contains("por que")
        ) {
            if (DESLIGAR.containsMatchIn(limpo)) return Comando(Tipo.NUCLEO, ligar = false)
            if (NUCLEO_LIGAR.containsMatchIn(limpo)) return Comando(Tipo.NUCLEO, ligar = true)
            if (Regex("^(o |meu )?nucleo( flutuante)?$").matches(limpo)) {
                return Comando(Tipo.NUCLEO, ligar = true)
            }
        }

        // Música: o app que estiver tocando é quem recebe os controles.
        val falaDeMusica = FALA_DE_MUSICA.containsMatchIn(limpo)
        if (MIDIA_PAUSAR.containsMatchIn(limpo) && (falaDeMusica || limpo.length <= 16)) {
            return Comando(Tipo.MIDIA, acaoMidia = AcaoMidia.PAUSAR)
        }
        if (MIDIA_CONTINUAR.containsMatchIn(limpo) && (falaDeMusica || limpo.length <= 16)) {
            return Comando(Tipo.MIDIA, acaoMidia = AcaoMidia.CONTINUAR)
        }
        if (MIDIA_PROXIMA.containsMatchIn(limpo) && (falaDeMusica || limpo.length <= 16)) {
            return Comando(Tipo.MIDIA, acaoMidia = AcaoMidia.PROXIMA)
        }
        if (MIDIA_ANTERIOR.containsMatchIn(limpo)) {
            return Comando(Tipo.MIDIA, acaoMidia = AcaoMidia.ANTERIOR)
        }

        ABRIR.find(limpo)?.let { achado ->
            val nome = achado.groupValues[1].trim()
            if (nome.isNotEmpty()) {
                val proibidos = listOf(
                    "arquivo", "pasta", "conversa", "memoria", "configuracoes", "ajustes", "cad"
                )
                val bloqueado = proibidos.any { nome == it || nome.startsWith("$it ") }
                if (!bloqueado) return Comando(Tipo.ABRIR_APP, nome = nome)
            }
        }
        return Comando(Tipo.DESCONHECIDO)
    }

    // ------------------------------------------------------------------ ações

    fun executar(context: Context, comando: Comando): Resultado = when (comando.tipo) {
        Tipo.ABRIR_APP -> abrirApp(context, comando.nome)
        Tipo.LANTERNA -> lanterna(context, comando.ligar)
        Tipo.VOLUME -> volume(context, comando.percentual, comando.delta)
        Tipo.ALARME -> alarme(context, comando.hora, comando.minuto)
        Tipo.HORA -> Resultado(true, horaFalada())
        Tipo.DATA -> Resultado(true, dataFalada())
        Tipo.MIDIA -> midia(context, comando.acaoMidia)
        Tipo.NUCLEO -> nucleo(context, comando.ligar)
        // Pergunta livre: quem chama (o serviço) envia o texto ao provedor de IA.
        Tipo.DESCONHECIDO -> Resultado(
            false,
            "Não reconheci esse pedido como comando do aparelho."
        )
    }

    private val DIAS = arrayOf(
        "domingo", "segunda-feira", "terça-feira", "quarta-feira",
        "quinta-feira", "sexta-feira", "sábado"
    )
    private val MESES = arrayOf(
        "janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho",
        "agosto", "setembro", "outubro", "novembro", "dezembro"
    )

    /** Hora atual em frase falável: os dois-pontos não são lidos em voz alta. */
    fun horaFalada(agora: Calendar = Calendar.getInstance()): String {
        val hora = agora.get(Calendar.HOUR_OF_DAY)
        val minuto = agora.get(Calendar.MINUTE)
        return if (minuto == 0) "Agora são $hora horas em ponto."
        else "Agora são $hora horas e $minuto minutos."
    }

    fun dataFalada(agora: Calendar = Calendar.getInstance()): String {
        val dia = DIAS[(agora.get(Calendar.DAY_OF_WEEK) - 1).coerceIn(0, 6)]
        val mes = MESES[(agora.get(Calendar.MONTH)).coerceIn(0, 11)]
        return "Hoje é $dia, ${agora.get(Calendar.DAY_OF_MONTH)} de $mes de " +
            "${agora.get(Calendar.YEAR)}."
    }

    /**
     * Sessão de mídia ativa: a que está tocando, a do Spotify ou a primeira.
     *
     * Exige acesso a notificações (o mesmo componente que já lê as mensagens),
     * que é o que permite ao Android entregar as sessões de outros apps. Sem
     * esse acesso, devolve `null` e quem chamou explica o que falta.
     */
    private fun controladorMidia(context: Context): MediaController? {
        val gerenciador = context.getSystemService(Context.MEDIA_SESSION_SERVICE)
            as? MediaSessionManager ?: return null
        val componente = ComponentName(context, JarvisNotificacaoListener::class.java)
        return try {
            val sessoes = gerenciador.getActiveSessions(componente)
            sessoes.firstOrNull { it.playbackState?.state == PlaybackState.STATE_PLAYING }
                ?: sessoes.firstOrNull { it.packageName.contains("spotify") }
                ?: sessoes.firstOrNull()
        } catch (_: SecurityException) {
            null
        } catch (_: Exception) {
            null
        }
    }

    /** Nome da faixa atual, para a resposta não ser genérica. */
    private fun faixaDe(controlador: MediaController?): String {
        val titulo = controlador?.metadata
            ?.getString(MediaMetadata.METADATA_KEY_TITLE).orEmpty().trim()
        if (titulo.isEmpty()) return ""
        val artista = controlador?.metadata
            ?.getString(MediaMetadata.METADATA_KEY_ARTIST).orEmpty().trim()
        return if (artista.isEmpty()) " \"$titulo\"" else " \"$titulo\" — $artista"
    }

    /**
     * Pausa, retoma, avança ou volta a música que estiver tocando, em qualquer
     * app de música — não só no Spotify.
     *
     * O comando é enviado pelo controle de sessão do Android. A confirmação é
     * lida do estado real depois de uma espera curta (no máximo 900 ms): se o
     * app não mudar de estado, a resposta diz que não confirmou, em vez de
     * afirmar que pausou.
     */
    private fun midia(context: Context, acao: AcaoMidia): Resultado {
        val controlador = controladorMidia(context)
            ?: return Resultado(
                false,
                "Não encontrei nenhum app de música ativo. Abra o app, toque algo uma " +
                    "vez e depois peça para pausar ou continuar. Se o app estiver " +
                    "tocando e ainda assim eu não achar, confira o acesso a " +
                    "notificações do JARVIS."
            )
        val tocandoAntes = controlador.playbackState?.state == PlaybackState.STATE_PLAYING
        if (acao == AcaoMidia.PAUSAR && !tocandoAntes) {
            return Resultado(true, "Nada está tocando agora${faixaDe(controlador)}.")
        }
        if (acao == AcaoMidia.CONTINUAR && tocandoAntes) {
            return Resultado(true, "A música já está tocando${faixaDe(controlador)}.")
        }
        try {
            when (acao) {
                AcaoMidia.PAUSAR -> controlador.transportControls.pause()
                AcaoMidia.CONTINUAR -> controlador.transportControls.play()
                AcaoMidia.PROXIMA -> controlador.transportControls.skipToNext()
                AcaoMidia.ANTERIOR -> controlador.transportControls.skipToPrevious()
            }
        } catch (_: Exception) {
            return Resultado(false, "O app de música recusou o comando agora.")
        }

        val esperado: Boolean? = when (acao) {
            AcaoMidia.PAUSAR -> false
            AcaoMidia.CONTINUAR -> true
            else -> null
        }
        if (esperado != null) {
            val limite = System.currentTimeMillis() + 900
            while (System.currentTimeMillis() < limite) {
                val estado = controladorMidia(context)?.playbackState?.state
                    ?: controlador.playbackState?.state
                if ((estado == PlaybackState.STATE_PLAYING) == esperado) break
                try {
                    Thread.sleep(120)
                } catch (_: InterruptedException) {
                    break
                }
            }
        }

        val depois = controladorMidia(context) ?: controlador
        val tocando = depois.playbackState?.state == PlaybackState.STATE_PLAYING
        val faixa = faixaDe(depois)
        return when (acao) {
            AcaoMidia.PAUSAR -> if (!tocando) {
                Resultado(true, "Pausado$faixa.")
            } else {
                Resultado(
                    false,
                    "Pedi a pausa, mas o app de música não confirmou: $faixa continua tocando."
                )
            }
            AcaoMidia.CONTINUAR -> if (tocando) {
                Resultado(true, "Tocando$faixa.")
            } else {
                Resultado(
                    false,
                    "Pedi para continuar, mas o app de música não confirmou a reprodução."
                )
            }
            AcaoMidia.PROXIMA -> Resultado(true, "Próxima faixa pedida ao app de música$faixa.")
            AcaoMidia.ANTERIOR -> Resultado(true, "Faixa anterior pedida ao app de música$faixa.")
        }
    }

    /** Liga ou desliga o núcleo flutuante por voz, com o motivo real. */
    private fun nucleo(context: Context, ligar: Boolean?): Resultado {
        if (ligar == false) {
            val estavaAtivo = JarvisNucleo.estado(context)["ativo"] == true
            JarvisNucleo.parar()
            if (!estavaAtivo) {
                return Resultado(true, "O núcleo flutuante já estava desligado.")
            }
            val aindaAtivo = JarvisNucleo.estado(context)["ativo"] == true
            return if (aindaAtivo) {
                Resultado(false, "O núcleo continua na tela; o Android não confirmou a saída.")
            } else {
                Resultado(true, "Núcleo flutuante desativado.")
            }
        }
        val estado = JarvisNucleo.iniciar(context, 112, 7_000L, false)
        return when {
            estado["ativo"] == true ->
                Resultado(true, "Núcleo flutuante ativo por cima dos outros apps.")
            estado["motivo"] == "sem_permissao" -> Resultado(
                false,
                "Para o núcleo aparecer por cima dos outros apps, autorize " +
                    "“Exibir sobre outros apps” nas configurações do Android."
            )
            else -> Resultado(false, "O Android não abriu o núcleo flutuante.")
        }
    }

    private fun abrirApp(context: Context, nome: String): Resultado {
        val termo = nome.trim().lowercase()
        if (termo.isEmpty()) return Resultado(false, "Diga o nome do app que devo abrir.")
        val pm = context.packageManager
        val apps = try {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(
                Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0
            ).mapNotNull { info ->
                val rotulo = info.loadLabel(pm)?.toString().orEmpty()
                val pacote = info.activityInfo?.packageName.orEmpty()
                if (rotulo.isBlank() || pacote.isBlank()) null
                else mapOf("rotulo" to rotulo, "pacote" to pacote)
            }.distinctBy { it["pacote"] }
        } catch (_: Exception) {
            emptyList()
        }
        val exatos = apps.filter {
            it["rotulo"].toString().lowercase() == termo ||
                it["pacote"].toString().lowercase() == termo
        }
        val encontrados = if (exatos.isNotEmpty()) exatos
        else apps.filter { it["rotulo"].toString().lowercase().contains(termo) }
        if (encontrados.isEmpty()) {
            return Resultado(false, "Nenhum app instalado corresponde a \"$nome\".")
        }
        if (encontrados.size > 1) {
            val nomes = encontrados.take(6).map { it["rotulo"].toString() }
            return Resultado(
                false,
                "Encontrei mais de um app: ${nomes.joinToString(", ")}. Diga o nome completo.",
                nomes
            )
        }
        val pacote = encontrados.first()["pacote"].toString()
        val rotulo = encontrados.first()["rotulo"].toString()
        val abertura = pm.getLaunchIntentForPackage(pacote)
            ?: return Resultado(false, "\"$rotulo\" está instalado, mas não abre uma tela.")
        if (!podeAbrirApps(context)) {
            return Resultado(
                false,
                "Para abrir apps com o JARVIS fechado, autorize \"Exibir sobre outros apps\" nas "
                    + "configurações do segundo plano."
            )
        }
        abertura.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            context.startActivity(abertura)
            Resultado(true, "$rotulo aberto.")
        } catch (erro: Exception) {
            Resultado(
                false,
                "O Android recusou abrir \"$rotulo\": ${erro.message ?: erro.javaClass.simpleName}"
            )
        }
    }

    private fun lanterna(context: Context, ligar: Boolean?): Resultado {
        val gerenciador = context.getSystemService(Context.CAMERA_SERVICE) as? CameraManager
            ?: return Resultado(false, "Este aparelho não informou serviço de câmera.")
        val id = try {
            gerenciador.cameraIdList.firstOrNull { candidato ->
                gerenciador.getCameraCharacteristics(candidato)
                    .get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
            }
        } catch (_: Exception) {
            null
        } ?: return Resultado(false, "Este aparelho não informou uma lanterna disponível.")
        return try {
            gerenciador.setTorchMode(id, ligar ?: true)
            Resultado(true, if (ligar == false) "Lanterna desligada." else "Lanterna ligada.")
        } catch (erro: Exception) {
            Resultado(
                false,
                "O Android recusou a lanterna: ${erro.message ?: erro.javaClass.simpleName}"
            )
        }
    }

    private fun volume(context: Context, percentual: Int?, delta: Int?): Resultado {
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            ?: return Resultado(false, "Este aparelho não informou serviço de áudio.")
        val canal = AudioManager.STREAM_MUSIC
        val maximo = audio.getStreamMaxVolume(canal).coerceAtLeast(1)
        val atual = audio.getStreamVolume(canal)
        if (percentual == null && delta == null) {
            return Resultado(false, "Informe o percentual ou o ajuste de volume.")
        }
        val alvo = if (percentual != null) {
            (percentual.coerceIn(0, 100) * maximo / 100.0).roundToInt()
        } else {
            (atual + (delta ?: 0) * maximo / 100.0).roundToInt().coerceIn(0, maximo)
        }
        return try {
            audio.setStreamVolume(canal, alvo, 0)
            val lido = audio.getStreamVolume(canal)
            val lidoPercentual = (lido * 100.0 / maximo).roundToInt()
            if (abs(lido - alvo) > 1) {
                Resultado(false, "O volume pedido era $alvo, mas o Android informou $lido.")
            } else {
                Resultado(true, "Volume de mídia em $lidoPercentual%.")
            }
        } catch (erro: Exception) {
            Resultado(
                false,
                "O Android recusou alterar o volume: ${erro.message ?: erro.javaClass.simpleName}"
            )
        }
    }

    private fun alarme(context: Context, hora: Int, minuto: Int): Resultado {
        if (hora !in 0..23 || minuto !in 0..59) {
            return Resultado(false, "Informe um horário entre 00:00 e 23:59.")
        }
        val formatado = "%02d:%02d".format(hora, minuto)
        val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
            putExtra(AlarmClock.EXTRA_HOUR, hora)
            putExtra(AlarmClock.EXTRA_MINUTES, minuto)
            putExtra(AlarmClock.EXTRA_SKIP_UI, false)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        if (intent.resolveActivity(context.packageManager) == null) {
            return Resultado(false, "Este aparelho não tem um app de relógio que aceite alarmes.")
        }
        if (!podeAbrirApps(context)) {
            return Resultado(
                false,
                "Para abrir o alarme com o JARVIS fechado, autorize \"Exibir sobre outros apps\"."
            )
        }
        return try {
            context.startActivity(intent)
            Resultado(true, "Abri o alarme para $formatado; confirme no relógio do aparelho.")
        } catch (erro: Exception) {
            Resultado(
                false,
                "O Android recusou abrir o alarme: ${erro.message ?: erro.javaClass.simpleName}"
            )
        }
    }
}
