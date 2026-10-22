package com.jarvis.nova;

import android.Manifest;
import android.app.NotificationManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.PowerManager;
import android.provider.Settings;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;

import com.getcapacitor.JSObject;
import com.getcapacitor.PermissionState;
import androidx.core.content.ContextCompat;

import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.getcapacitor.annotation.Permission;
import com.getcapacitor.annotation.PermissionCallback;

import java.util.ArrayList;

/**
 * Ponte da interface com o serviço de escuta e com o reconhecimento de voz do Android.
 *
 * A detecção da palavra de ativação agora vive no JarvisService (sobrevive ao app em
 * segundo plano). Este plugin só pede para começar/parar e recebe os eventos.
 */
@CapacitorPlugin(
    name = "JarvisBackground",
    permissions = { @Permission(strings = { Manifest.permission.RECORD_AUDIO }, alias = "mic") }
)
public class JarvisBackgroundPlugin extends Plugin {

    private final Handler main = new Handler(Looper.getMainLooper());
    private SpeechRecognizer transcricaoRec;
    private PluginCall transcricaoCall;
    private Runnable transcricaoTimeout;
    private String textoParcialTranscricao = "";
    private boolean transcricaoSomenteLocal = false;
    private boolean transcricaoJaTentouRede = false;

    private JarvisWakeBus.Ouvinte ouvinte;

    @Override
    public void load() {
        ouvinte = new JarvisWakeBus.Ouvinte() {
            @Override public void aoAcordar(String texto, String detector) {
                JSObject o = new JSObject();
                o.put("texto", texto == null ? "Jarvis" : texto);
                o.put("detector", detector == null ? "" : detector);
                notifyListeners("wake", o);
            }

            @Override public void aoParar(String motivo) {
                JSObject o = new JSObject();
                o.put("motivo", motivo == null ? "motivo desconhecido" : motivo);
                notifyListeners("wakeparou", o);
            }
        };
        // Entrega um evento que tenha acontecido enquanto o app estava fechado.
        JarvisWakeBus.registrar(ouvinte);
    }

    /* ---------- Serviço em segundo plano ---------- */

    @PluginMethod
    public void start(PluginCall call) {
        if (getPermissionState("mic") != PermissionState.GRANTED) {
            requestPermissionForAlias("mic", call, "aposPermissaoMic");
            return;
        }
        try {
            JarvisService.iniciarServico(getContext());
            call.resolve();
        } catch (Exception e) {
            call.reject("Não consegui iniciar o serviço: " + e.getMessage());
        }
    }

    @PermissionCallback
    private void aposPermissaoMic(PluginCall call) {
        if (getPermissionState("mic") == PermissionState.GRANTED) start(call);
        else call.reject("Microfone negado");
    }

    @PluginMethod
    public void stop(PluginCall call) {
        JarvisService.pararTudo(getContext());
        call.resolve();
    }

    /** Desliga a escuta de propósito (o vigia para de tentar reiniciar). */
    @PluginMethod
    public void desligarEscuta(PluginCall call) {
        JarvisService.desligar(getContext());
        call.resolve();
    }

    /* ---------- Palavra de ativação ---------- */

    @PluginMethod
    public void startWake(PluginCall call) {
        if (getPermissionState("mic") != PermissionState.GRANTED) {
            requestPermissionForAlias("mic", call, "aposPermissaoWake");
            return;
        }
        iniciarWake(call);
    }

    @PermissionCallback
    private void aposPermissaoWake(PluginCall call) {
        if (getPermissionState("mic") == PermissionState.GRANTED) iniciarWake(call);
        else call.reject("Microfone negado");
    }

    private void iniciarWake(PluginCall call) {
        try {
            String accessKey = call.getString("accessKey", "");
            boolean pausar = !Boolean.FALSE.equals(call.getBoolean("pausarDuranteMusica", true));
            JarvisService.iniciarEscuta(getContext(), accessKey, pausar);
            JSObject o = new JSObject();
            o.put("servico", "JarvisService");
            call.resolve(o);
        } catch (Exception e) {
            call.reject("Não consegui iniciar a escuta em segundo plano: "
                + (e.getMessage() == null ? "erro desconhecido" : e.getMessage()));
        }
    }

