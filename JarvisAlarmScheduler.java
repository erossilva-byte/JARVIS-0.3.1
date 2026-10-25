package com.jarvis.nova;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;

import org.json.JSONObject;

import java.util.Map;

/** Persiste alarmes/timers e permite reconstruí-los após o Android reiniciar. */
public final class JarvisAlarmScheduler {
    private static final String PREFS = "jarvis_agendamentos";
    private static final String PREFIXO = "item_";

    private JarvisAlarmScheduler() { }

    private static int flagsPi() {
        return PendingIntent.FLAG_UPDATE_CURRENT
            | (Build.VERSION.SDK_INT >= 23 ? PendingIntent.FLAG_IMMUTABLE : 0);
    }

    public static void agendar(Context ctx, int id, long quando,
                               String titulo, String texto, String fala, boolean alarme) throws Exception {
        JSONObject registro = new JSONObject();
        registro.put("id", id);
        registro.put("quando", quando);
        registro.put("titulo", titulo == null ? "Jarvis" : titulo);
        registro.put("texto", texto == null ? "" : texto);
        registro.put("fala", fala == null ? "" : fala);
        registro.put("alarme", alarme);
        String chave = PREFIXO + id;
        // Grave antes de programar para reduzir a janela de perda em caso de encerramento do processo.
        preferencias(ctx).edit().putString(chave, registro.toString()).commit();
        try {
            programarRegistro(ctx, registro);
        } catch (Exception e) {
            preferencias(ctx).edit().remove(chave).apply();
            throw e;
        }
    }

    public static void cancelar(Context ctx, int id) {
        try {
            AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
            Intent it = new Intent(ctx, JarvisAlarmReceiver.class);
            PendingIntent pi = PendingIntent.getBroadcast(ctx, id, it, flagsPi());
            if (am != null) am.cancel(pi);
            pi.cancel();
        } catch (Exception ignored) { }
        preferencias(ctx).edit().remove(PREFIXO + id).apply();
    }

    static void concluir(Context ctx, int id) {
        preferencias(ctx).edit().remove(PREFIXO + id).apply();
    }

    public static void restaurar(Context ctx) {
        SharedPreferences sp = preferencias(ctx);
        // setAlarmClock() NÃO exige SCHEDULE_EXACT_ALARM (o Android o trata como alarme do
        // usuário, igual ao despertador). A checagem de canScheduleExactAlarms() aqui
        // abortava a restauração no Android 12+ e os lembretes simplesmente não voltavam
        // depois de reiniciar o aparelho — mesmo com o agendamento funcionando.
        long agora = System.currentTimeMillis();
        for (Map.Entry<String, ?> entry : sp.getAll().entrySet()) {
            if (!entry.getKey().startsWith(PREFIXO) || !(entry.getValue() instanceof String)) continue;
            final JSONObject registro;
            try {
                registro = new JSONObject((String) entry.getValue());
            } catch (Exception e) {
                sp.edit().remove(entry.getKey()).apply();
                continue; // remove somente registros corrompidos
            }
            long quando = registro.optLong("quando", 0L);
            int id = registro.optInt("id", -1);
            if (id < 0 || quando <= agora) {
                sp.edit().remove(entry.getKey()).apply();
                continue; // não dispara alarmes antigos acumulados enquanto o telefone estava desligado
            }
            try {
                programarRegistro(ctx, registro);
            } catch (Exception e) {
                // Não apaga o lembrete: pode ser uma permissão revogada ou uma falha temporária do sistema.
            }
        }
    }

    private static SharedPreferences preferencias(Context ctx) {
        return ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    private static void programarRegistro(Context ctx, JSONObject r) throws Exception {
        int id = r.getInt("id");
        long quando = r.getLong("quando");
        Intent it = new Intent(ctx, JarvisAlarmReceiver.class);
        it.putExtra("id", id);
        it.putExtra("titulo", r.optString("titulo", "Jarvis"));
        it.putExtra("texto", r.optString("texto", ""));
        it.putExtra("fala", r.optString("fala", ""));
        it.putExtra("alarme", r.optBoolean("alarme", false));
        PendingIntent pi = PendingIntent.getBroadcast(ctx, id, it, flagsPi());

        Intent abrir = new Intent(ctx, MainActivity.class);
        abrir.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        PendingIntent mostrar = PendingIntent.getActivity(ctx, id, abrir, flagsPi());
        AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        if (am == null) throw new IllegalStateException("AlarmManager indisponível");
        am.setAlarmClock(new AlarmManager.AlarmClockInfo(quando, mostrar), pi);
    }
}
