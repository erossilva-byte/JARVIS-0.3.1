"""Contrato estático da 1.34.0: Core, agentes, contexto, saúde e limites honestos."""
import json
import pathlib
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent


def ler(nome):
    return (RAIZ / nome).read_text(encoding='utf-8')


app = ler('app.js')
html = ler('index.html')
core = ler('core.js')
ui = ler('core_ui.js')
css = ler('core.css')
meta = json.loads(ler('VERSAO.json'))
pkg = json.loads(ler('package.json'))
falhas = []


def check(nome, ok):
    print(('OK: ' if ok else 'FALHA: ') + nome)
    if not ok:
        falhas.append(nome)


check('versão 1.34.0 ou posterior', tuple(map(int, meta.get('version','0').split('.')[:2])) >= (1,34) and meta.get('versionCode',0) >= 10340)
check('app e pacote acompanham o metadado', "const VERSAO_APP = '%s';" % meta.get('version') in app and pkg.get('version') == meta.get('version'))
check('core.js, core_ui.js e core.css existem', all((RAIZ / n).is_file() for n in ('core.js', 'core_ui.js', 'core.css')))
check('core.css está no HTML', 'href="core.css"' in html)
check('core.js antes de app.js', 'src="core.js"' in html and html.index('src="core.js"') < html.index('src="app.js"'))
check('core_ui.js depois de app.js', 'src="core_ui.js"' in html and html.index('src="core_ui.js"') > html.index('src="app.js"'))
check('painel do Core e navegação', 'id="painel-core"' in html and 'data-lat="core"' in html and "'#painel-core'" in app)
check('ação do Core na área de IA', "acao: 'core'" in ler('interface.js') and "case 'core'" in app)
check('painel tem status, agentes, projetos, saúde e habilidades', all(x in html for x in [
    'id="core-status"', 'id="core-agentes"', 'id="core-projetos"', 'id="core-saude"', 'id="core-habilidades"'
]))

agentes = ['principal', 'pesquisa', 'programacao', 'arquivos', 'automacao', 'voz', 'memoria',
           'tecnico', 'planejamento', 'diagnostico', 'desenvolvimento', 'atualizacao']
check('os doze agentes estão declarados', all(("id: '%s'" % a) in core for a in agentes))
check('agentes têm cobertura e limite', 'cobertura:' in core and 'naoFaz:' in core and "'descritivo'" in core)
check('seleção de agente é explícita', 'function selecionar' in core and "sinal explícito no pedido" in core)
check('contexto e projetos persistem', 'core:contexto' in core and 'core:projetos' in core and 'resolverReferencia' in core)
check('contexto não inventa referência', 'não há pedido ou projeto anterior salvo' in core)
check('verificação conservadora', "return { status: 'incerto'" in core and "return { status: 'confirmado'" in core and "return { status: 'falhou'" in core)
check('recibo incerto é soberano', 'Recibo incerto é soberano' in core)
check('delegação não finge executor', "status: 'nao_configurado'" in core and 'Nada foi executado' in core)
check('saúde e watchdog reais', 'registrarComponente' in core and 'diagnosticar' in core and 'iniciarVigia' in core)
check('watchdog não reinicia serviços', 'não reinicia serviços' in ui and 'não reinicia componentes em loop' in core)
check('habilidades usam o SISTEMA', 'listarFerramentas' in core and 'sistema.executar' in core and 'bloqueado' in core)
check('integrações pendentes são declaradas', all(x in core for x in ['mcp:', 'rag_vetorial:', 'tv_esp32:', 'pareamento_pc:']))
check('app registra componentes e executores', all(x in app for x in ["id: 'sistema'", "id: 'armazenamento'", "id: 'rede'", "id: 'memoria'", "registrarExecutor('diagnostico'"]))

check('comandos do Core ligados ao turno', 'function responderCore' in app and 'coreLocal = await responderCore' in app)
check('comandos não interceptam ações sensíveis', 'Nenhuma frase' in app and 'sem o SISTEMA' in app)
check('watchdog iniciado após o boot', 'CORE.iniciarVigia(120000)' in app)
check('UI usa textContent, não innerHTML', 'innerHTML' not in ui)
check('Core não usa rede', 'fetch(' not in core and 'XMLHttpRequest' not in core)
check('Core e UI sem segredo', 'sk-' not in core and 'api_key' not in core.lower())
check('HTML estruturalmente equilibrado', html.count('<section') == html.count('</section>') and html.count('<aside') == html.count('</aside>'))
check('preservação dos painéis da 1.33', all(('id="%s"' % x) in html for x in ['painel-config', 'painel-sistema', 'painel-tarefas', 'painel-memoria', 'painel-visao']))
check('pacote inclui os arquivos do Core', all(x in pkg['build']['files'] for x in ['core.js', 'core_ui.js', 'core.css']))
check('suíte inclui Core e contrato', 'node tests/test_core.js' in pkg['scripts']['test:all'] and 'test_v1_34_0.py' in pkg['scripts']['test:all'])
check('workflows copiam o Core', all(('core.js' in ler(w)) for w in ('.github/workflows/build-apk.yml', '.github/workflows/release-apk.yml')))
check('auditoria da evolução existe', (RAIZ / 'docs' / 'EVOLUCAO-1.34.0.md').is_file())
check('build não é declarado concluído sem APK', (meta.get('build') or {}).get('resultado') in ('pendente', 'success'))

if falhas:
    print('\n%d verificação(ões) da 1.34.0 falharam.' % len(falhas))
    sys.exit(1)
print('1.34.0: Core, agentes, contexto, saúde e limites verificados.')
