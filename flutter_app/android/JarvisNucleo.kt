package com.jarvis.nova

import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.OvershootInterpolator
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.random.Random

/**
 * Núcleo flutuante — a bolha 3D do JARVIS por cima dos outros apps.
 *
 * Como os mascotes de desktop, ele fica pequeno no canto, se mexe sozinho e some
 * para reaparecer em outro ponto. Aqui não há motor 3D nem modelo importado: a
 * malha geodésica é calculada no aparelho, girada em três eixos e projetada em
 * perspectiva, como o avatar da tela. O que se move é a janela do Android; a
 * animação de sumir e voltar é escala e transparência no próprio desenho.
 *
 * Exige “Exibir sobre outros apps”. Sem essa autorização, [iniciar] devolve
 * `iniciado = false` com o motivo — nada é desenhado por cima de ninguém.
 */
object JarvisNucleo {
    private const val CANAL = "com.jarvis.nova/nucleo"
    private const val TAMANHO_PADRAO_DP = 112
    private const val INTERVALO_PADRAO_MS = 7_000L
    private const val FOLGA_DP = 8
    private const val PAUSA_APOS_ARRASTO_MS = 2_500L

    private var app: Context? = null
    private var janela: WindowManager? = null
    private var vista: NucleoView? = null
    private var parametros: WindowManager.LayoutParams? = null
    private var ativo = false
    private var tamanhoDp = TAMANHO_PADRAO_DP
    private var intervaloMs = INTERVALO_PADRAO_MS
    private var arrastando = false

    private val principal = Handler(Looper.getMainLooper())
    private val soltar = Runnable {
        arrastando = false
        agendarTeletransporte()
    }
    private val teletransportarSozinho = object : Runnable {
        override fun run() {
            if (!ativo) return
            if (!arrastando) teletransportar()
            agendarTeletransporte()
        }
    }

    fun estado(contexto: Context): Map<String, Any> = mapOf(
        "ativo" to ativo,
        "tamanho" to tamanhoDp,
        "intervalo" to intervaloMs.toInt(),
        "permissao" to podeSobrepor(contexto),
    )

