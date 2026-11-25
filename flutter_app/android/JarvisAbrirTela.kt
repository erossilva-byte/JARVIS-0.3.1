package com.jarvis.nova

/**
 * Tela do próprio JARVIS pedida na fala, com o app fechado.
 *
 * “Abre o modo visão”, “exibe o modo palco”, “abre a memória” e “mostra as
 * pessoas” não são comando de baixo risco nem pergunta para a IA: são pedido
 * para o app abrir a tela. O serviço reconhece a frase aqui e entrega a chave
 * fixa ao app por `Intent`, porque quem monta a tela é o Flutter.
 *
 * O reconhecimento é o mesmo do núcleo Dart (`core/pedido_abrir.dart`),
 * reescrito porque o serviço não tem o motor do Flutter à mão. A chave é a
 * mesma nos dois lados: é ela que o app traduz de volta para a tela.
 */
object JarvisAbrirTela {

    data class Pedido(val chave: String, val rotulo: String)

    /** Chave do `Intent` que leva a tela; o Flutter lê em `IntencaoSistema`. */
    const val EXTRA_TELA = "jarvis_tela"

    /** Alias de fala → chave/rotulo, na mesma tabela do Dart. */
    private val ALIASES: Map<String, Pedido> = mapOf(
        "modo visao" to Pedido("visao", "o modo visão"),
        "modo vision" to Pedido("visao", "o modo visão"),
        "vision" to Pedido("visao", "o modo visão"),
        "visao" to Pedido("visao", "o modo visão"),
        "camera" to Pedido("visao", "o modo visão"),
        "modo palco" to Pedido("palco", "o modo palco"),
        "palco" to Pedido("palco", "o modo palco"),
        "memoria" to Pedido("memoria", "a memória"),
        "obsidian" to Pedido("memoria", "a memória"),
        "anotacoes" to Pedido("memoria", "a memória"),
        "notas" to Pedido("memoria", "a memória"),
        "pessoas" to Pedido("pessoas", "as pessoas"),
        "fichas" to Pedido("pessoas", "as pessoas"),
        "ficha de pessoas" to Pedido("pessoas", "as pessoas"),
        "tarefas" to Pedido("tarefas", "as tarefas e rotinas"),
        "rotinas" to Pedido("tarefas", "as tarefas e rotinas"),
        "lembretes" to Pedido("tarefas", "as tarefas e rotinas"),
        "agenda" to Pedido("tarefas", "as tarefas e rotinas"),
        "modo programacao" to Pedido("programacao", "o modo programação"),
        "programacao" to Pedido("programacao", "o modo programação"),
        "modo dev" to Pedido("programacao", "o modo programação"),
        "arquivos" to Pedido("arquivos", "os arquivos"),
        "cadesimu" to Pedido("cadesimu", "o CADeSIMU"),
        "cad" to Pedido("cadesimu", "o CADeSIMU"),
        "simulador de circuitos" to Pedido("circuito", "o simulador de circuitos"),
        "simulador" to Pedido("circuito", "o simulador de circuitos"),
        "circuito" to Pedido("circuito", "o simulador de circuitos"),
        "projetista" to Pedido("projetista", "o projetista"),
        "seguranca" to Pedido("seguranca", "a segurança"),
        "bloqueio" to Pedido("seguranca", "a segurança"),
        "personalizacao" to Pedido("personalizacao", "a personalização"),
        "personalidade" to Pedido("personalizacao", "a personalização"),
        "configuracoes" to Pedido("configuracoes", "as configurações"),
        "configuracao" to Pedido("configuracoes", "as configurações"),
        "ajustes" to Pedido("configuracoes", "as configurações"),
        "habilidades" to Pedido("habilidades", "as habilidades"),
        "skills" to Pedido("habilidades", "as habilidades"),
        "gestos" to Pedido("gestos", "os gestos e o modo noturno"),
        "modo noturno" to Pedido("gestos", "os gestos e o modo noturno"),
        "perfis de timbre" to Pedido("timbre", "os perfis de timbre"),
        "perfis de voz" to Pedido("timbre", "os perfis de timbre"),
        "timbre" to Pedido("timbre", "os perfis de timbre"),
        "voz externa" to Pedido("voz_externa", "a voz externa"),
        "fish audio" to Pedido("voz_externa", "a voz externa"),
        "fish" to Pedido("voz_externa", "a voz externa"),
        "provedores de ia" to Pedido("provedores", "os provedores de IA"),
        "provedores" to Pedido("provedores", "os provedores de IA"),
        "chaves" to Pedido("provedores", "os provedores de IA"),
        "historico" to Pedido("historico", "o histórico de conversas"),
        "historico de voz" to Pedido("historico_voz", "o histórico de voz"),
        "historico da voz" to Pedido("historico_voz", "o histórico de voz"),
        "voz executada" to Pedido("historico_voz", "o histórico de voz"),
        "backups" to Pedido("backups", "os backups da memória"),
        "notas de backup" to Pedido("backups", "os backups da memória"),
        "versoes antigas" to Pedido("backups", "os backups da memória"),
        "regras do palco" to Pedido("regras_palco", "as regras do palco"),
        "regras" to Pedido("regras_palco", "as regras do palco"),
        "palavra de ativacao" to Pedido("ativacao", "a palavra de ativação"),
        "palavra chave" to Pedido("ativacao", "a palavra de ativação"),
        "ativacao" to Pedido("ativacao", "a palavra de ativação"),
        "hotword" to Pedido("ativacao", "a palavra de ativação"),
        "mapa da voz" to Pedido("mapa_voz", "o mapa da voz"),
        "telas por voz" to Pedido("mapa_voz", "o mapa da voz"),
        "comandos de voz" to Pedido("mapa_voz", "o mapa da voz"),
        "mapa dos comandos" to Pedido("mapa_voz", "o mapa da voz"),
        "aparelho conectado" to Pedido("aparelho", "o aparelho conectado"),
        "aparelho" to Pedido("aparelho", "o aparelho conectado"),
        "comandos do android" to Pedido("comandos", "os comandos do Android"),
        "comandos android" to Pedido("comandos", "os comandos do Android"),
        "comandos" to Pedido("comandos", "os comandos do Android"),
        "acessibilidade" to Pedido("acessibilidade", "a acessibilidade de tela"),
        "central do aparelho" to Pedido("dispositivo", "a central do aparelho"),
        "dispositivo" to Pedido("dispositivo", "a central do aparelho"),
        "segundo plano" to Pedido("segundo_plano", "o segundo plano"),
        "atualizacoes" to Pedido("atualizacoes", "as atualizações"),
        "atualizacao" to Pedido("atualizacoes", "as atualizações"),
        "avatar 3d" to Pedido("avatar", "o avatar 3D"),
        "avatar" to Pedido("avatar", "o avatar 3D"),
        "hermes" to Pedido("hermes", "o Hermes"),
        "agentes" to Pedido("agentes", "os agentes"),
        "agente" to Pedido("agentes", "os agentes"),
        "modelos locais" to Pedido("modelos_locais", "os modelos locais"),
        "conversa" to Pedido("conversa", "a conversa"),
        "chat" to Pedido("conversa", "a conversa"),
        "modo voz" to Pedido("voz", "o modo voz"),
        "tela de voz" to Pedido("voz", "o modo voz"),
        "voz" to Pedido("voz", "o modo voz"),
    )

