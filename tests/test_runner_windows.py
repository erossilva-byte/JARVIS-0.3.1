"""Regressão do lançador de testes no Windows.

O script oficial `test:all` usa `python3` porque o CI roda em Linux. No Windows,
`python3` é o atalho da Microsoft Store e não executa Python, então a suíte não
rodava na máquina de desenvolvimento. `npm run test:all:win` traduz a mesma
suíte em tempo de execução, sem duplicar a lista de testes.

Este teste garante que:
  - o lançador e o resolvedor de Python existem;
  - o resolvedor tenta `py -3` antes de `python`;
  - a suíte oficial continua intacta (com `python3`), preservando o CI e os
    testes históricos que conferem o registro em `test:all`;
  - a tradução do comando não deixa `python3` para trás.
"""
import json
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
falhas = []


def check(nome, cond, detalhe=''):
    if cond:
        print('OK: ' + nome)
    else:
        falhas.append(nome + (' -> ' + str(detalhe) if detalhe else ''))
        print('FALHA: ' + nome + ((' -> ' + str(detalhe)) if detalhe else ''))


def ler(rel):
    with open(os.path.join(RAIZ, rel), encoding='utf-8') as f:
        return f.read()


with open(os.path.join(RAIZ, 'package.json'), encoding='utf-8') as f:
    pacote = json.load(f)
scripts = pacote.get('scripts', {})
suite = scripts.get('test:all', '')

check('test:all:win registrado', scripts.get('test:all:win') == 'node tests/run_suite_win.js',
      scripts.get('test:all:win'))
check('suíte oficial preservada com python3', 'python3 tests/' in suite)
check('lançador do Windows existe', os.path.isfile(os.path.join(RAIZ, 'tests', 'run_suite_win.js')))
check('resolvedor de Python existe', os.path.isfile(os.path.join(RAIZ, 'tests', 'python.js')))

lancador = ler(os.path.join('tests', 'run_suite_win.js'))
check('lançador lê a suíte do package.json', "scripts['test:all']" in lancador)
check('lançador troca só a invocação do Python', r'/\bpython3 /g' in lancador)
check('lançador usa o resolvedor', 'node tests/python.js ' in lancador)

resolvedor = ler(os.path.join('tests', 'python.js'))
check('resolvedor aceita override por ambiente', 'JARVIS_PYTHON' in resolvedor)
check('resolvedor prefere py -3 no Windows', "'py'" in resolvedor and "'-3'" in resolvedor)
check('resolvedor cai para python e python3', "'python'" in resolvedor and "'python3'" in resolvedor)

traduzido = suite.replace('python3 ', 'node tests/python.js ')
check('tradução elimina python3', 'python3 ' not in traduzido)
check('tradução mantém todos os scripts Python',
      traduzido.count('node tests/python.js ') == suite.count('python3 ') + suite.count('node tests/python.js '))

if falhas:
    print('\n%d falha(s):' % len(falhas))
    for f in falhas:
        print(' - ' + f)
    sys.exit(1)
print('\nLançador Windows: %d verificações aprovadas.' % 11)
