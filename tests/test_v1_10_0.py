"""Verificações estáticas da 1.10.0.

Não executa Android: confere no código-fonte que cada requisito desta versão está
realmente implementado — personalidade num ponto só, aviso falado da análise de voz,
ligação completada, música que toca o arquivo do aparelho, economia em segundo plano e
rede de segurança contra exceções.
"""
import json
import pathlib
import re

raiz = pathlib.Path(__file__).resolve().parent.parent
app = (raiz / "app.js").read_text(encoding="utf-8")
html = (raiz / "index.html").read_text(encoding="utf-8")
historico = (raiz / "CHANGELOG.md").read_text(encoding="utf-8")
leituras = (raiz / "LEIA-ME.md").read_text(encoding="utf-8")
util = (raiz / "JarvisUtilPlugin.java").read_text(encoding="utf-8")
servico = (raiz / "JarvisMusicaService.java").read_text(encoding="utf-8")
plugin = (raiz / "JarvisMusicaPlugin.java").read_text(encoding="utf-8")
manifesto = (raiz / "patch_manifest.py").read_text(encoding="utf-8")
main = (raiz / "MainActivity.java").read_text(encoding="utf-8")
prefs = (raiz / "JarvisPrefs.java").read_text(encoding="utf-8")
boot = (raiz / "JarvisBootReceiver.java").read_text(encoding="utf-8")
ia_local = (raiz / "JarvisLocalAIPlugin.java").read_text(encoding="utf-8")
# O android/ é gerado por `npx cap add android` (fica fora do repositório); no CI a
# pasta ainda não existe quando os testes rodam, então o build.gradle é opcional aqui.
_gradle = raiz / "android" / "app" / "build.gradle"
gradle = _gradle.read_text(encoding="utf-8") if _gradle.exists() else ""
versao = json.loads((raiz / "VERSAO.json").read_text(encoding="utf-8"))
pacote = json.loads((raiz / "package.json").read_text(encoding="utf-8"))

# Bloco do prompt de sistema, para não confundir com o resto do arquivo.
inicio = app.find("function promptSistema()")
prompt = app[inicio:app.find("\n}\n", inicio)] if inicio > 0 else ""

