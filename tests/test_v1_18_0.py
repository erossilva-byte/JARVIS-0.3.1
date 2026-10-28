"""Revisão 1.18.0 — núcleo 3D no celular e no PC, auditoria do APK e instalação no PC.

O que este teste protege:
  1. o tamanho das partículas no shader (o bug que estourava a tela em branco);
  2. o teste de WebGL que não pode consumir o contexto do canvas real;
  3. a recuperação de contexto perdido, o redimensionamento e a máscara circular;
  4. o fallback 2D executando de verdade (simulado, sem navegador);
  5. as correções de auditoria do APK (startForeground, player, minSdk, HTTP);
  6. versão, documentação e workflows do release.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def texto(nome):
    return (ROOT / nome).read_text(encoding='utf-8')


orbita = texto('orbita.js')
css = texto('style.css')
app = texto('app.js')
html = texto('index.html')

# ---------- 1. Tamanho das partículas ----------
assert '250.0 / max' not in orbita, 'fórmula antiga (~46x) voltou ao shader'
assert 'uniform float uPixelRatio;' in orbita, 'falta o pixel ratio no shader'
assert 'aSize * uEscala * uPixelRatio * (3.2 / max(0.9, vDepth))' in orbita
assert 'clamp(tamanho * (1.0 + uAudio * 0.55), 1.0, 22.0)' in orbita, 'sem limite de tamanho'
assert 'this.uniformes.uPixelRatio.value = dpr;' in orbita, 'pixel ratio do renderer não chega ao shader'
assert 'uOpacity: { value: 0.78 }' in orbita
assert 'opacity: 0.30,' in orbita and 'this.brilho.scale.set(3.5, 3.5, 1)' in orbita

# Simulação numérica da fórmula: câmera a 5,4, esfera de raio 1,55 e brilho até 4,5.
def tamanho_px(a_size, dpr, profundidade, audio):
    base = a_size * 1.0 * dpr * (3.2 / max(0.9, profundidade))
    return min(22.0, max(1.0, base * (1.0 + audio * 0.55)))

medidas = [tamanho_px(a, dpr, prof, audio)
           for a in (1.0, 2.7)
           for dpr in (1, 1.5, 2, 3)
           for prof in (0.9, 3.85, 5.4, 6.95, 9.0)
           for audio in (0, 0.5, 1)]
assert max(medidas) <= 22.0
assert min(medidas) >= 1.0
# No pior caso real (partícula colada na câmera, microfone no máximo) o sprite não pode
# passar de 22 px: com 2.100 partículas, acima disso o blending aditivo satura a tela.
assert tamanho_px(2.7, 3, 0.9, 1.0) == 22.0
assert tamanho_px(1.0, 1, 5.4, 0) < 2.0, 'no PC (dpr 1) a partícula precisa ser discreta'

# ---------- 2. Teste de WebGL não usa o canvas real ----------
assert 'suportaWebGL()' in orbita, 'o teste de WebGL ainda recebe o canvas'
assert 'suportaWebGL(canvas)' not in orbita.split('function criar')[1]
assert "raiz.document.createElement('canvas')" in orbita
assert "getExtension('WEBGL_lose_context')" in orbita

# ---------- 3. Contexto perdido, tamanho e máscara ----------
assert "'webglcontextlost'" in orbita and "'webglcontextrestored'" in orbita
assert 'aoPerderContexto' in orbita and 'aoRecuperarContexto' in orbita
assert 'new raiz.ResizeObserver' in orbita
assert orbita.count('new raiz.ResizeObserver') >= 2, 'o fallback 2D também precisa reagir ao tamanho'
assert 'api._vigia = raiz.setTimeout' in orbita and '}, 1500);' in orbita
assert 'cloneNode(false)' in orbita, 'fallback 2D precisa de um canvas limpo'
assert 'contextoPerdido' in orbita and 'contextoPerdido: !!atual.contextoPerdido' in orbita
assert 'mask-image:radial-gradient' in css and '.hud .nucleo-orbita' in css

# ---------- 4. Fallback 2D realmente desenha (sem navegador) ----------
smoke = r"""
const fs = require('node:fs');
const vm = require('node:vm');
const fonte = fs.readFileSync(process.env.ORBITA_PATH, 'utf8');