    /**
     * Sobe a janela flutuante. Devolve o estado com `iniciado` e, quando falha,
     * um `motivo` curto (`sem_permissao`), para a tela dizer o que falta.
     */
    fun iniciar(contexto: Context, tamanho: Int, intervalo: Long): Map<String, Any> {
        tamanhoDp = tamanho.coerceIn(72, 160)
        intervaloMs = intervalo.coerceIn(3_000L, 15_000L)
        if (!podeSobrepor(contexto)) {
            return estado(contexto) + mapOf("iniciado" to false, "motivo" to "sem_permissao")
        }
        // Já na tela: recria com o tamanho e o ritmo novos, em vez de ignorar
        // a mudança que a tela acabou de pedir.
        if (ativo) parar()
        return try {
            val base = contexto.applicationContext
            val gerenciador =
                base.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val densidade = base.resources.displayMetrics.density
            val lado = (tamanhoDp * densidade).toInt().coerceAtLeast(1)
            val tipo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                WindowManager.LayoutParams.TYPE_PHONE
            }
            val layout = WindowManager.LayoutParams(
                lado,
                lado,
                tipo,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                x = (FOLGA_DP * densidade).toInt()
                y = (120 * densidade).toInt()
            }
            val desenho = NucleoView(base).apply {
                aoArrastar = { dx, dy -> arrastarNaTela(dx, dy) }
                aoTocar = { abrirApp() }
            }
            gerenciador.addView(desenho, layout)
            app = base
            janela = gerenciador
            vista = desenho
            parametros = layout
            ativo = true
            moverParaPontoAleatorio()
            agendarTeletransporte()
            estado(contexto) + mapOf("iniciado" to true, "motivo" to "")
        } catch (_: Exception) {
            parar()
            estado(contexto) + mapOf("iniciado" to false, "motivo" to "falhou")
        }
    }

    /** Tira o núcleo da tela e esquece a janela. */
    fun parar() {
        principal.removeCallbacks(teletransportarSozinho)
        principal.removeCallbacks(soltar)
        ativo = false
        arrastando = false
        val desenho = vista
        val gerenciador = janela
        vista = null
        parametros = null
        janela = null
        app = null
        if (desenho != null && gerenciador != null) {
            try {
                gerenciador.removeView(desenho)
            } catch (_: Exception) {
                // A janela já pode ter sido removida pelo sistema.
            }
        }
    }

    /** Teletransporte pedido pela tela (e pelo toque longo, se houver). */
    fun teletransportar() {
        val desenho = vista ?: return
        if (!ativo) return
        desenho.animate().cancel()
        desenho.animate()
            .alpha(0f)
            .scaleX(0.18f)
            .scaleY(0.18f)
            .setDuration(170)
            .withEndAction {
                moverParaPontoAleatorio()
                desenho.piscar()
                desenho.scaleX = 0.32f
                desenho.scaleY = 0.32f
                desenho.alpha = 1f
                desenho.animate()
                    .scaleX(1f)
                    .scaleY(1f)
                    .setDuration(340)
                    .setInterpolator(OvershootInterpolator(1.8f))
                    .start()
            }
            .start()
    }

    /** Arrasto do dedo: move a janela junto, sem sair da área visível. */
    fun arrastarNaTela(dx: Float, dy: Float) {
        val desenho = vista ?: return
        val layout = parametros ?: return
        val gerenciador = janela ?: return
        layout.x += dx.toInt()
        layout.y += dy.toInt()
        limitar(layout)
        try {
            gerenciador.updateViewLayout(desenho, layout)
        } catch (_: Exception) {
            return
        }
        arrastando = true
        principal.removeCallbacks(soltar)
        principal.postDelayed(soltar, PAUSA_APOS_ARRASTO_MS)
    }

    fun abrirAjuste(contexto: Context) {
        try {
            contexto.startActivity(
                Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:" + contexto.packageName),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        } catch (_: Exception) {
            // Alguns aparelhos não têm essa tela; a tela do app explica o caminho.
        }
    }

    private fun podeSobrepor(contexto: Context): Boolean = try {
        Settings.canDrawOverlays(contexto)
    } catch (_: Exception) {
        false
    }

    private fun agendarTeletransporte() {
        principal.removeCallbacks(teletransportarSozinho)
        if (!ativo) return
        // Uma folga para não parecer metrônomo.
        val variacao = (intervaloMs * 0.25).toLong()
        val espera = intervaloMs + if (variacao > 0) {
            Random.nextLong(-variacao, variacao)
        } else {
            0L
        }
        principal.postDelayed(teletransportarSozinho, espera.coerceAtLeast(2_000L))
    }

    private fun moverParaPontoAleatorio() {
        val desenho = vista ?: return
        val layout = parametros ?: return
        val gerenciador = janela ?: return
        val base = app ?: return
        val metricas = base.resources.displayMetrics
        val folga = (FOLGA_DP * metricas.density).toInt()
        val topo = alturaBarra(base, "status_bar_height")
        val baixo = alturaBarra(base, "navigation_bar_height")
        val largura = max(1, metricas.widthPixels - layout.width - folga * 2)
        val altura = max(1, metricas.heightPixels - layout.height - folga * 2 - topo - baixo)
        layout.x = folga + Random.nextInt(largura)
        layout.y = folga + topo + Random.nextInt(altura)
        try {
            gerenciador.updateViewLayout(desenho, layout)
        } catch (_: Exception) {
            // Se a janela sumiu no meio, o próximo ciclo tenta de novo.
        }
    }

    private fun limitar(layout: WindowManager.LayoutParams) {
        val base = app ?: return
        val metricas = base.resources.displayMetrics
        val folga = (FOLGA_DP * metricas.density).toInt()
        val topo = alturaBarra(base, "status_bar_height")
        val baixo = alturaBarra(base, "navigation_bar_height")
        val maxX = max(folga, metricas.widthPixels - layout.width - folga)
        val maxY = max(
            folga + topo,
            metricas.heightPixels - layout.height - folga - baixo,
        )
        layout.x = layout.x.coerceIn(folga, maxX)
        layout.y = layout.y.coerceIn(folga + topo, maxY)
    }

    private fun alturaBarra(contexto: Context, nome: String): Int {
        val id = contexto.resources.getIdentifier(nome, "dimen", "android")
        return if (id > 0) contexto.resources.getDimensionPixelSize(id) else 0
    }

    private fun abrirApp() {
        val base = app ?: return
        try {
            val abertura = base.packageManager
                .getLaunchIntentForPackage(base.packageName)
                ?: return
            abertura.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            base.startActivity(abertura)
        } catch (_: Exception) {
            // Sem app para abrir, o núcleo continua na tela.
        }
    }
}