    /** Alias do mais longo para o mais curto: "voz externa" não vira "voz". */
    private val ORDENADOS: List<Pair<String, Pedido>> =
        ALIASES.entries.sortedByDescending { it.key.length }.map { it.key to it.value }

    private val VERBO = Regex(
        "\\b(abrir|abre|abra|abri|mostrar|mostra|mostre|exibir|exibe|exiba|" +
            "entrar em|entra em|entre em|ir para|vai para|va para|leva para|" +
            "levar para|leva me para)\\b"
    )

    /** Pedido de mensagem: tem o seu próprio caminho, não abre tela. */
    private val BLOQUEIO = Regex(
        "\\b(mensagem|whatsapp|whats|zap|wpp|telegram|gmail|e-mail|email|sms|" +
            "manda|mandar|mande|envia|enviar|envie|escreve|escrever)\\b"
    )

    /** Pedido de ligação: “liga para a Ana” não é abrir tela. */
    private val LIGACAO = Regex("\\b(liga|ligar|ligue|disca|discar)\\s+(para|pra|pro|ao|a|o)\\b")

    private val PERGUNTA = Regex(
        "^(como|por que|porque|quando|quem|onde|qual|quais|o que)\\b"
    )

    /** Pedido reconhecido, ou `null` quando a frase é outra coisa. */
    fun interpretar(frase: String): Pedido? {
        val limpo = tirarCortesia(normalizar(frase))
        if (limpo.isEmpty()) return null
        if (PERGUNTA.containsMatchIn(limpo)) return null
        if (BLOQUEIO.containsMatchIn(limpo) || LIGACAO.containsMatchIn(limpo)) return null

        val verbo = VERBO.find(limpo)
        val semVerbo = limpo.startsWith("modo ") || ORDENADOS.any { it.first == limpo }
        if (verbo == null && !semVerbo) return null

        val inicio = verbo?.let { it.range.last + 1 } ?: 0
        for ((alias, pedido) in ORDENADOS) {
            val achado = Regex("\\b${Regex.escape(alias)}\\b").find(limpo) ?: continue
            if (achado.range.first < inicio) continue
            return pedido
        }
        return null
    }

    /** Frase curta falada antes de o app abrir. */
    fun fraseDeAbertura(pedido: Pedido): String = "Abrindo ${pedido.rotulo}."

    private fun tirarCortesia(texto: String): String = texto
        .replaceFirst(Regex("^(?:jarvis|ei jarvis|oi jarvis)[\\s,]*"), "")
        .replaceFirst(Regex("^(?:por favor|pfv)[\\s,]*"), "")
        .trim()

    /** Minúsculas e sem acento, como no Dart. */
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
