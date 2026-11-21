package com.jarvis.nova

import android.content.Context

/**
 * Comandos de tela com o app fechado.
 *
 * O caminho de segundo plano não tem Flutter para intermediar, então o
 * interpretador vive aqui, com o mesmo escopo estreito do ajuste 095: ler,
 * tocar e rolar. O consentimento é o mesmo do app, lido da preferência
 * `jarvis.acessibilidade.ativo` (o Flutter grava com o prefixo `flutter.`).
 *
 * Tocar nunca executa sozinho: quem chama ([KwsForegroundService]) pergunta em
 * voz alta e só executa depois de um “confirmar”.
 */
object JarvisTelaVoz {
    /** Arquivo de preferências do Flutter no Android. */
    const val PREFS_FLUTTER = "FlutterSharedPreferences"

    /** Chave de `jarvis.acessibilidade.ativo` como o Flutter grava. */
    const val CHAVE_CONSENTIMENTO = "flutter.jarvis.acessibilidade.ativo"

    const val LIMITE_LEITURA = 40

    sealed class Pedido {
        data class Ler(val limite: Int = LIMITE_LEITURA) : Pedido()
        data class Tocar(val texto: String) : Pedido()
        data class Rolar(val paraCima: Boolean) : Pedido()
        object Parar : Pedido()
    }

    data class Resposta(val ok: Boolean, val mensagem: String, val acao: String)

    private val PERGUNTA = Regex("^(como|por que|porque|quando|quem|onde)\\b")
    private val LEITURA =
        Regex("^(ler|leia|le|descrever|descreva|mostrar|mostre|o que|quais)\\b")
    private val PARAR = Regex(
        "\\b(parar|pare|interromper|interrompa|interrompe|cancelar|cancela|cancele)\\b"
    )
    private val AUTOMACAO = Regex("\\b(auto?macao|tela|toques?|acoes?)\\b")
    private val ROLAR =
        Regex("\\b(rolar|rola|role|descer|desce|desca|subir|sobe|suba|passar)\\b")
    private val CIMA = Regex("\\b(cima|acima|topo|inicio|subir|sobe|suba)\\b")
    private val BAIXO = Regex("\\b(baixo|abaixo|fim|descer|desce|desca)\\b")
    private val TOQUE = Regex(
        "\\b(?:tocar|toca|toque|clicar|clica|clique)\\s+(?:em|no|na|nos|nas)\\s+(.+)$",
        RegexOption.IGNORE_CASE
    )
    private val APERTAR = Regex(
        "\\b(?:apertar|aperta|aperte)\\s+(?:o|a|os|as|em|no|na)?\\s*(.+)$",
        RegexOption.IGNORE_CASE
    )
    private val ALVO_GENERICO = Regex("^(botao|o botao|a tela|tela|ele|isso)$")
    private val SIM = Regex(
        "^(sim|s|confirmo|confirma|confirmar|pode|pode tocar|claro|isso|manda|executa|ok|beleza)\\b"
    )
    private val NAO = Regex(
        "^(nao|n|cancela|cancelar|deixa|deixa pra la|nao quero|pare|para)\\b"
    )

    /** Consentimento gravado pelo app; ausente ou ilegível vale “desligado”. */
    fun consentido(contexto: Context): Boolean = try {
        contexto.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
            .getBoolean(CHAVE_CONSENTIMENTO, false)
    } catch (_: Exception) {
        false
    }

    /** Devolve `null` quando o texto é conversa normal e deve seguir para a IA. */
    fun interpretar(texto: String): Pedido? {
        val limpo = normalizar(texto)
        if (limpo.isEmpty()) return null
        if (PERGUNTA.containsMatchIn(limpo)) return null

        if (PARAR.containsMatchIn(limpo) && AUTOMACAO.containsMatchIn(limpo)) {
            return Pedido.Parar
        }
        if (limpo.contains("tela") && LEITURA.containsMatchIn(limpo)) {
            return Pedido.Ler()
        }
        if (ROLAR.containsMatchIn(limpo)) {
            val cima = CIMA.containsMatchIn(limpo)
            val baixo = BAIXO.containsMatchIn(limpo)
            if (cima != baixo) return Pedido.Rolar(cima)
        }
        val toque = TOQUE.find(texto) ?: APERTAR.find(texto)
        if (toque != null) {
            val alvo = toque.groupValues[1]
                .trim()
                .trim('"', '\'', '.', ',', '!', '?', ';', ':', '“', '”')
                .trim()
            if (alvo.isEmpty() || alvo.length > 80) return null
            if (ALVO_GENERICO.matches(normalizar(alvo))) return null
            return Pedido.Tocar(alvo)
        }
        return null
    }

