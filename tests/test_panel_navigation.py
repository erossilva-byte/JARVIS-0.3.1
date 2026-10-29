"""Regressão: navegação dos painéis não deve empilhar histórico nem esconder erros."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
app = (ROOT / "app.js").read_text(encoding="utf-8")
checks = {
    # A lista cresceu com o painel do computador (Electron). O que importa é que todos os
    # painéis estejam na MESMA lista usada por abrir/fechar — não a ordem literal.
    "painéis centralizados numa lista": (
        "const PAINEIS = [" in app
        and all(painel in app.split("const PAINEIS = [")[1].split("];")[0] for painel in [
            "'#painel-config'", "'#painel-log'", "'#painel-tarefas'", "'#painel-visao'",
            "'#painel-info'", "'#painel-memoria'", "'#painel-arquivos'", "'#painel-pc'"])),
    "marcador próprio no histórico": "jarvisPainel === true" in app,
    "não cria histórico ao alternar painéis": "if (!jaHaviaPainel && !estadoPainelJarvis(H.state))" in app,
    "substitui o estado quando o painel já está aberto": "H.replaceState({ ...H.state, jarvisPainel: true, painel: sel }, '')" in app,
    "voltar fecha os painéis sem empilhar": "if (aberto && !vindoDoHistorico && H && estadoPainelJarvis(H.state))" in app,
    "elementos ausentes não causam exceção ao abrir/fechar": "if (!alvo) { registrar('erro', 'painel inexistente: ' + sel); return; }" in app,
    "popstate fecha painel sem novo back": "window.addEventListener('popstate', () => fecharPaineis(true))" in app,
}
for label, ok in checks.items():
    print(("OK" if ok else "FALHOU") + ": " + label)
if not all(checks.values()):
    raise SystemExit(1)
