package com.jarvis.nova;

import android.media.AudioAttributes;
import android.media.AudioFormat;
import android.media.AudioTrack;
import android.os.Build;
import android.util.Log;

import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import com.k2fsa.sherpa.onnx.GeneratedAudio;
import com.k2fsa.sherpa.onnx.OfflineTts;
import com.k2fsa.sherpa.onnx.OfflineTtsConfig;
import com.k2fsa.sherpa.onnx.OfflineTtsKokoroModelConfig;
import com.k2fsa.sherpa.onnx.OfflineTtsModelConfig;
import com.k2fsa.sherpa.onnx.OfflineTtsVitsModelConfig;

import org.apache.commons.compress.archivers.tar.TarArchiveEntry;
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream;
import org.apache.commons.compress.compressors.bzip2.BZip2CompressorInputStream;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Voz neural offline (sherpa-onnx / Next-gen Kaldi).
 *
 * O motor nativo e os modelos são opcionais: o APK traz apenas as bibliotecas, e cada
 * voz é baixada uma única vez pelo usuário para o armazenamento privado do app. Depois
 * disso a síntese acontece no aparelho, sem internet e sem chave de API.
 *
 * Tudo aqui roda fora da thread da interface e qualquer falha do motor cai de volta no
 * TTS do Android (o app.js trata o erro), nunca travando a conversa.
 */
@CapacitorPlugin(name = "JarvisVoz")
public class JarvisVozPlugin extends Plugin {
    private static final String TAG = "JarvisVoz";
    private static final String BASE = "https://github.com/k2-fsa/sherpa-onnx/releases/download";
    private static final String MARCADOR = ".pronto";

    /** Um modelo de voz disponível para download. */
    private static final class Voz {
        final String id;
        final String nome;
        final String idioma;
        final String descricao;
        final String url;
        final long bytes;
        final boolean kokoro;
        final String arquivoOnnx;
        final String[] falantes; // "sid:nome" para Kokoro; vazio = falante único

        Voz(String id, String nome, String idioma, String descricao, String url, long bytes,
            boolean kokoro, String arquivoOnnx, String... falantes) {
            this.id = id;
            this.nome = nome;
            this.idioma = idioma;
            this.descricao = descricao;
            this.url = url;
            this.bytes = bytes;
            this.kokoro = kokoro;
            this.arquivoOnnx = arquivoOnnx;
            this.falantes = falantes;
        }
    }

    // Catálogo único de vozes. Qualquer mudança aqui aparece sozinha na interface.
    private static final List<Voz> CATALOGO = new ArrayList<>();

    static {
        CATALOGO.add(new Voz(
            "cadu",
            "Cadu — voz masculina grave (português do Brasil)",
            "pt-BR",
            "Recomendada. VITS/Piper treinada em português brasileiro, licença CC0, 22,05 kHz. "
                + "Fala rápido no aparelho (bem mais rápido que o tempo real) e é a mais próxima de "
                + "um timbre masculino brasileiro grave.",
            BASE + "/tts-models/vits-piper-pt_BR-cadu-medium.tar.bz2",
            67207562L, false, "pt_BR-cadu-medium.onnx"));
        CATALOGO.add(new Voz(
            "faber",
            "Faber — voz masculina clara (português do Brasil)",
            "pt-BR",
            "Alternativa à Cadu: timbre mais claro e um pouco mais agudo, mesma qualidade e licença "
                + "CC0. Útil se a Cadu soar grave demais para o seu gosto.",
            BASE + "/tts-models/vits-piper-pt_BR-faber-medium.tar.bz2",
            67183065L, false, "pt_BR-faber-medium.onnx"));
        CATALOGO.add(new Voz(
            "kokoro",
            "Kokoro — Jarvis do filme (inglês britânico)",
            "en",
            "Kokoro-82M quantizado: as vozes britânicas masculinas bm_fable/bm_george são o timbre "
                + "mais parecido com o J.A.R.V.I.S. do cinema. Só fala inglês (a fonetização "
                + "portuguesa não está disponível neste pacote) e sintetiza devagar: reserve para "
                + "respostas curtas.",
            BASE + "/tts-models/kokoro-int8-multi-lang-v1_0.tar.bz2",
            132303094L, true, "model.int8.onnx",
            "25:bm_fable (mais grave)", "26:bm_george (mais claro)", "24:bm_daniel"));
    }

    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private final Object trava = new Object();
    private OfflineTts motor;
    private String motorId;
    private volatile boolean pararPedido;
    private volatile AudioTrack faixa;
    private final Set<String> cancelados = new HashSet<>();

