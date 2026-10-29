"""Revisão 1.21.3 — tela de bloqueio holográfica e diagnóstico com estados reais."""
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


# ---------- 1. Tela de bloqueio: visual ----------
for marca in ['id="bloq-hora"', 'id="bloq-data"', 'id="bloq-estado"', 'id="bloqueio-pontos"',
              'class="bloq-arcos"', 'class="bloq-varredura"', 'class="bloq-grade"', 'class="bloq-rodape"']:
    checar('Bloqueio: ' + marca, marca in html)
checar('Bloqueio: quatro arcos no núcleo', html.count('class="ba ba') == 4)
checar('Bloqueio: container rola em tela baixa',
      '.bloqueio-caixa{position:relative' in css and 'max-height:calc(100dvh' in css and 'overflow-y:auto' in css)
checar('Bloqueio: animação de erro e de saída',
      '@keyframes bloq-tremer' in css and '.bloqueio.saindo' in css and '@keyframes bloq-sai' in css)
checar('Bloqueio: respeita prefers-reduced-motion', 'prefers-reduced-motion' in css and '.bloq-arcos .ba,.bloq-varredura' in css)
checar('Bloqueio: layout adapta telas estreitas', '@media(max-width:430px)' in css and '.bloq-cabeca{flex-direction:column' in css)

# ---------- 2. Tela de bloqueio: função e segurança ----------
checar('PIN validado por hash (sem texto simples)',
      "store.get('pin_hash'" in app and 'await hashPin(pin)' in app and "store.set('pin_hash', pin)" not in app)
checar('PIN errado mostra erro e atrasa a próxima tentativa',
      'PIN incorreto.' in app and 'Math.min(30, Math.round(0.5 * Math.pow(2' in app)
checar('Biometria usa o plugin oficial do aparelho',
      "plug('JarvisSeguranca')" in app and 'p.autenticar(' in app)
checar('Recuperação por código preservada', 'recuperarComCodigo' in app and "hashPin('rec|'" in app)
checar('Relógio só roda com a tela aberta',
      'bloqTimer = setInterval(bloqRelogio, 15000)' in app and 'clearInterval(bloqTimer)' in app)
checar('Bloqueio continua opcional', "store.get('bloqueio', '0') === '1'" in app and 'id="c-bloqueio"' in html)
checar('Saída animada e curta', "tela.classList.add('saindo')" in app and '}, 260);' in app)
checar('Pontos de PIN acompanham a digitação', 'bloqPintaPontos' in app and "addEventListener('input', bloqPintaPontos)" in app)

# ---------- 3. Diagnóstico: estados e detalhes ----------
for estado in ['ok:', 'warn:', 'fail:', 'cfg:', 'off:', 'na:', 'nig:']:
    checar('Diagnóstico: estado ' + estado.rstrip(':'), estado in app[app.index('const DIAG_ESTADOS'):app.index('let diagContagem')])
checar('Diagnóstico: rótulos corretos',
      all(r in app for r in ['Operacional', 'Aviso', 'Falha', 'Não configurado', 'Desativado', 'Não aplicável', 'Não verificado']))
checar('Diagnóstico: impacto, orientação, atalho e horário',
      'diag-impacto' in app and 'diag-orientacao' in app and 'diag-atalho' in app and 'diag-hora' in app)
checar('Diagnóstico: resumo no topo', 'function diagResumo' in app and 'id="diag-resumo"' in html)
checar('Diagnóstico: atalho abre a aba certa',
      'abrirConfig(); mudarCategoriaConfig(extra.atalho.aba);' in app)

# ---------- 4. Diagnóstico: verificações reais ----------
for nome in ['Módulos no pacote instalado', 'Pacote instalado', 'Persistência local',
             'Configurações carregadas', 'Cofre do Obsidian', 'Rotinas', 'Serviço de escuta em segundo plano']:
    checar('Verificação implementada: ' + nome, nome in app)
checar('Persistência é testada gravando e relendo', "store.set('diag_probe', 'ok')" in app and "store.get('diag_probe') === 'ok'" in app)
checar('Recurso desativado não vira falha', "diagLinha('off', 'Cofre do Obsidian'" in app and "diagLinha(rotinasErro ? 'fail' : (rotinasN ? 'ok' : 'off')" in app)
checar('Pacote não verificável no navegador é assumido', "diagLinha('nig', 'Pacote instalado'" in app)
checar('Diagnóstico não afirma integridade do APK', 'conferidos na compilação, não aqui' in app)

# ---------- 5. Versão, documentação e suíte ----------
checar('Versão 1.21.3 / 10213', meta['version'] == '1.21.3' and meta['versionCode'] == 10213 and pkg['version'] == '1.21.3')
checar('app.js e interface na versão', "const VERSAO_APP = '1.21.3';" in app and html.count('v1.21.3') >= 2)
checar('CHANGELOG e LEIA-ME na versão', '## 1.21.3' in texto('CHANGELOG.md') and '# J.A.R.V.I.S. Nova 1.21.3' in texto('LEIA-ME.md'))
checar('Suíte roda este teste', 'python3 tests/test_v1_21_3.py' in pkg['scripts']['test:all'])
checar('Workflows na versão', '1.21.3' in texto('.github/workflows/build-apk.yml') and '1.21.3' in texto('.github/workflows/release-apk.yml'))
checar('Funções antigas preservadas', all(x in app for x in ['function executarDiagnostico', 'function obsEscolher', 'function verificarAtualizacaoUI']))

if falhas:
    print('\n%d verificação(ões) da 1.21.3 falharam.' % len(falhas))
    sys.exit(1)
print('1.21.3: bloqueio holográfico e diagnóstico com estados reais verificados.')
