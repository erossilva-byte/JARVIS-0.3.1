package com.jarvis.nova;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.media.AudioAttributes;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;

import java.util.Locale;

/** Dispara no horário agendado: mostra a notificação e fala o aviso (2 vezes se for alarme). */
public class JarvisAlarmReceiver extends BroadcastReceiver {

    static final String CANAL = "jarvis_lembretes";

    @Override
    public void onReceive(Context ctx, Intent intent) {
        String titulo = intent.getStringExtra("titulo");
        String texto = intent.getStringExtra("texto");
        String fala = intent.getStringExtra("fala");
        boolean alarme = intent.getBooleanExtra("alarme", false);
        int id = intent.getIntExtra("id", 1);
        JarvisAlarmScheduler.concluir(ctx.getApplicationContext(), id);
        if (titulo == null) titulo = "Jarvis";
        if (texto == null) texto = "";
        if (fala == null || fala.isEmpty()) fala = texto;
        mostrar(ctx, id, titulo, texto);
        falar(ctx.getApplicationContext(), fala, alarme ? 2 : 1, goAsync());
    }

    private void mostrar(Context ctx, int id, String titulo, String texto) {
        NotificationManager nm = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm == null) return;
        Uri som = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM);
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(CANAL) == null) {
            NotificationChannel c = new NotificationChannel(CANAL, "Lembretes e alarmes", NotificationManager.IMPORTANCE_HIGH);
            c.setDescription("Avisos de lembretes, alarmes e timers do Jarvis");
            c.setSound(som, new AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build());
            c.enableVibration(true);
            nm.createNotificationChannel(c);
        }
        Intent abrir = new Intent(ctx, MainActivity.class);
        abrir.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        PendingIntent pi = PendingIntent.getActivity(ctx, id, abrir,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        Notification.Builder b = Build.VERSION.SDK_INT >= 26
            ? new Notification.Builder(ctx, CANAL)
            : new Notification.Builder(ctx);
        b.setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(titulo)
            .setContentText(texto)
            .setContentIntent(pi)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_ALARM);
        if (Build.VERSION.SDK_INT < 26) {
            b.setSound(som);
            b.setPriority(Notification.PRIORITY_HIGH);
        }
        nm.notify(id, b.build());
    }

    private void falar(Context ctx, final String texto, final int vezes, final PendingResult pr) {
        final Handler h = new Handler(Looper.getMainLooper());
        final TextToSpeech[] ref = new TextToSpeech[1];
        final boolean[] fim = new boolean[1];
        final Runnable terminar = new Runnable() {
            @Override
            public void run() {
                if (fim[0]) return;
                fim[0] = true;
                try {
                    if (ref[0] != null) ref[0].shutdown();
                } catch (Exception e) {
                    // ignora
                }
                try {
                    pr.finish();
                } catch (Exception e) {
                    // ignora
                }
            }
        };
        // O Android só dá alguns segundos ao receptor: encerra a fala por segurança.
        h.postDelayed(terminar, 9000);
        try {
            ref[0] = new TextToSpeech(ctx, new TextToSpeech.OnInitListener() {
                @Override
                public void onInit(int status) {
                    TextToSpeech t = ref[0];
                    if (status != TextToSpeech.SUCCESS || t == null) {
                        h.post(terminar);
                        return;
                    }
                    t.setLanguage(new Locale("pt", "BR"));
                    t.setAudioAttributes(new AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build());
                    t.setOnUtteranceProgressListener(new UtteranceProgressListener() {
                        @Override
                        public void onStart(String id) { }

                        @Override
                        public void onError(String id) {
                            h.post(terminar);
                        }

                        @Override
                        public void onDone(String id) {
                            if ("fim".equals(id)) h.post(terminar);
                        }
                    });
                    for (int i = 0; i < vezes; i++) {
                        String idu = (i == vezes - 1) ? "fim" : "p" + i;
                        t.speak(texto, TextToSpeech.QUEUE_ADD, null, idu);
                    }
                }
            });
        } catch (Exception e) {
            h.post(terminar);
        }
    }
}
