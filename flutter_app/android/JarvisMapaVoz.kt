package com.jarvis.nova

/**
 * “Quais telas você abre?” com o app fechado.
 *
 * A lista completa vive na tela do mapa da voz, que só o Flutter monta; aqui a
 * resposta é curta e honesta, apontando a tela e dizendo quantas telas existem.
 * Nada de provedor de IA para uma pergunta sobre o próprio app.
 */
object JarvisMapaVoz {

    /** Mesmo número de telas da tabela Dart (`TelaJarvis`). */
    const val TOTAL_TELAS = 36

    private val PEDE_LISTA = Regex(
        "\\b(quais|que|lista|listar|mostra|mostrar|mostre|ver|existe|existem)\\b"
    )
    private val ASSUNTO = Regex(
        "\\b(tela|telas|comando|comandos|voz|fala|funcao|funcoes)\\b"
    )

    /** A frase é a pergunta do mapa? */
    fun pergunta(frase: String): Boolean {
        val limpo = normalizar(frase)
        if (limpo.isEmpty()) return false
        if (Regex("^(abre|abrir|exibe|exibir|mostra|mostrar)\\b").containsMatchIn(limpo) &&
            limpo.contains("mapa da voz")
        ) return false
        if (!PEDE_LISTA.containsMatchIn(limpo) || !ASSUNTO.containsMatchIn(limpo)) return false
        if (limpo.contains("como ") && !limpo.contains("quais")) return false
        return true
    }

    /** Resposta curta para o alto-falante. */
    fun responder(): String =
        "Consigo abrir $TOTAL_TELAS telas por voz, de “abre a memória” a " +
            "“abre as configurações”. Também abro apps já na conversa, mando " +
            "mensagem, ligo, controlo música e o aparelho, e aprendo apelido de " +
            "contato. Para ver a lista completa, abra o JARVIS e diga: abre o mapa " +
            "da voz."

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
