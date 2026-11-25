package com.jarvis.nova

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.MediaStore

/**
 * App de terceiro aberto já numa ação: conversa, rascunho, busca, rota, câmera.
 *
 * “Abre o WhatsApp na conversa da Ana” não é só abrir o WhatsApp: o Android
 * aceita um link que cai direto na conversa. O mesmo vale para o rascunho do
 * Gmail, a busca do YouTube e a rota do mapa. Aqui ficam o reconhecimento (o
 * mesmo do núcleo Dart `core/pedido_app.dart`) e a montagem do link.
 *
 * A regra é conservadora: só age com verbo de abrir e uma ação reconhecida.
 * “Abre o WhatsApp” sozinho continua no comando de app que já existia, e
 * mensagem e ligação continuam no caminho delas. Quando o contato não é achado
 * ou o app não aceita o link, o resultado diz — nada de dizer que abriu.
 */
object JarvisAbrirApp {

    data class Pedido(
        val app: String,
        val acao: String,
        val alvo: String = "",
        val texto: String = "",
    )

    data class Resultado(val ok: Boolean, val mensagem: String, val acao: String)

    /** Chave → como o app é chamado na fala. */
    private val APPS: Map<String, String> = mapOf(
        "whatsapp" to "o WhatsApp",
        "whatsapp_business" to "o WhatsApp Business",
        "telegram" to "o Telegram",
        "instagram" to "o Instagram",
        "gmail" to "o Gmail",
        "email" to "o e-mail",
        "sms" to "o SMS",
        "maps" to "o mapa",
        "youtube" to "o YouTube",
        "spotify" to "o Spotify",
        "camera" to "a câmera",
        "calculadora" to "a calculadora",
    )

    /** Alias de fala → chave do app; o mais longo casa primeiro. */
    private val ALIASES: List<Pair<String, String>> = listOf(
        "whatsapp business" to "whatsapp_business",
        "wpp business" to "whatsapp_business",
        "mensagem de texto" to "sms",
        "google maps" to "maps",
        "google mail" to "gmail",
        "whatsapp" to "whatsapp",
        "whats" to "whatsapp",
        "zap" to "whatsapp",
        "wpp" to "whatsapp",
        "telegram" to "telegram",
        "instagram" to "instagram",
        "insta" to "instagram",
        "gmail" to "gmail",
        "e-mail" to "email",
        "email" to "email",
        "correio" to "email",
        "sms" to "sms",
        "torpedo" to "sms",
        "mapa" to "maps",
        "mapas" to "maps",
        "maps" to "maps",
        "youtube" to "youtube",
        "you tube" to "youtube",
        "spotify" to "spotify",
        "camera" to "camera",
        "calculadora" to "calculadora",
    ).sortedByDescending { it.first.length }

    private val VERBO_ABRIR = Regex(
        "\\b(abrir|abre|abra|abri|mostrar|mostra|mostre|exibir|exibe|exiba|" +
            "entrar em|entra em|entre em|ir para|vai para|va para)\\b"
    )
    private val PERGUNTA = Regex("^(como|por que|porque|quando|quem|onde|qual|quais|o que)\\b")
    private val PESQUISAR = Regex(
        "\\b(pesquisa|pesquisar|pesquise|busca|buscar|busque|procura|procurar|procure)\\b"
    )
    private val NAVEGAR = Regex("\\b(rota|navega|navegar|navegue|ir ate|vai ate|va ate|me leva|leva me|como chego|caminho ate)\\b")
    private val ROTA = Regex("\\b(rota|navega|navegar|navegue|ir ate|vai ate|va ate|me leva|leva me|como chego|caminho ate|ate)\\b")
    private val CONVERSA = Regex("\\b(?:na\\s+)?(?:conversa|conversar|falar|fala|direct)\\s+(?:com|da|do|de)\\s+")
    private val ESCREVER = Regex("\\b(?:escrever|escreve|nova mensagem|novo email|novo e-mail|compor)\\b")
    private val CONECTORES = Regex(
        "^(?:e|o|a|os|as|um|uma|para|pra|pro|ao|aos|no|na|nos|nas|com|da|do|" +
            "das|dos|de|sobre|por|pelo|pela|ate|que|nova|novo|mensagem|email|" +
            "e-mail|conversa|direct|pesquisa|pesquisar|busca|buscar|procura|" +
            "procurar|toca|tocar|escrever|escreve|falar|conversar|mapa|rota)\\b\\s*"
    )

