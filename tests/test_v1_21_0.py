"""Revisão 1.21.0 — cofre do Obsidian, memória por tópicos, recuperação relevante e núcleo 3D.

Roda o módulo de memória de verdade (Node) e confere as ligações nativas/desktop, a
interface e a coerência de versão. Não declara testado em aparelho o que só existe em código.
"""
import json
import pathlib
import subprocess
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent


def texto(nome):
    return (RAIZ / nome).read_text(encoding='utf-8')


app = texto('app.js')
html = texto('index.html')
css = texto('style.css')
mem = texto('memoria.js')
orbita = texto('orbita.js')
util = texto('JarvisUtilPlugin.java')
desktop = texto('platforms/desktop/main.js')
gradle = texto('patch_gradle.py')
meta = json.loads(texto('VERSAO.json'))
pkg = json.loads(texto('package.json'))

falhas = []


def checar(nome, ok):
    if not ok:
        falhas.append(nome)
    print(('OK: ' if ok else 'FALHA: ') + nome)


# ---------- 1. Memória por tópicos (comportamento real) ----------
script = r"""
const MEM = require('./memoria.js');
const db = {};
MEM.usarStore({ getItem: (k) => (k in db ? db[k] : null), setItem: (k, v) => { db[k] = String(v); } });
MEM.apagarTudo();
const a = MEM.anexarAoTopico('Prefiro respostas curtas e tom seco');
if (!a.ok || a.tema !== 'preferencias') throw new Error('classificação de preferência falhou: ' + JSON.stringify(a));
const b = MEM.anexarAoTopico('Gosto de café sem açúcar');
if (b.tema !== 'gostos') throw new Error('gostos falhou');
const c = MEM.anexarAoTopico('O projeto Jarvis está na fase de release');
if (c.tema !== 'projetos') throw new Error('projeto falhou');
const d = MEM.anexarAoTopico('Prefiro respostas curtas e tom seco');
if (!d.atualizada) throw new Error('segunda anotação deveria atualizar, não duplicar');
if (MEM.listar('preferencias').length !== 1) throw new Error('duplicou preferência');

const arqs = MEM.arquivosPorTopico();
const nomes = arqs.map((x) => x.nome).sort();
if (!nomes.includes('Memoria/Preferencias.md') || !nomes.includes('Memoria/Gostos.md')) throw new Error('arquivos por tópico: ' + nomes);
const pref = arqs.find((x) => x.tema === 'preferencias');
if (!/^---\ntitle: "Preferências"\ntema: preferencias/.test(pref.texto)) throw new Error('frontmatter do tópico');
if (!/\n## Prefiro respostas curtas/.test(pref.texto)) throw new Error('seção por nota');

const ctx = MEM.contextoRelevante('quais são minhas preferências?', 800);
if (!/Preferências/.test(ctx)) throw new Error('contexto não achou a preferência: ' + ctx);
const nada = MEM.contextoRelevante('qual a capital da Mongólia?', 800);
if (nada !== '') throw new Error('contexto inventou memória para pergunta sem relação');

const antes = MEM.listar().length;
const imp = MEM.importarMarkdown(arqs.map((x) => x.texto).join('\n'));
if (!imp.ok) throw new Error('importação dos tópicos falhou: ' + JSON.stringify(imp));
if (MEM.listar().length !== antes) throw new Error('reaimportação mudou a contagem: ' + antes + ' -> ' + MEM.listar().length);

const esp = MEM.espaco();
if (!(esp.notas >= 3) || !(esp.bytes > 0)) throw new Error('espaço inválido');
const topicos = MEM.topicos();
if (topicos.length < 10) throw new Error('esperava 10 tópicos, veio ' + topicos.length);
console.log('mem-ok');
"""
r = subprocess.run(['node', '-e', script], cwd=RAIZ, capture_output=True, text=True)
checar('Memória classifica por assunto, atualiza sem duplicar e recupera só o relevante',
      r.returncode == 0 and 'mem-ok' in r.stdout)
if r.returncode != 0:
    print(r.stdout + r.stderr)

checar('Dez tópicos com arquivo próprio', mem.count("'Memoria/") >= 10 and 'arquivosPorTopico' in mem)
checar('Contexto vazio quando não há registro', 'return \'\';' in mem and 'contextoRelevante' in mem)
checar('Importação entende seções ## dos arquivos por tópico', "split(/\\n\\s*##\\s+/)" in mem)

