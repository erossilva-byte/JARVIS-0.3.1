package com.jarvis.nova

import android.content.Context
import android.provider.ContactsContract
import java.text.Normalizer
import java.util.Locale
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * Lista de contatos do aparelho e entendimento do nome falado.
 *
 * O contato raramente é salvo como a pessoa fala: “Biaa🩵🩵” no celular, “Bia”
 * na fala, “Beatriz” no documento; “Murilo” salvo, “Murilin” falado. Procurar
 * por texto exato (`LIKE`) só funciona quando o nome é idêntico.
 *
 * Aqui o nome é normalizado (sem acento, sem emoji, sem letra repetida),
 * expandido por apelidos comuns do português e comparado por semelhança. A
 * escolha só é feita quando há **um** melhor candidato: empate vira pergunta
 * com os nomes encontrados, nunca um palpite. Quando o nome falado é diferente
 * do salvo e o contato é único, o par fica guardado — na próxima vez “Murilin”
 * já é o Murilo sem depender da semelhança.
 *
 * O espelho Dart (`lib/core/nome_contato.dart`) usa a mesma tabela e as mesmas
 * notas; o contrato do bloco cobra a paridade.
 */
object JarvisContatos {

    const val PREFS = "jarvis_contatos"
    private const val LIMITE_LISTA = 400
    private const val NOTA_MINIMA = 0.55
    private const val EMPATE = 0.02

    data class Contato(
        val nome: String,
        val telefones: List<String> = emptyList(),
        val emails: List<String> = emptyList(),
    ) {
        val primeiroTelefone: String get() = telefones.firstOrNull().orEmpty()
        val primeiroEmail: String get() = emails.firstOrNull().orEmpty()
    }

    /** Um contato certo, ou os candidatos quando o nome não decide sozinho. */
    data class Escolha(
        val contato: Contato? = null,
        val candidatos: List<Contato> = emptyList(),
    ) {
        val ambiguo: Boolean get() = contato == null && candidatos.size > 1
    }

    /** Apelidos comuns no Brasil: apelido → nomes que ele costuma abreviar. */
    private val APELIDOS: Map<String, List<String>> = mapOf(
        "bia" to listOf("beatriz", "bianca"),
        "bea" to listOf("beatriz", "beatrice"),
        "bibi" to listOf("beatriz", "bianca"),
        "ze" to listOf("jose"),
        "zeca" to listOf("jose"),
        "juca" to listOf("jose", "joaquim"),
        "ana" to listOf("ana", "anna", "anne"),
        "ju" to listOf("julia", "juliana", "juliane", "julio"),
        "duda" to listOf("eduarda", "eduardo"),
        "du" to listOf("eduarda", "eduardo"),
        "manu" to listOf("manuela", "emanuelly", "emanuelle"),
        "isa" to listOf("isabela", "isabel", "isadora"),
        "bel" to listOf("isabela", "isabel"),
        "nanda" to listOf("fernanda"),
        "fer" to listOf("fernanda"),
        "fe" to listOf("fernanda"),
        "vivi" to listOf("viviane", "vitoria"),
        "tati" to listOf("tatiane", "tatiana"),
        "tata" to listOf("tatiane", "tatiana"),
        "rafa" to listOf("rafaela", "rafael"),
        "fafa" to listOf("fabiana", "fabio"),
        "paty" to listOf("patricia"),
        "pati" to listOf("patricia"),
        "dri" to listOf("adriana", "adriane"),
        "cassi" to listOf("cassia", "cassiana"),
        "deby" to listOf("debora"),
        "deborah" to listOf("debora"),
        "lili" to listOf("liliane", "liliana"),
        "leo" to listOf("leonardo", "leonarda"),
        "digo" to listOf("rodrigo"),
        "thi" to listOf("thiago", "tiago"),
        "tiago" to listOf("thiago", "tiago"),
        "mari" to listOf("mariana", "maria"),
        "mary" to listOf("maria", "mariana"),
        "kaka" to listOf("carlos", "carla"),
        "caca" to listOf("carlos", "carla"),
        "gabi" to listOf("gabriela", "gabriel"),
        "gab" to listOf("gabriela", "gabriel"),
        "gui" to listOf("guilherme", "guilhermina"),
        "vitor" to listOf("vitor", "victor"),
        "victor" to listOf("vitor", "victor"),
        "yuri" to listOf("yuri"),
    )

    /** Palavras que decoram o nome salvo e não identificam ninguém. */
    private val ENFEITES = setOf(
        "tia", "tio", "dona", "seu", "sr", "sra", "dr", "dra", "amor",
        "amiga", "amigo", "mae", "pai", "filha", "filho", "irma", "irmao",
        "trabalho", "celular", "whats", "whatsapp", "zap", "pessoal",
        "fixo", "casa", "novo", "nova",
    )

