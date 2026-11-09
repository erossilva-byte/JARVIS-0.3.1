"""Contrato 1.40.0 — núcleo protagonista, áreas clicáveis e abertura sem piscadas."""
import json
import pathlib
import re
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
app = (RAIZ / 'app.js').read_text(encoding='utf-8')
html = (RAIZ / 'index.html').read_text(encoding='utf-8')
css = (RAIZ / 'interface.css').read_text(encoding='utf-8')
style = (RAIZ / 'style.css').read_text(encoding='utf-8')
ui = (RAIZ / 'interface.js').read_text(encoding='utf-8')
pkg = json.loads((RAIZ / 'package.json').read_text(encoding='utf-8'))
lock = json.loads((RAIZ / 'package-lock.json').read_text(encoding='utf-8'))
meta = json.loads((RAIZ / 'VERSAO.json').read_text(encoding='utf-8'))
gradle_path = RAIZ / 'android/app/build.gradle'
gradle = gradle_path.read_text(encoding='utf-8') if gradle_path.exists() else ''
patch_android = (RAIZ / 'patch_android_version.py').read_text(encoding='utf-8')
suite = pkg.get('scripts', {}).get('test:all', '')
falhas = []


def check(nome, ok):
    print(('OK: ' if ok else 'FALHA: ') + nome)
    if not ok:
        falhas.append(nome)


check('versão 1.40.0 ou posterior e versionCode >= 10400',
      [int(x) for x in meta.get('version', '0').split('.')] >= [1, 40, 0]
      and meta.get('versionCode', 0) >= 10400)
check('package e lock acompanham a versão',
      pkg.get('version') == meta.get('version')
      and lock.get('version') == meta.get('version')
      and lock.get('packages', {}).get('', {}).get('version') == meta.get('version'))
check('patch Gradle aplica a versão e build gerado acompanha quando existe',
      'versionCode' in patch_android and 'versionName' in patch_android
      and "meta.get('versionCode')" in patch_android
      and (not gradle or (('versionCode %s' % meta.get('versionCode')) in gradle
      and ('versionName \"%s\"' % meta.get('version')) in gradle)))
check('app e HTML mostram a versão corrente',
      ("const VERSAO_APP = '%s';" % meta.get('version')) in app
      and ('v%s' % meta.get('version')) in html)
      ("const VERSAO_APP = '%s';" % meta.get('version')) in app
      and ('v%s' % meta.get('version')) in html)

# Núcleo protagonista e Conversa fora do menu, sem apagar o sistema de conversa.
check('núcleo e resposta central no menu',
      'id="hud"' in html and 'id="resposta-atual"' in html
      and 'id="resposta-atual-texto"' in html and 'ÚLTIMA RESPOSTA' in html)
check('opção independente Conversa removida do menu',
      'id="btn-conversa"' not in html and 'id="dash-conversa"' not in html
      and 'id="dash-ultima"' not in html)
check('transcrição secundária preservada',
      'id="btn-transcricao"' in html and 'id="btn-transcricao-voltar"' in html
      and 'data-abrir-transcricao' in html and 'id="chat-area"' in html)
check('comando não troca de tela nem abre o chat',
      'function enviarComando' in app
      and 'entrarConversa();' not in app.split('function enviarComando', 1)[1].split('function enviarTexto', 1)[0]
      and 'atualizarRespostaCentral' in app)
check('voz e ciclo não abrem o chat automaticamente',
      'entrarConversa();' not in app.split('function ciclo() {', 1)[1].split('function enviarComando', 1)[0]
      and 'entrarConversa();' not in app.split('async function aoAcordar', 1)[1].split('/* ---------- Controle', 1)[0])
check('estados reais do núcleo continuam ligados',
      all(x in app + css for x in ('data-state', 'listening', 'thinking', 'speaking', 'processing')))
check('resposta central acompanha o estado e a fala',
      "resposta.dataset.estado = e" in app and 'atualizarRespostaCentral(texto);' in app
      and 'atualizarRespostaCentral(\'Processando o comando…\', \'processando\');' in app)

# Abertura: boot visível desde o primeiro quadro e bloqueio antes do menu.
boot_html = html.split('<div id="boot"', 1)[1].split('</div>\n<header>', 1)[0]
check('boot nasce visível e o corpo começa travado',
      '<body data-state="idle" class="travado">' in html
      and '<div id="boot" class="boot"' in html and 'id="boot" class="boot" hidden' not in html)
check('boot tem identidade própria e não é tela preta',
      all(x in boot_html for x in ('boot-nucleo', 'bn-orbita', 'boot-barra', 'boot-status', 'boot-telemetria')))
boot_z = re.search(r'\.boot\s*\{[^}]*z-index:(\d+)', css, re.S)
lock_z = re.search(r'\.bloqueio\s*\{[^}]*z-index:(\d+)', style, re.S)
check('boot fica acima do bloqueio',
      bool(boot_z and lock_z) and int(boot_z.group(1)) > int(lock_z.group(1)))