# ---------- 2. Cofre: Android (SAF) e PC ----------
for metodo in ['escolherCofre', 'cofreStatus', 'cofreListar', 'cofreLer', 'cofreEscrever', 'esquecerCofre']:
    checar('SAF: ' + metodo, ('public void ' + metodo) in util)
checar('SAF pede permissão persistente', 'takePersistableUriPermission' in util and 'ACTION_OPEN_DOCUMENT_TREE' in util)
checar('SAF só grava em Memoria/', 'caminho.startsWith("Memoria/")' in util)
checar('Dependência androidx.documentfile', 'androidx.documentfile' in gradle)
checar('Desktop escolhe cofre no diálogo nativo', 'escolher_cofre' in desktop and 'showOpenDialog' in desktop)
checar('Desktop só grava em Memoria/', "if (!/^Memoria\\//.test(rel))" in desktop)
checar('Desktop não apaga notas do cofre', 'unlinkSync(alvo)' not in desktop)

# ---------- 3. Interface do cofre ----------
for marca in ['id="obs-ativo"', 'id="obs-escolher"', 'id="obs-testar"', 'id="obs-enviar"',
              'id="obs-receber"', 'id="obs-organizar"', 'id="obs-desconectar"', 'id="obs-topicos"',
              'id="obs-diag"', 'id="obs-local"']:
    checar('Interface: ' + marca, marca in html)
checar('Interface lista os tópicos novos', all(t in html for t in ['data-mem-tema="preferencias"', 'data-mem-tema="objetivos"', 'data-mem-tema="estudos"', 'data-mem-tema="dispositivos"']))
checar('app.js conecta, envia, recebe e organiza', all(f in app for f in ['function obsEscolher', 'async function obsEnviar', 'async function obsReceber', 'async function obsOrganizar']))
checar('Prompt usa a memória relevante', 'MEM.contextoRelevante(perguntaAtual, 1600)' in app and 'Memória conectada (notas por tópico' in app)
checar('Bloqueio reflete o estado ao abrir Ajustes', 'atualizarBloqueioUI();' in app and 'preencherPainelAtualizacao();' in app)
checar('Tópicos renderizados no painel', 'function renderObsTopicos' in app and 'renderObsTopicos()' in app)
checar('Estilo do cofre no CSS', '.obs-avancado' in css and '#obs-topicos' in css)

# ---------- 4. Núcleo 3D ----------
checar('Paletas de processamento e erro', 'processing:' in orbita and 'error:' in orbita and 'PALETAS.erro' in orbita)
checar('Quarto anel orbital', 'var raios = [2.05, 2.42, 2.78, 3.14];' in orbita and 'for (var a = 0; a < 4; a++)' in orbita)
checar('Varredura holográfica animada', 'this.varredura' in orbita and 'varredura.position.y' in orbita)
checar('Anéis respondem à energia do estado', 'this.alvo.anel' in orbita)
checar('Sem alocação por quadro preservada', ' new ' not in orbita[orbita.index('Render3D.prototype.quadro'):orbita.index('Render3D.prototype.destruir')])

# ---------- 5. Versão, documentação, suíte ----------
checar('Versão >= 1.21.0 / 10210',
      tuple(int(x) for x in meta['version'].split('.')) >= (1, 21, 0)
      and meta['versionCode'] >= 10210 and pkg['version'] == meta['version'])
checar('app.js e interface na versão',
      ("const VERSAO_APP = '" + meta['version'] + "';") in app and html.count('v' + meta['version']) >= 2)
checar('CHANGELOG e LEIA-ME com a versão corrente',
      '## 1.21.0' in texto('CHANGELOG.md') and '## 1.21.1' in texto('CHANGELOG.md')
      and ('# J.A.R.V.I.S. Nova ' + meta['version']) in texto('LEIA-ME.md'))
checar('Suíte roda este teste', 'python3 tests/test_v1_21_0.py' in pkg['scripts']['test:all'])
checar('Workflows na versão atual',
      meta['version'] in texto('.github/workflows/build-apk.yml') and meta['version'] in texto('.github/workflows/release-apk.yml'))
checar('Workflow do PC existe', (RAIZ / '.github/workflows/release-pc.yml').exists())

if falhas:
    print('\n%d verificação(ões) da 1.21.0 falharam.' % len(falhas))
    sys.exit(1)
print('\n1.21.0: cofre Obsidian, memória por tópicos, recuperação relevante e núcleo 3D verificados.')
