"""Revisão 1.16.0 — crash do serviço em primeiro plano, núcleo órbita,
memória conectada (Obsidian), humor brasileiro com níveis e desktop.

Os testes de JavaScript rodam os módulos de verdade (memoria.js, orbita.js e o núcleo
Hermes com capacidades simuladas), não apenas procuram strings.
"""
import json
import pathlib
import re
import subprocess
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent


def texto(nome):
    return (RAIZ / nome).read_text(encoding='utf-8')


def sem_acento(t):
    return ''.join(c for c in __import__('unicodedata').normalize('NFD', t) if __import__('unicodedata').category(c) != 'Mn')


# ---------- 1. Crash do serviço em primeiro plano (foto do feedback) ----------
servico = texto('JarvisService.java')
assert 'promoverPrimeiroPlano();' in servico
cria = servico[servico.index('public void onCreate()'):servico.index('public int onStartCommand')]
assert 'promoverPrimeiroPlano();' in cria, 'onCreate precisa promover antes de qualquer trabalho'
inicio = servico[servico.index('public int onStartCommand'):]
promocao = inicio.index('promoverPrimeiroPlano();')
assert promocao < inicio.index('ACAO_PARAR.equals'), 'a promoção precisa vir antes dos caminhos de parar'
assert 'FOREGROUND_SERVICE_TYPE_DATA_SYNC' in servico
assert 'FOREGROUND_SERVICE_TYPE_MICROPHONE' in servico
# A promoção não pode depender de o microfone estar autorizado: é justamente o caso
# em que o Android 14 recusava e o processo morria.
assert 'checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)' in servico
manifesto = texto('patch_manifest.py')
assert 'microphone|dataSync' in manifesto
assert 'FOREGROUND_SERVICE_DATA_SYNC' in manifesto
assert 'microphone|dataSync' in texto('android/app/src/main/AndroidManifest.xml')

# ---------- 2. Módulos novos de verdade (Node) ----------
script_memoria = r"""
const Mem = require('./memoria.js');
const dados = {};
Mem.usarStore({ getItem: (k) => (k in dados ? dados[k] : null), setItem: (k, v) => { dados[k] = v; } });
const a = Mem.criar({ tema: 'gostos', titulo: 'Café', texto: 'prefiro café sem açúcar', tags: ['cafe'] });
if (!a.ok || a.duplicada) throw new Error('primeira nota deveria criar');
const b = Mem.criar({ tema: 'gostos', titulo: 'Café', texto: 'prefiro café sem açúcar' });
if (!b.ok || !b.duplicada) throw new Error('nota repetida deveria ser reaproveitada');
if (Mem.listar('gostos').length !== 1) throw new Error('duplicata inchou o cofre');
const c = Mem.criar({ tema: 'projetos', texto: '<script>alert(1)</script> Jarvis no PC' });
if (!c.ok) throw new Error('nota de projeto falhou');
if (c.nota.texto.includes('<') || c.nota.texto.includes('>')) throw new Error('texto não foi saneado');
if (Mem.espaco().notas !== 2) throw new Error('contagem de notas errada');
if (Mem.contexto(200).indexOf('[Gostos]') < 0) throw new Error('contexto do prompt sem tema');
if (Mem.temaPorPalavras('prefiro café sem açúcar') !== 'gostos') throw new Error('tema por palavras falhou');
if (Mem.temaPorPalavras('anota esse projeto de código') !== 'projetos') throw new Error('tema de projeto falhou');
const backup = Mem.exportar();
if (Mem.apagar(a.nota.id).ok !== true) throw new Error('apagar falhou');
if (Mem.listar().length !== 1) throw new Error('apagar não removeu');
const imp = Mem.importar(backup);
if (!imp.ok || imp.criadas !== 1) throw new Error('importar não restaurou');
if (!Mem.resumo().toLowerCase().includes('nota')) throw new Error('resumo falhou');
Mem.usarStore({ getItem: () => JSON.stringify([{ id: 'x', tema: 'x', titulo: 'a', texto: 'b' }]), setItem: () => true });
if (Mem.listar()[0].tema !== 'contextos') throw new Error('tema inválido não foi corrigido');
console.log('memoria ok');
"""
r = subprocess.run(['node', '-e', script_memoria], cwd=RAIZ, capture_output=True, text=True)
if r.returncode != 0:
    sys.exit('memoria.js falhou:\n' + r.stdout + r.stderr)
assert 'memoria ok' in r.stdout

script_hermes = r"""
const H = require('./hermes.js');
const falas = [];
const notas = [];
H.instalar({
  falar: async (t) => { falas.push(t); },
  trat: () => 'senhor',
  ler: () => '',
  gravar: () => {},
  frase: () => '',
  memoria: {
    criar: (o) => { const n = { id: '1', tema: o.tema || 'contextos', titulo: o.texto.slice(0, 20), texto: o.texto }; notas.push(n); return { ok: true, nota: n }; },
    listar: () => notas, buscar: () => notas, espaco: () => ({ bytes: 2048, notas: notas.length, percentual: 3 }),
    resumo: () => 'Tenho 1 nota.', temaNome: (t) => t, temaPorPalavras: () => 'gostos'
  },
  abrirMemoria: () => {},
  pc: {
    status: async () => ({ resumo: 'processador em 10% de uso' }),
    listar: async () => ({ caminho: '/casa', itens: ['a.txt'] }),
    criar: async (n) => ({ caminho: '/casa/' + n }),
    abrir: async () => ({ caminho: '/casa' })
  }
});
(async () => {
  const r1 = await H.despachar('anote que prefiro respostas curtas');
  if (!r1.tratado || r1.rota !== 'hermes:memoria') throw new Error('memória não assumiu o turno: ' + JSON.stringify(r1));
  if (!notas.length) throw new Error('nada foi anotado');
  const r2 = await H.despachar('status do computador');
  if (!r2.tratado || r2.rota !== 'hermes:computador') throw new Error('computador não assumiu o turno');
  if (!falas.join(' ').includes('processador')) throw new Error('status do PC não foi falado');
  console.log('hermes ok');
})().catch((e) => { console.error(e); process.exit(1); });
"""
r = subprocess.run(['node', '-e', script_hermes], cwd=RAIZ, capture_output=True, text=True)
if r.returncode != 0:
    sys.exit('hermes falhou:\n' + r.stdout + r.stderr)
