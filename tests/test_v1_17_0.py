"""Revisão 1.17.0 — TypeError do nível do núcleo, fluidez do 3D e arquivos .cad do CadSimu.

Os módulos são executados de verdade (Node) para o núcleo e para o parser `.cad`; o teste
não se limita a procurar strings.
"""
import json
import pathlib
import re
import subprocess
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent


def texto(nome):
    return (RAIZ / nome).read_text(encoding='utf-8')


def node(script):
    r = subprocess.run(['node', '-e', script], cwd=RAIZ, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit('falha no Node:\n' + r.stdout + r.stderr)
    return r.stdout


# ---------- 1. Causa raiz do "instancia.nivel is not a function" ----------
orbita = texto('orbita.js')
assert 'this.audioNivel = 0' in orbita, 'o valor do microfone precisa ter nome próprio'
assert not re.search(r'this\.nivel\s*=\s*[0-9]', orbita), 'this.nivel numérico voltaria a esconder o método'
assert 'Render3D.prototype.nivel = function' in orbita
assert 'Render2D.prototype.nivel = function' in orbita
assert "typeof atual.nivel === 'function'" in orbita, 'a fachada precisa conferir o tipo antes de chamar'
assert 'diagnostico: function' in orbita
assert 'NucleoOrbita.diagnostico' in orbita or 'diagnostico()' in orbita

# A API não pode estourar antes (ou sem) inicialização: era esse o caminho do crash.
saida = node(r"""
const N = require('./orbita.js');
N.nivel(0.5); N.estado('listening'); N.parar();
const d = N.diagnostico();
if (d.tipo !== null) throw new Error('diagnóstico deveria indicar núcleo não iniciado');
if (typeof N.nivel !== 'function') throw new Error('nivel precisa ser função na fachada');
if (typeof N.iniciar !== 'function') throw new Error('iniciar sumiu da API');
console.log('api-ok');
""")
assert 'api-ok' in saida

# O app continua chamando o nível a cada quadro e o estado na troca de estado.
app = texto('app.js')
assert 'NucleoOrbita.nivel(nivelPend)' in app
assert 'NucleoOrbita.estado(e)' in app
assert 'NucleoOrbita.iniciar(canvasOrb)' in app

# ---------- 2. 3D e fluidez ----------
assert 'WebGLRenderer' in orbita and 'ShaderMaterial' in orbita
assert 'RingGeometry' in orbita and 'IcosahedronGeometry' in orbita
assert 'getDelta' in orbita and 'Clock' in orbita
assert 'setPixelRatio' in orbita and 'dprTravado' in orbita
assert 'setDrawRange' in orbita, 'qualidade adaptativa precisa reduzir partículas, não só o dpr'
assert 'IntersectionObserver' in orbita, 'pausar fora da tela'
assert 'visibilitychange' in orbita
assert 'frustumCulled' in orbita
assert 'autoReset' in orbita
assert 'antialias: dprBase < 1.75' in orbita
assert 'forceContextLoss' in orbita
assert 'Render2D' in orbita, 'fallback obrigatório'

# Nenhuma alocação dentro do laço de quadro (heurística no corpo de quadro).
corpo = orbita[orbita.index('Render3D.prototype.quadro'):orbita.index('Render3D.prototype.destruir')]
assert ' new ' not in corpo, 'quadro não pode alocar por frame'
assert 'getBoundingClientRect' not in corpo, 'medir o canvas não pertence ao laço'

html = texto('index.html')
assert '<script src="vendor/three.min.js"></script>' in html
assert 'cdnjs' not in html and 'unpkg' not in html
assert (RAIZ / 'vendor/three.min.js').exists()
for wf in ('.github/workflows/build-apk.yml', '.github/workflows/release-apk.yml'):
    s = texto(wf)
    assert 'cp vendor/three.min.js www/vendor/three.min.js' in s

# ---------- 3. Arquivos .cad do CadSimu ----------
script = r"""
const Cad = require('./cad.js');
const dados = {};
Cad.usarStore({ getItem: (k) => (k in dados ? dados[k] : null), setItem: (k, v) => { dados[k] = v; } });

const doc = Cad.criar({ nome: 'peça-1', unidades: 'mm', tipo: 'caixa' });
doc.objetos[0].dimensoes = [100, 60, 20];
const texto = Cad.serializar(doc);
const p = Cad.parse(texto);
if (!p.ok) throw new Error('roundtrip falhou: ' + p.erro);
if (p.doc.objetos[0].tipo !== 'caixa') throw new Error('tipo perdido');

const a = Cad.analisar(texto);
if (!a.ok) throw new Error('análise falhou: ' + a.erro);
if (a.contagem.caixa !== 1) throw new Error('contagem errada');
if (Math.abs(a.caixa.tamanho[0] - 100) > 0.01) throw new Error('caixa envolvente errada');
if (!a.resumo.includes('caixa')) throw new Error('resumo sem tipo');

const invalidos = [
  ['', 'vazio'],
  ['{', 'JSON'],
  ['[]', 'objeto JSON'],
  ['{"formato":"Outro","versao":1,"objetos":[]}', 'Formato'],
  ['{"formato":"CadSimu CAD","versao":1}', 'objetos'],
  ['{"formato":"CadSimu CAD","versao":1,"objetos":[]}', 'objetos'],
  ['{"formato":"CadSimu CAD","versao":99,"objetos":[{"tipo":"caixa","dimensoes":[1,1,1]}]}', 'Versão'],
  ['{"formato":"CadSimu CAD","versao":1,"objetos":[{"tipo":"pirâmide","dimensoes":[1,1,1]}]}', 'não existe'],
  ['{"formato":"CadSimu CAD","versao":1,"objetos":[{"tipo":"caixa","dimensoes":[100,"x",20]}]}', 'dimensoes'],
  ['{"formato":"CadSimu CAD","versao":1,"objetos":[{"tipo":"caixa","dimensoes":[-1,2,3]}]}', 'maiores que zero'],
  ['{"formato":"CadSimu CAD","versao":1,"objetos":[{"tipo":"esfera","raio":0}]}', 'raio'],
  ['{"formato":"CadSimu CAD","versao":1,"objetos":[{"tipo":"cilindro","raio":2}]}', 'altura']
];
for (const [entrada, esperado] of invalidos) {
  let r;
  try { r = Cad.analisar(entrada); } catch (e) { throw new Error('exceção para entrada inválida: ' + e.message); }
  if (r.ok) throw new Error('entrada inválida aceita: ' + entrada);
  if (!String(r.erro).toLowerCase().includes(esperado.toLowerCase())) {
    throw new Error('mensagem fraca para "' + entrada + '": ' + r.erro);
  }
}
let r = Cad.analisar('{"formato":"CadSimu CAD","versao":1,"objetos":[{"tipo":"caixa","dimensoes":[1,1,1]}]}');
if (!r.ok || r.doc.unidades !== 'mm') throw new Error('unidade padrão deveria ser mm');

const s1 = Cad.salvar('peça 1', texto);
if (!s1.ok) throw new Error('salvar falhou: ' + s1.erro);
if (!s1.nome.endsWith('.cad') || /[\\/]/.test(s1.nome)) throw new Error('nome de arquivo inseguro: ' + s1.nome);
if (Cad.listar().length !== 1) throw new Error('lista deveria ter 1');
const salvo = Cad.ler('peça 1');
if (!salvo.ok || !salvo.texto.includes('CadSimu CAD')) throw new Error('leitura falhou');
if (Cad.salvar('x', '{') .ok) throw new Error('salvou arquivo inválido');
if (Cad.espaco().arquivos !== 1) throw new Error('espaço errado');
if (!Cad.apagar('peça 1').ok) throw new Error('apagar falhou');
if (Cad.listar().length !== 0) throw new Error('apagar não removeu');
if (Cad.apagar('inexistente').ok) throw new Error('apagar inexistente deveria falhar');
if (!Cad.parse(Cad.serializar(Cad.exemplo('exemplo'))).ok) throw new Error('exemplo inválido');
if (!Cad.nomeArquivo('../../etc/passwd').endsWith('.cad')) throw new Error('sanitização de nome');
if (/\.\.|\//.test(Cad.nomeArquivo('../../etc/passwd'))) throw new Error('caminho escapou do nome');

const muitos = { formato: 'CadSimu CAD', versao: 1, objetos: new Array(501).fill({ tipo: 'caixa', dimensoes: [1, 1, 1] }) };
if (Cad.analisar(JSON.stringify(muitos)).ok) throw new Error('limite de objetos não aplicado');
console.log('cad-ok');
"""
saida = node(script)
assert 'cad-ok' in saida

# Integração no app, voz e painel.
cad_js = texto('cad.js')
assert 'CadSimu CAD' in cad_js and 'LIMITE_OBJETOS = 500' in cad_js
assert 'const CAD = window.CadNucleo' in app
assert 'cadCriarDoTexto' in app and 'cadAnalisarPorNome' in app
assert 'confirmar(' in app[app.index('async function apagarCad'):app.index('function liberarEspacoCad')]
hermes = texto('hermes.js')
assert "id: 'arquivos'" in hermes and 'cap.cad' in hermes
assert 'data-lat="arquivos"' in html
for marca in ['painel-arquivos', 'cad-gerar', 'cad-analisar', 'cad-lista', 'cad-status', 'cad-importar']:
    assert marca in html, 'faltou ' + marca
assert "'#painel-arquivos'" in app
_pacote = json.loads(texto('package.json'))
assert 'cad.js' in _pacote['build']['files'] and 'vendor/**/*' in _pacote['build']['files']

# ---------- 4. Versão, documentação e suíte ----------
meta = json.loads(texto('VERSAO.json'))
pkg = json.loads(texto('package.json'))
assert [int(x) for x in str(meta['version']).split('.')] >= [1, 17, 0] and meta['versionCode'] >= 10170, meta
assert pkg['version'] == meta['version']
assert ("const VERSAO_APP = '%s';" % meta['version']) in app
assert ('<span class="orb-sub" aria-hidden="true">v%s</span>' % meta['version']) in html
changelog = texto('CHANGELOG.md')
assert '## 1.17.0' in changelog and '## 1.16.0' in changelog and '## 1.10.0' in changelog
assert changelog.count('\n## ') >= 30, 'CHANGELOG perdeu seções antigas'
assert '.cad' in changelog and 'instancia.nivel is not a function' in changelog
assert ('# J.A.R.V.I.S. Nova %s' % meta['version']) in texto('LEIA-ME.md')
assert 'python3 tests/test_v1_17_0.py' in pkg['scripts']['test:all']
assert 'node --check cad.js' in pkg['scripts']['test:all']
MODULOS_WWW = ('app.js', 'apps.js', 'hermes.js', 'plataforma.js', 'memoria.js', 'orbita.js',
               'cad.js', 'visao.js', 'pessoas.js')
for wf in ('.github/workflows/build-apk.yml', '.github/workflows/release-apk.yml'):
    s = texto(wf)
    copia = [l.strip() for l in s.splitlines() if l.strip().startswith('cp index.html')]
    assert len(copia) == 1 and copia[0].endswith(' www/'), (wf, copia)
    for mod in MODULOS_WWW:
        assert mod in copia[0].split(), (wf, mod)
    assert meta['version'] in s and '1.17.0' in texto('CHANGELOG.md')

# Ordem dos scripts: cad.js depois dos módulos base e antes do app.
ordem = [html.index('src="%s"' % n) for n in ['plataforma.js', 'memoria.js', 'vendor/three.min.js', 'orbita.js', 'cad.js', 'apps.js', 'hermes.js', 'app.js']]
assert ordem == sorted(ordem), 'scripts fora de ordem'

print('1.17.0: TypeError corrigido, núcleo 3D fluido e arquivos .cad validados')
