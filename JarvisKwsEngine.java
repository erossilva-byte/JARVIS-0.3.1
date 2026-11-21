package com.jarvis.nova;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;
import android.os.Process;
import android.os.SystemClock;

import androidx.core.content.ContextCompat;

import com.k2fsa.sherpa.onnx.FeatureConfig;
import com.k2fsa.sherpa.onnx.KeywordSpotter;
import com.k2fsa.sherpa.onnx.KeywordSpotterConfig;
import com.k2fsa.sherpa.onnx.KeywordSpotterResult;
import com.k2fsa.sherpa.onnx.OnlineModelConfig;
import com.k2fsa.sherpa.onnx.OnlineStream;
import com.k2fsa.sherpa.onnx.OnlineTransducerModelConfig;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * KWS acústico local. O microfone é capturado por AudioRecord e inferido pelo
 * sherpa-onnx no próprio aparelho; não usa SpeechRecognizer, rede ou serviço de nuvem.
 *
 * O modelo GigaSpeech é treinado em inglês; "Jarvis" é a palavra-chave configurada.
 * A aceitação de sotaques brasileiros deve ser medida em aparelhos/vozes reais antes
 * de declarar precisão final.
 *
 * As frases em português escolhidas na tela chegam tokenizadas pelo Flutter
 * (`lib/core/hotword_portugues.dart`) e são gravadas sobre o keywords.txt dos
 * assets; só entram linhas cujos tokens existem no tokens.txt do modelo.
 */
final class JarvisKwsEngine {
    interface Listener {
        void onDetected(String keyword);
        void onError(String message);
        void onState(String state);
    }

    static final int SAMPLE_RATE = 16000;
    static final String MODEL_DIR = "kws";
    static final String MODEL_NAME = "sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01";

    private final Context context;
    private final Listener listener;
    /** Teto de frases aceitas ao mesmo tempo (o mesmo da tabela em Dart). */
    static final int LIMITE_FRASES = 16;

    private final float keywordThreshold;
    private final int sensibilidade;
    private final String keywords;
    /** Linhas tokenizadas escolhidas na tela; vazio usa o keywords.txt dos assets. */
    private final String linhasHotword;
    /** Frases realmente em uso, em letras comuns, para o diagnóstico. */
    private volatile String palavrasLegiveis;
    private final AtomicBoolean running = new AtomicBoolean(false);
    private volatile AudioRecord recorder;
    private volatile Thread worker;
    private volatile KeywordSpotter spotter;
    private volatile OnlineStream stream;

    JarvisKwsEngine(Context context, Listener listener, int sensitivity, String extraKeywords) {
        this(context, listener, sensitivity, extraKeywords, "");
    }

    JarvisKwsEngine(Context context, Listener listener, int sensitivity,
                    String extraKeywords, String linhasHotword) {
        this.context = context.getApplicationContext();
        this.listener = listener;
        int s = Math.max(0, Math.min(100, sensitivity));
        this.sensibilidade = s;
        this.keywordThreshold = limiarPara(s);
        this.keywords = montarPalavrasChave(extraKeywords);
        this.linhasHotword = linhasHotword == null ? "" : linhasHotword;
        this.palavrasLegiveis = this.keywords.replace('/', ',');
    }

    /**
     * Limiar acústico para a sensibilidade escolhida (0–100).
     *
     * Mais sensibilidade = limiar menor = o detector aceita uma pronúncia mais
     * distante do modelo, que é o que falta quando ele "não ouve" o “Jarvis”.
     * O padrão do serviço é 75 (limiar 0,25), o mesmo valor de antes.
     */
    static float limiarPara(int sensibilidade) {
        int s = Math.max(0, Math.min(100, sensibilidade));
        if (s >= 85) return 0.20f;
        if (s >= 70) return 0.25f;
        if (s >= 45) return 0.33f;
        if (s >= 20) return 0.42f;
        return 0.50f;
    }

    /** Pontuação das palavras-chave; sobe junto com a sensibilidade. */
    static float pontuacaoPalavra(int sensibilidade) {
        int s = Math.max(0, Math.min(100, sensibilidade));
        if (s >= 85) return 2.0f;
        if (s >= 70) return 1.8f;
        return 1.5f;
    }

    /** Limiar em uso nesta sessão (mostrado no diagnóstico). */
    float limiar() {
        return keywordThreshold;
    }

    private String montarPalavrasChave(String extras) {
        LinkedHashSet<String> lista = new LinkedHashSet<>();
        for (String padrao : new String[]{
                "Jarvis", "Javis", "Jarve", "Jarvi", "Jarviz", "Jarves",
                "Javi", "Javali", "Charles", "Chales", "Chale"
        }) {
            lista.add(padrao);
        }
        if (extras != null) {
            for (String item : extras.split("[,;\\n/]+")) {
                String palavra = item.trim().replaceAll("[^\\p{L}\\p{N} ]", "").replaceAll("\\s+", " ");
                if (palavra.length() >= 3 && palavra.length() <= 40) lista.add(palavra);
                if (lista.size() >= 12) break;
            }
        }
        return String.join("/", lista);
    }

