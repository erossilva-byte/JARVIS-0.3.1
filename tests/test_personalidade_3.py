"""Personalidade permanente: prompt, padrões, IA local, voz e empacotamento."""
import json
import pathlib
ROOT = pathlib.Path(__file__).resolve().parent.parent
app = (ROOT / 'app.js').read_text(encoding='utf-8')
html = (ROOT / 'index.html').read_text(encoding='utf-8')
humor = (ROOT / 'humor.js').read_text(encoding='utf-8')
pkg = json.loads((ROOT / 'package.json').read_text(encoding='utf-8'))
falhas = []
def c(n, ok):
    print(('OK: ' if ok else 'FALHA: ') + n)
    if not ok: falhas.append(n)
c('módulo de humor carregado antes do app', html.index('humor.js') < html.index('src="app.js"'))
c('prompt de sistema usa regras obrigatórias', 'HumorJarvis.estiloPrompt' in app and 'regrasHumor' in app)
c('prompt recebe ângulo contextual do turno', 'HumorJarvis.sugerir(perguntaAtual' in app and 'Ângulo de humor para este turno' in app)
c('IA local também recebe personalidade', 'HumorJarvis.estiloPrompt(Object.assign({ humor: 90 }' in app)
c('humor padrão elevado a 90', "store.get('humor', '90')" in app and 'value="90"' in html)
c('eixos padrão elevados', all(x in app for x in ['sarcasmo: 90', 'ironia: 90', 'brincadeiras: 85', 'espontaneidade: 85', 'provocacao: 70', 'formalidade: 15']))
c('voz aplica prosódia por frase', 'opcoesComProsodia' in app and 'HumorJarvis.prosodia' in app)
c('três caminhos de voz usam prosódia', app.count('opcoesComProsodia(opcoes, partes[i])') >= 3)
c('abertura neutra proibida no prompt', 'Proibido abrir' in humor and 'Como posso ajudar' in humor)
c('assunto sensível silencia humor', 'Em emergência, saúde, luto' in humor)
c('humor entra nos arquivos do Electron', 'humor.js' in pkg['build']['files'])
c('teste de humor na suíte', 'tests/test_humor.js' in pkg['scripts']['test:all'])
for w in ['.github/workflows/build-apk.yml', '.github/workflows/release-apk.yml']:
    c('CI copia o humor (%s)' % w, 'humor.js' in (ROOT / w).read_text(encoding='utf-8'))
if falhas:
    print('\n%d verificação(ões) da personalidade falharam.' % len(falhas))
    raise SystemExit(1)
print('\nPersonalidade: prompt, padrões, IA local, voz e CI verificados.')
