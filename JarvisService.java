package com.jarvis.nova;

import android.Manifest;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ServiceInfo;
import android.media.AudioManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;

import androidx.core.content.ContextCompat;

import ai.picovoice.porcupine.Porcupine;
import ai.picovoice.porcupine.PorcupineManager;

import com.getcapacitor.JSObject;

import java.util.ArrayList;

/**
 * Serviço em primeiro plano que mantém a escuta de ativação viva fora da tela.
 *
 * O detector pertence ao serviço (não à tela) e o estado desejado é persistido em
 * JarvisPrefs, com a AccessKey cifrada no Keystore. Assim, quando o Android reinicia
 * o serviço (START_STICKY), reinicia o aparelho ou encerra o app pelos recentes, a
 * escuta volta sozinha — com o mesmo detector que o usuário escolheu.
 */
public class JarvisService extends Service {

    static final String CANAL = "jarvis_ativo";
    static final int ID = 4711;
    static final String ACAO_PARAR = "com.jarvis.nova.PARAR";
    static final String ACAO_SERVICO_ON = "com.jarvis.nova.SERVICO_ON";
    static final String ACAO_ESCUTA_ON = "com.jarvis.nova.ESCUTA_ON";
    static final String ACAO_ESCUTA_PAUSA = "com.jarvis.nova.ESCUTA_PAUSA";
    static final String ACAO_ESCUTA_OFF = "com.jarvis.nova.ESCUTA_OFF";
    static final String ACAO_TESTE_ON = "com.jarvis.nova.TESTE_ON";
    static final String ACAO_TESTE_OFF = "com.jarvis.nova.TESTE_OFF";
    static final String EXTRA_CHAVE = "accessKey";
    static final String EXTRA_MOTOR = "motor";
    static final String EXTRA_MUSICA = "pausarMusica";
    static final String EXTRA_SEGUNDOS = "segundos";

    private static JarvisService instancia;
    private static volatile boolean escutando = false;
    private static volatile String detectorAtual = "";

    private final Handler main = new Handler(Looper.getMainLooper());
    private PorcupineManager porcupine;
    private String chave = "";
    /** Motor pedido nesta execução ("" = usar o salvo em JarvisPrefs). */
    private String motorPedido = "";
    private boolean pausarDuranteMusica = true;
    private boolean querEscuta = false;
    private String estadoNotificacao = "Escuta em espera";

    /**
     * true quando a própria interface pediu a pausa (para gravar um comando).
     * Diferencia "pausado de propósito" de "a tela morreu no meio da ativação":
     * só no segundo caso o serviço se rearma sozinho.
     */
    private boolean pausadoPelaInterface = false;
    private Runnable rearme;

    // Modo teste: conta ativações em uma janela curta sem abrir o app.
    private long testeAte = 0;
    private int testeDeteccoes = 0;
    private String testeDetector = "";
    private final Runnable testeFim = new Runnable() {
        @Override public void run() {
            if (testeAte == 0) return;
            testeAte = 0;
            pausarMotor();
            estadoNotificacao = "Teste concluído — " + testeDeteccoes + " detecção(ões)";
            notificar();
            // O teste foi só uma medição: volta à escuta normal se ela deve continuar ligada.
            if (JarvisPrefs.desejaOuvir(JarvisService.this) && !pausadoPelaInterface) {
                try { iniciarEscutaInterna(); } catch (Exception e) { pararPorFalha(mensagemFalha(e)); }
            } else {
                querEscuta = false;
            }
        }
    };

    // Detector livre (sem AccessKey): sessões curtas do reconhecimento do Android.
    private SpeechRecognizer livreRec;
    private Runnable livreProximo;
    private Runnable livreTimeout;
    private boolean livreSessao = false;
    private int livreFalhas = 0;
    private int livreErrosIdioma = 0;
    private String livreParcial = "";
    private boolean preferirRede = false; // true quando o aparelho não tem o idioma offline

