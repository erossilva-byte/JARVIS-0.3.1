"""Contrato estático da Central de Utilidades (1.43.0).

Não abre navegador: confere que os núcleos puros existem, que a interface está ligada na
ordem certa, que o chat local alcança a central e que nenhum atalho promete o que não existe.
"""
import json
import re
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent


def ler(nome):
    return (RAIZ / nome).read_text(encoding='utf-8')


def principais():
    app = ler('app.js')
    html = ler('index.html')
    css = ler('style.css')
    pkg = json.loads(ler('package.json'))
    return app, html, css, pkg


def verificar():
    app, html, css, pkg = principais()
    checks = {}

    checks['quatro núcleos puros presentes'] = all(
        (RAIZ / f).is_file() for f in ['utilidades.js', 'cultura.js', 'briefing.js', 'jogos.js']
    )
    util = ler('utilidades.js')
    jogos = ler('jogos.js')
    cultura = ler('cultura.js')
    briefing = ler('briefing.js')
    checks['calculadora sem eval'] = 'eval(' not in util and 'new Function' not in util
    checks['funções matemáticas reais'] = all(k in util for k in ['U.fatorial', 'U.equacao2', 'U.matriz', 'U.estatistica'])
    checks['conversões com temperatura'] = "categoria: 'temperatura'" in util and 'U.converter' in util
    checks['saúde e finanças'] = all(k in util for k in ['U.imc', 'U.taxaMetabolica', 'U.jurosCompostos', 'U.parcelaPrice'])
    checks['senha usa crypto quando existe'] = 'crypto.getRandomValues' in util and 'U.senha' in util
    bloco = jogos[jogos.index('const TIPOS = {'):jogos.index('};', jogos.index('const TIPOS = {'))]
    checks['oito jogos'] = len(re.findall(r'\b(blackjack|velha|ligue4|forca|ppt|adivinha|termo|roleta)\s*:', bloco)) == 8
    checks['jogos têm RNG injetável'] = 'opts.rng' in jogos and 'sorteio(rng' in jogos
    checks['acervo local com receitas e nutrição'] = 'RECEITAS' in cultura and 'FRUTAS' in cultura and 'TREINOS' in cultura
    checks['briefing não inventa fonte ausente'] = 'faltando' in briefing and 'fontesAusentes' in briefing
    checks['monitoramento compara listas'] = 'compararMonitoramento' in briefing

    checks['painel presente no HTML'] = 'id="painel-utilidades"' in html
    checks['sete seções declaradas'] = all(f'data-util-tab="{t}"' in html for t in ['calc', 'conversao', 'saude', 'financas', 'jogos', 'cultura', 'briefing'])
    checks['campos essenciais existem'] = all(f'id="{i}"' in html for i in [
        'util-calc-expr', 'util-conv-valor', 'util-saude-peso', 'util-fin-capital',
        'util-jogo-tipo', 'util-cultura-lista', 'util-brief-tarefas', 'dash-utilidades',
    ])
    ordem = [html.index(f'<script src="{n}"></script>') for n in ['utilidades.js', 'cultura.js', 'briefing.js', 'jogos.js', 'app.js', 'utilidades_ui.js']]
    checks['núcleos antes do app e interface depois'] = ordem == sorted(ordem)
    checks['atalho leva à central'] = 'id="dash-utilidades"' in html and 'Utilidades' in html
    checks['chat local alcança a central'] = 'window.UtilidadesUI.responder' in app and 'respostaUtil' in app
    checks['interface não usa innerHTML com resposta'] = 'innerHTML' not in ler('utilidades_ui.js')
    checks['estilos próprios'] = '.util-secao' in css and '.util-estado' in css and '.util-tabs' in css

    entrada = pkg.get('scripts', {}).get('test:all', '')
    checks['testes novos entram no test:all'] = all(t in entrada for t in [
        'tests/test_utilidades.js', 'tests/test_jogos.js', 'tests/test_cultura.js',
        'tests/test_briefing.js', 'tests/test_utilidades_ui.py',
    ])
    return checks


if __name__ == '__main__':
    falhas = 0
    for nome, ok in verificar().items():
        print(('OK: ' if ok else 'FALHA: ') + nome)
        falhas += 0 if ok else 1
    print('\nUtilidades Android/UI: %d verificações aprovadas.' % (len(verificar()) - falhas) if not falhas else '\nFALHAS: %d' % falhas)
    raise SystemExit(1 if falhas else 0)
