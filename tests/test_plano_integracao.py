"""Contrato estático da integração do supervisor de planos (1.31.1)."""
import json
import pathlib

RAIZ = pathlib.Path(__file__).resolve().parent.parent
app = (RAIZ / 'app.js').read_text(encoding='utf-8')
html = (RAIZ / 'index.html').read_text(encoding='utf-8')
pkg = json.loads((RAIZ / 'package.json').read_text(encoding='utf-8'))
meta = json.loads((RAIZ / 'VERSAO.json').read_text(encoding='utf-8'))
falhas = []


def check(nome, ok):
    print(('OK: ' if ok else 'FALHA: ') + nome)
    if not ok:
        falhas.append(nome)


check('módulo de plano carregado antes do app', 'src="plano.js"' in html and html.index('plano.js') < html.index('src="app.js"'))
check('app referencia o supervisor', "window.PlanoJarvis" in app and 'PLANO.executar' in app)
check('comando explícito de planejamento', 'iniciarPlano(planoMatch[1])' in app and 'planeje|planejar' in app)
check('plano só começa após confirmação', 'const confirmado = await confirmar(' in app)
check('etapa incerta exige decisão humana', 'confirmarIncerteza' in app and 'NÃO foi confirmado' in app)
check('plano pausa em vez de seguir incerto', "status === 'pausado'" in app)
check('falha interrompe o restante', 'Nenhuma etapa seguinte foi executada' in app)
check('ações passam pelo executor seguro', 'executarSeguro({ nome: p.acao, args: p.args }, { leituraOk: PLANO_LEITURA.has(p.acao) })' in app)
check('planejamento não contamina histórico', 'histAntes = hist.slice()' in app and 'hist.length = 0' in app)
check('versão 1.31.1 no app e no metadado', meta.get('version') == '1.31.1' and meta.get('versionCode') == 10311 and "const VERSAO_APP = '1.31.1';" in app)
check('pacote e suíte incluem plano.js', 'plano.js' in pkg.get('build', {}).get('files', []) and 'tests/test_plano.js' in pkg.get('scripts', {}).get('test:all', ''))
check('workflows copiam plano.js', 'plano.js' in (RAIZ / '.github/workflows/build-apk.yml').read_text(encoding='utf-8'))
check('CHANGELOG registra a versão', '## 1.31.1' in (RAIZ / 'CHANGELOG.md').read_text(encoding='utf-8'))

if falhas:
    print('\nFALHA:', '; '.join(falhas))
    raise SystemExit(1)
print('Integração do supervisor de planos validada.')
