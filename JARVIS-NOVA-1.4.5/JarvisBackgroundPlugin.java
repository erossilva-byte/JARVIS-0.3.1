package com.jarvis.nova;

import android.Manifest;
import android.content.Intent;
import android.media.AudioManager;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;
import ai.picovoice.porcupine.Porcupine;
import ai.picovoice.porcupine.PorcupineException;
import ai.picovoice.porcupine.PorcupineManager;

import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import com.getcapacitor.JSObject;
import com.getcapacitor.PermissionState;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.getcapacitor.annotation.Permission;
import com.getcapacitor.annotation.PermissionCallback;

import java.util.ArrayList;

/**
 * 1) Serviço em primeiro plano usado quando o usuário opta pela escuta em segundo plano.
 * 2) Palavra de ativação local via Porcupine, quando o usuário configura uma AccessKey.
 *    Não há fallback openWakeWord porque a dependência Android anterior não resolvia no CI.
 */
@CapacitorPlugin(
    name = "JarvisBackground",
    permissions = { @Permission(strings = { Manifest.permission.RECORD_AUDIO }, alias = "mic") }
)
public class JarvisBackgroundPlugin extends Plugin {

    private final Handler main = new Handler(Looper.getMainLooper());
    private PorcupineManager porcupineManager;
    private String porcupineAccessKey = "";
    private String detectorAtivo = "picovoice-porcupine";
    private boolean wakeMotorAtivo = false;
    private boolean querWake = false;
    private boolean pausarDuranteMusica = true;
    private final Runnable wakeTask = this::ouvir;
    private final Runnable monitorMidia = new Runnable() {
        @Override public void run() {
            if (!querWake || !pausarDuranteMusica) return;
            boolean musica = musicaAtiva();
            if (musica && wakeMotorAtivo) {
                // Pause the lightweight detector during media playback if the user requested it.
                pausarMotorWake(false);
            } else if (!musica && querWake && !wakeMotorAtivo) {
                reiniciar(250);
            }
            main.postDelayed(this, 800);
        }
    };
    private SpeechRecognizer transcricaoRec;
    private PluginCall transcricaoCall;
    private Runnable transcricaoTimeout;
    private String textoParcialTranscricao = "";

    /* ---------- Serviço em segundo plano ---------- */

    @PluginMethod
    public void start(PluginCall call) {
        // No Android 14+ o serviço de microfone só pode iniciar com a permissão já concedida.
        if (getPermissionState("mic") != PermissionState.GRANTED) {
            requestPermissionForAlias("mic", call, "aposPermissaoMic");
            return;
        }
        iniciar(call);
    }

    @PermissionCallback
    private void aposPermissaoMic(PluginCall call) {
        if (getPermissionState("mic") == PermissionState.GRANTED) {
            iniciar(call);
        } else {
            call.reject("Microfone negado");
        }
    }

    private void iniciar(PluginCall call) {
        try {
            if (Build.VERSION.SDK_INT >= 33
                && ContextCompat.checkSelfPermission(getContext(), "android.permission.POST_NOTIFICATIONS")
                    != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(
                    getActivity(), new String[] { "android.permission.POST_NOTIFICATIONS" }, 7301);
            }
            ContextCompat.startForegroundService(getContext(), new Intent(getContext(), JarvisService.class));
            call.resolve();
        } catch (Exception e) {
            call.reject("Não consegui iniciar o serviço: " + e.getMessage());
        }
    }

    @PluginMethod
    public void stop(PluginCall call) {
        getContext().stopService(new Intent(getContext(), JarvisService.class));
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
        if (getPermissionState("mic") == PermissionState.GRANTED) {
            iniciarWake(call);
        } else {
            call.reject("Microfone negado");
        }
    }

