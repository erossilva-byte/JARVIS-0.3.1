"""Auditoria do sistema de arquivos: gera com o motor real e valida por fora.

O gerador (tests/gerar_arquivos_auditoria.js) usa o mesmo módulo que o Electron
usa. A validação abaixo NÃO reutiliza esse código: lê os bytes, decodifica com a
biblioteca padrão do Python e confere estrutura, tamanho e SHA-256. Se as duas
implementações discordarem, o teste falha.
"""
import csv
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import zipfile
import xml.etree.ElementTree as ET

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
tmp = tempfile.mkdtemp(prefix='jv-arq-audit-')
proc = subprocess.run(
    ['node', os.path.join(RAIZ, 'tests', 'gerar_arquivos_auditoria.js'), tmp],
    capture_output=True, text=True
)
if proc.returncode != 0:
    print(proc.stdout)
    print(proc.stderr)
    sys.exit('o gerador de arquivos falhou')

dados = json.loads(proc.stdout)
home = dados['raiz']
jarvis = os.path.join(home, 'Jarvis')
falhas = []


def check(nome, condicao, detalhe=''):
    if condicao:
        print('OK: ' + nome)
    else:
        falhas.append(nome + (' -> ' + str(detalhe) if detalhe else ''))
        print('FALHA: ' + nome + ((' -> ' + str(detalhe)) if detalhe else ''))


def caminho(rel):
    return os.path.join(home, rel.replace('~/', '', 1))


arquivos = {a['nome']: a for a in dados['arquivos']}
check('15 arquivos criados pelo motor', len(arquivos) == 15, len(arquivos))

for nome, info in arquivos.items():
    p = caminho(info['rel'])
    if not os.path.exists(p):
        check('existe: ' + nome, False, p)
        continue
    bruto = open(p, 'rb').read()
    check('bytes conferem: ' + nome, len(bruto) == info['bytes'], '%s != %s' % (len(bruto), info['bytes']))
    check('SHA-256 confere: ' + nome, hashlib.sha256(bruto).hexdigest() == info['hash'])
    check('conteúdo intacto: ' + nome, bruto.decode('utf-8') == info['texto'])

# ---------- Estrutura por formato, conferida com a biblioteca padrão ----------
with open(caminho(arquivos['dados.csv']['rel']), encoding='utf-8', newline='') as f:
    linhas = list(csv.reader(f))
check('CSV com 3 linhas e 2 colunas', linhas == [['nome', 'idade'], ['Ana', '30'], ['Bia', '25']], linhas)

with open(caminho(arquivos['dados.json']['rel']), encoding='utf-8') as f:
    lista = json.load(f)
check('JSON volta como lista de objetos', lista[1] == {'nome': 'Bia', 'idade': '25'})

xml = ET.fromstring(open(caminho(arquivos['dados.xml']['rel']), encoding='utf-8').read())
check('XML com raiz e item', xml.tag == 'raiz' and xml.find('item').text == 'alfa')

svg = ET.fromstring(open(caminho(arquivos['desenho.svg']['rel']), encoding='utf-8').read())
check('SVG é XML válido com namespace', svg.tag.endswith('svg') and svg[0].tag.endswith('rect'))

html = open(caminho(arquivos['pagina.html']['rel']), encoding='utf-8').read()
check('HTML completo com charset e título',
      html.lstrip().lower().startswith('<!doctype html') and 'charset="utf-8"' in html and '<h1>Ola</h1>' in html)

rtf = open(caminho(arquivos['documento.rtf']['rel']), encoding='utf-8').read()
check('RTF válido: abre, fecha e chaves balanceadas',
      rtf.startswith('{\\rtf1') and rtf.endswith('}') and rtf.count('{') == rtf.count('}'))

py = open(caminho(arquivos['modulo.py']['rel']), encoding='utf-8').read()
try:
    compile(py, 'modulo.py', 'exec')
    compila = True
except SyntaxError:
    compila = False
