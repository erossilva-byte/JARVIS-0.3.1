"""Contrato estático da 1.33.0: áreas, modos, atividades e preservação."""
import json
import pathlib
import re
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent


def ler(nome):
    return (RAIZ / nome).read_text(encoding='utf-8')


app = ler('app.js')
html = ler('index.html')
css = ler('interface.css') + '\n' + ler('style.css')
ui = ler('interface.js')
meta = json.loads(ler('VERSAO.json'))
pkg = json.loads(ler('package.json'))
falhas = []


def check(nome, ok):
    print(('OK: ' if ok else 'FALHA: ') + nome)
    if not ok:
        falhas.append(nome)


check('versão 1.33.0 ou posterior', tuple(map(int, meta.get('version','0').split('.')[:2])) >= (1,33) and meta.get('versionCode',0) >= 10330)
check('app e pacote acompanham o metadado', "const VERSAO_APP = '%s';" % meta.get('version') in app and pkg.get('version') == meta.get('version'))
check('interface.js e interface.css existem', (RAIZ / 'interface.js').is_file() and (RAIZ / 'interface.css').is_file())
check('interface.css está no HTML', 'href="interface.css"' in html)
check('interface.js está no HTML antes de app.js', 'src="interface.js"' in html and html.index('src="interface.js"') < html.index('src="app.js"'))

areas = ['inicio', 'ia', 'voz', 'automacao', 'memoria', 'ferramentas', 'dispositivos', 'seguranca', 'personalizacao', 'sistema']
check('as dez áreas estão definidas', all(("id: '%s'" % a) in ui for a in areas))
check('o mapa de áreas tem painel próprio', 'id="painel-areas"' in html and 'areas-grid' in html and 'areas-detalhe' in html)
check('o painel de áreas entra na navegação central', "'#painel-areas'" in app and "alvo === 'areas'" in app)
check('as áreas abrem painéis reais', all(x in app for x in [
    "case 'sistema': abrirSistema()", "case 'memoria': abrirMemoria()", "case 'pessoas': abrirPessoas()",
    "case 'arquivos': abrirArquivos()", "case 'dev': devAbrir()", "case 'visao': abrirVisao()",
    "case 'tarefas': abrirTarefas()", "case 'log': mostrarLog()"
]))
check('não há ação de área decorativa', 'default: msg(' in app and 'JarvisNavegacao' in app)

check('quatro modos existem', all(('data-modo="%s"' % m) in html for m in ['completo', 'discreto', 'silencioso', 'holografico']))
check('modos têm estado persistido', "CHAVE_MODO = 'jv_modo_interface'" in ui and 'localStorage.setItem' in ui)
check('modo silencioso suprime a fala', "document.body.dataset.modo === 'silencioso'" in app and 'fala suprimida pelo modo silencioso' in app)
check('modo silencioso não é um botão decorativo', 'JarvisModos.aplicar' in app)
check('modo holográfico tem CSS real', 'body[data-modo=holografico] .hud' in css and 'body[data-modo=holografico] .dash-card' in css)
check('modo discreto reduz a interface', 'body[data-modo=discreto] .dash .monitor' in css and 'display: none' in css)
check('modo completo restaura a apresentação', 'MODOS' in ui and 'completo' in ui)

check('atividades reais na página inicial', 'id="dash-atividades"' in html and 'function renderAtividadesInicio' in app)
check('atividades vêm de SISTEMA', 'SISTEMA.listarTarefas()' in app and 'SISTEMA.traces()' in app)
check('núcleo reage à execução de ferramenta', "SISTEMA.ao('ferramenta:inicio'" in app and "setEstado('processing')" in app)
check('estado processing tem rótulo', "processing: 'executando'" in app)
check('barra lateral está agrupada', 'lat-grupo' in html and 'OPERAÇÃO' in html and 'CONHECIMENTO' in html)
check('cabeçalho tem acesso às áreas', 'id="btn-areas"' in html and 'btnAreas' in app)
check('personalização é uma categoria de configuração', 'data-config-tab="personalizacao"' in html and "cat === 'personalizacao'" not in app and "'personalizacao'" in app)

preservados = ['painel-config', 'painel-sistema', 'painel-log', 'painel-tarefas', 'painel-visao',
               'painel-info', 'painel-memoria', 'painel-arquivos', 'painel-pessoas', 'painel-dev', 'painel-pc']
check('todos os painéis originais continuam no HTML', all(('id="%s"' % p) in html for p in preservados))
check('todos os painéis continuam na lista de navegação', all(("#%s" % p) in app for p in preservados))
check('funções antigas continuam expostas', all(x in app for x in ['function abrirPainel', 'function fecharPaineis', 'function executarDiagnostico', 'function abrirMemoria']))
check('nenhum innerHTML foi usado na camada nova', 'innerHTML' not in ui)
check('HTML sem tags desbalanceadas', html.count('<section') == html.count('</section>') and html.count('<aside') == html.count('</aside>'))

check('suite inclui este contrato', 'test_v1_33_0.py' in pkg['scripts']['test:all'])
check('suíte inclui interface.js', 'node --check interface.js' in pkg['scripts']['test:all'])
check('auditoria e limpeza documentadas', (RAIZ / 'docs' / 'AUDITORIA-1.33.0.md').is_file() and (RAIZ / 'docs' / 'LIMPEZA-1.33.0.md').is_file())
check('auditoria tem os 13 tópicos', all(('\n| %d |' % n) in ler('docs/AUDITORIA-1.33.0.md') for n in range(1, 14)))
check('build não é declarado concluído sem artefato', (meta.get('build') or {}).get('resultado') in ('pendente', 'success'))
check('não há segredo em arquivo novo', 'sk-' not in ui and 'api_key' not in ui.lower())

if falhas:
    print('\n%d verificação(ões) da 1.33.0 falharam.' % len(falhas))
    sys.exit(1)
print('1.33.0: áreas, modos, atividades e preservação verificados.')
