"""Contrato de versão e proteção contra status falsamente concluído.

Nasceu na 1.46.0, mas a versão não fica presa aqui: o teste lê o VERSAO.json e exige
que package.json, VERSAO.json e VERSAO_APP digam a mesma coisa, com versionCode
coerente. Assim a versão pode subir sem reescrever este arquivo, e continua valendo a
regra de nunca declarar build concluído sem evidência.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
pkg = json.loads((ROOT / "package.json").read_text(encoding="utf-8"))
version = json.loads((ROOT / "VERSAO.json").read_text(encoding="utf-8"))
app = (ROOT / "app.js").read_text(encoding="utf-8")
service = (ROOT / "JarvisService.java").read_text(encoding="utf-8")
engine = (ROOT / "JarvisKwsEngine.java").read_text(encoding="utf-8")
html = (ROOT / "index.html").read_text(encoding="utf-8")
pubspec = (ROOT / "flutter_app" / "pubspec.yaml").read_text(encoding="utf-8")
release = (ROOT / ".github/workflows/release-apk.yml").read_text(encoding="utf-8")
ci = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
docs = (ROOT / "docs/DIAGNOSTICO-1.46-FLUTTER-DART.md").read_text(encoding="utf-8")

checks = {
    "package e VERSAO.json concordam": pkg["version"] == version["version"] == version.get("versao"),
    # O versionCode do build sai do `+NNNN` do pubspec; aqui ele precisa ser o mesmo.
    "versionCode acompanha o pubspec": version["versionCode"] == int(re.search(r"version:\s*[\d.]+\+(\d+)", pubspec).group(1)),
    "versionCode é pelo menos 10460": version["versionCode"] >= 10460,
    "app.js usa a mesma versão": ("const VERSAO_APP = '%s';" % version["version"]) in app,
    "interface mostra a mesma versão": ('v' + version["version"]) in html,
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
print(f"{sum(checks.values())}/{len(checks)} verificações de versão e status aprovadas ({version['version']}).")
