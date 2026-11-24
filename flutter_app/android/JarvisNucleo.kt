package com.jarvis.nova

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.SystemClock
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.animation.OvershootInterpolator
import android.widget.LinearLayout
import android.widget.TextView
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
    private var pausado = false
    private var economico = false
    private var humor = HumorNucleo.ESPERA
    private var receptorRegistrado = false
    private var menu: View? = null
    private var menuLayout: WindowManager.LayoutParams? = null
    private var alturaMenu = 0
    private var consumoInicioMs = 0L
    private var consumoCpuInicio = 0L
    private var consumoBateriaInicio = -1
    private var consumoModo = ""
    private var consumoCarregando = false
    private var consumoTelaApagou = false
    private val consumoAmostras = mutableMapOf<String, Map<String, Any>>()

    /** Tela apagada: para de redesenhar até o Android avisar que acendeu. */
    private val receptorTela = object : BroadcastReceiver() {
        override fun onReceive(contexto: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    if (consumoInicioMs != 0L) consumoTelaApagou = true
                    vista?.suspender()
                }
                Intent.ACTION_SCREEN_ON -> vista?.acordar()
            }
        }
    }

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
        "pausado" to pausado,
        "economico" to economico,
        "humor" to humor,
    )

    /**
     * Sobe a janela flutuante. Devolve o estado com `iniciado` e, quando falha,
     * um `motivo` curto (`sem_permissao`), para a tela dizer o que falta.
     */
    fun iniciar(
        contexto: Context,
        tamanho: Int,
        intervalo: Long,
        economicoNovo: Boolean,
    ): Map<String, Any> {
        tamanhoDp = tamanho.coerceIn(72, 160)
        intervaloMs = intervalo.coerceIn(3_000L, 15_000L)
        val estavaPausado = pausado
        if (!podeSobrepor(contexto)) {
            return estado(contexto) + mapOf("iniciado" to false, "motivo" to "sem_permissao")
        }
        // Já na tela: recria com o tamanho e o ritmo novos, em vez de ignorar
        // a mudança que a tela acabou de pedir.
        if (ativo) parar()
        economico = economicoNovo
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
                aoAbrirMenu = { abrirMenu() }
            }
            gerenciador.addView(desenho, layout)
            app = base
            janela = gerenciador
            vista = desenho
            parametros = layout
            ativo = true
            registrarTela(base)
            desenho.definirEconomico(economico)
            desenho.definirHumor(humor)
            moverParaPontoAleatorio()
            if (estavaPausado) {
                pausado = true
                desenho.pausar()
            } else {
                pausado = false
                agendarTeletransporte()
            }
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
        pausado = false
        economico = false
        fecharMenu()
        removerReceptor()
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

    /** Congela o giro e o teletransporte sem tirar o núcleo da tela. */
    fun definirPausado(valor: Boolean) {
        pausado = valor
        if (!ativo) return
        val desenho = vista ?: return
        principal.removeCallbacks(teletransportarSozinho)
        principal.removeCallbacks(soltar)
        if (valor) {
            desenho.reiniciarAnimacao()
            desenho.pausar()
        } else {
            desenho.retomar()
            agendarTeletransporte()
        }
    }

    /**
     * Estado do JARVIS: `espera`, `ouvindo`, `pensando` ou `falando`.
     * O núcleo muda a cor e o ritmo para parecer um mascote atento.
     */
    fun definirHumor(valor: String) {
        if (!HumorNucleo.valido(valor)) return
        humor = valor
        vista?.definirHumor(valor)
    }

    /** Modo econômico: menos quadros, brilho menor e teletransporte mais raro. */
    fun definirEconomico(valor: Boolean) {
        economico = valor
        vista?.definirEconomico(valor)
        if (ativo && !pausado) agendarTeletransporte()
    }

    /** Teletransporte pedido pela tela (e pelo toque longo, se houver). */
    fun teletransportar() {
        val desenho = vista ?: return
        if (!ativo || pausado) return
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
        // O menu anda junto com o núcleo durante o arrasto.
        if (menu != null) aplicarPosicaoMenu()
        arrastando = true
        principal.removeCallbacks(soltar)
        principal.postDelayed(soltar, PAUSA_APOS_ARRASTO_MS)
    }

    /** Medição do desenho: quadros e tempo em cada modo, desde a abertura. */
    fun medicao(): Map<String, Any> = vista?.medicao() ?: mapOf(
        "normalQuadros" to 0L,
        "normalMs" to 0L,
        "ecoQuadros" to 0L,
        "ecoMs" to 0L,
    )

    fun zerarMedicao() {
        vista?.zerarMedicao()
    }

    /**
     * Consumo real: janelas controladas de CPU do processo e bateria do
     * aparelho. O Android não informa energia por janela sobreposta, então a
     * tela trata os números como estimativa de comparação, com motivo quando
     * não dá para concluir.
     */
    fun iniciarConsumo(contexto: Context): Map<String, Any> {
        if (consumoInicioMs != 0L) return estadoConsumo()
        consumoModo = if (economico) "economico" else "normal"
        consumoInicioMs = SystemClock.elapsedRealtime()
        consumoCpuInicio = Process.getElapsedCpuTime()
        consumoBateriaInicio = bateria(contexto)
        consumoCarregando = carregando(contexto)
        consumoTelaApagou = false
        return estadoConsumo()
    }

    fun pararConsumo(contexto: Context): Map<String, Any> {
        if (consumoInicioMs == 0L) return estadoConsumo()
        val duracao = SystemClock.elapsedRealtime() - consumoInicioMs
        val cpu = (Process.getElapsedCpuTime() - consumoCpuInicio).coerceAtLeast(0L)
        val amostra = mapOf(
            "modo" to consumoModo,
            "duracaoMs" to duracao,
            "cpuMs" to cpu,
            "bateriaInicio" to consumoBateriaInicio,
            "bateriaFim" to bateria(contexto),
            "carregando" to (consumoCarregando || carregando(contexto)),
            "telaApagou" to consumoTelaApagou,
        )
        consumoAmostras[consumoModo] = amostra
        consumoInicioMs = 0L
        return estadoConsumo()
    }

    fun estadoConsumo(): Map<String, Any> = mapOf(
        "medindo" to (consumoInicioMs != 0L),
        "modoAtual" to consumoModo,
        "normal" to (consumoAmostras["normal"] ?: emptyMap<String, Any>()),
        "economico" to (consumoAmostras["economico"] ?: emptyMap<String, Any>()),
    )

    fun zerarConsumo() {
        consumoAmostras.clear()
        consumoInicioMs = 0L
    }

    private fun bateria(contexto: Context): Int = try {
        val gerenciador =
            contexto.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        gerenciador.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
    } catch (_: Exception) {
        -1
    }

    private fun carregando(contexto: Context): Boolean = try {
        val gerenciador =
            contexto.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        gerenciador.isCharging
    } catch (_: Exception) {
        false
    }

    /**
     * Menu do núcleo: toque longo abre, toque curto continua abrindo o app.
     * Cada opção chama a mesma função que a tela chama — não há atalho falso.
     */
    private fun abrirMenu() {
        if (!ativo || menu != null) return
        val base = app ?: return
        val gerenciador = janela ?: return
        principal.removeCallbacks(teletransportarSozinho)
        val painel = LinearLayout(base).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(10), dp(8), dp(10), dp(10))
            background = GradientDrawable().apply {
                setColor(0xF208111C.toInt())
                cornerRadius = dp(16).toFloat()
                setStroke(dp(1), 0x5535E6FF)
            }
        }
        painel.addView(tituloMenu(base))
        painel.addView(
            itemMenu(base, if (pausado) "Retomar" else "Pausar") {
                fecharMenu()
                definirPausado(!pausado)
            }
        )
        painel.addView(
            itemMenu(
                base,
                "Modo econômico: ${if (economico) "ligado" else "desligado"}",
            ) {
                fecharMenu()
                definirEconomico(!economico)
            }
        )
        painel.addView(
            itemMenu(
                base,
                "Teletransportar agora",
                habilitado = !pausado,
            ) {
                fecharMenu()
                teletransportar()
            }
        )
        painel.addView(linhaTamanhos(base))
        painel.addView(
            itemMenu(base, "Abrir o JARVIS") {
                fecharMenu()
                abrirApp()
            }
        )
        painel.addView(
            itemMenu(base, "Desligar o núcleo", destaque = true) {
                fecharMenu()
                parar()
            }
        )
        painel.setOnTouchListener { _, evento ->
            if (evento.action == MotionEvent.ACTION_OUTSIDE) {
                fecharMenu()
                true
            } else {
                false
            }
        }
        val layout = WindowManager.LayoutParams(
            dp(206),
            WindowManager.LayoutParams.WRAP_CONTENT,
            tipoSobreposicao(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }
        try {
            gerenciador.addView(painel, layout)
            menu = painel
            menuLayout = layout
            alturaMenu = dp(280)
            aplicarPosicaoMenu()
            painel.post {
                alturaMenu = painel.height.coerceAtLeast(dp(1))
                aplicarPosicaoMenu()
            }
        } catch (_: Exception) {
            menu = null
            menuLayout = null
            if (!pausado) agendarTeletransporte()
        }
    }

    /** Coloca o menu ao lado do núcleo, trocando de lado quando não cabe. */
    private fun aplicarPosicaoMenu() {
        val painel = menu ?: return
        val layout = menuLayout ?: return
        val gerenciador = janela ?: return
        val base = app ?: return
        val nucleo = parametros ?: return
        val metricas = base.resources.displayMetrics
        val posicao = PosicaoMenu.calcular(
            nucleoX = nucleo.x,
            nucleoY = nucleo.y,
            nucleoLado = nucleo.width,
            menuLargura = layout.width,
            menuAltura = alturaMenu,
            telaLargura = metricas.widthPixels,
            telaAltura = metricas.heightPixels,
            topo = alturaBarra(base, "status_bar_height"),
            base = alturaBarra(base, "navigation_bar_height"),
            folga = dp(8),
        )
        layout.x = posicao.x
        layout.y = posicao.y
        try {
            gerenciador.updateViewLayout(painel, layout)
        } catch (_: Exception) {
            // Se a janela sumiu no meio, o próximo arrasto tenta de novo.
        }
    }

    private fun fecharMenu() {
        val painel = menu ?: return
        val gerenciador = janela
        menu = null
        menuLayout = null
        alturaMenu = 0
        if (gerenciador != null) {
            try {
                gerenciador.removeView(painel)
            } catch (_: Exception) {
                // O sistema já pode ter removido o menu.
            }
        }
        if (ativo && !pausado) agendarTeletransporte()
    }

    private fun aplicarTamanho(novoDp: Int) {
        val base = app ?: return
        iniciar(base, novoDp, intervaloMs, economico)
    }

    private fun tituloMenu(base: Context): TextView = TextView(base).apply {
        text = "JARVIS · núcleo"
        setTextColor(0xFF7DE9FF.toInt())
        textSize = 11f
        setPadding(dp(8), dp(2), dp(8), dp(6))
    }

    private fun itemMenu(
        base: Context,
        rotulo: String,
        habilitado: Boolean = true,
        destaque: Boolean = false,
        aoClicar: () -> Unit,
    ): TextView = TextView(base).apply {
        text = rotulo
        textSize = 13f
        setTextColor(
            when {
                !habilitado -> 0x55E6F7FF
                destaque -> 0xFFFFB4A9.toInt()
                else -> 0xFFE6F7FF.toInt()
            }
        )
        setPadding(dp(8), dp(10), dp(8), dp(10))
        isClickable = habilitado
        isFocusable = false
        if (habilitado) setOnClickListener { aoClicar() }
    }

    private fun linhaTamanhos(base: Context): View {
        val linha = LinearLayout(base).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        linha.addView(
            TextView(base).apply {
                text = "Tamanho"
                setTextColor(0xFF9FB6C6.toInt())
                textSize = 12f
                setPadding(dp(8), dp(8), dp(6), dp(8))
            }
        )
        for ((rotulo, valor) in listOf("P" to 80, "M" to 112, "G" to 150)) {
            linha.addView(
                TextView(base).apply {
                    text = rotulo
                    gravity = Gravity.CENTER
                    textSize = 13f
                    setTextColor(
                        if (tamanhoDp == valor) 0xFF35E6FF.toInt()
                        else 0xFFE6F7FF.toInt()
                    )
                    setPadding(dp(6), dp(8), dp(6), dp(8))
                    setOnClickListener {
                        fecharMenu()
                        aplicarTamanho(valor)
                    }
                },
                LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f),
            )
        }
        return linha
    }

    private fun tipoSobreposicao(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        }

    private fun dp(valor: Int): Int =
        (valor * (app?.resources?.displayMetrics?.density ?: 1f)).toInt()

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
        // No modo econômico o núcleo troca de lugar com o dobro do intervalo.
        val base = if (economico) intervaloMs * 2 else intervaloMs
        val variacao = (base * 0.25).toLong()
        val espera = base + if (variacao > 0) {
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

    private fun registrarTela(base: Context) {
        if (receptorRegistrado) return
        try {
            val filtro = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_OFF)
                addAction(Intent.ACTION_SCREEN_ON)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                base.registerReceiver(
                    receptorTela, filtro, Context.RECEIVER_NOT_EXPORTED
                )
            } else {
                base.registerReceiver(receptorTela, filtro)
            }
            receptorRegistrado = true
        } catch (_: Exception) {
            receptorRegistrado = false
        }
    }

    private fun removerReceptor() {
        if (!receptorRegistrado) return
        receptorRegistrado = false
        val base = app ?: return
        try {
            base.unregisterReceiver(receptorTela)
        } catch (_: Exception) {
            // O sistema já pode ter soltado o receptor.
        }
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
    var aoAbrirMenu: (() -> Unit)? = null

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
    private var pausado = false
    private var suspenso = false
    private var economico = false
    private var humor = HumorNucleo.ESPERA
    private val corAtual = HumorNucleo.cor(HumorNucleo.ESPERA)
    private var tempoAcumulado = 0f
    private var ultimoQuadroEconomico = 0L
    private var quadrosNormal = 0L
    private var msNormal = 0L
    private var quadrosEconomico = 0L
    private var msEconomico = 0L
    private var ultimoDesenho = 0L
    private val relogio = Handler(Looper.getMainLooper())
    private var abriuMenu = false
    private val abrirMenuAtrasado = Runnable {
        if (!arrastou) {
            abriuMenu = true
            aoAbrirMenu?.invoke()
        }
    }
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

    /** Para o giro e o clarão, mantendo um quadro parado na tela. */
    fun pausar() {
        pausado = true
        ultimoDesenho = 0L
        postInvalidate()
    }

    fun retomar() {
        pausado = false
        suspenso = false
        ultimoQuadro = 0L
        ultimoDesenho = 0L
        postInvalidateOnAnimation()
    }

    /** Tela apagada: nenhum quadro é desenhado até acordar. */
    fun suspender() {
        suspenso = true
        ultimoDesenho = 0L
    }

    fun acordar() {
        suspenso = false
        ultimoQuadro = 0L
        ultimoDesenho = 0L
        postInvalidateOnAnimation()
    }

    /** Quadros e tempo desenhados em cada modo, medidos no próprio núcleo. */
    fun medicao(): Map<String, Any> = mapOf(
        "normalQuadros" to quadrosNormal,
        "normalMs" to msNormal,
        "ecoQuadros" to quadrosEconomico,
        "ecoMs" to msEconomico,
    )

    fun zerarMedicao() {
        quadrosNormal = 0L
        msNormal = 0L
        quadrosEconomico = 0L
        msEconomico = 0L
        ultimoDesenho = 0L
    }

    /** Menos quadros (20 por segundo) e brilho mais contido. */
    fun definirEconomico(valor: Boolean) {
        economico = valor
        postInvalidateOnAnimation()
    }

    /** Troca a cor e a cadência conforme o JARVIS ouve, pensa ou fala. */
    fun definirHumor(valor: String) {
        if (!HumorNucleo.valido(valor) || valor == humor) return
        humor = valor
        postInvalidateOnAnimation()
    }

    /** Cancela um teletransporte no meio e devolve o tamanho normal. */
    fun reiniciarAnimacao() {
        animate().cancel()
        alpha = 1f
        scaleX = 1f
        scaleY = 1f
    }

    override fun onDraw(canvas: Canvas) {
        val agora = SystemClock.uptimeMillis()
        if (suspenso) {
            ultimoQuadro = agora
            return
        }
        var delta = 0f
        if (pausado) {
            if (ultimoQuadro == 0L) ultimoQuadro = agora
        } else {
            delta = if (ultimoQuadro == 0L) 0f else ((agora - ultimoQuadro) / 1000f)
            tempoAcumulado += delta.coerceIn(0f, 0.1f)
            brilho = (brilho - delta.coerceIn(0f, 0.1f) * 2.4f).coerceAtLeast(0f)
            ultimoQuadro = agora
            if (economico) {
                if (agora - ultimoQuadroEconomico < 50L) return
                ultimoQuadroEconomico = agora
            }
            // A medição conta só o que foi desenhado de verdade.
            if (ultimoDesenho != 0L) {
                val intervalo = (agora - ultimoDesenho).coerceIn(0L, 1_000L)
                if (economico) {
                    msEconomico += intervalo
                } else {
                    msNormal += intervalo
                }
            }
            ultimoDesenho = agora
            if (economico) {
                quadrosEconomico++
            } else {
                quadrosNormal++
            }
        }

        // A cor caminha até a do estado em vez de saltar: parece respiração.
        val alvo = HumorNucleo.cor(humor)
        if (!pausado) {
            val passo = (delta * 6f).coerceIn(0f, 1f)
            for (canal in 0..2) {
                corAtual[canal] += (alvo[canal] - corAtual[canal]) * passo
            }
        }
        val ritmo = HumorNucleo.giro(humor)
        val respiro = HumorNucleo.respiro(humor)

        val tempo = tempoAcumulado
        val raio = min(width, height) * 0.30f
        val centroX = width / 2f
        val amplitude = if (humor == HumorNucleo.FALANDO) 5f else 3f
        val centroY =
            height / 2f + sin(tempo * 1.6f * respiro) * amplitude * densidade

        if (economico) {
            canvas.saveLayerAlpha(0f, 0f, width.toFloat(), height.toFloat(), 210)
        }
        desenharHalo(canvas, centroX, centroY, raio)
        desenharEsfera(canvas, centroX, centroY, raio, tempo, ritmo)
        desenharAneis(canvas, centroX, centroY, raio, tempo, ritmo)
        desenharRitmo(canvas, centroX, centroY, raio, tempo, respiro)
        desenharParticulas(canvas, centroX, centroY, raio, tempo, ritmo)
        desenharClarao(canvas, centroX, centroY, raio)
        if (economico) canvas.restore()

        if (!pausado) postInvalidateOnAnimation()
    }

    private fun tom(alfa: Int, clarear: Int = 0): Int = Color.argb(
        alfa.coerceIn(0, 255),
        (corAtual[0].toInt() + clarear).coerceIn(0, 255),
        (corAtual[1].toInt() + clarear).coerceIn(0, 255),
        (corAtual[2].toInt() + clarear).coerceIn(0, 255),
    )

    private fun desenharHalo(canvas: Canvas, cx: Float, cy: Float, raio: Float) {
        tintaHalo.shader = RadialGradient(
            cx, cy, raio * 1.55f,
            intArrayOf(
                tom(70),
                tom(28),
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
        ritmo: Float,
    ) {
        val giro = tempo * 0.7f * ritmo
        val inclinacao = 0.42f + sin(tempo * 0.38f * ritmo) * 0.10f
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
            tintaAresta.color = tom(opacidade)
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
                tom(220, 60),
                tom(90),
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
        ritmo: Float,
    ) {
        tintaAnel.color = tom(96)
        tintaAnel.strokeWidth = 1.1f * densidade
        for (indice in 0..1) {
            val inclinacao = 0.55f + indice * 1.15f
            canvas.save()
            canvas.rotate(
                (tempo * (if (indice == 0) 18f else -12f) * ritmo) % 360f,
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

    /** Assinatura do estado: ondas de escuta, arco de raciocínio ou boca falando. */
    private fun desenharRitmo(
        canvas: Canvas,
        cx: Float,
        cy: Float,
        raio: Float,
        tempo: Float,
        respiro: Float,
    ) {
        when (humor) {
            HumorNucleo.OUVINDO -> {
                for (indice in 0..2) {
                    val fase = (tempo * 0.55f + indice / 3f) % 1f
                    tintaAnel.color = tom((80f * (1f - fase)).toInt())
                    tintaAnel.strokeWidth = 1.2f * densidade
                    canvas.drawCircle(cx, cy, raio * (1.08f + fase * 0.55f), tintaAnel)
                }
            }
            HumorNucleo.PENSANDO -> {
                tintaAnel.color = tom(190)
                tintaAnel.strokeWidth = 2.1f * densidade
                oval.set(
                    cx - raio * 1.20f, cy - raio * 1.20f,
                    cx + raio * 1.20f, cy + raio * 1.20f,
                )
                canvas.drawArc(oval, (tempo * 220f) % 360f, 62f, false, tintaAnel)
            }
            HumorNucleo.FALANDO -> {
                val base = cy + raio * 0.62f
                tintaParticula.color = tom(150)
                for (indice in 0..4) {
                    val altura =
                        (5f + 9f * abs(sin(tempo * respiro + indice * 0.9f))) * densidade
                    val x = cx + (indice - 2) * 8f * densidade
                    canvas.drawLine(x, base - altura, x, base + altura, tintaParticula)
                }
            }
        }
    }

    private fun desenharParticulas(
        canvas: Canvas,
        cx: Float,
        cy: Float,
        raio: Float,
        tempo: Float,
        ritmo: Float,
    ) {
        tintaParticula.color = tom(190, 80)
        for (indice in 0 until 14) {
            val fase = indice * 0.449f
            val orbita = 0.65f + (indice % 5) * 0.12f
            val angulo = tempo * (0.5f + indice % 3 * 0.22f) * ritmo + fase
            val x = cx + cos(angulo) * raio * orbita * 1.25f
            val y = cy + sin(angulo * 1.3f) * raio * orbita * 0.62f
            val tamanho = if (indice % 3 == 0) 1.9f else 1.2f
            canvas.drawCircle(x, y, tamanho * densidade, tintaParticula)
        }
    }

    private fun desenharClarao(canvas: Canvas, cx: Float, cy: Float, raio: Float) {
        if (brilho <= 0f) return
        val expansao = 1f + (1f - brilho) * 1.6f
        tintaClarao.color = tom((brilho * 200).toInt(), 40)
        tintaClarao.strokeWidth = (2.4f * brilho + 0.6f) * densidade
        canvas.drawCircle(cx, cy, raio * expansao, tintaClarao)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                inicioX = event.rawX
                inicioY = event.rawY
                arrastou = false
                abriuMenu = false
                relogio.removeCallbacks(abrirMenuAtrasado)
                relogio.postDelayed(abrirMenuAtrasado, 480L)
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = event.rawX - inicioX
                val dy = event.rawY - inicioY
                if (!arrastou && abs(dx) + abs(dy) > 6f * densidade) {
                    arrastou = true
                    relogio.removeCallbacks(abrirMenuAtrasado)
                }
                if (arrastou) {
                    aoArrastar?.invoke(dx, dy)
                    inicioX = event.rawX
                    inicioY = event.rawY
                }
                return true
            }
            MotionEvent.ACTION_UP -> {
                relogio.removeCallbacks(abrirMenuAtrasado)
                if (!arrastou && !abriuMenu) aoTocar?.invoke()
                abriuMenu = false
                return true
            }
            MotionEvent.ACTION_CANCEL -> {
                relogio.removeCallbacks(abrirMenuAtrasado)
                abriuMenu = false
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    override fun performClick(): Boolean {
        super.performClick()
        aoTocar?.invoke()
        return true
    }

    override fun onDetachedFromWindow() {
        relogio.removeCallbacks(abrirMenuAtrasado)
        super.onDetachedFromWindow()
    }
}

/**
 * Cor e cadência do núcleo para cada estado do JARVIS. Sem Android aqui: só
 * decide o tom, o multiplicador de giro e a frequência da respiração.
 */
internal object HumorNucleo {
    const val ESPERA = "espera"
    const val OUVINDO = "ouvindo"
    const val PENSANDO = "pensando"
    const val FALANDO = "falando"

    private val ESTADOS = setOf(ESPERA, OUVINDO, PENSANDO, FALANDO)

    fun valido(estado: String): Boolean = estado in ESTADOS

    /** Azul calmo em espera, verde-água ouvindo, violeta pensando, âmbar falando. */
    fun cor(estado: String): FloatArray = when (estado) {
        OUVINDO -> floatArrayOf(96f, 255f, 200f)
        PENSANDO -> floatArrayOf(158f, 146f, 255f)
        FALANDO -> floatArrayOf(255f, 196f, 120f)
        else -> floatArrayOf(53f, 230f, 255f)
    }

    /** Quanto mais pensa, mais rápido gira; ouvindo, gira devagar e atento. */
    fun giro(estado: String): Float = when (estado) {
        OUVINDO -> 0.85f
        PENSANDO -> 2.1f
        FALANDO -> 1.3f
        else -> 1f
    }

    /** Frequência da respiração; falando, acompanha o ritmo da boca. */
    fun respiro(estado: String): Float = when (estado) {
        OUVINDO -> 1.5f
        PENSANDO -> 2.2f
        FALANDO -> 5.2f
        else -> 1f
    }
}

/**
 * Geometria do menu em volta do núcleo, sem Android: entra posição e tamanho,
 * sai onde o menu cabe. À direita quando há espaço; à esquerda quando não há;
 * sempre dentro da tela, descontando as barras.
 */
internal object PosicaoMenu {
    data class Ponto(val x: Int, val y: Int, val aDireita: Boolean)

    fun calcular(
        nucleoX: Int,
        nucleoY: Int,
        nucleoLado: Int,
        menuLargura: Int,
        menuAltura: Int,
        telaLargura: Int,
        telaAltura: Int,
        topo: Int,
        base: Int,
        folga: Int,
    ): Ponto {
        val direita = nucleoX + nucleoLado + folga
        val cabeDireita = direita + menuLargura <= telaLargura - folga
        val bruto = if (cabeDireita) direita else nucleoX - menuLargura - folga
        val x = bruto.coerceIn(
            folga,
            (telaLargura - menuLargura - folga).coerceAtLeast(folga),
        )
        val desejado = nucleoY + nucleoLado / 2 - menuAltura / 2
        val y = desejado.coerceIn(
            topo + folga,
            (telaAltura - base - menuAltura - folga).coerceAtLeast(topo + folga),
        )
        return Ponto(x, y, cabeDireita)
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
