"""Garante que o APK publicado sai assinado com a chave de release, nunca com a de debug.

A chave de debug do repositório é pública (está em ci/debug.keystore). Um APK
publicado com ela pode ser substituído por qualquer pessoa que também tenha o
arquivo, então o workflow de release precisa falhar quando as credenciais de
release não estiverem configuradas.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
release = (ROOT / ".github/workflows/release-apk.yml").read_text(encoding="utf-8")
build = (ROOT / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")
patch = (ROOT / "patch_gradle.py").read_text(encoding="utf-8")
atualiza = (ROOT / "JarvisUpdatePlugin.java").read_text(encoding="utf-8")

checks = {
    "Release compila o variant release": "assembleRelease" in release,
    "Release não compila o variant debug": "assembleDebug" not in release,
    "Keystore de release vem de segredo": (
        "ANDROID_KEYSTORE_BASE64" in release and "base64 -d" in release),
    "Release falha sem o keystore": "ANDROID_KEYSTORE_BASE64 ausente" in release,
    "Senha, alias e chave também são exigidos": all(
        t in release for t in (
            "ANDROID_KEYSTORE_PASSWORD", "ANDROID_KEY_ALIAS", "ANDROID_KEY_PASSWORD")),
    "Assinatura conferida com apksigner": (
        "apksigner" in release and "--print-certs" in release),
    "Chave de debug é recusada na publicação": "CN=Android Debug" in release,
    "APK publicado é o de release": (
        "app/build/outputs/apk/release/app-release.apk" in release),
    "Gradle lê a chave do ambiente": all(
        t in patch for t in (
            "JARVIS_KEYSTORE_PATH", "JARVIS_KEYSTORE_PASSWORD",
            "JARVIS_KEY_ALIAS", "JARVIS_KEY_PASSWORD")),
    "Gradle aceita keystore.properties local": "keystore.properties" in patch,
    "Release só assina com credenciais completas": "jarvisTemAssinatura" in patch,
    "Build de desenvolvimento continua debug": (
        "assembleDebug" in build and "app-debug.apk" in build),
    "Atualizador detecta troca de chave": (
        "assinaturaCompativel" in atualiza
        and "GET_SIGNING_CERTIFICATES" in atualiza
        and "chave diferente da versão instalada" in atualiza),
}

falhas = [nome for nome, ok in checks.items() if not ok]
for nome, ok in checks.items():
    print(("OK" if ok else "FALHA") + ": " + nome)
if falhas:
    raise SystemExit(1)
print("Assinatura de release validada: chave separada da debug, falha sem segredo e troca de chave explicada no atualizador.")
