package com.jarvis.nova

/**
 * Pedido de palco reconhecido na fala, com o app fechado.
 *
 * “Jarvis, mostra fotos de motor trifásico”, “me mostra um vídeo sobre partida
 * direta” e “traz as últimas notícias de tecnologia” não são comando de baixo
 * risco nem pergunta para a IA: são pedido para abrir a tela do palco já
 * pesquisando. O serviço reconhece a frase aqui e entrega o pedido ao app por
 * `Intent`, porque quem sabe pesquisar e desenhar é o Flutter.
 *
 * O reconhecimento é o mesmo do núcleo Dart (`core/palco.dart`), reescrito
 * porque o serviço não tem o motor do Flutter à mão. Frase sem palavra de mídia
 * (“mostra o volume”) devolve `null` e segue o caminho de sempre.
 */
object JarvisPalco {
    enum class Tipo(val chave: String, val rotulo: String) {
        IMAGEM("imagem", "fotos"),
        VIDEO("video", "um vídeo"),
        NOTICIA("noticia", "notícias"),
    }

    data class Pedido(val tipo: Tipo, val consulta: String)

    /** Chave do `Intent` que leva o tipo; o Flutter lê em `IntencaoSistema`. */
    const val EXTRA_TIPO = "jarvis_palco_tipo"

    /** Chave do `Intent` que leva o assunto já limpo. */
    const val EXTRA_CONSULTA = "jarvis_palco_consulta"

    private const val VERBOS =
        "(mostra|mostre|mostrar|exibe|exibir|exiba|traz|traga|trazer|" +
            "pesquisa|pesquise|pesquisar|procura|procure|procurar|busca|" +
            "busque|buscar|quero ver|ver)"
    private const val IMAGENS = "(fotos?|imagens?|figuras?|ilustra[cç][aã]o|desenhos?)"
    private const val VIDEOS = "(v[ií]deos?|clipes?|filmes?)"
    private const val NOTICIAS = "(not[ií]cias?|manchetes?|reportagens?)"

    private val PEDIDO_IMAGEM = Regex(
        "$VERBOS\\b[^.!?]{0,40}\\b$IMAGENS\\b|\\b$IMAGENS\\b[^.!?]{0,20}\\b(no palco|na tela)",
        RegexOption.IGNORE_CASE
    )
    private val PEDIDO_VIDEO = Regex(
        "$VERBOS\\b[^.!?]{0,40}\\b$VIDEOS\\b|\\b$VIDEOS\\b[^.!?]{0,20}\\b(no palco|na tela)",
        RegexOption.IGNORE_CASE
    )
    private val PEDIDO_NOTICIA = Regex(
        "$VERBOS\\b[^.!?]{0,40}\\b$NOTICIAS\\b|\\b$NOTICIAS\\b[^.!?]{0,20}\\b(no palco|na tela)",
        RegexOption.IGNORE_CASE
    )

    /** Pedido reconhecido, ou `null` quando a frase é outra coisa. */
    fun interpretar(frase: String): Pedido? {
        val texto = frase.trim()
        if (texto.length < 4) return null
        val tipo = tipoDoPedido(texto) ?: return null
        val consulta = consultaDe(texto, tipo)
        if (consulta.isEmpty()) return null
        return Pedido(tipo, consulta)
    }

    /** O primeiro verbo de mídia que aparece manda; vídeo e notícia antes de imagem. */
    private fun tipoDoPedido(texto: String): Tipo? {
        val posicoes = mutableListOf<Pair<Tipo, Int>>()
        PEDIDO_VIDEO.find(texto)?.let { posicoes.add(Tipo.VIDEO to it.range.first) }
        PEDIDO_NOTICIA.find(texto)?.let { posicoes.add(Tipo.NOTICIA to it.range.first) }
        PEDIDO_IMAGEM.find(texto)?.let { posicoes.add(Tipo.IMAGEM to it.range.first) }
        return posicoes.minByOrNull { it.second }?.first
    }

    /** Tira verbo, palavra de mídia e preposições, deixando só o assunto. */
    private fun consultaDe(texto: String, tipo: Tipo): String {
        val palavras = when (tipo) {
            Tipo.IMAGEM -> IMAGENS
            Tipo.VIDEO -> VIDEOS
            Tipo.NOTICIA -> NOTICIAS
        }
        val remover = Regex(
            "^(?:por favor[, ]*)?(?:me )?(?:$VERBOS)\\s+" +
                "(?:(?:uma|um|uns|umas|a|o|as|os|algumas|alguns)\\s+)?" +
                "(?:$palavras)?(?:\\s+(?:de|do|da|dos|das|sobre|com|em|no|na|" +
                "nos|nas|para|pra|pelo|pela))?\\s*",
            RegexOption.IGNORE_CASE
        )
        var saida = texto.replaceFirst(remover, "")
        saida = saida.replaceFirst(
            Regex(
                "^(?:$palavras)\\s*(?:de|do|da|dos|das|sobre|com|em|no|na|" +
                    "nos|nas|para|pra)?\\s*",
                RegexOption.IGNORE_CASE
            ),
            ""
        )
        return saida
            .replace(Regex("[\"“”]"), " ")
            .replace(Regex("\\s+(no palco|na tela)\\s*$", RegexOption.IGNORE_CASE), "")
            .replace(Regex("\\s+"), " ")
            .trim()
            .trim('.', ',', ';', ':', '!', '?', '-')
    }

    /** Frase curta falada antes de o app abrir. */
    fun fraseDeAbertura(pedido: Pedido): String =
        "Abrindo o palco com ${pedido.tipo.rotulo} sobre ${pedido.consulta}."
}
