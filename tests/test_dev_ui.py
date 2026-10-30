"""Contrato da aba Desenvolvimento de Arquivos: painel, navegação, ações e empacotamento."""
import json
import pathlib

RAIZ = pathlib.Path(__file__).resolve().parent.parent
html = (RAIZ / 'index.html').read_text(encoding='utf-8')
app = (RAIZ / 'app.js').read_text(encoding='utf-8')
mod = (RAIZ / 'arquivos_dev.js').read_text(encoding='utf-8')
css = (RAIZ / 'style.css').read_text(encoding='utf-8')
pkg = json.loads((RAIZ / 'package.json').read_text(encoding='utf-8'))
falhas = []


def check(nome, ok):
    print(('OK: ' if ok else 'FALHA: ') + nome)
    if not ok:
        falhas.append(nome)


painel = html.split('id="painel-dev"')[1].split('</aside>')[0] if 'id="painel-dev"' in html else ''
check('painel de desenvolvimento existe', bool(painel))
check('painel tem rótulo acessível', 'aria-label="Desenvolvimento de arquivos' in painel)
check('aba própria na navegação', 'data-lat="dev"' in html and 'Dev. Arquivos' in html)
check('navegação abre a aba', "if (alvo === 'dev') { devAbrir(); return; }" in app)
check('painel entra na lista de painéis', "'#painel-dev'" in app)
check('painel entra na checagem de essenciais', "$('#painel-dev')" in app)
check('botão fechar ligado', "devFechar.onclick = () => fecharPaineis()" in app)
check('módulo carregado antes do app', html.index('arquivos_dev.js') < html.index('src="app.js"'))

campos = ['dev-input', 'dev-drop', 'dev-instrucao', 'dev-correcao', 'dev-formato',
          'dev-nome', 'dev-conteudo', 'dev-lista', 'dev-relatorio', 'dev-resultados', 'dev-historico']
for campo in campos:
    check('campo %s presente' % campo, ('id="%s"' % campo) in painel)

botoes = ['dev-escolher', 'dev-limpar', 'dev-analisar', 'dev-executar', 'dev-corrigir',
          'dev-criar', 'dev-zip', 'dev-historico-limpar']
for b in botoes:
    check('botão %s tem ação' % b, ("getElementById('%s')" % b) in app)

check('aceita múltiplos arquivos', 'id="dev-input" type="file" multiple' in painel)
check('aceita projeto .zip', '.zip' in painel and "DEV.extensao(f.name) === 'zip'" in app)
check('ZIP é descompactado no aparelho', 'DEV.descompactar' in app and 'DecompressionStream' in app)
check('leitura limita tamanho', 'DEV.LIMITE_TEXTO' in app)
check('binário é recusado com explicação', 'é binário; aqui só leio texto' in app)
check('original é preservado', 'original: texto' in app and 'a.modificado = true' in app)
check('correção não destrói original', 'O original continua guardado' in app)
check('histórico persistido e limitado', "DEV_HIST_KEY = 'jv_dev_hist'" in app and '.slice(0, 30)' in app)
check('download individual', 'URL.createObjectURL' in app and 'a.download = nome' in app)
check('download do projeto em ZIP', 'jarvis-arquivos.zip' in app)
check('análise ligada ao motor', 'DEV.analisar' in app)
check('correções ligadas ao motor', 'DEV.corrigir' in app)
check('criação ligada ao motor', 'DEV.criar(formato' in app)
check('projeto por instrução gera README e código', 'function devProjeto' in app and 'README.md' in app)
check('instrução em português executada', 'DEV.instrucao(txt, devArquivos)' in app)

check('motor gera PDF real', "if (f.id === 'pdf') bytes = pdf(texto)" in mod)
check('motor gera DOCX real', 'function docx(' in mod and 'word/document.xml' in mod)
check('motor gera XLSX real', 'function xlsx(' in mod and 'xl/worksheets/sheet1.xml' in mod)
check('motor gera ZIP com CRC', 'function crc32(' in mod and '0x50, 0x4b, 0x03, 0x04' in mod)
check('análise não executa código recebido', 'eval(' not in mod.split('function analisar')[1].split('function corrigir')[0])
check('segredo, conflito e importação checados', all(x in mod for x in ["id: 'segredo'", "id: 'conflito'", 'importacao']))

check('resultado de voz em três estados', all(x in app for x in ['INCONCLUSIVO', 'COMPATÍVEL com a referência', 'DIFERENTE da referência']))
check('limiar de voz é configurável', "store.get('voz_limiar'" in app and "INCONCLUSIVO" in app)

check('estilo do painel responsivo', '.painel-dev' in css and '@media (max-width:520px)' in css)
check('painel rola na vertical', '#painel-dev{overflow-y:auto' in css)

check('módulo entra nos arquivos do Electron', 'arquivos_dev.js' in pkg['build']['files'])
check('teste registrado na suíte', 'tests/test_dev_analise.js' in pkg['scripts']['test:all'] and 'tests/test_dev_auditoria.py' in pkg['scripts']['test:all'])
for w in ['.github/workflows/build-apk.yml', '.github/workflows/release-apk.yml']:
    texto = (RAIZ / w).read_text(encoding='utf-8')
    check('CI copia o módulo (%s)' % w, 'arquivos_dev.js' in texto)

if falhas:
    print('\n%d verificação(ões) da aba de desenvolvimento falharam.' % len(falhas))
    raise SystemExit(1)
print('\nDesenvolvimento de Arquivos: painel, navegação, análise, original, exportação e CI verificados.')
