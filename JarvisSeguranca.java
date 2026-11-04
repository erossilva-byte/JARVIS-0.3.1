package com.jarvis.nova;

import android.app.Activity;
import android.nfc.NfcAdapter;
import android.nfc.Tag;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.content.pm.PackageManager;

import androidx.biometric.BiometricManager;
import androidx.biometric.BiometricPrompt;
import androidx.core.content.ContextCompat;

import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import java.util.concurrent.Executor;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Biometria/credencial do aparelho e leitura NFC para o bloqueio OPCIONAL do aplicativo.
 *
 * Importante: isto protege apenas a abertura do próprio J.A.R.V.I.S. Não substitui o
 * bloqueio do Android e não impede abrir outros aplicativos. Quem decide se o bloqueio
 * existe é o usuário em Ajustes ▸ Segurança; o PIN do app continua valendo como
 * alternativa e nenhuma autenticação aqui é capaz de inutilizar o aplicativo.
 *
 * NFC: o plugin só lê o UID e as tecnologias da tag. Quem decide se ela desbloqueia é o
 * JavaScript, comparando o hash do UID com a lista autorizada. Um UID simples pode ser
 * clonado; por isso a interface trata NFC como conveniência e oferece duas etapas.
 */
@CapacitorPlugin(name = "JarvisSeguranca")
public class JarvisSeguranca extends Plugin {

    private static final int FORTE = BiometricManager.Authenticators.BIOMETRIC_STRONG;
    private static final int FORTE_OU_APARELHO =
        BiometricManager.Authenticators.BIOMETRIC_STRONG | BiometricManager.Authenticators.DEVICE_CREDENTIAL;

    private final Handler principal = new Handler(Looper.getMainLooper());
    private NfcAdapter leitor;
    private PluginCall chamadaNfc;
    private Runnable prazoNfc;

    @PluginMethod
    public void disponivel(PluginCall call) {
        JSObject out = new JSObject();
        boolean biometria = false;
        boolean aparelho = false;
        String motivo = "";
        try {
            BiometricManager bm = BiometricManager.from(getContext());
            biometria = bm.canAuthenticate(FORTE) == BiometricManager.BIOMETRIC_SUCCESS;
            aparelho = bm.canAuthenticate(FORTE_OU_APARELHO) == BiometricManager.BIOMETRIC_SUCCESS;
            motivo = descrever(bm.canAuthenticate(FORTE_OU_APARELHO));
        } catch (Throwable e) {
            motivo = "Não foi possível consultar a biometria neste aparelho.";
        }
        out.put("biometria", biometria);
        out.put("aparelho", aparelho);
        out.put("rosto", temRosto());
        out.put("digital", temDigital());
        out.put("nfc", nfcLigado());
        out.put("motivo", motivo);
        call.resolve(out);
    }

    @PluginMethod
    public void nfcDisponivel(PluginCall call) {
        JSObject out = new JSObject();
        NfcAdapter a = NfcAdapter.getDefaultAdapter(getContext());
        out.put("existe", a != null);
        out.put("ligado", a != null && a.isEnabled());
        out.put("motivo", a == null
            ? "Este aparelho não tem leitor NFC."
            : (a.isEnabled() ? "NFC ligado." : "O NFC está desligado; ative nas configurações do Android."));
        call.resolve(out);
    }

    /**
     * Lê uma tag por até {@code segundos}. Resolve com uid, tech e criptografica; rejeita se
     * não houver hardware, se o NFC estiver desligado ou se o tempo acabar. Uma leitura por
     * chamada, sempre encerrada no fim, na pausa e no cancelamento.
     */
    @PluginMethod
    public void nfcLer(final PluginCall call) {
        final int segundos = Math.max(5, Math.min(60, call.getInt("segundos", 20)));
        principal.post(() -> {
            NfcAdapter a = NfcAdapter.getDefaultAdapter(getContext());
            if (a == null) { call.reject("Este aparelho não tem leitor NFC."); return; }
            if (!a.isEnabled()) { call.reject("O NFC está desligado. Ative nas configurações do Android e tente de novo."); return; }
            if (chamadaNfc != null) { call.reject("Já existe uma leitura NFC em andamento."); return; }
            final Activity at = getActivity();
            if (at == null) { call.reject("A tela do aplicativo não está disponível para ler a tag."); return; }
            leitor = a;
            chamadaNfc = call;
            prazoNfc = () -> {
                if (chamadaNfc != call) return;
                encerrarLeitura();
                call.reject("Nenhuma tag aproximada em " + segundos + " s.");
            };
            principal.postDelayed(prazoNfc, segundos * 1000L);
            try {
                a.enableReaderMode(at, new NfcAdapter.ReaderCallback() {
                    @Override
                    public void onTagDiscovered(Tag tag) {
                        if (chamadaNfc != call) return;
                        JSObject out = new JSObject();
                        out.put("uid", hex(tag.getId()));
                        JSArray tech = new JSArray();
                        boolean iso = false;
                        String[] lista = tag.getTechList();
                        if (lista != null) {
                            for (String t : lista) {
                                tech.put(t);
                                if (t != null && t.endsWith("IsoDep")) iso = true;
                            }
                        }
                        out.put("tech", tech);
                        out.put("criptografica", iso);
                        encerrarLeitura();
                        call.resolve(out);
                    }
                }, NfcAdapter.FLAG_READER_NFC_A | NfcAdapter.FLAG_READER_NFC_B
                    | NfcAdapter.FLAG_READER_NFC_F | NfcAdapter.FLAG_READER_NFC_V
                    | NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS, null);
            } catch (Throwable e) {
                encerrarLeitura();
                call.reject("Não foi possível iniciar a leitura NFC neste aparelho.");
            }
        });
    }

