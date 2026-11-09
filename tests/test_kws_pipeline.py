"""Contrato estático do KWS local e do empacotamento Android."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
service = (ROOT / "JarvisService.java").read_text(encoding="utf-8")
engine = (ROOT / "JarvisKwsEngine.java").read_text(encoding="utf-8")
prepare = (ROOT / "preparar_kws.py").read_text(encoding="utf-8")
release = (ROOT / ".github/workflows/release-apk.yml").read_text(encoding="utf-8")
app = (ROOT / "app.js").read_text(encoding="utf-8")
patch = (ROOT / "patch_gradle.py").read_text(encoding="utf-8")

checks = {
    "serviço não usa Android SpeechRecognizer": "createSpeechRecognizer(" not in service and "createOnDeviceSpeechRecognizer(" not in service,
    "serviço seleciona explicitamente sherpa KWS": 'DETECTOR = "sherpa-onnx-kws-gigaspeech-en"' in service,
    "captura PCM real por AudioRecord": "new AudioRecord(" in engine and "audio.read(" in engine,
    "inferência passa por KeywordSpotter com arquivos locais": "new KeywordSpotter(null, config)" in engine and "kws.decode(kwsStream)" in engine,
    "UI espera confirmação real do serviço antes de mostrar ouvindo": "diagnosticoEscuta()" in app and "estadoKws.escutando" in app,
    "UI transfere microfone ao app e cancela rearme do serviço": "servicoWake.stopWake()" in app and "rearme de segurança do serviço" in app,
    "Novo KWS não herda erro antigo do diagnóstico": 'JarvisPrefs.ultimoErro(ctx, "");' in service,
    "amostras são convertidas para float PCM": "pcm[i] / 32768.0f" in engine,
    "modelo roda em CPU com threads limitadas": '.setProvider("cpu")' in engine and ".setNumThreads(2)" in engine,
    "KWS não faz fallback de rede": "não usa SpeechRecognizer, rede ou serviço de nuvem" in engine,
    "script usa modelo oficial GigaSpeech": "sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01" in prepare,
    "script gera hotwords com tokenizer sherpa": "sherpa-onnx-cli" in prepare and '"--tokens-type", "bpe"' in prepare,
    "modelo e palavras entram nos assets": "src/main/assets/kws" in prepare and '"keywords.txt"' in prepare,
    "release instala tokenizer antes do preparo": "sherpa-onnx==1.13.8" in release and "preparar_kws.py android/app" in release,
    "release exige a classe nativa KWS": "JarvisKwsEngine.java" in release,
    "AAR sherpa é mantido no Gradle": "sherpa-onnx-1.13.8.aar" in patch,
}
for nome, ok in checks.items():
    print(("OK" if ok else "FALHA") + ": " + nome)
if not all(checks.values()):
    raise SystemExit(1)
print(f"{sum(checks.values())}/{len(checks)} verificações do KWS passaram.")
