"""Contrato rápido da 1.28.0: versão, módulo no pacote, limites e testes na suíte."""
import json
import pathlib
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
pkg = json.loads((RAIZ / 'package.json').read_text(encoding='utf-8'))
versao = json.loads((RAIZ / 'VERSAO.json').read_text(encoding='utf-8'))
html = (RAIZ / 'index.html').read_text(encoding='utf-8')
app = (RAIZ / 'app.js').read_text(encoding='utf-8')
falhas = []


def checar(nome, ok):
    print(('OK: ' if ok else 'FALHA: ') + nome)
    if not ok:
        falhas.append(nome)


checar('versão corrente', pkg['version'] == versao['version'])
checar('versionCode >= 10280', versao['versionCode'] >= 10280)
checar('app.js na mesma versão', ("VERSAO_APP = '%s'" % versao['version']) in app)
checar('identidade.js no pacote desktop', 'identidade.js' in pkg['build']['files'])
checar('identidade_ui.js no pacote desktop', 'identidade_ui.js' in pkg['build']['files'])
checar('testes novos na suíte', 'tests/test_identidade.js' in pkg['scripts']['test:all'] and
      'tests/test_identidade_ui.py' in pkg['scripts']['test:all'])
checar('scripts carregados no HTML', 'src="identidade.js"' in html and 'src="identidade_ui.js"' in html)
checar('nenhuma chave exposta no painel', 'sk-' not in html.split('id="painel-pessoas"')[1].split('</aside>')[0])
checar('sem uri de câmera externa', 'getUserMedia({ video' not in (RAIZ / 'identidade_ui.js').read_text(encoding='utf-8'))

if falhas:
    print('\n%d falha(s): %s' % (len(falhas), ', '.join(falhas)))
    sys.exit(1)
print('\ntest_identidade_ui: todas as verificações passaram')
