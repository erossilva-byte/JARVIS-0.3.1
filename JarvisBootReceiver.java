package com.jarvis.nova;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/**
 * Restaura os lembretes futuros e, se o usuário deixou a palavra de ativação ligada,
 * recoloca a escuta no ar depois do reinício.
 *
 * O serviço de microfone não pode ser iniciado direto do BOOT_COMPLETED no Android 14+.
 * Por isso o vigia é agendado para alguns segundos depois: o alarme concede a isenção
 * temporária necessária para iniciar um serviço em primeiro plano do tipo microfone.
 */
public class JarvisBootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null) return;
        String action = intent.getAction();
        if (Intent.ACTION_BOOT_COMPLETED.equals(action)
                || Intent.ACTION_MY_PACKAGE_REPLACED.equals(action)
                || Intent.ACTION_TIME_CHANGED.equals(action)
                || Intent.ACTION_TIMEZONE_CHANGED.equals(action)) {
            Context ctx = context.getApplicationContext();
            JarvisAlarmScheduler.restaurar(ctx);
            if (JarvisPrefs.desejaOuvir(ctx)) JarvisWatchdog.agendar(ctx, 20000L);
            else JarvisWatchdog.cancelar(ctx);
        }
    }
}