check('Python compila e tem a função', compila and 'def soma' in py)

java = open(caminho(arquivos['App.java']['rel']), encoding='utf-8').read()
check('Java com classe e main', 'class App' in java and 'public static void main' in java)

c = open(caminho(arquivos['main.c']['rel']), encoding='utf-8').read()
cpp = open(caminho(arquivos['main.cpp']['rel']), encoding='utf-8').read()
check('C com include e main', '#include' in c and 'int main' in c)
check('C++ com iostream', 'std::cout' in cpp)
check('JS com função', 'function soma' in open(caminho(arquivos['script.js']['rel']), encoding='utf-8').read())
check('CSS com regra', 'color' in open(caminho(arquivos['estilo.css']['rel']), encoding='utf-8').read())
check('Markdown com título', open(caminho(arquivos['nota.md']['rel']), encoding='utf-8').read().startswith('# '))
check('Nome com acento e espaço preservado', 'relatório ção #1.txt' in arquivos and
      open(caminho(arquivos['relatório ção #1.txt']['rel']), encoding='utf-8').read() == 'acentos e espaços preservados\n')

# ---------- ZIP: CRC e conteúdo conferidos pelo zipfile ----------
z = dados['extras']['zip']
zp = caminho(z['rel'])
check('ZIP existe e tem o tamanho declarado', os.path.exists(zp) and os.path.getsize(zp) == z['bytes'])
check('SHA-256 do ZIP confere', hashlib.sha256(open(zp, 'rb').read()).hexdigest() == z['hash'])
with zipfile.ZipFile(zp) as zf:
    check('ZIP sem entrada corrompida (testzip)', zf.testzip() is None)
    check('ZIP com os 3 arquivos', set(zf.namelist()) == {'nota.txt', 'dados.csv', 'pagina.html'}, zf.namelist())
    check('Conteúdo dentro do ZIP bate com o original',
          zf.read('dados.csv').decode('utf-8') == arquivos['dados.csv']['texto'])
check('ZIP recém-criado passa na verificação de integridade', dados['extras']['verificarZip']['ok'] is True,
      dados['extras']['verificarZip']['problemas'])
check('ZIP truncado é reprovado com motivo',
      dados['extras']['verificarCorrompido']['ok'] is False and len(dados['extras']['verificarCorrompido']['problemas']) >= 1,
      dados['extras']['verificarCorrompido']['resumo'])
check('JSON inválido é detectado', dados['extras']['verificarJson']['ok'] is False)

# ---------- Conflito, backup e recusas ----------
check('Gravação concorrente é bloqueada', 'mudou desde' in dados['extras']['conflito'], dados['extras']['conflito'])
check('Arquivo não foi sobrescrito no conflito', dados['extras']['conflitoConteudo'] == 'mudou por fora\n')
check('Backup guarda a versão anterior',
      dados['extras']['backup']['existe'] and dados['extras']['backup']['anterior'] == 'versao original\n',
      dados['extras']['backup'])
check('Comparação de binário é recusada', 'Não comparo' in dados['extras']['compararBinario'])
check('Caminho fora da pasta do usuário é recusado', 'fora da pasta' in dados['extras']['traversal'])
check('Conteúdo acima de 8 MB é recusado', '8 MB' in dados['extras']['grande'])
check('Temporário órfão antigo é removido', dados['extras']['limpeza']['removidos'] == 1 and
      not os.path.exists(os.path.join(jarvis, 'orfao.txt.tmp-1234-antigo')))
check('Nenhum .tmp sobra depois das gravações', dados['extras']['temporariosRestantes'] == [],
      dados['extras']['temporariosRestantes'])

os.system('rm -rf ' + tmp)
if falhas:
    print('\n%d verificação(ões) do sistema de arquivos falharam.' % len(falhas))
    for f in falhas:
        print(' - ' + f)
    sys.exit(1)
print('\nSistema de arquivos: criação, integridade, ZIP, conflito e recusas validados.')
