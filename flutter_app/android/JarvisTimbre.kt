package com.jarvis.nova

import android.content.Context

/**
 * Perfis de timbre da voz, guardados no próprio aparelho.
 *
 * O tom e o ritmo são os mesmos valores de `core/timbre_voz.dart`; o teste
 * `tests/test_timbre_flutter.py` confere a paridade para a tela não prometer um
 * timbre diferente do que a síntese usa.
 *
 * O grave é o timbre original do app (0,72 / 0,88). Nada aqui envia dados e
 * nenhum perfil cria voz nova: só ajusta `setPitch` e `setSpeechRate`.
 */
object JarvisTimbre {
    const val PREFS = "jarvis_voz"
    private const val CHAVE = "timbre"

    const val PADRAO = "grave"

    data class Perfil(
        val id: String,
        val nome: String,
        val pitch: Float,
        val velocidade: Float,
    )

    val PERFIS = listOf(
        Perfil("grave", "Grave", 0.72f, 0.88f),
        Perfil("natural", "Natural", 1.0f, 1.0f),
        Perfil("agil", "Ágil", 1.15f, 1.12f),
    )

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun perfil(id: String?): Perfil =
        PERFIS.firstOrNull { it.id == id?.trim()?.lowercase() } ?: PERFIS.first()

    /** Perfil gravado no aparelho (padrão quando nunca escolheram). */
    fun id(context: Context): String =
        perfil(prefs(context).getString(CHAVE, PADRAO)).id

    /** Grava o perfil e devolve o id realmente guardado. */
    fun definir(context: Context, id: String?): String {
        val seguro = perfil(id).id
        prefs(context).edit().putString(CHAVE, seguro).apply()
        return seguro
    }

    /** Estado para a tela: id atual e a lista com tom e ritmo. */
    fun estado(context: Context): Map<String, Any> = mapOf(
        "timbre" to id(context),
        "padrao" to PADRAO,
        "perfis" to PERFIS.map { perfil ->
            mapOf(
                "id" to perfil.id,
                "nome" to perfil.nome,
                "pitch" to perfil.pitch,
                "velocidade" to perfil.velocidade,
            )
        },
    )
}
