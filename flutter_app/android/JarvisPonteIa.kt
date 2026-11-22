package com.jarvis.nova

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor.DartEntrypoint
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Ponte da resposta por IA com a parte Flutter do app.
 *
 * O detector de palavra roda no serviço em primeiro plano, mas quem tem as
 * chaves dos provedores e as regras de personalidade é o Flutter. Quando a
 * frase ouvida não é um comando do aparelho (por exemplo "que horas são" ou
 * "me fale sobre culinária"), o serviço pergunta aqui em vez de responder
 * "não tenho essa função em segundo plano".
 *
 * Até o ajuste 088 a ponte só existia enquanto o app estava aberto: com o app
 * encerrado o Android derrubava o motor do Flutter e toda pergunta livre
 * terminava em "abra o JARVIS". Agora, se ninguém estiver atendendo, a ponte
 * sobe um **motor só do serviço** (sem tela, entrada `mainFundo`) para usar o
 * mesmo `ProviderService`, as mesmas chaves e a mesma personalidade. Esse motor
 * é desligado depois de três minutos ocioso e no fim do serviço.
 *
 * Quando nem isso funciona, a promessa continua a mesma: devolver `null` e um
 * motivo curto — nunca uma resposta inventada.
 */
object JarvisPonteIa {
    const val CANAL = "com.jarvis.nova/fundo_ia"

    /** Entrada Dart do motor sem tela (ver `main.dart`). */
    private const val BIBLIOTECA_FUNDO = "package:jarvis_nova/main.dart"
    private const val ENTRADA_FUNDO = "mainFundo"

    /**
     * Tempo máximo de espera pela IA antes de desistir e avisar. Cobre a subida
     * do motor sem tela (até 12 s) mais a resposta do provedor (até 35 s).
     */
    private const val ESPERA_MS = 50_000L

    /** Tempo para o motor sem tela terminar de subir e registrar o canal. */
    private const val ESPERA_MOTOR_MS = 12_000L
    private const val PASSO_MOTOR_MS = 300L

    /** Motor sem tela parado depois deste tempo sem perguntas. */
    private const val OCIOSIDADE_MS = 180_000L

    private const val MOTIVO_TEMPO = "tempo"
    private const val MOTIVO_INDISPONIVEL = "indisponivel"
    private const val MOTIVO_VAZIO = "vazio"

    @Volatile private var canal: MethodChannel? = null

    /** Motor sem tela criado por esta ponte (o do app é de outro dono). */
    @Volatile private var motorProprio: FlutterEngine? = null

    private val principal = Handler(Looper.getMainLooper())
    private val desligarOcioso = Runnable { encerrarMotor() }

    fun registrar(engine: FlutterEngine) {
        if (motorProprio != null) encerrarMotor()
        canal = MethodChannel(engine.dartExecutor.binaryMessenger, CANAL)
    }

    fun disponivel(): Boolean = canal != null

    /**
     * Envia a pergunta ao Flutter. [retorno] é chamado uma única vez, na thread
     * principal, com a resposta já limpa (ou `null`) e um motivo curto quando
     * falhou: `sem_provedor`, `tempo`, `indisponivel` ou `vazio`.
     *
     * [contexto] é usado só para subir o motor sem tela quando o app não está
     * aberto; com o app aberto nada é criado.
     */
    fun perguntar(
        contexto: Context,
        texto: String,
        retorno: (String?, String?) -> Unit,
    ) {
        val pedido = texto.trim()
        if (pedido.isEmpty()) {
            retorno(null, MOTIVO_VAZIO)
            return
        }
        val app = contexto.applicationContext
        val respondido = AtomicBoolean(false)
        val entregar: (String?, String?) -> Unit = { resposta, motivo ->
            if (respondido.compareAndSet(false, true)) {
                if (resposta.isNullOrBlank()) marcarOcioso()
                principal.post {
                    retorno(resposta?.trim()?.takeIf { it.isNotEmpty() }, motivo)
                }
            }
        }
        principal.postDelayed({ entregar(null, MOTIVO_TEMPO) }, ESPERA_MS)
        principal.post {
            if (canal == null) subirMotor(app)
            esperarCanal(pedido, tentativas = restantesDoMotor(), entregar = entregar)
        }
    }

    /** Desliga o motor sem tela (fim do serviço ou fim da inatividade). */
    fun encerrar() {
        principal.removeCallbacks(desligarOcioso)
        encerrarMotor()
    }

    private fun restantesDoMotor(): Int =
        (ESPERA_MOTOR_MS / PASSO_MOTOR_MS).toInt()

    private fun marcarOcioso() {
        if (motorProprio == null) return
        principal.removeCallbacks(desligarOcioso)
        principal.postDelayed(desligarOcioso, OCIOSIDADE_MS)
    }

    @Synchronized
    private fun encerrarMotor() {
        val motor = motorProprio ?: return
        motorProprio = null
        canal = null
        try {
            motor.destroy()
        } catch (_: Exception) {
            // Motor já destruído pelo Android: nada a fazer.
        }
    }

    /** Sobe o motor sem tela uma única vez; devolve se há motor para tentar. */
    @Synchronized
    private fun subirMotor(contexto: Context): Boolean {
        if (motorProprio != null || canal != null) return true
        return try {
            val motor = FlutterEngine(contexto)
            motor.dartExecutor.executeDartEntrypoint(
                DartEntrypoint(BIBLIOTECA_FUNDO, ENTRADA_FUNDO)
            )
            motorProprio = motor
            canal = MethodChannel(motor.dartExecutor.binaryMessenger, CANAL)
            true
        } catch (_: Throwable) {
            motorProprio = null
            canal = null
            false
        }
    }

    /**
     * Espera o canal do motor sem tela existir e o Dart registrar o
     * atendimento. Cada tentativa gasta um passo curto; desistir devolve
     * `indisponivel` em vez de segurar o usuário até o prazo total.
     */
    private fun esperarCanal(
        pedido: String,
        tentativas: Int,
        entregar: (String?, String?) -> Unit,
    ) {
        val ativo = canal
        if (ativo == null) {
            if (tentativas <= 0) {
                entregar(null, MOTIVO_INDISPONIVEL)
                return
            }
            principal.postDelayed({
                esperarCanal(pedido, tentativas - 1, entregar)
            }, PASSO_MOTOR_MS)
            return
        }
        enviar(ativo, pedido, tentativas, entregar)
    }

    private fun enviar(
        ativo: MethodChannel,
        pedido: String,
        tentativas: Int,
        entregar: (String?, String?) -> Unit,
    ) {
        try {
            ativo.invokeMethod(
                "responderPergunta",
                mapOf("texto" to pedido),
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        val texto = result as? String
                        entregar(texto, if (texto.isNullOrBlank()) MOTIVO_VAZIO else null)
                    }

                    override fun error(codigo: String, mensagem: String?, detalhe: Any?) {
                        entregar(null, codigo)
                    }

                    override fun notImplemented() {
                        // Dart ainda não registrou o atendimento: nova tentativa.
                        if (tentativas > 0) {
                            principal.postDelayed({
                                esperarCanal(pedido, tentativas - 1, entregar)
                            }, PASSO_MOTOR_MS)
                        } else {
                            entregar(null, MOTIVO_INDISPONIVEL)
                        }
                    }
                }
            )
        } catch (_: Exception) {
            entregar(null, MOTIVO_INDISPONIVEL)
        }
    }
}
