"""Revisão 1.21.5 — cofre do Obsidian num só lugar, diagnóstico por área, animação unificada e modelos .task."""
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
falhas = []


def checar(nome, ok):
    print(('OK: ' if ok else 'FALHA: ') + nome)
    if not ok:
        falhas.append(nome)


# ---------- 1. Cofre: uma única seção, dentro de Ajustes ▸ Memória ----------
config = html[html.index('id="painel-config"'):html.index('id="painel-tarefas"')]
secoes = re.findall(r'<section class="grupo"([^>]*)>', config)
checar('Nenhuma seção de Ajustes sem categoria (era o bug do cofre invisível)',
      all('data-category' in attrs for attrs in secoes))
memoria = config[config.index('data-category="memoria"'):config.index('data-category="rotinas"')]
checar('Bloco do cofre vive dentro da seção Memória', 'id="obs-bloco"' in memoria)
checar('Existe um único bloco de cofre no HTML', html.count('id="obs-bloco"') == 1)
checar('Cofre depois da memória pessoal', memoria.index('id="c-memoria"') < memoria.index('id="obs-bloco"'))
checar('Um único ponto de seleção: sem campo de caminho duplicado',
      'obs-caminho' not in html and 'obs-caminho' not in app)
checar('Seleção da pasta continua existindo', 'id="obs-escolher"' in memoria and 'Escolher pasta do cofre' in memoria)
for marca in ['id="obs-ativo"', 'id="obs-testar"', 'id="obs-enviar"', 'id="obs-receber"', 'id="obs-organizar"',
              'id="obs-desconectar"', 'id="obs-baixar"', 'id="obs-importar"', 'id="obs-topicos"', 'id="obs-diag"']:
    checar('Controle do cofre presente: ' + marca, marca in memoria)
checar('Selo de estado do vínculo', 'id="obs-pill"' in memoria and "const pill = $('#obs-pill')" in app)
checar('Caminho vem do armazenamento, não de um input',
      "function obsCaminho() { return String(store.get('obs_caminho', '') || '').trim(); }" in app)
checar('Sem IDs duplicados no HTML',
      len(re.findall(r'id="([^"]+)"', html)) == len(set(re.findall(r'id="([^"]+)"', html))))

# ---------- 2. Diagnóstico agrupado por área ----------
for marca in ['DIAG_CATS', 'function diagCategoriaDe', 'function diagGrupoLista', 'function diagFecharGrupos',
              'diagFecharGrupos();', 'DIAG_PESO']:
    checar('Diagnóstico: ' + marca, marca in app)
for area in ['Aplicativo e pacote', 'Inteligência artificial', 'Voz e áudio', 'Memória e dados',
             'Permissões e sistema', 'Rede e conectividade']:
    checar('Área do diagnóstico: ' + area, area in app)
checar('Atalho para o registro de erros', 'id="diag-abrir-log"' in html and "abrirPainel('#painel-log')" in app)
checar('Detalhes técnicos recolhíveis', "className = 'diag-tec'" in app and 'diag-tec' in css)
checar('Sete estados preservados', all(x in app for x in ['Operacional', 'Não configurado', 'Desativado', 'Não verificado']))
r = subprocess.run(['node', 'tests/test_diag_grupos.js'], cwd=RAIZ, capture_output=True, text=True)
checar('Comportamento: linhas no grupo certo, contagem e ordem', r.returncode == 0)
if r.returncode != 0:
    print(r.stdout + r.stderr)

# ---------- 3. Sistema de animação unificado ----------
for marca in ['--jv-dur-1', '--jv-dur-2', '--jv-dur-3', '--jv-ease', '@keyframes jv-surge', '@keyframes jv-surge-x',
              '@keyframes jv-painel', '.painel:not([hidden]){animation:jv-painel', '.diag-row,.mem-item']:
    checar('Animação unificada: ' + marca, marca in css)
