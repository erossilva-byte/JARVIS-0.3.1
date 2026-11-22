package com.jarvis.nova

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.hardware.fingerprint.FingerprintManager
import android.os.Build
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Biometria e credencial do aparelho para a tela de bloqueio.
 *
 * Usa apenas as APIs do próprio Android: `BiometricPrompt` (Android 9+) e
 * `FingerprintManager` (Android 8) para a digital, e `KeyguardManager` para a
 * credencial do sistema usada na recuperação do PIN. Não há dependência nova nem
 * envio de dado biométrico para fora do aparelho — o Android só devolve
 * "autenticou" ou "não autenticou".
 */
class JarvisBiometria(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        const val CANAL = "com.jarvis.nova/biometria"
        private const val CODIGO_CREDENCIAL = 47160

        private var pendenteCredencial: MethodChannel.Result? = null

        /** Chamado pelo [MainActivity] quando a tela de credencial retorna. */
        @JvmStatic
        fun tratarResultado(requestCode: Int, resultCode: Int): Boolean {
            if (requestCode != CODIGO_CREDENCIAL) return false
            val pendente = pendenteCredencial ?: return true
            pendenteCredencial = null
            if (resultCode == Activity.RESULT_OK) {
                pendente.success(
                    mapOf("ok" to true, "mensagem" to "Credencial do aparelho confirmada.")
                )
            } else {
                pendente.success(
                    mapOf("ok" to false, "mensagem" to "Credencial do aparelho não confirmada.")
                )
            }
            return true
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var pendenteBiometria: MethodChannel.Result? = null
    private var cancelamento: CancellationSignal? = null

    fun registrar(engine: io.flutter.embedding.engine.FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CANAL)
            .setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "estado" -> result.success(estado())
            "autenticar" -> autenticar(call.argument<String>("motivo").orEmpty(), result)
            "credencialAparelho" ->
                credencialDoAparelho(call.argument<String>("motivo").orEmpty(), result)
            else -> result.notImplemented()
        }
    }

    private fun estado(): Map<String, Any> {
        val hardware = activity.packageManager.hasSystemFeature(
            android.content.pm.PackageManager.FEATURE_FINGERPRINT
        ) || (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && activity.packageManager
            .hasSystemFeature(android.content.pm.PackageManager.FEATURE_FACE))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val gerenciador = activity.getSystemService(BiometricManager::class.java)
            val codigo = gerenciador?.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_WEAK)
                ?: BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE
            return mapOf(
                "estado" to when (codigo) {
                    BiometricManager.BIOMETRIC_SUCCESS -> "pronto"
                    BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "sem_cadastro"
                    else -> "indisponivel"
                },
                "hardware" to hardware,
                "api" to Build.VERSION.SDK_INT,
            )
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            // Android 9 tem BiometricPrompt, mas não o BiometricManager público.
            val digital = activity.getSystemService(FingerprintManager::class.java)
            val temSensor = digital?.isHardwareDetected == true
            val inscrito = digital?.hasEnrolledFingerprints() == true
            return mapOf(
                "estado" to when {
                    !temSensor -> "indisponivel"
                    inscrito -> "pronto"
                    else -> "sem_cadastro"
                },
                "hardware" to temSensor,
                "api" to Build.VERSION.SDK_INT,
            )
        }
        return mapOf("estado" to "indisponivel", "hardware" to hardware, "api" to Build.VERSION.SDK_INT)
    }

    private fun ocupado(result: MethodChannel.Result): Boolean {
        if (pendenteBiometria == null) return false
        result.error("em_andamento", "Já existe um pedido de biometria em andamento.", null)
        return true
    }

    private fun autenticar(motivo: String, result: MethodChannel.Result) {
        if (ocupado(result)) return
        val titulo = motivo.trim().ifEmpty { "Desbloquear o J.A.R.V.I.S." }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val executor = androidx.core.content.ContextCompat.getMainExecutor(activity)
            pendenteBiometria = result
            val prompt = BiometricPrompt.Builder(activity)
                .setTitle("J.A.R.V.I.S. Nova")
                .setSubtitle(titulo)
                .setNegativeButton("Usar o PIN", executor) { _, _ ->
                    finalizar(false, "Autenticação cancelada.")
                }
                .build()
            val sinal = CancellationSignal()
            cancelamento = sinal
            try {
                prompt.authenticate(
                    sinal,
                    executor,
                    object : BiometricPrompt.AuthenticationCallback() {
                        override fun onAuthenticationSucceeded(
                            authenticationResult: BiometricPrompt.AuthenticationResult
                        ) {
                            finalizar(true, "Biometria confirmada.")
                        }

                        override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                            finalizar(false, "Biometria não confirmada: $errString")
                        }
                    }
                )
            } catch (erro: Exception) {
                pendenteBiometria = null
                result.error(
                    "biometria_falhou",
                    "O Android recusou abrir a biometria: ${erro.message ?: erro.javaClass.simpleName}",
                    null
                )
            }
            return
        }
        autenticarDigital(titulo, result)
    }

    @Suppress("DEPRECATION")
    private fun autenticarDigital(titulo: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.success(mapOf("ok" to false, "mensagem" to "Este Android não oferece biometria ao app."))
            return
        }
        val gerenciador = activity.getSystemService(FingerprintManager::class.java)
        if (gerenciador == null || !gerenciador.isHardwareDetected) {
            result.success(mapOf("ok" to false, "mensagem" to "Este aparelho não tem leitor de digital."))
            return
        }
        if (!gerenciador.hasEnrolledFingerprints()) {
            result.success(
                mapOf("ok" to false, "mensagem" to "Nenhuma digital cadastrada no aparelho.")
            )
            return
        }
        pendenteBiometria = result
        cancelamento = CancellationSignal()
        try {
            gerenciador.authenticate(
                null,
                cancelamento,
                0,
                object : FingerprintManager.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(resultado: FingerprintManager.AuthenticationResult?) {
                        finalizar(true, "Digital confirmada.")
                    }

                    override fun onAuthenticationError(codigo: Int, mensagem: CharSequence?) {
                        val excecao = mensagem?.toString().orEmpty()
                        finalizar(false, "Digital não confirmada: $excecao")
                    }

                    override fun onAuthenticationFailed() {
                        finalizar(false, "Digital não reconhecida. Tente de novo ou use o PIN.")
                    }
                },
                handler
            )
        } catch (erro: Exception) {
            pendenteBiometria = null
            result.error(
                "biometria_falhou",
                "O Android recusou abrir a biometria: ${erro.message ?: erro.javaClass.simpleName}",
                null
            )
        }
    }

    private fun finalizar(ok: Boolean, mensagem: String) {
        val pendente = pendenteBiometria ?: return
        pendenteBiometria = null
        try {
            cancelamento?.cancel()
        } catch (_: Exception) {
        }
        cancelamento = null
        pendente.success(mapOf("ok" to ok, "mensagem" to mensagem))
    }

    private fun credencialDoAparelho(motivo: String, result: MethodChannel.Result) {
        if (pendenteCredencial != null) {
            result.error("em_andamento", "Já existe um pedido de credencial em andamento.", null)
            return
        }
        val gerenciador = activity.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        if (gerenciador == null || gerenciador.isDeviceSecure != true) {
            result.success(
                mapOf(
                    "ok" to false,
                    "mensagem" to "Este aparelho não tem PIN, senha ou padrão de tela configurado."
                )
            )
            return
        }
        val titulo = motivo.trim().ifEmpty { "Confirme a credencial do aparelho" }
        val intent: Intent? = gerenciador.createConfirmDeviceCredentialIntent(
            "J.A.R.V.I.S. Nova",
            titulo
        )
        if (intent == null) {
            result.success(
                mapOf("ok" to false, "mensagem" to "O Android não abriu a confirmação do aparelho.")
            )
            return
        }
        pendenteCredencial = result
        try {
            activity.startActivityForResult(intent, CODIGO_CREDENCIAL)
        } catch (erro: Exception) {
            pendenteCredencial = null
            result.error(
                "credencial_falhou",
                "O Android recusou abrir a credencial: ${erro.message ?: erro.javaClass.simpleName}",
                null
            )
        }
    }
}