    private void iniciarWake(PluginCall call) {
        pausarDuranteMusica = Boolean.TRUE.equals(call.getBoolean("pausarDuranteMusica", true));
        porcupineAccessKey = call.getString("accessKey", "").trim();
        querWake = true;
        main.removeCallbacks(monitorMidia);
        if (pausarDuranteMusica) main.post(monitorMidia);
        try {
            iniciarMotorWake();
            call.resolve();
        } catch (Exception e) {
            boolean tentativaPicovoice = !porcupineAccessKey.isEmpty();
            querWake = false;
            main.removeCallbacks(monitorMidia);
            liberarMotorWake();
            call.reject((tentativaPicovoice ? "Não consegui iniciar o Porcupine. Confira a AccessKey, a conexão inicial e o limite da conta Picovoice" : "A ativação contínua exige uma AccessKey Picovoice. Configure-a em Ajustes > Voz; sem ela, use o botão de microfone para conversar.") + ". Detalhe: " + e.getMessage());
        }
    }

    @PluginMethod
    public void stopWake(final PluginCall call) {
        querWake = false;
        main.removeCallbacks(monitorMidia);
        main.removeCallbacks(wakeTask);
        main.post(() -> {
            liberarMotorWake();
            call.resolve();
        });
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
        if (getPermissionState("mic") == PermissionState.GRANTED) {
            main.post(() -> iniciarTranscricaoNativa(call));
        } else {
            call.reject("Permissão do microfone negada.");
        }
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
        // Só pode haver uma sessão de reconhecimento por vez no plugin.
        querWake = false;
        main.removeCallbacks(monitorMidia);
        liberarMotorWake();
        transcricaoCall = call;
        textoParcialTranscricao = "";
        boolean somenteLocal = Boolean.TRUE.equals(call.getBoolean("somenteLocal", false));
        boolean localDisponivel = Build.VERSION.SDK_INT >= 31 && SpeechRecognizer.isOnDeviceRecognitionAvailable(getContext());
        if (somenteLocal && !localDisponivel) {
            transcricaoCall = null;
            call.reject("Modo offline: reconhecimento de voz local indisponível neste aparelho.");
            return;
        }
        try {
            if (localDisponivel && (somenteLocal || Boolean.TRUE.equals(call.getBoolean("preferirLocal", true)))) {
                transcricaoRec = SpeechRecognizer.createOnDeviceSpeechRecognizer(getContext());
            } else {
                transcricaoRec = SpeechRecognizer.createSpeechRecognizer(getContext());
            }
        } catch (Exception e) {
            encerrarTranscricaoNativa();
            call.reject("Não consegui iniciar o reconhecimento Android: " + e.getMessage());
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
                ret.put("mecanismo", localDisponivel && (somenteLocal || Boolean.TRUE.equals(call.getBoolean("preferirLocal", true))) ? "local-no-dispositivo" : "servico-android-pode-usar-rede");
                atual.resolve(ret);
            }

            @Override public void onError(int error) {
                PluginCall atual = transcricaoCall;
                String parcial = textoParcialTranscricao;
                encerrarTranscricaoNativa();
                if (atual == null) return;
                if (parcial != null && !parcial.trim().isEmpty()) {
                    JSObject ret = new JSObject(); ret.put("texto", parcial.trim()); ret.put("mecanismo", "parcial-android"); atual.resolve(ret);
                } else {
                    String motivo;
                    switch (error) {
                        case SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS: motivo = "Permissão de microfone insuficiente."; break;
                        case SpeechRecognizer.ERROR_NETWORK:
                        case SpeechRecognizer.ERROR_NETWORK_TIMEOUT: motivo = "O serviço de reconhecimento Android precisa de rede."; break;
                        case SpeechRecognizer.ERROR_NO_MATCH:
                        case SpeechRecognizer.ERROR_SPEECH_TIMEOUT: motivo = "Nenhuma fala reconhecida pelo Android."; break;
                        case SpeechRecognizer.ERROR_RECOGNIZER_BUSY: motivo = "O reconhecedor Android está ocupado."; break;
                        default: motivo = "Falha no reconhecimento Android (código " + error + ").";
                    }
                    atual.reject(motivo);
                }
            }
        });

        Intent intent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "pt-BR");
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "pt-BR");
        intent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true);
        intent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3);
        intent.putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true);
        intent.putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, getContext().getPackageName());
        transcricaoTimeout = () -> {
            PluginCall atual = transcricaoCall;
            encerrarTranscricaoNativa();
            if (atual != null) atual.reject("Tempo esgotado no reconhecimento Android. Tente de novo ou digite o comando.");
        };
        main.postDelayed(transcricaoTimeout, 18000);
        try {
            transcricaoRec.startListening(intent);
        } catch (Exception e) {
            PluginCall atual = transcricaoCall;
            encerrarTranscricaoNativa();
            if (atual != null) atual.reject("Não consegui iniciar a escuta Android: " + e.getMessage());
        }
    }

    private void encerrarTranscricaoNativa() {
        if (transcricaoTimeout != null) main.removeCallbacks(transcricaoTimeout);
        transcricaoTimeout = null;
        transcricaoCall = null; // zera antes de cancelar para impedir callbacks duplicados
        SpeechRecognizer atual = transcricaoRec;
        transcricaoRec = null;
        if (atual != null) {
            try { atual.cancel(); atual.destroy(); } catch (Exception ignored) { }
        }
        textoParcialTranscricao = "";
    }

    private void reiniciar(long atrasoMs) {
        if (!querWake) return;
        main.removeCallbacks(wakeTask);
        main.postDelayed(wakeTask, atrasoMs);
    }

    private boolean musicaAtiva() {
        try {
            AudioManager audio = (AudioManager) getContext().getSystemService(android.content.Context.AUDIO_SERVICE);
            return audio != null && audio.isMusicActive();
        } catch (Exception ignored) {
            return false;
        }
    }

    private void disparar(String texto) {
        querWake = false;
        main.removeCallbacks(monitorMidia);
        main.removeCallbacks(wakeTask);
        liberarMotorWake();
        JSObject o = new JSObject();
        o.put("texto", texto == null ? "Jarvis" : texto);
        o.put("detector", detectorAtivo);
        notifyListeners("wake", o);
    }

    private void iniciarMotorWake() throws Exception {
        if (!querWake) return;
        if (pausarDuranteMusica && musicaAtiva()) return;
        if (!porcupineAccessKey.isEmpty()) {
            detectorAtivo = "picovoice-porcupine";
            if (porcupineManager == null) {
                porcupineManager = new PorcupineManager.Builder()
                    .setAccessKey(porcupineAccessKey)
                    .setKeyword(Porcupine.BuiltInKeyword.JARVIS)
                    .setSensitivity(0.55f)
                    .build(getContext(), keywordIndex -> {
                        if (!querWake) return;
                        querWake = false;
                        main.post(() -> disparar("Jarvis"));
                    });
            }
            if (!wakeMotorAtivo) {
                porcupineManager.start();
                wakeMotorAtivo = true;
            }
            return;
        }
        throw new IllegalStateException("AccessKey Picovoice ausente. A ativação contínua por palavra-chave não está disponível sem configurar a chave.");
    }

    private void pausarMotorWake(boolean liberar) {
        try {
            if (porcupineManager != null && wakeMotorAtivo) porcupineManager.stop();
        } catch (Exception ignored) { }
        wakeMotorAtivo = false;
        if (liberar) {
            try { if (porcupineManager != null) porcupineManager.delete(); } catch (Exception ignored) { }
            porcupineManager = null;
            porcupineAccessKey = "";
        }
    }

    private void liberarMotorWake() {
        pausarMotorWake(true);
    }

    private void falhaMotorWake(String motivo) {
        if (!querWake) return;
        querWake = false;
        main.removeCallbacks(monitorMidia);
        main.removeCallbacks(wakeTask);
        liberarMotorWake();
        JSObject o = new JSObject();
        o.put("motivo", "Detector local: " + (motivo == null ? "falha desconhecida" : motivo));
        notifyListeners("wakeparou", o);
    }

    private void ouvir() {
        if (!querWake) return;
        if (pausarDuranteMusica && musicaAtiva()) return;
        try {
            iniciarMotorWake();
        } catch (Exception e) {
            falhaMotorWake(e.getMessage());
        }
    }

    @Override
    protected void handleOnDestroy() {
        querWake = false;
        main.removeCallbacks(monitorMidia);
        main.removeCallbacks(wakeTask);
        main.post(() -> { liberarMotorWake(); encerrarTranscricaoNativa(); });
        super.handleOnDestroy();
    }
}