    @PluginMethod
    public void stopWake(PluginCall call) {
        // Pausa temporária: o estado desejado continua ligado para o serviço voltar sozinho.
        JarvisService.pausarEscuta();
        call.resolve();
    }

    @PluginMethod
    public void pausarEscuta(PluginCall call) {
        JarvisService.pausarEscuta();
        call.resolve();
    }

    /** Teste de 20 s da palavra de ativação: conta acertos sem abrir o app. */
    @PluginMethod
    public void iniciarTesteEscuta(PluginCall call) {
        if (getPermissionState("mic") != PermissionState.GRANTED) {
            requestPermissionForAlias("mic", call, "aposPermissaoTeste");
            return;
        }
        Integer pedido = call.getInt("segundos");
        int segundos = pedido == null ? 20 : pedido.intValue();
        try {
            JarvisService.iniciarTeste(getContext(), segundos);
            call.resolve(JarvisService.statusTeste());
        } catch (Exception e) {
            call.reject("Não consegui iniciar o teste: " + (e.getMessage() == null ? "erro desconhecido" : e.getMessage()));
        }
    }

    @PermissionCallback
    private void aposPermissaoTeste(PluginCall call) {
        if (getPermissionState("mic") == PermissionState.GRANTED) iniciarTesteEscuta(call);
        else call.reject("Microfone negado");
    }

    @PluginMethod
    public void statusTesteEscuta(PluginCall call) {
        call.resolve(JarvisService.statusTeste());
    }

    @PluginMethod
    public void pararTesteEscuta(PluginCall call) {
        JarvisService.pararTeste(getContext());
        call.resolve();
    }

    /** Pedido feito pelo botão "Ouvir agora" da notificação. */
    @PluginMethod
    public void consumirPedidoOuvir(PluginCall call) {
        Context ctx = getContext();
        boolean pedido = JarvisPrefs.pedidoOuvir(ctx);
        if (pedido) JarvisPrefs.pedidoOuvir(ctx, false);
        JSObject o = new JSObject();
        o.put("pedido", pedido);
        call.resolve(o);
    }

    /**
     * Diagnóstico honesto do segundo plano: cada item reflete uma consulta real ao
     * sistema, sem inventar "tudo certo". A interface usa isto para dizer o que falta.
     */
    @PluginMethod
    public void diagnosticoEscuta(PluginCall call) {
        Context c = getContext();
        JSObject o = new JSObject();
        o.put("mic", getPermissionState("mic") == PermissionState.GRANTED);
        boolean notifPermitida = true;
        if (Build.VERSION.SDK_INT >= 33) {
            notifPermitida = ContextCompat.checkSelfPermission(c, Manifest.permission.POST_NOTIFICATIONS)
                == android.content.pm.PackageManager.PERMISSION_GRANTED;
        }
        NotificationManager nm = (NotificationManager) c.getSystemService(Context.NOTIFICATION_SERVICE);
        o.put("notificacoes", notifPermitida && (nm == null || nm.areNotificationsEnabled()));
        try {
            PowerManager pm = (PowerManager) c.getSystemService(Context.POWER_SERVICE);
            o.put("bateriaLivre", pm != null && pm.isIgnoringBatteryOptimizations(c.getPackageName()));
        } catch (Exception e) {
            o.put("bateriaLivre", false);
        }
        boolean sobreposicao = false;
        if (Build.VERSION.SDK_INT >= 23) {
            try { sobreposicao = Settings.canDrawOverlays(c); } catch (Exception ignored) { }
        }
        o.put("sobreposicao", sobreposicao);
        boolean acessoNotif = false;
        try {
            String habilitados = Settings.Secure.getString(c.getContentResolver(), "enabled_notification_listeners");
            acessoNotif = habilitados != null && habilitados.contains(c.getPackageName());
        } catch (Exception ignored) { }
        o.put("acessoNotificacoes", acessoNotif);
        o.put("servico", JarvisService.ativo());
        o.put("escutando", JarvisService.escutando());
        o.put("detector", JarvisService.detectorAtual());
        o.put("desejada", JarvisPrefs.desejaOuvir(c));
        o.put("chaveSalva", JarvisPrefs.temChave(c));
        o.put("ultimoErro", JarvisPrefs.ultimoErro(c));
        o.put("ultimoEvento", JarvisPrefs.ultimoEvento(c));
        o.put("fabricante", Build.MANUFACTURER == null ? "" : Build.MANUFACTURER);
        o.put("modelo", Build.MODEL == null ? "" : Build.MODEL);
        o.put("android", Build.VERSION.RELEASE == null ? "" : Build.VERSION.RELEASE);
        o.put("testeAtivo", JarvisService.testeAtivo());
        o.put("restricaoOem", restricaoOem());
        call.resolve(o);
    }

