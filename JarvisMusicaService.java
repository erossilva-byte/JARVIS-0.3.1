package com.jarvis.nova;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.media.AudioAttributes;
import android.media.MediaMetadata;
import android.media.MediaPlayer;
import android.media.session.MediaSession;
import android.media.session.PlaybackState;
import android.net.Uri;
import android.os.Build;
import android.os.IBinder;
import android.os.PowerManager;

import androidx.core.content.ContextCompat;

import com.getcapacitor.JSObject;

import java.util.ArrayList;

/**
 * Toca as músicas que estão no próprio aparelho, de verdade.
 *
 * Antes, "coloca a música X" só abria a busca de outro aplicativo e parava ali. Este
 * serviço toca o arquivo encontrado na biblioteca de mídia do Android (MediaStore), com
 * notificação, controles de tela bloqueada e MediaSession — e continua tocando com o app
 * fechado. O que não estiver no aparelho continua caindo na busca de um app de streaming,
 * com o aviso honesto de que ele não inicia a faixa sozinho.
 */
public class JarvisMusicaService extends Service {

    static final String CANAL = "jarvis_musica";
    static final int ID = 4712;
    static final String ACAO_TOCAR = "com.jarvis.nova.MUSICA_TOCAR";
    static final String ACAO_CONTROLE = "com.jarvis.nova.MUSICA_CONTROLE";

    static final String EXTRA_URIS = "uris";
    static final String EXTRA_TITULOS = "titulos";
    static final String EXTRA_ARTISTAS = "artistas";
    static final String EXTRA_COMANDO = "comando";

    // Estado lido pela interface (escrito no thread principal, lido de qualquer thread).
    private static volatile boolean tocando = false;
    private static volatile String tituloAtual = "";
    private static volatile String artistaAtual = "";
    private static volatile int posicaoAtual = 0;
    private static volatile int duracaoAtual = 0;
    private static volatile int indiceAtual = -1;
    private static volatile int totalAtual = 0;
    private static volatile String erroAtual = "";

    private MediaPlayer player;
    private MediaSession sessao;
    private PowerManager.WakeLock trava;
    private final ArrayList<String> uris = new ArrayList<>();
    private final ArrayList<String> titulos = new ArrayList<>();
    private final ArrayList<String> artistas = new ArrayList<>();

    /* ---------- Consulta de estado (usada pelo plugin) ---------- */

    static JSObject estado() {
        JSObject o = new JSObject();
        o.put("tocando", tocando);
        o.put("titulo", tituloAtual);
        o.put("artista", artistaAtual);
        o.put("posicao", posicaoAtual);
        o.put("duracao", duracaoAtual);
        o.put("indice", indiceAtual);
        o.put("total", totalAtual);
        o.put("erro", erroAtual);
        o.put("ativo", !tituloAtual.isEmpty());
        return o;
    }

    static void tocar(Context ctx, ArrayList<String> u, ArrayList<String> t, ArrayList<String> a) {
        Intent i = new Intent(ctx, JarvisMusicaService.class);
        i.setAction(ACAO_TOCAR);
        i.putStringArrayListExtra(EXTRA_URIS, u);
        i.putStringArrayListExtra(EXTRA_TITULOS, t);
        i.putStringArrayListExtra(EXTRA_ARTISTAS, a);
        ContextCompat.startForegroundService(ctx, i);
    }

    static void comando(Context ctx, String comando) {
        Intent i = new Intent(ctx, JarvisMusicaService.class);
        i.setAction(ACAO_CONTROLE);
        i.putExtra(EXTRA_COMANDO, comando == null ? "" : comando);
        try {
            ContextCompat.startForegroundService(ctx, i);
        } catch (Exception e) {
            // Serviço já encerrado: nada a controlar.
        }
    }

    @Override
    public IBinder onBind(Intent intent) { return null; }

