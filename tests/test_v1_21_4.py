"""Revisão 1.21.4 — Obsidian dentro de Ajustes ▸ Memória, erros recentes e polimento do bloqueio."""
import json
import pathlib
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent


def texto(nome):
    return (RAIZ / nome).read_text(encoding='utf-8')


app = texto('app.js')
html = texto('index.html')
css = texto('style.css')
meta = json.loads(texto('VERSAO.json'))
pkg = json.loads(texto('package.json'))
falhas = []


def checar(nome, ok):
    print(('OK: ' if ok else 'FALHA: ') + nome)
    if not ok:
        falhas.append(nome)


# ---------- 1. Obsidian dentro da aba Memória dos Ajustes ----------
aba = html.index('data-category="memoria"')
bloco = html.index('id="obs-bloco"')
rotinas = html.index('data-category="rotinas"')
checar('Bloco do cofre está dentro da aba Memória', aba < bloco < rotinas)
checar('Aba Memória mantém a memória pessoal', 'id="c-memoria"' in html and html.index('id="c-memoria"') < bloco)
for marca in ['id="obs-ativo"', 'id="obs-escolher"', 'id="obs-testar"', 'id="obs-enviar"',
              'id="obs-receber"', 'id="obs-organizar"', 'id="obs-desconectar"', 'id="obs-topicos"', 'id="obs-diag"']:
    checar('Controle do cofre presente: ' + marca, marca in html)
checar('Painel Memória aponta para a aba dos Ajustes',
      'id="mem-abrir-obs"' in html and 'Ajustes ▸ Memória' in html)
checar('Atalho ligado no app.js',
      "abrirNosAjustes.onclick = () => { abrirConfig(); mudarCategoriaConfig('memoria'); };" in app)
checar('Aba consulta o estado real do cofre ao abrir',
      "if (cat === 'memoria' && typeof atualizarObsUI === 'function')" in app
      and "if (typeof atualizarObsUI === 'function') atualizarObsUI().catch(() => {});" in app)
checar('Nenhum ID duplicado no HTML', len({i for i in __import__('re').findall(r'id="([^"]+)"', html)}) == len(__import__('re').findall(r'id="([^"]+)"', html)))

# ---------- 2. Organização e recuperação por assunto (comportamento real) ----------
import subprocess
script = r"""
const MEM = require('./memoria.js');
const db = {};
MEM.usarStore({ getItem: (k) => (k in db ? db[k] : null), setItem: (k, v) => { db[k] = String(v); } });
MEM.apagarTudo();
const casos = [
  ['Gosto de café sem açúcar', 'gostos'],
  ['Prefiro respostas curtas', 'preferencias'],
  ['O projeto Jarvis está na fase de release', 'projetos'],
  ['Meu objetivo é publicar até dezembro', 'objetivos'],
  ['Estudo Kotlin nas terças', 'estudos']
];
for (const [txt, tema] of casos) {
  const r = MEM.anexarAoTopico(txt);
  if (!r.ok || r.tema !== tema) throw new Error('classificação: ' + txt + ' -> ' + JSON.stringify(r));
}
const arqs = MEM.arquivosPorTopico().map((a) => a.nome).sort();
for (const esperado of ['Memoria/Gostos.md', 'Memoria/Preferencias.md', 'Memoria/Projetos.md', 'Memoria/Objetivos.md', 'Memoria/Estudos.md'])
  if (!arqs.includes(esperado)) throw new Error('arquivo ausente: ' + esperado);
const ctx = MEM.contextoRelevante('quais são meus gostos?', 900);
if (!/café/i.test(ctx)) throw new Error('não recuperou o gosto: ' + ctx);
const vazio = MEM.contextoRelevante('qual a capital da Mongólia?', 900);
if (vazio !== '') throw new Error('inventou memória');
const dup = MEM.anexarAoTopico('Gosto de café sem açúcar');
if (!dup.atualizada) throw new Error('repetição deveria atualizar, não duplicar');
if (MEM.listar('gostos').length !== 1) throw new Error('duplicou nota de gosto');
console.log('mem-ok');
"""
r = subprocess.run(['node', '-e', script], cwd=RAIZ, capture_output=True, text=True)
checar('Classifica por assunto, grava um arquivo por tópico e recupera o relevante',
      r.returncode == 0 and 'mem-ok' in r.stdout)
if r.returncode != 0:
    print(r.stdout + r.stderr)

# ---------- 3. Diagnóstico ----------
checar('Verificação de erros recentes', "'Erros recentes'" in app and "store.get('log', '[]')" in app)
checar('Mantém os sete estados', all(x in app for x in ['Operacional', 'Não configurado', 'Desativado', 'Não verificado']))
checar('Cofre é verificado no diagnóstico', "'Cofre do Obsidian'" in app)

# ---------- 4. Bloqueio: polimento sem mudar segurança ----------
checar('Núcleo e tipografia ajustados', '.bloq-nucleo{position:relative;flex:none;width:88px;height:88px' in css
      and 'font-size:clamp(1.72rem,6.2vw,2.28rem)' in css)
checar('Layout estreito sem linhas decorativas', '@media(max-width:430px)' in css and '.bloq-linha{display:none}' in css)
checar('Segurança intacta', "store.get('pin_hash'" in app and 'BLOQ_ATE' in app and 'hashPin(pin)' in app)
checar('Bloqueio segue opcional', "store.get('bloqueio', '0') === '1'" in app)

# ---------- 5. Versão e entrega ----------
def _tri(v):
    return tuple(int(x) for x in str(v).split('.')[:3])
checar('Versão a partir da 1.21.4 / 10214',
      _tri(meta['version']) >= (1, 21, 4) and meta['versionCode'] >= 10214 and pkg['version'] == meta['version'])
checar('app.js e interface na versão corrente',
      ("const VERSAO_APP = '" + meta['version'] + "';") in app and html.count('v' + meta['version']) >= 2)
checar('CHANGELOG mantém a entrada 1.21.4 e o LEIA-ME segue versionado',
      '## 1.21.4' in texto('CHANGELOG.md') and ('# J.A.R.V.I.S. Nova ' + meta['version']) in texto('LEIA-ME.md'))
checar('Suíte roda este teste', 'python3 tests/test_v1_21_4.py' in pkg['scripts']['test:all'])
checar('Workflows na versão corrente', meta['version'] in texto('.github/workflows/build-apk.yml') and meta['version'] in texto('.github/workflows/release-apk.yml'))
checar('Funções antigas preservadas', all(x in app for x in ['function obsEscolher', 'function executarDiagnostico', 'function tentarDesbloquear', 'function verificarAtualizacaoUI']))

if falhas:
    print('\n%d verificação(ões) da 1.21.4 falharam.' % len(falhas))
    sys.exit(1)
print('1.21.4: Obsidian em Ajustes ▸ Memória, recuperação por assunto e bloqueio refinado verificados.')
