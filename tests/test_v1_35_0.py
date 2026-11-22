"""Contrato estático da 1.35.0: autodiagnóstico, recuperação controlada e honestidade."""
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


check('versão 1.35.0 ou posterior', tuple(map(int, meta.get('version','0').split('.')[:2])) >= (1,35) and meta.get('versionCode',0) >= 10350)
check('app e pacote acompanham o metadado', "const VERSAO_APP = '%s';" % meta.get('version') in app and pkg.get('version') == meta.get('version'))
check('classificação de causa no Core', all(x in core for x in ['classificarCausa', 'temporaria', 'configuracao', 'critica']))
check('diagnóstico carrega causa, evidência e orientação', all(x in core for x in ['causa:', 'evidencias:', 'orientacao:']))
check('recuperação por componente com timeout', 'recuperarComponente' in core and 'recuperação excedeu 4 s' in core)
check('prevenção de loop por espera e limite', all(x in core for x in ['INTERVALO_RECUPERACAO_MS', 'JANELA_RECUPERACAO_MS', 'MAX_RECUPERACOES', 'aguardando']))
check('recuperação automática é opt-in por componente', 'recuperacaoAutomatica' in core and 'recuperarAutomatico' in core)
check('histórico de recuperação persistido', 'core:recuperacoes' in core and 'listarRecuperacoes' in core)
check('pré-checagem operacional antes de delegar', 'async function preflight' in core and 'Pré-checagem bloqueou' in core)
check('bloqueio não é mascarado por falha', 'bloqueado: true' in core)
check('componentes reais declaram categoria e recuperação', all(x in app for x in ["categoria: 'nucleo'", "categoria: 'dados'", 'recuperacaoAutomatica: true', 'recuperar: () =>']))
check('diagnóstico dos recursos sem números inventados', all(x in app for x in ['diagRecursosAparelho', 'performance.memory', 'getBattery', 'uso percentual de CPU não é exposto', 'não foi inventado']))
check('botão de recuperação no diagnóstico', 'c-recuperar-core' in html and 'recuperarCoreUI' in app)
check('Core mostra recuperação no painel', all(x in html for x in ['core-recuperar', 'core-recuperacoes', 'core-recuperacao-status']))
check('histórico do Core é renderizado sem innerHTML', 'renderRecuperacoes' in ui and 'listarRecuperacoes' in ui and 'innerHTML' not in ui)
check('estado de aviso tem estilo próprio', '.core-saude-linha.aviso' in css and '.core-rec' in css)
check('Core não promete reiniciar serviço Android', 'não reinicia serviços Android' in html and 'não reinicia serviços' in docs if (docs := ler('docs/RECUPERACAO-1.35.0.md')) else False)
check('relatório 1.35 existe e classifica os recursos', (RAIZ / 'docs' / 'RECUPERACAO-1.35.0.md').is_file() and all(
    x in ler('docs/RECUPERACAO-1.35.0.md') for x in ['IMPLEMENTADO E TESTADO', 'IMPLEMENTADO, MAS NÃO TESTADO', 'PARCIALMENTE IMPLEMENTADO', 'NÃO IMPLEMENTADO']))
check('suíte inclui o contrato 1.35', 'test_v1_35_0.py' in pkg['scripts']['test:all'] and 'node tests/test_core.js' in pkg['scripts']['test:all'])
check('workflows na versão atual', all(meta.get('version') in ler(w) for w in ('.github/workflows/build-apk.yml', '.github/workflows/release-apk.yml')))
check('build não é declarado sem artefato', (meta.get('build') or {}).get('resultado') in ('pendente', 'success'))
check('núcleo antigo continua presente', all(x in app for x in ['function executarDiagnostico', 'function abrirPainel', 'function recuperarComCodigo']))

if falhas:
    print('\n%d verificação(ões) da 1.35.0 falharam.' % len(falhas))
    sys.exit(1)
print('1.35.0: autodiagnóstico, recuperação controlada e limites verificados.')
