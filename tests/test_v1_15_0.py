"""Verificações da 1.15.0 — opção de estilo do Núcleo (HUD/plasma) e a animação própria do plasma.

Roda depois da 1.14.0 e olha só o que a 1.15.0 acrescentou: o seletor em Ajustes ▸ Voz, o DOM e o
CSS do núcleo em plasma, a animação em camadas, a reação ao nível do microfone, a pausa com a tela
fora de vista, a prévia do cartão e a coerência de versão/documentação/suíte.
"""
import json
import re
import sys
from pathlib import Path

raiz = Path(__file__).resolve().parent.parent
html = (raiz / "index.html").read_text(encoding="utf-8")
app = (raiz / "app.js").read_text(encoding="utf-8")
css = (raiz / "style.css").read_text(encoding="utf-8")
versao = json.loads((raiz / "VERSAO.json").read_text(encoding="utf-8"))
pacote = json.loads((raiz / "package.json").read_text(encoding="utf-8"))
leituras = (raiz / "CHANGELOG.md").read_text(encoding="utf-8") + (raiz / "LEIA-ME.md").read_text(encoding="utf-8")
script_teste = pacote.get("scripts", {}).get("test:all", "")
release_wf = (raiz / ".github" / "workflows" / "release-apk.yml").read_text(encoding="utf-8")
build_wf = (raiz / ".github" / "workflows" / "build-apk.yml").read_text(encoding="utf-8")

checagens = {
    # 1. A opção existe, vale na hora e fica salva
    "Seletor de estilo do núcleo em Ajustes ▸ Voz": (
        'id="c-nucleo-estilo"' in html and 'value="hud"' in html and 'value="plasma"' in html
        and 'APARÊNCIA DO NÚCLEO' in html and 'class="nucleo-card"' in html),
    "Estilo aplicado por uma função única": (
        "function aplicarNucleo(" in app and "aplicarNucleo();" in app
        and "body.dataset.nucleo" in app and "document.body.dataset.nucleo = v" in app),
    "Escolha fica salva e é relida nos ajustes": (
        "store.set('nucleo_estilo'" in app and "store.get('nucleo_estilo', 'hud')" in app
        and "const selNucleo = $('#c-nucleo-estilo');" in app and "aplicarNucleo(selNucleo.value)" in app),
    "HUD continua sendo o padrão": (
        "const NUCLEO_ESTILOS = { hud: 'HUD técnico" in app
        and "store.get('nucleo_estilo', 'hud')" in app
        and "NUCLEO_ESTILOS[v] ? v : 'hud'" in app),
    "Configuração em Salvar/Reload acompanha o seletor": (
        "nucleoEstiloAtual()" in app and "c-nucleo-estilo" in app),

    # 2. O DOM do plasma e a animação
    "Núcleo em plasma tem seu próprio DOM dentro do HUD": (
        'class="plas" aria-hidden="true"' in html and html.count('class="fil f') == 4
        and 'class="plas-haze"' in html and 'class="plas-core"' in html and 'class="plas-ponto"' in html
        and html.index('class="plas"') > html.index('id="hud"')),
    "Animação em camadas: giro, deformação, respiração e pulso": (
        '@keyframes plas-gira' in css and '@keyframes plas-forma' in css
        and '@keyframes plas-respira' in css and '@keyframes plas-pulsa' in css
        and re.search(r'\.plas \.fil\{[^}]*animation:plas-gira', css)
        and re.search(r'\.plas \.fil i\{[^}]*animation:plas-forma', css)
        and 'plas-respira 6.5s' in css and 'plas-pulsa 3.4s' in css),
    "Plasma só aparece quando escolhido; HUD some no lugar dele": (
        re.search(r'\.hud \.plas\{[^}]*opacity:0', css)
        and 'body[data-nucleo=plasma] .hud .plas{opacity:1' in css
        and 'body[data-nucleo=plasma] .hud .cam,' in css and 'body[data-nucleo=plasma] .hud-grade' in css),
    "Anel reage ao nível real do microfone": (
        "hud.style.setProperty('--nv'" in app and 'calc(1 + var(--nv) * .07)' in css
        and 'opacity:calc(.5 + var(--nv) * .5)' in css),
    "Bateria e acessibilidade respeitadas": (
        'body.oculto .plas' in css and 'animation-play-state:paused' in css
        and '@media(prefers-reduced-motion:reduce)' in css),
    "Abertura nasce com o mesmo estilo": (
        'body[data-nucleo=plasma] .boot-nucleo .bn-aro' in css
        and 'body[data-nucleo=plasma] .bn-nucleo' in css),
    "Prévia do estilo no próprio cartão": (
        'class="nucleo-preview"' in html and '.nucleo-preview' in css
        and 'body[data-nucleo=plasma] .nucleo-preview .np-plas' in css),
    "Estado do cartão em texto, para leitor de tela": (
        'id="c-nucleo-status"' in html and 'id="c-nucleo-pill"' in html
        and "const pill = document.getElementById('c-nucleo-pill');" in app),

    # 3. Versão, documentação e suíte
    "Versão 1.15.0 com versionCode 10150 (a partir da 1.14.0)": (
        [int(x) for x in str(versao.get("version", "0")).split(".")] >= [1, 15, 0]
        and versao.get("versionCode", 0) >= 10150
        and pacote.get("version") == versao.get("version")
        and ("const VERSAO_APP = '%s';" % versao.get("version")) in app),
    "Versão na interface acompanha o release": (
        ('<span class="orb-sub" aria-hidden="true">v%s</span>' % versao.get("version")) in html
        and ('<span class="versao-chip">v%s</span>' % versao.get("version")) in html),
    "Mudança registrada no CHANGELOG e no LEIA-ME": (
        "## 1.15.0" in leituras and ("# J.A.R.V.I.S. Nova %s" % versao.get("version")) in leituras
        and "plasma" in leituras.lower()),
    "Notas da versão descrevem o que foi entregue": (
        all(t in versao.get("notas", "").lower() for t in ("plasma", "núcleo", "animação"))),
    "Suíte roda o teste novo": "python3 tests/test_v1_15_0.py" in script_teste,
    "Workflows carregam a versão atual": (
        "1.15.0" in build_wf and "1.15.0" in release_wf
        and "1.14.0" not in build_wf and "1.14.0" not in release_wf.split("Novidades")[0]),
}

falhas = [nome for nome, ok in checagens.items() if not ok]
for nome, ok in checagens.items():
    print(("OK: " if ok else "FALHA: ") + nome)
if falhas:
    print("\n%d verificação(ões) da 1.15.0 falharam." % len(falhas))
    sys.exit(1)
print("\n%d verificações da 1.15.0 aprovadas." % len(checagens))
