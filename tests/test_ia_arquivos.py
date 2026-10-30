"""IA executa arquivos: ações reais expostas ao modelo, com limites por plataforma."""
import io
import os
import json

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
app = io.open(os.path.join(RAIZ, 'app.js'), encoding='utf-8').read()
pkg = json.loads(io.open(os.path.join(RAIZ, 'package.json'), encoding='utf-8').read())
falhas = []


def check(nome, cond, det=''):
    if cond:
        print('OK: ' + nome)
    else:
        falhas.append(nome)
        print('FALHA: ' + nome + ((' -> ' + str(det)) if det else ''))


# Cada ação precisa existir, ser só de desktop e chamar o motor de verdade.
acoes = {
    'arquivos_listar': 'arq_listar',
    'arquivo_ler': 'arq_ler',
    'arquivo_pesquisar': 'arq_pesquisar',
    'arquivo_verificar': 'arq_verificar',
    'arquivo_criar': ['arq_salvar'],
    'arquivo_editar': ['arq_ler', 'arq_salvar'],
    'arquivo_compactar': 'arq_compactar',
}
for nome, motor in acoes.items():
    marca = nome + ': {'
    check('Ação existe: ' + nome, marca in app)
    if marca not in app:
        continue
    trecho = app[app.index(marca):app.index(marca) + 4200]
    check(nome + ' é só desktop', "disp: ['desktop']" in trecho, trecho[:120])
    motores = motor if isinstance(motor, list) else [motor]
    for m in motores:
        check(nome + ' chama ' + m, "nativo('" + m + "'" in trecho)

ler = app[app.index('arquivo_ler: {'):app.index('arquivo_pesquisar: {')]
check('Leitura marcada como não confiável', 'naoConfiavel: true' in ler)
check('Leitura recusa binário', 'r.binario' in ler and 'Não é texto' in ler)
check('Leitura limita o trecho', 'slice(0, 6000)' in ler)

criar = app[app.index('arquivo_criar: {'):app.index('arquivo_editar: {')]
check('Gravação exige confirmação (risco 2)', 'risco: 2' in criar)
check('Gravação sempre com backup', 'backup: true' in criar)
check('Gravação recusa conteúdo vazio', 'O conteúdo está vazio' in criar)

editar = app[app.index('arquivo_editar: {'):app.index('arquivo_compactar: {')]
check('Edição usa hash da leitura (conflito)', 'hashEsperado: atual.hash' in editar)
check('Edição recusa binário', 'não edito binário' in editar)

pesq = app[app.index('arquivo_pesquisar: {'):app.index('arquivo_verificar: {')]
check('Pesquisa também é conteúdo não confiável', 'naoConfiavel: true' in pesq)

check('Ações entram no prompt via disponiveis()', "disponiveis().map((k) => `- ${k}: ${ACOES[k].ajuda" in app)
check('Prompt não promete arquivos no Android', "disp: ['desktop']" in app and 'Android estas ações NÃO entram' in app)
check('Teste registrado na suíte', 'python3 tests/test_ia_arquivos.py' in pkg['scripts']['test:all'])

if falhas:
    print('\n%d verificação(ões) da IA com arquivos falharam.' % len(falhas))
    raise SystemExit(1)
print('\nIA com arquivos: ações, risco, backup, hash e plataforma verificados.')
