package com.jarvis.nova;

import android.Manifest;
import android.content.ContentResolver;
import android.content.ContentUris;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.provider.MediaStore;

import androidx.core.content.ContextCompat;

import com.getcapacitor.JSObject;
import com.getcapacitor.PermissionState;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.getcapacitor.annotation.Permission;
import com.getcapacitor.annotation.PermissionCallback;

import java.text.Normalizer;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Busca a música na biblioteca do aparelho e manda tocar de verdade.
 *
 * O comando de voz “coloca a música This I Love” precisa começar a tocar, não apenas
 * mostrar uma lista. Aqui a busca é feita no MediaStore (ignorando acentos, pontuação
 * e ordem das palavras) e o JarvisMusicaService toca o arquivo encontrado. Quando a
 * faixa não existe no aparelho, a interface avisa e cai na busca de um app de streaming.
 */
@CapacitorPlugin(
    name = "JarvisMusica",
    permissions = {
        // Android 13+ lê áudio com READ_MEDIA_AUDIO; até o 12 era READ_EXTERNAL_STORAGE.
        // Ficam em aliases separados porque um pedido que inclui permissão inexistente
        // na versão do Android volta como negado e esconderia o resultado real.
        @Permission(strings = { Manifest.permission.READ_MEDIA_AUDIO }, alias = "audio"),
        @Permission(strings = { Manifest.permission.READ_EXTERNAL_STORAGE }, alias = "audioAntigo")
    }
)
public class JarvisMusicaPlugin extends Plugin {

    private final ExecutorService worker = Executors.newSingleThreadExecutor();

    @PluginMethod
    public void tocar(PluginCall call) {
        if (temPermissaoMidia()) { tocarInterno(call); return; }
        String alias = Build.VERSION.SDK_INT >= 33 ? "audio" : "audioAntigo";
        requestPermissionForAlias(alias, call, "aposPermissaoMidia");
    }

    @PermissionCallback
    private void aposPermissaoMidia(PluginCall call) {
        // Mesmo sem permissão seguimos: a consulta devolve vazio e a interface explica.
        tocarInterno(call);
    }

    private void tocarInterno(final PluginCall call) {
        final String busca = call.getString("busca", "");
        worker.execute(() -> {
            try {
                List<Faixa> achadas = procurar(busca);
                if (achadas.isEmpty()) {
                    JSObject o = new JSObject();
                    o.put("achou", false);
                    o.put("busca", busca);
                    o.put("precisaPermissao", !temPermissaoMidia());
                    call.resolve(o);
                    return;
                }
                ArrayList<String> uris = new ArrayList<>();
                ArrayList<String> titulos = new ArrayList<>();
                ArrayList<String> artistas = new ArrayList<>();
                for (Faixa f : achadas) {
                    uris.add(f.uri);
                    titulos.add(f.titulo);
                    artistas.add(f.artista);
                }
                JarvisMusicaService.tocar(getContext(), uris, titulos, artistas);
                JSObject o = new JSObject();
                o.put("achou", true);
                o.put("titulo", achadas.get(0).titulo);
                o.put("artista", achadas.get(0).artista);
                o.put("total", achadas.size());
                call.resolve(o);
            } catch (Throwable e) {
                call.reject("Não consegui procurar a música: " + (e.getMessage() == null ? "erro desconhecido" : e.getMessage()));
            }
        });
    }

    @PluginMethod
    public void estado(PluginCall call) {
        call.resolve(JarvisMusicaService.estado());
    }

    @PluginMethod
    public void pausar(PluginCall call) {
        JarvisMusicaService.comando(getContext(), "pausar");
        call.resolve(JarvisMusicaService.estado());
    }

    @PluginMethod
    public void continuar(PluginCall call) {
        JarvisMusicaService.comando(getContext(), "continuar");
        call.resolve(JarvisMusicaService.estado());
    }

    @PluginMethod
    public void proxima(PluginCall call) {
        JarvisMusicaService.comando(getContext(), "proxima");
        call.resolve(JarvisMusicaService.estado());
    }

    @PluginMethod
    public void anterior(PluginCall call) {
        JarvisMusicaService.comando(getContext(), "anterior");
        call.resolve(JarvisMusicaService.estado());
    }

    @PluginMethod
    public void parar(PluginCall call) {
        JarvisMusicaService.comando(getContext(), "parar");
        call.resolve();
    }

    /* ---------- Busca ---------- */

    private boolean temPermissaoMidia() {
        String p = Build.VERSION.SDK_INT >= 33 ? Manifest.permission.READ_MEDIA_AUDIO : Manifest.permission.READ_EXTERNAL_STORAGE;
        return ContextCompat.checkSelfPermission(getContext(), p) == android.content.pm.PackageManager.PERMISSION_GRANTED;
    }

    static class Faixa {
        String uri;
        String titulo;
        String artista;
        String album;
        long duracao;
        int score;
    }

