"""Verificações estáticas da 1.8.0: detector livre mais tolerante (e sem pisca-pisca de
microfone), botão explícito de desligar o segundo plano, voz que não muda sozinha e
personalidade mais conversadora. Não executa Android: são checagens de código-fonte.
"""
import json
import pathlib

raiz = pathlib.Path(__file__).resolve().parent.parent
servico = (raiz / "JarvisService.java").read_text(encoding="utf-8")
plugin = (raiz / "JarvisBackgroundPlugin.java").read_text(encoding="utf-8")
historico = (raiz / "CHANGELOG.md").read_text(encoding="utf-8")
app = (raiz / "app.js").read_text(encoding="utf-8")
html = (raiz / "index.html").read_text(encoding="utf-8")
versao = json.loads((raiz / "VERSAO.json").read_text(encoding="utf-8"))
pacote = json.loads((raiz / "package.json").read_text(encoding="utf-8"))

checagens = {
    "Detector confere todas as hipóteses do Android": (
        "conferirWakeLivreEmLote" in servico
        and "EXTRA_MAX_RESULTS, 5" in servico),
    "Aceita as formas que o transcritor realmente devolve": all(
        forma in servico for forma in ("javis", "jarvy", "charves", "jarvis")),
    "Sessões mais longas reduzem abertura/fechamento do microfone": all(
        extra in servico for extra in (
            "EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS",
            "EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS",
            "EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS")),
    "Falha fatal desliga o vigia em vez de religar a cada 15 min": (
        "JarvisPrefs.desejaOuvir(this, false);" in servico
        and "JarvisWatchdog.cancelar(this);" in servico
        and "private void pararPorFalha" in servico),
    "Notificação usa rótulo claro para desligar": '"Desligar escuta"' in servico,
    "Interface tem botão explícito de desligar o segundo plano": (
        'id="c-bg-desligar"' in html and "btnBgDesligar" in app),
    "Escuta que para sozinha também desliga a preferência": (
        "store.set('wake', '0')" in app),
    "Voz salva é fixada e não recalculada a cada abertura": (
        "store.set('voz', sel.value)" in app),
    "Perfil de voz Jarvis completo existe": "jarvis: { nome:" in app,
    "Guia de voz offline masculina na interface": (
        "pt_BR-faber" in html and "bm_george" in html),
    "Humor e conversa reforçados no prompt": (
        "Inteligência de conversa" in app
        and "fontes primárias" in app
        and "com opinião própria" in app),
    "Respostas não são curtas por padrão": (
        "store.get('curtas', '0')" in app and "store.get('curtas', '1')" not in app),
    "Comando falado tem tempo para terminar a frase": (
        "EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 1800L" in plugin),
    "Mudança registrada no CHANGELOG": "## 1.8.0" in historico,
    "Versão do app, do pacote e do projeto batem entre si": (
        f"VERSAO_APP = '{versao.get('version')}'" in app
        and versao.get("version") == pacote.get("version")),
}

falhas = [nome for nome, ok in checagens.items() if not ok]
for nome, ok in checagens.items():
    if ok:
        print("OK:", nome)
if falhas:
    print("\nFALHA:", "; ".join(falhas))
    raise SystemExit(1)
print("%d verificações da 1.8.0 aprovadas." % len(checagens))
