package com.jarvis.nova;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Detector de ativação próprio do J.A.R.V.I.S. Nova — sem Picovoice e sem nenhum serviço
 * externo: o serviço ouve, o reconhecimento do Android transcreve e as regras daqui
 * decidem, no próprio aparelho, se o usuário chamou o assistente.
 *
 * Como o reconhecimento do Android escreve "Jarvis" quando quem fala é brasileiro:
 * "já vi", "javis", "charvis", "garvis", "jarviz"... Em vez de uma lista fixa de padrões,
 * a decisão passa por três degraus:
 *
 *   1. variantes conhecidas (curadoria) e as palavras extras cadastradas pelo usuário;
 *   2. distância de edição pequena em relação a "jarvis" — tolera sotaque e vogal trocada;
 *   3. comparação pelo esqueleto consonantal: "ch", "sh" e "x" viram "j", "z" vira "s" e as
 *      vogais saem, então "charvis" e "jarvis" chegam ao mesmo "jrvs".
 *
 * O degrau 2/3 só vale para palavra começando com "j": é o que impede "graves", "garvos" e
 * outras palavras do dia a dia de acordarem o assistente. A sensibilidade escolhida pelo
 * usuário controla a tolerância (0, 1 ou 2 caracteres) e o porteiro de ruído.
 *
 * Estas regras são as mesmas de hermes.js (Hermes.ativacao), que roda no WebView; os testes
 * comparam os dois lados para que o comportamento não divirja entre a tela e o serviço.
 */
final class JarvisAtivacao {

    static final String VERSAO = "1.1.0";
    static final String CANONICO = "jarvis";

    /**
     * Variantes medidas com voz brasileira — todas já vistas em transcrições reais, incluindo
     * as formas curtas que o usuário dita rápido ("jaive"). As formas sem o "v" só funcionam
     * porque estão nesta lista exata: a tolerância por fonética exige a letra "v" na palavra.
     * Esta lista precisa ser idêntica à de Hermes.ativacao (hermes.js) — há teste comparando.
     */
    static final String[] VARIANTES = {
        "jarvis", "jarvi", "jarvys", "jarvs", "jarves", "jarvez", "jarvy", "jarviz", "jarvisz",
        "javi", "javis", "javy", "javiz", "jervis", "jervys", "jervi", "jerves", "jervesz",
        "gervis", "gerves", "garvis", "garvys", "garves", "charvis", "charves", "sharvis", "xarvis",
        "jarbis", "jarbys", "jorvis", "jaive", "jaives", "jaivi"
    };

    private JarvisAtivacao() { }

    /** Calibragem derivada da sensibilidade (0-100) e das palavras extras do usuário. */
    static final class Config {
        int sensibilidade = 55;
        int tolerancia = 1;
        boolean aceitaParcial = true;
        int minimoParcial = 6;
        float ruidoDb = -40f;
        String[] extras = new String[0];

        /** Resumo para a tela de diagnóstico e para o registro. */
        String descricao() {
            return "sensibilidade " + sensibilidade + "%, tolerância " + tolerancia +
                " caractere(s), parcial " + (aceitaParcial ? "sim" : "não") +
                ", piso de voz " + Math.round(ruidoDb) + " dB" +
                (extras.length > 0 ? ", " + extras.length + " palavra(s) extra(s)" : "");
        }
    }

    static Config config(int sensibilidade, String variantes) {
        Config c = new Config();
        c.sensibilidade = Math.max(0, Math.min(100, sensibilidade));
        c.tolerancia = c.sensibilidade >= 75 ? 2 : c.sensibilidade >= 45 ? 1 : 0;
        c.aceitaParcial = c.sensibilidade >= 35;
        c.minimoParcial = c.sensibilidade >= 75 ? 5 : 6;
        c.ruidoDb = c.sensibilidade >= 75 ? -46f : c.sensibilidade >= 45 ? -40f : -34f;
        c.extras = separarExtras(variantes);
        return c;
    }