    /** Pedido reconhecido, ou `null` quando a frase é outra coisa. */
    fun interpretar(frase: String): Pedido? {
        val original = frase.trim()
        val limpo = tirarCortesia(normalizar(original))
        if (limpo.isEmpty()) return null
        if (PERGUNTA.containsMatchIn(limpo)) return null
        if (!VERBO_ABRIR.containsMatchIn(limpo)) return null
        // Mensagem e ligação têm caminho próprio; esta regra não as rouba.
        if (JarvisMensagens.interpretar(original) != null) return null

        var app: String? = null
        for ((alias, chave) in ALIASES) {
            if (Regex("\\b${Regex.escape(alias)}\\b").containsMatchIn(limpo)) {
                app = chave
                break
            }
        }
        if (app == null) return null

        if (app == "camera") return Pedido("camera", "camera")
        if (app == "calculadora") return Pedido("calculadora", "abrir")

        if (PESQUISAR.containsMatchIn(limpo)) {
            val alvo = depois(original, PESQUISAR)
            if (alvo.isEmpty()) return null
            if (app == "spotify") return Pedido(app, "tocar", alvo)
            return Pedido(app, "pesquisar", alvo)
        }
        if (app == "maps") {
            val navegar = NAVEGAR.containsMatchIn(limpo) || ROTA.containsMatchIn(limpo)
            val alvo = if (navegar) depois(original, ROTA)
            else depois(original, Regex("\\b(?:de|em|para|pra|ate|sobre)\\s+"))
            if (alvo.isEmpty()) return null
            return Pedido(app, if (navegar) "navegar" else "pesquisar", alvo)
        }
        if (app == "whatsapp" || app == "whatsapp_business" ||
            app == "telegram" || app == "instagram" || app == "sms"
        ) {
            val marcador = if (CONVERSA.containsMatchIn(limpo)) CONVERSA
            else Regex("\\b(?:com|para|pra|pro)\\s+")
            val alvo = depois(original, marcador)
            if (alvo.isEmpty()) return null
            return Pedido(app, "conversa", alvo)
        }
        if (app == "gmail" || app == "email") {
            val alvo = depois(original, ESCREVER)
            if (alvo.isEmpty()) return Pedido(app, "escrever")
            val destinatario = limparAlvo(
                Regex("^(?:para|pra|pro|a|ao)\\s+").replaceFirst(alvo, "")
            )
            return Pedido(app, "escrever", destinatario)
        }
        return null
    }

