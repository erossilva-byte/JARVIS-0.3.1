"""Verificações estáticas do cofre de chaves para Android/Electron."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
app = (ROOT / "app.js").read_text(encoding="utf-8")
main = (ROOT / "main.js").read_text(encoding="utf-8")
html = (ROOT / "index.html").read_text(encoding="utf-8")
checks = {
    "Android usa o cofre nativo": "guardarSeguro({ nome: n, valor: v })" in app,
    "Desktop usa safeStorage": "safeStorage.encryptString" in main and "safeStorage.decryptString" in main,
    "Cofre desktop falha fechado": "O armazenamento criptografado do sistema não está disponível" in main,
    "Segredos do desktop ficam fora do renderer": "jarvis-secrets.json" in main and "guardar_chave_segura" in main,
    "Nomes de chave são permitidos por lista": "groq|cerebras|mistral|gemini|picovoice" in main,
    "Navegador não persiste chaves em texto puro": "O navegador comum não possui cofre criptográfico integrado" in app,
    "Campo Picovoice avisa salvamento ao sair do campo": "A chave é salva quando você sai do campo" in html,
    "Campo Picovoice permanece protegido por senha": 'id="c-key-picovoice" type="password"' in html,
}
for nome, ok in checks.items():
    print(("OK" if ok else "FALHA") + ": " + nome)
if not all(checks.values()):
    raise SystemExit(1)