/**
 * Desenho do núcleo: esfera geodésica 3D projetada, halo, anéis, partículas e
 * o clarão de chegada do teletransporte. Nada é bitmap: tudo sai da malha.
 */
private class NucleoView(contexto: Context) : View(contexto) {

    var aoArrastar: ((Float, Float) -> Unit)? = null
    var aoTocar: (() -> Unit)? = null

    private val densidade = resources.displayMetrics.density
    private val malha = malhaGeodesica()
    private val tintaAresta = Paint(Paint.ANTI_ALIAS_FLAG)
    private val tintaAnel = Paint(Paint.ANTI_ALIAS_FLAG)
    private val tintaHalo = Paint(Paint.ANTI_ALIAS_FLAG)
    private val tintaNucleo = Paint(Paint.ANTI_ALIAS_FLAG)
    private val tintaParticula = Paint(Paint.ANTI_ALIAS_FLAG)
    private val tintaClarao = Paint(Paint.ANTI_ALIAS_FLAG)
    private val oval = RectF()
    private val girados = FloatArray(malha.pontos.size / 3 * 3)
    private val profundidade = FloatArray(malha.pontos.size / 3)
    private var brilho = 0f
    private var ultimoQuadro = 0L
    private var inicioX = 0f
    private var inicioY = 0f
    private var arrastou = false

    init {
        tintaAresta.style = Paint.Style.STROKE
        tintaAresta.strokeCap = Paint.Cap.ROUND
        tintaAnel.style = Paint.Style.STROKE
        tintaParticula.style = Paint.Style.FILL
        tintaClarao.style = Paint.Style.STROKE
        setLayerType(LAYER_TYPE_HARDWARE, null)
    }

    /** Clarão curto ao reaparecer depois do teletransporte. */
    fun piscar() {
        brilho = 1f
        postInvalidateOnAnimation()
    }

    override fun onDraw(canvas: Canvas) {
        val agora = SystemClock.uptimeMillis()
        val delta = if (ultimoQuadro == 0L) 0f else ((agora - ultimoQuadro) / 1000f)
        ultimoQuadro = agora
        brilho = (brilho - delta.coerceIn(0f, 0.1f) * 2.4f).coerceAtLeast(0f)

        val tempo = agora / 1000f
        val raio = min(width, height) * 0.30f
        val centroX = width / 2f
        val centroY = height / 2f + sin(tempo * 1.6f) * 3f * densidade

        desenharHalo(canvas, centroX, centroY, raio)
        desenharEsfera(canvas, centroX, centroY, raio, tempo)
        desenharAneis(canvas, centroX, centroY, raio, tempo)
        desenharParticulas(canvas, centroX, centroY, raio, tempo)
        desenharClarao(canvas, centroX, centroY, raio)

        postInvalidateOnAnimation()
    }

    private fun desenharHalo(canvas: Canvas, cx: Float, cy: Float, raio: Float) {
        tintaHalo.shader = RadialGradient(
            cx, cy, raio * 1.55f,
            intArrayOf(
                Color.argb(70, 53, 230, 255),
                Color.argb(26, 54, 139, 255),
                Color.TRANSPARENT,
            ),
            floatArrayOf(0f, 0.55f, 1f),
            Shader.TileMode.CLAMP,
        )
        canvas.drawCircle(cx, cy, raio * 1.55f, tintaHalo)
    }