    @Override
    protected void handleOnDestroy() {
        liberarMotor();
        try {
            worker.shutdownNow();
        } catch (Exception e) {
            // encerramento best-effort
        }
        super.handleOnDestroy();
    }

    // ---------------------------------------------------------------- catálogo

    private static Voz achar(String id) {
        for (Voz v : CATALOGO) {
            if (v.id.equals(id)) return v;
        }
        return null;
    }

    private File raiz() {
        File d = new File(getContext().getFilesDir(), "voz-neural");
        if (!d.exists()) //noinspection ResultOfMethodCallIgnored
            d.mkdirs();
        return d;
    }

    private File pasta(Voz v) {
        return new File(raiz(), v.id);
    }

    /** Diretório que contém o .onnx (o arquivo .tar.bz2 traz uma pasta com o nome do modelo). */
    private File pastaModelo(Voz v) {
        File base = pasta(v);
        if (new File(base, v.arquivoOnnx).isFile()) return base;
        File[] filhos = base.listFiles();
        if (filhos != null) {
            for (File f : filhos) {
                if (f.isDirectory() && new File(f, v.arquivoOnnx).isFile()) return f;
            }
        }
        return null;
    }

    private boolean instalado(Voz v) {
        File dir = pastaModelo(v);
        return dir != null && new File(pasta(v), MARCADOR).isFile();
    }

    private static long tamanho(File dir) {
        if (dir == null || !dir.exists()) return 0;
        File[] filhos = dir.listFiles();
        if (filhos == null) return dir.length();
        long total = dir.length();
        for (File f : filhos) total += tamanho(f);
        return total;
    }

    private boolean abiSuportada() {
        Set<String> abis = new HashSet<>();
        if (Build.SUPPORTED_ABIS != null) {
            for (String a : Build.SUPPORTED_ABIS) abis.add(a);
        }
        return abis.contains("arm64-v8a") || abis.contains("armeabi-v7a");
    }

    // ---------------------------------------------------------------- status

    @PluginMethod
    public void status(PluginCall call) {
        JSObject out = new JSObject();
        boolean nativo = abiSuportada();
        String aviso = "";
        try {
            // Carrega a biblioteca nativa agora: se o AAR não entrou no APK, avisamos aqui
            // em vez de estourar no meio de uma resposta falada.
            Class.forName("com.k2fsa.sherpa.onnx.OfflineTts");
        } catch (Throwable t) {
            nativo = false;
            aviso = "O motor neural não está nesta instalação (" + t.getClass().getSimpleName() + ").";
        }
        out.put("suportado", nativo);
        out.put("aviso", aviso);
        out.put("motor", "sherpa-onnx 1.13.8 (Next-gen Kaldi, Apache-2.0)");
        JSArray abis = new JSArray();
        if (Build.SUPPORTED_ABIS != null) {
            for (String a : Build.SUPPORTED_ABIS) abis.put(a);
        }
        out.put("abis", abis);
        JSArray lista = new JSArray();
        for (Voz v : CATALOGO) {
            JSObject o = new JSObject();
            File modelo = pastaModelo(v);
            o.put("id", v.id);
            o.put("nome", v.nome);
            o.put("idioma", v.idioma);
            o.put("descricao", v.descricao);
            o.put("bytes", v.bytes);
            o.put("downloadMB", Math.round(v.bytes / 1048576.0));
            o.put("instalado", instalado(v));
            o.put("disco", tamanho(pasta(v)));
            o.put("kokoro", v.kokoro);
            o.put("emUso", motorId != null && motorId.equals(v.id) && motor != null);
            JSArray falantes = new JSArray();
            for (String f : v.falantes) {
                String[] partes = f.split(":", 2);
                JSObject fo = new JSObject();
                fo.put("sid", Integer.parseInt(partes[0]));
                fo.put("nome", partes[1]);
                falantes.put(fo);
            }
            o.put("falantes", falantes);
            o.put("modelo", modelo != null ? new File(modelo, v.arquivoOnnx).getAbsolutePath() : "");
            lista.put(o);
        }
        out.put("modelos", lista);
        out.put("emReproducao", faixa != null);
        call.resolve(out);
    }

