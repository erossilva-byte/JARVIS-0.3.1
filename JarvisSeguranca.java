package com.jarvis.nova;

import android.os.Handler;
import android.os.Looper;

import androidx.biometric.BiometricManager;
import androidx.biometric.BiometricPrompt;
import androidx.core.content.ContextCompat;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import java.util.concurrent.Executor;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Biometria/credencial do aparelho para o bloqueio OPCIONAL do aplicativo.
 *
 * Importante: isto protege apenas a abertura do próprio J.A.R.V.I.S. Não substitui o
 * bloqueio do Android e não impede abrir outros aplicativos. Quem decide se o bloqueio
 * existe é o usuário em Ajustes ▸ Segurança; o PIN do app continua valendo como
 * alternativa e nenhuma autenticação aqui é capaz de inutilizar o aplicativo.
 */
@CapacitorPlugin(name = "JarvisSeguranca")
public class JarvisSeguranca extends Plugin {

    private static final int PERMITIDOS =
        BiometricManager.Authenticators.BIOMETRIC_STRONG | BiometricManager.Authenticators.DEVICE_CREDENTIAL;

    @PluginMethod
    public void disponivel(PluginCall call) {
        JSObject out = new JSObject();
        boolean biometria = false;
        boolean aparelho = false;
        String motivo = "";
        try {
            BiometricManager bm = BiometricManager.from(getContext());
            int fortes = bm.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG);
            int comCredencial = bm.canAuthenticate(PERMITIDOS);
            biometria = fortes == BiometricManager.BIOMETRIC_SUCCESS;
            aparelho = comCredencial == BiometricManager.BIOMETRIC_SUCCESS;
            motivo = descrever(comCredencial);
        } catch (Throwable e) {
            motivo = "Não foi possível consultar a biometria neste aparelho.";
        }
        out.put("biometria", biometria);
        out.put("aparelho", aparelho);
        out.put("motivo", motivo);
        call.resolve(out);
    }

    @PluginMethod
    public void autenticar(final PluginCall call) {
        final String titulo = call.getString("titulo", "Desbloquear o J.A.R.V.I.S.");
        final String subtitulo = call.getString("subtitulo", "Confirme sua identidade para liberar o aplicativo.");
        final AtomicBoolean respondido = new AtomicBoolean(false);
        new Handler(Looper.getMainLooper()).post(new Runnable() {
            @Override
            public void run() {
                try {
                    Executor executor = ContextCompat.getMainExecutor(getContext());
                    BiometricPrompt prompt = new BiometricPrompt(getActivity(), executor, new BiometricPrompt.AuthenticationCallback() {
                        @Override
                        public void onAuthenticationSucceeded(BiometricPrompt.AuthenticationResult result) {
                            if (!respondido.compareAndSet(false, true)) return;
                            JSObject out = new JSObject();
                            out.put("ok", true);
                            call.resolve(out);
                        }

                        @Override
                        public void onAuthenticationError(int codigo, CharSequence mensagem) {
                            if (!respondido.compareAndSet(false, true)) return;
                            // Cancelamento do usuário não é falha de segurança: o PIN continua disponível.
                            call.reject(mensagem == null ? "Autenticação cancelada." : mensagem.toString());
                        }

                        @Override
                        public void onAuthenticationFailed() {
                            // Tentativa não reconhecida: o prompt continua aberto. Não finaliza a chamada.
                        }
                    });
                    BiometricPrompt.PromptInfo info = new BiometricPrompt.PromptInfo.Builder()
                        .setTitle(titulo)
                        .setSubtitle(subtitulo)
                        .setAllowedAuthenticators(PERMITIDOS)
                        .setConfirmationRequired(false)
                        .build();
                    prompt.authenticate(info);
                } catch (Throwable e) {
                    if (!respondido.compareAndSet(false, true)) return;
                    call.reject("Biometria indisponível neste aparelho. Use o PIN do aplicativo.");
                }
            }
        });
    }

    private String descrever(int codigo) {
        switch (codigo) {
            case BiometricManager.BIOMETRIC_SUCCESS:
                return "Biometria ou credencial do aparelho disponível.";
            case BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE:
                return "Este aparelho não tem sensor biométrico; use o PIN do aplicativo.";
            case BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE:
                return "Sensor biométrico temporariamente indisponível; use o PIN do aplicativo.";
            case BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED:
                return "Nenhuma digital/rosto cadastrado no aparelho; cadastre nas configurações do Android ou use o PIN.";
            case BiometricManager.BIOMETRIC_STATUS_UNKNOWN:
                return "O sistema não informou o estado da biometria; use o PIN do aplicativo.";
            default:
                return "Biometria indisponível; use o PIN do aplicativo.";
        }
    }
}
