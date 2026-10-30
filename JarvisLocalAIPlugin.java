package com.jarvis.nova;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.net.Uri;
import android.provider.OpenableColumns;
import android.util.Log;

import androidx.activity.result.ActivityResult;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.ActivityCallback;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.google.mediapipe.tasks.genai.llminference.LlmInference;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Inferência de texto no aparelho com MediaPipe LLM Inference (modelos .task compatíveis). */
@CapacitorPlugin(name = "JarvisLocalAI")
public class JarvisLocalAIPlugin extends Plugin {
    private static final String TAG = "JarvisLocalAI";
    private static final long MAX_MODEL_BYTES = 6L * 1024L * 1024L * 1024L;
    /** Contexto do .task q4_ekv2048: 2048 tokens. Prompt acima disso estoura o KV cache. */
    private static final int MAX_PROMPT_CHARS = 6000;
    private static final String PREF = "jarvis_local_ai";

    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private LlmInference engine;
    private final Object engineLock = new Object();
    /** Uma geração por vez: dois interpreters simultâneos derrubavam o processo. */
    private volatile boolean gerando = false;
    /** Durante onDestroy o worker pode estar gerando; fechar a engine agora seria crash nativo. */
    private volatile boolean desligando = false;

    private File modelFile() {
        File dir = new File(getContext().getFilesDir(), "jarvis-models");
        if (!dir.exists()) dir.mkdirs();
        return new File(dir, "jarvis-model.task");
    }

    private SharedPreferences prefs() {
        return getContext().getSharedPreferences(PREF, Context.MODE_PRIVATE);
    }

    private void responder(PluginCall call, JSObject out) {
        android.app.Activity a = getActivity();
        if (a != null) a.runOnUiThread(() -> call.resolve(out));
        else call.resolve(out);
    }

    private void recusar(PluginCall call, String msg) {
        android.app.Activity a = getActivity();
        if (a != null) a.runOnUiThread(() -> call.reject(msg));
        else call.reject(msg);
    }

    @PluginMethod
    public void status(PluginCall call) {
        File f = modelFile();
        boolean existe = f.isFile() && f.length() > 0;
        String motivo = existe ? validarModelo(f) : "Nenhum modelo importado.";
        boolean valida = existe && motivo.isEmpty();
        JSObject out = new JSObject();
        out.put("supported", true);
        out.put("installed", valida);
        out.put("valida", valida);
        out.put("bytes", f.isFile() ? f.length() : 0);
        out.put("motivo", motivo);
        // "pronto" só depois de uma geração real bem-sucedida; importar não prova nada.
        out.put("testado", valida && prefs().getBoolean("testado", false));
        out.put("pronto", valida && prefs().getBoolean("testado", false));
        out.put("carregado", engine != null);
        out.put("modelo", prefs().getString("modelo", ""));
        out.put("api", "tasks-genai 0.10.24");
        out.put("contexto", "2048 tokens (q4_ekv2048)");
        out.put("runtime", "MediaPipe LLM Inference · CPU");
        out.put("note", "Importe um .task compatível (Gemma 3 1B IT funciona a partir do runtime 0.10.22). O arquivo fica no armazenamento privado do app.");
        responder(call, out);
    }

    @PluginMethod
    public void chooseModel(PluginCall call) {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("*/*");
        intent.putExtra(Intent.EXTRA_TITLE, "Selecionar modelo J.A.R.V.I.S. (.task)");
        startActivityForResult(call, intent, "modelSelected");
    }