checagens = {
    # 1. Personalidade centralizada
    "Personalidade vive num único objeto (PERSONALIDADE)": (
        "const PERSONALIDADE = {" in app
        and all(campo in app.split("const PERSONALIDADE")[1].split("};")[0]
                for campo in ("identidade", "personalidade", "lealdade", "tratamento", "humor", "limites"))),
    "Prompt de sistema é montado a partir de PERSONALIDADE": (
        "${PERSONALIDADE.personalidade}" in prompt
        and "${PERSONALIDADE.lealdade}" in prompt
        and "${PERSONALIDADE.tratamento.replace('{tratamento}', t)}" in prompt
        and "${PERSONALIDADE.humor}" in prompt),
    "Tratamento ao usuário vem de PERSONALIDADE, sem duplicar no prompt": (
        prompt.count('Chame o usuário de') == 0
        and app.count('Chame o usuário de') == 1),
    "Personalidade é formal, espirituosa e leal": (
        "formal, espirituosa e leal" in app),
    # 2. Inteligência preservada
    "Regras de conversa e pesquisa continuam no prompt": (
        "Inteligência de conversa" in prompt
        and "fontes primárias" in prompt
        and "com opinião própria" in prompt),

    # 3. Palavra de ativação intacta (a personalidade não mexe nela)
    "Detector de ativação é o próprio (reconhecimento + fonética local)": (
        "JarvisAtivacao.presente" in (raiz / "JarvisService.java").read_text(encoding="utf-8")
        and "Hermes.ativacao.casaToken" in app
        and "startWake(" in app),

    # 4. Verificação de voz, falada e uma vez por sessão
    # 1.12.0: na ativação a fala continua igual; o indicador usa "avisar", que na abertura
    # é a própria animação e na ativação por voz é o mostrarWakeMini de sempre.
    "Assistente fala em voz alta que está analisando a voz": (
        "await falar('Analisando sua voz, ' + nomeV + '. Um instante.', false);" in app
        and "avisar('Analisando sua voz, ' + nomeV" in app
        and "const avisar = o.aoProgresso || mostrarWakeMini;" in app),
    "Gravação acontece depois da fala (evita captar a própria voz)": (
        app.find("await falar('Analisando sua voz") < app.find("const v = await capturarVetorVoz();")),
    "Verificação é exigida uma vez por sessão e liberada na confirmação": (
        "wake_perfil_sessao" in app
        and "store.set('wake_perfil_sessao', token)" in app
        and "tokenSessaoVoz" in app),
    "Token de sessão muda a cada reinício do aparelho": (
        "static void novaSessao(Context c)" in prefs
        and "JarvisPrefs.novaSessao(ctx)" in boot
        and "public void sessaoVoz(PluginCall call)" in util),
    "Usuário escolhe entre por sessão e em toda ativação": (
        'id="c-wake-perfil-modo"' in html
        and "wake_perfil_modo" in app),

    # 5. Comandos completos
    "Ligação usa ACTION_CALL com permissão de telefone": (
        'new Intent(Intent.ACTION_CALL, Uri.fromParts("tel", numero, null))' in util
        and 'alias = "ligacoes"' in util
        and "Manifest.permission.CALL_PHONE" in util),
    "Permissão de telefone é declarada no manifesto": (
        '"android.permission.CALL_PHONE"' in manifesto),
    "Se o Android negar, cai no discador avisando": (
        'new Intent(Intent.ACTION_DIAL' in util
        and 'o.put("discador", true)' in util
        and "toque em chamar" in app.lower()),
    "Ação de ligar não se limita a abrir o discador": (
        "await nativo('ligar', { numero: a.numero })" in app
        and "url: 'tel:' + a.numero" not in app),
    "Música toca o arquivo do aparelho (MediaStore + MediaPlayer)": (
        "MediaStore.Audio.Media.EXTERNAL_CONTENT_URI" in plugin
        and "prepareAsync()" in servico
        and ".start()" in servico),
    "Player roda em serviço de primeiro plano com MediaSession": (
        'new MediaSession(this, "JarvisMusica")' in servico
        and "FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK" in servico
        and "startForeground(" in servico),
    "Serviço e plugin são registrados": (
        'registerPlugin(JarvisMusicaPlugin.class);' in main
        and '.JarvisMusicaService' in manifesto
        and 'foregroundServiceType="mediaPlayback"' in manifesto),
    "Busca ignora acento, pontuação e ordem das palavras": (
        "Normalizer.normalize" in plugin
        and "static int pontuar" in plugin),
    "Comando de voz tira o “a música” e toca de fato": (
        "const alvoMusica = (t) =>" in app
        and "ACOES.tocar_musica.run({ busca: alvo })" in app),
    "Controle de mídia obedece o player do próprio app": (
        "const st = await M.estado();" in app
        and "if (st && st.ativo) {" in app
        and "verboLocal" in app),

    # 6/7. Estabilidade e IA local
    "Exceções da interface viram aviso, não fechamento": (
        "function registrarFalhaJS" in app
        and "window.addEventListener('error'" in app
        and "window.addEventListener('unhandledrejection'" in app),
    "IA local confere memória antes de carregar o modelo": (
        "private void checarMemoria(File modelo)" in ia_local
        and "checarMemoria(f);" in ia_local),
    "IA local não derruba o app em falha de inferência": (
        "catch (Throwable e)" in ia_local
        and "closeEngineLocked();" in ia_local),

    # 8. Economia em segundo plano
    "Reconhecimento do WebView para quando o app sai da tela": (
        "reconhecimento pausado: app em segundo plano" in app
        and "if (recAtual && recAtual.state !== 'inactive') { recAtual.stop();" in app),

    # 9. Versão e documentação
    # A linha 1.10 continua válida para as versões seguintes; o número exato da versão
    # publicada é conferido pelo teste daquela versão (test_v1_12_0.py e seguintes).
    "Versão a partir da 1.10 com versionCode >= 10100": (
        re.match(r"^1\.(1[0-9]|[2-9][0-9])\.", str(versao.get("version", "")))
        and versao.get("versionCode", 0) >= 10100
        and pacote.get("version") == versao.get("version")
        and "const VERSAO_APP = '" + str(versao.get("version")) + "';" in app
        and (not gradle or ('versionCode %d' % versao.get('versionCode', 0) in gradle
                             and 'versionName "%s"' % versao.get('version') in gradle))),
    "Mudança registrada no CHANGELOG": "## 1.10.0" in historico,
    "Instruções de instalação e assinatura no LEIA-ME": (
        "1.10.0" in leituras and "assinatura" in leituras.lower()),
}

falhas = [nome for nome, ok in checagens.items() if not ok]
for nome, ok in checagens.items():
    if ok:
        print("OK:", nome)
if falhas:
    print("\nFALHA:", "; ".join(falhas))
    raise SystemExit(1)
print("%d verificações da 1.10.0 aprovadas." % len(checagens))
