package com.jarvis.nova

import android.accessibilityservice.AccessibilityService
import android.app.Activity
import android.content.Intent
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.Normalizer
import java.util.Locale

/**
 * Automação de tela por acessibilidade, com escopo estreito e consentimento.
 *
 * Só funciona depois de duas coisas: o serviço autorizado em
 * Configurações ▸ Acessibilidade ▸ JARVIS Nova e o interruptor “Ler a tela”
 * ligado dentro do app. O app confere o interruptor antes de chamar qualquer
 * método daqui; este serviço é só o executor.
 *
 * Escopo fechado: ler os textos visíveis, tocar num elemento pelo texto e
 * rolar a tela. Não digita, não usa coordenadas livres, não abre intents
 * arbitrárias, não lê campo de senha nem o conteúdo já digitado num campo de
 * texto.
 */
class JarvisAcessibilidade : AccessibilityService() {

    companion object {
        const val CANAL = "com.jarvis.nova/acessibilidade"

        /** Teto de nós por leitura: uma tela de conversa tem poucos elementos úteis. */
        const val limiteDeNos = 120

        private const val profundidadeMaxima = 18
        private const val limiteDeTexto = 180

        @Volatile
        private var instancia: JarvisAcessibilidade? = null

        @Volatile
        private var pacoteAtual = ""

        /** “Parar” vale para a próxima ação; nada roda em laço. */
        @Volatile
        private var cancelado = false

        fun servicoLigado() = instancia != null

        fun status(): Map<String, Any> = mapOf(
            "ligado" to servicoLigado(),
            "pacote" to pacoteAtual,
            "limite" to limiteDeNos
        )

        fun parar(): Map<String, Any> {
            cancelado = true
            return mapOf(
                "ok" to true,
                "mensagem" to "Automação interrompida. Nenhuma nova ação de tela será executada."
            )
        }

        fun ler(): Map<String, Any> {
            val servico = instancia ?: return desligado()
            cancelado = false
            val raiz = raiz(servico)
                ?: return mapOf(
                    "ok" to false,
                    "pacote" to pacoteAtual,
                    "erro" to "Não há uma janela ativa para ler."
                )
            val nos = mutableListOf<Map<String, Any>>()
            coletar(raiz, nos, 0)
            return mapOf(
                "ok" to true,
                "pacote" to pacoteAtual,
                "nos" to nos,
                "quantidade" to nos.size,
                "limitado" to (nos.size >= limiteDeNos)
            )
        }

        fun tocar(texto: String, ocorrencia: Int): Map<String, Any> {
            val servico = instancia ?: return desligado()
            val procurado = normalizar(texto)
            if (procurado.isEmpty()) {
                return mapOf("ok" to false, "erro" to "Diga o texto do botão que devo tocar.")
            }
            cancelado = false
            val raiz = raiz(servico)
                ?: return mapOf("ok" to false, "erro" to "Não há uma janela ativa para tocar.")
            val achados = mutableListOf<AccessibilityNodeInfo>()
            buscar(raiz, procurado, achados, 0)
            if (achados.isEmpty()) {
                return mapOf(
                    "ok" to false,
                    "pacote" to pacoteAtual,
                    "erro" to "Não encontrei nenhum elemento visível com esse texto."
                )
            }
            if (cancelado) {
                return mapOf("ok" to false, "erro" to "Automação interrompida antes do toque.")
            }
            val alvo = achados[ocorrencia.coerceIn(0, achados.size - 1)]
            var clicavel: AccessibilityNodeInfo? = alvo
            var subiu = 0
            while (clicavel != null && !clicavel.isClickable && subiu < 5) {
                clicavel = clicavel.parent
                subiu++
            }
            val feito = clicavel?.isClickable == true &&
                clicavel.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            return mapOf(
                "ok" to feito,
                "pacote" to pacoteAtual,
                "texto" to textoDe(alvo),
                "mensagem" to if (feito) {
                    "Toquei em \"${textoDe(alvo)}\"."
                } else {
                    "O elemento foi encontrado, mas o aplicativo recusou o toque."
                },
                "erro" to if (feito) "" else "O aplicativo recusou o toque nesse elemento."
            )
        }

        fun rolar(paraCima: Boolean): Map<String, Any> {
            val servico = instancia ?: return desligado()
            cancelado = false
            val raiz = raiz(servico)
                ?: return mapOf("ok" to false, "erro" to "Não há uma janela ativa para rolar.")
            val area = rolavel(raiz, 0)
                ?: return mapOf("ok" to false, "erro" to "Não encontrei uma área rolável nesta tela.")
            val acao = if (paraCima) {
                AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
            } else {
                AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
            }
            val feito = area.performAction(acao)
            return mapOf(
                "ok" to feito,
                "pacote" to pacoteAtual,
                "mensagem" to if (feito) {
                    if (paraCima) "Rolei a tela para cima." else "Rolei a tela para baixo."
                } else {
                    "A área rolável recusou a rolagem."
                },
                "erro" to if (feito) "" else "A área rolável recusou a rolagem."
            )
        }

        private fun desligado() = mapOf(
            "ok" to false,
            "pacote" to pacoteAtual,
            "erro" to "O serviço de acessibilidade está desligado. " +
                "Ative em Configurações ▸ Acessibilidade ▸ JARVIS Nova."
        )

        private fun raiz(servico: JarvisAcessibilidade): AccessibilityNodeInfo? {
            try {
                servico.rootInActiveWindow?.let { return it }
                servico.windows?.forEach { janela ->
                    janela?.root?.let { return it }
                }
            } catch (_: Exception) {
                // Sem janela ativa o Android lança; a tela só não tem o que ler.
            }
            return null
        }

        private fun textoDe(no: AccessibilityNodeInfo): String {
            if (no.isPassword) return ""
            val texto = no.text?.toString()?.trim().orEmpty()
            if (texto.isNotEmpty()) return texto
            return no.contentDescription?.toString()?.trim().orEmpty()
        }

        private fun visivel(no: AccessibilityNodeInfo): Boolean {
            return try {
                val area = Rect()
                no.getBoundsInScreen(area)
                no.isVisibleToUser && area.width() > 0 && area.height() > 0
            } catch (_: Exception) {
                false
            }
        }

        private fun normalizar(texto: String): String {
            val semAcento = Normalizer.normalize(texto, Normalizer.Form.NFD)
                .replace(Regex("[\\u0300-\\u036f]"), "")
                .lowercase(Locale.ROOT)
            return semAcento.replace(Regex("[^a-z0-9 ]+"), " ")
                .replace(Regex("\\s+"), " ")
                .trim()
        }

        /**
         * Lista só o que a tela mostra como texto ou ação. Campo de senha some
         * inteiro; campo de texto entra como “campo de texto”, sem o conteúdo.
         */
        private fun coletar(
            no: AccessibilityNodeInfo?,
            saida: MutableList<Map<String, Any>>,
            profundidade: Int
        ) {
            if (no == null || profundidade > profundidadeMaxima || saida.size >= limiteDeNos) return
            try {
                if (visivel(no) && !no.isPassword) {
                    val editavel = no.isEditable
                    val texto = if (editavel) "" else textoDe(no)
                    if (texto.isNotEmpty() || editavel || no.isClickable || no.isScrollable) {
                        saida.add(
                            mapOf(
                                "texto" to if (editavel) "campo de texto" else texto.take(limiteDeTexto),
                                "pacote" to (no.packageName?.toString() ?: ""),
                                "clicavel" to no.isClickable,
                                "rolavel" to no.isScrollable,
                                "campo" to editavel
                            )
                        )
                    }
                }
                for (indice in 0 until no.childCount) {
                    coletar(no.getChild(indice), saida, profundidade + 1)
                    if (saida.size >= limiteDeNos) return
                }
            } catch (_: Exception) {
                // Um nó pode morrer entre a leitura e o acesso; o resto da tela continua válido.
            }
        }

        /** Junta elementos cujo texto contém o procurado, sem entrar em senha ou campo de texto. */
        private fun buscar(
            no: AccessibilityNodeInfo?,
            procurado: String,
            saida: MutableList<AccessibilityNodeInfo>,
            profundidade: Int
        ) {
            if (no == null || profundidade > profundidadeMaxima || saida.size >= limiteDeNos) return
            try {
                if (!no.isPassword && !no.isEditable && visivel(no)) {
                    val texto = normalizar(textoDe(no))
                    if (texto.isNotEmpty() && texto.contains(procurado)) saida.add(no)
                }
                for (indice in 0 until no.childCount) {
                    buscar(no.getChild(indice), procurado, saida, profundidade + 1)
                }
            } catch (_: Exception) {
                // Nó reciclado pelo aplicativo; ignora este ramo.
            }
        }

        private fun rolavel(no: AccessibilityNodeInfo?, profundidade: Int): AccessibilityNodeInfo? {
            if (no == null || profundidade > profundidadeMaxima) return null
            try {
                if (no.isScrollable && visivel(no)) return no
                for (indice in 0 until no.childCount) {
                    rolavel(no.getChild(indice), profundidade + 1)?.let { return it }
                }
            } catch (_: Exception) {
                // Ramo inacessível; segue para o próximo.
            }
            return null
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instancia = this
        cancelado = false
        try {
            serviceInfo?.apply {
                eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                    AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
                feedbackType = android.accessibilityservice.AccessibilityServiceInfo.FEEDBACK_GENERIC
                notificationTimeout = 100
                flags = flags or
                    android.accessibilityservice.AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    android.accessibilityservice.AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
                setServiceInfo(this)
            }
        } catch (_: Exception) {
            // A configuração do XML já basta; o ajuste em memória é opcional.
        }
    }

    override fun onAccessibilityEvent(evento: AccessibilityEvent?) {
        val pacote = evento?.packageName?.toString().orEmpty()
        if (pacote.isNotEmpty() && pacote != "com.jarvis.nova") pacoteAtual = pacote
    }

    override fun onInterrupt() {
        cancelado = true
    }

    override fun onDestroy() {
        if (instancia === this) instancia = null
        super.onDestroy()
    }
}

/**
 * Canal `com.jarvis.nova/acessibilidade`.
 *
 * A leitura da árvore pode levar dezenas de milissegundos; ela roda numa thread
 * própria e a resposta volta para a thread principal, como o Flutter espera.
 */
class JarvisAcessibilidadeCanal(private val activity: Activity) {

