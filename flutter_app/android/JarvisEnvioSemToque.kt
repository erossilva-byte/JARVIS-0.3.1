package com.jarvis.nova

import android.content.Context
import android.view.accessibility.AccessibilityNodeInfo
import java.text.Normalizer
import java.util.Locale

/**
 * Toca no botão Enviar do app de mensagem, pelo serviço de acessibilidade.
 *
 * Nenhum app de terceiro aceita envio silencioso: o texto chega pelo link e o
 * toque em Enviar é seu. Com o serviço de acessibilidade autorizado e o
 * interruptor “Enviar mensagem sem toque” ligado, o JARVIS faz esse toque —
 * só depois de conferir que o texto pedido está na tela e que o botão Enviar
 * pertence ao app que ele acabou de abrir.
 *
 * O que este arquivo **não** faz: digitar, escolher contato, tocar em qualquer
 * outro botão, agir sem o serviço autorizado ou insistir depois do prazo. Se o
 * botão não aparecer, o resultado diz que não apareceu.
 */
object JarvisEnvioSemToque {

    private const val PREFS = "jarvis_envio"
    private const val CHAVE = "envio_sem_toque"

    /** Intervalo entre duas olhadas na tela. */
    private const val PASSO_MS = 350L

    data class Resultado(
        val tentou: Boolean,
        val enviado: Boolean,
        val motivo: String = "",
    )

    /** Ligado por padrão; vale só com o serviço de acessibilidade autorizado. */
    fun ativo(contexto: Context): Boolean = try {
        contexto.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(CHAVE, true)
    } catch (_: Exception) {
        true
    }

    fun definir(contexto: Context, ativo: Boolean) {
        try {
            contexto.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putBoolean(CHAVE, ativo).apply()
        } catch (_: Exception) {
            // Sem armazenamento a preferência volta ao padrão; nada quebra.
        }
    }

    /**
     * Espera a tela do app [pacote] mostrar o [texto] e toca em Enviar.
     *
     * Bloqueia no máximo [esperaMs]; quem chama já está fora da thread da
     * interface. `tentou = false` quando o envio assistido está desligado ou o
     * serviço não está autorizado — nesse caso nada foi procurado.
     */
    fun tentar(
        contexto: Context,
        pacote: String,
        texto: String,
        esperaMs: Long = 9000L,
    ): Resultado {
        if (!ativo(contexto)) return Resultado(false, false, "desligado")
        if (!JarvisAcessibilidade.servicoLigado()) {
            return Resultado(false, false, "sem_servico")
        }
        val corpo = normalizar(texto)
        if (corpo.isEmpty()) return Resultado(false, false, "sem_texto")

        val limite = System.currentTimeMillis() + esperaMs
        var viuTexto = false
        var cliques = 0
        while (System.currentTimeMillis() < limite) {
            try {
                val raiz = JarvisAcessibilidade.raizVisivel()
                if (raiz != null && (pacote.isBlank() ||
                        raiz.packageName?.toString() == pacote)
                ) {
                    val nos = mutableListOf<AccessibilityNodeInfo>()
                    coletar(raiz, nos, 0)
                    val textoNaTela = nos.any {
                        normalizar(it.text?.toString().orEmpty()).contains(corpo.take(40))
                    }
                    if (textoNaTela) {
                        viuTexto = true
                        val botao = nos.firstOrNull { enviar(it) }
                        if (botao != null) {
                            val clicavel = clicavel(botao)
                            val feito = clicavel?.performAction(
                                AccessibilityNodeInfo.ACTION_CLICK
                            ) == true
                            if (feito) {
                                cliques++
                                // A conversa pode aparecer antes do botão ficar
                                // habilitado: confere se o texto saiu do campo
                                // antes de dizer que enviou. Sem isso o toque
                                // era dado com o botão ainda desativado e a
                                // mensagem ficava escrita, sem sair.
                                Thread.sleep(600)
                                val depois = JarvisAcessibilidade.raizVisivel()
                                if (depois != null) {
                                    val restantes = mutableListOf<AccessibilityNodeInfo>()
                                    coletar(depois, restantes, 0)
                                    val aindaNoCampo = restantes.any { no ->
                                        no.isEditable && normalizar(
                                            no.text?.toString().orEmpty()
                                        ).contains(corpo.take(40))
                                    }
                                    if (!aindaNoCampo) return Resultado(true, true)
                                } else {
                                    return Resultado(true, true)
                                }
                                if (cliques >= 3) return Resultado(true, false, "recusado")
                            }
                        }
                    } else if (viuTexto) {
                        // O texto saiu da tela: o app já enviou (ou limpou o
                        // campo). Isso conta como enviado, não como falha.
                        return Resultado(true, true)
                    }
                }
            } catch (_: Exception) {
                // Nó reciclado ou janela trocando; tenta de novo no próximo passo.
            }
            try {
                Thread.sleep(PASSO_MS)
            } catch (_: InterruptedException) {
                return Resultado(true, false, "interrompido")
            }
        }
        return Resultado(true, false, if (viuTexto) "sem_botao" else "sem_texto_na_tela")
    }