    @Override
    public void onCreate() {
        super.onCreate();
        criarCanal();
        try {
            sessao = new MediaSession(this, "JarvisMusica");
            sessao.setCallback(new MediaSession.Callback() {
                @Override public void onPlay() { retomar(); }
                @Override public void onPause() { pausar(); }
                @Override public void onStop() { encerrar(); }
                @Override public void onSkipToNext() { proxima(); }
                @Override public void onSkipToPrevious() { anterior(); }
            });
            sessao.setActive(true);
        } catch (Throwable e) {
            sessao = null;
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        try {
            if (intent == null) {
                // Reinício sem comando (não deveria acontecer: o serviço não é STICKY).
                // Encerra em vez de ficar sem notificação nem áudio.
                pararTudo();
                return START_NOT_STICKY;
            }
            String acao = intent.getAction() == null ? "" : intent.getAction();
            if (ACAO_TOCAR.equals(acao)) {
                iniciarPrimeiroPlano();
                ArrayList<String> u = intent.getStringArrayListExtra(EXTRA_URIS);
                ArrayList<String> t = intent.getStringArrayListExtra(EXTRA_TITULOS);
                ArrayList<String> a = intent.getStringArrayListExtra(EXTRA_ARTISTAS);
                uris.clear(); titulos.clear(); artistas.clear();
                if (u != null) uris.addAll(u);
                if (t != null) titulos.addAll(t);
                if (a != null) artistas.addAll(a);
                totalAtual = uris.size();
                erroAtual = "";
                if (uris.isEmpty()) { pararTudo(); return START_NOT_STICKY; }
                tocarIndice(0);
            } else if (ACAO_CONTROLE.equals(acao)) {
                // Este serviço é criado com startForegroundService(). Se ele não chamar
                // startForeground() em poucos segundos, o Android encerra o processo com
                // ForegroundServiceDidNotStartInTimeException — era o que acontecia ao
                // pedir "pausar"/"próxima" com o player já parado.
                iniciarPrimeiroPlano();
                String c = intent.getStringExtra(EXTRA_COMANDO);
                c = c == null ? "" : c.trim().toLowerCase(java.util.Locale.ROOT);
                if (player == null) {
                    // Nada para controlar: sai do primeiro plano na hora, sem áudio pendente.
                    pararTudo();
                    return START_NOT_STICKY;
                }
                switch (c) {
                    case "pausar": pausar(); break;
                    case "continuar":
                    case "retomar": retomar(); break;
                    case "proxima": proxima(); break;
                    case "anterior": anterior(); break;
                    case "parar": encerrar(); break;
                    default: break;
                }
            }
        } catch (Throwable e) {
            erroAtual = "Falha no player: " + (e.getMessage() == null ? "erro desconhecido" : e.getMessage());
            pararTudo();
        }
        return START_NOT_STICKY;
    }

    /* ---------- Reprodução ---------- */

    private void tocarIndice(int i) {
        if (i < 0 || i >= uris.size()) { encerrar(); return; }
        indiceAtual = i;
        tituloAtual = i < titulos.size() ? titulos.get(i) : "";
        artistaAtual = i < artistas.size() ? artistas.get(i) : "";
        soltarPlayer();
        try {
            MediaPlayer p = new MediaPlayer();
            p.setAudioAttributes(new AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build());
            p.setDataSource(this, Uri.parse(uris.get(i)));
            p.setOnPreparedListener(this::aoPreparar);
            p.setOnCompletionListener(this::aoTerminar);
            p.setOnErrorListener((mp, oQue, extra) -> {
                erroAtual = "Não consegui tocar “" + tituloAtual + "”.";
                if (indiceAtual + 1 < uris.size()) tocarIndice(indiceAtual + 1);
                else pararTudo();
                return true;
            });
            player = p;
            p.prepareAsync();
            atualizarNotificacao();
        } catch (Throwable e) {
            erroAtual = "Arquivo de áudio indisponível: " + (e.getMessage() == null ? "erro desconhecido" : e.getMessage());
            if (i + 1 < uris.size()) tocarIndice(i + 1);
            else pararTudo();
        }
    }

    private void aoPreparar(MediaPlayer p) {
        try {
            p.start();
            tocando = true;
            duracaoAtual = Math.max(0, p.getDuration());
            segurarTrava();
            publicarSessao(true);
            atualizarNotificacao();
        } catch (Throwable e) {
            erroAtual = "Não consegui iniciar o áudio: " + (e.getMessage() == null ? "erro desconhecido" : e.getMessage());
            pararTudo();
        }
    }

    private void aoTerminar(MediaPlayer p) {
        if (indiceAtual + 1 < uris.size()) tocarIndice(indiceAtual + 1);
        else {
            tocando = false;
            posicaoAtual = duracaoAtual;
            publicarSessao(false);
            encerrar();
        }
    }

    private void pausar() {
        try {
            if (player != null && player.isPlaying()) {
                player.pause();
                tocando = false;
                posicaoAtual = player.getCurrentPosition();
                publicarSessao(false);
                atualizarNotificacao();
                soltarTrava();
            }
        } catch (Throwable ignored) { }
    }

    private void retomar() {
        try {
            if (player != null) {
                player.start();
                tocando = true;
                publicarSessao(true);
                atualizarNotificacao();
                segurarTrava();
            }
        } catch (Throwable ignored) { }
    }

    private void proxima() {
        if (uris.isEmpty()) return;
        int alvo = indiceAtual + 1;
        if (alvo >= uris.size()) alvo = 0;
        tocarIndice(alvo);
    }

    private void anterior() {
        if (uris.isEmpty()) return;
        try {
            // Reinicia a faixa atual quando já passou dos primeiros segundos.
            if (player != null && player.getCurrentPosition() > 4000) { player.seekTo(0); return; }
        } catch (Throwable ignored) { }
        int alvo = indiceAtual - 1;
        if (alvo < 0) alvo = uris.size() - 1;
        tocarIndice(alvo);
    }

    private void encerrar() {
        tocando = false;
        publicarSessao(false);
        pararTudo();
    }

    private void pararTudo() {
        soltarPlayer();
        soltarTrava();
        try {
            if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE);
            else stopForeground(true);
        } catch (Throwable ignored) { }
        stopSelf();
    }

