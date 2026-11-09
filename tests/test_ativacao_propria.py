"""Auditoria do detector KWS Android e da escuta Groq/WebView."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
app = (ROOT / "app.js").read_text(encoding="utf-8")
html = (ROOT / "index.html").read_text(encoding="utf-8")
hermes = (ROOT / "hermes.js").read_text(encoding="utf-8")
servico = (ROOT / "JarvisService.java").read_text(encoding="utf-8")
engine = (ROOT / "JarvisKwsEngine.java").read_text(encoding="utf-8")
prefs = (ROOT / "JarvisPrefs.java").read_text(encoding="utf-8")
plugin = (ROOT / "JarvisBackgroundPlugin.java").read_text(encoding="utf-8")
prepare = (ROOT / "preparar_kws.py").read_text(encoding="utf-8")
release = (ROOT / ".github/workflows/release-apk.yml").read_text(encoding="utf-8")
main_js = (ROOT / "platforms/desktop/main.js").read_text(encoding="utf-8")
css = (ROOT / "style.css").read_text(encoding="utf-8")

issues = []

# 1. O detector de segundo plano é KWS acústico real, não ASR contínuo.
if "new JarvisKwsEngine(" not in servico:
    issues.append("JarvisService não instancia o motor KWS")
if 'DETECTOR = "sherpa-onnx-kws-gigaspeech-en"' not in servico:
    issues.append("Nome do motor KWS não está exposto no serviço")
if "SpeechRecognizer.createSpeechRecognizer(" in servico or "SpeechRecognizer.createOnDeviceSpeechRecognizer(" in servico:
    issues.append("Serviço de ativação ainda chama SpeechRecognizer")
if "new AudioRecord(" not in engine or "audio.read(" not in engine:
    issues.append("KWS não captura áudio PCM contínuo por AudioRecord")
if "new KeywordSpotter(config)" not in engine or "kws.decode(kwsStream)" not in engine:
    issues.append("KWS não executa inferência sherpa-onnx")
if "pcm[i] / 32768.0f" not in engine:
    issues.append("PCM 16-bit não é convertido para float corretamente")
if '.setProvider("cpu")' not in engine or ".setNumThreads(2)" not in engine:
    issues.append("Configuração de inferência local CPU não está explícita")
if "não usa SpeechRecognizer, rede ou serviço de nuvem" not in engine:
    issues.append("Privacidade do áudio antes da palavra-chave não está documentada")
if "setKeywordsThreshold(keywordThreshold)" not in engine:
    issues.append("Sensibilidade não altera o limiar do KWS")
if "montarPalavrasChave(extraKeywords)" not in engine or "JarvisPrefs.variantes(this)" not in servico:
    issues.append("Palavras-chave adicionais não chegam ao motor KWS")
if "JarvisPrefs.sensibilidade(this)" not in servico:
    issues.append("Sensibilidade persistida não chega ao motor KWS")
if "sherpa-onnx-cli" not in prepare or "text2token" not in prepare:
    issues.append("Build não gera tokens das palavras-chave com ferramenta sherpa oficial")
if "src/main/assets/kws" not in prepare or "preparar_kws.py android/app" not in release:
    issues.append("Modelo KWS não é empacotado nos assets do APK")
if "JarvisKwsEngine.java" not in release:
    issues.append("Workflow de Release não copia a classe KWS")

# 2. A interface descreve o motor real e não promete ASR Android como KWS.
for token in ("sherpa-onnx KWS", "AudioRecord", "treinado em inglês", 'id="c-wake-sensibilidade"', 'id="c-wake-variantes"'):
    if token not in html:
        issues.append("Interface sem informação/controle KWS: " + token)
for token in ("KWS acústico local", "KWS sherpa-onnx local", "JarvisPrefs.variantes"):
    if token not in app and token not in servico:
        issues.append("Aplicativo sem integração KWS: " + token)
if "o reconhecimento do Android transcreve e as regras de fonética do núcleo decidem" in html:
    issues.append("Interface ainda descreve o detector antigo como motor de ativação")

# 3. Escuta Groq e lógica Hermes permanecem como modo alternativo no app aberto.
if "Hermes.ativacao.presente" not in app:
    issues.append("Escuta Groq não usa as regras de ativação Hermes")
if "ATIVACAO_VARIANTES" not in hermes:
    issues.append("Lista de variantes fonéticas Hermes não existe")

# 4. Cofre de chaves Windows e segurança do resto da aplicação permanecem.
if "safeStorage.encryptString" not in main_js or "safeStorage.decryptString" not in main_js:
    issues.append("Cofre criptografado do Windows ausente")

# 5. Personalidade: humor seco com limites e frases próprias novas.
for token, nome in (
    ("sarcasmo seco", "caráter do humor"),
    ("Nunca rude, nunca ofensivo, nunca humilhante", "limites do humor"),
    ("o humor desaparece por completo", "suspensão do humor em assunto sério"),
    ("visaoSemObjeto", "frase própria da visão"),
    ("roteadorTroca", "frase própria da troca de motor"),
):
    if token not in app:
        issues.append("Personalidade/frases: falta " + nome)

# 6. Estados de carregamento e movimento reduzido continuam disponíveis.
if "function msgPensando" not in app or "function removerPensando" not in app:
    issues.append("Falta estado de carregamento da conversa")
if ".pensando-pontos" not in css or ".msg.pensando" not in css:
    issues.append("Estado de carregamento sem estilo")
if "@media(prefers-reduced-motion:reduce)" not in css.replace(" ", ""):
    issues.append("Movimento reduzido não é respeitado")

if issues:
    print("FALHA na auditoria KWS:")
    for item in issues:
        print(" - " + item)
    raise SystemExit(1)

print("KWS sherpa-onnx validado estaticamente: captura PCM local, inferência CPU, "
      "limiar e palavras extras conectados, build do APK configurado; Hermes/Groq preservados.")