    boolean isRunning() {
        return running.get();
    }

    /** Verdadeiro quando nenhum AudioRecord desta instância está aberto. */
    boolean microfoneLivre() {
        return recorder == null && (worker == null || !worker.isAlive());
    }

    /**
     * Encerra a captura e espera o AudioRecord ser realmente fechado.
     *
     * O reconhecedor do comando só pode abrir o microfone depois disso: dois
     * AudioRecord abertos ao mesmo tempo devolvem silêncio e o Android responde
     * ERROR_AUDIO/ERROR_NO_MATCH mesmo com a fala clara.
     *
     * @return true quando o microfone ficou livre dentro do prazo pedido.
     */
    boolean pararEAguardar(long esperaMs) {
        stop();
        long limite = SystemClock.uptimeMillis() + Math.max(0L, esperaMs);
        while (SystemClock.uptimeMillis() < limite) {
            if (microfoneLivre()) return true;
            try {
                Thread.sleep(40L);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            }
        }
        return microfoneLivre();
    }

    /** Sessão de áudio do AudioRecord atual; 0 quando ainda não há captura. */
    int sessaoAudio() {
        AudioRecord atual = recorder;
        if (atual == null) return 0;
        try { return atual.getAudioSessionId(); } catch (Throwable e) { return 0; }
    }

