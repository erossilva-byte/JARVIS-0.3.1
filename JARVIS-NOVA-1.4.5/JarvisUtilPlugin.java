package com.jarvis.nova;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.Manifest;
import android.content.Context;
import android.database.Cursor;
import android.provider.ContactsContract;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.ComponentName;
import android.media.AudioManager;
import android.media.session.MediaSessionManager;
import android.media.session.MediaController;
import android.view.KeyEvent;
import android.net.Uri;
import android.provider.CalendarContract;
import android.provider.Settings;
import android.os.BatteryManager;
import android.net.ConnectivityManager;
import android.net.NetworkCapabilities;
import android.os.PowerManager;
import java.util.Date;
import java.text.SimpleDateFormat;
import java.util.Locale;
import android.os.Build;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;

import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.PermissionState;
import com.getcapacitor.annotation.Permission;
import com.getcapacitor.annotation.PermissionCallback;
import com.getcapacitor.annotation.CapacitorPlugin;

import java.nio.charset.StandardCharsets;
import java.security.KeyStore;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/**
 * 1) Cofre de chaves: guarda as chaves de API cifradas (AES-GCM) com uma chave que fica
 *    no Android Keystore e nunca sai do aparelho.
 * 2) Lembretes, alarmes e timers: agenda com AlarmManager.setAlarmClock, que dispara no
 *    horário certo mesmo com o aparelho em repouso. Quem fala e notifica é o JarvisAlarmReceiver.
 */
@CapacitorPlugin(name = "JarvisUtil", permissions = { @Permission(strings = { Manifest.permission.READ_CONTACTS }, alias = "contacts") })
public class JarvisUtilPlugin extends Plugin {

    private static final String KS = "AndroidKeyStore";
    private static final String ALIAS = "jarvis_chaves";
    private static final String PREFS = "jarvis_seguro";

    /* ---------- Cofre de chaves ---------- */

    private SecretKey chaveCofre() throws Exception {
        if (Build.VERSION.SDK_INT < 23) {
            throw new Exception("Android antigo demais para o cofre de chaves");
        }
        KeyStore ks = KeyStore.getInstance(KS);
        ks.load(null);
        if (!ks.containsAlias(ALIAS)) {
            KeyGenerator kg = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KS);
            kg.init(new KeyGenParameterSpec.Builder(
                    ALIAS, KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build());
            return kg.generateKey();
        }
        return (SecretKey) ks.getKey(ALIAS, null);
    }

    @PluginMethod
    public void guardarSeguro(PluginCall call) {
        try {
            String nome = call.getString("nome");
            String valor = call.getString("valor", "");
            if (nome == null || nome.isEmpty()) {
                call.reject("nome ausente");
                return;
            }
            SharedPreferences sp = getContext().getSharedPreferences(PREFS, Context.MODE_PRIVATE);
            if (valor == null || valor.isEmpty()) {
                sp.edit().remove(nome).apply();
                call.resolve();
                return;
            }
            Cipher c = Cipher.getInstance("AES/GCM/NoPadding");
            c.init(Cipher.ENCRYPT_MODE, chaveCofre());
            byte[] iv = c.getIV();
            byte[] ct = c.doFinal(valor.getBytes(StandardCharsets.UTF_8));
            String s = Base64.encodeToString(iv, Base64.NO_WRAP) + ":" + Base64.encodeToString(ct, Base64.NO_WRAP);
            sp.edit().putString(nome, s).apply();
            call.resolve();
        } catch (Exception e) {
            call.reject("Falha ao proteger a chave: " + e.getMessage());
        }
    }

    @PluginMethod
    public void lerSeguro(PluginCall call) {
        try {
            String nome = call.getString("nome");
            JSObject o = new JSObject();
            if (nome == null || nome.isEmpty()) {
                o.put("valor", "");
                call.resolve(o);
                return;
            }
            SharedPreferences sp = getContext().getSharedPreferences(PREFS, Context.MODE_PRIVATE);
            String s = sp.getString(nome, null);
            if (s == null || !s.contains(":")) {
                o.put("valor", "");
                call.resolve(o);
                return;
            }
            String[] p = s.split(":");
            byte[] iv = Base64.decode(p[0], Base64.NO_WRAP);
            byte[] ct = Base64.decode(p[1], Base64.NO_WRAP);
            Cipher c = Cipher.getInstance("AES/GCM/NoPadding");
            c.init(Cipher.DECRYPT_MODE, chaveCofre(), new GCMParameterSpec(128, iv));
            o.put("valor", new String(c.doFinal(ct), StandardCharsets.UTF_8));
            call.resolve(o);
        } catch (Exception e) {
            call.reject("Falha ao ler a chave: " + e.getMessage());
        }
    }

