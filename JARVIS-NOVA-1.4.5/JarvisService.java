package com.jarvis.nova;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.os.Build;
import android.os.IBinder;

public class JarvisService extends Service {
    static final String CANAL = "jarvis_ativo";
    static final int ID = 4711;
    static final String ACAO_PARAR = "com.jarvis.nova.PARAR";


    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && ACAO_PARAR.equals(intent.getAction())) {
            stopSelf();
            return START_NOT_STICKY;
        }
        criarCanal();
        Notification n = montarNotificacao();
        try {
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE);
            } else {
                startForeground(ID, n);
            }
        } catch (Exception e) {
            stopSelf();
            return START_NOT_STICKY;
        }
        return START_NOT_STICKY;
    }

    private void criarCanal() {
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationChannel c = new NotificationChannel(CANAL, "Jarvis ativo", NotificationManager.IMPORTANCE_LOW);
            c.setDescription("Mantém a escuta de ativação enquanto autorizada");
            NotificationManager nm = getSystemService(NotificationManager.class);
            if (nm != null) nm.createNotificationChannel(c);
        }
    }

    private Notification montarNotificacao() {
        int fi = Build.VERSION.SDK_INT >= 23 ? PendingIntent.FLAG_IMMUTABLE : 0;
        Intent abrir = getPackageManager().getLaunchIntentForPackage(getPackageName());
        PendingIntent abrirPi = PendingIntent.getActivity(this, 0, abrir, fi | PendingIntent.FLAG_UPDATE_CURRENT);
        Intent parar = new Intent(this, JarvisService.class).setAction(ACAO_PARAR);
        PendingIntent pararPi = PendingIntent.getService(this, 1, parar, fi | PendingIntent.FLAG_UPDATE_CURRENT);

        Notification.Builder b = Build.VERSION.SDK_INT >= 26
            ? new Notification.Builder(this, CANAL)
            : new Notification.Builder(this);
        b.setContentTitle("J.A.R.V.I.S. Nova ativo")
            .setContentText("J.A.R.V.I.S. Nova em segundo plano; toque para abrir.")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setOngoing(true)
            .setContentIntent(abrirPi)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Parar", pararPi);
        return b.build();
    }

    @Override
    public void onTaskRemoved(Intent rootIntent) {
        // A notificação persistente e o botão "Parar" dão ao usuário controle explícito.
        // Não encerra automaticamente apenas porque a tarefa saiu da tela de recentes.
        super.onTaskRemoved(rootIntent);
    }

    @Override
    public void onDestroy() {
        stopForeground(true);
        super.onDestroy();
    }
}
