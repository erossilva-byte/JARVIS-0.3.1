"""Contrato de interface e estabilidade visual 1.39 — verificações estáticas."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
css = (ROOT / "core.css").read_text(encoding="utf-8")
orbita = (ROOT / "orbita.js").read_text(encoding="utf-8")
avatar = (ROOT / "avatar.js").read_text(encoding="utf-8")
html = (ROOT / "index.html").read_text(encoding="utf-8")
package = (ROOT / "package.json").read_text(encoding="utf-8")

checks = {
    "HUD futurista sem substituir os módulos": "HUD de comando refinado" in css and "id=\"lateral\"" in html,
    "paleta holográfica ciano/azul": "--jv-hud-cyan" in css and "--jv-hud-blue" in css,
    "navegação preserva foco visível": "#lateral .lat-btn:focus-visible" in css,
    "layout adapta celulares estreitos": "@media (max-width: 640px)" in css and "@media (max-width: 360px)" in css,
    "movimento reduzido respeitado": "@media (prefers-reduced-motion: reduce)" in css,
    "sem blur pesado em aparelhos lentos/mobile": "@media (update: slow), (max-width: 640px)" in css,
    "modo de efeitos reduzidos preservado": "body.efeitos-reduzidos" in css,
    "órbita reduz partículas em mobile": "this.compacto ? 820 : 1600" in orbita,
    "órbita limita pixel ratio": "largura < 640 ? 1.25 : 1.75" in orbita,
    "órbita limita render em 30 FPS no mobile": "1000 / 30" in orbita and "ultimoQuadro" in orbita,
    "avatar limita pixel ratio": "w < 640 ? 1.25 : 1.6" in avatar,
    "avatar limita render em 30 FPS no mobile": "1000 / 30" in avatar and "ultimoQuadro" in avatar,
    "folha HUD incluída no build Electron": '"core.css"' in package,
    "folha HUD incluída no HTML": '<link rel="stylesheet" href="core.css">' in html,
}
for label, ok in checks.items():
    print(("OK: " if ok else "FALHOU: ") + label)
if not all(checks.values()):
    raise SystemExit(1)
