"""Pacote CAD do celular conferido por fora, com o zipfile do Python."""
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import zipfile

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
tmp = tempfile.mkdtemp(prefix='jv-pacote-cad-')
proc = subprocess.run(['node', os.path.join(RAIZ, 'tests', 'gerar_pacote_cad.js'), tmp], capture_output=True, text=True)
if proc.returncode != 0:
    print(proc.stdout); print(proc.stderr); sys.exit('o gerador do pacote falhou')
d = json.loads(proc.stdout)
falhas = []
def check(nome, cond, det=''):
    if cond: print('OK: ' + nome)
    else:
        falhas.append(nome); print('FALHA: ' + nome + ((' -> ' + str(det)) if det else ''))

check('Pacote gerado', os.path.exists(d['zip']))
z = zipfile.ZipFile(d['zip'])
nomes = set(z.namelist())
check('Sem entrada corrompida (testzip)', z.testzip() is None)
for esperado in ['suporte-de-parede.cad', 'suporte-de-parede.dxf', 'suporte-de-parede.stl',
                 'suporte-de-parede.step', 'suporte-de-parede.scad', 'RELATORIO.md', 'LEIA-ME.txt', 'projeto.json']:
    check('Entrada ' + esperado, esperado in nomes, sorted(nomes))

cad = json.loads(z.read('suporte-de-parede.cad').decode('utf-8'))
check('Projeto .cad dentro do ZIP é JSON válido', cad.get('formato') == 'CadSimu CAD' and len(cad.get('objetos', [])) == 2, cad.get('formato'))
check('Unidades preservadas no .cad', cad.get('unidades') == 'mm')
check('DXF começa com SECTION', z.read('suporte-de-parede.dxf').decode('utf-8').lstrip().startswith('0'), z.read('suporte-de-parede.dxf')[:40])
check('STL tem cabeçalho binário mínimo', len(z.read('suporte-de-parede.stl')) >= 84)
step = z.read('suporte-de-parede.step').decode('utf-8')
check('STEP com ISO-10303-21', step.startswith('ISO-10303-21'), step[:30])
scad = z.read('suporte-de-parede.scad').decode('utf-8')
check('OpenSCAD com scale e cube', 'scale([' in scad and 'cube([' in scad)
rel = z.read('RELATORIO.md').decode('utf-8')
check('Relatório separa medido de estimado', 'MEDIDO aqui' in rel and 'ESTIMADO' in rel)
check('Relatório declara não suportados', 'NÃO SUPORTADO' in rel and 'CADe SIMU' in rel)
check('Relatório traz volume medido', 'Volume:' in rel)
leia = z.read('LEIA-ME.txt').decode('utf-8')
check('Instruções citam OpenSCAD e STEP', 'OpenSCAD' in leia and 'STEP' in leia)
check('Instruções avisam sobre .cad próprio', 'NÃO é o .cad do CADe SIMU' in leia)
proj = json.loads(z.read('projeto.json').decode('utf-8'))
check('projeto.json preserva a especificação', proj['unidades'] == 'mm' and len(proj['objetos']) == 2)
check('Pacote abaixo de 64 MB', d['tamanho'] < 64 * 1024 * 1024)
check('Validação do projeto aprovada', d['validacao']['ok'] is True, d['validacao'])
check('Volume coerente com a geometria', d['volumes']['volume'] > 0)

os.system('rm -rf ' + tmp)
if falhas:
    print('\n%d verificação(ões) do pacote CAD falharam.' % len(falhas)); sys.exit(1)
print('\nPacote CAD: ZIP, formatos, relatório e instruções validados por fora.')
