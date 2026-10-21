"""Static checks for the experimental on-device LLM integration and fallback."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
js = (ROOT / "app.js").read_text(encoding="utf-8")
html = (ROOT / "index.html").read_text(encoding="utf-8")
plugin = (ROOT / "JarvisLocalAIPlugin.java").read_text(encoding="utf-8")
main = (ROOT / "MainActivity.java").read_text(encoding="utf-8")
workflow = (ROOT / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")
checks = {
    "Plugin local registrado": "registerPlugin(JarvisLocalAIPlugin.class)" in main,
    "Modelo importado via seletor do sistema": "Intent.ACTION_OPEN_DOCUMENT" in plugin,
    "Modelo restrito ao armazenamento privado": 'new File(getContext().getFilesDir(), "jarvis-models")' in plugin,
    "Tamanho de modelo limitado": "MAX_MODEL_BYTES" in plugin,
    "Inferência roda em worker": "ExecutorService worker" in plugin and "worker.execute" in plugin,
    "API MediaPipe usada para inferência real": "LlmInference.createFromOptions" in plugin and "engine.generateResponse" in plugin,
    "UI permite importar, testar e apagar modelo": all(x in html for x in ['id="c-local-ai-import"', 'id="c-local-ai-test"', 'id="c-local-ai-delete"']),
    "Fallback local quando APIs não estão configuradas": "const local = await gerarIALocal(conteudo, false)" in js,
    "Modo offline tenta inferência local": "const local = await gerarIALocal(texto, true)" in js,
    "Workflow copia o plugin": "JarvisLocalAIPlugin.java" in workflow,
    "Plugin usa ActivityResult compatível com AndroidX": "import androidx.activity.result.ActivityResult;" in plugin,
    "MediaPipe compatível com JDK 17 fixado": "tasks-genai:0.10.14" in (ROOT / "patch_gradle.py").read_text(encoding="utf-8"),
}
for name, ok in checks.items(): print(("OK" if ok else "FALHA") + ": " + name)
if not all(checks.values()): raise SystemExit(1)
