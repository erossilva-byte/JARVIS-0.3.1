"""Contrato da 1.37.0: retomada sem duplicar, pausa entre etapas e lembretes."""
import json
import pathlib
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
def ler(n): return (RAIZ / n).read_text(encoding='utf-8')
app = ler('app.js'); html = ler('index.html'); sis = ler('sistema.js'); tests = ler('tests/test_sistema.js')
meta = json.loads(ler('VERSAO.json')); pkg = json.loads(ler('package.json'))
gradle_path = RAIZ / 'android/app/build.gradle'\ngradle = gradle_path.read_text(encoding='utf-8') if gradle_path.exists() else ''\npatch_android = ler('patch_android_version.py')
falhas = []
def check(nome, ok):
    print(('OK: ' if ok else 'FALHA: ') + nome)
    if not ok: falhas.append(nome)

check('versão 1.37.0 ou posterior e versionCode >= 10370', tuple(map(int, meta.get('version','0').split('.')[:2])) >= (1,37) and meta.get('versionCode',0) >= 10370)
check('app, pacote e patch Gradle acompanham', ("const VERSAO_APP = '%s';" % meta.get('version')) in app and pkg.get('version') == meta.get('version') and ('versionCode %s' % meta.get('versionCode')) in patch_android and (not gradle or ('versionCode %s' % meta.get('versionCode')) in gradle))
check('pausa manual exposta pelo núcleo', 'function pausarTarefa' in sis and 'pausarTarefa,' in sis)
check('retomada não reexecuta etapa incerta', 'autorizado sem repetir' in sis and 'não é reexecutá-la' in sis)
check('pausa só entre etapas', 'pausasSolicitadas' in sis and 'entreEtapas' in sis)
check('UI diferencia iniciar, continuar e pausar', all(x in app for x in ["b.textContent", "t.estado === 'pausada' ? 'Continuar'", "b.textContent = 'Pausar'", "SISTEMA.pausarTarefa"]))
check('UI atualiza ao pausar/cancelar', "SISTEMA.ao('tarefa:pausa'" in app and "SISTEMA.ao('tarefa:cancelada'" in app)
check('teste cobre duplicação e pausa', 'autorizado sem repetir' in tests and 'pausa manual entre etapas' in tests)
check('texto de lembrete corresponde ao código', '09:00' in html and 'ainda não são agendadas' not in html and 'agendarAvisoTarefa' in app)
check('contrato 1.37 está na suíte', 'tests/test_v1_37_0.py' in pkg['scripts']['test:all'])
check('relatório 1.37 existe', (RAIZ / 'docs' / 'CORRECOES-1.37.0.md').is_file())
check('build não é declarado sem artefato', (meta.get('build') or {}).get('resultado') in ('pendente', 'success'))
check('módulos anteriores preservados', all(x in app for x in ['function turno', 'function executarDiagnostico', 'function renderTarefas']) and 'function criarTarefa' in sis)
if falhas:
    print('\n%d verificação(ões) da 1.37.0 falharam.' % len(falhas)); sys.exit(1)
print('1.37.0: retomada, pausa e lembretes coerentes verificados.')
