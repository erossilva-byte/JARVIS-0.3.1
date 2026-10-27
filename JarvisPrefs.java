package com.jarvis.nova;

import android.content.Context;
import android.content.SharedPreferences;

/**
 * Estado que precisa sobreviver ao fechamento da tela (e ao reinício do aparelho).
 *
 * Quem decide se a escuta está ligada é este arquivo, não o localStorage da interface:
 * quando o Android reinicia o serviço (START_STICKY) ou o aparelho, o serviço precisa
 * saber que deve continuar ouvindo e com qual calibragem do detector próprio.
 *
 * Aqui só ficam preferências sem segredo: o detector de ativação é 100% local (nenhuma
 * chave de terceiro, nenhum áudio saindo do aparelho), então não há mais nada cifrado
 * neste arquivo — o que existia era a AccessKey do Picovoice, removida com ele.
 */
final class JarvisPrefs {

    private static final String ARQ = "jarvis_escuta";

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

    /**
     * Sensibilidade do detector próprio (0 a 100, padrão 55). Mais alto aceita a palavra
     * dita mais torta, aceita resultado parcial (responde antes) e tolera mais ruído.
     */
    static int sensibilidade(Context c) {
        int v = sp(c).getInt("sensibilidade", 55);
        return v < 0 ? 0 : Math.min(100, v);
    }

    static void sensibilidade(Context c, int v) {
        sp(c).edit().putInt("sensibilidade", v < 0 ? 0 : Math.min(100, v)).apply();
    }

    /**
     * Palavras extras que também devem acordar o assistente (separadas por vírgula).
     * Útil para apelidos e para o jeito de cada sotaque transcrever "Jarvis".
     */
    static String variantes(Context c) {
        return sp(c).getString("variantes", "");
    }

    static void variantes(Context c, String v) {
        String t = v == null ? "" : v.trim();
        if (t.length() > 200) t = t.substring(0, 200);
        sp(c).edit().putString("variantes", t).apply();
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

    /**
     * Quantas vezes uma transcrição parecida com a palavra foi descartada pelo porteiro de
     * ruído (som baixo demais para ser voz dirigida ao aparelho). É o número que mostra se
     * a calibragem está apertada ou frouxa demais.
     */
    static int rejeitadas(Context c) {
        return sp(c).getInt("rejeitadas", 0);
    }

    static void rejeitadas(Context c, int v) {
        sp(c).edit().putInt("rejeitadas", Math.max(0, v)).apply();
    }

    /**
     * Contador de sessões de voz: começa em 1 e sobe a cada reinício do aparelho.
     * A verificação do perfil de voz acontece uma vez por sessão (primeiro acesso
     * depois de ligar o celular), não a cada palavra de ativação.
     */
    static int sessao(Context c) {
        int s = sp(c).getInt("sessao_voz", 1);
        return s < 1 ? 1 : s;
    }

    static void novaSessao(Context c) {
        sp(c).edit().putInt("sessao_voz", sessao(c) + 1).apply();
    }
}
