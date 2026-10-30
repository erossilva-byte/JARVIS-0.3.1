"""Auditoria da integração de IA local (MediaPipe .task) e fallback."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
js = (ROOT / "app.js").read_text(encoding="utf-8")
html = (ROOT / "index.html").read_text(encoding="utf-8")
plugin = (ROOT / "JarvisLocalAIPlugin.java").read_text(encoding="utf-8")
main = (ROOT / "MainActivity.java").read_text(encoding="utf-8")
workflow = (ROOT / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")
gradle_patch = (ROOT / "patch_gradle.py").read_text(encoding="utf-8")
gradle = (ROOT / "android/app/build.gradle").read_text(encoding="utf-8")
doc = (ROOT / "MODELOS-IA-LOCAL.md").read_text(encoding="utf-8")
checks = {
    "Plugin local registrado": "registerPlugin(JarvisLocalAIPlugin.class)" in main,
    "Modelo importado via seletor do sistema": "Intent.ACTION_OPEN_DOCUMENT" in plugin,
    "Modelo restrito ao armazenamento privado": 'new File(getContext().getFilesDir(), "jarvis-models")' in plugin,
    "Tamanho de modelo limitado": "MAX_MODEL_BYTES" in plugin,
    "Inferência roda em worker": "ExecutorService worker" in plugin and "worker.execute" in plugin,
    "API MediaPipe usada para inferência real": "LlmInference.createFromOptions" in plugin and "engine.generateResponse" in plugin,
    "UI permite importar, testar e apagar modelo": all(x in html for x in ['id="c-local-ai-import"', 'id="c-local-ai-test"', 'id="c-local-ai-delete"']),
    "UI permite descarregar sem apagar": 'id="c-local-ai-unload"' in html and "public void unload" in plugin,
    "Fallback local quando APIs não estão configuradas": "const local = await gerarIALocal(conteudo, false)" in js,
    "Modo offline tenta inferência local": "const local = await gerarIALocal(texto, true)" in js,
    "Workflow copia o plugin": "JarvisLocalAIPlugin.java" in workflow,
    "Plugin usa ActivityResult compatível com AndroidX": "import androidx.activity.result.ActivityResult;" in plugin,
    "Toolchain Java 21 alinhada no patch do CI": "AGP atualizado para 8.7.3" in gradle_patch and "gradle-8.9-all.zip" in gradle_patch and "compileSdk" in gradle_patch,
    "Runtime suporta Gemma 3 (>=0.10.22)": "tasks-genai:0.10.24" in gradle_patch and 'tasks-genai:0.10.24' in gradle,
    "Não usa mais o runtime 0.10.14": "tasks-genai:0.10.14" not in gradle_patch and "tasks-genai:0.10.14" not in gradle,
    "Prompt local limitado ao contexto do modelo": "MAX_PROMPT_CHARS = 6000" in plugin and "promptLocal" in js,
    "Prompt local não usa o prompt gigante da nuvem": "promptSistema() + regrasOffline" not in js,
    "Backend CPU explícito (sem crash de GPU)": "delegate GPU" in plugin and "Backend.GPU" not in plugin,
    "Fechamento da engine serializado no worker": "desligando = true" in plugin and "worker.execute(() -> {\n            synchronized (engineLock) { closeEngineLocked(); }" in plugin,
    "Status separa testado de importado": 'out.put("testado"' in plugin and 'out.put("pronto"' in plugin,
    "Status só vira pronto depois de gerar": 'prefs().edit().putBoolean("testado", true)' in plugin,
    "GGUF renomeado é recusado": 'GGUF' in plugin and "não .task do MediaPipe" in plugin,
    "Teste mede o tempo real": "r.ms" in js and "Teste concluído em" in js,
    "Documentação registra a causa raiz": "SIGABRT" in doc and "0.10.24" in doc and "Gemma 3" in doc,
}
for name, ok in checks.items(): print(("OK" if ok else "FALHA") + ": " + name)
if not all(checks.values()): raise SystemExit(1)
print("\nIA local: runtime, contexto, ciclo de vida, estados e recusa de GGUF verificados.")