    private final Runnable monitorMidia = new Runnable() {
        @Override public void run() {
            if (!querEscuta) return;
            // Chamada/VoIP nunca divide o microfone com o detector; mídia só pausa se o usuário pediu.
            boolean ocupado = chamadaAtiva() || (pausarDuranteMusica && musicaAtiva());
            if (ocupado) {
                if (porcupine != null || livreSessao || livreProximo != null) pausarMotor();
            } else if (porcupine == null && !livreSessao && livreProximo == null) {
                try { iniciarMotor(); } catch (Exception e) { pararPorFalha(mensagemFalha(e)); return; }
            }
            main.postDelayed(this, 1000);
        }
    };

    static boolean escutando() { return escutando; }
    static String detectorAtual() { return detectorAtual; }

    static boolean ativo() {
        JarvisService s = instancia;
        return s != null;
    }

    static boolean testeAtivo() {
        JarvisService s = instancia;
        return s != null && s.testeAtivoInterno();
    }

    private boolean testeAtivoInterno() {
        return testeAte > 0 && System.currentTimeMillis() < testeAte;
    }

    /** Resultado parcial do teste de ativação, consultado pela interface. */
    static JSObject statusTeste() {
        JarvisService s = instancia;
        JSObject o = new JSObject();
        if (s == null) {
            o.put("ativo", false);
            o.put("deteccoes", 0);
            o.put("restante", 0);
            o.put("detector", "");
            return o;
        }
        long restante = Math.max(0, s.testeAte - System.currentTimeMillis());
        o.put("ativo", s.testeAtivoInterno());
        o.put("deteccoes", s.testeDeteccoes);
        o.put("restante", Math.round(restante / 1000.0));
        o.put("detector", s.testeDetector);
        return o;
    }

    /* ---------- Comandos vindos da interface ---------- */

    /** Liga só o serviço em primeiro plano, sem começar a ouvir. */
    static void iniciarServico(Context ctx) {
        ContextCompat.startForegroundService(ctx, new Intent(ctx, JarvisService.class).setAction(ACAO_SERVICO_ON));
    }

    /** Liga o serviço, persiste o estado desejado e começa a escutar. */
    static void iniciarEscuta(Context ctx, String accessKey, boolean pausarMusica, String motor) {
        JarvisPrefs.desejaOuvir(ctx, true);
        JarvisPrefs.pausarMusica(ctx, pausarMusica);
        JarvisPrefs.motor(ctx, motor);
        boolean temChave = accessKey != null && !accessKey.trim().isEmpty();
        if (temChave) JarvisPrefs.guardarChave(ctx, accessKey);
        JarvisWatchdog.agendar(ctx, 15L * 60L * 1000L);
        Intent i = new Intent(ctx, JarvisService.class)
            .setAction(ACAO_ESCUTA_ON)
            .putExtra(EXTRA_CHAVE, temChave ? accessKey.trim() : JarvisPrefs.lerChave(ctx))
            .putExtra(EXTRA_MOTOR, JarvisPrefs.motor(ctx))
            .putExtra(EXTRA_MUSICA, pausarMusica);
        ContextCompat.startForegroundService(ctx, i);
    }

    /** Pausa temporária (antes de gravar um comando) sem encerrar o serviço. */
    static void pausarEscuta() {
        JarvisService s = instancia;
        if (s != null) s.main.post(() -> {
            s.pausadoPelaInterface = true;
            s.main.removeCallbacks(s.monitorMidia);
            if (s.rearme != null) { s.main.removeCallbacks(s.rearme); s.rearme = null; }
            s.querEscuta = false;
            s.testeAte = 0;
            s.pausarMotor();
            s.estadoNotificacao = "Escuta em espera";
            s.notificar();
        });
    }

    /** Desliga de verdade: o vigia para de tentar reiniciar. */
    static void desligar(Context ctx) {
        JarvisPrefs.desejaOuvir(ctx, false);
        JarvisWatchdog.cancelar(ctx);
        JarvisService s = instancia;
        if (s != null) s.main.post(() -> {
            s.pausadoPelaInterface = true;
            s.encerrarEscuta();
            s.stopSelf();
        });
        else ctx.stopService(new Intent(ctx, JarvisService.class));
    }