checar('Entrada em cascata nas seções', '.grupo:not([hidden]) > *:nth-child(n+7)' in css)
checar('Redução de movimento desliga animações e transições',
      'prefers-reduced-motion:reduce' in css and 'animation:none!important' in css and 'transition:none!important' in css)
checar('Animações presas ao estado real', 'body[data-state="thinking"] .hud{animation:jv-nucleo-pulso' in css
      and 'body[data-state="listening"] .ondas-voz' in css)
checar('Superfícies e diagnóstico com estilo próprio', '.obs-estado' in css and '.diag-grupo-cab' in css
      and '.modelos-lista' in css)

# ---------- 4. Modelos .task: links verificados e documentados ----------
urls = ['https://huggingface.co/litert-community/Gemma3-1B-IT', 'https://huggingface.co/litert-community',
        'https://ai.google.dev/edge/mediapipe/solutions/genai/llm_inference', 'https://www.kaggle.com/models/google/gemma-3']
for u in urls:
    checar('Link de modelo na interface: ' + u, u in html)
checar('Bloco de modelos na aba IA', 'class="modelos-card"' in html)
doc = texto('MODELOS-IA-LOCAL.md')
for u in urls:
    checar('Link no documento de modelos: ' + u, u in doc)
checar('Nomes de arquivo conferidos no documento',
      'Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task' in doc and 'Gemma3-1B-IT_multi-prefill-seq_q8_ekv2048.task' in doc)
checar('Documento explica que .task é binário e GGUF não serve',
      'GGUF' in doc and 'Task Bundle' in doc and 'não' in doc)
# A pasta android/ é gerada pelo `npx cap add android` DEPOIS dos testes no CI,
# então a fonte de verdade é o patch que o workflow aplica nela.
_gradle = RAIZ / 'android/app/build.gradle'
if _gradle.exists():
    _fonte_mediapipe = _gradle.read_text(encoding='utf-8')
else:
    _fonte_mediapipe = texto('patch_gradle.py')
checar('Documento aponta a API realmente usada',
      'tasks-genai' in _fonte_mediapipe and 'MediaPipe' in doc)
checar('Nenhum link fora das fontes oficiais nos modelos',
      all(h in ('huggingface.co', 'ai.google.dev', 'www.kaggle.com')
          for h in re.findall(r'https://([^/\s)]+)', doc)))
checar('Interface remete ao documento', 'MODELOS-IA-LOCAL.md' in html)

# ---------- 5. Versão e entrega ----------
checar('Versão e versionCode coerentes com o VERSAO.json',
      meta['versionCode'] >= 10215 and pkg['version'] == meta['version'] and meta['versionCode'] % 1 == 0)
checar('app.js e interface na versão',
      ("const VERSAO_APP = '%s';" % meta['version']) in app and ('v' + meta['version']) in html)
checar('CHANGELOG e LEIA-ME na versão',
      ('## ' + meta['version']) in texto('CHANGELOG.md') and
      ('# J.A.R.V.I.S. Nova ' + meta['version']) in texto('LEIA-ME.md'))
checar('Suíte roda este teste', 'python3 tests/test_v1_21_5.py' in pkg['scripts']['test:all'])
checar('Suíte roda o teste de comportamento do diagnóstico', 'node tests/test_diag_grupos.js' in pkg['scripts']['test:all'])
checar('Workflows na versão',
      meta['version'] in texto('.github/workflows/build-apk.yml') and
      meta['version'] in texto('.github/workflows/release-apk.yml'))
checar('Funções antigas preservadas', all(x in app for x in ['function obsEscolher', 'async function obsTestar',
                                                             'async function obsEnviar', 'async function obsReceber',
                                                             'function executarDiagnostico', 'function tentarDesbloquear',
                                                             'function atualizarObsUI']))
checar('Tela de bloqueio intocada nesta revisão', 'BLOQ_ATE' in app and 'pin_hash' in app)

if falhas:
    print('\n%d verificação(ões) da 1.21.5 falharam.' % len(falhas))
    sys.exit(1)
print('1.21.5: cofre em um só lugar, diagnóstico por área, animação unificada e modelos .task verificados.')