    // ---------------------------------------------------------------- download

    @PluginMethod
    public void baixar(PluginCall call) {
        final String id = call.getString("id", "");
        final Voz v = achar(id);
        if (v == null) {
            call.reject("Modelo de voz desconhecido: " + id);
            return;
        }
        if (instalado(v)) {
            JSObject out = new JSObject();
            out.put("id", v.id);
            out.put("instalado", true);
            out.put("jaExistia", true);
            call.resolve(out);
            return;
        }
        synchronized (cancelados) {
            cancelados.remove(v.id);
        }
        final PluginCall pendente = call;
        worker.execute(() -> {
            File destino = pasta(v);
            File temporario = new File(raiz(), v.id + ".tar.bz2.part");
            try {
                if (destino.exists() && !instalado(v)) apagar(destino);
                if (!destino.exists() && !destino.mkdirs()) {
                    throw new IOException("Não consegui criar a pasta da voz.");
                }
                baixarArquivo(v, temporario);
                progresso(v, 0, 0, "extraindo");
                extrair(temporario, destino);
                if (!temporario.delete()) Log.w(TAG, "não consegui apagar o arquivo temporário");
                File modelo = pastaModelo(v);
                if (modelo == null) throw new IOException("O pacote baixado não tem " + v.arquivoOnnx);
                OutputStream m = new FileOutputStream(new File(destino, MARCADOR));
                try {
                    m.write(v.id.getBytes("UTF-8"));
                } finally {
                    m.close();
                }
                JSObject out = new JSObject();
                out.put("id", v.id);
                out.put("instalado", true);
                out.put("disco", tamanho(destino));
                out.put("jaExistia", false);
                pendente.resolve(out);
                notifyListeners("concluido", out);
            } catch (Exception e) {
                temporario.delete();
                apagar(new File(raiz(), v.id));
                String msg = mensagem(e);
                Log.e(TAG, "falha ao baixar voz " + v.id, e);
                pendente.reject("Não consegui baixar a voz: " + msg);
                notifyListeners("erro", objeto("id", v.id, "erro", msg));
            }
        });
    }

    @PluginMethod
    public void cancelar(PluginCall call) {
        String id = call.getString("id", "");
        synchronized (cancelados) {
            cancelados.add(id);
        }
        JSObject out = new JSObject();
        out.put("id", id);
        out.put("cancelado", true);
        call.resolve(out);
    }

    @PluginMethod
    public void remover(PluginCall call) {
        final String id = call.getString("id", "");
        final Voz v = achar(id);
        if (v == null) {
            call.reject("Modelo de voz desconhecido: " + id);
            return;
        }
        worker.execute(() -> {
            synchronized (trava) {
                if (id.equals(motorId)) liberarMotor();
            }
            boolean apagou = apagar(pasta(v));
            JSObject out = new JSObject();
            out.put("id", id);
            out.put("removido", apagou || !pasta(v).exists());
            call.resolve(out);
        });
    }

    private void baixarArquivo(Voz v, File destino) throws IOException {
        HttpURLConnection conexao = null;
        try {
            URL url = new URL(v.url);
            conexao = (HttpURLConnection) url.openConnection();
            conexao.setInstanceFollowRedirects(true);
            conexao.setConnectTimeout(20000);
            conexao.setReadTimeout(30000);
            conexao.setRequestProperty("User-Agent", "JARVIS-Nova/Android");
            conexao.connect();
            int codigo = conexao.getResponseCode();
            if (codigo != HttpURLConnection.HTTP_OK) throw new IOException("HTTP " + codigo);
            long total = conexao.getContentLengthLong();
            if (total <= 0) total = v.bytes;
            InputStream entrada = new BufferedInputStream(conexao.getInputStream(), 65536);
            OutputStream saida = new BufferedOutputStream(new FileOutputStream(destino), 65536);
            byte[] buffer = new byte[65536];
            long recebido = 0;
            int lido;
            long ultimoAviso = 0;
            try {
                while ((lido = entrada.read(buffer)) > 0) {
                    if (cancelado(v.id)) throw new IOException("cancelado");
                    saida.write(buffer, 0, lido);
                    recebido += lido;
                    if (recebido - ultimoAviso > 262144) {
                        ultimoAviso = recebido;
                        progresso(v, recebido, total, "baixando");
                    }
                }
            } finally {
                try {
                    saida.flush();
                    saida.close();
                } catch (IOException e) {
                    // segue: o arquivo pode estar incompleto e a extração vai acusar
                }
                entrada.close();
            }
            if (recebido < 1024) throw new IOException("o download veio vazio");
            progresso(v, recebido, total, "baixando");
        } finally {
            if (conexao != null) conexao.disconnect();
        }
    }