    private fun desenharEsfera(
        canvas: Canvas,
        cx: Float,
        cy: Float,
        raio: Float,
        tempo: Float,
    ) {
        val giro = tempo * 0.7f
        val inclinacao = 0.42f + sin(tempo * 0.38f) * 0.10f
        val cosG = cos(giro)
        val sinG = sin(giro)
        val cosI = cos(inclinacao)
        val sinI = sin(inclinacao)
        val camera = raio * 3.7f
        for (i in 0 until malha.pontos.size / 3) {
            val x = malha.pontos[i * 3].toDouble()
            val y = malha.pontos[i * 3 + 1].toDouble()
            val z = malha.pontos[i * 3 + 2].toDouble()
            val x1 = x * cosG + z * sinG
            val z1 = -x * sinG + z * cosG
            val y1 = y * cosI - z1 * sinI
            val z2 = y * sinI + z1 * cosI
            val perspectiva = camera / (camera + z2 * raio)
            girados[i * 3] = cx + (x1 * raio * perspectiva).toFloat()
            girados[i * 3 + 1] = cy - (y1 * raio * perspectiva).toFloat()
            profundidade[i] = z2.toFloat()
        }

        val arestas = malha.arestas
        var i = 0
        while (i < arestas.size) {
            val a = arestas[i]
            val b = arestas[i + 1]
            val frente = ((profundidade[a] + profundidade[b]) / 2f + 1f) / 2f
            val opacidade = (48 + frente.coerceIn(0f, 1f) * 170f).toInt()
            tintaAresta.color = Color.argb(opacidade, 53, 230, 255)
            tintaAresta.strokeWidth =
                (0.6f + frente.coerceIn(0f, 1f) * 2.1f) * densidade
            canvas.drawLine(
                girados[a * 3], girados[a * 3 + 1],
                girados[b * 3], girados[b * 3 + 1],
                tintaAresta,
            )
            i += 2
        }

        tintaNucleo.shader = RadialGradient(
            cx, cy, raio * 0.58f,
            intArrayOf(
                Color.WHITE,
                Color.argb(220, 125, 249, 255),
                Color.argb(90, 53, 230, 255),
                Color.TRANSPARENT,
            ),
            floatArrayOf(0f, 0.35f, 0.72f, 1f),
            Shader.TileMode.CLAMP,
        )
        canvas.drawCircle(cx, cy, raio * 0.58f, tintaNucleo)
    }

    private fun desenharAneis(
        canvas: Canvas,
        cx: Float,
        cy: Float,
        raio: Float,
        tempo: Float,
    ) {
        tintaAnel.color = Color.argb(96, 140, 240, 255)
        tintaAnel.strokeWidth = 1.1f * densidade
        for (indice in 0..1) {
            val inclinacao = 0.55f + indice * 1.15f
            canvas.save()
            canvas.rotate(
                (tempo * (indice == 0 ? 18f : -12f)) % 360f,
                cx,
                cy,
            )
            oval.set(
                cx - raio * (1.16f + indice * 0.12f),
                cy - raio * (0.30f + 0.14f * inclinacao / 2f),
                cx + raio * (1.16f + indice * 0.12f),
                cy + raio * (0.30f + 0.14f * inclinacao / 2f),
            )
            canvas.drawOval(oval, tintaAnel)
            canvas.restore()
        }
    }

    private fun desenharParticulas(
        canvas: Canvas,
        cx: Float,
        cy: Float,
        raio: Float,
        tempo: Float,
    ) {
        tintaParticula.color = Color.argb(190, 190, 250, 255)
        for (indice in 0 until 14) {
            val fase = indice * 0.449f
            val orbita = 0.65f + (indice % 5) * 0.12f
            val angulo = tempo * (0.5f + indice % 3 * 0.22f) + fase
            val x = cx + cos(angulo) * raio * orbita * 1.25f
            val y = cy + sin(angulo * 1.3f) * raio * orbita * 0.62f
            val tamanho = (indice % 3 == 0) 1.9f else 1.2f
            canvas.drawCircle(x, y, tamanho * densidade, tintaParticula)
        }
    }

    private fun desenharClarao(canvas: Canvas, cx: Float, cy: Float, raio: Float) {
        if (brilho <= 0f) return
        val expansao = 1f + (1f - brilho) * 1.6f
        tintaClarao.color = Color.argb((brilho * 200).toInt(), 190, 250, 255)
        tintaClarao.strokeWidth = (2.4f * brilho + 0.6f) * densidade
        canvas.drawCircle(cx, cy, raio * expansao, tintaClarao)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                inicioX = event.rawX
                inicioY = event.rawY
                arrastou = false
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = event.rawX - inicioX
                val dy = event.rawY - inicioY
                if (!arrastou && abs(dx) + abs(dy) > 6f * densidade) {
                    arrastou = true
                }
                if (arrastou) {
                    aoArrastar?.invoke(dx, dy)
                    inicioX = event.rawX
                    inicioY = event.rawY
                }
                return true
            }
            MotionEvent.ACTION_UP -> {
                if (!arrastou) aoTocar?.invoke()
                return true
            }
            MotionEvent.ACTION_CANCEL -> return true
        }
        return super.onTouchEvent(event)
    }

    override fun performClick(): Boolean {
        super.performClick()
        aoTocar?.invoke()
        return true
    }
}

private class Malha(val pontos: FloatArray, val arestas: IntArray)