    /** Lista completa, com telefones e e-mails agrupados por contato. */
    fun lista(contexto: Context, limite: Int = LIMITE_LISTA): List<Contato> {
        val porId = LinkedHashMap<Long, Mutable>()
        try {
            contexto.contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(
                    ContactsContract.CommonDataKinds.Phone.CONTACT_ID,
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER,
                ),
                null, null, "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC",
            )?.use { cursor ->
                while (cursor.moveToNext() && porId.size < limite) {
                    val id = cursor.getLong(0)
                    val nome = cursor.getString(1)?.trim().orEmpty()
                    val numero = cursor.getString(2)?.trim().orEmpty()
                    if (nome.isEmpty()) continue
                    val registro = porId.getOrPut(id) { Mutable(nome) }
                    if (numero.isNotEmpty() && !registro.telefones.contains(numero)) {
                        registro.telefones.add(numero)
                    }
                }
            }
        } catch (_: Exception) {
            // Sem permissão de contatos a lista fica vazia; quem chamou explica.
        }
        try {
            contexto.contentResolver.query(
                ContactsContract.CommonDataKinds.Email.CONTENT_URI,
                arrayOf(
                    ContactsContract.CommonDataKinds.Email.CONTACT_ID,
                    ContactsContract.CommonDataKinds.Email.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Email.ADDRESS,
                ),
                null, null, null,
            )?.use { cursor ->
                while (cursor.moveToNext() && porId.size < limite) {
                    val id = cursor.getLong(0)
                    val nome = cursor.getString(1)?.trim().orEmpty()
                    val endereco = cursor.getString(2)?.trim().orEmpty()
                    if (nome.isEmpty() || endereco.isEmpty()) continue
                    val registro = porId.getOrPut(id) { Mutable(nome) }
                    if (!registro.emails.contains(endereco)) registro.emails.add(endereco)
                }
            }
        } catch (_: Exception) {
            // Sem e-mails o telefone continua valendo.
        }
        return porId.values.map { it.paraContato() }
    }

    /** Escolhe o contato do nome falado; empate devolve os candidatos. */
    fun resolver(contexto: Context, dito: String): Escolha {
        val alvo = normalizar(dito)
        if (alvo.isEmpty()) return Escolha()
        // Número dito na hora vale como contato, sem procurar na agenda.
        val digitos = dito.filter { it.isDigit() || it == '+' }
        if (dito.none { it.isLetter() } && digitos.count { it.isDigit() } >= 8) {
            return Escolha(Contato(dito.trim(), listOf(digitos)))
        }
        val contatos = lista(contexto)
        if (contatos.isEmpty()) return Escolha()

        // Apelido já aprendido neste aparelho vale como acerto exato.
        val aprendido = prefs(contexto).getString(alvo, null)
        if (!aprendido.isNullOrBlank()) {
            contatos.firstOrNull { normalizar(it.nome) == aprendido }
                ?.let { return Escolha(it) }
        }

        val notas = contatos.map { it to pontuar(alvo, it.nome) }
            .filter { it.second >= NOTA_MINIMA }
            .sortedByDescending { it.second }
        if (notas.isEmpty()) return Escolha()

        val melhor = notas.first().second
        var empatados = notas.filter { melhor - it.second <= EMPATE }
        if (empatados.size > 1) {
            // "Murilo" e "Murilo Silva": o mais curto é o nome base do contato.
            val primeiro = normalizar(empatados.first().first.nome)
            val todosComPrefixo = empatados.all {
                val outro = normalizar(it.first.nome)
                outro.startsWith(primeiro) || primeiro.startsWith(outro)
            }
            if (todosComPrefixo) {
                empatados = listOf(empatados.minByOrNull { it.first.nome.length }!!)
            } else {
                return Escolha(candidatos = empatados.take(5).map { it.first })
            }
        }
        val escolhido = empatados.first().first
        if (melhor < 0.99) aprender(contexto, alvo, normalizar(escolhido.nome))
        return Escolha(escolhido)
    }

    /** Contatos que combinam com o texto, do mais parecido para o menos. */
    fun buscar(contexto: Context, dito: String, limite: Int = 20): List<Contato> {
        val alvo = normalizar(dito)
        val contatos = lista(contexto)
        if (alvo.isEmpty()) return contatos.take(limite)
        return contatos.map { it to pontuar(alvo, it.nome) }
            .filter { it.second > 0.0 }
            .sortedByDescending { it.second }
            .take(limite)
            .map { it.first }
    }

    /** Apelidos já aprendidos: apelido normalizado → nome normalizado. */
    fun apelidos(contexto: Context): Map<String, String> = try {
        prefs(contexto).all.mapNotNull { (chave, valor) ->
            if (valor is String) chave to valor else null
        }.toMap()
    } catch (_: Exception) {
        emptyMap()
    }

    /** Esquece um apelido ensinado; o nome salvo continua valendo. */
    fun esquecer(contexto: Context, apelido: String) {
        val alvo = normalizar(apelido)
        if (alvo.isEmpty()) return
        try {
            prefs(contexto).edit().remove(alvo).apply()
        } catch (_: Exception) {
            // Sem armazenamento o apelido apenas não existia mais.
        }
    }

    /** Guarda “Murilin” → “murilo” para o próximo pedido ser direto. */
    fun aprender(contexto: Context, dito: String, nomeNormalizado: String) {
        val alvo = normalizar(dito)
        if (alvo.isEmpty() || nomeNormalizado.isBlank()) return
        try {
            prefs(contexto).edit().putString(alvo, nomeNormalizado).apply()
        } catch (_: Exception) {
            // Sem armazenamento a semelhança continua resolvendo na hora.
        }
    }

    /** Minúsculas, sem acento, sem emoji e sem letra repetida. */
    fun normalizar(texto: String): String {
        val semAcento = Normalizer.normalize(texto, Normalizer.Form.NFD)
            .replace(Regex("[\\u0300-\\u036f]"), "")
            .lowercase(Locale.ROOT)
        val limpo = semAcento.replace(Regex("[^a-z0-9 ]+"), " ")
            .replace(Regex("\\s+"), " ")
            .trim()
        val compacto = StringBuilder()
        var anterior = ' '
        for (c in limpo) {
            if (c == ' ' || c != anterior) compacto.append(c)
            anterior = c
        }
        return compacto.toString().trim()
    }

    /** Nome completo, cada palavra, apelidos e a raiz sem a vogal final. */
    fun variantes(nome: String): Set<String> {
        val base = normalizar(nome)
        if (base.isEmpty()) return emptySet()
        val saida = LinkedHashSet<String>()
        saida.add(base)
        val palavras = base.split(' ').filter { it.isNotEmpty() && it !in ENFEITES }
        if (palavras.isEmpty()) return saida
        saida.add(palavras.joinToString(" "))
        saida.add(palavras.first())
        for (palavra in palavras) {
            saida.add(palavra)
            raiz(palavra)?.let { saida.add(it) }
            APELIDOS[palavra]?.let { saida.addAll(it) }
            for ((apelido, nomes) in APELIDOS) {
                if (palavra in nomes) saida.add(apelido)
            }
        }
        return saida
    }

    /** “Murilo” → “muril”, “Beatriz” → “beatri”: aproxima o diminutivo falado. */
    private fun raiz(palavra: String): String? {
        var p = palavra
        for (sufixo in listOf("zinho", "zinha", "inho", "inha")) {
            if (p.length > sufixo.length + 2 && p.endsWith(sufixo)) {
                p = p.dropLast(sufixo.length)
            }
        }
        if (p.length >= 5 && (p.endsWith("a") || p.endsWith("o") || p.endsWith("e"))) {
            return p.dropLast(1)
        }
        return null
    }

    /** Nota de 0 a 1 entre o nome falado e o nome salvo. */
    fun pontuar(dito: String, salvo: String): Double {
        val alvos = variantes(dito)
        val nomes = variantes(salvo)
        var melhor = 0.0
        for (a in alvos) {
            for (n in nomes) {
                val nota = comparar(a, n)
                if (nota > melhor) melhor = nota
            }
        }
        return melhor
    }

    private fun comparar(a: String, n: String): Double {
        if (a == n) return 1.0
        if (a.length < 3 || n.length < 3) return 0.0
        if (n.startsWith(a)) return 0.90
        if (a.startsWith(n)) return 0.88
        if (Regex("\\b${Regex.escape(a)}\\b").containsMatchIn(n)) return 0.85
        val distancia = distancia(a, n)
        val maior = max(a.length, n.length)
        val limite = when {
            maior <= 4 -> 1
            maior <= 7 -> 2
            else -> 3
        }
        if (distancia > limite) return 0.0
        val base = 0.78 - distancia * 0.06
        return if (a.first() == n.first()) base else base - 0.12
    }

    /** Distância de edição, com teto para não gastar tempo em nomes enormes. */
    fun distancia(a: String, b: String): Int {
        if (a == b) return 0
        val x = a.take(40)
        val y = b.take(40)
        var anterior = IntArray(y.length + 1) { it }
        var atual = IntArray(y.length + 1)
        for (i in 1..x.length) {
            atual[0] = i
            for (j in 1..y.length) {
                val custo = if (x[i - 1] == y[j - 1]) 0 else 1
                atual[j] = min(min(atual[j - 1] + 1, anterior[j] + 1), anterior[j - 1] + custo)
            }
            val troca = anterior
            anterior = atual
            atual = troca
        }
        return anterior[y.length]
    }

    private class Mutable(val nome: String) {
        val telefones = mutableListOf<String>()
        val emails = mutableListOf<String>()
        fun paraContato() = Contato(nome, telefones.toList(), emails.toList())
    }

    private fun prefs(contexto: Context) =
        contexto.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