    private boolean cancelado(String id) {
        synchronized (cancelados) {
            return cancelados.contains(id);
        }
    }

    private void progresso(Voz v, long recebido, long total, String fase) {
        JSObject o = new JSObject();
        o.put("id", v.id);
        o.put("recebido", recebido);
        o.put("total", total);
        o.put("fase", fase);
        if (total > 0) o.put("porcentagem", Math.min(100, (int) (recebido * 100 / total)));
        notifyListeners("progresso", o);
    }

    /** Extrai o .tar.bz2 recusando caminhos que escapariam da pasta da voz. */
    private void extrair(File pacote, File destino) throws IOException {
        String prefixo = destino.getCanonicalPath() + File.separator;
        InputStream arquivo = new BufferedInputStream(new java.io.FileInputStream(pacote), 65536);
        try {
            BZip2CompressorInputStream bz = new BZip2CompressorInputStream(arquivo, true);
            TarArchiveInputStream tar = new TarArchiveInputStream(bz);
            try {
                TarArchiveEntry e;
                while ((e = tar.getNextTarEntry()) != null) {
                    if (cancelado(destino.getName())) throw new IOException("cancelado");
                    String nome = e.getName().replace('\\', '/');
                    if (nome.contains("..")) continue;
                    File alvo = new File(destino, nome);
                    if (!alvo.getCanonicalPath().startsWith(prefixo)) continue;
                    if (e.isDirectory()) {
                        if (!alvo.exists() && !alvo.mkdirs()) throw new IOException("pasta: " + nome);
                    } else if (e.isFile()) {
                        File pai = alvo.getParentFile();
                        if (pai != null && !pai.exists() && !pai.mkdirs()) throw new IOException("pasta: " + nome);
                        OutputStream s = new BufferedOutputStream(new FileOutputStream(alvo), 65536);
                        try {
                            byte[] buf = new byte[65536];
                            int n;
                            while ((n = tar.read(buf)) > 0) s.write(buf, 0, n);
                        } finally {
                            s.close();
                        }
                    }
                }
            } finally {
                tar.close();
            }
        } finally {
            arquivo.close();
        }
    }

    // ---------------------------------------------------------------- síntese

    private OfflineTts motorPara(Voz v) throws IOException {
        synchronized (trava) {
            if (motor != null && v.id.equals(motorId)) return motor;
            liberarMotor();
            File dir = pastaModelo(v);
            if (dir == null) throw new IOException("voz ainda não baixada");
            String modelo = new File(dir, v.arquivoOnnx).getAbsolutePath();
            String tokens = new File(dir, "tokens.txt").getAbsolutePath();
            File dados = new File(dir, "espeak-ng-data");
            String dataDir = dados.isDirectory() ? dados.getAbsolutePath() : "";

            OfflineTtsModelConfig mc = new OfflineTtsModelConfig();
            if (v.kokoro) {
                OfflineTtsKokoroModelConfig k = new OfflineTtsKokoroModelConfig();
                k.setModel(modelo);
                k.setTokens(tokens);
                k.setVoices(new File(dir, "voices.bin").getAbsolutePath());
                k.setDataDir(dataDir);
                k.setLexicon("");
                // "en-gb" não existe no espeak-ng empacotado com este modelo: o timbre
                // britânico vem do falante, e a fonetização funciona com "en".
                k.setLang("en");
                k.setLengthScale(1.0f);
                mc.setKokoro(k);
            } else {
                OfflineTtsVitsModelConfig vit = new OfflineTtsVitsModelConfig();
                vit.setModel(modelo);
                vit.setTokens(tokens);
                vit.setDataDir(dataDir);
                mc.setVits(vit);
            }
            mc.setNumThreads(Math.max(2, Math.min(4, Runtime.getRuntime().availableProcessors() - 1)));
            mc.setDebug(false);
            OfflineTtsConfig cfg = new OfflineTtsConfig();
            cfg.setModel(mc);
            cfg.setMaxNumSentences(1);
            // AssetManager nulo: os arquivos estão em caminhos absolutos no armazenamento
            // privado. Com assets não nulo o sherpa tentaria abrir os modelos do APK.
            motor = new OfflineTts((android.content.res.AssetManager) null, cfg);
            motorId = v.id;
            return motor;
        }
    }

