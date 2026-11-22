package com.jarvis.nova;

import android.Manifest;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.BroadcastReceiver;
import android.content.pm.PackageManager;
import android.content.pm.ServiceInfo;
import android.media.AudioManager;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.PowerManager;

import androidx.core.content.ContextCompat;

import com.getcapacitor.JSObject;


/**
 * Serviço em primeiro plano que mantém a escuta de ativação viva fora da tela.
 *
 * O detector pertence ao serviço (não à tela) e o estado desejado é persistido em
 * JarvisPrefs, junto da sensibilidade e das palavras extras do KWS. Assim, quando o
 * Android reinicia o serviço (START_STICKY), reinicia o aparelho ou encerra o app pelos
 * recentes, a escuta volta sozinha e calibrada do jeito que o usuário deixou.
 *
 * A detecção usa sherpa-onnx + AudioRecord em CPU, sem SpeechRecognizer, sem fallback
 * de rede e sem transmitir áudio. O modelo KWS disponível é treinado em inglês; o uso
 * com sotaques brasileiros exige validação de campo antes de prometer precisão.
 */
public class JarvisService extends Service {

    static final String CANAL = "jarvis_ativo";
    static final int ID = 4711;
    static final String ACAO_PARAR = "com.jarvis.nova.PARAR";
    static final String ACAO_SERVICO_ON = "com.jarvis.nova.SERVICO_ON";
    static final String ACAO_ESCUTA_ON = "com.jarvis.nova.ESCUTA_ON";
    static final String ACAO_ESCUTA_PAUSA = "com.jarvis.nova.ESCUTA_PAUSA";
    static final String ACAO_ESCUTA_OFF = "com.jarvis.nova.ESCUTA_OFF";
    static final String ACAO_PAUSAR = "com.jarvis.nova.ESCUTA_PAUSAR_MANUAL";
    static final String ACAO_RETOMAR = "com.jarvis.nova.ESCUTA_RETOMAR";
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
    /** true depois que startForeground() foi aceito nesta instância. */
    private boolean emPrimeiroPlano = false;

    /**
     * true quando a própria interface pediu a pausa (para gravar um comando).
     * Diferencia "pausado de propósito" de "a tela morreu no meio da ativação":
     * só no segundo caso o serviço se rearma sozinho.
     */
    private boolean pausadoPelaInterface = false;
    private Runnable rearme;
    /** Até quando a escuta fica parada depois de o fone ser desconectado. */
    private long pausaFoneAte = 0;
    private boolean foneRegistrado = false;

    /**
     * Rota de áudio mudou (fone Bluetooth caiu, cabo saiu): o Android manda este aviso
     * para quem está tocando. A escuta para por 5 s e volta sozinha, sem desligar nada.
     */
    private final BroadcastReceiver foneReceiver = new BroadcastReceiver() {
        @Override public void onReceive(Context context, Intent intent) {
            if (intent == null) return;
            if (AudioManager.ACTION_AUDIO_BECOMING_NOISY.equals(intent.getAction())) {
                main.post(JarvisService.this::pausarPorFone);
            }
        }
    };

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

    // KWS acústico sherpa-onnx: a inferência e a captura PCM acontecem no processo do serviço.
    // Não existe fallback para SpeechRecognizer, serviço de reconhecimento Android ou rede.
    private volatile JarvisKwsEngine kwsEngine;
    private volatile boolean sessao = false;
    /** Nome explícito do motor real, exposto no diagnóstico e na notificação. */
    static final String DETECTOR = "sherpa-onnx-kws-gigaspeech-en";

    /** Tráfego transmitido pelo app no início do processo, para a auditoria de privacidade. */
    private static long redeNoInicio = -1;

