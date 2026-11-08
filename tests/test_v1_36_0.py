"""Contrato estático da 1.36.0: aprendizado explícito e revisável."""
import json
import pathlib
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent


def ler(nome):
    return (RAIZ / nome).read_text(encoding='utf-8')


app = ler('app.js')
html = ler('index.html')
mod = ler('aprendizado.js')
ui = ler('aprendizado_ui.js')
meta = json.loads(ler('VERSAO.json'))
pkg = json.loads(ler('package.json'))
falhas = []


def check(nome, ok):
    print(('OK: ' if ok else 'FALHA: ') + nome)
    if not ok:
        falhas.append(nome)


check('versão 1.36.0 ou posterior', tuple(map(int, meta.get('version','0').split('.')[:2])) >= (1,36) and meta.get('versionCode',0) >= 10360)
check('app e pacote acompanham o metadado', "const VERSAO_APP = '%s';" % meta.get('version') in app and pkg.get('version') == meta.get('version'))
check('módulo de aprendizado sem DOM e sem rede', 'document' not in mod and 'fetch(' not in mod and 'module.exports' in mod)
check('aprende somente padrões explícitos', all(x in mod for x in ['PADROES', 'prefiro', 'evite', 'lembre', 'feedback']))
check('bloqueia conteúdo sensível', 'SENSIVEL' in mod and 'senha' in mod and 'bloqueado: true' in mod)
check('aprendizado é revisável e reversível', all(x in mod for x in ['function remover', 'function desfazer', 'function limparTudo', 'function exportar', 'function importar']))
check('contexto é limitado e confiável', 'CONFIANCA_MIN' in mod and 'slice(-10)' in mod)
check('app usa o contexto no prompt', 'APRENDIZADO.contexto()' in app and 'Aprendizado explícito do usuário' in app)
check('turno registra apenas instrução explícita', 'APRENDIZADO.observar(texto)' in app)
check('script carrega antes do app', 'src="aprendizado.js"' in html and html.index('src="aprendizado.js"') < html.index('src="app.js"'))
check('UI carrega depois do app', 'src="aprendizado_ui.js"' in html and html.index('src="aprendizado_ui.js"') > html.index('src="app.js"'))
check('painel de revisão está no HTML', all(x in html for x in ['aprend-lista', 'aprend-resumo', 'aprend-adicionar', 'aprend-exportar', 'aprend-limpar', 'aprend-contexto']))
check('UI não usa innerHTML', 'innerHTML' not in ui)
check('módulo e UI entram no pacote', 'aprendizado.js' in pkg['build']['files'] and 'aprendizado_ui.js' in pkg['build']['files'])
check('suíte cobre o módulo', 'tests/test_aprendizado.js' in pkg['scripts']['test:all'])
check('workflows copiam o módulo', all('aprendizado.js' in ler(w) for w in ('.github/workflows/build-apk.yml', '.github/workflows/release-apk.yml')))
check('relatório 1.36 existe', (RAIZ / 'docs' / 'APRENDIZADO-1.36.0.md').is_file())
check('build não é declarado sem artefato', (meta.get('build') or {}).get('resultado') in ('pendente', 'success'))
check('funções antigas preservadas', all(x in app for x in ['function executarDiagnostico', 'function abrirPainel', 'function turno']))

if falhas:
    print('\n%d verificação(ões) da 1.36.0 falharam.' % len(falhas))
    sys.exit(1)
print('1.36.0: aprendizado explícito, revisável e preservação verificados.')