    static String[] separarExtras(String variantes) {
        if (variantes == null) return new String[0];
        List<String> lista = new ArrayList<>();
        for (String parte : variantes.split("[,;\\n]")) {
            String t = norm(parte);
            if (t.length() >= 3 && t.indexOf(' ') < 0 && !lista.contains(t)) lista.add(t);
        }
        return lista.toArray(new String[0]);
    }

    /** Minúsculas, sem acento e sem pontuação — o mesmo tratamento do lado JavaScript. */
    static String norm(String s) {
        if (s == null) return "";
        String t = java.text.Normalizer.normalize(s, java.text.Normalizer.Form.NFD).replaceAll("\\p{M}+", "");
        t = t.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]+", " ").replaceAll("\\s+", " ").trim();
        return t;
    }

    /** Esqueleto consonantal: "charvis" -> "jrvs", "jarvi" -> "jrv", "javis" -> "jvs". */
    static String esqueleto(String t) {
        String s = norm(t).replace(" ", "");
        s = s.replaceAll("ch|sh|x", "j");
        s = s.replaceAll("[zç]", "s");
        s = s.replaceAll("[aeiouy]", "");
        s = s.replaceAll("(.)\\1+", "$1");
        return s;
    }

    /** Levenshtein: quantas letras separam duas palavras (tolerância a sotaque). */
    static int distancia(String a, String b) {
        String x = a == null ? "" : a;
        String y = b == null ? "" : b;
        if (x.equals(y)) return 0;
        if (x.isEmpty()) return y.length();
        if (y.isEmpty()) return x.length();
        int[] anterior = new int[y.length() + 1];
        int[] atual = new int[y.length() + 1];
        for (int j = 0; j <= y.length(); j++) anterior[j] = j;
        for (int i = 1; i <= x.length(); i++) {
            atual[0] = i;
            for (int j = 1; j <= y.length(); j++) {
                int custo = x.charAt(i - 1) == y.charAt(j - 1) ? 0 : 1;
                atual[j] = Math.min(Math.min(anterior[j] + 1, atual[j - 1] + 1), anterior[j - 1] + custo);
            }
            int[] troca = anterior;
            anterior = atual;
            atual = troca;
        }
        return anterior[y.length()];
    }

    /** Uma palavra isolada é a palavra de ativação? */
    static boolean casaToken(String token, Config c) {
        Config cfg = c == null ? config(55, "") : c;
        String t = norm(token);
        if (t.isEmpty() || t.indexOf(' ') >= 0) return false;
        for (String v : VARIANTES) if (v.equals(t)) return true;
        for (String v : cfg.extras) if (v.equals(t)) return true;
        if (t.length() < 4) return false;
        // As formas tortas só entram na família "jarv-": J inicial e a letra "v" na palavra.
        // É essa trave que impede "jardim", "jardineiro" e "jargão" de acordar o assistente.
        if (t.charAt(0) != 'j' || t.indexOf('v') < 0) return false;
        if (distancia(t, CANONICO) <= Math.min(2, cfg.tolerancia + 1)) return true;
        if (distancia(esqueleto(t), esqueleto(CANONICO)) <= cfg.tolerancia) return true;
        return false;
    }

    /** A palavra aparece em algum lugar da transcrição (inclusive partida em duas)? */
    static boolean presente(String texto, Config c) {
        Config cfg = c == null ? config(55, "") : c;
        String n = norm(texto);
        if (n.isEmpty()) return false;
        if (casaToken(n, cfg)) return true;
        String[] partes = n.split(" ");
        for (String p : partes) if (casaToken(p, cfg)) return true;
        // O transcritor às vezes separa a palavra: "jar vis".
        for (int i = 1; i < partes.length; i++) {
            if (casaToken(partes[i - 1] + partes[i], cfg)) return true;
        }
        return false;
    }
}