    /* ---------- Contatos do aparelho: somente após consentimento explícito ---------- */

    @PluginMethod
    public void listarContatos(PluginCall call) {
        if (getPermissionState("contacts") != PermissionState.GRANTED) {
            requestPermissionForAlias("contacts", call, "aposPermissaoContatos");
            return;
        }
        lerContatos(call);
    }

    @PermissionCallback
    private void aposPermissaoContatos(PluginCall call) {
        if (getPermissionState("contacts") == PermissionState.GRANTED) lerContatos(call);
        else call.reject("Acesso aos contatos negado. Você pode cadastrar contatos manualmente.");
    }

    private void lerContatos(PluginCall call) {
        Cursor cursor = null;
        try {
            JSArray lista = new JSArray();
            cursor = getContext().getContentResolver().query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                new String[] { ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                               ContactsContract.CommonDataKinds.Phone.NUMBER },
                null, null, ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " ASC");
            if (cursor != null) {
                int nomeCol = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME);
                int numCol = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER);
                int limite = 0;
                while (cursor.moveToNext() && limite < 500) {
                    String nome = nomeCol >= 0 ? cursor.getString(nomeCol) : "";
                    String numero = numCol >= 0 ? cursor.getString(numCol) : "";
                    if (nome == null || nome.trim().isEmpty() || numero == null) continue;
                    JSObject item = new JSObject();
                    item.put("nome", nome.trim());
                    item.put("numero", numero.trim());
                    lista.put(item);
                    limite++;
                }
            }
            JSObject resultado = new JSObject();
            resultado.put("contatos", lista);
            resultado.put("limitado", lista.length() >= 500);
            call.resolve(resultado);
        } catch (Exception e) {
            call.reject("Não foi possível ler os contatos: " + (e.getMessage() == null ? "erro desconhecido" : e.getMessage()));
        } finally {
            if (cursor != null) cursor.close();
        }
    }

    /* ---------- Ações locais do Android ---------- */

    @PluginMethod
    public void abrirAplicativo(PluginCall call) {
        try {
            String app = call.getString("app", "").toLowerCase(Locale.ROOT).trim();
            if ("jarvis".equals(app) || "jarvis nova".equals(app)) {
                Intent own = getContext().getPackageManager().getLaunchIntentForPackage(getContext().getPackageName());
                if (own == null) throw new Exception("Atalho do J.A.R.V.I.S. não encontrado.");
                own.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT);
                getContext().startActivity(own); call.resolve(); return;
            }
            String pkg;
            switch (app) {
                case "whatsapp": case "zap": pkg = "com.whatsapp"; break;
                case "youtube": pkg = "com.google.android.youtube"; break;
                case "spotify": pkg = "com.spotify.music"; break;
                case "instagram": pkg = "com.instagram.android"; break;
                case "maps": case "mapas": pkg = "com.google.android.apps.maps"; break;
                case "gmail": pkg = "com.google.android.gm"; break;
                case "chrome": case "navegador": pkg = "com.android.chrome"; break;
                case "calculadora": pkg = "com.google.android.calculator"; break;
                case "telegram": pkg = "org.telegram.messenger"; break;
                case "tiktok": pkg = "com.zhiliaoapp.musically"; break;
                case "facebook": pkg = "com.facebook.katana"; break;
                case "discord": pkg = "com.discord"; break;
                case "netflix": pkg = "com.netflix.mediaclient"; break;
                case "camera": case "câmera": case "camera do celular":
                    Intent camera = new Intent("android.media.action.IMAGE_CAPTURE");
                    camera.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    if (camera.resolveActivity(getContext().getPackageManager()) == null) throw new Exception("Nenhum app de câmera compatível foi encontrado.");
                    getContext().startActivity(camera); call.resolve(); return;
                default: throw new Exception("Aplicativo não possui um atalho nativo cadastrado: " + app);
            }
            Intent i = getContext().getPackageManager().getLaunchIntentForPackage(pkg);
            if (i == null) throw new Exception("O aplicativo não está instalado ou não possui atalho disponível.");
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
            getContext().startActivity(i);
            call.resolve();
        } catch (Exception e) { call.reject(e.getMessage() == null ? "Não consegui abrir o aplicativo." : e.getMessage()); }
    }

    @PluginMethod
    public void irInicio(PluginCall call) {
        try {
            Intent i = new Intent(Intent.ACTION_MAIN);
            i.addCategory(Intent.CATEGORY_HOME);
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            getContext().startActivity(i); call.resolve();
        } catch (Exception e) { call.reject("Não consegui voltar à tela inicial: " + e.getMessage()); }
    }

    @PluginMethod
    public void comporSms(PluginCall call) {
        try {
            String numero = call.getString("numero", "").trim();
            String texto = call.getString("texto", "").trim();
            if (numero.isEmpty() || texto.isEmpty()) throw new Exception("Número e mensagem são obrigatórios.");
            Intent i = new Intent(Intent.ACTION_SENDTO, Uri.fromParts("smsto", numero, null));
            i.putExtra("sms_body", texto);
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            getContext().startActivity(i); call.resolve();
        } catch (Exception e) { call.reject("Não consegui abrir o SMS: " + e.getMessage()); }
    }

    @PluginMethod
    public void controleMidia(PluginCall call) {
        try {
            String comando = call.getString("comando", "pausar").toLowerCase(Locale.ROOT);
            int key;
            if (comando.equals("continuar") || comando.equals("play") || comando.equals("retomar")) key = KeyEvent.KEYCODE_MEDIA_PLAY;
            else if (comando.equals("proxima") || comando.equals("próxima")) key = KeyEvent.KEYCODE_MEDIA_NEXT;
            else if (comando.equals("anterior")) key = KeyEvent.KEYCODE_MEDIA_PREVIOUS;
            else if (comando.equals("alternar")) key = KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE;
            else key = KeyEvent.KEYCODE_MEDIA_PAUSE;
            AudioManager am = (AudioManager) getContext().getSystemService(Context.AUDIO_SERVICE);
            if (am == null) throw new Exception("Controle de áudio indisponível.");
            long now = System.currentTimeMillis();
            am.dispatchMediaKeyEvent(new KeyEvent(now, now, KeyEvent.ACTION_DOWN, key, 0));
            am.dispatchMediaKeyEvent(new KeyEvent(now, now, KeyEvent.ACTION_UP, key, 0));
            call.resolve();
        } catch (Exception e) { call.reject("O controle de mídia falhou: " + e.getMessage()); }
    }

    @PluginMethod
    public void ajustarVolume(PluginCall call) {
        try {
            AudioManager am = (AudioManager) getContext().getSystemService(Context.AUDIO_SERVICE);
            if (am == null) throw new Exception("Controle de volume indisponível.");
            String dir = call.getString("direcao", "aumentar");
            int flags = AudioManager.FLAG_SHOW_UI;
            if ("diminuir".equals(dir)) am.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_LOWER, flags);
            else if ("silenciar".equals(dir)) am.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_MUTE, flags);
            else am.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_RAISE, flags);
            call.resolve();
        } catch (Exception e) { call.reject("Não consegui ajustar o volume: " + e.getMessage()); }
    }

    @PluginMethod
    public void abrirAcessoNotificacoes(PluginCall call) {
        try {
            Intent i = new Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS);
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            getContext().startActivity(i); call.resolve();
        } catch (Exception e) { call.reject("Não consegui abrir as configurações de notificações: " + e.getMessage()); }
    }

    @PluginMethod
    public void responderUltimaNotificacao(PluginCall call) {
        try {
            String texto = call.getString("texto", "").trim();
            if (texto.isEmpty()) throw new Exception("O texto da resposta está vazio.");
            String info = JarvisNotificationListener.responderUltimaNotificacao(getContext(), texto);
            JSObject o = new JSObject(); o.put("info", info); call.resolve(o);
        } catch (Exception e) { call.reject(e.getMessage() == null ? "Não consegui responder à notificação." : e.getMessage()); }
    }

    @PluginMethod
    public void definirAnuncioChamadas(PluginCall call) {
        boolean ativo = Boolean.TRUE.equals(call.getBoolean("ativo", false));
        getContext().getSharedPreferences("jarvis_notificacoes", Context.MODE_PRIVATE)
            .edit().putBoolean("anunciar_chamadas", ativo).apply();
        call.resolve();
    }

    @PluginMethod
    public void limparNotificacoes(PluginCall call) {
        getContext().getSharedPreferences("jarvis_notificacoes", Context.MODE_PRIVATE).edit()
            .remove("itens").putBoolean("anunciar_chamadas", false).apply();
        call.resolve();
    }

    @PluginMethod
    public void lerNotificacoes(PluginCall call) {
        try {
            SharedPreferences sp = getContext().getSharedPreferences("jarvis_notificacoes", Context.MODE_PRIVATE);
            String raw = sp.getString("itens", "[]");
            sp.edit().remove("itens").apply();
            JSObject o = new JSObject();
            try { o.put("itens", new org.json.JSONArray(raw)); }
            catch (Exception ignored) { o.put("itens", new org.json.JSONArray()); }
            call.resolve(o);
        } catch (Exception e) { call.reject("Não consegui ler notificações: " + e.getMessage()); }
    }

    @PluginMethod
    public void statusDispositivo(PluginCall call) {
        try {
            Intent bat = getContext().registerReceiver(null, new android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED));
            int level = -1, scale = 100, status = -1, temperaturaDecimos = -1;
            if (bat != null) { level = bat.getIntExtra(BatteryManager.EXTRA_LEVEL, -1); scale = bat.getIntExtra(BatteryManager.EXTRA_SCALE, 100); status = bat.getIntExtra(BatteryManager.EXTRA_STATUS, -1); temperaturaDecimos = bat.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1); }
            JSObject o = new JSObject();
            o.put("bateria", level >= 0 && scale > 0 ? Math.round(level * 100f / scale) : -1);
            o.put("carregando", status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL);
            o.put("temperaturaC", temperaturaDecimos >= 0 ? temperaturaDecimos / 10.0 : -1);
            try {
                android.os.StatFs fs = new android.os.StatFs(android.os.Environment.getDataDirectory().getAbsolutePath());
                long total = fs.getTotalBytes(), livre = fs.getAvailableBytes();
                o.put("armazenamentoTotal", total); o.put("armazenamentoLivre", livre);
                o.put("armazenamentoUsadoPct", total > 0 ? Math.round((total-livre) * 100.0 / total) : -1);
            } catch (Exception ignored) { o.put("armazenamentoTotal", -1); o.put("armazenamentoLivre", -1); o.put("armazenamentoUsadoPct", -1); }
            try {
                android.app.ActivityManager am = (android.app.ActivityManager) getContext().getSystemService(Context.ACTIVITY_SERVICE);
                android.app.ActivityManager.MemoryInfo mi = new android.app.ActivityManager.MemoryInfo();
                if (am != null) { am.getMemoryInfo(mi); o.put("ramTotal", mi.totalMem); o.put("ramLivre", mi.availMem); o.put("ramBaixa", mi.lowMemory); }
            } catch (Exception ignored) { o.put("ramTotal", -1); o.put("ramLivre", -1); o.put("ramBaixa", false); }
            o.put("fabricante", Build.MANUFACTURER == null ? "Android" : Build.MANUFACTURER);
            o.put("modelo", Build.MODEL == null ? "dispositivo Android" : Build.MODEL);
            o.put("android", Build.VERSION.RELEASE == null ? "Android" : Build.VERSION.RELEASE);
            String conexao = "sem conexão";
            ConnectivityManager cm = (ConnectivityManager) getContext().getSystemService(Context.CONNECTIVITY_SERVICE);
            if (cm != null && android.os.Build.VERSION.SDK_INT >= 23) {
                NetworkCapabilities nc = cm.getNetworkCapabilities(cm.getActiveNetwork());
                if (nc != null) conexao = nc.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ? "Wi-Fi" : nc.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ? "dados móveis" : nc.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) ? "Ethernet" : "conectado";
            }
            o.put("conexao", conexao); call.resolve(o);
        } catch (Exception e) { call.reject("Não consegui consultar o estado do aparelho: " + e.getMessage()); }
    }


    @PluginMethod
    public void abrirConfiguracaoSistema(PluginCall call) {
        try {
            String alvo = call.getString("alvo", "geral");
            Intent i;
            if ("bateria".equals(alvo)) i = new Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS);
            else if ("armazenamento".equals(alvo)) i = new Intent(Settings.ACTION_INTERNAL_STORAGE_SETTINGS);
            else i = new Intent(Settings.ACTION_SETTINGS);
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            getContext().startActivity(i); call.resolve();
        } catch (Exception e) {
            try { Intent i = new Intent(Settings.ACTION_SETTINGS); i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK); getContext().startActivity(i); call.resolve(); }
            catch (Exception x) { call.reject("Não consegui abrir as configurações do Android: " + x.getMessage()); }
        }
    }

    @PluginMethod
    public void abrirAgenda(PluginCall call) {
        try {
            long quando = System.currentTimeMillis();
            Uri uri = Uri.parse("content://com.android.calendar/time/" + quando);
            Intent i = new Intent(Intent.ACTION_VIEW, uri);
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            getContext().startActivity(i);
            call.resolve();
        } catch (Exception e) { call.reject("Não consegui abrir a agenda: " + e.getMessage()); }
    }

    @PluginMethod
    public void criarEventoAgenda(PluginCall call) {
        try {
            String titulo = call.getString("titulo", "Evento do Jarvis");
            String descricao = call.getString("descricao", "");
            String inicioIso = call.getString("inicio", "");
            long inicio = System.currentTimeMillis() + 3600000L;
            if (!inicioIso.isEmpty()) {
                try { inicio = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSX", Locale.US).parse(inicioIso).getTime(); }
                catch (Exception e) { try { inicio = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssX", Locale.US).parse(inicioIso).getTime(); } catch (Exception ignored) {} }
            }
            int mins = Math.max(5, Math.min(1440, call.getInt("duracao_minutos", 60)));
            Intent i = new Intent(Intent.ACTION_INSERT, CalendarContract.Events.CONTENT_URI);
            i.putExtra(CalendarContract.Events.TITLE, titulo);
            i.putExtra(CalendarContract.Events.DESCRIPTION, descricao);
            i.putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, inicio);
            i.putExtra(CalendarContract.EXTRA_EVENT_END_TIME, inicio + mins * 60000L);
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            getContext().startActivity(i);
            JSObject o = new JSObject(); o.put("info", "Abri o calendário para revisar e salvar o evento."); call.resolve(o);
        } catch (Exception e) { call.reject("Não consegui abrir o calendário: " + e.getMessage()); }
    }

    /* ---------- Lembretes, alarmes e timers ---------- */

    @PluginMethod
    public void restaurarAgendamentos(PluginCall call) {
        try {
            JarvisAlarmScheduler.restaurar(getContext().getApplicationContext());
            call.resolve();
        } catch (Exception e) {
            call.reject("Não consegui restaurar lembretes pendentes: " + e.getMessage());
        }
    }

    @PluginMethod
    public void agendar(PluginCall call) {
        try {
            Integer seg = call.getInt("segundos");
            Integer id = call.getInt("id");
            if (seg == null || id == null || id < 0) {
                call.reject("Parâmetros de agendamento ausentes ou inválidos.");
                return;
            }
            // Limite defensivo: evita overflow ou um prazo acidentalmente enorme.
            long segundos = Math.max(1L, Math.min(seg.longValue(), 31536000L));
            long quando = System.currentTimeMillis() + segundos * 1000L;
            Context ctx = getContext().getApplicationContext();
            if (Build.VERSION.SDK_INT >= 31) {
                AlarmManager alarmManager = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
                if (alarmManager != null && !alarmManager.canScheduleExactAlarms()) {
                    try {
                        Intent permissao = new Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                            Uri.parse("package:" + ctx.getPackageName()));
                        permissao.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                        getContext().startActivity(permissao);
                    } catch (Exception ignored) { }
                    call.reject("Permita alarmes e lembretes exatos nas configurações do Android e tente novamente.");
                    return;
                }
            }
            JarvisAlarmScheduler.agendar(ctx, id.intValue(), quando,
                call.getString("titulo", "Jarvis"),
                call.getString("texto", ""),
                call.getString("fala", ""),
                Boolean.TRUE.equals(call.getBoolean("alarme", false)));
            call.resolve();
        } catch (Exception e) {
            call.reject("Não consegui agendar: " + e.getMessage());
        }
    }

    @PluginMethod
    public void cancelar(PluginCall call) {
        try {
            Integer id = call.getInt("id");
            if (id == null || id < 0) {
                call.reject("ID ausente ou inválido.");
                return;
            }
            JarvisAlarmScheduler.cancelar(getContext().getApplicationContext(), id.intValue());
            call.resolve();
        } catch (Exception e) {
            call.reject("Não consegui cancelar: " + e.getMessage());
        }
    }

}