    private String restricaoOem() {
        String m = Build.MANUFACTURER == null ? "" : Build.MANUFACTURER.toLowerCase(java.util.Locale.ROOT);
        if (m.contains("xiaomi") || m.contains("redmi") || m.contains("poco")) return "xiaomi";
        if (m.contains("samsung")) return "samsung";
        if (m.contains("motorola") || m.contains("moto")) return "motorola";
        if (m.contains("huawei") || m.contains("honor")) return "huawei";
        if (m.contains("oppo") || m.contains("realme") || m.contains("oneplus")) return "oppo";
        if (m.contains("vivo")) return "vivo";
        if (m.contains("asus")) return "asus";
        return "";
    }

    /** Abre a tela de "início automático"/autostart do fabricante, com fallback honesto. */
    @PluginMethod
    public void abrirAutostart(PluginCall call) {
        Context c = getContext();
        String oem = restricaoOem();
        String[][] alvos = {
            { "xiaomi", "com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity" },
            { "samsung", "com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity" },
            { "samsung", "com.samsung.android.sm", "com.samsung.android.sm.ui.battery.BatteryActivity" },
            { "motorola", "com.motorola.motocare", "com.motorola.motocare.internal.settings.AutoStartActivity" },
            { "huawei", "com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity" },
            { "oppo", "com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity" },
            { "vivo", "com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity" },
            { "asus", "com.asus.mobilemanager", "com.asus.mobilemanager.autostart.AutoStartActivity" }
        };
        for (String[] alvo : alvos) {
            if (!oem.equals(alvo[0])) continue;
            try {
                Intent i = new Intent();
                i.setComponent(new ComponentName(alvo[1], alvo[2]));
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                c.startActivity(i);
                JSObject o = new JSObject();
                o.put("aberto", true);
                o.put("fabricante", oem);
                o.put("info", "Abrindo a tela de início automático do fabricante. Ative o J.A.R.V.I.S. Nova na lista.");
                call.resolve(o);
                return;
            } catch (Exception ignored) { }
        }
        try {
            Intent i = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:" + c.getPackageName()));
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            c.startActivity(i);
            JSObject o = new JSObject();
            o.put("aberto", false);
            o.put("fabricante", oem);
            o.put("info", "Este aparelho não expõe uma tela de início automático conhecida. Abri as informações do app: procure “Iniciar automaticamente” ou “Autostart” e permita.");
            call.resolve(o);
        } catch (Exception e) {
            call.reject("Não consegui abrir as configurações do app: " + e.getMessage());
        }
    }

    /** Evento guardado enquanto o app estava fechado (chamado depois de registrar o ouvinte). */
    @PluginMethod
    public void consumirEventoPendente(PluginCall call) {
        JSObject pendente = JarvisWakeBus.consumirPendente();
        call.resolve(pendente == null ? new JSObject() : pendente);
    }

    /** Informa à interface qual detector está ativo agora. */
    @PluginMethod
    public void statusEscuta(PluginCall call) {
        JSObject o = new JSObject();
        o.put("escutando", JarvisService.escutando());
        o.put("detector", JarvisService.detectorAtual());
        o.put("servico", JarvisService.ativo());
        o.put("desejada", JarvisPrefs.desejaOuvir(getContext()));
        o.put("testeAtivo", JarvisService.testeAtivo());
        call.resolve(o);
    }

    /* ---------- Transcrição alternativa do Android ---------- */

    @PluginMethod
    public void transcreverNativo(PluginCall call) {
        if (getPermissionState("mic") != PermissionState.GRANTED) {
            requestPermissionForAlias("mic", call, "aposPermissaoTranscricao");
            return;
        }
        main.post(() -> iniciarTranscricaoNativa(call));
    }

    @PermissionCallback
    private void aposPermissaoTranscricao(PluginCall call) {
        if (getPermissionState("mic") == PermissionState.GRANTED) main.post(() -> iniciarTranscricaoNativa(call));
        else call.reject("Permissão do microfone negada.");
    }