    private void liberarMotor() {
        synchronized (trava) {
            try {
                if (motor != null) motor.release();
            } catch (Throwable t) {
                Log.w(TAG, "falha ao liberar motor: " + t.getMessage());
            }
            motor = null;
            motorId = null;
        }
    }

    /** Pré-carrega o modelo para a primeira resposta não esperar a carga. */
    @PluginMethod
    public void aquecer(PluginCall call) {
        final Voz v = achar(call.getString("id", ""));
        if (v == null || !instalado(v)) {
            call.reject("Baixe a voz antes de aquecer o motor.");
            return;
        }
        worker.execute(() -> {
            try {
                motorPara(v);
                JSObject out = new JSObject();
                out.put("id", v.id);
                out.put("pronto", true);
                call.resolve(out);
            } catch (Throwable t) {
                call.reject("Falha ao carregar o motor: " + mensagem(t));
            }
        });
    }

    @PluginMethod
    public void falar(PluginCall call) {
        final String id = call.getString("id", "");
        final String texto = call.getString("texto", "");
        final Voz v = achar(id);
        final int sid = call.getInt("falante", v != null && v.kokoro ? 25 : 0);
        float velocidade = call.getFloat("velocidade", 1.0f).floatValue();
        float tom = call.getFloat("tom", 1.0f).floatValue();
        if (v == null) {
            call.reject("Modelo de voz desconhecido: " + id);
            return;
        }
        if (texto == null || texto.trim().isEmpty()) {
            call.reject("Texto vazio.");
            return;
        }
        if (!instalado(v)) {
            call.reject("A voz " + v.nome + " não está baixada.");
            return;
        }
        if (velocidade < 0.5f) velocidade = 0.5f;
        if (velocidade > 2.0f) velocidade = 2.0f;
        if (tom < 0.6f) tom = 0.6f;
        if (tom > 1.4f) tom = 1.4f;
        final float vel = velocidade;
        final float fTom = tom;
        pararPedido = false;
        worker.execute(() -> {
            try {
                long t0 = System.currentTimeMillis();
                OfflineTts m = motorPara(v);
                GeneratedAudio audio = m.generate(texto, sid, vel);
                float[] amostras = audio.getSamples();
                int taxa = audio.getSampleRate();
                if (amostras == null || amostras.length < 1000) {
                    throw new IOException("o motor não gerou áudio (texto não fonetizável?)");
                }
                amostras = mudarTom(amostras, fTom);
                normalizar(amostras);
                long sintese = System.currentTimeMillis() - t0;
                JSObject info = new JSObject();
                info.put("id", v.id);
                info.put("sinteseMs", sintese);
                info.put("segundos", Math.round(amostras.length * 1000.0 / taxa) / 1000.0);
                notifyListeners("sintetizado", info);
                tocar(amostras, taxa);
                if (pararPedido) {
                    call.reject("fala interrompida");
                } else {
                    call.resolve(info);
                }
            } catch (Throwable t) {
                Log.e(TAG, "falha na síntese", t);
                call.reject("Voz neural falhou: " + mensagem(t));
            }
        });
    }

    /** Solta o modelo da memória (o arquivo continua baixado no aparelho). */
    @PluginMethod
    public void liberar(PluginCall call) {
        worker.execute(() -> {
            liberarMotor();
            JSObject out = new JSObject();
            out.put("liberado", true);
            call.resolve(out);
        });
    }

