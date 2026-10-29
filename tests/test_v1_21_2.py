"""Revisão 1.21.2 — auditoria de runtime e instalação reproduzível.

Confere as duas correções desta versão (handler de apagar chave com tratamento de erro e
lockfile em sincronia com o package.json), a coerência de versão e a documentação.
Não declara testado em aparelho o que só existe em código.
"""
import json
import pathlib
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent


def texto(nome):
    return (RAIZ / nome).read_text(encoding='utf-8')


app = texto('app.js')
html = texto('index.html')
meta = json.loads(texto('VERSAO.json'))
pkg = json.loads(texto('package.json'))
lock = json.loads(texto('package-lock.json'))

falhas = []


def checar(nome, ok):
    print(('OK: ' if ok else 'FALHA: ') + nome)
    if not ok:
        falhas.append(nome)


# ---------- 1. Handler de apagar chave com tratamento de erro ----------
inicio = app.find("Object.keys(CAMPOS_CHAVE).forEach((n) => {")
fim = app.find("function atualizarValoresVoz", inicio)
bloco = app[inicio:fim] if inicio >= 0 and fim > inicio else ''
checar('Handler de apagar chave localizado', bool(bloco))
checar('Handler tem try/catch', 'try {' in bloco and 'catch (e)' in bloco)
checar('Falha avisa o usuário em vez de só rejeitar', 'Não consegui apagar a chave' in bloco and "msg('sis', texto)" in bloco)
checar('Botão ausente não derruba o laço', "if (!botao) return;" in bloco)
checar('Sucesso continua registrando e atualizando a lista', "registrar('config', 'chave ' + n + ' apagada')" in bloco and 'mostrarChaves(); atualizarChipIA();' in bloco)

# ---------- 2. Lockfile em sincronia (npm ci volta a funcionar) ----------
deps = lock.get('packages', {})
checar('Lockfile tem versão de formato', isinstance(lock.get('lockfileVersion'), int))
checar('Lockfile registra as dependências do app', all(('node_modules/' + d) in deps for d in pkg['dependencies']))
checar('Lockfile registra o empacotador Windows',
      any(k.startswith('node_modules/electron-builder') for k in deps))
checar('Lockfile e package.json na mesma versão',
      deps.get('', {}).get('version') == pkg['version'])

# ---------- 3. Versão e documentação ----------
checar('VERSAO.json e package.json na 1.21.2',
      meta['version'] == '1.21.2' and pkg['version'] == '1.21.2' and meta['versionCode'] == 10212)
checar('app.js na versão corrente', "const VERSAO_APP = '1.21.2';" in app)
checar('Interface na versão corrente', html.count('v1.21.2') >= 2)
checar('CHANGELOG registra a 1.21.2', '## 1.21.2' in texto('CHANGELOG.md'))
checar('LEIA-ME registra a 1.21.2',
      '# J.A.R.V.I.S. Nova 1.21.2' in texto('LEIA-ME.md') and '## O que mudou na 1.21.2' in texto('LEIA-ME.md'))
checar('Suíte roda este teste', 'python3 tests/test_v1_21_2.py' in pkg['scripts']['test:all'])
checar('Workflows citam a versão corrente',
      '1.21.2' in texto('.github/workflows/build-apk.yml')
      and '1.21.2' in texto('.github/workflows/release-apk.yml'))

# ---------- 4. Funções preservadas das versões anteriores ----------
checar('Cofre do Obsidian segue ligado à interface',
      'function obsEscolher' in app and 'id="obs-ativo"' in html)
checar('Memória por tópicos preservada', 'function arquivosPorTopico' in texto('memoria.js'))
checar('Núcleo 3D preservado', 'Render3D.prototype.quadro' in texto('orbita.js'))
checar('IA local com validação de modelo preservada',
      'LlmInference.createFromOptions' in texto('JarvisLocalAIPlugin.java'))
checar('Atualização in-app preservada',
      'verificarAtualizacaoUI' in app and 'JarvisUpdatePlugin' in texto('JarvisUpdatePlugin.java'))

if falhas:
    print('\n%d verificação(ões) da 1.21.2 falharam.' % len(falhas))
    sys.exit(1)
print('1.21.2: auditoria de runtime e instalação reproduzível verificadas.')