    synchronized void start() {
        if (running.get()) return;
        Thread anterior = worker;
        if (anterior != null && anterior.isAlive()) {
            try { anterior.join(1200); }
            catch (InterruptedException e) { Thread.currentThread().interrupt(); }
            if (anterior.isAlive()) {
                listener.onError("O detector anterior ainda está encerrando; evitei iniciar dois microfones simultaneamente.");
                return;
            }
        }
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
                != PackageManager.PERMISSION_GRANTED) {
            listener.onError("Permissão de microfone não concedida.");
            return;
        }
        running.set(true);
        worker = new Thread(this::runLoop, "Jarvis-KWS");
        worker.start();
    }

    synchronized void stop() {
        running.set(false);
        AudioRecord current = recorder;
        if (current != null) {
            try { if (current.getRecordingState() == AudioRecord.RECORDSTATE_RECORDING) current.stop(); }
            catch (Exception ignored) { }
        }
        Thread t = worker;
        if (t != null && t != Thread.currentThread()) {
            t.interrupt();
            try { t.join(1200); } catch (InterruptedException e) { Thread.currentThread().interrupt(); }
        }
    }

    private void runLoop() {
        AudioRecord audio = null;
        KeywordSpotter kws = null;
        OnlineStream kwsStream = null;
        try {
            Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO);
            listener.onState("Preparando detector acústico local");
            File dir = new File(context.getFilesDir(), MODEL_DIR);
            instalarAssets(dir);
            gravarPalavrasChave(dir);

            String base = dir.getAbsolutePath() + File.separator;
            // O AAR Android oficial expõe a Kotlin API (data classes + AssetManager),
            // não a Java API baseada em Builder. Configure pelos setters gerados pelo Kotlin.
            OnlineTransducerModelConfig transducer = new OnlineTransducerModelConfig();
            transducer.setEncoder(base + "encoder-epoch-12-avg-2-chunk-16-left-64.int8.onnx");
            transducer.setDecoder(base + "decoder-epoch-12-avg-2-chunk-16-left-64.onnx");
            transducer.setJoiner(base + "joiner-epoch-12-avg-2-chunk-16-left-64.int8.onnx");

            OnlineModelConfig model = new OnlineModelConfig();
            model.setTransducer(transducer);
            model.setTokens(base + "tokens.txt");
            model.setNumThreads(2);
            model.setDebug(false);
            model.setProvider("cpu");
            model.setModelType("zipformer2");

            FeatureConfig features = new FeatureConfig();
            features.setSampleRate(SAMPLE_RATE);
            features.setFeatureDim(80);
            KeywordSpotterConfig config = new KeywordSpotterConfig();
            config.setFeatConfig(features);
            config.setModelConfig(model);
            config.setKeywordsFile(base + "keywords.txt");
            config.setKeywordsScore(pontuacaoPalavra(sensibilidade));
            config.setKeywordsThreshold(keywordThreshold);
            config.setMaxActivePaths(8);
            config.setNumTrailingBlanks(2);
            if (!running.get()) return;
            // Os caminhos do modelo são arquivos absolutos em filesDir; null seleciona newFromFile(),
            // enquanto AssetManager selecionaria newFromAsset() e procuraria esses caminhos nos assets.
            kws = new KeywordSpotter(null, config);
            // String vazia usa o keywords.txt tokenizado em BPE preparado nos assets.
            // Passar "Jarvis/Javis" em texto puro faz EncodeKeywords falhar e
            // createStream devolver um ponteiro nulo.
            kwsStream = kws.createStream("");
            if (!running.get()) return;

            int minBuffer = AudioRecord.getMinBufferSize(SAMPLE_RATE,
                    AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT);
            if (minBuffer <= 0) throw new IllegalStateException("AudioRecord retornou tamanho de buffer inválido: " + minBuffer);
            int bufferBytes = Math.max(minBuffer * 2, SAMPLE_RATE / 5 * 2);
            audio = new AudioRecord(MediaRecorder.AudioSource.VOICE_RECOGNITION,
                    SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT, bufferBytes);
            if (audio.getState() != AudioRecord.STATE_INITIALIZED) {
                throw new IllegalStateException("Não foi possível inicializar o microfone para KWS.");
            }
            recorder = audio;
            if (!running.get()) return;
            audio.startRecording();
            if (audio.getRecordingState() != AudioRecord.RECORDSTATE_RECORDING) {
                throw new IllegalStateException("O microfone não entrou em estado de gravação.");
            }
            spotter = kws;
            stream = kwsStream;
            listener.onState("KWS local ativo · limiar " + keywordThreshold + " · palavras: " + palavrasLegiveis + " · áudio não enviado à rede");

            short[] pcm = new short[Math.max(1600, SAMPLE_RATE / 10)];
            float[] samples = new float[pcm.length];
            float ganho = 1f;
            while (running.get() && !Thread.currentThread().isInterrupted()) {
                int n = audio.read(pcm, 0, pcm.length, AudioRecord.READ_BLOCKING);
                if (n < 0) throw new IllegalStateException("Falha de leitura do microfone: " + n);
                if (n == 0) continue;
                ganho = aplicarGanho(pcm, n, samples, ganho);
                float[] frame = new float[n];
                System.arraycopy(samples, 0, frame, 0, n);
                kwsStream.acceptWaveform(frame, SAMPLE_RATE);
                while (kws.isReady(kwsStream)) {
                    kws.decode(kwsStream);
                    KeywordSpotterResult result = kws.getResult(kwsStream);
                    String keyword = result == null ? "" : result.getKeyword();
                    if (keyword != null && !keyword.trim().isEmpty()) {
                        kws.reset(kwsStream);
                        running.set(false);
                        listener.onDetected(keyword.trim());
                        return;
                    }
                }
            }
        } catch (Throwable e) {
            if (running.get()) {
                String message = e.getMessage() == null ? e.getClass().getSimpleName() : e.getMessage();
                listener.onError("Falha no KWS local: " + message);
            }
        } finally {
            running.set(false);
            recorder = null;
            stream = null;
            spotter = null;
            if (audio != null) {
                try { if (audio.getRecordingState() == AudioRecord.RECORDSTATE_RECORDING) audio.stop(); } catch (Exception ignored) { }
                try { audio.release(); } catch (Exception ignored) { }
            }
            if (kwsStream != null) {
                try { kwsStream.release(); } catch (Exception ignored) { }
            }
            if (kws != null) {
                try { kws.release(); } catch (Exception ignored) { }
            }
            worker = null;
        }
    }

    /**
     * Converte o PCM em float com ganho automático suave.
     *
     * O detector é treinado em inglês e a palavra dita em português, de longe do
     * microfone, chega baixa e é rejeitada. Aqui a fala fraca sobe até 4x e a fala
     * normal fica em 1x, com transição suave para não “bombear” o volume. O sinal
     * é limitado a ±1 para não estourar a entrada do modelo.
     */
    private static float aplicarGanho(short[] pcm, int n, float[] destino, float anterior) {
        double soma = 0;
        for (int i = 0; i < n; i++) {
            float amostra = pcm[i] / 32768.0f;
            soma += (double) amostra * amostra;
        }
        double rms = Math.sqrt(soma / Math.max(1, n));
        float alvo = 1f;
        if (rms > 0.0005 && rms < 0.02) {
            alvo = (float) Math.min(4.0, 0.02 / rms);
        }
        float ganho = anterior * 0.7f + alvo * 0.3f;
        for (int i = 0; i < n; i++) {
            float amostra = (pcm[i] / 32768.0f) * ganho;
            if (amostra > 1f) amostra = 1f;
            else if (amostra < -1f) amostra = -1f;
            destino[i] = amostra;
        }
        return ganho;
    }

    /**
     * Grava as frases escolhidas na tela por cima do keywords.txt dos assets.
     *
     * O Flutter manda as linhas já tokenizadas. Aqui a linha só é aceita se
     * todos os tokens existirem no tokens.txt do modelo: uma linha inválida
     * faria o KeywordSpotter falhar na criação, então é descartada em vez de
     * derrubar o detector. Sem nenhuma linha válida, o arquivo dos assets
     * continua valendo — é o conjunto de fábrica.
     *
     * @return quantas frases foram gravadas.
     */
    private int gravarPalavrasChave(File dir) {
        palavrasLegiveis = keywords.replace('/', ',');
        if (linhasHotword == null || linhasHotword.trim().isEmpty()) return 0;
        Set<String> vocabulario = lerVocabulario(new File(dir, "tokens.txt"));
        if (vocabulario.isEmpty()) return 0;
        List<String> validas = new ArrayList<>();
        for (String bruta : linhasHotword.split("\n")) {
            String linha = bruta.trim().replaceAll("\\s+", " ");
            if (linha.isEmpty() || validas.contains(linha)) continue;
            boolean completa = true;
            for (String token : linha.split(" ")) {
                if (!vocabulario.contains(token)) {
                    completa = false;
                    break;
                }
            }
            if (completa) validas.add(linha);
            if (validas.size() >= LIMITE_FRASES) break;
        }
        if (validas.isEmpty()) return 0;
        File alvo = new File(dir, "keywords.txt");
        File temp = new File(dir, "keywords.txt.part");
        try (FileOutputStream out = new FileOutputStream(temp)) {
            out.write((String.join("\n", validas) + "\n").getBytes(StandardCharsets.UTF_8));
            out.getFD().sync();
        } catch (Throwable e) {
            temp.delete();
            return 0;
        }
        if (!temp.renameTo(alvo)) {
            temp.delete();
            return 0;
        }
        StringBuilder legivel = new StringBuilder();
        for (String linha : validas) {
            if (legivel.length() > 0) legivel.append(", ");
            legivel.append(fraseLegivel(linha));
        }
        palavrasLegiveis = legivel.toString();
        return validas.size();
    }

    /** Junta os tokens de uma linha em letras comuns ("▁E I ▁JA R VI S" → "EI JARVIS"). */
    static String fraseLegivel(String linha) {
        StringBuilder sb = new StringBuilder();
        for (String token : linha.split(" ")) {
            if (token.isEmpty()) continue;
            boolean inicio = token.startsWith("▁");
            if (inicio && sb.length() > 0) sb.append(' ');
            sb.append(inicio ? token.substring(1) : token);
        }
        return sb.toString();
    }

    /** Lê o vocabulário do modelo: o primeiro campo de cada linha do tokens.txt. */
    private static Set<String> lerVocabulario(File arquivo) {
        Set<String> vocabulario = new HashSet<>();
        if (!arquivo.isFile()) return vocabulario;
        try (BufferedReader leitor = new BufferedReader(
                new InputStreamReader(new FileInputStream(arquivo), StandardCharsets.UTF_8))) {
            String linha;
            while ((linha = leitor.readLine()) != null) {
                String[] partes = linha.trim().split("\\s+");
                if (partes.length > 0 && !partes[0].isEmpty()) vocabulario.add(partes[0]);
            }
        } catch (Throwable ignorado) {
            // Sem vocabulário legível a escolha da tela não é aplicada; o
            // conjunto dos assets continua valendo.
        }
        return vocabulario;
    }

    private void instalarAssets(File dir) throws Exception {
        if (!dir.exists() && !dir.mkdirs()) throw new IllegalStateException("Não foi possível criar a pasta do modelo KWS.");
        String[] nomes = {
                "encoder-epoch-12-avg-2-chunk-16-left-64.int8.onnx",
                "decoder-epoch-12-avg-2-chunk-16-left-64.onnx",
                "joiner-epoch-12-avg-2-chunk-16-left-64.int8.onnx",
                "tokens.txt",
                "keywords.txt"
        };
        for (String nome : nomes) {
            File destino = new File(dir, nome);
            if (destino.isFile() && destino.length() > 0) continue;
            File temp = new File(dir, nome + ".part");
            try (InputStream in = context.getAssets().open(MODEL_DIR + "/" + nome);
                 FileOutputStream out = new FileOutputStream(temp)) {
                byte[] buffer = new byte[64 * 1024];
                int lido;
                while ((lido = in.read(buffer)) != -1) out.write(buffer, 0, lido);
                out.getFD().sync();
            }
            if (!temp.renameTo(destino)) {
                temp.delete();
                throw new IllegalStateException("Não foi possível instalar o arquivo do KWS: " + nome);
            }
        }
    }
}
