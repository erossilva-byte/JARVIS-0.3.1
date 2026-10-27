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

import com.getcapacitor.JSObject;

import java.util.ArrayList;

/**
 * Serviço em primeiro plano que mantém a escuta de ativação viva fora da tela.
 *
 * O detector pertence ao serviço (não à tela) e o estado desejado é persistido em
 * JarvisPrefs, junto da calibragem (sensibilidade e palavras extras). Assim, quando o
 * Android reinicia o serviço (START_STICKY), reinicia o aparelho ou encerra o app pelos
 * recentes, a escuta volta sozinha e calibrada do jeito que o usuário deixou.
 *
 * A detecção é 100% local: o reconhecimento do Android transcreve e as regras de
 * JarvisAtivacao decidem. Não há chave de terceiro, não há SDK de palavra de ativação e
 * nenhum áudio sai do aparelho.
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
    static final String EXTRA_MUSICA = "pausarMusica";
    static final String EXTRA_SEGUNDOS = "segundos";

    private static JarvisService instancia;
    private static volatile boolean escutando = false;
    private static volatile String detectorAtual = "";

    private final Handler main = new Handler(Looper.getMainLooper());
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

    // Detector de ativação próprio: sessões do reconhecimento do Android conferidas no
    // próprio aparelho pelas regras de JarvisAtivacao (variantes fonéticas + limiar).
    private SpeechRecognizer rec;
    private Runnable proximo;
    private Runnable timeout;
    private boolean sessao = false;
    private int falhas = 0;
    private int errosIdioma = 0;
    private String parcial = "";
    private boolean preferirRede = false; // true quando o aparelho não tem o idioma offline
    private JarvisAtivacao.Config cfg = JarvisAtivacao.config(55, "");
    // Porteiro de ruído: pico de nível da sessão. Transcrição que só aparece com o som
    // baixo (televisão ao fundo, conversa de outra sala) não acorda o assistente.
    private float picoDb = -120f;
    private int rejeitadasRuido = 0;
    /** Nome do detector, exposto no diagnóstico e na notificação. */
    static final String DETECTOR = "proprio";

    private final Runnable monitorMidia = new Runnable() {
        @Override public void run() {
            if (!querEscuta) return;
            // Chamada/VoIP nunca divide o microfone com o detector; mídia só pausa se o usuário pediu.
            boolean ocupado = chamadaAtiva() || (pausarDuranteMusica && musicaAtiva());
            if (ocupado) {
                if (sessao || proximo != null) pausarMotor();
            } else if (!sessao && proximo == null) {
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
    static void iniciarEscuta(Context ctx, boolean pausarMusica) {
        JarvisPrefs.desejaOuvir(ctx, true);
        JarvisPrefs.pausarMusica(ctx, pausarMusica);
        JarvisWatchdog.agendar(ctx, 15L * 60L * 1000L);
        Intent i = new Intent(ctx, JarvisService.class)
            .setAction(ACAO_ESCUTA_ON)
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
            .putExtra(EXTRA_MUSICA, false); // no teste, música não deve mascarar o resultado
        ContextCompat.startForegroundService(ctx, i);
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
            pausarDuranteMusica = false;
            main.removeCallbacks(testeFim);
            testeDeteccoes = 0;
            testeAte = System.currentTimeMillis() + Math.max(10, Math.min(60, segundos)) * 1000L;
            testeDetector = DETECTOR;
            main.postDelayed(testeFim, Math.max(10, Math.min(60, segundos)) * 1000L + 300);
            iniciarEscutaInterna();
            estadoNotificacao = "Teste da palavra de ativação — diga “Jarvis”";
            notificar();
            return START_NOT_STICKY;
        }

        if (ACAO_SERVICO_ON.equals(acao)) {
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
        if (intent != null && intent.hasExtra(EXTRA_MUSICA)) {
            pausarDuranteMusica = intent.getBooleanExtra(EXTRA_MUSICA, JarvisPrefs.pausarMusica(this));
        } else {
            pausarDuranteMusica = JarvisPrefs.pausarMusica(this);
        }
        // O pedido veio do usuário (ou do vigia com estado salvo): persiste e mantém o vigia.
        JarvisPrefs.desejaOuvir(this, true);
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
        return "o detector de ativação próprio não conseguiu ouvir. Confira a permissão de microfone e, se o aparelho não tiver o reconhecimento de português, instale o pacote de idioma (Configurações ▸ Google ▸ Voz)." + detalhe;
    }

    /* ---------- Motor de escuta (detector próprio) ---------- */

    private void iniciarMotor() throws Exception {
        if (!querEscuta) return;
        if (chamadaAtiva() || (pausarDuranteMusica && musicaAtiva())) return;
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            throw new IllegalStateException("o reconhecimento de voz do Android não está disponível neste aparelho.");
        }
        // A calibragem é relida no começo de cada sessão: mexer na sensibilidade na tela
        // passa a valer sem reiniciar o serviço.
        cfg = JarvisAtivacao.config(JarvisPrefs.sensibilidade(this), JarvisPrefs.variantes(this));
        detectorAtual = DETECTOR;
        escutando = true;
        estadoNotificacao = testeAtivoInterno()
            ? "Teste · diga “Jarvis” (" + testeDeteccoes + ")"
            : "Ouvindo “Jarvis” · detector próprio";
        notificar();
        if (!sessao && proximo == null) agendarSessao(0);
    }

    private void pausarMotor() {
        encerrarSessao(true);
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
        // Falha fatal: desliga o desejo de ouvir e cancela o vigia. Sem isso, o vigia
        // reabria a escuta a cada 15 minutos para falhar de novo — o microfone ficava
        // ligando e desligando sem nunca reconhecer a palavra. Só o usuário religa.
        JarvisPrefs.desejaOuvir(this, false);
        JarvisWatchdog.cancelar(this);
        encerrarEscuta();
        estadoNotificacao = "Escuta parada — toque para abrir";
        notificar();
        if (avisar) JarvisWakeBus.parou("Detector local: " + (motivo == null ? "falha desconhecida" : motivo));
        // O serviço continua vivo (em espera) para a interface poder religar a escuta
        // sem precisar reiniciar um serviço de microfone a partir do fundo. Se ninguém
        // religar em dois minutos, ele sai: primeiro plano e notificação sem escuta só
        // gastariam bateria e ficariam presos na barra de status.
        main.postDelayed(() -> {
            if (!querEscuta && !JarvisPrefs.desejaOuvir(JarvisService.this)) stopSelf();
        }, 120000L);
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

    /* ---------- Detector de ativação próprio ----------
     * O transcritor do Android não conhece "Jarvis": com voz brasileira ele escreve "já vi",
     * "javis", "jarvi", "charvis" e variações. Aqui cada sessão devolve até cinco hipóteses,
     * todas são conferidas pelas regras de JarvisAtivacao e o resultado PARCIAL já vale: o
     * assistente é chamado antes de a frase terminar — é isso que faz a ativação parecer
     * instantânea em vez de esperar o silêncio. Duas travas evitam sustos: o porteiro de
     * ruído (som baixo demais para ser voz dirigida ao aparelho) e o mínimo de caracteres
     * aceito em resultado parcial.
     */

    /** Quantas ativações o porteiro de ruído descartou (aparece no diagnóstico). */
    static int descartesRuido() {
        JarvisService s = instancia;
        return s == null ? 0 : s.rejeitadasRuido;
    }

    /** Calibragem em uso, em uma linha legível, para o diagnóstico e o registro. */
    static String calibragem() {
        JarvisService s = instancia;
        return s == null ? '' : s.cfg.descricao();
    }

    private void agendarSessao(long atrasoMs) {
        if (proximo != null) main.removeCallbacks(proximo);
        proximo = () -> {
            proximo = null;
            iniciarSessao();
        };
        main.postDelayed(proximo, Math.max(0, atrasoMs));
    }

    private boolean temReconhecimentoLocal() {
        return Build.VERSION.SDK_INT >= 31 && SpeechRecognizer.isOnDeviceRecognitionAvailable(this);
    }

    private ArrayList<String> hipoteses(Bundle results) {
        ArrayList<String> lista = results == null ? null
            : results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
        return lista == null ? new ArrayList<>() : lista;
    }

    private void iniciarSessao() {
        if (!querEscuta || sessao) return;
        if (chamadaAtiva() || (pausarDuranteMusica && musicaAtiva())) return;
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            pararPorFalha("o reconhecimento de voz do Android não está disponível neste aparelho");
            return;
        }
        final boolean noDispositivo = temReconhecimentoLocal() && !preferirRede;
        try {
            rec = noDispositivo
                ? SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
                : SpeechRecognizer.createSpeechRecognizer(this);
        } catch (Exception e) {
            // Muitos aparelhos oferecem o reconhecedor local mas sem o pacote de português.
            if (noDispositivo) {
                preferirRede = true;
                agendarSessao(200);
                return;
            }
            pararPorFalha(e.getMessage());
            return;
        }
        sessao = true;
        parcial = "";
        picoDb = -120f;
        final boolean usouLocal = noDispositivo;
        final SpeechRecognizer r = rec;
        r.setRecognitionListener(new RecognitionListener() {
            @Override public void onReadyForSpeech(Bundle params) { }
            @Override public void onBeginningOfSpeech() { }
            /** Nível do áudio: alimenta o porteiro de ruído da ativação. */
            @Override public void onRmsChanged(float rmsdB) { if (rmsdB > picoDb) picoDb = rmsdB; }
            @Override public void onBufferReceived(byte[] buffer) { }
            @Override public void onEndOfSpeech() { }
            @Override public void onEvent(int eventType, Bundle params) { }

            @Override public void onPartialResults(Bundle results) {
                conferirEmLote(results, false);
            }

            @Override public void onResults(Bundle results) {
                if (conferirEmLote(results, true)) return;
                if (conferirAtivacao(parcial, true)) return;
                encerrarSessao(false);
                if (querEscuta) {
                    falhas = 0;
                    agendarSessao(400);
                }
            }

            @Override public void onError(int error) {
                if (conferirAtivacao(parcial, true)) return;
                boolean tinhaFala = parcial != null && !parcial.trim().isEmpty();
                encerrarSessao(false);
                if (!querEscuta) return;
                switch (error) {
                    case SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS:
                        pararPorFalha("permissão de microfone negada pelo usuário");
                        return;
                    case SpeechRecognizer.ERROR_RECOGNIZER_BUSY:
                        agendarSessao(1500);
                        return;
                    case 12: // ERROR_LANGUAGE_NOT_SUPPORTED
                    case 13: // ERROR_LANGUAGE_UNAVAILABLE (pacote offline ausente)
                    case 14: // ERROR_CANNOT_CHECK_SUPPORT
                        errosIdioma++;
                        if (usouLocal && errosIdioma < 3) {
                            preferirRede = true;
                            agendarSessao(300);
                            return;
                        }
                        pararPorFalha("o Android não tem o reconhecimento de português instalado. Baixe o pacote de idioma (Configurações ▸ Google ▸ Voz) ou cadastre palavras extras do seu jeito de falar em Ajustes ▸ Voz");
                        return;
                    case SpeechRecognizer.ERROR_NETWORK:
                    case SpeechRecognizer.ERROR_NETWORK_TIMEOUT:
                        if (preferirRede && temReconhecimentoLocal()) preferirRede = false;
                        falhas++;
                        if (falhas >= 6) {
                            pararPorFalha("sem conexão e o reconhecimento local não respondeu. O detector próprio precisa de rede quando o aparelho não tem o idioma offline");
                            return;
                        }
                        agendarSessao(Math.min(8000, 600L * falhas));
                        return;
                    case SpeechRecognizer.ERROR_SPEECH_TIMEOUT:
                    case SpeechRecognizer.ERROR_NO_MATCH:
                        falhas = 0;
                        // Reinício curto: quanto menos tempo entre sessões, menor a chance de
                        // o usuário falar exatamente no intervalo em que ninguém está ouvindo.
                        agendarSessao(tinhaFala ? 350 : 700);
                        return;
                    default:
                        falhas++;
                        if (falhas >= 10) {
                            pararPorFalha("o reconhecimento do Android falhou repetidamente (último código " + error + ")");
                            return;
                        }
                        agendarSessao(Math.min(4000, 300L * falhas));
                }
            }
        });
        Intent intent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE, "pt-BR")
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "pt-BR")
            .putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            .putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
            // Sessões longas, com mais silêncio tolerado: o microfone abre menos vezes e a
            // palavra dita no meio de uma frase tem mais chance de ser transcrita.
            .putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 5000L)
            .putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 1600L)
            .putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 1200L)
            .putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, getPackageName());
        if (usouLocal) intent.putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true);
        timeout = () -> {
            if (!sessao) return;
            if (conferirAtivacao(parcial, true)) return;
            encerrarSessao(false);
            if (querEscuta) agendarSessao(400);
        };
        main.postDelayed(timeout, 15000);
        try {
            r.startListening(intent);
        } catch (Exception e) {
            encerrarSessao(false);
            pararPorFalha(e.getMessage());
        }
    }

    /** Confere todas as hipóteses devolvidas pelo Android, não só a primeira. */
    private boolean conferirEmLote(Bundle results, boolean definitivo) {
        if (!querEscuta) return true;
        ArrayList<String> lista = hipoteses(results);
        if (lista.isEmpty()) return conferirAtivacao(null, definitivo);
        String primeiro = lista.get(0) == null ? "" : lista.get(0).trim();
        if (primeiro.length() > parcial.length()) parcial = primeiro;
        if (!definitivo && primeiro.length() < cfg.minimoParcial) return false;
        for (String hip : lista) {
            if (conferirAtivacao(hip, definitivo)) return true;
        }
        return false;
    }

    /** true quando a palavra foi encontrada (ou quando a ativação já foi encerrada). */
    private boolean conferirAtivacao(String texto, boolean definitivo) {
        if (!querEscuta) return true;
        if (texto == null || texto.trim().isEmpty()) return false;
        parcial = texto;
        if (!definitivo && !cfg.aceitaParcial) return false;
        if (!JarvisAtivacao.presente(texto, cfg)) return false;
        if (!definitivo && texto.trim().length() < cfg.minimoParcial) return false;
        if (picoDb < cfg.ruidoDb) {
            // Porteiro de ruído: a transcrição veio, mas o microfone mal registrou som —
            // típico de televisão, conversa ao fundo ou ruído que o reconhecimento tentou
            // interpretar. Não acorda; conta o descarte para a calibragem ficar visível.
            rejeitadasRuido++;
            JarvisPrefs.rejeitadas(this, JarvisPrefs.rejeitadas(this) + 1);
            encerrarSessao(false);
            if (querEscuta) agendarSessao(250);
            return true;
        }
        String limpo = texto.trim();
        querEscuta = false;
        encerrarSessao(true);
        disparar(limpo);
        return true;
    }

    private void encerrarSessao(boolean limparParcial) {
        if (timeout != null) { main.removeCallbacks(timeout); timeout = null; }
        if (proximo != null) { main.removeCallbacks(proximo); proximo = null; }
        sessao = false;
        SpeechRecognizer r = rec;
        rec = null;
        if (r != null) {
            try { r.cancel(); r.destroy(); } catch (Exception ignored) { }
        }
        if (limparParcial) parcial = "";
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
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Desligar escuta", pararPi);
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
        // O usuário fechou pelos recentes: se a escuta deve continuar, o serviço volta a
        // ouvir na hora e, como garantia, um alarme rápido tenta de novo em 8 s.
        if (JarvisPrefs.desejaOuvir(this)) {
            // A interface pausa a escuta para gravar o comando. Se ela morrer no meio (o
            // usuário fecha o app durante a resposta), ninguém religava: o serviço ficava
            // em "Escuta em espera" e o vigia não agia, porque o serviço ainda estava vivo.
            if (!querEscuta && testeAte == 0) {
                pausadoPelaInterface = false;
                try {
                    iniciarEscutaInterna();
                } catch (Exception e) {
                    pararPorFalha(mensagemFalha(e));
                }
            }
            JarvisWatchdog.agendarRapido(this, 8000L);
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
        // Se o sistema derrubou o serviço com a escuta ligada, o vigia tenta de novo em
        // 20 s (alarme rápido, separado do periódico de 15 min).
        if (JarvisPrefs.desejaOuvir(this)) JarvisWatchdog.agendarRapido(this, 20000L);
        stopForeground(true);
        super.onDestroy();
    }
}