const chamadas = [];
const ctx2d = {
  setTransform(){ chamadas.push('setTransform'); },
  clearRect(){ chamadas.push('clearRect'); },
  createRadialGradient(){ return { addColorStop(){} }; },
  beginPath(){}, arc(){}, fill(){ chamadas.push('fill'); }, fillRect(){ chamadas.push('fillRect'); },
  set fillStyle(v){}, get fillStyle(){ return '#000'; }
};
function novoCanvas(){
  return {
    width: 0, height: 0, parentNode: null,
    getContext(tipo){ return tipo === '2d' ? ctx2d : null; },
    getBoundingClientRect(){ return { width: 290, height: 290 }; },
    addEventListener(){}, removeEventListener(){}, cloneNode(){ return novoCanvas(); }
  };
}
const janela = {
  devicePixelRatio: 1.5,
  innerWidth: 390, innerHeight: 844,
  document: { hidden: false, addEventListener(){}, createElement(){ return novoCanvas(); } },
  addEventListener(){}, removeEventListener(){},
  matchMedia(){ return { matches: false }; },
  performance: { now: () => Date.now() },
  requestAnimationFrame(cb){ if (this._n === undefined) this._n = 0; if (this._n++ < 3) { cb(this._n * 16); } return this._n; },
  cancelAnimationFrame(){},
  setTimeout, clearTimeout, setInterval, clearInterval,
  console
};
janela.window = janela;
const ctxVm = vm.createContext(janela);
vm.runInContext(fonte, ctxVm);
const api = janela.NucleoOrbita;
if (!api) throw new Error('NucleoOrbita não foi publicado');
const canvas = novoCanvas();
api.iniciar(canvas);
if (api.tipo() !== 'canvas2d') throw new Error('esperava fallback 2D sem WebGL, veio ' + api.tipo());
if (!api.ativo()) throw new Error('a animação não iniciou no fallback');
api.nivel(0.8);
api.estado('speaking');
const d = api.diagnostico();
if (d.tipo !== 'canvas2d' || d.particulas < 100) throw new Error('diagnóstico inconsistente: ' + JSON.stringify(d));
if (!chamadas.includes('fill') && !chamadas.includes('fillRect')) throw new Error('nada foi desenhado');
api.parar();
if (api.ativo()) throw new Error('parar() não parou');
console.log('smoke 2D ok: ' + d.particulas + ' partículas, ' + chamadas.length + ' operações de desenho');
"""
import os
ambiente = dict(os.environ, ORBITA_PATH=str(ROOT / 'orbita.js'))
saida = subprocess.run(['node', '-e', smoke], capture_output=True, text=True, env=ambiente)
assert saida.returncode == 0, saida.stderr
assert 'smoke 2D ok' in saida.stdout, saida.stdout

# Sintaxe do arquivo real.
assert subprocess.run(['node', '--check', str(ROOT / 'orbita.js')], capture_output=True).returncode == 0

# ---------- 5. Auditoria do APK ----------
servico = texto('JarvisService.java')
assert 'private void subirPrimeiroPlano(Notification n)' in servico
assert 'Segunda tentativa, mínima' in servico
assert 'setSmallIcon(android.R.drawable.ic_btn_speak_now)' in servico
assert 'registrarFalhaPrimeiroPlano' in servico
assert servico.count('promoverPrimeiroPlano()') >= 2
assert 'catch (Throwable e) {\n            // Nada em onCreate pode escapar' in servico

musica = texto('JarvisMusicaService.java')
trecho = musica[musica.index('public void onDestroy()'):musica.index('public void onTaskRemoved')]
for campo in ('tocando = false;', 'tituloAtual = "";', 'artistaAtual = "";', 'indiceAtual = -1;', 'totalAtual = 0;'):
    assert campo in trecho, 'onDestroy do player não limpa ' + campo

# A pasta android/ é gerada pelo `npx cap add android` (o CI faz isso DEPOIS dos testes),
# então a fonte de verdade aqui são os patches; os arquivos gerados são conferidos quando
# existem na cópia local.
assert 'minSdkVersion 26' in texto('patch_gradle.py')
assert 'usesCleartextTraffic' in texto('patch_manifest.py')
assert 'allowBackup' in texto('patch_manifest.py')
vari = ROOT / 'android/variables.gradle'
if vari.exists():
    assert 'minSdkVersion = 26' in vari.read_text(encoding='utf-8')
    manifesto = texto('android/app/src/main/AndroidManifest.xml')
    assert 'android:usesCleartextTraffic="false"' in manifesto
    assert 'android:allowBackup="false"' in manifesto
    assert 'android:exported' in manifesto

# Nada de http:// no código do app (o bloqueio de cleartext não quebra nada).
for arquivo in ('app.js', 'hermes.js', 'index.html', 'orbita.js', 'cad.js', 'memoria.js', 'plataforma.js'):
    assert 'http://' not in texto(arquivo).replace('http://schemas.android.com', '').replace('http://www.w3.org', '').replace('http://schemas.openxmlformats.org', '').replace('http://schemas.microsoft.com', ''), arquivo

# ---------- 6. Versão, documentação, PC e workflows ----------
meta = json.loads(texto('VERSAO.json'))
pkg = json.loads(texto('package.json'))
assert [int(x) for x in meta['version'].split('.')] >= [1, 18, 0] and meta['versionCode'] >= 10180, meta
# A 1.18.x foi superada: o release corrente pode ser mais novo (checado pelo teste da versão dele).
assert pkg['version'] == meta['version']
assert ("const VERSAO_APP = '%s';" % meta['version']) in app
assert ('v%s' % meta['version']) in html
assert 'python3 tests/test_v1_18_0.py' in pkg['scripts']['test:all']
assert pkg['build']['linux']['target'][0] == 'AppImage' and pkg['build']['win']['target'] == 'nsis'
assert pkg['scripts']['dist:win'] == 'electron-builder --win'

lei = texto('LEIA-ME.md')
assert '# J.A.R.V.I.S. Nova' in lei
assert '## Instalar o J.A.R.V.I.S. no PC' in lei and 'npm start' in lei and 'npm run dist:win' in lei
assert '## 1.19.0' in texto('CHANGELOG.md') and '## 1.17.0' in texto('CHANGELOG.md')
assert texto('CHANGELOG.md').count('\n## ') >= 30

for wf in ('.github/workflows/build-apk.yml', '.github/workflows/release-apk.yml'):
    s = texto(wf)
    assert 'J.A.R.V.I.S. Nova' in s, wf
    assert 'cad.js www/' in s
assert 'Novidades da' in texto('.github/workflows/release-apk.yml')

print('1.18.0: núcleo 3D corrigido para celular/PC, fallback 2D desenhando e auditoria do APK validada')