    fun confirmacaoPara(pedido: Pedido): String = when (pedido) {
        is Pedido.Tocar ->
            "Posso tocar em ${pedido.texto} na tela atual? Diga confirmar ou cancelar."
        else -> ""
    }

    /** `true` confirma, `false` cancela, `null` não entendeu (nada é executado). */
    fun confirmar(texto: String): Boolean? {
        val limpo = normalizar(texto)
        if (limpo.isEmpty()) return null
        if (SIM.containsMatchIn(limpo)) return true
        if (NAO.containsMatchIn(limpo)) return false
        return null
    }

    fun executar(pedido: Pedido): Resposta = when (pedido) {
        is Pedido.Ler -> ler(pedido.limite)
        is Pedido.Tocar -> tocar(pedido.texto)
        is Pedido.Rolar -> rolar(pedido.paraCima)
        Pedido.Parar -> {
            JarvisAcessibilidade.parar()
            Resposta(
                true,
                "Automação de tela interrompida. Nenhuma nova ação será executada.",
                "parar a automação de tela"
            )
        }
    }

    private fun ler(limite: Int): Resposta {
        val mapa = JarvisAcessibilidade.ler()
        if (mapa["ok"] != true) {
            return Resposta(false, erro(mapa, "Não consegui ler a tela."), "ler a tela")
        }
        val lista = (mapa["nos"] as? List<*>)
            ?.filterIsInstance<Map<*, *>>()
            .orEmpty()
        val partes = mutableListOf<String>()
        for (item in lista) {
            val texto = item["texto"]?.toString()?.trim().orEmpty()
            if (texto.isEmpty() || texto.equals("campo de texto", ignoreCase = true)) continue
            if (partes.any { it.equals(texto, ignoreCase = true) }) continue
            partes.add(if (texto.length > 40) texto.take(40) else texto)
            if (partes.size >= limite) break
        }
        if (partes.isEmpty()) {
            return Resposta(
                false,
                "Não encontrei texto legível nesta tela.",
                "ler a tela"
            )
        }
        val pacote = mapa["pacote"]?.toString().orEmpty()
        val onde = if (pacote.isEmpty()) "na tela atual" else "em $pacote"
        return Resposta(
            true,
            "Li ${lista.size} elementos $onde: ${partes.joinToString(", ")}.",
            "ler a tela"
        )
    }

    private fun tocar(texto: String): Resposta {
        val mapa = JarvisAcessibilidade.tocar(texto, 0)
        val ok = mapa["ok"] == true
        return Resposta(
            ok,
            mapa["mensagem"]?.toString()?.takeIf { it.isNotBlank() }
                ?: erro(mapa, "O aplicativo recusou o toque."),
            "tocar em \"$texto\""
        )
    }

    private fun rolar(paraCima: Boolean): Resposta {
        val mapa = JarvisAcessibilidade.rolar(paraCima)
        val ok = mapa["ok"] == true
        return Resposta(
            ok,
            mapa["mensagem"]?.toString()?.takeIf { it.isNotBlank() }
                ?: erro(mapa, "A tela recusou a rolagem."),
            if (paraCima) "rolar a tela para cima" else "rolar a tela para baixo"
        )
    }

    private fun erro(mapa: Map<String, Any>, padrao: String): String =
        mapa["erro"]?.toString()?.takeIf { it.isNotBlank() } ?: padrao

    private fun normalizar(texto: String): String {
        val de = "áàâãäéèêëíìîïóòôõöúùûüç"
        val para = "aaaaaeeeeiiiiooooouuuuc"
        val semAcento = StringBuilder()
        for (c in texto.lowercase()) {
            val indice = de.indexOf(c)
            semAcento.append(if (indice < 0) c else para[indice])
        }
        return semAcento.toString()
            .replace(Regex("[^a-z0-9 ]+"), " ")
            .replace(Regex("\\s+"), " ")
            .trim()
    }
}
