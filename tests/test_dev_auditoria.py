"""Audita os formatos reais do Desenvolvimento de Arquivos por fora do motor.

O gerador roda o mesmo módulo que o aplicativo usa; esta validação NÃO reutiliza
o código JS: abre os bytes com zipfile, xml.etree, csv e json da biblioteca padrão.
Se as duas implementações discordarem, o teste falha.
"""
import csv
import hashlib
import io
import json
import os
import subprocess
import sys
import tempfile
import zipfile
import xml.etree.ElementTree as ET

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
tmp = tempfile.mkdtemp(prefix='jv-dev-audit-')
proc = subprocess.run(['node', os.path.join(RAIZ, 'tests', 'gerar_dev_auditoria.js'), tmp],
                      capture_output=True, text=True)
if proc.returncode != 0:
    print(proc.stdout)
    print(proc.stderr)
    sys.exit('o gerador do desenvolvimento de arquivos falhou')

dados = json.loads(proc.stdout)
falhas = []


def check(nome, cond, detalhe=''):
    if cond:
        print('OK: ' + nome)
    else:
        falhas.append(nome)
        print('FALHA: ' + nome + ((' -> ' + str(detalhe)) if detalhe else ''))


info = {a['nome']: a for a in dados['arquivos']}
check('seis formatos gerados', len(info) == 6, sorted(info))

for nome, meta in info.items():
    caminho = os.path.join(tmp, nome)
    bruto = open(caminho, 'rb').read()
    check('existe e tem bytes: ' + nome, len(bruto) == meta['bytes'] and len(bruto) > 0, len(bruto))
    check('SHA-256 confere: ' + nome, hashlib.sha256(bruto).hexdigest() == meta['sha256'])

# ---------------- PDF ----------------
pdf = open(os.path.join(tmp, 'relatorio.pdf'), 'rb').read()
check('PDF começa com %PDF-1.4', pdf.startswith(b'%PDF-1.4'))
check('PDF termina com %%EOF', pdf.rstrip().endswith(b'%%EOF'))
check('PDF tem catálogo e página', b'/Type /Catalog' in pdf and b'/Type /Page' in pdf)
check('PDF tem fonte Helvetica', b'/BaseFont /Helvetica' in pdf)
pos = pdf.rfind(b'startxref')
inicio = int(pdf[pos + 9:].split()[0])
check('startxref aponta para a tabela xref', pdf[inicio:inicio + 4] == b'xref', inicio)

# ---------------- DOCX ----------------
with zipfile.ZipFile(os.path.join(tmp, 'documento.docx')) as z:
    check('DOCX sem corrupção', z.testzip() is None)
    nomes = set(z.namelist())
    check('DOCX contém as partes OOXML', {'[Content_Types].xml', '_rels/.rels', 'word/document.xml'} <= nomes, nomes)
    raiz = ET.fromstring(z.read('word/document.xml'))
    textos = [t.text or '' for t in raiz.iter('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}t')]
    check('DOCX preserva os dois parágrafos', len(textos) == 2, textos)
    check('DOCX escapa símbolos', 'Segundo parágrafo com <tags> & símbolos.' in textos, textos)

# ---------------- XLSX ----------------
with zipfile.ZipFile(os.path.join(tmp, 'planilha.xlsx')) as z:
    check('XLSX sem corrupção', z.testzip() is None)
    nomes = set(z.namelist())
    check('XLSX contém as partes OOXML', {'[Content_Types].xml', 'xl/workbook.xml', 'xl/worksheets/sheet1.xml'} <= nomes, nomes)
    wb = ET.fromstring(z.read('xl/workbook.xml'))
    abas = [s.get('name') for s in wb.iter('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}sheet')]
    check('XLSX usa o nome da aba pedido', abas == ['Pessoas'], abas)
    folha = ET.fromstring(z.read('xl/worksheets/sheet1.xml'))
    celulas = [t.text or '' for t in folha.iter('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t')]
    check('XLSX tem cabeçalho e duas linhas', celulas == ['Nome', 'Idade', 'Ana', '30', 'Bia', '25'], celulas)

# ---------------- CSV ----------------
with open(os.path.join(tmp, 'dados.csv'), encoding='utf-8', newline='') as f:
    linhas = list(csv.reader(f, delimiter=';'))
check('CSV converteu JSON em linhas reais', linhas == [['nome', 'nota'], ['Ana', '9'], ['Bia', '8']], linhas)

# ---------------- JSON ----------------
conf = json.load(open(os.path.join(tmp, 'config.json'), encoding='utf-8'))
check('JSON gerado abre e mantém os dados', conf == {'ativo': True, 'itens': [1, 2, 3]}, conf)

# ---------------- ZIP de projeto ----------------
with zipfile.ZipFile(os.path.join(tmp, 'projeto.zip')) as z:
    check('ZIP sem corrupção', z.testzip() is None)
    nomes = sorted(z.namelist())
    check('ZIP preserva a estrutura de pastas', nomes == ['README.md', 'src/main.py', 'src/util.py'], nomes)
    check('ZIP preserva o conteúdo', b'def soma' in z.read('src/util.py'))

if falhas:
    print('\n%d verificação(ões) do desenvolvimento de arquivos falharam.' % len(falhas))
    raise SystemExit(1)
print('\nDesenvolvimento de arquivos: PDF, DOCX, XLSX, CSV, JSON e ZIP validados por leitores externos.')
