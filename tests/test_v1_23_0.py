"""Revisão 1.23.0 — camada holográfica 3D, transições e opção de reduzir efeitos."""
import json
import pathlib
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent


def texto(nome):
    return (RAIZ / nome).read_text(encoding='utf-8')


app = texto('app.js')
html = texto('index.html')
css = texto('style.css')
meta = json.loads(texto('VERSAO.json'))
pkg = json.loads(texto('package.json'))
falhas = []


def checar(nome, ok):
    print(('OK: ' if ok else 'FALHA: ') + nome)
    if not ok:
        falhas.append(nome)


# ---------- 1. Versão única ----------
checar('VERSAO.json em 1.23.0', meta.get('version') == '1.23.0' and meta.get('versionCode') == 10230)
checar('package.json em 1.23.0', pkg.get('version') == '1.23.0')
checar('app.js em 1.23.0', "const VERSAO_APP = '1.23.0';" in app)
checar('interface na 1.23.0', 'v1.23.0' in html and 'v1.22.0' not in html)
checar('CHANGELOG na 1.23.0', '## 1.23.0' in texto('CHANGELOG.md'))
checar('LEIA-ME na 1.23.0', '# J.A.R.V.I.S. Nova 1.23.0' in texto('LEIA-ME.md'))
checar('Workflows na 1.23.0', '1.23.0' in texto('.github/workflows/build-apk.yml')
      and '1.23.0' in texto('.github/workflows/release-apk.yml'))
checar('Suíte roda este teste', 'python3 tests/test_v1_23_0.py' in pkg['scripts']['test:all'])

# ---------- 2. Camada holográfica: profundidade real ----------
camada = css.split('Revisão visual holográfica')[-1]
for marca in ['--jv-vidro-3d', 'translateZ(34px)', 'translateZ(-16px)', 'perspective(900px) rotateX(6deg)',
              '@keyframes jv-painel-holo', 'jv-varre', 'content-visibility:auto', '(update:slow)']:
    checar('Camada holográfica: ' + marca, marca in camada)
checar('Profundidade restrita ao estilo HUD', 'body[data-nucleo=hud] .hud{transform-style:preserve-3d}' in camada)
checar('Inclinação só com ponteiro fino', '@media (hover:hover) and (pointer:fine)' in camada)
checar('Superfícies com vidro e elevação', '.dash-card,.info-card,.nucleo-card' in camada
      and 'translateY(-2px)' in camada)
checar('Camada nova não inventa estados da IA', 'data-state' not in camada)

# ---------- 3. Redução de movimento e de efeitos ----------
checar('Redução de movimento cobre a camada nova',
      'prefers-reduced-motion:reduce' in camada and '.hud:hover,.hud:active,.dash-card:hover' in camada)
checar('Opção do usuário no CSS', 'body.efeitos-reduzidos' in camada
      and 'animation-duration:.001ms!important' in camada)
checar('Opção na interface', 'id="c-efeitos"' in html and 'Reduzir efeitos visuais' in html)
checar('Opção fica na aba Voz', html.index('id="c-efeitos"') < html.index('id="c-voz"'))
checar('Opção é persistida', "var CHAVE = 'efeitos_visuais'" in app
      and "store.get(CHAVE, 'completos')" in app and 'store.set(CHAVE' in app)
checar('Classe aplicada no body', "classList.toggle('efeitos-reduzidos'" in app)
checar('Escolha registrada no log', "registrar('interface', 'efeitos visuais: '" in app)
checar('Estado reaplicado ao abrir', "document.addEventListener('DOMContentLoaded', aplicar)" in app)

# ---------- 4. O que não podia mudar ----------
checar('Três estilos de núcleo preservados',
      all(x in css for x in ['body[data-nucleo=plasma]', 'body[data-nucleo=orbita]', 'body[data-nucleo=hud]']))
checar('Sistema de animação da 1.21.5 intacto',
      all(x in css for x in ['--jv-dur-1', '@keyframes jv-surge', '.painel:not([hidden]){animation:jv-painel']))
checar('Telas e funções preservadas',
      all(x in app for x in ['function abrirPainel', 'function executarDiagnostico', 'function atualizarObsUI'])
      and 'id="painel-config"' in html and 'id="painel-pessoas"' in html)

if falhas:
    print('\n%d verificação(ões) da 1.23.0 falharam.' % len(falhas))
    sys.exit(1)
print('1.23.0: camada holográfica, transições e redução de efeitos verificadas.')