    private void soltarPlayer() {
        MediaPlayer p = player;
        player = null;
        if (p == null) return;
        try { p.stop(); } catch (Throwable ignored) { }
        try { p.reset(); } catch (Throwable ignored) { }
        try { p.release(); } catch (Throwable ignored) { }
    }

    private void segurarTrava() {
        try {
            if (trava != null && trava.isHeld()) return;
            PowerManager pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
            if (pm == null) return;
            trava = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "jarvis:musica");
            trava.setReferenceCounted(false);
            trava.acquire(3 * 60 * 60 * 1000L);
        } catch (Throwable ignored) { }
    }

    private void soltarTrava() {
        try {
            if (trava != null && trava.isHeld()) trava.release();
        } catch (Throwable ignored) { }
        trava = null;
    }

    private void publicarSessao(boolean tocandoAgora) {
        if (sessao == null) return;
        try {
            int estado = tocandoAgora ? PlaybackState.STATE_PLAYING : PlaybackState.STATE_PAUSED;
            sessao.setPlaybackState(new PlaybackState.Builder()
                .setActions(PlaybackState.ACTION_PLAY | PlaybackState.ACTION_PAUSE
                    | PlaybackState.ACTION_PLAY_PAUSE | PlaybackState.ACTION_SKIP_TO_NEXT
                    | PlaybackState.ACTION_SKIP_TO_PREVIOUS | PlaybackState.ACTION_STOP)
                .setState(estado, posicaoAtual, 1f)
                .build());
            sessao.setMetadata(new MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE, tituloAtual)
                .putString(MediaMetadata.METADATA_KEY_ARTIST, artistaAtual)
                .putLong(MediaMetadata.METADATA_KEY_DURATION, duracaoAtual)
                .build());
            sessao.setActive(true);
        } catch (Throwable ignored) { }
    }

    /* ---------- Notificação ---------- */

    private void criarCanal() {
        if (Build.VERSION.SDK_INT < 26) return;
        try {
            NotificationManager nm = getSystemService(NotificationManager.class);
            if (nm == null) return;
            NotificationChannel c = new NotificationChannel(CANAL, "Música do J.A.R.V.I.S.", NotificationManager.IMPORTANCE_LOW);
            c.setShowBadge(false);
            nm.createNotificationChannel(c);
        } catch (Throwable ignored) { }
    }

    private PendingIntent pi(String comando, int codigo) {
        Intent i = new Intent(this, JarvisMusicaService.class);
        i.setAction(ACAO_CONTROLE);
        i.putExtra(EXTRA_COMANDO, comando);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= 23) flags |= PendingIntent.FLAG_IMMUTABLE;
        return PendingIntent.getService(this, codigo, i, flags);
    }

    private Notification montarNotificacao() {
        Intent abrir = new Intent(this, MainActivity.class);
        abrir.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= 23) flags |= PendingIntent.FLAG_IMMUTABLE;
        PendingIntent conteudo = PendingIntent.getActivity(this, 90, abrir, flags);

        String titulo = tituloAtual.isEmpty() ? "Música" : tituloAtual;
        String sub = artistaAtual.isEmpty() ? "J.A.R.V.I.S. Nova" : artistaAtual;
        Notification.Builder b = new Notification.Builder(this, CANAL);
        b.setContentTitle(titulo)
            .setContentText(sub)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentIntent(conteudo)
            .setOngoing(tocando)
            .setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .addAction(new Notification.Action.Builder(android.R.drawable.ic_media_previous, "Anterior", pi("anterior", 91)).build())
            .addAction(new Notification.Action.Builder(
                tocando ? android.R.drawable.ic_media_pause : android.R.drawable.ic_media_play,
                tocando ? "Pausar" : "Tocar",
                pi(tocando ? "pausar" : "continuar", 92)).build())
            .addAction(new Notification.Action.Builder(android.R.drawable.ic_media_next, "Próxima", pi("proxima", 93)).build());
        try {
            if (sessao != null) {
                Notification.MediaStyle estilo = new Notification.MediaStyle()
                    .setShowActionsInCompactView(0, 1, 2)
                    .setMediaSession(sessao.getSessionToken());
                b.setStyle(estilo);
            }
        } catch (Throwable ignored) { }
        return b.build();
    }

    private void atualizarNotificacao() {
        try {
            NotificationManager nm = getSystemService(NotificationManager.class);
            if (nm == null) return;
            nm.notify(ID, montarNotificacao());
        } catch (Throwable ignored) { }
    }

    private void iniciarPrimeiroPlano() {
        Notification n = montarNotificacao();
        try {
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);
            } else {
                startForeground(ID, n);
            }
        } catch (Throwable e) {
            erroAtual = "O Android não deixou o player rodar em segundo plano: " + (e.getMessage() == null ? "sem detalhe" : e.getMessage());
            try { startForeground(ID, n); } catch (Throwable ignored) { }
        }
    }

    @Override
    public void onDestroy() {
        soltarPlayer();
        soltarTrava();
        // Limpa o estado estático: sem isso, depois de o sistema encerrar o serviço a
        // interface continuava mostrando a última faixa como se estivesse tocando
        // ("ativo" e "tocando" ficavam verdadeiros para um player que não existe mais).
        tocando = false;
        tituloAtual = "";
        artistaAtual = "";
        posicaoAtual = 0;
        duracaoAtual = 0;
        indiceAtual = -1;
        totalAtual = 0;
        try { if (sessao != null) { sessao.setActive(false); sessao.release(); } } catch (Throwable ignored) { }
        sessao = null;
        super.onDestroy();
    }

    @Override
    public void onTaskRemoved(Intent rootIntent) {
        // O app fechado não interrompe a música: só o fim da fila ou um comando param.
        super.onTaskRemoved(rootIntent);
    }
}