    @PluginMethod
    public void cancelarTranscricaoNativa(PluginCall call) {
        main.post(() -> {
            PluginCall pendente = transcricaoCall;
            encerrarTranscricaoNativa();
            if (pendente != null) pendente.reject("Transcrição cancelada pelo usuário.");
            call.resolve();
        });
    }

    private void iniciarTranscricaoNativa(PluginCall call) {
        if (!SpeechRecognizer.isRecognitionAvailable(getContext())) {
            call.reject("O Android não oferece um serviço de reconhecimento de voz neste aparelho.");
            return;
        }
        encerrarTranscricaoNativa();
        // Só pode haver um microfone por vez: a escuta de ativação sai da frente.
        JarvisService.pausarEscuta();
        transcricaoCall = call;
        textoParcialTranscricao = "";
        transcricaoSomenteLocal = Boolean.TRUE.equals(call.getBoolean("somenteLocal", false));
        transcricaoJaTentouRede = false;
        boolean existirLocal = temLocal();
        if (transcricaoSomenteLocal && !existirLocal) {
            transcricaoCall = null;
            call.reject("Modo offline: reconhecimento de voz local indisponível neste aparelho (falta o pacote de português). Digite o comando ou desligue o modo offline.");
            return;
        }
        boolean preferirLocal = Boolean.TRUE.equals(call.getBoolean("preferirLocal", true));
        // Pequena espera para o serviço soltar o microfone (Porcupine/reconhecedor) antes de abrir outro.
        final boolean usarLocal = existirLocal && (transcricaoSomenteLocal || preferirLocal);
        main.postDelayed(() -> {
            if (transcricaoCall != null) iniciarReconhecedor(usarLocal);
        }, 350);
    }

    private boolean temLocal() {
        try {
            return Build.VERSION.SDK_INT >= 31 && SpeechRecognizer.isOnDeviceRecognitionAvailable(getContext());
        } catch (Exception e) {
            return false;
        }
    }

