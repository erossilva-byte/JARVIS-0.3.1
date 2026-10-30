"""Contrato do reconhecimento de locutor na interface e no pacote Android."""
import json
import pathlib

RAIZ = pathlib.Path(__file__).resolve().parent.parent
html = (RAIZ / 'index.html').read_text(encoding='utf-8')
app = (RAIZ / 'app.js').read_text(encoding='utf-8')
mod = (RAIZ / 'voz_motor.js').read_text(encoding='utf-8')
pkg = json.loads((RAIZ / 'package.json').read_text(encoding='utf-8'))
falhas = []


def check(nome, ok, det=''):
    print(('OK: ' if ok else 'FALHA: ') + nome + ((' -> ' + str(det)) if (not ok and det) else ''))
    if not ok:
        falhas.append(nome)


check('motor carregado antes do app', html.index('voz_motor.js') < html.index('src="app.js"'))
check('motor expõe análise, comparação e identificação', all(x in mod for x in ['analisar: analisar', 'comparar: comparar', 'identificar: identificar']))
check('motor tem VAD e formantes', 'percentil(rmsLista' in mod and 'formantes' in mod and 'pitchHps' in mod)
check('motor não guarda áudio', 'localStorage' not in mod and 'fetch(' not in mod)

campos = ['c-voz-consentimento', 'c-voz-nome', 'c-voz-frase', 'c-voz-salvar', 'c-voz-diag',
          'c-voz-perfil-ativo', 'c-voz-limiar', 'c-voz-identificar', 'c-mic-ec', 'c-mic-ns',
          'c-mic-agc', 'c-voz-qualidade', 'c-voz-perfis']
for c in campos:
    check('controle %s existe' % c, ('id="%s"' % c) in html)

check('consentimento é exigido antes de gravar', "if (!consent || !consent.checked)" in app)
check('captura usa configurações de áudio do usuário', 'echoCancellation: cfg.echoCancellation' in app and 'noiseSuppression: cfg.noiseSuppression' in app and 'autoGainControl: cfg.autoGainControl' in app)
check('microfone é liberado ao terminar', 'stream.getTracks().forEach((t) => t.stop())' in app)
check('captura dura quatro segundos', 'capturarAmostraVoz(4000)' in app)
check('medidor atualiza em tempo real', 'vozNivel(' in app and 'aria-valuenow' in app)
check('amostra com qualidade ruim é recusada', 'if (!r.qualidade.ok)' in app and 'Amostra recusada' in app)
check('três amostras compõem o perfil', 'vozPendentes.length < 3' in app and 'Grave três amostras' in app)
check('perfil é média dos vetores', 'media[i] += x / vozPendentes.length' in app)
check('máximo de cinco perfis', '.slice(0, 5)' in app)
check('limiar é aplicado na comparação', 'm.identificar(perfis, r, { limiar: limiar' in app and 'm.comparar(perfis.find' in app)
check('resultado inconclusivo é tratado', "res.estado === 'compativel'" in app and "res.estado === 'diferente'" in app and 'INCONCLUSIVO' in app)
check('diagnóstico mostra motor, limiar e microfone', 'Diagnóstico: motor' in app and 'microfone ' in app)
check('pista de replay é apresentada como indício', 'm.pistaReplay(r)' in app and 'não é prova' in app)
check('ativação por voz continua usando o perfil', 'capturarVetorVoz()' in app and 'similaridadeVoz(p.v' in app)

check('motor entra nos arquivos do Electron', 'voz_motor.js' in pkg['build']['files'])
check('teste do motor registrado', 'tests/test_voz_motor.js' in pkg['scripts']['test:all'])
check('teste de UI registrado', 'tests/test_voz_ui.py' in pkg['scripts']['test:all'])
for w in ['.github/workflows/build-apk.yml', '.github/workflows/release-apk.yml']:
    texto = (RAIZ / w).read_text(encoding='utf-8')
    check('CI copia o motor (%s)' % w, 'voz_motor.js' in texto)

if falhas:
    print('\n%d verificação(ões) da voz falharam.' % len(falhas))
    raise SystemExit(1)
print('\nMotor de voz: captura, consentimento, qualidade, perfis, limiar, diagnóstico e CI verificados.')
