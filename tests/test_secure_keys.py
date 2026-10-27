"""Verificações estáticas do cofre de chaves para Android/Electron."""
import re
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
    "Nomes de chave são permitidos por lista": "groq|cerebras|mistral|gemini" in main and "picovoice" not in main,
    "Navegador não persiste chaves em texto puro": "O navegador comum não possui cofre criptográfico integrado" in app,
    # O detector de ativação é próprio: nenhum campo de chave na interface. A checagem
    # olha para o campo (input), não para a palavra: o texto explica que nenhuma chave
    # é necessária, e isso é justamente o que se quer manter.
    "Ativação própria não tem campo de chave": (
        'c-key-picovoice' not in html
        and not re.search(r'<input[^>]*(accesskey|picovoice)', html, re.IGNORECASE)
        and 'nenhuma AccessKey' in html),
    "Calibragem da ativação exposta com sensibilidade e palavras extras": (
        'id="c-wake-sensibilidade"' in html and 'id="c-wake-variantes"' in html),
}
for nome, ok in checks.items():
    print(("OK" if ok else "FALHA") + ": " + nome)
if not all(checks.values()):
    raise SystemExit(1)
