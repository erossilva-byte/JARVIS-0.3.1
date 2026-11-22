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
     * Pedido feito pelo botão "Ouvir agora" da notificação. A interface consome o pedido
     * e o zera; se o processo morrer no meio, o pedido não fica ligado para sempre.
     */
    static boolean pedidoOuvir(Context c) {
        return sp(c).getBoolean("pedido_ouvir", false);
    }

    static void pedidoOuvir(Context c, boolean v) {
        sp(c).edit().putBoolean("pedido_ouvir", v).apply();
    }

    /**
     * Sensibilidade KWS (0 a 100, padrão 55). Mais alto reduz o limiar de detecção;
     * isso facilita a ativação, mas pode aumentar falsos positivos.
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

    /* ---------- Perfil de energia e pausa manual (Fase 4B) ---------- */

    static final String PERFIL_SEMPRE = "sempre";
    static final String PERFIL_CARREGANDO = "carregando";
    static final String PERFIL_HORARIO = "horario";
    static final String PERFIL_DESLIGADO = "desligado";

    /** Perfil escolhido pelo usuário; qualquer valor desconhecido cai em "sempre". */
    static String perfilEnergia(Context c) {
        String v = sp(c).getString("perfil_energia", PERFIL_SEMPRE);
        if (PERFIL_CARREGANDO.equals(v) || PERFIL_HORARIO.equals(v) || PERFIL_DESLIGADO.equals(v)) return v;
        return PERFIL_SEMPRE;
    }

    static void perfilEnergia(Context c, String v) {
        String p = v == null ? "" : v.trim().toLowerCase(java.util.Locale.ROOT);
        if (!PERFIL_CARREGANDO.equals(p) && !PERFIL_HORARIO.equals(p) && !PERFIL_DESLIGADO.equals(p)) {
            p = PERFIL_SEMPRE;
        }
        sp(c).edit().putString("perfil_energia", p).apply();
    }

    /** Início da janela em minutos desde a meia-noite (padrão 07:00). */
    static int horarioInicio(Context c) { return minutosDoDia(sp(c).getInt("horario_inicio", 7 * 60)); }

    static void horarioInicio(Context c, int v) { sp(c).edit().putInt("horario_inicio", minutosDoDia(v)).apply(); }

    /** Fim da janela em minutos desde a meia-noite (padrão 23:00). */
    static int horarioFim(Context c) { return minutosDoDia(sp(c).getInt("horario_fim", 23 * 60)); }

    static void horarioFim(Context c, int v) { sp(c).edit().putInt("horario_fim", minutosDoDia(v)).apply(); }

    private static int minutosDoDia(int v) { return v < 0 ? 0 : Math.min(1439, v); }

    /** Limites oferecidos na tela: o usuário escolhe quando reduzir a escuta. */
    static final int[] LIMITES_BATERIA = { 10, 15, 20 };

    /** Limite de bateria (%) para reduzir a escuta; fora da lista, vale 15%. */
    static int limiteBateria(Context c) {
        int v = sp(c).getInt("limite_bateria", 15);
        for (int opcao : LIMITES_BATERIA) if (opcao == v) return opcao;
        return 15;
    }

    static void limiteBateria(Context c, int v) {
        int escolhido = 15;
        for (int opcao : LIMITES_BATERIA) if (opcao == v) escolhido = opcao;
        sp(c).edit().putInt("limite_bateria", escolhido).apply();
    }

    /** Última execução da manutenção periódica do WorkManager. */
    static long ultimaManutencao(Context c) { return sp(c).getLong("ultima_manutencao", 0L); }

    static void ultimaManutencao(Context c, long quando) { sp(c).edit().putLong("ultima_manutencao", quando).apply(); }

    static boolean manutencaoAgendada(Context c) { return sp(c).getBoolean("manutencao_agendada", false); }

    static void manutencaoAgendada(Context c, boolean v) { sp(c).edit().putBoolean("manutencao_agendada", v).apply(); }

    /**
     * Pausa pedida pelo usuário no botão da notificação. É diferente de "deseja":
     * continua querendo ouvir, só não agora — e isso precisa sobreviver à tela apagada.
     */
    static boolean pausadoManual(Context c) { return sp(c).getBoolean("pausado_manual", false); }

    static void pausadoManual(Context c, boolean v) { sp(c).edit().putBoolean("pausado_manual", v).apply(); }
}

