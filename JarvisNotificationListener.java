package com.jarvis.nova;

import android.app.Notification;
import android.app.RemoteInput;
import android.app.PendingIntent;
import android.content.Intent;
import android.os.Bundle;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.text.TextUtils;
import android.speech.tts.TextToSpeech;
import java.util.Locale;
import org.json.JSONArray;
import org.json.JSONObject;
import java.util.ArrayList;
import java.util.List;
import java.util.Collections;

/**
 * Listener opcional: só recebe notificações após o usuário conceder acesso especial
 * nas configurações do Android. Guarda no máximo dez resumos e apaga-os quando lidos.
 */
public class JarvisNotificationListener extends NotificationListenerService {
    private TextToSpeech tts;
    private volatile boolean ttsPronto = false;
    private static final List<StatusBarNotification> RECENTES = Collections.synchronizedList(new ArrayList<>());
    @Override public void onCreate() {
        super.onCreate();
        tts = new TextToSpeech(this, status -> {
            if (status == TextToSpeech.SUCCESS && tts != null) {
                int idioma = tts.setLanguage(new Locale("pt", "BR"));
                ttsPronto = idioma != TextToSpeech.LANG_MISSING_DATA
                    && idioma != TextToSpeech.LANG_NOT_SUPPORTED;
            } else {
                ttsPronto = false;
            }
        });
    }
    @Override public void onNotificationPosted(StatusBarNotification sbn) {
        if (sbn == null || getPackageName().equals(sbn.getPackageName())) return;
        synchronized (RECENTES) {
            for (int i = RECENTES.size() - 1; i >= 0; i--) {
                if (RECENTES.get(i).getKey().equals(sbn.getKey())) RECENTES.remove(i);
            }
            RECENTES.add(sbn);
            while (RECENTES.size() > 20) RECENTES.remove(0);
        }
        Notification n = sbn.getNotification();
        if (n == null || n.extras == null) return;
        Bundle b = n.extras;
        CharSequence title = b.getCharSequence(Notification.EXTRA_TITLE);
        // Anúncio de chamada é opt-in e só usa notificações explicitamente categorizadas como chamada.
        try {
            boolean anunciar = getSharedPreferences("jarvis_notificacoes", Context.MODE_PRIVATE).getBoolean("anunciar_chamadas", false);
            if (anunciar && Notification.CATEGORY_CALL.equals(n.category) && title != null && !title.toString().trim().isEmpty() && tts != null && ttsPronto) {
                String fala = "Chamada recebida de " + title.toString().trim();
                if (android.os.Build.VERSION.SDK_INT >= 21) tts.speak(fala, TextToSpeech.QUEUE_FLUSH, null, "jarvis-call-" + sbn.getId());
                else tts.speak(fala, TextToSpeech.QUEUE_FLUSH, null);
            }
        } catch (Exception ignored) { }

        CharSequence text = b.getCharSequence(Notification.EXTRA_BIG_TEXT);
        if (TextUtils.isEmpty(text)) text = b.getCharSequence(Notification.EXTRA_TEXT);
        if (TextUtils.isEmpty(text)) return;
        try {
            String app = sbn.getPackageName();
            try {
                app = getPackageManager().getApplicationLabel(getPackageManager().getApplicationInfo(app, 0)).toString();
            } catch (Exception ignored) { }
            JSONObject item = new JSONObject();
            item.put("app", app);
            item.put("titulo", title == null ? "" : title.toString().trim());
            item.put("texto", text.toString().trim().substring(0, Math.min(500, text.toString().trim().length())));
            SharedPreferences sp = getSharedPreferences("jarvis_notificacoes", Context.MODE_PRIVATE);
            JSONArray old;
            try { old = new JSONArray(sp.getString("itens", "[]")); } catch (Exception e) { old = new JSONArray(); }
            List<JSONObject> keep = new ArrayList<>();
            for (int i = Math.max(0, old.length() - 9); i < old.length(); i++) {
                JSONObject prev = old.optJSONObject(i);
                if (prev != null) keep.add(prev);
            }
            keep.add(item);
            JSONArray out = new JSONArray();
            for (JSONObject x : keep) out.put(x);
            sp.edit().putString("itens", out.toString()).apply();
        } catch (Exception ignored) { }
    }
    public static String responderUltimaNotificacao(Context context, String texto) throws Exception {
        synchronized (RECENTES) {
            for (int i = RECENTES.size() - 1; i >= 0; i--) {
                StatusBarNotification sbn = RECENTES.get(i);
                Notification n = sbn.getNotification();
                if (n == null || n.actions == null) continue;
                for (Notification.Action action : n.actions) {
                    RemoteInput[] inputs = action.getRemoteInputs();
                    PendingIntent pi = action.actionIntent;
                    if (inputs == null || inputs.length == 0 || pi == null) continue;
                    Intent fillIn = new Intent();
                    Bundle values = new Bundle();
                    values.putCharSequence(inputs[0].getResultKey(), texto);
                    RemoteInput.addResultsToIntent(inputs, fillIn, values);
                    pi.send(context, 0, fillIn);
                    CharSequence title = n.extras == null ? null : n.extras.getCharSequence(Notification.EXTRA_TITLE);
                    return title == null ? "Resposta enviada pela ação de resposta rápida disponível." : "Resposta enviada para a notificação de " + title.toString() + ".";
                }
            }
        }
        throw new Exception("Nenhuma notificação ativa oferece resposta rápida. Abra o aplicativo e responda por lá.");
    }

    @Override public void onDestroy() {
        if (tts != null) { try { tts.stop(); tts.shutdown(); } catch (Exception ignored) { } tts = null; }
        super.onDestroy();
    }
}
