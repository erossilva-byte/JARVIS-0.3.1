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
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraManager;
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
@CapacitorPlugin(name = "JarvisUtil", permissions = {
    @Permission(strings = { Manifest.permission.READ_CONTACTS }, alias = "contacts"),
    @Permission(strings = { Manifest.permission.CAMERA }, alias = "camera")
})
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

    /** Chave de app -> pacote Android; null quando não há atalho nativo cadastrado. */
    private String pacoteDe(String app) {
        if (app == null) return null;
        switch (app) {
            case "whatsapp": case "zap": return "com.whatsapp";
            case "youtube": return "com.google.android.youtube";
            case "spotify": return "com.spotify.music";
            case "instagram": return "com.instagram.android";
            case "maps": case "mapas": return "com.google.android.apps.maps";
            case "gmail": return "com.google.android.gm";
            case "chrome": case "navegador": return "com.android.chrome";
            case "calculadora": return primeiroInstalado("com.google.android.calculator", "com.android.calculator2", "com.sec.android.app.calculator");
            case "telegram": return "org.telegram.messenger";
            case "tiktok": return "com.zhiliaoapp.musically";
            case "facebook": return "com.facebook.katana";
            case "discord": return "com.discord";
            case "netflix": return "com.netflix.mediaclient";
            case "configuracoes": case "ajustes": return "com.android.settings";
            case "galeria": case "fotos": return primeiroInstalado("com.google.android.apps.photos", "com.miui.gallery", "com.sec.android.gallery3d", "com.android.gallery3d");
            case "play": case "loja": return "com.android.vending";
            case "relogio": case "despertador": return primeiroInstalado("com.google.android.deskclock", "com.sec.android.app.clockpackage", "com.android.deskclock");
            default: return null;
        }
    }

    /** Primeiro pacote instalado da lista (varia por fabricante); se nenhum, o primeiro candidato. */
    private String primeiroInstalado(String... pacotes) {
        try {
            PackageManager pm = getContext().getPackageManager();
            for (String p : pacotes) {
                if (pm.getLaunchIntentForPackage(p) != null) return p;
            }
        } catch (Exception ignored) { }
        return pacotes[0];
    }

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
            if ("camera".equals(app) || "câmera".equals(app) || "camera do celular".equals(app)) {
                Intent camera = new Intent("android.media.action.IMAGE_CAPTURE");
                camera.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                if (camera.resolveActivity(getContext().getPackageManager()) == null) throw new Exception("Nenhum app de câmera compatível foi encontrado.");
                getContext().startActivity(camera); call.resolve(); return;
            }
            String pkg = pacoteDe(app);
            if (pkg == null) throw new Exception("Aplicativo não possui um atalho nativo cadastrado: " + app);
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

    /* ---------- Mídia em reprodução ---------- */

    /** Nome amigável do app que está tocando (usado nas respostas por voz). */
    private String nomeDoPacote(String pkg) {
        if (pkg == null) return "";
        switch (pkg) {
            case "com.spotify.music": return "Spotify";
            case "com.google.android.youtube": return "YouTube";
            case "com.google.android.apps.youtube.music": return "YouTube Music";
            case "com.google.android.music": case "com.google.android.apps.youtube.music.playback": return "Google Play Música";
            case "com.amazon.mp3": return "Amazon Music";
            case "com.deezer.android.app": return "Deezer";
            case "com.soundcloud.android": return "SoundCloud";
            case "tv.danmaku.bili": return "Bilibili";
            default: return pkg;
        }
    }

    /**
     * Sessão de mídia ativa (Spotify, YouTube Music, etc.). Lemos pelo acesso às
     * notificações, que o app já usa para anunciar chamadas: sem essa permissão o
     * Android barra a consulta e caímos no envio de teclas de mídia.
     */
    private MediaController controladorAtivo() {
        try {
            MediaSessionManager msm =
                (MediaSessionManager) getContext().getSystemService(Context.MEDIA_SESSION_SERVICE);
            if (msm == null) return null;
            ComponentName ouvinte = new ComponentName(getContext(), JarvisNotificationListener.class);
            MediaController primeiro = null;
            for (MediaController c : msm.getActiveSessions(ouvinte)) {
                if (c == null || c.getPlaybackState() == null) continue;
                if (primeiro == null) primeiro = c;
                if (c.getPlaybackState().getState() == android.media.session.PlaybackState.STATE_PLAYING) return c;
            }
            return primeiro;
        } catch (Exception e) {
            return null;
        }
    }

    private boolean tocandoAgora(MediaController c) {
        try {
            return c.getPlaybackState() != null
                && c.getPlaybackState().getState() == android.media.session.PlaybackState.STATE_PLAYING;
        } catch (Exception e) { return false; }
    }

    /** Fallback antigo (teclas de mídia): funciona em aparelhos sem acesso às notificações. */
    private void enviarTeclaMidia(int key) throws Exception {
        AudioManager am = (AudioManager) getContext().getSystemService(Context.AUDIO_SERVICE);
        if (am == null) throw new Exception("Controle de áudio indisponível.");
        long now = System.currentTimeMillis();
        am.dispatchMediaKeyEvent(new KeyEvent(now, now, KeyEvent.ACTION_DOWN, key, 0));
        am.dispatchMediaKeyEvent(new KeyEvent(now, now, KeyEvent.ACTION_UP, key, 0));
    }

    @PluginMethod
    public void controleMidia(PluginCall call) {
        try {
            String comando = call.getString("comando", "pausar").toLowerCase(Locale.ROOT).trim();
            MediaController c = controladorAtivo();
            JSObject o = new JSObject();
            if (c != null) {
                MediaController.TransportControls t = c.getTransportControls();
                boolean tocando = tocandoAgora(c);
                switch (comando) {
                    case "continuar": case "play": case "retomar": case "tocar":
                        t.play(); break;
                    case "proxima": case "próxima": case "avancar": case "avançar": case "pular":
                        t.skipToNext(); break;
                    case "anterior": case "voltar": case "volta":
                        t.skipToPrevious(); break;
                    case "alternar": case "playpause": case "pausar_continuar":
                        if (tocando) t.pause(); else t.play(); break;
                    case "parar": case "stop":
                        t.stop(); break;
                    default:
                        t.pause(); break;
                }
                o.put("app", nomeDoPacote(c.getPackageName()));
                o.put("pacote", c.getPackageName());
                o.put("metodo", "sessao");
                o.put("tocava", tocando);
                o.put("tocando", tocandoAgora(c));
                call.resolve(o);
                return;
            }
            int key;
            if (comando.equals("continuar") || comando.equals("play") || comando.equals("retomar")) key = KeyEvent.KEYCODE_MEDIA_PLAY;
            else if (comando.equals("proxima") || comando.equals("próxima")) key = KeyEvent.KEYCODE_MEDIA_NEXT;
            else if (comando.equals("anterior")) key = KeyEvent.KEYCODE_MEDIA_PREVIOUS;
            else if (comando.equals("alternar")) key = KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE;
            else key = KeyEvent.KEYCODE_MEDIA_PAUSE;
            enviarTeclaMidia(key);
            o.put("app", "");
            o.put("metodo", "teclas");
            call.resolve(o);
        } catch (Exception e) { call.reject("O controle de mídia falhou: " + e.getMessage()); }
    }

    /** O que está tocando agora (app, título e artista), para responder por voz. */
    @PluginMethod
    public void midiaAtual(PluginCall call) {
        JSObject o = new JSObject();
        MediaController c = controladorAtivo();
        if (c == null) {
            AudioManager am = (AudioManager) getContext().getSystemService(Context.AUDIO_SERVICE);
            o.put("ativo", am != null && am.isMusicActive());
            o.put("app", "");
            o.put("titulo", "");
            o.put("artista", "");
            o.put("tocando", am != null && am.isMusicActive());
            o.put("permitido", false);
            call.resolve(o);
            return;
        }
        String titulo = "", artista = "";
        try {
            android.media.MediaMetadata md = c.getMetadata();
            if (md != null) {
                CharSequence t = md.getText(android.media.MediaMetadata.METADATA_KEY_TITLE);
                CharSequence a = md.getText(android.media.MediaMetadata.METADATA_KEY_ARTIST);
                titulo = t == null ? "" : t.toString();
                artista = a == null ? "" : a.toString();
            }
        } catch (Exception ignored) { }
        o.put("ativo", true);
        o.put("app", nomeDoPacote(c.getPackageName()));
        o.put("pacote", c.getPackageName());
        o.put("titulo", titulo);
        o.put("artista", artista);
        o.put("tocando", tocandoAgora(c));
        o.put("permitido", true);
        call.resolve(o);
    }

    /**
     * Abre o Spotify já na busca (ou numa seção fixa). O app do Spotify não aceita
     * "toque esta faixa" vindo de fora: a busca mostra os resultados e o usuário toca
     * no primeiro. Sem Spotify instalado, cai para o player web.
     */
    @PluginMethod
    public void tocarNoSpotify(PluginCall call) {
        try {
            String busca = call.getString("busca", "");
            String tipo = call.getString("tipo", "");
            String uri;
            String t = tipo == null ? "" : tipo.toLowerCase(Locale.ROOT);
            if (busca != null && !busca.trim().isEmpty()) uri = "spotify:search:" + Uri.encode(busca.trim());
            else if ("curtidas".equals(t) || "favoritas".equals(t) || "biblioteca".equals(t)) uri = "spotify:collection";
            else if ("tocando".equals(t) || "tocando_agora".equals(t)) uri = "spotify:playing";
            else if ("radio".equals(t)) uri = "spotify:radio";
            else throw new Exception("Diga o que quer ouvir: “toca <música> no Spotify” ou “abre minhas curtidas”");

            JSObject o = new JSObject();
            try {
                Intent i = new Intent(Intent.ACTION_VIEW, Uri.parse(uri));
                i.setPackage("com.spotify.music");
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                getContext().startActivity(i);
                o.put("aberto", true);
                o.put("app", "Spotify");
            } catch (Exception semSpotify) {
                String web = busca != null && !busca.trim().isEmpty()
                    ? "https://open.spotify.com/search/" + Uri.encode(busca.trim())
                    : "https://open.spotify.com";
                Intent i = new Intent(Intent.ACTION_VIEW, Uri.parse(web));
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                getContext().startActivity(i);
                o.put("aberto", true);
                o.put("app", "Navegador");
                o.put("aviso", "O Spotify não está instalado; abri a busca no navegador.");
            }
            o.put("uri", uri);
            call.resolve(o);
        } catch (Exception e) { call.reject("Não consegui abrir o Spotify: " + (e.getMessage() == null ? "erro desconhecido" : e.getMessage())); }
    }

    @PluginMethod
    public void ajustarVolume(PluginCall call) {
        try {
            AudioManager am = (AudioManager) getContext().getSystemService(Context.AUDIO_SERVICE);
            if (am == null) throw new Exception("Controle de volume indisponível.");
            String dir = call.getString("direcao", "aumentar");
            String tipo = call.getString("tipo", "musica");
            String t = tipo == null ? "musica" : tipo.toLowerCase(Locale.ROOT);
            int stream;
            switch (t) {
                case "chamada": stream = AudioManager.STREAM_VOICE_CALL; break;
                case "notificacao": stream = AudioManager.STREAM_NOTIFICATION; break;
                case "alarme": stream = AudioManager.STREAM_ALARM; break;
                case "toque": stream = AudioManager.STREAM_RING; break;
                case "sistema": stream = AudioManager.STREAM_SYSTEM; break;
                default: stream = AudioManager.STREAM_MUSIC; break;
            }
            int flags = AudioManager.FLAG_SHOW_UI;
            Integer pct = call.getInt("percentual");
            if (pct != null) {
                int alvo = Math.round(Math.max(0, Math.min(100, pct)) / 100f * am.getStreamMaxVolume(stream));
                am.setStreamVolume(stream, alvo, flags);
            } else if ("diminuir".equals(dir)) am.adjustStreamVolume(stream, AudioManager.ADJUST_LOWER, flags);
            else if ("silenciar".equals(dir)) am.adjustStreamVolume(stream, AudioManager.ADJUST_MUTE, flags);
            else if ("definir".equals(dir)) am.setStreamVolume(stream, am.getStreamMaxVolume(stream) / 2, flags);
            else am.adjustStreamVolume(stream, AudioManager.ADJUST_RAISE, flags);
            JSObject o = new JSObject();
            o.put("nivel", am.getStreamVolume(stream));
            o.put("maximo", am.getStreamMaxVolume(stream));
            o.put("tipo", t);
            call.resolve(o);
        } catch (Exception e) { call.reject("Não consegui ajustar o volume: " + e.getMessage()); }
    }

    @PluginMethod
    public void lanterna(PluginCall call) {
        if (getPermissionState("camera") != PermissionState.GRANTED) {
            requestPermissionForAlias("camera", call, "aposPermissaoCamera");
            return;
        }
        aplicarLanterna(call.getString("estado", "alternar"), call);
    }

    @PermissionCallback
    private void aposPermissaoCamera(PluginCall call) {
        if (getPermissionState("camera") == PermissionState.GRANTED) {
            aplicarLanterna(call.getString("estado", "alternar"), call);
        } else {
            call.reject("Permissão de câmera negada. O Android exige essa permissão para acender a lanterna.");
        }
    }

    private static volatile boolean lanternaAcesa = false;

    private void aplicarLanterna(String estado, PluginCall call) {
        try {
            CameraManager cm = (CameraManager) getContext().getSystemService(Context.CAMERA_SERVICE);
            if (cm == null) throw new Exception("Serviço de câmera indisponível.");
            String alvo = null;
            for (String id : cm.getCameraIdList()) {
                Boolean temFlash = cm.getCameraCharacteristics(id).get(CameraCharacteristics.FLASH_INFO_AVAILABLE);
                if (!Boolean.TRUE.equals(temFlash)) continue;
                Integer frente = cm.getCameraCharacteristics(id).get(CameraCharacteristics.LENS_FACING);
                if (frente != null && frente == CameraCharacteristics.LENS_FACING_BACK) { alvo = id; break; }
                if (alvo == null) alvo = id;
            }
            if (alvo == null) throw new Exception("Este aparelho não tem lanterna.");
            boolean ligar;
            if ("ligar".equalsIgnoreCase(estado)) ligar = true;
            else if ("desligar".equalsIgnoreCase(estado)) ligar = false;
            else ligar = !lanternaAcesa;
            cm.setTorchMode(alvo, ligar);
            lanternaAcesa = ligar;
            JSObject o = new JSObject();
            o.put("ligada", ligar);
            call.resolve(o);
        } catch (Exception e) {
            call.reject("Não consegui usar a lanterna: " + (e.getMessage() == null ? "erro desconhecido" : e.getMessage()));
        }
    }

    @PluginMethod
    public void ajustarBrilho(PluginCall call) {
        try {
            if (!Settings.System.canWrite(getContext())) {
                try {
                    Intent permissao = new Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS,
                        Uri.parse("package:" + getContext().getPackageName()));
                    permissao.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    getContext().startActivity(permissao);
                } catch (Exception ignored) { }
                call.reject("O Android precisa da permissão “Modificar configurações” para eu mexer no brilho. A tela de autorização já abriu; permita e repita o pedido.");
                return;
            }
            android.content.ContentResolver cr = getContext().getContentResolver();
            String direcao = call.getString("direcao", "");
            String modo = call.getString("modo", "");
            Integer pct = call.getInt("percentual");
            String info;
            if ("auto".equalsIgnoreCase(modo)) {
                Settings.System.putInt(cr, Settings.System.SCREEN_BRIGHTNESS_MODE, Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC);
                info = "Brilho automático ativado.";
            } else if ("manual".equalsIgnoreCase(modo)) {
                Settings.System.putInt(cr, Settings.System.SCREEN_BRIGHTNESS_MODE, Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL);
                info = "Brilho manual ativado.";
            } else {
                Settings.System.putInt(cr, Settings.System.SCREEN_BRIGHTNESS_MODE, Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL);
                int atual = Settings.System.getInt(cr, Settings.System.SCREEN_BRIGHTNESS, 128);
                int max = 255;
                int novo;
                if (pct != null) novo = Math.round(Math.max(0, Math.min(100, pct)) * max / 100f);
                else if ("diminuir".equalsIgnoreCase(direcao)) novo = atual - 32;
                else if ("aumentar".equalsIgnoreCase(direcao)) novo = atual + 32;
                else novo = atual;
                novo = Math.max(16, Math.min(max, novo));
                Settings.System.putInt(cr, Settings.System.SCREEN_BRIGHTNESS, novo);
                info = "Brilho em " + Math.round(novo * 100f / max) + " por cento.";
            }
            JSObject o = new JSObject();
            o.put("info", info);
            o.put("auto", Settings.System.getInt(cr, Settings.System.SCREEN_BRIGHTNESS_MODE, 0)
                == Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC);
            call.resolve(o);
        } catch (Exception e) {
            call.reject("Não consegui ajustar o brilho: " + (e.getMessage() == null ? "erro desconhecido" : e.getMessage()));
        }
    }

    @PluginMethod
    public void abrirPainel(PluginCall call) {
        String alvo = call.getString("alvo", "rapido");
        boolean notificacoes = "notificacoes".equals(alvo);
        boolean expandido = false;
        // API oculta do sistema: funciona em parte dos Androids; se bloqueada, usamos o fallback abaixo.
        try {
            Class<?> statusBar = Class.forName("android.app.StatusBarManager");
            java.lang.reflect.Method getService = statusBar.getMethod("getService");
            Object mgr = getService.invoke(null);
            if (mgr != null) {
                java.lang.reflect.Method expand = statusBar.getMethod(notificacoes ? "expandNotificationsPanel" : "expandSettingsPanel");
                expand.invoke(mgr);
                expandido = true;
            }
        } catch (Throwable ignored) { }
        JSObject o = new JSObject();
        if (expandido) {
            o.put("info", "Painel de " + (notificacoes ? "notificações" : "configurações rápidas") + " aberto.");
            call.resolve(o);
            return;
        }
        try {
            Intent i = notificacoes
                ? new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, getContext().getPackageName())
                : new Intent(Settings.ACTION_SETTINGS);
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            getContext().startActivity(i);
            o.put("info", "Este Android bloqueou a abertura direta do painel (API oculta); abri as Configurações. Deslize a barra de status para baixo para ver o painel completo.");
        } catch (Exception e) {
            o.put("info", "Não consegui abrir o painel neste aparelho; deslize a barra de status manualmente.");
        }
        call.resolve(o);
    }

    @PluginMethod
    public void enviarEmail(PluginCall call) {
        try {
            String para = call.getString("para", "").trim();
            String rascunho = call.getString("rascunhoPara", "").trim();
            String assunto = call.getString("assunto", "");
            String texto = call.getString("texto", "");
            Intent i = new Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:" + para));
            if (!assunto.isEmpty()) i.putExtra(Intent.EXTRA_SUBJECT, assunto);
            if (!texto.isEmpty()) i.putExtra(Intent.EXTRA_TEXT, texto);
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            try {
                getContext().startActivity(i);
            } catch (android.content.ActivityNotFoundException e) {
                throw new Exception("Nenhum app de e-mail encontrado neste aparelho.");
            }
            JSObject o = new JSObject();
            o.put("info", !para.isEmpty()
                ? "Abri o app de e-mail com a mensagem pronta para " + para + ". Revise e toque em enviar."
                : "Abri o app de e-mail. Não tenho o endereço de “" + (rascunho.isEmpty() ? "destinatário" : rascunho)
                    + "” no cadastro de contatos; preencha o destinatário e revise antes de enviar.");
            call.resolve(o);
        } catch (Exception e) {
            call.reject("Não consegui abrir o e-mail: " + (e.getMessage() == null ? "erro desconhecido" : e.getMessage()));
        }
    }

    @PluginMethod
    public void fecharAplicativo(PluginCall call) {
        try {
            String app = call.getString("app", "").toLowerCase(Locale.ROOT).trim();
            String pkg = pacoteDe(app);
            JSObject o = new JSObject();
            boolean instalado = pkg != null && getContext().getPackageManager().getLaunchIntentForPackage(pkg) != null;
            if (pkg == null || getContext().getPackageName().equals(pkg) || !instalado) {
                Intent home = new Intent(Intent.ACTION_MAIN);
                home.addCategory(Intent.CATEGORY_HOME);
                home.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                getContext().startActivity(home);
                o.put("info", "Voltei à tela inicial. O Android não permite encerrar aplicativos à força; para encerrar um app, abra os detalhes dele.");
                call.resolve(o);
                return;
            }
            Intent i = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + pkg));
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            getContext().startActivity(i);
            o.put("info", "Abri os detalhes de " + app.replace("_", " ") + ". Toque em “Forçar parada” para encerrar — o Android não deixa apps encerrarem outros apps à força.");
            call.resolve(o);
        } catch (Exception e) {
            call.reject("Não consegui fechar o aplicativo: " + (e.getMessage() == null ? "erro desconhecido" : e.getMessage()));
        }
    }

    @PluginMethod
    public void versaoApp(PluginCall call) {
        try {
            PackageInfo pi = getContext().getPackageManager().getPackageInfo(getContext().getPackageName(), 0);
            JSObject o = new JSObject();
            o.put("versao", pi.versionName == null ? "" : pi.versionName);
            long codigo = Build.VERSION.SDK_INT >= 28 ? pi.getLongVersionCode() : pi.versionCode;
            o.put("versionCode", codigo);
            call.resolve(o);
        } catch (Exception e) {
            call.reject("Não consegui ler a versão do aplicativo: " + e.getMessage());
        }
    }

    /* ---------- Escuta em segundo plano: exceções do sistema ---------- */

    @PluginMethod
    public void otimizacaoBateria(PluginCall call) {
        try {
            String pkg = getContext().getPackageName();
            PowerManager pm = (PowerManager) getContext().getSystemService(Context.POWER_SERVICE);
            boolean ignorando = Build.VERSION.SDK_INT >= 23 && pm != null && pm.isIgnoringBatteryOptimizations(pkg);
            Intent i;
            if (!ignorando && Build.VERSION.SDK_INT >= 23) {
                i = new Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:" + pkg));
            } else {
                i = new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS);
            }
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            getContext().startActivity(i);
            JSObject o = new JSObject();
            o.put("ignorando", ignorando);
            o.put("info", ignorando
                ? "O Android já não otimiza a bateria do J.A.R.V.I.S. Nova."
                : "Na tela que abriu, escolha “Sem restrições” (ou “Não otimizar”) para o J.A.R.V.I.S. Nova.");
            call.resolve(o);
        } catch (Exception e) {
            try {
                Intent i = new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS);
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                getContext().startActivity(i);
                JSObject o = new JSObject();
                o.put("ignorando", false);
                o.put("info", "Abri a lista de otimização de bateria; procure o J.A.R.V.I.S. Nova e escolha “Não otimizar”.");
                call.resolve(o);
            } catch (Exception x) {
                call.reject("Não consegui abrir a tela de bateria: " + (x.getMessage() == null ? "erro" : x.getMessage()));
            }
        }
    }

    @PluginMethod
    public void sobreposicao(PluginCall call) {
        try {
            boolean ativo = Build.VERSION.SDK_INT < 23 || Settings.canDrawOverlays(getContext());
            if (!ativo) {
                Intent i = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:" + getContext().getPackageName()));
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                getContext().startActivity(i);
            }
            JSObject o = new JSObject();
            o.put("ativo", ativo);
            o.put("info", ativo
                ? "O Jarvis pode abrir a própria tela quando for chamado de outro app."
                : "Ative “Permitir sobreposição” para o Jarvis conseguir abrir a tela quando for chamado com o app fechado.");
            call.resolve(o);
        } catch (Exception e) {
            call.reject("Não consegui abrir a permissão de sobreposição: " + (e.getMessage() == null ? "erro" : e.getMessage()));
        }
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
            else if ("permissoes".equals(alvo)) i = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:" + getContext().getPackageName()));
            else if ("notificacoes".equals(alvo) && Build.VERSION.SDK_INT >= 26) {
                i = new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS);
                i.putExtra(Settings.EXTRA_APP_PACKAGE, getContext().getPackageName());
            }
            else if ("acessoNotificacoes".equals(alvo)) i = new Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS");
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
