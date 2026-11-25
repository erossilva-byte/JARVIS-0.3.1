package com.jarvis.nova

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract
import android.telephony.SmsManager
import androidx.core.content.ContextCompat

/**
 * Mensagem e ligação pedidas na fala, com o app fechado.
 *
 * O Flutter já faz isso com o app aberto (`services/tarefas_da_voz.dart` +
 * `JarvisAparelho.kt`). Com o app fora da tela não há o motor da conversa, então
 * o serviço reconhece o pedido aqui e abre o app de destino pelo `Intent` — o
 * mesmo caminho que o JARVIS usa quando você pede pela tela.
 *
 * A regra é conservadora: só age quando o app de mensagem é citado e existe
 * destinatário e texto; no SMS o envio é direto quando o Android autoriza
 * enviar SMS, e nos demais apps a conversa é preenchida e falta o toque em
 * enviar — nenhum app de terceiro aceita envio silencioso. Ligação usa
 * `ACTION_CALL` quando há permissão e cai no discador quando não há, dizendo
 * qual dos dois aconteceu.
 */
object JarvisMensagens {

    enum class Tipo { MENSAGEM, LIGACAO }

    data class Pedido(
        val tipo: Tipo,
        val app: String = "",
        val destino: String = "",
        val texto: String = "",
    )

    data class Resultado(val ok: Boolean, val mensagem: String, val acao: String)

    private data class App(val id: String, val nome: String, val pacote: String)

    private val APPS = listOf(
        App("whatsapp_business", "WhatsApp Business", "com.whatsapp.w4b"),
        App("whatsapp", "WhatsApp", "com.whatsapp"),
        App("telegram", "Telegram", "org.telegram.messenger"),
        App("gmail", "Gmail", "com.google.android.gm"),
        App("email", "E-mail", ""),
        App("sms", "SMS", ""),
        App("discord", "Discord", "com.discord"),
        App("instagram", "Instagram", "com.instagram.android"),
        App("messenger", "Messenger", "com.facebook.orca"),
        App("signal", "Signal", "org.thoughtcrime.securesms"),
    )

    /** Alias dito → app; o mais longo casa primeiro ("whatsapp business"). */
    private val APELIDOS: List<Pair<String, String>> = listOf(
        "whatsapp business" to "whatsapp_business",
        "wpp business" to "whatsapp_business",
        "mensagem de texto" to "sms",
        "google mail" to "gmail",
        "whatsapp" to "whatsapp",
        "whats" to "whatsapp",
        "zap" to "whatsapp",
        "wpp" to "whatsapp",
        "telegram" to "telegram",
        "gmail" to "gmail",
        "e-mail" to "email",
        "email" to "email",
        "correio" to "email",
        "sms" to "sms",
        "torpedo" to "sms",
        "discord" to "discord",
        "instagram" to "instagram",
        "insta" to "instagram",
        "direct" to "instagram",
        "messenger" to "messenger",
        "facebook messenger" to "messenger",
        "signal" to "signal",
    ).sortedByDescending { it.first.length }

    private val VERBO_MENSAGEM = Regex(
        "\\b(manda|mandar|mande|envia|enviar|envie|escreve|escrever|fala|falar)\\b"
    )
    // Mesmos verbos do Dart (`interpretarLigacao` em `core/aparelho.dart`):
    // “chama o Murilo” liga tanto com a tela aberta quanto em segundo plano.
    private val VERBO_LIGACAO =
        Regex("\\b(liga|ligar|ligue|disca|discar|chama|chamar)\\b")
    private val MARCADOR_TEXTO = Regex(
        "\\b(?:dizendo(?:\\s+que)?|falando(?:\\s+que)?|com\\s+o\\s+texto|texto|que)\\b"
    )
    private val CONECTORES = Regex(
        "^(manda|mandar|mande|envia|enviar|envie|escreve|escrever|fala|falar|" +
            "mensagem|msg|texto|um|uma|para|pra|pro|a|ao|no|na|pelo|pela|via|" +
            "o|os|as|contato|contatos)\\b\\s*"
    )

