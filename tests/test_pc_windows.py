"""Camada Windows (PC): motores, ações IPC, painel, build e documentação.

Não testa interface em janela real — isso exigiria Electron com display. O que este
teste garante é o contrato entre as partes: os arquivos existem, as ações que a
interface chama estão na lista branca do processo principal, o painel está no HTML,
o build empacota os módulos e nada disso liga no Android.
"""
import json
import pathlib
import re
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent


def texto(nome):
    return (RAIZ / nome).read_text(encoding='utf-8')


main = texto('platforms/desktop/main.js')
arq = texto('platforms/desktop/arquivos.js')
cad = texto('platforms/desktop/cad_pc.js')
pc = texto('pc.js')
html = texto('index.html')
app = texto('app.js')
css = texto('style.css')
pkg = json.loads(texto('package.json'))
falhas = []


def checar(nome, ok):
    print(('OK: ' if ok else 'FALHA: ') + nome)
    if not ok:
        falhas.append(nome)


# ---------- 1. Arquivos e motores ----------
for f in ['platforms/desktop/arquivos.js', 'platforms/desktop/cad_pc.js', 'pc.js',
          'platforms/WINDOWS.md', 'tests/test_pc_arquivos.js', 'tests/test_pc_cad.js']:
    checar('Existe ' + f, (RAIZ / f).exists())
checar('main.js carrega os dois motores', "require('./arquivos.js')" in main and "require('./cad_pc.js')" in main)
checar('Motores não dependem de Electron (testáveis no Node)',
      'require(\'electron\')' not in arq and 'require(\'electron\')' not in cad)
checar('Detecção por assinatura, não por extensão',
      'detectar(buf, nome)' in arq and '0x89' in arq and 'AC10' in arq and 'ISO-10303-21' in arq)
checar('Gravação atômica com backup',
      "'.bak-'" in arq and 'renameSync(tmp, alvo)' in arq)
checar('Comparação, pesquisa e organização presentes',
      all(x in arq for x in ['function comparar(', 'function pesquisar(', 'function organizar(', 'function converter(']))
checar('Organização calcula plano antes de aplicar',
      'if (!aplicar) return aviso;' in arq and 'aplicado: false' in arq)
checar('Conversões limitadas ao que existe',
      'csv→json' in arq and 'json→csv' in arq and 'md→html' in arq)

# ---------- 2. CAD ----------
checar('CAD usa o mesmo núcleo do Android', "require('../../cad.js')" in cad)
checar('CAD identifica e recusa o que não lê',
      'não é legível aqui' in cad and 'DWG é binário proprietário' in cad and 'FCStd' in cad)
checar('CAD cria, versiona e exporta com validação',
      'function criar(' in cad and 'function modificar(' in cad and 'function exportar(' in cad)
checar('Versão nova nunca sobrescreve o original',
      'O original não foi alterado' in cad or 'original não foi alterado' in cad)
checar('Visualizador recebe geometria 2D e 3D',
      "tipo: '2d'" in cad and "tipo: '3d'" in cad and 'malhaParaVisual' in cad)

# ---------- 3. Lista branca do processo principal ----------
acoes = ['arq_listar', 'arq_ler', 'arq_salvar', 'arq_comparar', 'arq_pesquisar', 'arq_converter',
         'arq_organizar', 'arq_mover', 'arq_criar_pasta', 'arq_apagar', 'arq_abrir',
         'cad_identificar', 'cad_abrir', 'cad_criar', 'cad_modificar', 'cad_exportar', 'cad_formatos',
         'tarefas_executar', 'tarefas_cancelar', 'diag_pc']
for a in acoes:
    checar('Ação na lista branca: ' + a, re.search(r'(?m)^\s{2}' + a + r':', main) is not None)
checar('Tarefa só aceita ações permitidas', 'ACOES_DE_TAREFA' in main and "'arq_organizar'" in main)
checar('Nenhum shell livre vindo do renderer',
      'execSync' not in main and 'child_process.exec(' not in main and 'shell: true' not in main)
checar('IPC valida a ação e registra a falha',
      "Object.prototype.hasOwnProperty.call(acoes, nome)" in main and 'anotarFalha(nome, e)' in main)
checar('Diagnóstico do PC usa estados reais',
      all(x in main for x in ["'ok'", "'aviso'", "'nao_configurado'", "'nao_verificado'"]))
checar('Diagnóstico não expõe valor de chave', 'chaves.join' in main and 'decryptString' not in main.split('diag_pc')[1])

# ---------- 4. Interface ----------
checar('Painel e botão existem no HTML',
      'id="painel-pc"' in html and 'data-lat="pc"' in html and 'src="pc.js"' in html)
checar('Painel começa escondido (Android não vê)', re.search(r'id="painel-pc"[^>]*hidden', html) is not None)
checar('Botão da barra lateral começa escondido', re.search(r'data-lat="pc"[^>]*hidden', html) is not None)
checar('pc.js só age no Electron', 'window.jarvisNative' in pc and 'if (!nativo' in pc)
checar('pc.js expõe abrir/rotas para app.js', "window.PcPainel = {" in pc)
checar('Abas do painel ligadas', all(('data-pcx-aba="' + a + '"') in html for a in ['arquivos', 'cad', 'tarefas', 'diagnostico']))
checar('Canvas do visualizador CAD existe', 'id="pcx-canvas"' in html and 'pcx-canvas' in css)
checar('app.js lista o painel e tem a rota', "'#painel-pc'" in app and "alvo === 'pc'" in app)
checar('Sem ids duplicados no HTML', len(re.findall(r'id="([^"]+)"', html)) == len(set(re.findall(r'id="([^"]+)"', html))))
checar('CSS do painel usa os tokens do tema', '.pcx-abas' in css and 'body.pc .lat-btn[data-lat=pc]' in css)
checar('pc.js não injeta HTML de arquivo do usuário', 'innerHTML' not in pc)

# ---------- 5. Build e testes ----------
for f in ['pc.js', 'platforms/desktop/arquivos.js', 'platforms/desktop/cad_pc.js']:
    checar('Build empacota ' + f, f in pkg['build']['files'])
checar('Alvo Windows segue NSIS', pkg['build']['win']['target'] == 'nsis')
checar('Suíte roda estes testes',
      all(x in pkg['scripts']['test:all'] for x in ['tests/test_pc_arquivos.js', 'tests/test_pc_cad.js', 'tests/test_pc_windows.py']))

# ---------- 6. Documentação ----------
win = texto('platforms/WINDOWS.md')
checar('Documento explica arquitetura compartilhada', 'compartilh' in win.lower() and 'platforms/desktop' in win)
checar('Documento traz matriz de formatos', 'Matriz' in win and 'DWG' in win and 'FCStd' in win)
checar('Documento separa testado de não testado', 'não testado' in win.lower() or 'não foi testado' in win.lower())
checar('Documento de plataformas aponta para o PC', 'WINDOWS.md' in texto('platforms/LEIA-ME.md'))
checar('CHANGELOG registra a camada Windows', 'Windows' in texto('CHANGELOG.md'))

if falhas:
    print('\n%d verificação(ões) da camada Windows falharam.' % len(falhas))
    sys.exit(1)
print('Camada Windows: motores, lista branca, painel, build e documentação verificados.')
