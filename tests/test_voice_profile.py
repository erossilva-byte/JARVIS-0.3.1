"""Contrato do reconhecimento de locutor: consentimento, amostras, motor e privacidade."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
html = (ROOT / 'index.html').read_text(encoding='utf-8')
js = (ROOT / 'app.js').read_text(encoding='utf-8')
motor = (ROOT / 'voz_motor.js').read_text(encoding='utf-8')
# Só o bloco do locutor interessa: o resto do app usa FileReader para prévias de imagem.
inicio = js.index("VOZ_PERFIS_KEY")
fim = js.index("vozAplicarConfigUI();", inicio)
bloco_voz = js[inicio:fim]

checks = {
    'Botões de cadastrar/comparar/apagar perfil': all(x in html for x in ['c-voz-cadastrar', 'c-voz-verificar', 'c-voz-apagar-perfil']),
    'Consentimento explícito antes da captura': 'id="c-voz-consentimento"' in html and "if (!consent || !consent.checked)" in js,
    'Captura só acontece após ação do usuário': 'navigator.mediaDevices.getUserMedia' in js and 'btnVozCadastrar.onclick = async' in js,
    'Três frases guiadas': 'VOZ_FRASES' in js and 'Amostra ' in js and js.count('Jarvis, hoje eu quero') == 1,
    'Exige três amostras para salvar': "vozPendentes.length < 3" in js,
    'Perfil guarda apenas vetor e metadados': "VOZ_PERFIS_KEY = 'voz_perfis_v3'" in js and 'v: media.map' in js and 'samples: vozPendentes.length' in js,
    'Nenhum áudio bruto é persistido': 'readAsDataURL' not in bloco_voz and 'FileReader' not in bloco_voz and 'audioBase64' not in bloco_voz,
    'Perfil pode ser apagado': "vozSalvarLista(vozPerfis().filter" in js and 'Apagar perfil ativo' in html,
    'Limiar configurável e persistido': 'id="c-voz-limiar"' in html and "store.get('voz_limiar'" in js,
    'Identificação entre perfis é opcional': 'id="c-voz-identificar"' in html and 'm.identificar(perfis, r' in js,
    'Comparação devolve três estados': all(x in js for x in ['INCONCLUSIVO', 'COMPATÍVEL com a referência', 'DIFERENTE da referência']),
    'Aviso de que não é identidade confirmada': 'não é biometria certificada nem prova de identidade' in html and 'não é prova de identidade' in js,
    'Motor local é usado (não apenas UI)': 'VozMotor' in js and 'm.analisar(a.samples, a.sampleRate)' in js,
    'Qualidade da captura é mostrada': 'c-voz-qualidade' in html and 'vozDescreverQualidade' in js,
    'Diagnóstico de voz disponível': 'c-voz-diag' in html and 'pistaReplay' in js,
    'Microfone com cancelamento/ruído/AGC': all(x in html for x in ['c-mic-ec', 'c-mic-ns', 'c-mic-agc']) and 'echoCancellation: cfg.echoCancellation' in js,
    'Medidor de nível em tempo real': 'vozNivel' in js and 'c-audio-meter-fill' in js,
    'VAD, pitch e formantes no motor': all(x in motor for x in ['pitchHps', 'formantes', 'percentil(rmsLista', 'identificar']),
    'Perfil antigo não é apagado': "VOZ_PERFIL_KEY = 'perfil_acustico_v2'" in js,
}
for k, v in checks.items():
    print(('OK: ' if v else 'FALHA: ') + k)
if not all(checks.values()):
    raise SystemExit(1)
print('\nReconhecimento de locutor: consentimento, amostras, três estados, privacidade e diagnóstico verificados.')
