package com.jarvis.nova;

import android.content.Context;
import android.content.Intent;
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
import java.io.FileOutputStream;
import java.io.InputStream;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Experimental on-device text inference. Model files are imported by the user and remain app-private. */
@CapacitorPlugin(name = "JarvisLocalAI")
public class JarvisLocalAIPlugin extends Plugin {
    private static final String TAG = "JarvisLocalAI";
    private static final long MAX_MODEL_BYTES = 6L * 1024L * 1024L * 1024L;
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private LlmInference engine;
    private final Object engineLock = new Object();

    private File modelFile() {
        File dir = new File(getContext().getFilesDir(), "jarvis-models");
        if (!dir.exists()) dir.mkdirs();
        return new File(dir, "jarvis-model.task");
    }

    @PluginMethod
    public void status(PluginCall call) {
        File f = modelFile();
        JSObject out = new JSObject();
        out.put("supported", true);
        out.put("installed", f.isFile() && f.length() > 0);
        out.put("bytes", f.isFile() ? f.length() : 0);
        out.put("runtime", "MediaPipe LLM Inference experimental");
        out.put("note", "Importe um modelo .task compatível. O arquivo permanece no armazenamento privado do app.");
        call.resolve(out);
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
            call.reject("Importação de modelo cancelada.");
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
                // Troca atômica com rollback: um erro de rename não deve apagar o modelo funcional anterior.
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
                JSObject out = new JSObject();
                out.put("installed", true); out.put("bytes", total); out.put("name", name);
                call.resolve(out);
            } catch (Exception e) {
                if (temp.exists()) temp.delete();
                call.reject("Falha ao importar modelo: " + (e.getMessage() == null ? "erro desconhecido" : e.getMessage()));
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
        if (prompt.isEmpty()) { call.reject("O prompt está vazio."); return; }
        if (prompt.length() > 14000) prompt = prompt.substring(0, 14000);
        final String finalPrompt = prompt;
        worker.execute(() -> {
            try {
                String response;
                synchronized (engineLock) {
                    File f = modelFile();
                    if (!f.isFile() || f.length() == 0) throw new Exception("Nenhum modelo local foi importado.");
                    if (engine == null) {
                        checarMemoria(f);
                        LlmInference.LlmInferenceOptions options = LlmInference.LlmInferenceOptions.builder()
                            .setModelPath(f.getAbsolutePath())
                            .setMaxTokens(512)
                            .setTemperature(0.35f)
                            .build();
                        engine = LlmInference.createFromOptions(getContext(), options);
                    }
                    response = engine.generateResponse(finalPrompt);
                }
                JSObject out = new JSObject(); out.put("text", response == null ? "" : response.trim()); out.put("local", true);
                call.resolve(out);
            } catch (Throwable e) {
                Log.w(TAG, "Local inference failed", e);
                synchronized (engineLock) { closeEngineLocked(); }
                call.reject("A IA local não conseguiu carregar ou executar esse modelo. Confira se o .task é compatível com MediaPipe e se há memória disponível.");
            }
        });
    }

    @PluginMethod
    public void removeModel(PluginCall call) {
        worker.execute(() -> {
            try {
                synchronized (engineLock) { closeEngineLocked(); }
                File f = modelFile();
                if (f.exists() && !f.delete()) throw new Exception("Não foi possível apagar o arquivo do modelo.");
                call.resolve();
            } catch (Exception e) { call.reject(e.getMessage() == null ? "Falha ao apagar modelo." : e.getMessage()); }
        });
    }

    /**
     * O carregamento de um modelo .task pode pedir mais memória do que o arquivo ocupa.
     * Sem esta checagem o processo morria com OutOfMemoryError nativo — e o app fechava
     * sem explicação. Agora a falha vira mensagem na tela.
     */
    private void checarMemoria(File modelo) throws Exception {
        android.app.ActivityManager am = (android.app.ActivityManager) getContext().getSystemService(Context.ACTIVITY_SERVICE);
        if (am == null) return;
        android.app.ActivityManager.MemoryInfo info = new android.app.ActivityManager.MemoryInfo();
        am.getMemoryInfo(info);
        long precisa = modelo.length() + 256L * 1024L * 1024L;
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
        synchronized (engineLock) { closeEngineLocked(); }
        worker.shutdownNow();
        super.handleOnDestroy();
    }
}