    fun registrar(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, JarvisAcessibilidade.CANAL)
            .setMethodCallHandler { chamada, resultado ->
                if (chamada.method == "abrirConfiguracoes") {
                    resultado.success(abrirConfiguracoes())
                    return@setMethodCallHandler
                }
                val metodo = chamada.method
                val texto = chamada.argument<String>("texto").orEmpty()
                val ocorrencia = chamada.argument<Number>("ocorrencia")?.toInt() ?: 0
                val paraCima = chamada.argument<Boolean>("paraCima") == true
                Thread {
                    val resposta: Map<String, Any> = try {
                        when (metodo) {
                            "status" -> JarvisAcessibilidade.status()
                            "ler" -> JarvisAcessibilidade.ler()
                            "tocar" -> JarvisAcessibilidade.tocar(texto, ocorrencia)
                            "rolar" -> JarvisAcessibilidade.rolar(paraCima)
                            "parar" -> JarvisAcessibilidade.parar()
                            else -> mapOf("ok" to false, "erro" to "Ação de tela desconhecida.")
                        }
                    } catch (erro: Exception) {
                        mapOf(
                            "ok" to false,
                            "erro" to "Falha na automação de tela: " +
                                (erro.message ?: erro.javaClass.simpleName)
                        )
                    }
                    Handler(Looper.getMainLooper()).post { resultado.success(resposta) }
                }.start()
            }
    }

    private fun abrirConfiguracoes(): Map<String, Any> = try {
        val intencao = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        intencao.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        activity.startActivity(intencao)
        mapOf("ok" to true)
    } catch (_: Exception) {
        mapOf("ok" to false, "erro" to "Não consegui abrir as configurações de acessibilidade do Android.")
    }
}
