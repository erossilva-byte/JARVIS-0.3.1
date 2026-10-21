from pathlib import Path
root = Path(__file__).resolve().parents[1]
css = (root / 'style.css').read_text(encoding='utf-8')
html = (root / 'index.html').read_text(encoding='utf-8')
checks = {
    'layout com áreas seguras Android': 'env(safe-area-inset-bottom' in css and 'env(safe-area-inset-top' in css,
    'layout estreito e telas pequenas': '@media(max-width:360px)' in css and '@media(max-width:520px)' in css,
    'orientação horizontal curta': 'orientation:landscape' in css,
    'movimento reduzido acessível': 'prefers-reduced-motion:reduce' in css,
    'painel de configuração com rolagem': '#painel-config .config-tabs' in css and 'overflow-y:auto' in css,
    'chat com quebra de texto longa': '#chat pre,#chat code' in css and 'overflow-wrap:anywhere' in css,
    'alvos de toque e foco visível': 'touch-action:manipulation' in css and ':focus-visible' in css,
    'viewport mobile presente': 'viewport-fit=cover' in html,
}
for label, ok in checks.items():
    print(('OK' if ok else 'FALHOU') + ': ' + label)
if not all(checks.values()):
    raise SystemExit(1)
