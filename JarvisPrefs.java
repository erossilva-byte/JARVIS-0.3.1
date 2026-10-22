package com.jarvis.nova;

import android.content.Context;
import android.content.SharedPreferences;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;

import java.security.KeyStore;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/**
 * Estado que precisa sobreviver ao fechamento da tela (e ao reinício do aparelho).
 *
 * Antes, quem decidia se a escuta estava ligada era só o localStorage da interface.
 * Quando o Android reiniciava o serviço (START_STICKY) ou o aparelho, o serviço não
 * tinha como saber que deveria continuar ouvindo — e a AccessKey do Porcupine se
 * perdia, fazendo-o cair no detector livre sem avisar.
 *
 * A chave é cifrada com uma chave AES/GCM gerada no Android Keystore (a mesma ideia
 * usada pelo cofre do app); se o Keystore falhar, a leitura devolve vazio e o serviço
 * segue com o detector livre em vez de guardar a chave em texto puro.
 */
final class JarvisPrefs {

    private static final String ARQ = "jarvis_escuta";
    private static final String ALIAS = "jarvis_escuta_aes";
    private static final String PREFIXO = "aes_v1:";

    private JarvisPrefs() { }

    static SharedPreferences sp(Context c) {
        return c.getSharedPreferences(ARQ, Context.MODE_PRIVATE);
    }

    /** O usuário quer a palavra de ativação ligada (sobrevive a app fechado e reinício). */
    static boolean desejaOuvir(Context c) {
        return sp(c).getBoolean("deseja", false);
    }

    static void desejaOuvir(Context c, boolean v) {
        sp(c).edit().putBoolean("deseja", v).apply();
    }

    static boolean pausarMusica(Context c) {
        return sp(c).getBoolean("musica", true);
    }

    static void pausarMusica(Context c, boolean v) {
        sp(c).edit().putBoolean("musica", v).apply();
    }

    /** Última falha do detector, mostrada no diagnóstico (sem áudio nem conteúdo de comandos). */
    static String ultimoErro(Context c) {
        return sp(c).getString("erro", "");
    }

    static void ultimoErro(Context c, String v) {
        String texto = v == null ? "" : v;
        if (texto.length() > 300) texto = texto.substring(0, 300);
        sp(c).edit().putString("erro", texto).apply();
    }

    static long ultimoEvento(Context c) {
        return sp(c).getLong("evento", 0L);
    }

    static void ultimoEvento(Context c, long quando) {
        sp(c).edit().putLong("evento", quando).apply();
    }

    static boolean pedidoOuvir(Context c) {
        return sp(c).getBoolean("pedido_ouvir", false);
    }

    static void pedidoOuvir(Context c, boolean v) {
        sp(c).edit().putBoolean("pedido_ouvir", v).apply();
    }

    /* ---------- AccessKey do Porcupine ---------- */

    static void guardarChave(Context c, String chave) {
        String limpa = chave == null ? "" : chave.trim();
        if (limpa.isEmpty()) {
            sp(c).edit().remove("chave").apply();
            return;
        }
        try {
            sp(c).edit().putString("chave", PREFIXO + cifrar(limpa)).apply();
        } catch (Exception e) {
            // Sem Keystore não guardamos o segredo em claro: o serviço usa o detector livre.
            sp(c).edit().remove("chave").apply();
        }
    }

    static String lerChave(Context c) {
        String guardada = sp(c).getString("chave", "");
        if (guardada == null || guardada.isEmpty()) return "";
        if (!guardada.startsWith(PREFIXO)) {
            // Formato antigo ou valor inesperado: descarta para não usar dado não cifrado.
            sp(c).edit().remove("chave").apply();
            return "";
        }
        try {
            return decifrar(guardada.substring(PREFIXO.length()));
        } catch (Exception e) {
            // Keystore invalidado (restauração/troca de senha): melhor pedir a chave de novo.
            sp(c).edit().remove("chave").apply();
            return "";
        }
    }

    static boolean temChave(Context c) {
        return !sp(c).getString("chave", "").isEmpty();
    }

    private static SecretKey chaveAes() throws Exception {
        KeyStore ks = KeyStore.getInstance("AndroidKeyStore");
        ks.load(null);
        if (ks.containsAlias(ALIAS)) {
            return (SecretKey) ks.getKey(ALIAS, null);
        }
        KeyGenerator kg = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
        kg.init(new KeyGenParameterSpec.Builder(ALIAS,
                KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .build());
        return kg.generateKey();
    }

    private static String cifrar(String texto) throws Exception {
        Cipher c = Cipher.getInstance("AES/GCM/NoPadding");
        c.init(Cipher.ENCRYPT_MODE, chaveAes());
        byte[] iv = c.getIV();
        byte[] dados = c.doFinal(texto.getBytes("UTF-8"));
        byte[] juntos = new byte[iv.length + dados.length];
        System.arraycopy(iv, 0, juntos, 0, iv.length);
        System.arraycopy(dados, 0, juntos, iv.length, dados.length);
        return Base64.encodeToString(juntos, Base64.NO_WRAP);
    }

    private static String decifrar(String base64) throws Exception {
        byte[] juntos = Base64.decode(base64, Base64.NO_WRAP);
        if (juntos.length < 13) throw new IllegalArgumentException("conteúdo curto");
        byte[] iv = new byte[12];
        System.arraycopy(juntos, 0, iv, 0, 12);
        Cipher c = Cipher.getInstance("AES/GCM/NoPadding");
        c.init(Cipher.DECRYPT_MODE, chaveAes(), new GCMParameterSpec(128, iv));
        return new String(c.doFinal(juntos, 12, juntos.length - 12), "UTF-8");
    }
}
