package com.jarvis.nova

import android.content.Context

/**
 * Apelido de contato ensinado pela fala, com o app aberto ou fechado.
 *
 * “O apelido do Murilo é Murilin”, “chama o Murilo de Murilin”, “conhece o
 * Murilo como Murilin” e “esquece o apelido Murilin”. A regra exige marcador
 * explícito — sem “apelido” ou “chama… de”, a frase não vira apelido, então
 * “o céu é azul” não mexe em contato nenhum.
 *
 * Quem guarda é o `JarvisContatos`; aqui ficam o reconhecimento (o mesmo do
 * núcleo Dart `core/pedido_apelido.dart`) e a conversa com a agenda.
 */
object JarvisApelidos {

    data class Pedido(
        val apelido: String,
        val nome: String = "",
        val esquecer: Boolean = false,
    )

    private val PERGUNTA = Regex("^(como|por que|porque|quando|quem|onde|qual|quais|o que)\\b")
    private val CORTESIA = Regex("^(?:(?:ei|oi)?\\s*jarvis|por favor|pfv)[\\s,]*")
    private val ESQUECER = Regex(
        "\\b(esquece|esquecer|esqueca|apaga|apagar|remove|remover|tira|tirar)\\b" +
            "\\s+(?:o\\s+|a\\s+)?apelido\\s*(?:de|do|da)?\\s+(.+)$"
    )
    private val POR_APELIDO = Regex(
        "^(?:o\\s+|a\\s+)?apelido\\s+(?:de|do|da)\\s+(.+?)\\s*(?:e|eh|:|=)\\s+(.+)$"
    )
    private val CHAMAR = Regex(
        "^(?:pode\\s+)?(?:chama|chamar|chame)\\s+(?:o\\s+|a\\s+)?(.+?)\\s+de\\s+(.+)$"
    )
    private val CONHECER = Regex(
        "^(?:conhece|conhecer)\\s+(?:o\\s+|a\\s+)?(.+?)\\s+como\\s+(.+)$"
    )

    /** Pedido reconhecido, ou `null` quando a frase é outra coisa. */
    fun interpretar(frase: String): Pedido? {
        val original = frase.trim()
        if (original.isEmpty()) return null
        val base = normalizar(original)
        var inicio = 0
        CORTESIA.find(base)?.let { inicio = it.range.last + 1 }
        val resto = base.substring(inicio)
        if (resto.isBlank()) return null
        if (PERGUNTA.containsMatchIn(resto.trim())) return null

        val esquece = ESQUECER.find(resto)
        if (esquece != null) {
            // Grupo 1 é o verbo; o apelido é o grupo 2.
            val grupo = esquece.groups[2] ?: return null
            val apelido = limpar(
                original.substring(
                    inicio + grupo.range.first,
                    inicio + grupo.range.last + 1,
                )
            )
            if (apelido.isBlank()) return null
            return Pedido(apelido = apelido, esquecer = true)
        }

        for (padrao in listOf(POR_APELIDO, CHAMAR, CONHECER)) {
            val achado = padrao.find(resto) ?: continue
            val grupoNome = achado.groups[1] ?: continue
            val grupoApelido = achado.groups[2] ?: continue
            val nome = limpar(original.substring(inicio + grupoNome.range.first, inicio + grupoNome.range.last + 1))
            val apelido = limpar(
                original.substring(inicio + grupoApelido.range.first, inicio + grupoApelido.range.last + 1)
            ).trim('"', '“', '”', '\'', '`', ' ')
            if (nome.isBlank() || apelido.isBlank()) return null
            return Pedido(apelido = apelido, nome = nome)
        }
        return null
    }

    /** Executa o pedido e devolve a frase que o alto-falante fala. */
    fun executar(contexto: Context, pedido: Pedido): Map<String, Any> {
        val acao = if (pedido.esquecer) {
            "esquecer o apelido ${pedido.apelido}"
        } else {
            "apelido de ${pedido.nome}: ${pedido.apelido}"
        }
        if (pedido.apelido.isBlank()) {
            return mapOf(
                "ok" to false,
                "mensagem" to "Diga qual apelido devo guardar.",
                "acao" to acao,
            )
        }
        if (pedido.esquecer) {
            JarvisContatos.esquecer(contexto, pedido.apelido)
            return mapOf(
                "ok" to true,
                "mensagem" to "Apelido ${pedido.apelido} esquecido. Quando você falar " +
                    "${pedido.apelido}, volto a procurar na agenda.",
                "acao" to acao,
            )
        }
        val escolha = JarvisContatos.resolver(contexto, pedido.nome)
        if (escolha.ambiguo) {
            return mapOf(
                "ok" to false,
                "mensagem" to "Achei mais de um contato parecido com ${pedido.nome}: ${
                    escolha.candidatos.joinToString(", ") { it.nome }
                }. Diga o sobrenome para eu guardar o apelido no contato certo.",
                "acao" to acao,
            )
        }
        val contato = escolha.contato
            ?: return mapOf(
                "ok" to false,
                "mensagem" to "Não achei ${pedido.nome} nos contatos do aparelho. " +
                    "Confira a permissão de contatos ou salve o contato primeiro.",
                "acao" to acao,
            )
        JarvisContatos.aprender(
            contexto, pedido.apelido, JarvisContatos.normalizar(contato.nome)
        )
        return mapOf(
            "ok" to true,
            "mensagem" to "Pronto. Quando você falar ${pedido.apelido}, eu entendo " +
                "${contato.nome}.",
            "acao" to acao,
            "contato" to contato.nome,
        )
    }

    private fun limpar(texto: String): String = texto
        .replace(Regex("\\s+"), " ")
        .trim()
        .trim(',', '.', ';', ':', ' ')

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