    /** Texto para o alto-falante quando o toque não aconteceu. */
    fun explicar(resultado: Resultado): String = when (resultado.motivo) {
        "desligado" -> "O envio sem toque está desligado nas configurações de acessibilidade."
        "sem_servico" -> "O serviço de acessibilidade do JARVIS não está autorizado no Android."
        "recusado" -> "Achei o botão Enviar, mas o app recusou o toque."
        "sem_botao" -> "O texto está na conversa, mas não achei o botão Enviar."
        "sem_texto_na_tela" -> "O app não mostrou o texto a tempo; não toquei em nada."
        "interrompido" -> "O envio assistido foi interrompido."
        else -> "Não consegui tocar em Enviar."
    }

    /** Rótulos de envio nas línguas que o app instala costuma usar. */
    private val ROTULOS = setOf(
        "enviar", "send", "enviar mensagem", "send message", "senden",
        "enviar agora", "send now", "invia",
    )

    private fun enviar(no: AccessibilityNodeInfo): Boolean {
        if (no.isPassword || no.isEditable || !no.isVisibleToUser) return false
        val rotulo = normalizar(no.text?.toString().orEmpty())
        val descricao = normalizar(no.contentDescription?.toString().orEmpty())
        if (rotulo in ROTULOS || descricao in ROTULOS) return true
        if (descricao.startsWith("enviar") || rotulo.startsWith("enviar")) {
            // "Enviar mensagem", "Enviar agora": continua sendo o botão de envio.
            if (!rotulo.contains(" ")) return true
        }
        val id = no.viewIdResourceName?.lowercase(Locale.ROOT).orEmpty()
        return id.endsWith("/send") || id.endsWith("_send") ||
            id.contains("send_button") || id.endsWith("/sendbutton")
    }

    private fun clicavel(no: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        var atual: AccessibilityNodeInfo? = no
        var subiu = 0
        while (atual != null && !atual.isClickable && subiu < 4) {
            atual = atual.parent
            subiu++
        }
        return atual?.takeIf { it.isClickable }
    }

    private fun coletar(
        no: AccessibilityNodeInfo?,
        saida: MutableList<AccessibilityNodeInfo>,
        profundidade: Int,
    ) {
        if (no == null || profundidade > 16 || saida.size >= 200) return
        try {
            if (!no.isPassword && no.isVisibleToUser) saida.add(no)
            for (i in 0 until no.childCount) coletar(no.getChild(i), saida, profundidade + 1)
        } catch (_: Exception) {
            // Ramo reciclado; o resto da tela continua válido.
        }
    }

    private fun normalizar(texto: String): String {
        val semAcento = Normalizer.normalize(texto, Normalizer.Form.NFD)
            .replace(Regex("[\\u0300-\\u036f]"), "")
            .lowercase(Locale.ROOT)
        return semAcento.replace(Regex("\\s+"), " ").trim()
    }
}
