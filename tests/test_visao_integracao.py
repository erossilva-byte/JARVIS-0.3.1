"""Contrato da integração do contexto visual no app (estático, sem rede nem câmera).

Confere a fiação: módulo carregado antes do app, análise registrada, pergunta resolvida antes da
chamada de IA, referente explícito no pedido, ponte com a base elétrica, OCR como dado, privacidade
e o módulo presente nos dois pacotes.
"""
from pathlib import Path

raiz = Path(__file__).resolve().parents[1]
html = (raiz / 'index.html').read_text(encoding='utf-8')
app = (raiz / 'app.js').read_text(encoding='utf-8')
ctx = (raiz / 'visao_contexto.js').read_text(encoding='utf-8')
release = (raiz / '.github/workflows/release-apk.yml').read_text(encoding='utf-8')
build = (raiz / '.github/workflows/build-apk.yml').read_text(encoding='utf-8')
doc = (raiz / 'docs/VISION.md').read_text(encoding='utf-8')
pacote = (raiz / 'package.json').read_text(encoding='utf-8')

checagens = {
    'visao_contexto.js carregado antes do app': 'visao_contexto.js' in html and html.index('visao_contexto.js') < html.index('app.js'),
    'análise registra o contexto': 'registrarContextoVisual(r);' in app,
    'ponte JarvisVisao exposta': 'window.JarvisVisao = {' in app and 'resolver: (texto)' in app,
    'pergunta resolvida antes da IA': app.index('VC.resolver(ctx, pergunta)') < app.index('analisarDataUrl(visaoUltimaImagem, perg)'),
    'referente explícito no pedido': 'referente = \' [contexto visual: \'' in app and 'pergunta + referente' in app,
    'pergunta técnica sem rede': "res.intencao === 'tecnico'" in app and 'window.EletricaBase' in app,
    'OCR tratado como dado': 'tratado_como' in ctx and "'dado'" in ctx,
    'marca exige evidência': 'evidenciaSuficiente' in ctx and "o.marca = ''" in ctx,
    'privacidade sem salvamento automático': 'podeSalvar' in ctx and 'precisaConsentimento' in ctx,
    'módulo nos dois workflows': 'visao_contexto.js' in release and 'visao_contexto.js' in build,
    'módulo no pacote Windows': '"visao_contexto.js"' in pacote,
    'suíte roda o novo teste': 'tests/test_visao_contexto.js' in pacote,
    'documento de auditoria do Vision': 'Diagnóstico do Vision anterior' in doc and 'Limitações' in doc,
}

falhas = [nome for nome, ok in checagens.items() if not ok]
for nome, ok in checagens.items():
    print(('OK: ' if ok else 'FALHA: ') + nome)
if falhas:
    print('\n%d verificação(ões) da integração do Vision falharam.' % len(falhas))
    raise SystemExit(1)
print('\nIntegração do Vision: %d verificações aprovadas.' % len(checagens))