    /** Executa o pedido: monta o link do app e informa o que aconteceu. */
    fun executar(contexto: Context, pedido: Pedido): Resultado {
        val nome = APPS[pedido.app] ?: pedido.app
        val acao = quando(pedido)
        return try {
            when (pedido.app) {
                "whatsapp", "whatsapp_business" -> whatsapp(contexto, pedido, nome, acao)
                "telegram" -> telegram(contexto, pedido, acao)
                "instagram" -> instagram(contexto, pedido, acao)
                "sms" -> sms(contexto, pedido, acao)
                "gmail", "email" -> email(contexto, pedido, nome, acao)
                "maps" -> mapa(contexto, pedido, acao)
                "youtube" -> youtube(contexto, pedido, acao)
                "spotify" -> spotify(contexto, pedido, acao)
                "camera" -> abrirIntent(
                    contexto,
                    Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA),
                    "Abri a câmera.",
                    acao,
                )
                "calculadora" -> abrirCalculadora(contexto, acao)
                else -> Resultado(false, "Esse app não está na lista do JARVIS.", acao)
            }
        } catch (erro: Exception) {
            Resultado(
                false,
                "Não consegui abrir $nome: ${erro.message ?: erro.javaClass.simpleName}",
                acao,
            )
        }
    }

    private fun quando(pedido: Pedido): String {
        val nome = APPS[pedido.app] ?: pedido.app
        return when (pedido.acao) {
            "conversa" -> "abrir $nome na conversa com ${pedido.alvo}"
            "escrever" -> "abrir $nome para escrever" +
                if (pedido.alvo.isBlank()) "" else " para ${pedido.alvo}"
            "pesquisar" -> "pesquisar \"${pedido.alvo}\" no $nome"
            "navegar" -> "traçar rota até ${pedido.alvo}"
            "tocar" -> "tocar \"${pedido.alvo}\" no $nome"
            "camera" -> "abrir a câmera"
            else -> "abrir $nome"
        }
    }

    private fun whatsapp(contexto: Context, pedido: Pedido, nome: String, acao: String): Resultado {
        val numero = telefoneDe(contexto, pedido.alvo)
            .ifBlank { if (pedido.alvo.any { it.isDigit() }) pedido.alvo.filter { c -> c.isDigit() || c == '+' } else "" }
        if (numero.isBlank()) {
            return abrirPacote(
                contexto,
                if (pedido.app == "whatsapp_business") "com.whatsapp.w4b" else "com.whatsapp",
                "Não achei o número de ${pedido.alvo} nos contatos. Abri o $nome; " +
                    "escolha a conversa na tela.",
                acao,
            )
        }
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/$numero"))
            .setPackage(if (pedido.app == "whatsapp_business") "com.whatsapp.w4b" else "com.whatsapp")
        val abriu = abrirIntent(contexto, intent, "Abri o $nome na conversa com ${pedido.alvo}.", acao)
        if (abriu.ok) return abriu
        return abrirIntent(
            contexto,
            Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/$numero")),
            "Abri o $nome na conversa com ${pedido.alvo}.",
            acao,
        )
    }

    private fun telegram(contexto: Context, pedido: Pedido, acao: String): Resultado {
        val usuario = pedido.alvo.trim().removePrefix("@")
        if (usuario.isNotEmpty() && usuario.none { it.isDigit() } && !usuario.contains(" ")) {
            return abrirIntent(
                contexto,
                Intent(Intent.ACTION_VIEW, Uri.parse("https://t.me/$usuario")),
                "Abri o Telegram na conversa com $usuario.",
                acao,
            )
        }
        return abrirPacote(
            contexto,
            "org.telegram.messenger",
            "Abri o Telegram. Para cair direto numa conversa, diga o usuário do Telegram.",
            acao,
        )
    }

    private fun instagram(contexto: Context, pedido: Pedido, acao: String): Resultado {
        val usuario = pedido.alvo.trim().removePrefix("@")
        if (usuario.isNotEmpty() && !usuario.contains(" ")) {
            return abrirIntent(
                contexto,
                Intent(Intent.ACTION_VIEW, Uri.parse("https://ig.me/m/$usuario")),
                "Abri o Instagram no direct com $usuario.",
                acao,
            )
        }
        return abrirPacote(
            contexto,
            "com.instagram.android",
            "Abri o Instagram. Para cair direto no direct, diga o usuário do Instagram.",
            acao,
        )
    }

    private fun sms(contexto: Context, pedido: Pedido, acao: String): Resultado {
        val numero = telefoneDe(contexto, pedido.alvo)
            .ifBlank { if (pedido.alvo.any { it.isDigit() }) pedido.alvo.filter { c -> c.isDigit() || c == '+' } else "" }
        if (numero.isBlank()) {
            return abrirIntent(
                contexto,
                Intent(Intent.ACTION_VIEW, Uri.parse("sms:")),
                "Não achei o número de ${pedido.alvo} nos contatos. Abri o SMS; " +
                    "escolha a conversa na tela.",
                acao,
            )
        }
        return abrirIntent(
            contexto,
            Intent(Intent.ACTION_VIEW, Uri.parse("smsto:$numero")),
            "Abri o SMS na conversa com ${pedido.alvo}.",
            acao,
        )
    }

    private fun email(contexto: Context, pedido: Pedido, nome: String, acao: String): Resultado {
        val endereco = emailDe(contexto, pedido.alvo)
            .ifBlank { if (pedido.alvo.contains("@")) pedido.alvo.trim() else "" }
        val intent = Intent(Intent.ACTION_SENDTO).apply {
            data = Uri.parse("mailto:$endereco")
            if (pedido.texto.isNotBlank()) putExtra(Intent.EXTRA_SUBJECT, pedido.texto)
            if (pedido.app == "gmail") setPackage("com.google.android.gm")
        }
        val destino = endereco.ifBlank { "um destinatário em branco" }
        val abriu = abrirIntent(
            contexto, intent, "Abri $nome para escrever para $destino.", acao
        )
        if (abriu.ok) return abriu
        return abrirIntent(
            contexto,
            Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:$endereco")),
            "Abri $nome para escrever para $destino.",
            acao,
        )
    }

    private fun mapa(contexto: Context, pedido: Pedido, acao: String): Resultado {
        val alvo = Uri.encode(pedido.alvo)
        if (pedido.acao == "navegar") {
            val rota = Intent(Intent.ACTION_VIEW, Uri.parse("google.navigation:q=$alvo"))
                .setPackage("com.google.android.apps.maps")
            val tentou = abrirIntent(
                contexto, rota, "Abri a rota até ${pedido.alvo} no mapa.", acao
            )
            if (tentou.ok) return tentou
            return abrirIntent(
                contexto,
                Intent(Intent.ACTION_VIEW, Uri.parse("geo:0,0?q=$alvo")),
                "Abri o mapa em ${pedido.alvo}. Toque em rotas para começar a navegação.",
                acao,
            )
        }
        return abrirIntent(
            contexto,
            Intent(Intent.ACTION_VIEW, Uri.parse("geo:0,0?q=$alvo")),
            "Abri o mapa em ${pedido.alvo}.",
            acao,
        )
    }

    private fun youtube(contexto: Context, pedido: Pedido, acao: String): Resultado {
        val url = "https://www.youtube.com/results?search_query=${Uri.encode(pedido.alvo)}"
        val comApp = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            .setPackage("com.google.android.youtube")
        val tentou = abrirIntent(
            contexto, comApp, "Abri o YouTube pesquisando \"${pedido.alvo}\".", acao
        )
        if (tentou.ok) return tentou
        return abrirIntent(
            contexto,
            Intent(Intent.ACTION_VIEW, Uri.parse(url)),
            "Abri a pesquisa de \"${pedido.alvo}\" no YouTube.",
            acao,
        )
    }

    private fun spotify(contexto: Context, pedido: Pedido, acao: String): Resultado {
        val busca = Uri.encode(pedido.alvo)
        val comApp = Intent(Intent.ACTION_VIEW, Uri.parse("spotify:search:$busca"))
            .setPackage("com.spotify.music")
        val tentou = abrirIntent(
            contexto, comApp, "Abri o Spotify pesquisando \"${pedido.alvo}\".", acao
        )
        if (tentou.ok) return tentou
        return abrirIntent(
            contexto,
            Intent(
                Intent.ACTION_VIEW,
                Uri.parse("https://open.spotify.com/search/$busca"),
            ),
            "Abri a pesquisa de \"${pedido.alvo}\" no Spotify.",
            acao,
        )
    }

    private fun abrirCalculadora(contexto: Context, acao: String): Resultado {
        for (pacote in listOf("com.google.android.calculator", "com.android.calculator2")) {
            val abertura = contexto.packageManager.getLaunchIntentForPackage(pacote)
            if (abertura != null) {
                return abrirIntent(contexto, abertura, "Abri a calculadora.", acao)
            }
        }
        return Resultado(false, "Não encontrei a calculadora neste aparelho.", acao)
    }

    private fun abrirPacote(
        contexto: Context,
        pacote: String,
        mensagem: String,
        acao: String,
    ): Resultado {
        val abertura = contexto.packageManager.getLaunchIntentForPackage(pacote)
            ?: return Resultado(
                false,
                "O app não está instalado neste aparelho.",
                acao,
            )
        return abrirIntent(contexto, abertura, mensagem, acao)
    }

    private fun abrirIntent(
        contexto: Context,
        intent: Intent,
        mensagem: String,
        acao: String,
    ): Resultado = try {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        contexto.startActivity(intent)
        Resultado(true, mensagem, acao)
    } catch (_: Exception) {
        Resultado(
            false,
            "O Android não deixou abrir o app para essa ação. Confira se ele está instalado.",
            acao,
        )
    }

    private fun telefoneDe(contexto: Context, destino: String): String =
        JarvisContatos.resolver(contexto, destino).contato?.primeiroTelefone.orEmpty()

    private fun emailDe(contexto: Context, destino: String): String {
        val alvo = destino.trim()
        if (alvo.contains("@")) return alvo
        return JarvisContatos.resolver(contexto, alvo).contato?.primeiroEmail.orEmpty()
    }

    private fun depois(original: String, marcador: Regex): String {
        val achado = marcador.find(normalizar(original)) ?: return ""
        return limparAlvo(original.substring(achado.range.last + 1))
    }

    private fun limparAlvo(trecho: String): String {
        var t = trecho
            .replace(Regex("[:\"“”?!.,;]"), " ")
            .replace(Regex("\\s+"), " ")
            .trim()
        var anterior = ""
        while (t != anterior) {
            anterior = t
            t = CONECTORES.replaceFirst(t, "").trim()
        }
        return t
    }

    private fun tirarCortesia(texto: String): String = texto
        .replaceFirst(Regex("^(?:jarvis|ei jarvis|oi jarvis)[\\s,]*"), "")
        .replaceFirst(Regex("^(?:por favor|pfv)[\\s,]*"), "")
        .trim()

    /** Minúsculas e sem acento, com o mesmo comprimento do texto original. */
    private fun normalizar(texto: String): String {
        val de = "áàâãäéèêëíìîïóòôõöúùûüç"
        val para = "aaaaaeeeeiiiiooooouuuuc"
        val saida = StringBuilder()
        for (c in texto.lowercase()) {
            val i = de.indexOf(c)
            saida.append(if (i < 0) c else para[i])
        }
        return saida.toString()
    }
}