liberar = app.split('function liberarApp()', 1)[1].split('async function finalizarBoot', 1)[0]
check('bloqueio é aberto antes de liberar o corpo',
      liberar.index('abrirBloqueio()') < liberar.index("document.body.classList.remove('travado')")
      and "if (!document.body.classList.contains('bloqueado')) document.body.classList.remove('travado');" in liberar)
check('desbloqueio destrava o corpo',
      app.split('function fecharBloqueio()', 1)[1].split('async function tentarDesbloquear', 1)[0]
      .count("document.body.classList.remove('travado')") == 1)
check('boot começa no primeiro ciclo, sem atraso de menu',
      re.search(r'setTimeout\(\(\) => \{.*?iniciarSequenciaBoot\(\);.*?\}, 0\);', app, re.S) is not None)
check('boot não depende de espera de 700 ms nem de 520 ms',
      '700' not in app.split('iniciarSequenciaBoot', 1)[1][:600]
      and '520' not in app.split('iniciarSequenciaBoot', 1)[1][:600])

# Áreas: causa raiz do clique perdido e cobertura de todas as ações.
areas_bloco = ui.split('var AREAS = [', 1)[1].split('  var modoAtual', 1)[0]
check('as dez áreas continuam definidas', len(re.findall(r"\n      id: '", areas_bloco)) == 10)
check('as ações reais das áreas continuam definidas', areas_bloco.count('{ rot:') == 44)
acoes_areas = set(re.findall(r"\{ rot: '[^']+', acao: '([^']+)'", areas_bloco))
rotas_app = set(re.findall(r"case '([^']+)'", app.split('function acaoNavegacao(nome)', 1)[1].split('\n}', 1)[0]))
check('toda ação de área tem rota real no app', bool(acoes_areas) and not (acoes_areas - rotas_app))
check('body não é confundido com botão de modo',
      "closest('[data-modo]')" not in ui and "closest('.modo-btn[data-modo]')" in ui
      and "querySelectorAll('.modo-btn[data-modo]')" in ui)
check('cartão abre por listener direto e por delegação',
      "b.addEventListener('click'" in ui and "data-area-abrir" in ui
      and "alvo.closest('[data-area-abrir]')" in ui)
check('clique em nó de texto da WebView sobe para o elemento',
      'alvo.nodeType !== 1' in ui and 'alvo.parentElement' in ui)
check('ação interna tem prioridade sobre abrir a área',
      ui.index("alvo.closest('[data-area-acao]')") < ui.index("alvo.closest('[data-area-abrir]')"))
check('retorno limpa o detalhe e volta ao mapa',
      "abrirArea('')" in ui and "detalhe.textContent = ''" in ui and 'painel.scrollTop = 0' in ui)
check('init é idempotente', "data-jarvis-ui" in ui and '=== \'1\') return' in ui)
check('teste de DOM entra na suíte',
      'node tests/test_interface_dom.js' in suite and 'python3 tests/test_v1_40_0.py' in suite)
check('jsdom é dependência de desenvolvimento',
      'jsdom' in pkg.get('devDependencies', {}) and (RAIZ / 'tests/test_interface_dom.js').exists())

# Preservação de configurações e recursos anteriores.
check('Obsidian, bloqueio, provedores, humor, voz e pessoas preservados',
      all(('id="%s"' % x) in html for x in (
          'obs-ativo', 'obs-escolher', 'obs-testar', 'c-bloqueio', 'c-bloqueio-biometria',
          'c-humor', 'c-humor-nivel', 'c-voz-perfil', 'c-voz-consentimento',
          'c-voz-cadastrar', 'idp-cfg-pessoas', 'painel-pessoas')))
check('núcleo, agentes, memória, executores e confirmações preservados',
      all(x in (RAIZ / f).read_text(encoding='utf-8') for f, x in (
          ('hermes.js', 'Hermes'), ('core.js', 'criarCore'), ('memoria.js', 'MemoriaJarvis'),
          ('app.js', 'async function executarSeguro'), ('agentes.js', 'Agentes'))))
check('redução de movimento e responsividade continuam',
      '@media(prefers-reduced-motion:reduce)' in css
      and '@media(max-width:600px)' in css and 'body.efeitos-reduzidos::before' in css)
check('documentação da 1.40 existe', (RAIZ / 'docs/INTERFACE-1.40.0.md').exists())
check('notas descrevem núcleo, áreas e abertura',
      all(x in meta.get('notas', '').lower() for x in ('núcleo', 'áreas', 'flash')))

if falhas:
    print('\n%d falha(s) no contrato 1.40.0: %s' % (len(falhas), ', '.join(falhas)))
    sys.exit(1)
print('\n1.40.0: interface, áreas, abertura e preservação aprovadas.')