    /** Pedido reconhecido, ou `null` quando a frase é outra coisa. */
    fun interpretar(frase: String): Pedido? {
        val original = frase.trim()
        val limpo = normalizar(original)
        if (limpo.isEmpty()) return null
        if (limpo.startsWith("como ") || limpo.startsWith("por que ")) return null

        val app = appCitado(limpo)

        // Ligação: "liga para a Ana". Não confundir com lanterna ("liga a").
        if (app == null &&
            VERBO_LIGACAO.containsMatchIn(limpo) &&
            !Regex("\\b(desliga|desligar|lanterna|volume|alarme|ligar a|ligar o|ligue a|ligue o)\\b")
                .containsMatchIn(limpo)
        ) {
            val achado = VERBO_LIGACAO.find(original) ?: return null
            val destino = limparDestino(original.substring(achado.range.last + 1))
            if (destino.isNotEmpty()) return Pedido(Tipo.LIGACAO, destino = destino)
        }

        if (!VERBO_MENSAGEM.containsMatchIn(limpo)) return null
        val aplicativo = app ?: return null
        if (!limpo.contains("mensagem") &&
            !Regex("\\b(para|pra|pro|a|ao|no|na|pelo|pela|via)\\b").containsMatchIn(limpo)
        ) return null

        val marcador = MARCADOR_TEXTO.find(original) ?: return null
        var corpo = original.substring(marcador.range.last + 1).trim()
        corpo = corpo.replaceFirst(Regex("^[:,\\-–—]\\s*"), "").trim()
        corpo = corpo.replaceFirst(Regex("^que\\s+", RegexOption.IGNORE_CASE), "").trim()
        if (corpo.isEmpty()) return null

        var trecho = original.substring(0, marcador.range.first)
        for ((alias, _) in APELIDOS) {
            trecho = trecho.replace(Regex("\\b${Regex.escape(alias)}\\b", RegexOption.IGNORE_CASE), " ")
        }
        val destino = limparDestino(trecho)
        if (destino.isEmpty()) return null
        return Pedido(Tipo.MENSAGEM, app = aplicativo, destino = destino, texto = corpo)
    }

    /** Executa o pedido com o contexto do serviço (sem Activity). */
    fun executar(contexto: Context, pedido: Pedido): Resultado {
        return when (pedido.tipo) {
            Tipo.LIGACAO -> ligar(contexto, pedido.destino)
            Tipo.MENSAGEM -> mensagem(contexto, pedido)
        }
    }

    private fun appCitado(limpo: String): String? {
        for ((alias, id) in APELIDOS) {
            if (Regex("\\b${Regex.escape(alias)}\\b").containsMatchIn(limpo)) return id
        }
        return null
    }