    @ActivityCallback
    private void modelSelected(PluginCall call, ActivityResult result) {
        if (call == null) return;
        if (result == null || result.getResultCode() != android.app.Activity.RESULT_OK || result.getData() == null || result.getData().getData() == null) {
            recusar(call, "Importação de modelo cancelada.");
            return;
        }
        Uri uri = result.getData().getData();
        worker.execute(() -> {
            File target = modelFile();
            File temp = new File(target.getParentFile(), "jarvis-model.task.part");
            try {
                String name = displayName(uri);
                if (name == null || !name.toLowerCase(java.util.Locale.ROOT).endsWith(".task")) {
                    throw new Exception("Selecione um modelo compatível com MediaPipe, com extensão .task.");
                }
                long available = target.getParentFile().getUsableSpace();
                if (available < 512L * 1024L * 1024L) throw new Exception("Há menos de 512 MB livres. Libere armazenamento antes de importar o modelo.");
                long total = 0;
                try (InputStream in = getContext().getContentResolver().openInputStream(uri);
                     FileOutputStream out = new FileOutputStream(temp)) {
                    if (in == null) throw new Exception("Não foi possível abrir o arquivo selecionado.");
                    byte[] buf = new byte[1024 * 1024];
                    int n;
                    while ((n = in.read(buf)) != -1) {
                        total += n;
                        if (total > MAX_MODEL_BYTES) throw new Exception("Modelo acima do limite de 6 GB desta versão.");
                        out.write(buf, 0, n);
                    }
                    out.getFD().sync();
                }
                if (total < 1024 * 1024) throw new Exception("O arquivo é pequeno demais para ser um modelo de linguagem válido.");
                synchronized (engineLock) { closeEngineLocked(); }
                File backup = new File(target.getParentFile(), "jarvis-model.task.bak");
                if (backup.exists() && !backup.delete()) throw new Exception("Não foi possível limpar o backup antigo do modelo.");
                boolean hadTarget = target.isFile();
                if (hadTarget && !target.renameTo(backup)) throw new Exception("Não foi possível preparar a substituição do modelo anterior.");
                if (!temp.renameTo(target)) {
                    if (hadTarget) backup.renameTo(target);
                    throw new Exception("Não foi possível finalizar a importação; o modelo anterior foi preservado quando possível.");
                }
                if (backup.exists()) backup.delete();
                prefs().edit().putString("modelo", name).putBoolean("testado", false).apply();
                JSObject out = new JSObject();
                out.put("installed", true); out.put("bytes", total); out.put("name", name);
                out.put("validado", true);
                responder(call, out);
            } catch (Exception e) {
                if (temp.exists()) temp.delete();
                recusar(call, "Falha ao importar modelo: " + (e.getMessage() == null ? "erro desconhecido" : e.getMessage()));
            }
        });
    }

    private String displayName(Uri uri) {
        Cursor c = null;
        try {
            c = getContext().getContentResolver().query(uri, new String[]{OpenableColumns.DISPLAY_NAME}, null, null, null);
            if (c != null && c.moveToFirst()) {
                int i = c.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                if (i >= 0) return c.getString(i);
            }
        } catch (Exception ignored) { }
        finally { if (c != null) c.close(); }
        return uri.getLastPathSegment();
    }

    @PluginMethod
    public void generate(PluginCall call) {
        String prompt = call.getString("prompt", "").trim();
        if (prompt.isEmpty()) { recusar(call, "O prompt está vazio."); return; }
        if (prompt.length() > MAX_PROMPT_CHARS) {
            recusar(call, "O prompt tem " + prompt.length() + " caracteres e passaria do contexto de 2048 tokens deste modelo. Envie um pedido mais curto (até " + MAX_PROMPT_CHARS + " caracteres).");
            return;
        }
        final String finalPrompt = prompt;
        worker.execute(() -> {
            if (desligando) { recusar(call, "O aplicativo está sendo encerrado; a inferência local foi cancelada."); return; }
            if (gerando) {
                recusar(call, "Já existe uma geração local em andamento. Aguarde a resposta atual terminar.");
                return;
            }
            gerando = true;
            try {
                String response;
                synchronized (engineLock) {
                    File f = modelFile();
                    if (!f.isFile() || f.length() == 0) throw new Exception("Nenhum modelo local foi importado.");
                    String problema = validarModelo(f);
                    if (!problema.isEmpty()) throw new Exception(problema);
                    if (engine == null) {
                        checarMemoria(f);
                        // CPU por escolha deliberada: o delegate GPU do MediaPipe em Mali/Adreno
                        // era mais uma fonte de SIGABRT e não é necessário para 1B.
                        LlmInference.LlmInferenceOptions options = LlmInference.LlmInferenceOptions.builder()
                            .setModelPath(f.getAbsolutePath())
                            .setMaxTokens(512)
                            .setPreferredBackend(LlmInference.Backend.CPU)
                            .build();
                        engine = LlmInference.createFromOptions(getContext(), options);
                    }
                    response = engine.generateResponse(finalPrompt);
                }
                String texto = response == null ? "" : response.trim();
                if (texto.isEmpty()) throw new Exception("O modelo abriu, mas não devolveu texto. Tente novamente ou use outro .task.");
                prefs().edit().putBoolean("testado", true).putLong("ultimo_ms", System.currentTimeMillis()).apply();
                JSObject out = new JSObject();
                out.put("text", texto); out.put("local", true); out.put("pronto", true);
                responder(call, out);
            } catch (Throwable e) {
                Log.w(TAG, "Local inference failed", e);
                synchronized (engineLock) { closeEngineLocked(); }
                String detalhe;
                if (e instanceof OutOfMemoryError) {
                    detalhe = "memória esgotada ao abrir o modelo";
                } else if (e.getMessage() != null && !e.getMessage().isEmpty()) {
                    detalhe = e.getMessage();
                } else {
                    detalhe = "falha nativa do MediaPipe (modelo incompatível com esta versão da biblioteca ou ABI)";
                }
                recusar(call, "A IA local não conseguiu carregar ou executar esse modelo: " + detalhe +
                    ". O app continua funcionando com os provedores em nuvem.");
            } finally {
                gerando = false;
            }
        });
    }