    private final Runnable monitorMidia = new Runnable() {
        @Override public void run() {
            if (!querEscuta || JarvisPrefs.pausadoManual(JarvisService.this)) return;
            // Chamada/VoIP nunca divide o microfone com o detector; mídia só pausa se o usuário pediu.
            String microfone = bloqueioMicrofone(JarvisService.this);
            boolean ocupado = chamadaAtiva() || (pausarDuranteMusica && musicaAtiva()) || !microfone.isEmpty();
            if (ocupado) {
                if (sessao) {
                    pausarMotor();
                    String novo = chamadaAtiva()
                        ? "Escuta pausada durante chamada"
                        : (pausarDuranteMusica && musicaAtiva() ? "Escuta pausada durante mídia" : "Escuta pausada: " + microfone);
                    if (!novo.equals(estadoNotificacao)) { estadoNotificacao = novo; notificar(); }
                }
            } else if (!sessao) {
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
        JarvisPrefs.ultimoErro(ctx, "");
        JarvisPrefs.desejaOuvir(ctx, true);
        JarvisPrefs.pausadoManual(ctx, false);
        JarvisPrefs.pausarMusica(ctx, pausarMusica);
        JarvisWatchdog.agendar(ctx, 15L * 60L * 1000L);
        JarvisManutencaoWorker.agendar(ctx);
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
        JarvisPrefs.pausadoManual(ctx, false);
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

    /* ---------- Perfil de energia e pausa manual (Fase 4B) ---------- */

    /** Pausa pelo botão da notificação: solta o microfone, mantém serviço e vigia. */
    static void pausarEscutaManual(Context ctx) {
        JarvisPrefs.pausadoManual(ctx, true);
        JarvisService s = instancia;
        if (s == null) return;
        s.main.post(() -> {
            s.pausadoPelaInterface = false;
            s.querEscuta = false;
            if (s.rearme != null) { s.main.removeCallbacks(s.rearme); s.rearme = null; }
            s.main.removeCallbacks(s.monitorMidia);
            s.pausarMotor();
            s.estadoNotificacao = "Escuta pausada por você — Retomar volta a ouvir";
            s.notificar();
        });
    }

    /** Retoma depois da pausa manual, respeitando o perfil de energia. */
    static void retomarEscutaManual(Context ctx) {
        JarvisPrefs.pausadoManual(ctx, false);
        JarvisPrefs.desejaOuvir(ctx, true);
        JarvisWatchdog.agendar(ctx, 15L * 60L * 1000L);
        JarvisService s = instancia;
        if (s != null) {
            s.main.post(s::iniciarEscutaInterna);
        } else {
            ContextCompat.startForegroundService(ctx,
                new Intent(ctx, JarvisService.class).setAction(ACAO_RETOMAR));
        }
    }

    /**
     * Motivo pelo qual o perfil de energia impede a escuta agora, ou "" quando permite.
     * Fica aqui, e não na interface, porque quem inicia o microfone é o serviço.
     */
    static String bloqueioPerfil(Context c) {
        String perfil = JarvisPrefs.perfilEnergia(c);
        if (JarvisPrefs.PERFIL_DESLIGADO.equals(perfil)) {
            return "perfil Desligado: a escuta em segundo plano não abre o microfone.";
        }
        if (JarvisPrefs.PERFIL_CARREGANDO.equals(perfil) && !carregando(c)) {
            return "perfil Somente carregando: o aparelho está na bateria.";
        }
        if (JarvisPrefs.PERFIL_HORARIO.equals(perfil) && !dentroDoHorario(c)) {
            return "perfil Horários: fora da janela "
                + formatarHora(JarvisPrefs.horarioInicio(c)) + "–" + formatarHora(JarvisPrefs.horarioFim(c)) + ".";
        }
        return "";
    }

    /**
     * Redução automática: economia de energia do sistema ou bateria no limite, sem
     * carregador. Devolve o motivo, ou "" quando a escuta pode rodar.
     */
    static String bloqueioBateria(Context c) {
        if (economiaEnergia(c)) return "economia de energia do sistema ligada.";
        int nivel = nivelBateria(c);
        int limite = JarvisPrefs.limiteBateria(c);
        if (nivel >= 0 && nivel <= limite && !carregando(c)) {
            return "bateria em " + nivel + "% (limite " + limite + "%).";
        }
        return "";
    }

    /** Nível da bateria em %, ou -1 quando o Android não informa. */
    static int nivelBateria(Context c) {
        try {
            Intent bat = c.registerReceiver(null, new android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED));
            if (bat == null) return -1;
            int nivel = bat.getIntExtra(android.os.BatteryManager.EXTRA_LEVEL, -1);
            int escala = bat.getIntExtra(android.os.BatteryManager.EXTRA_SCALE, -1);
            if (nivel < 0 || escala <= 0) return -1;
            return Math.round(nivel * 100f / escala);
        } catch (Exception e) {
            return -1;
        }
    }

    /** Economia de energia do sistema (a que o usuário liga em Configurações ▸ Bateria). */
    static boolean economiaEnergia(Context c) {
        try {
            PowerManager pm = (PowerManager) c.getSystemService(Context.POWER_SERVICE);
            return pm != null && pm.isPowerSaveMode();
        } catch (Exception e) {
            return false;
        }
    }

    /** Pausa curta depois de o fone cair; o laço de 1 s retoma quando o tempo passa. */
    private void pausarPorFone() {
        if (!querEscuta) return;
        // Pausa manual vence: o aviso do fone não pode trocar o texto nem fingir que volta sozinho.
        if (JarvisPrefs.pausadoManual(this)) return;
        pausaFoneAte = System.currentTimeMillis() + 5000;
        pausarMotor();
        estadoNotificacao = "Escuta pausada: o fone foi desconectado";
        notificar();
    }

    /**
     * Bytes que o app transmitiu desde o início do processo, pelo contador do Android.
     * Serve como evidência de que a escuta parada não gera tráfego; não diz o que era o
     * tráfego, e o contador do sistema reinicia quando o aparelho reinicia.
     */
    static long trafegoTxBytes() {
        try {
            long v = android.net.TrafficStats.getUidTxBytes(android.os.Process.myUid());
            return v < 0 ? -1 : v;
        } catch (Throwable e) {
            return -1;
        }
    }

    /** Tráfego desde o início do processo; -1 quando o Android não informa. */
    static long redeDesdeInicioBytes() {
        long agora = trafegoTxBytes();
        if (redeNoInicio < 0 || agora < 0) return -1;
        return Math.max(0, agora - redeNoInicio);
    }

    /** Quanto falta da pausa do fone, em ms (0 quando não está pausada). */
    static long pausaFoneRestanteMs() {
        JarvisService s = instancia;
        if (s == null) return 0;
        return Math.max(0, s.pausaFoneAte - System.currentTimeMillis());
    }

    /**
     * Outro app gravando agora? Usa as configurações de gravação ativas do sistema, que
     * não dão acesso ao áudio nem exigem permissão extra. O próprio app é ignorado.
     */
    static String bloqueioMicrofone(Context c) {
        try {
            AudioManager am = (AudioManager) c.getSystemService(Context.AUDIO_SERVICE);
            if (am == null) return "";
            int nossa = sessaoAudioLocal();
            int desconhecidas = 0;
            for (android.media.AudioRecordingConfiguration cfg : am.getActiveRecordingConfigurations()) {
                // A sessão de áudio identifica o nosso próprio AudioRecord sem depender de
                // permissão de sistema (o nome do pacote exige MODIFY_AUDIO_ROUTING).
                int sessao = cfg.getClientAudioSessionId();
                if (nossa != 0 && sessao == nossa) continue;
                String pkg = cfg.getClientPackageName();
                if (pkg != null && !pkg.isEmpty()) {
                    if (pkg.equals(c.getPackageName())) continue;
                    return "outro app está usando o microfone (" + pkg + ").";
                }
                desconhecidas++;
            }
            // Sem MODIFY_AUDIO_ROUTING o pacote vem vazio (AOSP). Enquanto estamos gravando,
            // uma entrada sem nome é o nosso próprio registro; duas já indicam outro app.
            if (nossa == 0 && escutando && desconhecidas > 0) desconhecidas--;
            if (desconhecidas > 0) return "outro app está usando o microfone.";
        } catch (Throwable ignored) { }
        return "";
    }

    /** Sessão do nosso AudioRecord; permite ignorar a própria captura na lista do sistema. */
    private static int sessaoAudioLocal() {
        JarvisService s = instancia;
        JarvisKwsEngine e = s == null ? null : s.kwsEngine;
        return e == null ? 0 : e.sessaoAudio();
    }

    /** Carregador conectado agora (bateria cheia conta como conectada). */
    static boolean carregando(Context c) {
        try {
            Intent bat = c.registerReceiver(null, new android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED));
            if (bat == null) return false;
            int status = bat.getIntExtra(android.os.BatteryManager.EXTRA_STATUS, -1);
            return status == android.os.BatteryManager.BATTERY_STATUS_CHARGING
                || status == android.os.BatteryManager.BATTERY_STATUS_FULL;
        } catch (Exception e) {
            return false;
        }
    }

    private static boolean dentroDoHorario(Context c) {
        int inicio = JarvisPrefs.horarioInicio(c);
        int fim = JarvisPrefs.horarioFim(c);
        if (inicio == fim) return true; // janela de 24 h
        java.util.Calendar cal = java.util.Calendar.getInstance();
        int agora = cal.get(java.util.Calendar.HOUR_OF_DAY) * 60 + cal.get(java.util.Calendar.MINUTE);
        return inicio < fim ? (agora >= inicio && agora < fim) : (agora >= inicio || agora < fim);
    }

    private static String formatarHora(int minutos) {
        return String.format(java.util.Locale.ROOT, "%02d:%02d", minutos / 60, minutos % 60);
    }

    /** Reavalia o perfil agora: usado quando o usuário troca a opção na tela. */
    static void aplicarPerfil(Context ctx) {
        JarvisService s = instancia;
        if (s == null) return;
        s.main.post(() -> {
            if (!JarvisPrefs.desejaOuvir(s)) return;
            if (JarvisPrefs.pausadoManual(s)) {
                s.pausarMotor();
                s.estadoNotificacao = "Escuta pausada por você — Retomar volta a ouvir";
                s.notificar();
                return;
            }
            String bloqueio = bloqueioPerfil(s);
            if (!bloqueio.isEmpty()) {
                s.querEscuta = false;
                s.main.removeCallbacks(s.monitorMidia);
                s.pausarMotor();
                s.estadoNotificacao = "Escuta parada pelo perfil — " + bloqueio;
                s.notificar();
                return;
            }
            s.iniciarEscutaInterna();
        });
    }

    /** Inicia uma janela de teste: cada "Jarvis" conta como acerto e não abre a tela. */
    static void iniciarTeste(Context ctx, int segundos) {
        JarvisPrefs.ultimoErro(ctx, "");
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
        if (redeNoInicio < 0) redeNoInicio = trafegoTxBytes();
        // ContextCompat exige a flag de não-exportado no Android 14+; o aviso de rota de
        // áudio é do sistema, mas a chamada é a mesma em todas as versões suportadas.
        try {
            ContextCompat.registerReceiver(this, foneReceiver,
                new IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY),
                ContextCompat.RECEIVER_NOT_EXPORTED);
            foneRegistrado = true;
        } catch (Throwable ignored) { }
        // O serviço pode nascer de startForegroundService() (vigia, alarme, notificação ou
        // interface). O Android dá 5 s para startForeground() e mata o processo com
        // ForegroundServiceDidNotStartInTimeException se isso não acontecer. Promover aqui,
        // antes de qualquer trabalho, é a única forma de o prazo valer em TODOS os caminhos.
        try {
            promoverPrimeiroPlano();
        } catch (Throwable e) {
            // Nada em onCreate pode escapar: uma exceção aqui também viraria o crash de
            // "serviço em primeiro plano não iniciou a tempo".
            registrarFalhaPrimeiroPlano(e);
            stopSelf();
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // Mesma garantia do onCreate: inclusive "parar", "pausar" e "sem permissão" precisam
        // cumprir o contrato do primeiro plano antes de sair. Era aqui que o app caía com
        // "Context.startForegroundService() did not then call Service.startForeground()".
        promoverPrimeiroPlano();
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
        if (ACAO_PAUSAR.equals(acao)) {
            JarvisPrefs.pausadoManual(this, true);
            pausadoPelaInterface = false;
            querEscuta = false;
            main.removeCallbacks(monitorMidia);
            pausarMotor();
            estadoNotificacao = "Escuta pausada por você — Retomar volta a ouvir";
            notificar();
            return START_STICKY;
        }
        if (ACAO_RETOMAR.equals(acao)) {
            JarvisPrefs.pausadoManual(this, false);
            JarvisPrefs.desejaOuvir(this, true);
            JarvisWatchdog.agendar(this, 15L * 60L * 1000L);
            iniciarEscutaInterna();
            return START_STICKY;
        }
        if (ACAO_ESCUTA_OFF.equals(acao)) {
            JarvisPrefs.desejaOuvir(this, false);
            JarvisWatchdog.cancelar(this);
            encerrarEscuta();
            estadoNotificacao = "Escuta em espera";
            notificar();
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
        if (JarvisPrefs.pausadoManual(this)) {
            // A pausa do usuário vence o pedido de ligar, inclusive o do vigia.
            querEscuta = false;
            pausarMotor();
            estadoNotificacao = "Escuta pausada por você — Retomar volta a ouvir";
            notificar();
            return START_STICKY;
        }
        iniciarEscutaInterna();
        return START_STICKY;
    }

    private void iniciarEscutaInterna() {
        main.post(() -> {
            try {
                if (JarvisPrefs.pausadoManual(this)) {
                    querEscuta = false;
                    pausarMotor();
                    estadoNotificacao = "Escuta pausada por você — Retomar volta a ouvir";
                    notificar();
                    return;
                }
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
        return "o detector KWS local não conseguiu iniciar. Confira a permissão de microfone, espaço livre e integridade dos arquivos sherpa-onnx incluídos no APK." + detalhe;
    }

    /* ---------- Motor de escuta (KWS acústico sherpa-onnx) ---------- */

    private void iniciarMotor() throws Exception {
        if (!querEscuta || sessao) return;
        // Perfil de energia: o microfone nem abre. O laço de 1 s volta a tentar, então
        // conectar o carregador ou entrar na janela de horário já libera a escuta.
        String bloqueio = bloqueioPerfil(this);
        if (!bloqueio.isEmpty()) {
            String novo = "Escuta aguardando o perfil — " + bloqueio;
            if (!novo.equals(estadoNotificacao)) { estadoNotificacao = novo; notificar(); }
            return;
        }
        String bateria = bloqueioBateria(this);
        if (!bateria.isEmpty()) {
            String novo = "Escuta reduzida para poupar bateria — " + bateria;
            if (!novo.equals(estadoNotificacao)) { estadoNotificacao = novo; notificar(); }
            return;
        }
        if (System.currentTimeMillis() < pausaFoneAte) return;
        String outroApp = bloqueioMicrofone(this);
        if (!outroApp.isEmpty()) {
            String novo = "Escuta pausada: " + outroApp;
            if (!novo.equals(estadoNotificacao)) { estadoNotificacao = novo; notificar(); }
            return;
        }
        if (chamadaAtiva() || (pausarDuranteMusica && musicaAtiva())) return;
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
                != PackageManager.PERMISSION_GRANTED) {
            throw new SecurityException("Permissão de microfone não concedida.");
        }
        // A sensibilidade da tela altera o limiar acústico do KWS: alta = mais permissivo;
        // baixa = mais conservador para reduzir ativações acidentais.
        int sensibilidade = JarvisPrefs.sensibilidade(this);
        detectorAtual = DETECTOR;
        sessao = true;
        escutando = false; // só passa a true depois que AudioRecord confirma gravação ativa
        estadoNotificacao = "Preparando o detector KWS local…";
        notificar();

        if (kwsEngine != null) {
            kwsEngine.stop();
            kwsEngine = null;
        }
        kwsEngine = new JarvisKwsEngine(this, new JarvisKwsEngine.Listener() {
            @Override public void onDetected(String keyword) {
                main.post(() -> {
                    if (!querEscuta) return;
                    sessao = false;
                    escutando = false;
                    disparar(keyword == null || keyword.trim().isEmpty() ? "Jarvis" : keyword);
                });
            }

            @Override public void onError(String message) {
                main.post(() -> {
                    if (!querEscuta) return;
                    sessao = false;
                    escutando = false;
                    pararPorFalha(message);
                });
            }

            @Override public void onState(String state) {
                main.post(() -> {
                    if (!querEscuta) return;
                    escutando = state != null && state.startsWith("KWS local ativo");
                    // No teste, a mensagem só aparece quando o microfone abriu de verdade:
                    // assim um perfil/bateria bloqueando não parece uma falha do detector.
                    estadoNotificacao = testeAtivoInterno() && escutando
                        ? "Teste da palavra de ativação — diga “Jarvis”"
                        : state;
                    notificar();
                });
            }
        }, sensibilidade, JarvisPrefs.variantes(this));
        kwsEngine.start();
    }

    private void pausarMotor() {
        sessao = false;
        escutando = false;
        JarvisKwsEngine atual = kwsEngine;
        if (atual != null) atual.stop();
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
            if (JarvisPrefs.pausadoManual(this)) return;
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

    /* ---------- Motor KWS acústico local ---------- */
    static String calibragem() {
        JarvisService s = instancia;
        if (s == null) return "";
        int sens = JarvisPrefs.sensibilidade(s);
        float limiar = sens >= 75 ? 0.25f : (sens >= 45 ? 0.35f : 0.45f);
        return "Sherpa-ONNX KWS local · GigaSpeech inglês · limiar " + limiar;
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
        boolean pausado = JarvisPrefs.pausadoManual(this);
        Intent alternar = new Intent(this, JarvisService.class).setAction(pausado ? ACAO_RETOMAR : ACAO_PAUSAR);
        PendingIntent alternarPi = PendingIntent.getService(this, 2, alternar, fi | PendingIntent.FLAG_UPDATE_CURRENT);
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
            .addAction(pausado ? android.R.drawable.ic_media_play : android.R.drawable.ic_media_pause,
                pausado ? "Retomar" : "Pausar", alternarPi)
            .addAction(android.R.drawable.ic_menu_view, "Abrir", abrirPi)
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

    /**
     * Cumpre o contrato do primeiro plano uma única vez por instância.
     *
     * O tipo do serviço é escolhido pelo que está realmente disponível: com RECORD_AUDIO
     * concedida, "microphone"; sem ela, "dataSync" (permissão normal, declarada no
     * manifesto). Sem essa escolha, o Android 14 recusa startForeground() com
     * SecurityException quando o microfone não foi autorizado — e a recusa virava o mesmo
     * crash de serviço que não subiu. Qualquer falha inesperada é registrada e o serviço
     * sai de cena sozinho, sem deixar o processo pendurado.
     */
    private void promoverPrimeiroPlano() {
        if (emPrimeiroPlano) { notificar(); return; }
        try {
            criarCanal();
            subirPrimeiroPlano(montarNotificacao());
            emPrimeiroPlano = true;
            return;
        } catch (Throwable e) {
            registrarFalhaPrimeiroPlano(e);
        }
        // Segunda tentativa, mínima: sem PendingIntent, sem ações e sem depender de
        // preferências. O prazo de 5 s do Android continua correndo; se a notificação
        // completa falhar, esta ainda cumpre o contrato e evita o
        // ForegroundServiceDidNotStartInTimeException que derrubava o app.
        try {
            Notification.Builder b = new Notification.Builder(this, CANAL);
            b.setContentTitle("Jarvis ativo")
                .setSmallIcon(android.R.drawable.ic_btn_speak_now)
                .setOngoing(true)
                .setOnlyAlertOnce(true);
            subirPrimeiroPlano(b.build());
            emPrimeiroPlano = true;
            return;
        } catch (Throwable e2) {
            registrarFalhaPrimeiroPlano(e2);
        }
        try { stopForeground(true); } catch (Throwable ignored) { }
        stopSelf();
    }

    /** startForeground com o tipo exigido pelo Android 10+ (e sem tipo nas versões antigas). */
    private void subirPrimeiroPlano(Notification n) {
        if (Build.VERSION.SDK_INT >= 29) {
            boolean podeMicrofone = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
                == PackageManager.PERMISSION_GRANTED;
            int tipo = podeMicrofone
                ? ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                : ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC;
            startForeground(ID, n, tipo);
        } else {
            startForeground(ID, n);
        }
    }

    /** Registra a recusa sem deixar uma exceção de SharedPreferences escapar do onCreate. */
    private void registrarFalhaPrimeiroPlano(Throwable e) {
        try {
            String msg = e == null ? "erro desconhecido" : (e.getMessage() == null ? e.getClass().getSimpleName() : e.getMessage());
            JarvisPrefs.ultimoErro(this, "serviço em primeiro plano recusado: " + msg);
        } catch (Throwable ignored) { /* registro é opcional */ }
    }

    @Override
    public void onTaskRemoved(Intent rootIntent) {
        // O usuário fechou pelos recentes: se a escuta deve continuar, o serviço volta a
        // ouvir na hora e, como garantia, um alarme rápido tenta de novo em 8 s.
        if (JarvisPrefs.desejaOuvir(this) && !JarvisPrefs.pausadoManual(this)) {
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
        if (foneRegistrado) {
            try { unregisterReceiver(foneReceiver); } catch (Throwable ignored) { }
            foneRegistrado = false;
        }
        escutando = false;
        instancia = null;
        emPrimeiroPlano = false;
        // Se o sistema derrubou o serviço com a escuta ligada, o vigia tenta de novo em
        // 20 s (alarme rápido, separado do periódico de 15 min).
        if (JarvisPrefs.desejaOuvir(this)) JarvisWatchdog.agendarRapido(this, 20000L);
        stopForeground(true);
        super.onDestroy();
    }
}
