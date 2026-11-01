"""Contrato 1.38.1 — correções da auditoria sem regressão de recursos."""
import json
import pathlib
import re
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
app = (RAIZ / 'app.js').read_text(encoding='utf-8')
sistema = (RAIZ / 'sistema.js').read_text(encoding='utf-8')
hermes = (RAIZ / 'hermes.js').read_text(encoding='utf-8')
package = json.loads((RAIZ / 'package.json').read_text(encoding='utf-8'))
meta = json.loads((RAIZ / 'VERSAO.json').read_text(encoding='utf-8'))
lock = json.loads((RAIZ / 'package-lock.json').read_text(encoding='utf-8'))
gradle = (RAIZ / 'android/app/build.gradle').read_text(encoding='utf-8')
html = (RAIZ / 'index.html').read_text(encoding='utf-8')
suite = (RAIZ / 'tests/test_sistema.js').read_text(encoding='utf-8')
falhas = []


def check(nome, ok):
    print(('OK: ' if ok else 'FALHA: ') + nome)
    if not ok:
        falhas.append(nome)


check('versão 1.38.1 no metadado', meta.get('version') == '1.38.1' and meta.get('versionCode') == 10381)
check('package e lock acompanham a versão', package.get('version') == '1.38.1' and lock.get('version') == '1.38.1'
      and lock.get('packages', {}).get('', {}).get('version') == '1.38.1')
check('Gradle acompanha a versão', 'versionCode 10381' in gradle and 'versionName "1.38.1"' in gradle)
check('app e interface mostram a versão', "const VERSAO_APP = '1.38.1';" in app and 'v1.38.1' in html and 'v1.38.0' not in html)
check('build success exige hash real', meta.get('build', {}).get('resultado') == 'success'
      and bool(meta.get('build', {}).get('sha256')) and int(meta.get('build', {}).get('bytes', 0)) > 0)

# A Visão 2.0 tinha duas declarações de cada função; a última vencia e a primeira era
# código morto. O contrato impede que essa duplicação volte silenciosamente.
nomes = re.findall(r'^(?:async )?function ([A-Za-z0-9_]+)', app, re.M)
check('app.js não tem funções de topo duplicadas', len(nomes) == len(set(nomes)))
for nome in ('abrirVisao', 'limparBaloes', 'desenharBaloes', 'selecionarObjeto', 'analisarQuadro'):
    check('uma única definição de ' + nome, nomes.count(nome) == 1)
visao = app.split('function abrirVisao()', 1)[1].split('\nfunction ', 1)[0]
check('abrirVisao limpa a análise anterior', 'limparBaloes();' in visao and 'visaoProgressoFechar();' in visao)
check('layout avançado preservado', 'VIS.layoutBaloes(visaoObjetos' in app and 'visao-guias' in html)

# Cancelamento durante a etapa em voo: o resultado tardio não pode marcar a tarefa
# como concluída nem liberar a trava antes do finally.
check('cancelamento em voo tem guarda no núcleo', "if (t.estado === 'cancelada')" in sistema
      and "codigo: 'CANCELADA'" in sistema and "p.estado = 'incerto';" in sistema)
check('teste de cancelamento em voo está na suíte', 'cancelar durante a última etapa' in suite)
check('senha usa sorteio uniforme', 'inteiroSeguro(' in sistema and 'b[i] %' not in sistema)
check('prep de ação tem tratamento de exceção', 'try { p = def.prep(args); }' in app)

check('roteador filtra provedor desconhecido', 'filter((id) => !!CATALOGO[id])' in hermes and '|| true' not in hermes)
check('teste do roteador inválido está na suíte', 'roteador não estoura quando só há id inválido' in
      (RAIZ / 'tests/test_hermes.js').read_text(encoding='utf-8'))

check('suíte inclui este contrato', 'test_v1_38_1.py' in package.get('scripts', {}).get('test:all', ''))
check('documentação da correção existe', (RAIZ / 'docs/CORRECOES-1.38.1.md').exists()
      and (RAIZ / 'release/RELEASE-1.38.1.md').exists())
check('workflow cita a versão corrente', '1.38.1' in (RAIZ / '.github/workflows/build-apk.yml').read_text(encoding='utf-8')
      and '1.38.1' in (RAIZ / '.github/workflows/release-apk.yml').read_text(encoding='utf-8'))

if falhas:
    print('\n%d falha(s): %s' % (len(falhas), ', '.join(falhas)))
    sys.exit(1)
print('\n1.38.1: correções da auditoria verificadas.')