    private fun ligar(contexto: Context, destino: String): Resultado {
        val escolha = JarvisContatos.resolver(contexto, destino)
        if (escolha.ambiguo) {
            return Resultado(
                false,
                "Achei mais de um contato parecido com $destino: ${
                    escolha.candidatos.joinToString(", ") { it.nome }
                }. Diga o sobrenome.",
                "ligar para $destino",
            )
        }
        val numero = escolha.contato?.primeiroTelefone.orEmpty()
            .ifBlank { if (destino.any { it.isDigit() }) destino else "" }
        if (numero.isBlank()) {
            return Resultado(
                false,
                "Não achei o número de $destino nos contatos. Diga o número ou salve o contato.",
                "ligar para $destino",
            )
        }
        val acao = Uri.parse("tel:${Uri.encode(numero)}")
        val podeLigar = ContextCompat.checkSelfPermission(
            contexto, Manifest.permission.CALL_PHONE
        ) == PackageManager.PERMISSION_GRANTED
        val intent = if (podeLigar) {
            Intent(Intent.ACTION_CALL, acao)
        } else {
            Intent(Intent.ACTION_DIAL, acao)
        }.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return abrirIntent(
            contexto,
            intent,
            if (podeLigar) "Discando para $destino ($numero)."
            else "Abri o discador com o número de $destino ($numero). Falta tocar em ligar: " +
                "o JARVIS não tem permissão de ligar sozinho.",
            "ligar para $destino",
        )
    }

    private fun mensagem(contexto: Context, pedido: Pedido): Resultado {
        if (pedido.destino.isBlank() || pedido.texto.isBlank()) {
            return Resultado(
                false,
                "Faltou o destinatário ou o texto da mensagem.",
                "mensagem por ${nome(pedido.app)}",
            )
        }
        val acao = "mensagem por ${nome(pedido.app)}"
        val escolha = JarvisContatos.resolver(contexto, pedido.destino)
        if (escolha.ambiguo) {
            return Resultado(
                false,
                "Achei mais de um contato parecido com ${pedido.destino}: ${
                    escolha.candidatos.joinToString(", ") { it.nome }
                }. Diga o sobrenome.",
                acao,
            )
        }
        val numero = escolha.contato?.primeiroTelefone.orEmpty()
            .ifBlank { if (pedido.destino.any { it.isDigit() }) pedido.destino else "" }
        return try {
            when (pedido.app) {
                "sms" -> enviarSms(contexto, numero, pedido.texto, acao)
                "whatsapp", "whatsapp_business" -> {
                    val pacote = if (pedido.app == "whatsapp_business") "com.whatsapp.w4b" else "com.whatsapp"
                    val texto = Uri.encode(pedido.texto)
                    val uri = if (numero.isNotBlank()) {
                        Uri.parse("https://wa.me/$numero?text=$texto")
                    } else {
                        Uri.parse("whatsapp://send?text=$texto")
                    }
                    val intent = Intent(Intent.ACTION_VIEW, uri)
                        .setPackage(pacote)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    val abertura = abrirIntent(
                        contexto, intent,
                        "Abri o ${nome(pedido.app)} para ${pedido.destino} com o texto exato.",
                        acao,
                    )
                    if (!abertura.ok) abertura
                    else concluirEnvio(
                        contexto, pacote, pedido.texto, pedido.destino,
                        nome(pedido.app), acao
                    )
                }
                "telegram" -> {
                    val usuario = pedido.destino.trim().removePrefix("@")
                    val uri = if (usuario.isNotEmpty() && usuario.none { it.isDigit() }) {
                        Uri.parse("https://t.me/$usuario")
                    } else {
                        Uri.parse("https://t.me/share/url?url=${Uri.encode(pedido.texto)}")
                    }
                    val intent = Intent(Intent.ACTION_VIEW, uri)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    val abertura = abrirIntent(
                        contexto, intent,
                        "Abri o Telegram para ${pedido.destino}.",
                        acao,
                    )
                    // Só o link de compartilhar leva o texto; com usuário, o
                    // texto ainda não está na tela e não há o que tocar.
                    if (!abertura.ok || usuario.isNotEmpty() && usuario.none { it.isDigit() }) {
                        abertura
                    } else {
                        concluirEnvio(
                            contexto, "org.telegram.messenger", pedido.texto,
                            pedido.destino, "Telegram", acao
                        )
                    }
                }
                "gmail", "email" -> {
                    val endereco = emailDe(contexto, pedido.destino)
                        .ifBlank { if (pedido.destino.contains("@")) pedido.destino else "" }
                    val intent = Intent(Intent.ACTION_SENDTO).apply {
                        data = Uri.parse("mailto:$endereco")
                        putExtra(Intent.EXTRA_TEXT, pedido.texto)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    val abertura = abrirIntent(
                        contexto, intent,
                        "Abri o e-mail para ${pedido.destino} com o texto exato.",
                        acao,
                    )
                    if (!abertura.ok) abertura
                    else concluirEnvio(
                        contexto, "com.google.android.gm", pedido.texto,
                        pedido.destino, "e-mail", acao
                    )
                }
                else -> {
                    val aplicativo = APPS.firstOrNull { it.id == pedido.app }
                    if (aplicativo == null || aplicativo.pacote.isBlank()) {
                        return Resultado(false, "Esse app de mensagem não está na lista do JARVIS.", acao)
                    }
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, pedido.texto)
                        setPackage(aplicativo.pacote)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    abrirIntent(
                        contexto, intent,
                        "Abri o ${aplicativo.nome} com o texto. Falta escolher ${pedido.destino} " +
                            "e tocar em enviar.",
                        acao,
                    )
                }
            }
        } catch (e: Exception) {
            Resultado(
                false,
                "Não consegui abrir a mensagem: ${e.message ?: e.javaClass.simpleName}",
                acao,
            )
        }
    }

    /**
     * SMS sai direto quando o Android autoriza enviar SMS; sem a permissão, a
     * conversa fica pronta na tela de mensagens em vez de o JARVIS dizer que
     * enviou sem ter enviado.
     */
    private fun enviarSms(contexto: Context, numero: String, texto: String, acao: String): Resultado {
        if (numero.isBlank()) {
            return Resultado(false, "Não achei um número de telefone para esse destinatário.", acao)
        }
        val autorizado = ContextCompat.checkSelfPermission(
            contexto, Manifest.permission.SEND_SMS
        ) == PackageManager.PERMISSION_GRANTED
        if (!autorizado) {
            val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:$numero")).apply {
                putExtra("sms_body", texto)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            return abrirIntent(
                contexto, intent,
                "Abri o SMS para $numero com o texto. Falta tocar em enviar: o JARVIS não tem " +
                    "permissão de enviar SMS sozinho.",
                acao,
            )
        }
        return try {
            val gerenciador = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                contexto.getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
            gerenciador.sendTextMessage(numero, null, texto, null, null)
            Resultado(true, "SMS enviado para $numero com o texto pedido.", acao)
        } catch (e: Exception) {
            Resultado(false, "O SMS não saiu: ${e.message ?: e.javaClass.simpleName}", acao)
        }
    }

    /**
     * Fecha a mensagem: toca em Enviar pelo serviço de acessibilidade quando
     * ele está autorizado e o interruptor está ligado. Sem isso, a conversa
     * fica com o texto e o resultado diz que falta o toque.
     */
    private fun concluirEnvio(
        contexto: Context,
        pacote: String,
        texto: String,
        destino: String,
        nome: String,
        acao: String,
    ): Resultado {
        val envio = JarvisEnvioSemToque.tentar(contexto, pacote, texto, 5000L)
        return when {
            envio.enviado -> Resultado(
                true, "Mensagem enviada para $destino no $nome, sem toque.", acao
            )
            envio.tentou -> Resultado(
                true,
                "Abri o $nome para $destino com o texto exato. " +
                    JarvisEnvioSemToque.explicar(envio) + " Falta tocar em enviar.",
                acao,
            )
            else -> Resultado(
                true,
                "Abri o $nome para $destino com o texto exato. Falta tocar em enviar — " +
                    "$nome não aceita envio silencioso.",
                acao,
            )
        }
    }

    private fun abrirIntent(contexto: Context, intent: Intent, mensagem: String, acao: String): Resultado =
        try {
            contexto.startActivity(intent)
            Resultado(true, mensagem, acao)
        } catch (_: Exception) {
            Resultado(
                false,
                "O Android não deixou abrir o app para essa ação. Confira se ele está instalado.",
                acao,
            )
        }

    private fun nome(id: String): String =
        APPS.firstOrNull { it.id == id }?.nome ?: id

    private fun telefoneDe(contexto: Context, destino: String): String =
        JarvisContatos.resolver(contexto, destino).contato?.primeiroTelefone.orEmpty()

    private fun emailDe(contexto: Context, destino: String): String {
        val alvo = destino.trim()
        if (alvo.contains("@")) return alvo
        return JarvisContatos.resolver(contexto, alvo).contato?.primeiroEmail.orEmpty()
    }

    private fun limparDestino(trecho: String): String {
        var t = trecho
            .replace(Regex("[\"“”]"), " ")
            .replace(Regex("\\s+"), " ")
            .trim()
        var anterior = ""
        while (t != anterior) {
            anterior = t
            t = t.replaceFirst(CONECTORES, "").trim()
        }
        t = t.replaceFirst(Regex("\\s+(o|a|os|as|no|na|do|da)$", RegexOption.IGNORE_CASE), "").trim()
        return t
    }

    private fun normalizar(texto: String): String {
        val de = "áàâãäéèêëíìîïóòôõöúùûüç"
        val para = "aaaaaeeeeiiiiooooouuuuc"
        val saida = StringBuilder()
        for (c in texto.lowercase()) {
            val i = de.indexOf(c)
            saida.append(if (i < 0) c else para[i])
        }
        return saida.toString().replace(Regex("\\s+"), " ").trim()
    }
}
