"""Contrato 1.39.0 — raciocínio em etapas, personalidade adaptativa e verificação."""
import json
import pathlib
import re
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
app = (RAIZ / 'app.js').read_text(encoding='utf-8')
html = (RAIZ / 'index.html').read_text(encoding='utf-8')
pkg = json.loads((RAIZ / 'package.json').read_text(encoding='utf-8'))
meta = json.loads((RAIZ / 'VERSAO.json').read_text(encoding='utf-8'))
cog = (RAIZ / 'cognicao.js').read_text(encoding='utf-8')
suite = pkg.get('scripts', {}).get('test:all', '')
falhas = []


def check(nome, ok):
    print(('OK: ' if ok else 'FALHA: ') + nome)
    if not ok:
        falhas.append(nome)


check('versão 1.39.0 ou posterior e versionCode >= 10390',
      [int(x) for x in meta.get('version', '0').split('.')] >= [1, 39, 0]
      and meta.get('versionCode', 0) >= 10390)
check('package acompanha a versão', pkg.get('version') == meta.get('version'))
check('app e interface mostram a versão corrente',
      ("const VERSAO_APP = '%s';" % meta.get('version')) in app
      and ('v%s' % meta.get('version')) in html and 'v1.38.1' not in html)
check('módulo carregado antes do app',
      '<script src="cognicao.js"></script>' in html and html.index('cognicao.js') < html.index('src="app.js"'))
check('módulo é puro e determinístico',
      'fetch(' not in cog and 'document.' not in cog and 'innerHTML' not in cog and 'VERSAO' in cog)
check('app instancia a cognição', 'const COGNICAO' in app and 'COGNICAO.analisar' in app)
check('prompt recebe plano interno', 'COGNICAO.promptPlano' in app and 'PLANO COGNITIVO INTERNO' in cog)
check('contexto é selecionado por relevância',
      'COGNICAO.selecionarHistorico' in app and 'function historicoParaIA' in app)
check('resposta é verificada e revisada',
      'COGNICAO.verificarResposta' in app and 'COGNICAO.revisarFala' in app and 'revisarSaida' in app)
check('três preferências novas no HTML',
      all(('id="c-cog-%s"' % x) in html for x in ('profundidade', 'iniciativa', 'conversa')))
check('preferências novas são persistidas',
      all(("store.set('cog_%s'" % x) in app for x in ('profundidade', 'iniciativa', 'conversa')))
check('padrões de cognição existem',
      "profundidade: 'equilibrada'" in app and "iniciativa: 'normal'" in app and "conversa: 'natural'" in app)
check('módulo e teste entram na suíte',
      'node tests/test_cognicao.js' in suite and 'node --check cognicao.js' in suite)
check('contrato 1.39.0 na suíte', 'tests/test_v1_39_0.py' in suite)
check('documentação da cognição existe', (RAIZ / 'docs/COGNICAO-1.39.0.md').exists())
check('notas citam raciocínio e personalidade',
      all(x in meta.get('notas', '').lower() for x in ('raciocínio', 'personalidade', 'verifica')))
check('módulo entra no pacote Electron', 'cognicao.js' in pkg.get('build', {}).get('files', []))
for w in ('.github/workflows/build-apk.yml', '.github/workflows/release-apk.yml'):
    check('CI copia a cognição (%s)' % w, 'cp cognicao.js www/' in (RAIZ / w).read_text(encoding='utf-8'))
check('funções antigas preservadas',
      all(x in app for x in ('function turno', 'function executarDiagnostico', 'function responderCore')))

if falhas:
    print('\n%d falha(s) no contrato 1.39.0: %s' % (len(falhas), ', '.join(falhas)))
    sys.exit(1)
print('\n1.39.0: cognição, contexto, configuração e verificação aprovados.')
