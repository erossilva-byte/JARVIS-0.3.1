package com.jarvis.nova

import android.app.Notification
import android.app.RemoteInput
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.time.Instant

/**
 * Guarda as notificações do aparelho em memória para o Jarvis consultar e,
 * quando a notificação tem campo de resposta (WhatsApp, Telegram, SMS, Signal…),
 * responde **sem abrir o aplicativo**, pelo `RemoteInput` da própria notificação.
 *
 * O serviço só recebe eventos depois que o usuário autoriza o acesso em
 * Configurações → Notificações → Acesso a notificações. Nada é gravado em disco
 * e nada é enviado para a rede: a lista vive só enquanto o processo existe, é
 * limitada a [limite] itens e as respondíveis a [limiteRespostas].
 */
class JarvisNotificacaoListener : NotificationListenerService() {

    companion object {
        const val limite = 80
        const val limiteRespostas = 40

        private val recentes = ArrayDeque<Map<String, Any>>()

        /** Notificação viva, por chave, para responder depois (RemoteInput). */
        private val respondiveis = LinkedHashMap<String, StatusBarNotification>()

        /**
         * O serviço conectado. Sem ele não há `PendingIntent` de onde enviar a
         * resposta, então a recusa é explícita em vez de fingir que enviou.
         */
        @Volatile
        private var instancia: JarvisNotificacaoListener? = null

        /**
         * Reconexão pedida pela tela: o serviço conectado faz o `requestRebind`.
         * Sem instância não há o que reconectar — a próxima notificação religa.
         */
        @JvmStatic
        fun reconectar() {
            instancia?.pedirReconexao()
        }

        @JvmStatic
        fun lista(): List<Map<String, Any>> = synchronized(recentes) {
            recentes.toList().asReversed()
        }

        @JvmStatic
        fun limpar() = synchronized(recentes) { recentes.clear() }

        @JvmStatic
        fun remover(pacote: String) = synchronized(recentes) {
            recentes.removeAll { it["pacote"] == pacote }
        }

        @JvmStatic
        fun registrar(item: Map<String, Any>) = synchronized(recentes) {
            recentes.addLast(item)
            while (recentes.size > limite) recentes.removeFirst()
        }

        @JvmStatic
        fun temRespondivel(): Boolean = synchronized(respondiveis) {
            respondiveis.isNotEmpty()
        }

        /** A ação "Responder" da notificação, quando existe. */
        private fun acaoDeResposta(notificacao: Notification): Notification.Action? =
            notificacao.actions?.firstOrNull { acao ->
                acao.actionIntent != null && !acao.remoteInputs.isNullOrEmpty()
            }

        private fun guardarRespondivel(chave: String, sbn: StatusBarNotification) {
            synchronized(respondiveis) {
                respondiveis.remove(chave)
                respondiveis[chave] = sbn
                while (respondiveis.size > limiteRespostas) {
                    val primeira = respondiveis.keys.firstOrNull() ?: break
                    respondiveis.remove(primeira)
                }
            }
        }

        private fun esquecer(chave: String) {
            synchronized(respondiveis) { respondiveis.remove(chave) }
        }

        private fun nomeDoPacote(contexto: Context, pacote: String): String = try {
            val info = contexto.packageManager.getApplicationInfo(pacote, 0)
            contexto.packageManager.getApplicationLabel(info).toString()
        } catch (_: Exception) {
            pacote
        }

        /**
         * Injeta [texto] na notificação [chave] (ou na mais recente do [pacote])
         * pelo campo de resposta do sistema. Devolve o que aconteceu de verdade.
         */
        @JvmStatic
        fun responder(chave: String, texto: String, pacote: String?): Map<String, Any> {
            val limpo = texto.trim()
            if (limpo.isEmpty()) {
                return mapOf(
                    "ok" to false,
                    "mensagem" to "Escreva a resposta antes de enviar."
                )
            }
            val servico = instancia ?: return mapOf(
                "ok" to false,
                "mensagem" to "O acesso às notificações não está ativo agora. " +
                    "Abra o JARVIS, autorize o acesso e tente de novo."
            )
            val alvo = synchronized(respondiveis) {
                respondiveis[chave]
                    ?: respondiveis.entries.lastOrNull {
                        pacote.isNullOrEmpty() || it.value.packageName == pacote
                    }?.value
            } ?: return mapOf(
                "ok" to false,
                "mensagem" to "Nenhuma mensagem com campo de resposta disponível agora. " +
                    "Peça outra mensagem ao remetente ou abra o aplicativo."
            )
            val notificacao = alvo.notification ?: return mapOf(
                "ok" to false,
                "mensagem" to "A notificação não está mais disponível para resposta."
            )
            val acao = acaoDeResposta(notificacao) ?: return mapOf(
                "ok" to false,
                "mensagem" to "Esta notificação não aceita resposta direta."
            )
            val entrada = acao.remoteInputs?.firstOrNull() ?: return mapOf(
                "ok" to false,
                "mensagem" to "A notificação não informou o campo de resposta."
            )
            val resultado = entrada.resultKey
            if (resultado.isNullOrBlank()) {
                return mapOf(
                    "ok" to false,
                    "mensagem" to "A notificação não informou o campo de resposta."
                )
            }
            return try {
                val dados = Bundle().apply { putCharSequence(resultado, limpo) }
                // O Intent vazio só carrega os resultados; quem entrega é o
                // PendingIntent da própria notificação.
                val preenchido = Intent()
                RemoteInput.addResultsToIntent(arrayOf(entrada), preenchido, dados)
                acao.actionIntent.send(servico, 0, preenchido)
                mapOf(
                    "ok" to true,
                    "mensagem" to "Resposta enviada pelo campo da notificação de " +
                        nomeDoPacote(servico, alvo.packageName) + "."
                )
            } catch (erro: Exception) {
                mapOf(
                    "ok" to false,
                    "mensagem" to "O aplicativo recusou a resposta: " +
                        (erro.message ?: erro.javaClass.simpleName) + "."
                )
            }
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        instancia = this
        // Sem isto a lista nasce vazia e só enche quando chega uma notificação
        // nova: quem autoriza o acesso e volta para o app não vê nada, mesmo
        // havendo notificações na barra. As ativas são lidas uma vez aqui.
        try {
            val ativas = activeNotifications ?: emptyArray()
            for (sbn in ativas) {
                try {
                    guardar(sbn)
                } catch (_: Exception) {
                    // Uma notificação ilegível não impede as outras.
                }
            }
        } catch (_: Exception) {
            // Serviço sem permissão de listar ativas: os eventos novos bastam.
        }
    }

    /**
     * Pede ao Android para reconectar o serviço quando ele está autorizado mas
     * o processo foi encerrado. Sem isso, "acesso autorizado" e lista vazia
     * convivem até o usuário reiniciar o aparelho.
     */
    private fun pedirReconexao() {
        try {
            requestRebind(android.content.ComponentName(
                "com.jarvis.nova", "com.jarvis.nova.JarvisNotificacaoListener"
            ))
        } catch (_: Exception) {
            // Versão antiga do Android: a próxima notificação reconecta.
        }
    }

    /** Extrai e guarda uma notificação; usado pelo evento e pela leitura inicial. */
    private fun guardar(n: StatusBarNotification) {
        if (n.packageName == packageName) return
        val notificacao = n.notification ?: return
        if (notificacao.flags and Notification.FLAG_ONGOING_EVENT != 0) return
        val extras = notificacao.extras ?: return
        val titulo = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val texto = (extras.getCharSequence(Notification.EXTRA_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_BIG_TEXT))?.toString().orEmpty()
        if (titulo.isBlank() && texto.isBlank()) return
        val responde = acaoDeResposta(notificacao) != null
        registrar(
            mapOf(
                "app" to nomeDoPacote(this, n.packageName),
                "pacote" to n.packageName,
                "chave" to n.key,
                "titulo" to titulo,
                "texto" to texto,
                "respondivel" to responde,
                "hora" to Instant.ofEpochMilli(n.postTime).toString(),
            )
        )
        if (responde) guardarRespondivel(n.key, n) else esquecer(n.key)
    }

    override fun onListenerDisconnected() {
        if (instancia === this) instancia = null
        super.onListenerDisconnected()
    }

    override fun onDestroy() {
        if (instancia === this) instancia = null
        super.onDestroy()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val n = sbn ?: return
        guardar(n)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        val n = sbn ?: return
        esquecer(n.key)
        // Remove só as antigas desse app; as novas continuam na lista.
        synchronized(recentes) {
            val doApp = recentes.filter { it["pacote"] == n.packageName }
            if (doApp.isNotEmpty()) recentes.remove(doApp.first())
        }
    }
}