    @PluginMethod
    public void nfcCancelar(PluginCall call) {
        principal.post(() -> {
            if (chamadaNfc != null) chamadaNfc.reject("Leitura NFC cancelada.");
            encerrarLeitura();
        });
        call.resolve();
    }

    @PluginMethod
    public void autenticar(final PluginCall call) {
        final String titulo = call.getString("titulo", "Desbloquear o J.A.R.V.I.S.");
        final String subtitulo = call.getString("subtitulo", "Confirme sua identidade para liberar o aplicativo.");
        // Por padrão aceita a credencial do aparelho como recuperação; o app pode pedir
        // biometria estrita (sem PIN do sistema) quando o modo exige apenas biometria.
        final boolean comCredencial = !Boolean.FALSE.equals(call.getBoolean("permitirCredencial", true));
        final int permitidos = comCredencial ? FORTE_OU_APARELHO : FORTE;
        final AtomicBoolean respondido = new AtomicBoolean(false);
        principal.post(() -> {
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
                BiometricPrompt.PromptInfo.Builder info = new BiometricPrompt.PromptInfo.Builder()
                    .setTitle(titulo)
                    .setSubtitle(subtitulo)
                    .setAllowedAuthenticators(permitidos)
                    .setConfirmationRequired(false);
                if (!comCredencial) info.setNegativeButtonText("Cancelar");
                prompt.authenticate(info.build());
            } catch (Throwable e) {
                if (!respondido.compareAndSet(false, true)) return;
                call.reject("Biometria indisponível neste aparelho. Use o PIN do aplicativo.");
            }
        });
    }

    /** A leitura nunca sobrevive à saída da tela: sem isso o sensor ficaria ativo em segundo plano. */
    @Override
    protected void handleOnPause() {
        encerrarLeitura();
        super.handleOnPause();
    }

    @Override
    protected void handleOnDestroy() {
        encerrarLeitura();
        super.handleOnDestroy();
    }

    private void encerrarLeitura() {
        if (prazoNfc != null) { principal.removeCallbacks(prazoNfc); prazoNfc = null; }
        if (leitor != null) {
            try {
                Activity at = getActivity();
                if (at != null) leitor.disableReaderMode(at);
            } catch (Throwable e) {
                // sem leitura ativa: nada a desfazer
            }
        }
        leitor = null;
        chamadaNfc = null;
    }

    private boolean nfcLigado() {
        try {
            NfcAdapter a = NfcAdapter.getDefaultAdapter(getContext());
            return a != null && a.isEnabled();
        } catch (Throwable e) {
            return false;
        }
    }

    private boolean temRosto() {
        try {
            if (Build.VERSION.SDK_INT < 29) return false;
            return getContext().getPackageManager().hasSystemFeature(PackageManager.FEATURE_FACE);
        } catch (Throwable e) {
            return false;
        }
    }

    private boolean temDigital() {
        try {
            return getContext().getPackageManager().hasSystemFeature(PackageManager.FEATURE_FINGERPRINT);
        } catch (Throwable e) {
            return false;
        }
    }

    private static String hex(byte[] dados) {
        if (dados == null) return "";
        StringBuilder sb = new StringBuilder();
        for (byte b : dados) sb.append(String.format("%02X", b));
        return sb.toString();
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
                return "Nenhuma biometria forte cadastrada no Android; cadastre nas configurações do sistema ou use o PIN.";
            case BiometricManager.BIOMETRIC_STATUS_UNKNOWN:
                return "O sistema não informou o estado da biometria; use o PIN do aplicativo.";
            default:
                return "Biometria indisponível; use o PIN do aplicativo.";
        }
    }
}
