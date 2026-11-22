"""Contrato de versão e proteção contra status falsamente concluído na 1.46.0."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
pkg = json.loads((ROOT / "package.json").read_text(encoding="utf-8"))
version = json.loads((ROOT / "VERSAO.json").read_text(encoding="utf-8"))
app = (ROOT / "app.js").read_text(encoding="utf-8")
service = (ROOT / "JarvisService.java").read_text(encoding="utf-8")
engine = (ROOT / "JarvisKwsEngine.java").read_text(encoding="utf-8")
html = (ROOT / "index.html").read_text(encoding="utf-8")
release = (ROOT / ".github/workflows/release-apk.yml").read_text(encoding="utf-8")
ci = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
docs = (ROOT / "docs/DIAGNOSTICO-1.46-FLUTTER-DART.md").read_text(encoding="utf-8")

checks = {
    "package e VERSAO.json concordam": pkg["version"] == version["version"] == "1.46.0",
    "versionCode é 10460": version["versionCode"] == 10460,
    "app.js usa a mesma versão": "const VERSAO_APP = '1.46.0';" in app,
    "APK continua pendente até build real": version["build"]["resultado"] == "pendente",
    "Windows continua pendente até build real": version["pc"]["build"]["resultado"] == "pendente",
    "KWS não usa SpeechRecognizer no serviço de wake": "SpeechRecognizer.create" not in service,
    "AudioRecord e sherpa estão conectados": "new AudioRecord(" in engine and "new KeywordSpotter(null, config)" in engine,
    "UI informa que o modelo KWS é inglês": "treinado em inglês" in html,
    "workflow instala Python e tokenizer": "setup-python@v5" in release and "sherpa-onnx==1.13.8" in release,
    "workflow prepara modelo e exige assets": "preparar_kws.py android/app" in release and "assets/kws/keywords.txt" in release,
    "CI tem job de compilação Android": "android-build:" in ci and "./gradlew assembleDebug" in ci,
    "documentação não declara validação física concluída": "precisão PT-BR" in docs and "ainda precisa ser medida" in docs,
}
for nome, ok in checks.items():
    print(("OK" if ok else "FALHA") + ": " + nome)
if not all(checks.values()):
    raise SystemExit(1)
print(f"{sum(checks.values())}/{len(checks)} verificações da 1.46.0 aprovadas.")
