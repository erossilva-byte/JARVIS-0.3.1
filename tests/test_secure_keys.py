"""Verificações estáticas do cofre de chaves para Android/Electron."""
import re
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
app = (ROOT / "app.js").read_text(encoding="utf-8")
main = (ROOT / "platforms/desktop/main.js").read_text(encoding="utf-8")
html = (ROOT / "index.html").read_text(encoding="utf-8")
cofre_java = (ROOT / "JarvisUtilPlugin.java").read_text(encoding="utf-8")
identidade = (ROOT / "identidade.js").read_text(encoding="utf-8")
checks = {
    "Android usa o cofre nativo": "guardarSeguro({ nome: n, valor: v })" in app,
    "Desktop usa safeStorage": "safeStorage.encryptString" in main and "safeStorage.decryptString" in main,
    "Cofre desktop falha fechado": "O armazenamento criptografado do sistema não está disponível" in main,
    "Segredos do desktop ficam fora do renderer": "jarvis-secrets.json" in main and "guardar_chave_segura" in main,
    "Nomes de chave são permitidos por lista": "groq|openrouter|cerebras|mistral|gemini" in main and "picovoice" not in main,
    "Navegador não persiste chaves em texto puro": "O navegador comum não possui cofre criptográfico integrado" in app,
    # O detector de ativação é próprio: nenhum campo de chave na interface. A checagem
    # olha para o campo (input), não para a palavra: o texto explica que nenhuma chave
    # é necessária, e isso é justamente o que se quer manter.
    "Ativação própria não tem campo de chave": (
        'c-key-picovoice' not in html
        and not re.search(r'<input[^>]*(accesskey|picovoice)', html, re.IGNORECASE)
        and 'sherpa-onnx KWS' in html and 'não envia áudio antes da palavra-chave' in html),
    "Calibragem da ativação exposta com sensibilidade e palavras extras": (
        'id="c-wake-sensibilidade"' in html and 'id="c-wake-variantes"' in html),

    # Cofre do Android: AES-256-GCM com a chave no Keystore e sem segredo em claro.
    "Android cifra com AES-GCM e chave do Keystore": (
        'KeyProperties.KEY_ALGORITHM_AES' in cofre_java
        and 'Cipher.getInstance("AES/GCM/NoPadding")' in cofre_java
        and '.setKeySize(256)' in cofre_java
        and 'private static final String KS = "AndroidKeyStore";' in cofre_java),
    "Android guarda IV e texto cifrado, nunca o segredo": (
        'Base64.encodeToString(iv, Base64.NO_WRAP) + ":" + Base64.encodeToString(ct, Base64.NO_WRAP)' in cofre_java
        and 'putString(nome, s)' in cofre_java),
    "Sem cofre, o app falha fechado em vez de gravar em claro": (
        'Cofre seguro do Android indisponível' in app
        and "localStorage.removeItem('jv_' + nomeLS(n))" in app
        and 'localStorage.removeItem(chaveLocal)' in app),
    "Migração antiga apaga a cópia em claro mesmo quando falha": (
        'antiga removida porque não foi possível migrá-la' in app
        and 'antiga removida do armazenamento em claro' in app
        and 'removida do armazenamento do navegador' in app),
    "Configuração do cofre é normalizada apesar de não ter UID bruto": (
        'uidHash' in (ROOT / 'seguranca.js').read_text(encoding='utf-8')),
    "PIN e código de recuperação usam PBKDF2 com sal": (
        'iterations: 120000, hash: ' in app and "'pbkdf2$'" in app
        and 'pin_salt' in app and 'rec_salt' in app),
    "Desktop grava o cofre com 0o600 e troca atômica": (
        'fs.writeFileSync(temporario, JSON.stringify(dados), { mode: 0o600 })' in main
        and 'fs.renameSync(temporario, arquivo)' in main),
    "Diagnóstico do desktop lista apenas o nome da chave": (
        'Object.keys(lerCofreDesktop())' in main),
    "Biometria de voz declara chave local, sem Keystore": (
        'biometria cifrada em repouso (AES-GCM) com chave local' in identidade
        and 'não existe aqui Keystore/cofre de hardware' in identidade),
}
for nome, ok in checks.items():
    print(("OK" if ok else "FALHA") + ": " + nome)
if not all(checks.values()):
    raise SystemExit(1)