    @PluginMethod
    public void parar(PluginCall call) {
        pararPedido = true;
        AudioTrack atual = faixa;
        if (atual != null) {
            try {
                atual.pause();
                atual.flush();
                atual.stop();
            } catch (Exception e) {
                Log.w(TAG, "parar: " + e.getMessage());
            }
        }
        JSObject out = new JSObject();
        out.put("parado", atual != null);
        call.resolve(out);
    }

    /**
     * Abaixa o tom reamostrando o áudio gerado. Como não há mudança de taxa de
     * reprodução, a fala fica mais grave e um pouco mais lenta — exatamente a cadência
     * arrastada do J.A.R.V.I.S. do filme.
     */
    private static float[] mudarTom(float[] amostras, float fator) {
        if (fator <= 0f || Math.abs(fator - 1f) < 0.01f) return amostras;
        int n = (int) (amostras.length / fator);
        if (n < 16) return amostras;
        float[] saida = new float[n];
        for (int i = 0; i < n; i++) {
            float pos = i * fator;
            int a = (int) pos;
            float resto = pos - a;
            float x = amostras[Math.min(a, amostras.length - 1)];
            float y = amostras[Math.min(a + 1, amostras.length - 1)];
            saida[i] = x + (y - x) * resto;
        }
        return saida;
    }

    /** Sobe o volume até 90% do máximo, sem distorcer. */
    private static void normalizar(float[] amostras) {
        float pico = 0f;
        for (float a : amostras) pico = Math.max(pico, Math.abs(a));
        if (pico <= 0.001f || pico >= 0.9f) return;
        float ganho = 0.9f / pico;
        for (int i = 0; i < amostras.length; i++) amostras[i] *= ganho;
    }

    private void tocar(float[] amostras, int taxa) throws IOException {
        int bytesBuffer = Math.max(
            AudioTrack.getMinBufferSize(taxa, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_FLOAT),
            amostras.length * 4);
        AudioTrack trilha = new AudioTrack(
            new AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .build(),
            new AudioFormat.Builder()
                .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                .setSampleRate(taxa)
                .build(),
            bytesBuffer,
            AudioTrack.MODE_STREAM,
            android.media.AudioManager.AUDIO_SESSION_ID_GENERATE);
        if (trilha.getState() != AudioTrack.STATE_INITIALIZED) {
            trilha.release();
            throw new IOException("AudioTrack não inicializou");
        }
        faixa = trilha;
        try {
            trilha.play();
            int escritos = 0;
            while (escritos < amostras.length && !pararPedido) {
                int n = Math.min(4096, amostras.length - escritos);
                int r = trilha.write(amostras, escritos, n, AudioTrack.WRITE_BLOCKING);
                if (r <= 0) break;
                escritos += r;
            }
            // Espera o buffer tocar antes de soltar a trilha, senão o fim da frase
            // seria cortado. O limite evita travar se o aparelho não informar posição.
            long limite = System.currentTimeMillis() + (long) (amostras.length * 1000L / taxa) + 5000;
            while (!pararPedido && System.currentTimeMillis() < limite) {
                if (trilha.getPlaybackHeadPosition() >= amostras.length - 1024) break;
                try {
                    Thread.sleep(40);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    break;
                }
            }
        } finally {
            faixa = null;
            try {
                trilha.stop();
            } catch (Exception e) {
                // já parada
            }
            trilha.release();
        }
    }

    // ---------------------------------------------------------------- utilidades

    private static boolean apagar(File f) {
        if (f == null || !f.exists()) return false;
        boolean ok = true;
        if (f.isDirectory()) {
            File[] filhos = f.listFiles();
            if (filhos != null) {
                for (File x : filhos) ok &= apagar(x);
            }
        }
        return f.delete() && ok;
    }

    private static JSObject objeto(String k, Object v, String k2, Object v2) {
        JSObject o = new JSObject();
        o.put(k, v);
        o.put(k2, v2);
        return o;
    }

    private static String mensagem(Throwable t) {
        String m = t.getMessage();
        if (m == null || m.trim().isEmpty()) m = t.getClass().getSimpleName();
        return String.format(Locale.ROOT, "%s", m);
    }
}
