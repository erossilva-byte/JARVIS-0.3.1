"""Revisão 1.23.1 — store no escopo certo, diagnóstico horizontal e anexos no chat."""
import json
import pathlib
import re
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


# ---------- 1. "store is not defined": tudo dentro do IIFE ----------
fim = app.rstrip()
checar('app.js termina no fechamento do IIFE', fim.endswith('})();'))
checar('nenhum código solto depois do IIFE', fim[fim.rfind('})();') + 5:].strip() == '')
checar('bloco de efeitos dentro do IIFE',
      app.index('/* ---- "Reduzir efeitos visuais"') < app.rindex('})();'))
checar('anexos dentro do IIFE', app.index('const ANEXO_TEXTO') < app.rindex('})();'))
checar('store declarado antes de ser lido',
      app.index('const store = {') < app.index("store.get(CHAVE, 'completos')"))
checar('opção aplica a classe e persiste',
      "classList.toggle('efeitos-reduzidos'" in app and "store.set(CHAVE" in app)

# ---------- 2. Diagnóstico: texto na horizontal ----------
for marca in ['.diag-row .diag-cab{flex-wrap:wrap', '.diag-cab .diag-chip{flex:0 0 auto',
              'min-width:min(11ch,100%)', '.diag-grupo-lista>*,.diag-grupo,.diag-lista{min-width:0}']:
    checar('Diagnóstico horizontal: ' + marca, marca in css)
checar('Nenhum texto girado por writing-mode', 'writing-mode' not in css)
checar('Nome do cartão mantém palavra inteira',
      'white-space:normal' in css and 'word-break:normal' in css)

# ---------- 3. Anexos no chat ----------
checar('Botão de anexo no rodapé', 'id="btn-anexo"' in html and 'Anexar arquivos' in html)
checar('Seletor múltiplo nativo', 'id="anexo-input"' in html and 'type="file" multiple' in html)
checar('Lista de anexos na interface', 'id="anexos"' in html and 'class="anexos"' in html)
checar('Leitura de texto por FileReader', 'new FileReader()' in app and 'readAsText(arquivo)' in app)
checar('Limite por arquivo', 'const ANEXO_MAX = 40000' in app)
checar('Conteúdo entra no mesmo pedido da IA', "const pedido = extra ? t" in app)
checar('Anexos limpos depois do envio', 'limparAnexos();' in app)
checar('Imagem remetida ao Visão', 'analise no painel Visão' in app)
checar('Binário não é lido como texto', 'aqui só leio texto' in app)
trecho = app[app.index('function renderAnexos'):app.index('function anexosParaIA')]
checar('Render sem innerHTML', 'innerHTML' not in trecho and 'textContent' in trecho)
checar('Estilo dos anexos', '.anexo-item' in css and 'button.anexo' in css)

# ---------- 4. Versão e suíte ----------
V = meta.get('version', '')
partes = tuple(int(x) for x in V.split('.')) if re.fullmatch(r'\d+\.\d+\.\d+', V) else (0,)
checar('VERSAO.json em 1.23.1 ou posterior', partes >= (1, 23, 1) and meta.get('versionCode') >= 10231)
checar('package.json acompanha a versão', pkg.get('version') == V)
checar('app.js acompanha a versão', ("const VERSAO_APP = '%s';" % V) in app)
checar('interface acompanha a versão', ('v' + V) in html and 'v1.23.0' not in html)
checar('CHANGELOG e LEIA-ME preservam a 1.23.1',
      '## 1.23.1' in texto('CHANGELOG.md') and '1.23.1' in texto('LEIA-ME.md'))
checar('Workflows acompanham a versão', V in texto('.github/workflows/build-apk.yml')
      and V in texto('.github/workflows/release-apk.yml'))
checar('Suíte roda este teste', 'python3 tests/test_v1_23_1.py' in pkg['scripts']['test:all'])
checar('Limites declarados no changelog',
      'CADe SIMU' in texto('CHANGELOG.md') and 'alarme do Windows' in texto('CHANGELOG.md'))

if falhas:
    print('\n%d verificação(ões) da 1.23.1 falharam.' % len(falhas))
    sys.exit(1)
print('1.23.1: store no escopo, diagnóstico horizontal e anexos verificados.')