    private List<Faixa> procurar(String busca) {
        String alvo = norm(busca);
        if (alvo.isEmpty()) return Collections.emptyList();
        List<Faixa> todas = lerBiblioteca();
        List<Faixa> achadas = new ArrayList<>();
        for (Faixa f : todas) {
            int pontos = pontuar(alvo, norm(f.titulo), norm(f.artista), norm(f.album));
            if (pontos <= 0) continue;
            f.score = pontos;
            achadas.add(f);
        }
        Collections.sort(achadas, new Comparator<Faixa>() {
            @Override public int compare(Faixa a, Faixa b) { return Integer.compare(b.score, a.score); }
        });
        if (achadas.size() > 25) return new ArrayList<>(achadas.subList(0, 25));
        return achadas;
    }

    private List<Faixa> lerBiblioteca() {
        List<Faixa> lista = new ArrayList<>();
        ContentResolver cr = getContext().getContentResolver();
        Uri colecao = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI;
        String[] colunas = {
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION
        };
        String selecao = MediaStore.Audio.Media.IS_MUSIC + "!=0";
        Cursor c = null;
        try {
            c = cr.query(colecao, colunas, selecao, null, MediaStore.Audio.Media.TITLE + " ASC");
            if (c == null) return lista;
            while (c.moveToNext() && lista.size() < 20000) {
                try {
                    long id = c.getLong(0);
                    Faixa f = new Faixa();
                    f.uri = ContentUris.withAppendedId(colecao, id).toString();
                    f.titulo = c.getString(1) == null ? "" : c.getString(1);
                    f.artista = c.getString(2) == null ? "" : c.getString(2);
                    f.album = c.getString(3) == null ? "" : c.getString(3);
                    f.duracao = c.getLong(4);
                    if (f.titulo.isEmpty() || f.duracao < 8000) continue;
                    lista.add(f);
                } catch (Throwable ignored) { }
            }
        } catch (Throwable ignored) {
            return lista;
        } finally {
            if (c != null) try { c.close(); } catch (Throwable ignored) { }
        }
        return lista;
    }

    /** Normaliza para comparar: sem acento, sem pontuação, minúsculo. */
    static String norm(String s) {
        if (s == null) return "";
        String n = Normalizer.normalize(s, Normalizer.Form.NFD).replaceAll("\\p{M}+", "");
        n = n.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]+", " ").trim();
        return n.replaceAll("\\s+", " ");
    }

    private static Set<String> palavras(String s) {
        Set<String> p = new HashSet<>();
        for (String x : s.split(" ")) if (x.length() > 0) p.add(x);
        return p;
    }

    /**
     * Nota de 0 a 1000. Título exato ganha de título contido, que ganha de "todas as
     * palavras aparecem" — e aí entram o artista e o álbum, para o caso de o usuário
     * dizer o nome do disco ou da banda.
     */
    static int pontuar(String busca, String titulo, String artista, String album) {
        if (busca.isEmpty() || titulo.isEmpty()) return 0;
        if (titulo.equals(busca)) return 1000;
        if (titulo.startsWith(busca + " ") || titulo.startsWith(busca)) return 950;
        if (titulo.contains(busca)) return 900 - Math.min(80, Math.abs(titulo.length() - busca.length()));
        if (busca.contains(titulo) && titulo.length() >= 5) return 820;

        Set<String> alvo = palavras(busca);
        if (alvo.isEmpty()) return 0;
        Set<String> noTitulo = palavras(titulo);
        int comuns = 0;
        for (String p : alvo) if (noTitulo.contains(p)) comuns++;
        double coberturaTitulo = comuns / (double) alvo.size();
        if (coberturaTitulo >= 1.0) return 780;
        if (coberturaTitulo >= 0.66) return (int) (560 + 120 * coberturaTitulo);

        String conjunto = titulo + " " + artista + " " + album;
        Set<String> todas = palavras(conjunto);
        int noConjunto = 0;
        for (String p : alvo) if (todas.contains(p)) noConjunto++;
        double cobertura = noConjunto / (double) alvo.size();
        if (cobertura >= 1.0) return 640;
        if (cobertura >= 0.75) return (int) (440 + 120 * cobertura);

        // Um erro de digitação ou de transcrição: compara as duas frases inteiras.
        int d = distancia(busca, titulo);
        int limite = Math.max(1, Math.min(busca.length(), titulo.length()) / 7);
        if (d <= limite) return 380;
        return 0;
    }

    private static int distancia(String a, String b) {
        int[] antes = new int[b.length() + 1];
        int[] agora = new int[b.length() + 1];
        for (int j = 0; j <= b.length(); j++) antes[j] = j;
        for (int i = 1; i <= a.length(); i++) {
            agora[0] = i;
            for (int j = 1; j <= b.length(); j++) {
                int custo = a.charAt(i - 1) == b.charAt(j - 1) ? 0 : 1;
                agora[j] = Math.min(Math.min(agora[j - 1] + 1, antes[j] + 1), antes[j - 1] + custo);
            }
            int[] troca = antes; antes = agora; agora = troca;
        }
        return antes[b.length()];
    }

    @Override
    protected void handleOnDestroy() {
        worker.shutdownNow();
        super.handleOnDestroy();
    }
}
