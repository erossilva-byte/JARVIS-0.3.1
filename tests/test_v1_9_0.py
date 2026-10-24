"""Verificações estáticas da 1.9.0: voz neural offline (sherpa-onnx).

Não executa Android: confere que o plugin nativo, o catálogo de vozes, as dependências
de build, a interface e o caminho de fala estão ligados de ponta a ponta. O que depende
do aparelho (download, síntese, áudio) é verificado pelos testes descritos no LEIA-ME.
"""
import json
import pathlib
import re

raiz = pathlib.Path(__file__).resolve().parent.parent
plugin = (raiz / "JarvisVozPlugin.java").read_text(encoding="utf-8")
atividade = (raiz / "MainActivity.java").read_text(encoding="utf-8")
gradle = (raiz / "patch_gradle.py").read_text(encoding="utf-8")
baixar = (raiz / "baixar_sherpa.py").read_text(encoding="utf-8")
app = (raiz / "app.js").read_text(encoding="utf-8")
html = (raiz / "index.html").read_text(encoding="utf-8")
estilo = (raiz / "style.css").read_text(encoding="utf-8")
build_wf = (raiz / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")
release_wf = (raiz / ".github/workflows/release-apk.yml").read_text(encoding="utf-8")
historico = (raiz / "CHANGELOG.md").read_text(encoding="utf-8")
versao = json.loads((raiz / "VERSAO.json").read_text(encoding="utf-8"))
pacote = json.loads((raiz / "package.json").read_text(encoding="utf-8"))

urls = re.findall(r'BASE \+ "([^"]+)"', plugin)
nomes_modelo = re.findall(r'new Voz\(\s*"([a-z]+)"', plugin)

checagens = {
    "Plugin de voz registrado na atividade principal": (
        "registerPlugin(JarvisVozPlugin.class);" in atividade),
    "Plugin expõe o nome usado pelo JavaScript": '@CapacitorPlugin(name = "JarvisVoz")' in plugin,
    "JavaScript busca o mesmo nome de plugin": "plug('JarvisVoz')" in app,
    "Catálogo tem as três vozes (Cadu, Faber e Kokoro)": (
        sorted(nomes_modelo) == ["cadu", "faber", "kokoro"]),
    "Todas as vozes vêm dos pacotes oficiais do sherpa-onnx": (
        len(urls) == 3
        and all(u.startswith("/tts-models/vits-piper-pt_BR-") or u.startswith("/tts-models/kokoro-int8-") for u in urls)
        and all(u.endswith(".tar.bz2") for u in urls)),
    "Download usa HTTPS com tempo limite e recusa resposta que não seja 200": (
        "https://github.com/k2-fsa/sherpa-onnx/releases/download" in plugin
        and "setConnectTimeout" in plugin
        and "setReadTimeout" in plugin
        and "HTTP_OK" in plugin),
    "Extração recusa caminho que escaparia da pasta da voz": (
        'nome.contains("..")' in plugin and "getCanonicalPath().startsWith(prefixo)" in plugin),
    "Motor é aberto por caminho de arquivo (AssetManager nulo)": (
        "new OfflineTts((android.content.res.AssetManager) null, cfg)" in plugin),
    "espeak-ng-data é passado ao motor (sem isso Piper/Kokoro não fonetizam)": (
        'new File(dir, "espeak-ng-data")' in plugin and "setDataDir(dataDir)" in plugin),
    "Kokoro usa o idioma que o pacote realmente tem": (
        'k.setLang("en")' in plugin and 'setLang("en-gb")' not in plugin),
    "Modelos não são embarcados no APK": (
        not list(raiz.rglob("*.onnx")) and not list(raiz.rglob("*.tar.bz2"))),
    "AAR é baixado no build e conferido por SHA-256": (
        'VERSAO = "1.13.8"' in baixar
        and 'NOME = f"sherpa-onnx-{VERSAO}.aar"' in baixar
        and re.search(r'SHA256 = "[0-9a-f]{64}"', baixar) is not None
        and "hashlib.sha256" in baixar
        and "raise SystemExit" in baixar),
    "Gradle aponta para o AAR baixado": (
        "implementation files('libs/sherpa-onnx-1.13.8.aar')" in gradle),
    "Descompactação de .tar.bz2 declarada (commons-compress)": (
        "org.apache.commons:commons-compress:1.26.2" in gradle
        and "BZip2CompressorInputStream" in plugin
        and "TarArchiveInputStream" in plugin),
    "ABIs limitadas a ARM para não inchar o APK": (
        "abiFilters 'arm64-v8a', 'armeabi-v7a'" in gradle),
    "Os dois workflows baixam o AAR antes de compilar": (
        "baixar_sherpa.py android/app" in build_wf
        and "baixar_sherpa.py android/app" in release_wf),
    "Workflows exigem o plugin de voz no código nativo": (
        "JarvisVozPlugin.java" in build_wf and "JarvisVozPlugin.java" in release_wf),
    "Fala tenta a voz neural antes do TTS do Android": (
        "const neural = neuralAtiva();" in app
        and app.index("const neural = neuralAtiva();") < app.index("if (TTSN()) {", app.index("async function falar("))),
    "Botão Parar também interrompe a voz neural": "  neuralParar();" in app,
    "Interface tem a lista, o seletor, o tom e o teste": all(
        f'id="{i}"' in html for i in (
            "c-neural-lista", "c-neural-voz", "c-neural-falante",
            "c-neural-tom", "c-neural-testar", "c-neural-parar", "c-neural-liberar")),
    "Estado inicial é desligado (não baixa nada sozinho)": (
        "store.get(NEURAL_KEY, '')" in app
        and "sel.appendChild(desligada)" in app),
    "Tom padrão é mais grave que o neutro": (
        'store.get(NEURAL_TOM_KEY, \'0.9\')' in app
        and 'value="0.9"' in html),
    "Estilos da lista de vozes existem": (
        ".neural-item" in estilo and ".neural-barra" in estilo),
    "Versão 1.9.0 e versionCode 1900": (
        versao.get("version") == "1.9.0" and versao.get("versionCode") == 1900
        and pacote.get("version") == "1.9.0"),
    "Mudança registrada no CHANGELOG": "## 1.9.0" in historico,
}

falhas = [nome for nome, ok in checagens.items() if not ok]
for nome, ok in checagens.items():
    if ok:
        print("OK:", nome)
if falhas:
    print("\nFALHA:", "; ".join(falhas))
    raise SystemExit(1)
print("%d verificações da 1.9.0 aprovadas." % len(checagens))