private fun normalizar(ponto: DoubleArray): DoubleArray {
    val tamanho = sqrt(ponto[0] * ponto[0] + ponto[1] * ponto[1] + ponto[2] * ponto[2])
    if (tamanho == 0.0) return doubleArrayOf(0.0, 1.0, 0.0)
    return doubleArrayOf(ponto[0] / tamanho, ponto[1] / tamanho, ponto[2] / tamanho)
}

/** Icosaedro subdividido uma vez: 42 vértices, 120 arestas. */
private fun malhaGeodesica(): Malha {
    val phi = (1.0 + sqrt(5.0)) / 2.0
    val base = listOf(
        doubleArrayOf(-1.0, phi, 0.0),
        doubleArrayOf(1.0, phi, 0.0),
        doubleArrayOf(-1.0, -phi, 0.0),
        doubleArrayOf(1.0, -phi, 0.0),
        doubleArrayOf(0.0, -1.0, phi),
        doubleArrayOf(0.0, 1.0, phi),
        doubleArrayOf(0.0, -1.0, -phi),
        doubleArrayOf(0.0, 1.0, -phi),
        doubleArrayOf(phi, 0.0, -1.0),
        doubleArrayOf(phi, 0.0, 1.0),
        doubleArrayOf(-phi, 0.0, -1.0),
        doubleArrayOf(-phi, 0.0, 1.0),
    )
    val faces = listOf(
        intArrayOf(0, 11, 5), intArrayOf(0, 5, 1), intArrayOf(0, 1, 7),
        intArrayOf(0, 7, 10), intArrayOf(0, 10, 11), intArrayOf(1, 5, 9),
        intArrayOf(5, 11, 4), intArrayOf(11, 10, 2), intArrayOf(10, 7, 6),
        intArrayOf(7, 1, 8), intArrayOf(3, 9, 4), intArrayOf(3, 4, 2),
        intArrayOf(3, 2, 6), intArrayOf(3, 6, 8), intArrayOf(3, 8, 9),
        intArrayOf(4, 9, 5), intArrayOf(2, 4, 11), intArrayOf(6, 2, 10),
        intArrayOf(8, 6, 7), intArrayOf(9, 8, 1),
    )
    val pontos = base.map { normalizar(it) }.toMutableList()
    val indice = HashMap<String, Int>()
    fun chave(ponto: DoubleArray): String =
        "${(ponto[0] * 10000).toInt()}:${(ponto[1] * 10000).toInt()}:" +
            "${(ponto[2] * 10000).toInt()}"
    for (i in pontos.indices) indice[chave(pontos[i])] = i
    fun meio(a: Int, b: Int): Int {
        val ponto = doubleArrayOf(
            (pontos[a][0] + pontos[b][0]) / 2.0,
            (pontos[a][1] + pontos[b][1]) / 2.0,
            (pontos[a][2] + pontos[b][2]) / 2.0,
        )
        val normalizado = normalizar(ponto)
        val identificador = chave(normalizado)
        val existente = indice[identificador]
        if (existente != null) return existente
        pontos.add(normalizado)
        val novo = pontos.size - 1
        indice[identificador] = novo
        return novo
    }
    val subdivididas = mutableListOf<IntArray>()
    for (face in faces) {
        val ab = meio(face[0], face[1])
        val bc = meio(face[1], face[2])
        val ca = meio(face[2], face[0])
        subdivididas.add(intArrayOf(face[0], ab, ca))
        subdivididas.add(intArrayOf(face[1], bc, ab))
        subdivididas.add(intArrayOf(face[2], ca, bc))
        subdivididas.add(intArrayOf(ab, bc, ca))
    }
    val codigos = LinkedHashSet<Long>()
    for (face in subdivididas) {
        for (i in 0..2) {
            val a = face[i]
            val b = face[(i + 1) % 3]
            val menor = min(a, b)
            val maior = max(a, b)
            codigos.add((menor.toLong() shl 32) or maior.toLong())
        }
    }
    val arestas = IntArray(codigos.size * 2)
    var posicao = 0
    for (codigo in codigos) {
        arestas[posicao++] = (codigo ushr 32).toInt()
        arestas[posicao++] = codigo.toInt()
    }
    val saida = FloatArray(pontos.size * 3)
    for (i in pontos.indices) {
        saida[i * 3] = pontos[i][0].toFloat()
        saida[i * 3 + 1] = pontos[i][1].toFloat()
        saida[i * 3 + 2] = pontos[i][2].toFloat()
    }
    return Malha(saida, arestas)
}