    static void pararTudo(Context ctx) {
        desligar(ctx);
    }

    /** Inicia uma janela de teste: cada "Jarvis" conta como acerto e não abre a tela. */
    static void iniciarTeste(Context ctx, int segundos) {
        int dur = Math.max(10, Math.min(60, segundos));
        Intent i = new Intent(ctx, JarvisService.class)
            .setAction(ACAO_TESTE_ON)
            .putExtra(EXTRA_SEGUNDOS, dur)
            .putExtra(EXTRA_CHAVE, JarvisPrefs.lerChave(ctx))
            .putExtra(EXTRA_MOTOR, JarvisPrefs.motor(ctx))
            .putExtra(EXTRA_MUSICA, false); // no teste, música não deve mascarar o resultado
        ContextCompat.startForegroundService(ctx, i);
    }

    static void pararTeste(Context ctx) {
        JarvisService s = instancia;
        if (s != null) s.main.post(() -> {
            s.testeAte = 0;
            s.main.removeCallbacks(s.testeFim);
            s.pausarMotor();
            s.querEscuta = false;
            s.estadoNotificacao = "Escuta em espera";
            s.notificar();
        });
        else ctx.stopService(new Intent(ctx, JarvisService.class));
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onCreate() {
        super.onCreate();
        instancia = this;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        String acao = intent == null ? null : intent.getAction();

        // Reinício pelo Android (START_STICKY) ou pelo vigia sem ação: retoma o estado salvo.
        if (acao == null) {
            if (!JarvisPrefs.desejaOuvir(this)) {
                stopSelf();
                return START_NOT_STICKY;
            }
            acao = ACAO_ESCUTA_ON;
        }

        if (ACAO_PARAR.equals(acao)) {
            JarvisPrefs.desejaOuvir(this, false);
            JarvisWatchdog.cancelar(this);
            encerrarEscuta();
            JarvisWakeBus.parou("Escuta encerrada pelo botão Parar da notificação.");
            stopSelf();
            return START_NOT_STICKY;
        }
        if (ACAO_ESCUTA_OFF.equals(acao)) {
            JarvisPrefs.desejaOuvir(this, false);
            JarvisWatchdog.cancelar(this);
            encerrarEscuta();
            estadoNotificacao = "Escuta em espera";
            notificar();
            return START_NOT_STICKY;
        }
        criarCanal();
        try {
            Notification n = montarNotificacao();
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE);
            } else {
                startForeground(ID, n);
            }
        } catch (Exception e) {
            JarvisPrefs.ultimoErro(this, "serviço em primeiro plano recusado: " + e.getMessage());
            stopSelf();
            return START_NOT_STICKY;
        }

        if (ACAO_TESTE_OFF.equals(acao)) {
            testeAte = 0;
            main.removeCallbacks(testeFim);
            pausarMotor();
            querEscuta = false;
            estadoNotificacao = "Escuta em espera";
            notificar();
            return START_NOT_STICKY;
        }

        if (ACAO_TESTE_ON.equals(acao)) {
            int segundos = intent == null ? 20 : intent.getIntExtra(EXTRA_SEGUNDOS, 20);
            String k = intent == null ? "" : intent.getStringExtra(EXTRA_CHAVE);
            motorPedido = intent == null || intent.getStringExtra(EXTRA_MOTOR) == null
                ? "" : intent.getStringExtra(EXTRA_MOTOR).trim();
            chave = k == null ? JarvisPrefs.lerChave(this) : k.trim();
            if (chave.isEmpty()) chave = JarvisPrefs.lerChave(this);
            pausarDuranteMusica = false;
            main.removeCallbacks(testeFim);
            testeDeteccoes = 0;
            testeAte = System.currentTimeMillis() + Math.max(10, Math.min(60, segundos)) * 1000L;
            testeDetector = chave.isEmpty() || "android".equals(motorEscolhido()) ? "android-sem-chave" : "picovoice-porcupine";
            main.postDelayed(testeFim, Math.max(10, Math.min(60, segundos)) * 1000L + 300);
            iniciarEscutaInterna();
            estadoNotificacao = "Teste da palavra de ativação — diga “Jarvis”";
            notificar();
            return START_NOT_STICKY;
        }

