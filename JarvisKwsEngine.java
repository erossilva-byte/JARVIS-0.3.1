package com.jarvis.nova;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;
import android.os.Process;

import androidx.core.content.ContextCompat;

import com.k2fsa.sherpa.onnx.FeatureConfig;
import com.k2fsa.sherpa.onnx.KeywordSpotter;
import com.k2fsa.sherpa.onnx.KeywordSpotterConfig;
import com.k2fsa.sherpa.onnx.KeywordSpotterResult;
import com.k2fsa.sherpa.onnx.OnlineModelConfig;
import com.k2fsa.sherpa.onnx.OnlineStream;
import com.k2fsa.sherpa.onnx.OnlineTransducerModelConfig;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.util.LinkedHashSet;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * KWS acústico local. O microfone é capturado por AudioRecord e inferido pelo
 * sherpa-onnx no próprio aparelho; não usa SpeechRecognizer, rede ou serviço de nuvem.
 *
 * O modelo GigaSpeech é treinado em inglês; "Jarvis" é a palavra-chave configurada.
 * A aceitação de sotaques brasileiros deve ser medida em aparelhos/vozes reais antes
 * de declarar precisão final.
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
    private final float keywordThreshold;
    private final String keywords;
    private final AtomicBoolean running = new AtomicBoolean(false);
    private volatile AudioRecord recorder;
    private volatile Thread worker;
    private volatile KeywordSpotter spotter;
    private volatile OnlineStream stream;

    JarvisKwsEngine(Context context, Listener listener, int sensitivity, String extraKeywords) {
        this.context = context.getApplicationContext();
        this.listener = listener;
        int s = Math.max(0, Math.min(100, sensitivity));
        this.keywordThreshold = s >= 75 ? 0.25f : (s >= 45 ? 0.35f : 0.45f);
        this.keywords = montarPalavrasChave(extraKeywords);
    }

    private String montarPalavrasChave(String extras) {
        LinkedHashSet<String> lista = new LinkedHashSet<>();
        lista.add("Jarvis");
        lista.add("Javis");
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

    synchronized void start() {
        if (running.get()) return;
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
            config.setKeywordsScore(1.5f);
            config.setKeywordsThreshold(keywordThreshold);
            config.setMaxActivePaths(4);
            config.setNumTrailingBlanks(2);
            if (!running.get()) return;
            // Os caminhos do modelo são arquivos absolutos em filesDir; null seleciona newFromFile(),
            // enquanto AssetManager selecionaria newFromAsset() e procuraria esses caminhos nos assets.
            kws = new KeywordSpotter(null, config);
            kwsStream = kws.createStream(keywords);
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
            listener.onState("KWS local ativo · limiar " + keywordThreshold + " · palavras: " + keywords.replace('/', ',') + " · áudio não enviado à rede");

            short[] pcm = new short[Math.max(1600, SAMPLE_RATE / 10)];
            float[] samples = new float[pcm.length];
            while (running.get() && !Thread.currentThread().isInterrupted()) {
                int n = audio.read(pcm, 0, pcm.length, AudioRecord.READ_BLOCKING);
                if (n < 0) throw new IllegalStateException("Falha de leitura do microfone: " + n);
                if (n == 0) continue;
                for (int i = 0; i < n; i++) samples[i] = pcm[i] / 32768.0f;
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
