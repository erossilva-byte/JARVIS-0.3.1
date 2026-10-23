package com.jarvis.nova;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

/**
 * Rede de segurança da escuta em segundo plano.
 *
 * O serviço em primeiro plano já é START_STICKY, mas fabricantes agressivos (Xiaomi,
 * Samsung, Motorola, Oppo/Vivo) encerram serviços mesmo assim. Este receptor é
 * acordado por um alarme inexato (setAndAllowWhileIdle, sem exigir permissão de
 * alarme exato) a cada 15 minutos: se o usuário quer a escuta ligada e o serviço não
 * está rodando, ele é iniciado de novo — o alarme dá a isenção temporária que o
 * Android 12+ exige para iniciar um serviço de microfone a partir do fundo.
 *
 * Também é usado logo depois de o app sair dos recentes (onTaskRemoved), que é o
 * momento em que o sistema costuma derrubar o processo.
 */
public class JarvisWatchdog extends BroadcastReceiver {

    static final String ACAO = "com.jarvis.nova.VERIFICAR_ESCUTA";
    private static final int ID = 90210;
    private static final long INTERVALO = 15L * 60L * 1000L;

    static void agendar(Context c, long emMs) {
        try {
            AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
            if (am == null) return;
            Intent i = new Intent(c, JarvisWatchdog.class).setAction(ACAO);
            PendingIntent pi = PendingIntent.getBroadcast(c, ID, i, flags());
            long quando = System.currentTimeMillis() + Math.max(5000L, emMs);
            if (Build.VERSION.SDK_INT >= 31) {
                // Com alarme exato autorizado o reinício é pontual; sem ele, o alarme
                // inexato ainda é entregue no Doze (só pode atrasar).
                if (am.canScheduleExactAlarms()) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, quando, pi);
                else am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, quando, pi);
            } else if (Build.VERSION.SDK_INT >= 23) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, quando, pi);
            } else {
                am.set(AlarmManager.RTC_WAKEUP, quando, pi);
            }
        } catch (Exception ignored) { }
    }

    static void cancelar(Context c) {
        try {
            AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
            if (am == null) return;
            Intent i = new Intent(c, JarvisWatchdog.class).setAction(ACAO);
            PendingIntent pi = PendingIntent.getBroadcast(c, ID, i, flags());
            am.cancel(pi);
            pi.cancel();
        } catch (Exception ignored) { }
    }

    /** Mantém o vigia ativo enquanto o usuário quiser a escuta ligada. */
    static void garantir(Context c) {
        if (JarvisPrefs.desejaOuvir(c)) agendar(c, INTERVALO);
        else cancelar(c);
    }

    private static int flags() {
        return PendingIntent.FLAG_UPDATE_CURRENT
            | (Build.VERSION.SDK_INT >= 23 ? PendingIntent.FLAG_IMMUTABLE : 0);
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        Context ctx = context.getApplicationContext();
        if (!JarvisPrefs.desejaOuvir(ctx)) {
            cancelar(ctx);
            return;
        }
        if (!JarvisService.ativo()) {
            try {
                JarvisService.iniciarEscuta(ctx, JarvisPrefs.lerChave(ctx), JarvisPrefs.pausarMusica(ctx), JarvisPrefs.motor(ctx));
            } catch (Exception e) {
                JarvisPrefs.ultimoErro(ctx, "vigia não conseguiu reiniciar a escuta: " + e.getMessage());
            }
        }
        agendar(ctx, INTERVALO);
    }
}
