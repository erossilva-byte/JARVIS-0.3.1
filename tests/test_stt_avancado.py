"""Contrato da voz 1.42.0: confiança, alternativas, filtro, replay e diagnóstico.

Não mede áudio: confere que o caminho real liga os sinais que o motor devolve,
que a captura usa a cadeia de filtros e que o teste de WER/latência está ligado.
A validação acústica continua dependendo de microfone e gravações no aparelho.
"""
import json
import pathlib
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
app = (RAIZ / 'app.js').read_text(encoding='utf-8')
html = (RAIZ / 'index.html').read_text(encoding='utf-8')
java = (RAIZ / 'JarvisBackgroundPlugin.java').read_text(encoding='utf-8')
fala = (RAIZ / 'fala.js').read_text(encoding='utf-8')
audio = (RAIZ / 'audio_pcm.js').read_text(encoding='utf-8')
ident = (RAIZ / 'identidade.js').read_text(encoding='utf-8')
motor = (RAIZ / 'voz_motor.js').read_text(encoding='utf-8')
escuta = (RAIZ / 'escuta.js').read_text(encoding='utf-8')
pkg = json.loads((RAIZ / 'package.json').read_text(encoding='utf-8'))
falhas = []


def check(nome, ok, detalhe=''):
    print(('OK: ' if ok else 'FALHA: ') + nome + ((' -> ' + str(detalhe)) if not ok and detalhe else ''))
    if not ok:
        falhas.append(nome)


check('Android devolve confiança', 'SpeechRecognizer.CONFIDENCE_SCORES' in java and 'ret.put("confianca"' in java)
check('Android devolve até cinco alternativas', 'RESULTS_RECOGNITION' in java and 'i < 5' in java and 'alternativas.put' in java)
check('app consome confiança e alternativas', 'confianca: r && r.confianca' in app and 'alternativas: r && r.alternativas' in app)
check('app avalia a transcrição antes de executar', 'function avaliarTranscricao' in app and 'F.avaliar' in app and 'ultimaTranscricaoAvaliada' in app)
check('baixa confiança pede repetição', 'precisaRepetir' in app and 'Repita devagar ou digite' in app)
check('captura normal usa high-pass e compressor', 'ligarFiltrosMicrofone' in app and 'highpass' in app and 'DynamicsCompressor' in app)
check('teste de transcrição compara esperado e reconhecido', all(x in app for x in ('c-voz-teste-transcrever', 'F.acerto(esperado, reconhecido)', 'F.wer(esperado, reconhecido)', 'pintarMetricasVoz')))
check('teste de transcrição registra latência real', 'Date.now() - t0' in app and 'latenciaMs' in app and 'latenciaMediaMs' in app)
check('WAV PCM é usado como fallback real', 'gravarWav' in app and 'AudioPcm.wav' in app and "audio.wav" in app)
check('módulo de fala é puro e testável', 'document.' not in fala and 'fetch(' not in fala and 'localStorage' not in fala)
check('módulo PCM é puro e testável', 'document.' not in audio and 'fetch(' not in audio and 'localStorage' not in audio)
check('scripts entram antes do app', html.index('src="fala.js"') < html.index('src="app.js"') and html.index('src="audio_pcm.js"') < html.index('src="app.js"'))
check('perfil pondera amostras por qualidade', 'pesos' in ident and 'snrDb' in ident and 'somaPeso' in ident)
check('replay bloqueia identidade', 'replay.suspeita' in ident and "estado: ESTADOS.INCONCLUSIVO" in ident and 'replay: true' in ident)
check('pista de replay lê pausaRatio da qualidade', 'q.pausaRatio' in motor)
check('teste estático entra na suíte', 'python3 tests/test_stt_avancado.py' in pkg['scripts']['test:all'])
check('fala e PCM entram no pacote Electron', 'fala.js' in pkg['build']['files'] and 'audio_pcm.js' in pkg['build']['files'])
check('detector de fluxo é puro e testável', 'criarDetectorRms' in escuta and 'function criarDetectorRms' in escuta and 'DETECTOR_PADRAO' in escuta)
check('captura principal usa VAD/WAV', 'return gravarWav()' in app and 'E.criarDetectorRms' in app and 'capturarAmostraVoz(20000' in app and 'reamostrar(a.samples, a.sampleRate, alvo)' in app)
check('MediaRecorder virou caminho de reserva', "typeof window.MediaRecorder !== 'function') return null" in app)
check('toggles do microfone chegam ao gravador', 'const mic = vozMicConfig()' in app and 'echoCancellation: mic.echoCancellation' in app and 'autoGainControl: mic.autoGainControl' in app)
check('seletor de STT tem quatro motores reais', all(x in html for x in ('id="c-stt-motor"', 'value="auto"', 'value="groq"', 'value="android"', 'value="android-local"')))
check('roteamento respeita o motor escolhido', all(x in app for x in ('STT_MOTORES', 'motor === \'android-local\'', 'motorPedido !== \'groq\'', 'transcreverAndroidApp')))
check('captura mede duração e bytes', 'audioMs: cap ? cap.duracaoMs' in app and 'bytesMedios' in app and 'audioMedioMs' in app)

if falhas:
    print('\n%d verificação(ões) falharam.' % len(falhas))
    sys.exit(1)
print('\nVoz 1.42.0: confiança, alternativas, filtros, replay e diagnóstico ligados no caminho real.')
