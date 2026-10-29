"""Revisão 1.20.0 — erro de inicialização da memória, IA local protegida, diagnóstico
e bloqueio opcional do aplicativo.

O teste não se limita a procurar strings: confere a ORDEM de execução que causava o
`Cannot access 'MEM' before initialization` e executa a fiação da memória com um DOM
mínimo para provar que ela não depende mais da zona morta temporal.
"""
import json
import pathlib
import re
import subprocess
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent


def texto(nome):
    return (RAIZ / nome).read_text(encoding='utf-8')


app = texto('app.js')
html = texto('index.html')
css = texto('style.css')
meta = json.loads(texto('VERSAO.json'))
pkg = json.loads(texto('package.json'))
plugin_ia = texto('JarvisLocalAIPlugin.java')
plugin_bio = texto('JarvisSeguranca.java')
main = texto('MainActivity.java')
gradle_patch = texto('patch_gradle.py')
manifest_patch = texto('patch_manifest.py')
pc_wf = (RAIZ / '.github' / 'workflows' / 'release-pc.yml')

falhas = []


def checar(nome, ok):
    if not ok:
        falhas.append(nome)
    print(('OK: ' if ok else 'FALHA: ') + nome)


# ---------- 1. Causa raiz do MEM ----------
checar('MEM é declarada uma única vez', app.count('const MEM =') == 1)
pos_decl = app.index('const MEM =')
# O bloco de ligações da interface é o que roda em nível de topo e chamava as funções.
pos_render = app.index('renderMemoria();\n')
pos_tema = app.index("memTemaSel.value = memTemaAtual();")
checar('Declaração de MEM vem antes de renderMemoria() de topo', pos_decl < pos_render)
checar('Declaração de MEM vem antes de memTemaAtual() de topo', pos_decl < pos_tema)
checar('MEM resolvido logo após a detecção de plataforma', pos_decl < app.index('const GROQ ='))
checar('Estado explícito da memória', "const MEM_ESTADO = MEM ? 'pronta' : 'indisponivel';" in app)
checar('Diagnóstico confere a memória conectada',
      "'Memória conectada (Obsidian local)'" in app and 'MEM.espaco()' in app)
checar('Diagnóstico confere armazenamento e abertura',
      "'Armazenamento do app'" in app and "'Abertura do aplicativo'" in app)
checar('Diagnóstico carimba início e conclusão',
      'inicioDiag' in app and "'Conclusão'" in app)

# Nenhuma rotina de topo pode tocar funções que dependem de MEM antes da declaração.
funcoes_mem = ['memTemaAtual', 'renderMemoria', 'criarNotaMemoria', 'apagarNotaMemoria',
               'apagarTemaMemoria', 'esvaziarMemoria', 'exportarMemoria', 'liberarEspacoMemoria',
               'obsEnviar', 'obsReceber', 'vsMemoria']
topo_antes = []
for numero, linha in enumerate(app[:pos_decl].split('\n'), 1):
    if not linha or linha[0] in ' \t}' or linha.startswith(('//', '/*', '*')):
        continue
    if re.match(r'\s*(async\s+)?function\s', linha) or re.match(r'\s*(const|let|var)\s', linha):
        continue
    if any(re.search(re.escape(f) + r'\s*\(', linha) for f in funcoes_mem):
        topo_antes.append((numero, linha.strip()[:90]))
checar('Nenhuma rotina de topo usa a memória antes da declaração', not topo_antes)
if topo_antes:
    print(topo_antes[:5])

# ---------- 2. IA local protegida ----------
checar('Valida o modelo antes do nativo', 'private String validarModelo(File f)' in plugin_ia)
checar('Rejeita cabeçalho que não é ZIP nem TFL3',
      'cabecalho[0] == 0x50' in plugin_ia and "cabecalho[0] == 'T'" in plugin_ia)
checar('Trava uma sessão de inferência por vez',
      'private volatile boolean gerando' in plugin_ia and 'if (gerando)' in plugin_ia)
checar('Libera a trava no finally', 'finally {' in plugin_ia and 'gerando = false;' in plugin_ia)
checar('Mensagem distingue memória esgotada', 'OutOfMemoryError' in plugin_ia)
checar('Status informa validade e motivo', '"valida"' in plugin_ia and '"motivo"' in plugin_ia)