    /** Descarrega da memória sem apagar o arquivo: o modelo continua importado. */
    @PluginMethod
    public void unload(PluginCall call) {
        worker.execute(() -> {
            synchronized (engineLock) { closeEngineLocked(); }
            JSObject out = new JSObject();
            out.put("carregado", false);
            out.put("pronto", prefs().getBoolean("testado", false));
            responder(call, out);
        });
    }

    @PluginMethod
    public void removeModel(PluginCall call) {
        worker.execute(() -> {
            try {
                synchronized (engineLock) { closeEngineLocked(); }
                File f = modelFile();
                if (f.exists() && !f.delete()) throw new Exception("Não foi possível apagar o arquivo do modelo.");
                prefs().edit().remove("modelo").putBoolean("testado", false).putLong("ultimo_ms", 0).apply();
                responder(call, new JSObject());
            } catch (Exception e) { recusar(call, e.getMessage() == null ? "Falha ao apagar modelo." : e.getMessage()); }
        });
    }

    /**
     * Pré-checagem do arquivo antes de chamar o nativo.
     *
     * O .task do MediaPipe é um pacote (ZIP). Arquivo truncado/vazio ou GGUF renomeado
     * fazia o interpretador nascer nulo e o processo morrer com SIGABRT — try/catch Java
     * não pega isso, então o certo é nunca chamar o nativo nesses casos.
     */
    private String validarModelo(File f) {
        if (!f.isFile() || f.length() == 0) return "Arquivo do modelo ausente ou vazio.";
        if (f.length() < 1024L * 1024L) return "Arquivo pequeno demais para ser um modelo de linguagem.";
        if (!f.canRead()) return "Sem permissão de leitura no arquivo do modelo.";
        byte[] cabecalho = new byte[4];
        try (FileInputStream in = new FileInputStream(f)) {
            int lidos = in.read(cabecalho);
            if (lidos < 4) return "Arquivo do modelo truncado.";
        } catch (Exception e) {
            return "Não foi possível ler o início do modelo: " + (e.getMessage() == null ? "erro de I/O" : e.getMessage());
        }
        if (cabecalho[0] == 'G' && cabecalho[1] == 'G' && cabecalho[2] == 'U' && cabecalho[3] == 'F') {
            return "Este arquivo é GGUF, não .task do MediaPipe. Exporte o modelo para o formato .task.";
        }
        boolean zip = cabecalho[0] == 0x50 && cabecalho[1] == 0x4B;
        boolean flat = cabecalho[0] == 'T' && cabecalho[1] == 'F' && cabecalho[2] == 'L' && cabecalho[3] == '3';
        if (!zip && !flat) return "O arquivo não parece um modelo MediaPipe (.task): o cabeçalho não é ZIP nem TFL3.";
        return "";
    }

    private void checarMemoria(File modelo) throws Exception {
        android.app.ActivityManager am = (android.app.ActivityManager) getContext().getSystemService(Context.ACTIVITY_SERVICE);
        if (am == null) return;
        android.app.ActivityManager.MemoryInfo info = new android.app.ActivityManager.MemoryInfo();
        am.getMemoryInfo(info);
        // O runtime aloca pesos + KV cache + buffers: o arquivo sozinho não é a conta.
        long precisa = modelo.length() + 512L * 1024L * 1024L;
        if (info.availMem < precisa) {
            throw new Exception("Memória livre insuficiente para carregar o modelo: "
                + (info.availMem / (1024 * 1024)) + " MB livres, cerca de "
                + (precisa / (1024 * 1024)) + " MB necessários. Feche outros apps e tente de novo.");
        }
    }

    private void closeEngineLocked() {
        if (engine != null) { try { engine.close(); } catch (Exception ignored) { } engine = null; }
    }

    @Override
    protected void handleOnDestroy() {
        desligando = true;
        // Enfileira o fechamento no MESMO worker: se houver geração em curso, ela termina
        // antes de a engine ser liberada. Fechar de outra thread no meio = SIGSEGV nativo.
        worker.execute(() -> {
            synchronized (engineLock) { closeEngineLocked(); }
        });
        worker.shutdown();
        super.handleOnDestroy();
    }
}
