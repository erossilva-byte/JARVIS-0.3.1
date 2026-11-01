"""Contrato estático da 1.38.0: avatar, plano persistente, executores e auditorias."""
import json
import pathlib
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
def ler(n): return (RAIZ / n).read_text(encoding='utf-8')
app = ler('app.js'); html = ler('index.html'); css = ler('style.css'); avatar = ler('avatar.js')
sis = ler('sistema.js'); pkg = json.loads(ler('package.json')); meta = json.loads(ler('VERSAO.json'))
lock = json.loads(ler('package-lock.json'))
falhas = []
def check(nome, ok):
    print(('OK: ' if ok else 'FALHA: ') + nome)
    if not ok: falhas.append(nome)

check('versão 1.38.0 ou posterior e versionCode >= 10380', [int(x) for x in meta.get('version', '0').split('.')] >= [1, 38, 0] and meta.get('versionCode', 0) >= 10380)
check('app, pacote, lock e Gradle acompanham', ("const VERSAO_APP = '%s';" % meta['version']) in app and pkg.get('version') == meta['version'] and lock.get('version') == meta['version'] and ('versionCode %s' % meta['versionCode']) in ler('android/app/build.gradle'))
check('interface mostra a versão nova', html.count('v' + meta['version']) >= 5)
check('avatar existe e é carregado depois da órbita e antes do app', (RAIZ / 'avatar.js').is_file() and 'src="orbita.js"' in html and 'src="avatar.js"' in html and html.index('src="orbita.js"') < html.index('src="avatar.js"') < html.index('src="app.js"'))
check('seletor oferece Avatar 3D', 'value="avatar"' in html and 'Avatar 3D — rosto holográfico' in html)
check('prévia e cartão do avatar são reais', 'np-avatar' in html and '<b>Avatar 3D procedural</b>' in html and 'Ainda não implementado' not in html[html.index('Avatar 3D procedural'):html.index('Avatar 3D procedural')+800])
check('CSS do avatar cobre HUD e prévia', 'body[data-nucleo=avatar]' in css and 'np-avatar' in css)
check('avatar reage à amplitude e declara limites', 'audioNivel' in avatar and 'amplitude' in avatar and 'visemas' in avatar and 'Render2D' in avatar and 'suportaWebGL' in avatar)
check('avatar não usa innerHTML, rede ou CDN', 'innerHTML' not in avatar and 'fetch(' not in avatar and 'https://cdn' not in avatar)
check('app liga estado e nível ao avatar', 'window.AvatarJarvis.estado' in app and 'window.AvatarJarvis.nivel' in app)
check('ponte plano→núcleo presente', all(x in app for x in ['function tarefaDoPlano', 'function resultadoDaTarefaDoPlano', 'SISTEMA.executarTarefa', "ferramenta: 'plano_etapa'"]))
check('etapa interna não duplica confirmação da ação real', 'semConfirmacaoPropria: true' in app and 'def.semConfirmacaoPropria' in sis and 'executarSeguro({ nome: acao, args }' in app)
check('teste cobre confirmação única', 'despachante de etapa não duplica' in ler('tests/test_sistema.js'))
check('Core tem executores novos', all(("registrarExecutor('%s'" % n) in app for n in ['voz', 'automacao', 'atualizacao', 'planejamento']))
check('executor de voz usa diagnóstico real', "SISTEMA.executar('audio_diagnostico'" in app)
check('executor de automação consulta acessibilidade', "nativo('status'" in app and 'serviço de acessibilidade' in app)
check('auditorias de IA e repertório existem', (RAIZ / 'docs' / 'IA-1.38.0.md').is_file() and (RAIZ / 'docs' / 'REPERTORIO-1.38.0.md').is_file())
ia = ler('docs/IA-1.38.0.md'); rep = ler('docs/REPERTORIO-1.38.0.md')
check('auditoria de IA separa implementado de bloqueado', 'bloqueado' in ia.lower() and 'não prova' in ia.lower() and 'cota' in ia.lower())
check('auditoria do repertório tem inventário e classificação', '53 ações' in rep and '12 agentes' in rep and '6 executores' in rep and 'Não implementado' in rep)
check('avatar entra no pacote e nos workflows', 'avatar.js' in pkg['build']['files'] and all('avatar.js' in ler(w) for w in ('.github/workflows/build-apk.yml', '.github/workflows/release-apk.yml')))
check('suíte cobre avatar e contrato', 'node tests/test_avatar.js' in pkg['scripts']['test:all'] and 'python3 tests/test_v1_38_0.py' in pkg['scripts']['test:all'] and 'node --check avatar.js' in pkg['scripts']['test:all'])
check('workflows citam a versão corrente', all(meta.get('version') in ler(w) for w in ('.github/workflows/build-apk.yml', '.github/workflows/release-apk.yml')))
check('build não é declarado sem artefato', (meta.get('build') or {}).get('resultado') in ('pendente', 'success'))
check('módulos antigos preservados', all(x in app for x in ['function turno', 'function executarDiagnostico', 'function renderTarefas']) and 'function criarTarefa' in sis and 'Render3D.prototype.quadro' in ler('orbita.js'))

if falhas:
    print('\n%d verificação(ões) da 1.38.0 falharam.' % len(falhas))
    sys.exit(1)
print('1.38.0: avatar, plano persistente, executores e auditorias verificados.')
