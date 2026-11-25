package com.jarvis.nova

/**
 * PIN dito em voz alta não entra no histórico de execuções.
 *
 * A mesma regra do Dart (`lib/core/segredo_pedido.dart`): sequência isolada de
 * 4 a 8 dígitos vira `[oculto]`. Ela é aplicada dentro do `JarvisFundo.anotar`,
 * funil por onde passa todo registro — o comando da tela (pelo canal) e o do
 * serviço de segundo plano. Assim nenhum caminho grava o PIN por esquecimento.
 *
 * Telefone (9+ dígitos) e hora (“às 9”) não são mascarados: não cabem num PIN
 * deste app e tiram a explicação do comando.
 */
object JarvisSegredo {

    const val OCULTO = "[oculto]"

    private val SEQUENCIA_DE_PIN = Regex("(?<!\\d)\\d{4,8}(?!\\d)")

    /** Devolve o texto sem nenhum PIN ditado. */
    fun ocultarPin(texto: String): String =
        SEQUENCIA_DE_PIN.replace(texto, OCULTO)
}