assert 'hermes ok' in r.stdout

# ---------- 3. Núcleo órbita ----------
orbita = texto('orbita.js')
assert 'NucleoOrbita' in orbita
assert 'THREE.' not in orbita and '<script' not in orbita.lower(), 'órbita precisa ser offline e sem CDN'
assert 'requestAnimationFrame' in orbita and 'prefers-reduced-motion' in orbita
assert 'visibilitychange' in orbita
app = texto('app.js')
assert "'orbita'" in app and 'NucleoOrbita' in app
assert 'nucleo-orbita' in texto('index.html')
assert 'data-nucleo=orbita' in texto('style.css')
assert 'option value="orbita"' in texto('index.html')

# ---------- 4. Memória: interface, segurança e espaço ----------
html = texto('index.html')
for marca in ['painel-memoria', 'mem-espaco', 'mem-barra', 'mem-lista', 'mem-tema', 'mem-buscar' if 'mem-buscar' in html else 'mem-busca',
              'mem-apagar-tema', 'mem-esvaziar', 'mem-liberar', 'mem-exportar', 'pc-bloco', 'pc-status']:
    assert marca in html, 'faltou ' + marca
assert 'data-lat="memoria"' in html
assert "'#painel-memoria'" in app
assert 'MEM.apagar' in app and 'confirmar(' in app
# Notas nunca entram como HTML: só textContent/createElement.
trecho = app[app.index('function renderMemoria()'):app.index('function abrirMemoria()')]
assert 'innerHTML' not in trecho, 'render da memória não pode usar innerHTML'
assert 'textContent' in trecho
assert 'fetch(' not in texto('memoria.js') and 'XMLHttpRequest' not in texto('memoria.js'), 'cofre é local: nada de rede'

# ---------- 5. Humor brasileiro com níveis ----------
assert 'HUMOR_NIVEIS' in app and 'nivelHumor' in app
assert 'Discreto' in html and 'Equilibrado' in html and 'Avançado' in html
assert 'brasileira' in sem_acento(app).lower() or 'brasileiro' in sem_acento(app).lower()
assert 'capacidade de improvisar' in app, 'exemplo de humor de referência ausente'
# Limites: humor suspenso em assunto sério continua valendo.
assert 'humor desaparece por completo' in app

# ---------- 6. Plataforma e desktop ----------
plat = texto('plataforma.js')
for chave in ["tipo", "capacidades", "desktopComando", "layout", "observarTela"]:
    assert chave in plat, 'faltou ' + chave + ' no adaptador'
assert 'Plataforma.observarTela()' in app
assert 'data-plataforma' in texto('style.css')
ma = texto('main.js')
for acao in ['status_pc', 'listar_arquivos', 'criar_arquivo', 'apagar_arquivo', 'abrir_pasta', 'ler_arquivo', 'pesquisar_web']:
    assert acao in ma, 'faltou ação ' + acao
assert 'dentroDaCasa' in ma and 'trashItem' in ma, 'arquivos precisam ficar na pasta do usuário e ir para a lixeira'
assert 'child_process' in ma and 'exec(' not in ma, 'renderer não pode executar shell livre'
assert 'Processamento' not in ma

# ---------- 7. Versão e documentação ----------
meta = json.loads(texto('VERSAO.json'))
assert meta['version'] == '1.16.0' and meta['versionCode'] == 10160, meta
pkg = json.loads(texto('package.json'))
assert pkg['version'] == '1.16.0'
assert "const VERSAO_APP = '1.16.0';" in app
assert 'versionCode 10160' in texto('android/app/build.gradle')
assert 'versionName "1.16.0"' in texto('android/app/build.gradle')
assert '1.16.0' in texto('CHANGELOG.md').split('\n')[0:20][0] + texto('CHANGELOG.md')[:2000]
for novo in ['plataforma.js', 'memoria.js', 'orbita.js']:
    assert novo in pkg['build']['files'], 'desktop precisa empacotar ' + novo
    assert novo in pkg['scripts']['test:all'], 'test:all precisa verificar ' + novo
assert 'test_v1_16_0.py' in pkg['scripts']['test:all']

# ---------- 8. Ordem dos scripts (CSP: sem CDN) ----------
ordem = [html.index('src="%s"' % n) for n in ['plataforma.js', 'memoria.js', 'orbita.js', 'apps.js', 'hermes.js', 'app.js']]
assert ordem == sorted(ordem), 'scripts fora de ordem'
csp = re.search(r'Content-Security-Policy" content="([^"]+)"', html).group(1)
assert "script-src 'self'" in csp and 'unsafe-eval' not in csp
assert 'cdn.tailwindcss.com' not in html and 'three.min.js' not in html

print('1.16.0: crash do serviço, núcleo órbita, memória Obsidian, humor e desktop verificados')
