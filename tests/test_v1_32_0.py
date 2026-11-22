"""Contrato estático da 1.32.0: núcleo operacional, acessibilidade e central."""
from pathlib import Path
import json, re, sys

ROOT = Path(__file__).resolve().parent.parent
ok = 0
falhas = []

def check(nome, cond):
    global ok
    if cond:
        ok += 1
        print('OK:', nome)
    else:
        falhas.append(nome)
        print('FALHOU:', nome)

ler = lambda p: (ROOT / p).read_text(encoding='utf-8')
meta = json.loads(ler('VERSAO.json'))
app = ler('app.js'); idx = ler('index.html'); sis = ler('sistema.js')
manifest_patch = ler('patch_manifest.py'); main = ler('MainActivity.java')
acess = ler('JarvisAcessibilidade.java'); plugin = ler('JarvisAcessibilidadePlugin.java')
pkg = json.loads(ler('package.json'))

check('versão 1.32.0 ou posterior', tuple(int(x) for x in meta.get('version', '0').split('.')) >= (1, 32, 0) and meta.get('versionCode', 0) >= 10320)
check('app e pacote na mesma versão', ("const VERSAO_APP = '%s';" % meta['version']) in app and pkg.get('version') == meta['version'])
check('sistema.js existe e expõe o núcleo', (ROOT / 'sistema.js').is_file() and 'criarNucleo' in sis and 'registrarFerramenta' in sis)
check('ferramentas reais no catálogo', all(x in sis for x in ['calc', 'converter', 'senha', 'texto_estatisticas', 'json_formatar', 'hash', 'data_calcular']))
check('calculadora não usa eval', 'eval(' not in sis and 'Function(' not in sis)
check('permissões e confirmação no núcleo', "def.risco >= 2" in sis and "confirmar('Executar '" in sis)
check('traces não gravam valores', 'argsNomes' in sis and 'args: dados' not in sis)
check('tarefas e checkpoint no núcleo', 'criarTarefa' in sis and 'executarTarefa' in sis and 'sistema:tarefas' in sis)
check('detecção de injeção', 'detectarInjecao' in sis and 'PADROES_INJECAO' in sis and 'ignore' in sis)
check('app inicializa o núcleo', 'const SISTEMA' in app and 'SISTEMA.interpretar(texto)' in app)
check('central e painel no índice', 'id="painel-sistema"' in idx and 'data-lat="sistema"' in idx)
check('script sistema antes de app', idx.find('src="sistema.js"') > 0 and idx.find('src="sistema.js"') < idx.find('src="app.js"'))
check('painel registrado na navegação', "'#painel-sistema'" in app and "alvo === 'sistema'" in app)
check('diagnóstico de áudio sem gravação', 'diagnosticoAudioSistema' in app and 'MediaRecorder' not in app[app.find('function diagnosticoAudioSistema'):app.find('function diagnosticoAudioSistema')+2600])
check('botão de parada de emergência', 'sisPararTudo' in app and 'cancelarTodas' in app and 'interromperFala' in app)
check('plugin de acessibilidade registrado', 'registerPlugin(JarvisAcessibilidadePlugin.class)' in main)
check('serviço e permissão no manifesto', 'JarvisAcessibilidade' in manifest_patch and 'BIND_ACCESSIBILITY_SERVICE' in manifest_patch)
check('XML do serviço de acessibilidade', 'jarvis_acessibilidade.xml' in manifest_patch and 'canRetrieveWindowContent' in manifest_patch)
check('serviço não usa clique por coordenada', 'dispatchGesture' not in acess and 'GestureDescription' not in acess)
check('campos de senha são omitidos', 'isPassword()' in acess and 'senha' in acess)
check('plugin expõe status, árvore e ações', all(x in plugin for x in ['status', 'arvore', 'clicar', 'digitar', 'rolar', 'esperar', 'parar']))
check('ações de acessibilidade no catálogo e na voz', all(x in app for x in ['acessibilidade_status', 'acessibilidade_ler', 'acessibilidade_clicar', 'acessibilidade_digitar', 'acessibilidade_rolar', 'acessibilidade_esperar']) and 'cliqueTela' in app and 'digitarTela' in app)
check('workflow copia sistema.js', 'sistema.js' in ler('.github/workflows/build-apk.yml') and 'sistema.js' in ler('.github/workflows/release-apk.yml'))
check('workflow valida as classes novas', 'JarvisAcessibilidade.java' in ler('.github/workflows/build-apk.yml') and 'JarvisAcessibilidadePlugin.java' in ler('.github/workflows/release-apk.yml'))
check('pacote desktop inclui sistema.js', 'sistema.js' in pkg.get('build', {}).get('files', []))
check('testes do núcleo estão na suíte', 'test_sistema.js' in pkg['scripts']['test:all'] and 'test_v1_32_0.py' in pkg['scripts']['test:all'])
check('central tem todas as seções', all(x in idx for x in ['sis-ferramentas', 'sis-tarefas', 'sis-acess-status', 'sis-mic', 'sis-traces']))
check('ids da central não se repetem no HTML', all(len(re.findall(r'id="%s"' % re.escape(x), idx)) == 1 for x in ['painel-sistema','sis-status','sis-ferramentas','sis-tarefas','sis-acess-status','sis-mic','sis-traces','sis-parar']))
check('CHANGELOG registra 1.32.0', '## 1.32.0' in ler('CHANGELOG.md'))
check('rastreabilidade existe', (ROOT / 'docs' / 'RASTREABILIDADE-1.32.0.md').is_file())

if falhas:
    print('\n%d falha(s): %s' % (len(falhas), ', '.join(falhas)))
    sys.exit(1)
print('\nContrato 1.32.0 aprovado: %d verificações.' % ok)