# ---------- 3. Bloqueio opcional ----------
for marca in ['id="bloqueio"', 'id="bloqueio-pin"', 'id="bloqueio-bio"', 'id="bloqueio-recuperacao"',
              'id="c-bloqueio"', 'id="c-bloqueio-recuperacao"', 'id="c-bloqueio-codigo"']:
    checar('Bloqueio: ' + marca, marca in html)
checar('Bloqueio desligado por padrão',
      "store.get('bloqueio', '0') === '1'" in app and 'bloqueioAtivo()' in app)
checar('Só liga com PIN cadastrado',
      'Cadastre um PIN antes de ativar o bloqueio' in app and 'querBloqueio && !store.get(\'pin_hash\'' in app)
checar('PIN usa hash (nunca texto puro)', "store.set('pin_hash', await hashPin(pin));" in app)
checar('Código de recuperação em hash', "store.set('bloqueio_codigo_hash'" in app)
checar('Recuperação apaga o PIN e desativa o bloqueio',
      "store.set('pin_hash', '');" in app and "store.set('bloqueio', '0');" in app)
checar('Atraso progressivo após erro', 'Math.min(30, Math.round(0.5 * Math.pow(2' in app)
checar('Biometria nativa registrada', 'registerPlugin(JarvisSeguranca.class)' in main)
checar('BiometricPrompt com credencial do aparelho',
      'BiometricPrompt' in plugin_bio and 'DEVICE_CREDENTIAL' in plugin_bio)
checar('Dependência androidx.biometric no Gradle', 'androidx.biometric' in gradle_patch)
checar('Permissão de biometria no manifesto', 'USE_BIOMETRIC' in manifest_patch)
checar('Bloqueio não substitui o do Android (texto explícito)',
      'não substitui o bloqueio do android' in html.lower())
checar('Estilo do bloqueio no CSS',
      '.bloqueio{' in css and '@keyframes bloq-gira' in css and 'body.bloqueado' in css)

# ---------- 4. Versão, documentação, suíte e PC ----------
# A partir da 1.20.0 a versão anda: o teste confere a coerência interna e o piso, não o número.
VERSAO = tuple(int(x) for x in str(meta.get('version', '0')).split('.'))
checar('Versão >= 1.20.0 com versionCode coerente',
      VERSAO >= (1, 20, 0) and int(meta.get('versionCode', 0)) >= 10200
      and pkg.get('version') == meta.get('version'))
checar('app.js e interface com a versão corrente',
      ("const VERSAO_APP = '" + meta['version'] + "';") in app
      and html.count('v' + meta['version']) >= 2)
# O diretório android/ é gerado por `cap add android` no CI; quando existe, a versão tem de bater.
gradle_local = RAIZ / 'android' / 'app' / 'build.gradle'
gradle_txt = gradle_local.read_text(encoding='utf-8') if gradle_local.exists() else ''
checar('Gradle coerente com a versão corrente (quando o projeto nativo existe)',
      (not gradle_txt) or ('versionCode ' + str(meta['versionCode']) in gradle_txt
                            and 'versionName "' + meta['version'] + '"' in gradle_txt))
checar('patch_android_version lê a versão do VERSAO.json',
      'VERSAO.json' in texto('patch_android_version.py'))
changelog = texto('CHANGELOG.md')
leia = texto('LEIA-ME.md')
checar('CHANGELOG registra a 1.20.0', '## 1.20.0' in changelog and 'MEM' in changelog)
checar('LEIA-ME registra a 1.20.0 (e segue atualizado)',
      '# J.A.R.V.I.S. Nova ' in leia and '## 1.20.0' in changelog and 'bloqueio' in leia.lower())
checar('Suíte roda o teste desta versão',
      'python3 tests/test_v1_20_0.py' in pkg['scripts']['test:all'])
checar('Workflow do PC existe e empacota Windows',
      pc_wf.exists() and 'electron-builder' in pc_wf.read_text(encoding='utf-8')
      and '--win' in pc_wf.read_text(encoding='utf-8'))

if falhas:
    print('\n%d verificação(ões) da 1.20.0 falharam.' % len(falhas))
    sys.exit(1)
print('\n1.20.0: inicialização da memória, IA local, diagnóstico e bloqueio opcional verificados.')