        if (ACAO_SERVICO_ON.equals(acao)) {
            if (intent != null && intent.hasExtra(EXTRA_CHAVE)) {
                String k = intent.getStringExtra(EXTRA_CHAVE);
                chave = k == null ? "" : k.trim();
            }
            if (chave.isEmpty()) chave = JarvisPrefs.lerChave(this);
            estadoNotificacao = "Escuta em espera";
            notificar();
            return JarvisPrefs.desejaOuvir(this) ? START_STICKY : START_NOT_STICKY;
        }

        if (ACAO_ESCUTA_PAUSA.equals(acao)) {
            pausadoPelaInterface = true;
            main.removeCallbacks(monitorMidia);
            pausarMotor();
            estadoNotificacao = "Escuta em espera";
            notificar();
            return START_STICKY;
        }

        // ACAO_ESCUTA_ON (ou reinício sem ação)
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            // Sem microfone não há o que retomar: parar o vigia evita reinícios a cada 15 min.
            JarvisPrefs.desejaOuvir(this, false);
            JarvisWatchdog.cancelar(this);
            pararPorFalha("a permissão de microfone foi negada. Autorize em Configurações ▸ Apps ▸ Jarvis ▸ Permissões.");
            return START_NOT_STICKY;
        }
        String extraChave = intent == null ? null : intent.getStringExtra(EXTRA_CHAVE);
        if (extraChave != null) chave = extraChave.trim();
        if (intent != null && intent.getStringExtra(EXTRA_MOTOR) != null) {
            motorPedido = intent.getStringExtra(EXTRA_MOTOR).trim();
        }
        if (chave.isEmpty()) chave = JarvisPrefs.lerChave(this);
        if (intent != null && intent.hasExtra(EXTRA_MUSICA)) {
            pausarDuranteMusica = intent.getBooleanExtra(EXTRA_MUSICA, JarvisPrefs.pausarMusica(this));
        } else {
            pausarDuranteMusica = JarvisPrefs.pausarMusica(this);
        }
        // O pedido veio do usuário (ou do vigia com estado salvo): persiste e mantém o vigia.
        JarvisPrefs.desejaOuvir(this, true);
        if (!chave.isEmpty()) JarvisPrefs.guardarChave(this, chave);
        JarvisWatchdog.agendar(this, 15L * 60L * 1000L);
        pausadoPelaInterface = false;
        iniciarEscutaInterna();
        return START_STICKY;
    }

    private void iniciarEscutaInterna() {
        main.post(() -> {
            try {
                pausarMotor();
                pausadoPelaInterface = false;
                querEscuta = true;
                main.removeCallbacks(monitorMidia);
                main.post(monitorMidia);
                iniciarMotor();
            } catch (Exception e) {
                pararPorFalha(mensagemFalha(e));
            }
        });
    }

    private String mensagemFalha(Exception e) {
        String detalhe = e == null || e.getMessage() == null ? "" : " Detalhe: " + e.getMessage();
        if (!chave.isEmpty()) {
            return "não consegui iniciar o Porcupine. Confira a AccessKey, a conexão inicial e o limite da conta Picovoice." + detalhe;
        }
        return "o reconhecimento de voz do Android não está disponível neste aparelho. Confira a permissão de microfone ou configure uma AccessKey Picovoice em Ajustes ▸ Voz." + detalhe;
    }

    /* ---------- Motor de escuta ---------- */

    /** Motor efetivo: o pedido nesta execução, senão o salvo pelo usuário. */
    private String motorEscolhido() {
        String m = motorPedido == null ? "" : motorPedido;
        if (m.isEmpty()) m = JarvisPrefs.motor(this);
        return m;
    }

    private void iniciarMotor() throws Exception {
        if (!querEscuta) return;
        if (chamadaAtiva() || (pausarDuranteMusica && musicaAtiva())) return;
        String motor = motorEscolhido();
        if ("porcupine".equals(motor) && chave.isEmpty()) {
            // Escolha explícita sem chave: avisar em vez de cair calado no detector livre.
            pararPorFalha("o detector Porcupine está selecionado, mas não há AccessKey Picovoice salva. Cole a chave ou mude o detector para “Android (grátis)” em Ajustes ▸ Voz");
            return;
        }
        boolean usarPorcupine = !chave.isEmpty() && !"android".equals(motor);
        if (usarPorcupine) {
            if (porcupine == null) {
                porcupine = new PorcupineManager.Builder()
                    .setAccessKey(chave)
                    .setKeyword(Porcupine.BuiltInKeyword.JARVIS)
                    .setSensitivity(0.55f)
                    .build(getApplicationContext(), keywordIndex -> {
                        if (!querEscuta) return;
                        main.post(() -> disparar("Jarvis"));
                    });
            }
            porcupine.start();
            detectorAtual = "picovoice-porcupine";
            escutando = true;
            estadoNotificacao = testeAtivoInterno()
                ? "Teste · diga “Jarvis” (" + testeDeteccoes + ")"
                : "Ouvindo “Jarvis” · Porcupine";
            notificar();
            return;
        }
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            throw new IllegalStateException("AccessKey Picovoice ausente e o reconhecimento de voz do Android não está disponível neste aparelho.");
        }
        detectorAtual = "android-sem-chave";
        escutando = true;
        estadoNotificacao = testeAtivoInterno()
            ? "Teste · diga “Jarvis” (" + testeDeteccoes + ")"
            : "Ouvindo “Jarvis” · reconhecimento do Android";
        notificar();
        if (!livreSessao && livreProximo == null) agendarSessaoLivre(0);
    }

    private void pausarMotor() {
        try {
            if (porcupine != null) porcupine.delete();
        } catch (Exception ignored) { }
        porcupine = null;
        encerrarSessaoLivre(true);
        escutando = false;
    }

    private void encerrarEscuta() {
        querEscuta = false;
        testeAte = 0;
        main.removeCallbacks(testeFim);
        main.removeCallbacks(monitorMidia);
        if (rearme != null) { main.removeCallbacks(rearme); rearme = null; }
        pausarMotor();
        detectorAtual = "";
    }

    private void pararPorFalha(String motivo) {
        boolean avisar = querEscuta;
        JarvisPrefs.ultimoErro(this, motivo == null ? "falha desconhecida" : motivo);
        encerrarEscuta();
        estadoNotificacao = "Escuta parada — toque para abrir";
        notificar();
        if (avisar) JarvisWakeBus.parou("Detector local: " + (motivo == null ? "falha desconhecida" : motivo));
        // O serviço continua vivo (em espera) para a interface poder religar a escuta
        // sem precisar reiniciar um serviço de microfone a partir do fundo.
    }

    private void disparar(String texto) {
        if (testeAtivoInterno()) {
            testeDeteccoes++;
            testeDetector = detectorAtual;
            estadoNotificacao = "Teste · " + testeDeteccoes + " detecção(ões)";
            notificar();
            // Rearma sem abrir o app, para contar quantas vezes a palavra é reconhecida.
            pausarMotor();
            main.postDelayed(() -> {
                if (!querEscuta || !testeAtivoInterno()) return;
                try { iniciarMotor(); } catch (Exception e) { pararPorFalha(mensagemFalha(e)); }
            }, 700);
            return;
        }
        String detector = detectorAtual;
        JarvisPrefs.ultimoEvento(this, System.currentTimeMillis());
        JarvisPrefs.ultimoErro(this, "");
        encerrarEscuta();
        estadoNotificacao = "Chamado — abrindo o J.A.V.I.S.";
        notificar();
        abrirTela();
        JarvisWakeBus.acordou(texto == null ? "Jarvis" : texto, detector);
        agendarRearmeSeTelaNaoResponder();
    }

    /**
     * Se o Android bloquear a abertura da tela (ou o WebView não carregar), a escuta
     * não pode ficar desligada até o próximo alarme do vigia. Depois de 9 s, se a
     * interface não assumiu (nem pausou de propósito), volta a ouvir.
     */
    private void agendarRearmeSeTelaNaoResponder() {
        if (rearme != null) main.removeCallbacks(rearme);
        rearme = () -> {
            rearme = null;
            if (!JarvisPrefs.desejaOuvir(this)) return;
            if (querEscuta || pausadoPelaInterface || testeAte > 0) return;
            try { iniciarEscutaInterna(); } catch (Exception e) { pararPorFalha(mensagemFalha(e)); }
        };
        main.postDelayed(rearme, 9000);
    }

    private void abrirTela() {
        try {
            Intent i = new Intent(this, MainActivity.class);
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            i.putExtra("jarvis_wake", true);
            startActivity(i);
        } catch (Exception ignored) {
            // Android 10+ pode bloquear abrir tela a partir do fundo; a notificação continua tocando.
        }
    }

    private boolean musicaAtiva() {
        try {
            AudioManager audio = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
            return audio != null && audio.isMusicActive();
        } catch (Exception ignored) {
            return false;
        }
    }

    /** Chamada telefônica ou VoIP: o microfone é do usuário, o detector sai da frente. */
    private boolean chamadaAtiva() {
        try {
            AudioManager audio = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
            if (audio == null) return false;
            int modo = audio.getMode();
            return audio.isMicrophoneMute()
                || modo == AudioManager.MODE_IN_CALL
                || modo == AudioManager.MODE_IN_COMMUNICATION;
        } catch (Exception ignored) {
            return false;
        }
    }

    /* ---------- Detector livre (sem AccessKey) ---------- */

    private static final String RX_WAKE_NATIVO =
        "(?i)\\b(jarvis|jarvi|jarves|jervis|gervis|garvis|charvis|jarbis|jarvez|jarvs)\\b";

    private static String simplificarTexto(String s) {
        if (s == null) return "";
        return java.text.Normalizer.normalize(s, java.text.Normalizer.Form.NFD).replaceAll("\\p{M}+", "");
    }

    private String primeiroTextoLivre(Bundle results) {
        ArrayList<String> lista = results == null ? null : results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
        return (lista != null && !lista.isEmpty()) ? lista.get(0) : null;
    }

    private void agendarSessaoLivre(long atrasoMs) {
        if (livreProximo != null) main.removeCallbacks(livreProximo);
        livreProximo = () -> {
            livreProximo = null;
            iniciarSessaoLivre();
        };
        main.postDelayed(livreProximo, Math.max(0, atrasoMs));
    }

    private boolean temReconhecimentoLocal() {
        return Build.VERSION.SDK_INT >= 31 && SpeechRecognizer.isOnDeviceRecognitionAvailable(this);
    }

    private void iniciarSessaoLivre() {
        if (!querEscuta || livreSessao) return;
        if (chamadaAtiva() || (pausarDuranteMusica && musicaAtiva())) return;
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            pararPorFalha("reconhecimento de voz indisponível neste aparelho");
            return;
        }
        final boolean noDispositivo = temReconhecimentoLocal() && !preferirRede;
        try {
            livreRec = noDispositivo
                ? SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
                : SpeechRecognizer.createSpeechRecognizer(this);
        } catch (Exception e) {
            // Muitos aparelhos oferecem o reconhecedor local mas sem o pacote de português.
            if (noDispositivo) {
                preferirRede = true;
                agendarSessaoLivre(200);
                return;
            }
            pararPorFalha(e.getMessage());
            return;
        }
        livreSessao = true;
        livreParcial = "";
        final boolean usouLocal = noDispositivo;
        final SpeechRecognizer rec = livreRec;
        rec.setRecognitionListener(new RecognitionListener() {
            @Override public void onReadyForSpeech(Bundle params) { }
            @Override public void onBeginningOfSpeech() { }
            @Override public void onRmsChanged(float rmsdB) { }
            @Override public void onBufferReceived(byte[] buffer) { }
            @Override public void onEndOfSpeech() { }
            @Override public void onEvent(int eventType, Bundle params) { }

            @Override public void onPartialResults(Bundle results) {
                conferirWakeLivre(primeiroTextoLivre(results), false);
            }

            @Override public void onResults(Bundle results) {
                String texto = primeiroTextoLivre(results);
                if (texto == null || texto.trim().isEmpty()) texto = livreParcial;
                if (conferirWakeLivre(texto, true)) return;
                encerrarSessaoLivre(false);
                if (querEscuta) {
                    livreFalhas = 0;
                    agendarSessaoLivre(200);
                }
            }

            @Override public void onError(int error) {
                if (conferirWakeLivre(livreParcial, true)) return;
                String parcial = livreParcial;
                encerrarSessaoLivre(false);
                if (!querEscuta) return;
                switch (error) {
                    case SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS:
                        pararPorFalha("permissão de microfone negada pelo usuário");
                        return;
                    case SpeechRecognizer.ERROR_RECOGNIZER_BUSY:
                        agendarSessaoLivre(1800);
                        return;
                    case 12: // ERROR_LANGUAGE_NOT_SUPPORTED
                    case 13: // ERROR_LANGUAGE_UNAVAILABLE (pacote offline ausente)
                    case 14: // ERROR_CANNOT_CHECK_SUPPORT
                        livreErrosIdioma++;
                        if (usouLocal && livreErrosIdioma < 3) {
                            preferirRede = true;
                            agendarSessaoLivre(300);
                            return;
                        }
                        pararPorFalha("o Android não tem o reconhecimento de português instalado. Baixe o pacote de idioma (Configurações ▸ Google ▸ Voz) ou use uma AccessKey Picovoice");
                        return;
                    case SpeechRecognizer.ERROR_NETWORK:
                    case SpeechRecognizer.ERROR_NETWORK_TIMEOUT:
                        if (preferirRede && temReconhecimentoLocal()) preferirRede = false;
                        livreFalhas++;
                        if (livreFalhas >= 6) {
                            pararPorFalha("sem conexão e o reconhecimento local não respondeu. O detector livre precisa de rede quando o aparelho não tem o idioma offline");
                            return;
                        }
                        agendarSessaoLivre(Math.min(8000, 600L * livreFalhas));
                        return;
                    case SpeechRecognizer.ERROR_SPEECH_TIMEOUT:
                    case SpeechRecognizer.ERROR_NO_MATCH:
                        livreFalhas = 0;
                        agendarSessaoLivre(parcial != null && !parcial.trim().isEmpty() ? 250 : 400);
                        return;
                    default:
                        livreFalhas++;
                        if (livreFalhas >= 10) {
                            pararPorFalha("o reconhecimento do Android falhou repetidamente (último código " + error + ")");
                            return;
                        }
                        agendarSessaoLivre(Math.min(4000, 300L * livreFalhas));
                }
            }
        });
        Intent intent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE, "pt-BR")
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "pt-BR")
            .putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            .putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1);
        if (usouLocal) intent.putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true);
        livreTimeout = () -> {
            if (!livreSessao) return;
            if (conferirWakeLivre(livreParcial, true)) return;
            encerrarSessaoLivre(false);
            if (querEscuta) agendarSessaoLivre(250);
        };
        main.postDelayed(livreTimeout, 9000);
        try {
            rec.startListening(intent);
        } catch (Exception e) {
            encerrarSessaoLivre(false);
            pararPorFalha(e.getMessage());
        }
    }

    /** true quando a palavra foi encontrada (ou quando a ativação já foi encerrada). */
    private boolean conferirWakeLivre(String texto, boolean definitivo) {
        if (!querEscuta) return true;
        if (texto == null || texto.trim().isEmpty()) return false;
        livreParcial = texto;
        java.util.regex.Matcher m =
            java.util.regex.Pattern.compile(RX_WAKE_NATIVO).matcher(simplificarTexto(texto));
        if (!m.find()) return false;
        if (!definitivo && texto.trim().length() < 6) return false; // evita gatilho fraco em ruído
        String limpo = texto.trim();
        querEscuta = false;
        encerrarSessaoLivre(true);
        disparar(limpo);
        return true;
    }

    private void encerrarSessaoLivre(boolean limparParcial) {
        if (livreTimeout != null) { main.removeCallbacks(livreTimeout); livreTimeout = null; }
        if (livreProximo != null) { main.removeCallbacks(livreProximo); livreProximo = null; }
        livreSessao = false;
        SpeechRecognizer rec = livreRec;
        livreRec = null;
        if (rec != null) {
            try { rec.cancel(); rec.destroy(); } catch (Exception ignored) { }
        }
        if (limparParcial) livreParcial = "";
    }

    /* ---------- Notificação ---------- */

    private void criarCanal() {
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationChannel c = new NotificationChannel(CANAL, "Jarvis ativo", NotificationManager.IMPORTANCE_LOW);
            c.setDescription("Mantém a escuta de ativação enquanto autorizada");
            c.setShowBadge(false);
            NotificationManager nm = getSystemService(NotificationManager.class);
            if (nm != null) nm.createNotificationChannel(c);
        }
    }

    private Notification montarNotificacao() {
        int fi = Build.VERSION.SDK_INT >= 23 ? PendingIntent.FLAG_IMMUTABLE : 0;
        Intent abrir = getPackageManager().getLaunchIntentForPackage(getPackageName());
        PendingIntent abrirPi = abrir == null ? null
            : PendingIntent.getActivity(this, 0, abrir, fi | PendingIntent.FLAG_UPDATE_CURRENT);

        PendingIntent ouvirPi = PendingIntent.getBroadcast(this, 3,
            new Intent(this, JarvisOuvirReceiver.class).setAction(JarvisOuvirReceiver.ACAO),
            fi | PendingIntent.FLAG_UPDATE_CURRENT);
        Intent parar = new Intent(this, JarvisService.class).setAction(ACAO_PARAR);
        PendingIntent pararPi = PendingIntent.getService(this, 1, parar, fi | PendingIntent.FLAG_UPDATE_CURRENT);

        Notification.Builder b = Build.VERSION.SDK_INT >= 26
            ? new Notification.Builder(this, CANAL)
            : new Notification.Builder(this);
        b.setContentTitle("J.A.R.V.I.S. Nova ativo")
            .setContentText(estadoNotificacao)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(abrirPi)
            .addAction(android.R.drawable.ic_btn_speak_now, "Ouvir agora", ouvirPi)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Parar", pararPi);
        return b.build();
    }

    private void notificar() {
        try {
            NotificationManager nm = getSystemService(NotificationManager.class);
            if (nm != null) nm.notify(ID, montarNotificacao());
        } catch (Exception ignored) { }
    }

    @Override
    public void onTaskRemoved(Intent rootIntent) {
        // O usuário fechou pelos recentes: se a escuta deve continuar, pede um reinício curto.
        if (JarvisPrefs.desejaOuvir(this)) {
            JarvisWatchdog.agendar(this, 8000L);
            JarvisWatchdog.agendar(this, 60000L);
        }
        super.onTaskRemoved(rootIntent);
    }

    @Override
    public void onDestroy() {
        querEscuta = false;
        testeAte = 0;
        main.removeCallbacks(monitorMidia);
        main.removeCallbacks(testeFim);
        if (rearme != null) { main.removeCallbacks(rearme); rearme = null; }
        pausarMotor();
        escutando = false;
        instancia = null;
        // Se o sistema derrubou o serviço com a escuta ligada, o vigia tenta de novo.
        if (JarvisPrefs.desejaOuvir(this)) JarvisWatchdog.agendar(this, 120000L);
        stopForeground(true);
        super.onDestroy();
    }
}