    private void iniciarReconhecedor(final boolean local) {
        try {
            transcricaoRec = local
                ? SpeechRecognizer.createOnDeviceSpeechRecognizer(getContext())
                : SpeechRecognizer.createSpeechRecognizer(getContext());
        } catch (Exception e) {
            if (local && !transcricaoSomenteLocal && !transcricaoJaTentouRede) {
                transcricaoJaTentouRede = true;
                iniciarReconhecedor(false);
                return;
            }
            String detalhe = e.getMessage() == null ? "erro desconhecido" : e.getMessage();
            PluginCall pendente = transcricaoCall;
            soltarReconhecedor();
            transcricaoCall = null;
            if (pendente != null) pendente.reject("Não consegui iniciar o reconhecimento Android: " + detalhe);
            return;
        }
        transcricaoRec.setRecognitionListener(new RecognitionListener() {
            @Override public void onReadyForSpeech(Bundle params) { }
            @Override public void onBeginningOfSpeech() { }
            @Override public void onRmsChanged(float rmsdB) { }
            @Override public void onBufferReceived(byte[] buffer) { }
            @Override public void onEndOfSpeech() { }
            @Override public void onEvent(int eventType, Bundle params) { }

            @Override public void onPartialResults(Bundle results) {
                ArrayList<String> lista = results == null ? null : results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
                if (lista != null && !lista.isEmpty()) textoParcialTranscricao = lista.get(0);
            }

            @Override public void onResults(Bundle results) {
                ArrayList<String> lista = results == null ? null : results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
                String texto = (lista != null && !lista.isEmpty()) ? lista.get(0) : textoParcialTranscricao;
                PluginCall atual = transcricaoCall;
                encerrarTranscricaoNativa();
                if (atual == null) return;
                if (texto == null || texto.trim().isEmpty()) {
                    atual.reject("O Android não reconheceu uma frase. Tente novamente ou digite o comando.");
                    return;
                }
                JSObject ret = new JSObject();
                ret.put("texto", texto.trim());
                ret.put("mecanismo", local ? "local-no-dispositivo" : "servico-android");
                atual.resolve(ret);
            }

            @Override public void onError(int error) {
                // Pacote de português offline ausente ou idioma não suportado: tenta o serviço normal.
                boolean falhaDeIdioma = error == 12 || error == 13 || error == 14;
                if (local && !transcricaoSomenteLocal && !transcricaoJaTentouRede
                    && (falhaDeIdioma || error == SpeechRecognizer.ERROR_NETWORK || error == SpeechRecognizer.ERROR_NETWORK_TIMEOUT)) {
                    transcricaoJaTentouRede = true;
                    String parcial = textoParcialTranscricao;
                    soltarReconhecedor();
                    textoParcialTranscricao = parcial;
                    if (transcricaoCall != null) iniciarReconhecedor(false);
                    return;
                }
                PluginCall atual = transcricaoCall;
                String parcial = textoParcialTranscricao;
                encerrarTranscricaoNativa();
                if (atual == null) return;
                if (parcial != null && !parcial.trim().isEmpty()) {
                    JSObject ret = new JSObject();
                    ret.put("texto", parcial.trim());
                    ret.put("mecanismo", "parcial-android");
                    atual.resolve(ret);
                    return;
                }
                String motivo;
                switch (error) {
                    case SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS:
                        motivo = "Permissão de microfone insuficiente."; break;
                    case SpeechRecognizer.ERROR_NETWORK:
                    case SpeechRecognizer.ERROR_NETWORK_TIMEOUT:
                        motivo = "O serviço de reconhecimento do Android precisa de internet e não conseguiu responder."; break;
                    case SpeechRecognizer.ERROR_NO_MATCH:
                    case SpeechRecognizer.ERROR_SPEECH_TIMEOUT:
                        motivo = "Nenhuma fala reconhecida pelo Android. Tente falar mais perto do microfone."; break;
                    case SpeechRecognizer.ERROR_RECOGNIZER_BUSY:
                        motivo = "O reconhecedor do Android está ocupado. Tente de novo em alguns segundos."; break;
                    case 12:
                        motivo = "O Android não aceita português neste reconhecedor. Instale o pacote de português em Configurações ▸ Google ▸ Voz."; break;
                    case 13:
                        motivo = "O pacote de português para reconhecimento offline não está instalado neste aparelho. Instale-o em Configurações ▸ Google ▸ Voz ▸ Reconhecimento de voz offline (ou desligue o modo offline)."; break;
                    case 14:
                        motivo = "O Android não conseguiu verificar o idioma do reconhecimento local. Saia do modo offline ou instale o pacote de português."; break;
                    default:
                        motivo = "Falha no reconhecimento Android (código " + error + ").";
                }
                atual.reject(motivo);
            }
        });

        Intent intent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "pt-BR");
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "pt-BR");
        intent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true);
        intent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3);
        if (local) intent.putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true);
        intent.putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, getContext().getPackageName());
        transcricaoTimeout = () -> {
            PluginCall atual = transcricaoCall;
            encerrarTranscricaoNativa();
            if (atual != null) atual.reject("Tempo esgotado no reconhecimento Android. Tente de novo ou digite o comando.");
        };
        main.postDelayed(transcricaoTimeout, local ? 15000 : 20000);
        try {
            transcricaoRec.startListening(intent);
        } catch (Exception e) {
            PluginCall atual = transcricaoCall;
            encerrarTranscricaoNativa();
            if (atual != null) atual.reject("Não consegui iniciar a escuta Android: "
                + (e.getMessage() == null ? "erro desconhecido" : e.getMessage()));
        }
    }

    /** Fecha o reconhecedor sem apagar a chamada pendente (usado nas trocas local ↔ rede). */
    private void soltarReconhecedor() {
        if (transcricaoTimeout != null) main.removeCallbacks(transcricaoTimeout);
        transcricaoTimeout = null;
        SpeechRecognizer atual = transcricaoRec;
        transcricaoRec = null;
        if (atual != null) {
            try { atual.cancel(); atual.destroy(); } catch (Exception ignored) { }
        }
    }

    private void encerrarTranscricaoNativa() {
        soltarReconhecedor();
        transcricaoCall = null; // zera antes de cancelar para impedir callbacks duplicados
        textoParcialTranscricao = "";
    }

    @Override
    protected void handleOnDestroy() {
        // Não encerra o serviço: a escuta deve continuar com o app fechado.
        JarvisWakeBus.remover(ouvinte);
        main.post(this::encerrarTranscricaoNativa);
        super.handleOnDestroy();
    }
}
