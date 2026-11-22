package com.jarvis.nova

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.SystemClock

/**
 * Gestos com os sensores do próprio aparelho e o modo noturno.
 *
 * **Virar para baixo (flip-to-shush):** o acelerômetro informa a gravidade; com
 * a tela para baixo o eixo Z fica negativo. Ao virar, o JARVIS para de falar —
 * sem permissão extra, sem nuvem e sem serviço de acessibilidade.
 *
 * **Modo noturno:** guarda o brilho escolhido (10–100%) e deixa a voz mais baixa.
 * O brilho é aplicado só na janela do app (`WindowManager.LayoutParams`), porque
 * mudar o brilho do sistema exigiria a permissão WRITE_SETTINGS — o JARVIS não
 * pede permissão que não usa.
 *
 * O estado fica em SharedPreferences do aparelho; nada aqui envia dados.
 */
object JarvisSensores {
    const val PREFS = "jarvis_gestos"
    private const val CHAVE_CALAR = "calar_ao_virar"
    private const val CHAVE_NOTURNO = "modo_noturno"
    private const val CHAVE_BRILHO = "brilho_noturno"

    const val BRILHO_PADRAO = 35
    const val BRILHO_MINIMO = 10
    const val BRILHO_MAXIMO = 100

    /** Gravidade apontando para o lado oposto à tela: celular de bruços. */
    const val LIMIAR_VIRADO = -8.0f

    /** Folga para voltar a considerar o celular para cima. */
    const val LIMIAR_VOLTA = -4.0f

    /** Intervalo mínimo entre dois avisos: virar de lado não cala duas vezes. */
    const val ESPERA_ENTRE_AVISOS_MS = 1_200L

    /** Volume da voz no modo noturno (0–1). */
    const val VOLUME_NOTURNO = 0.45f

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun calarAoVirar(context: Context): Boolean =
        prefs(context).getBoolean(CHAVE_CALAR, false)

    fun definirCalarAoVirar(context: Context, ativo: Boolean) {
        prefs(context).edit().putBoolean(CHAVE_CALAR, ativo).apply()
    }

    fun modoNoturno(context: Context): Boolean =
        prefs(context).getBoolean(CHAVE_NOTURNO, false)

    fun definirModoNoturno(context: Context, ativo: Boolean) {
        prefs(context).edit().putBoolean(CHAVE_NOTURNO, ativo).apply()
    }

    fun brilho(context: Context): Int =
        prefs(context).getInt(CHAVE_BRILHO, BRILHO_PADRAO)
            .coerceIn(BRILHO_MINIMO, BRILHO_MAXIMO)

    /** Guarda o brilho e devolve o valor realmente gravado. */
    fun definirBrilho(context: Context, valor: Int): Int {
        val seguro = valor.coerceIn(BRILHO_MINIMO, BRILHO_MAXIMO)
        prefs(context).edit().putInt(CHAVE_BRILHO, seguro).apply()
        return seguro
    }

    private fun gerenciador(context: Context): SensorManager? =
        context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager

    fun temAcelerometro(context: Context): Boolean =
        gerenciador(context)?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null

    fun estado(context: Context): Map<String, Any> = mapOf(
        "temAcelerometro" to temAcelerometro(context),
        "calarAoVirar" to calarAoVirar(context),
        "modoNoturno" to modoNoturno(context),
        "brilho" to brilho(context),
        "brilhoMinimo" to BRILHO_MINIMO,
        "brilhoMaximo" to BRILHO_MAXIMO,
    )

    /**
     * Vigia do acelerômetro. Chama [aoVirar] uma vez por vez que o aparelho
     * fica de bruços e se rearma quando ele volta para cima.
     *
     * Só é registrado enquanto a tela do app está na frente: um sensor ligado
     * em segundo plano gastaria bateria sem ter o que calar.
     */
    class Vigia(context: Context, private val aoVirar: () -> Unit) : SensorEventListener {
        private val gerenciador = gerenciador(context.applicationContext)
        private val sensor = gerenciador?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        private var deBrucos = false
        private var ultimoAviso = 0L
        private var registrado = false

        val disponivel: Boolean
            get() = sensor != null && gerenciador != null

        fun iniciar(): Boolean {
            if (!disponivel || registrado) return disponivel
            registrado = try {
                gerenciador?.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL) == true
            } catch (_: Exception) {
                false
            }
            return registrado
        }

        fun parar() {
            if (!registrado) return
            try {
                gerenciador?.unregisterListener(this)
            } catch (_: Exception) {
                // Sensor já removido pelo sistema: nada a fazer.
            }
            registrado = false
            deBrucos = false
        }

        override fun onSensorChanged(evento: SensorEvent) {
            val z = evento.values.getOrNull(2) ?: return
            if (!deBrucos && z <= LIMIAR_VIRADO) {
                // Carimbo antes do aviso: o tempo do gesto é o tempo da chegada.
                deBrucos = true
                val agora = SystemClock.uptimeMillis()
                if (agora - ultimoAviso < ESPERA_ENTRE_AVISOS_MS) return
                ultimoAviso = agora
                aoVirar()
                return
            }
            if (deBrucos && z >= LIMIAR_VOLTA) deBrucos = false
        }

        override fun onAccuracyChanged(sensor: Sensor?, precisao: Int) = Unit
    }
}
