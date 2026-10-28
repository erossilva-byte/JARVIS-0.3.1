"""Verificações da 1.12.0 — núcleo Hermes, briefing diário, autodiagnóstico e abertura por voz.

Nada aqui é opinião: cada item confere no código a peça que faz a função existir, para uma
revisão futura não desfazer sem perceber o que a versão entrega.
"""
from pathlib import Path
import json
import sys

raiz = Path(__file__).resolve().parents[1]
hermes = (raiz / "hermes.js").read_text(encoding="utf-8")
app = (raiz / "app.js").read_text(encoding="utf-8")
html = (raiz / "index.html").read_text(encoding="utf-8")
css = (raiz / "style.css").read_text(encoding="utf-8")
workflow = (raiz / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")
historico = (raiz / "CHANGELOG.md").read_text(encoding="utf-8")
leituras = (raiz / "LEIA-ME.md").read_text(encoding="utf-8")
versao = json.loads((raiz / "VERSAO.json").read_text(encoding="utf-8"))
pacote = json.loads((raiz / "package.json").read_text(encoding="utf-8"))
gradle = raiz / "android/app/build.gradle"
gradle = gradle.read_text(encoding="utf-8") if gradle.exists() else ""

checagens = {
    # 1. Núcleo Hermes
    "Núcleo Hermes com instalação de capacidades": (
        "Hermes.instalar" in hermes
        and "async despachar(texto, opcoes)" in hermes
        and "planejar(texto)" in hermes),
    "Decisão da IA é validada antes de virar ação": (
        "function validarDecisao(obj, ctx)" in hermes
        and "acao-invalida" in hermes
        and "Hermes.validarDecisao(lerJson(raw)" in app),
    "Rotas em ordem: habilidade, aparelho e IA": (
        "rota: 'local'" in hermes
        and "return { rota: 'ia', tratado: false" in hermes
        and "await Hermes.despachar(texto)" in app),
    "Telemetria por rota disponível ao diagnóstico": (
        "metricas()" in hermes
        and "relatorio()" in hermes
        and "Hermes.metricas()" in app),
    "Habilidades próprias: saudação, diagnóstico e núcleo": (
        "id: 'saudacao'" in hermes
        and "id: 'diagnostico'" in hermes
        and "id: 'nucleo'" in hermes),
    "Habilidades rodam offline, sem tocar no DOM": (
        "window.document" not in hermes and "document." not in hermes),

    # 2. Briefing diário
    "Briefing diário com clima e notícias em paralelo": (
        "briefing_dia" in hermes
        and "Promise.allSettled" in hermes
        and "Nas notícias de agora" in hermes),
    "Briefing depende de clima e notícias do aplicativo": (
        "clima: (dia) => clima(dia)" in app
        and "noticias: noticiasDeHoje" in app
        and "async function noticiasDeHoje()" in app),
    "Briefing não repete no mesmo dia e respeita o modo offline": (
        "cap.ler('briefing_auto', '1') === '1'" in hermes
        and "cap.gravar('briefing_dia', hoje)" in hermes
        and "cap.offline()" in hermes),

    # 3. Autodiagnóstico
    "Autodiagnóstico cobre voz, síntese, IA local, rede e permissão": (
        "'Reconhecimento de voz'" in app
        and "'Síntese de voz'" in app
        and "'IA local no aparelho'" in app
        and "'Permissão de microfone (Android)'" in app
        and "'Conexão e CORS'" in app),
    "Diagnóstico devolve itens e resumo falado do núcleo": (
        "return { itens, resumo: Hermes.resumoDiagnostico(itens" in app
        and "function resumoDiagnostico(itens, opcoes)" in hermes
        and "diagnosticoSistema: diagnosticoSistemaFalado" in app),
    "Diagnóstico da escuta continua no seu próprio comando": (
        "RX_DIAG_ESPECIFICO" in hermes
        and "(?:diagnostico|verificar|checar) (?:do |da |de )?(?:segundo plano|escuta|ativacao por voz)" in app),

    # 4. Abertura e animações
    "Abertura com animação e etapas na tela": (
        'id="boot"' in html
        and 'id="boot-status"' in html
        and 'id="boot-barra"' in html
        and 'id="boot-preenche"' in html
        and "async function iniciarSequenciaBoot()" in app),
    "Reconhecimento de voz conclui a animação e libera o app": (
        "async function esperarVozNaAbertura()" in app
        and "async function conferirPerfilAgora()" in app
        and "confirmarVozDoUsuario({\n      falado: false" in app
        and "document.body.classList.add('travado')" in app
        and "function liberarApp()" in app),
    "Sem perfil (ou reconhecimento desligado) roda só a animação inicial": (
        "if (conferir) return esperarVozNaAbertura();" in app
        and "return finalizarBoot('Sistemas prontos, ' + trat() + '.')" in app),
    "Abertura nunca prende o usuário": (
        'id="boot-pular"' in html
        and "btnBootPular.onclick" in app
        and "Date.now() + 25000" in app
        and "abertura: limite de 45 s atingido" in app
        and "abertura: ' + (e && e.message ? e.message : e)" in app),
    "Comando por voz libera a tela na hora": "liberarApp();                       // o comando por voz tem prioridade" in app,
    "Interface travada enquanto a abertura roda": (
        ".boot{" in css and "body.travado header" in css and ".boot.saindo{opacity:0" in css),
    "Animações novas respeitam quem pediu menos movimento": (
        "@keyframes bnGira" in css
        and css.count("prefers-reduced-motion") >= 8
        and ".bn1,.bn2,.bn3,.bn-nucleo,.boot-voz{animation:none!important}" in css),
    "Camadas do HUD compostas na GPU": (
        ".hud{transform:translateZ(0);will-change:transform}" in css),

    # 5. Personalidade e humor no núcleo
    "Tom do turno é do núcleo e continua alimentando o prompt": (
        "function tomDoTurno(texto) { return Hermes.tom(texto); }" in app
        and "tom(texto) {" in hermes
        and "const tom = tomDoTurno(perguntaAtual);" in app),
    "Frases próprias novas passam pelo mesmo portão de humor": (
        "respostaVazia:" in app and "briefingFecho:" in app and "saudacaoCurta:" in app
        and "frase: (chave, vars) => fraseApp(chave, vars)" in app),

    # 6. Empacotamento e suíte
    "hermes.js é carregado antes de app.js": (
        '<script src="hermes.js"></script>' in html
        and html.index('hermes.js') < html.index('<script src="app.js"></script>')),
    "hermes.js entra na cópia da web (build e release) e no pacote do desktop": (
        (raiz / ".github/workflows/build-apk.yml").read_text(encoding="utf-8").count(
            "cp index.html style.css app.js apps.js hermes.js plataforma.js memoria.js orbita.js cad.js www/") == 1
        and (raiz / ".github/workflows/release-apk.yml").read_text(encoding="utf-8").count(
            "cp index.html style.css app.js apps.js hermes.js plataforma.js memoria.js orbita.js cad.js www/") == 1
        and "hermes.js" in pacote.get("build", {}).get("files", [])),
    "Suíte roda o teste do núcleo": (
        "node tests/test_hermes.js" in pacote.get("scripts", {}).get("test:all", "")
        and "python3 tests/test_v1_12_0.py" in pacote.get("scripts", {}).get("test:all", "")),

    # 7. Versão e documentação
    # A versão publicada avança: o teste confere que a revisão 1.12.0 continua dentro do
    # pacote atual (>= 1.12.0) e que número e nome acompanham o VERSAO.json, em vez de fixar
    # um literal que envelhece a cada release.
    "Versão publicada é igual ou posterior à 1.12.0": (
        str(versao.get("version", "")) >= "1.12.0"
        and int(versao.get("versionCode", 0)) >= 10120
        and pacote.get("version") == versao.get("version")
        and ("const VERSAO_APP = '%s';" % versao.get("version")) in app
        and (not gradle or ("versionCode %d" % int(versao.get("versionCode")) in gradle
                            and 'versionName "%s"' % versao.get("version") in gradle))),
    "Versão na interface acompanha o release": (
        ('<span class="orb-sub" aria-hidden="true">v%s</span>' % versao.get("version")) in html
        and ('<span class="versao-chip">v%s</span>' % versao.get("version")) in html),
    "Mudança registrada no CHANGELOG": "## 1.12.0" in historico,
    "Instruções atualizadas no LEIA-ME": (
        ("# J.A.R.V.I.S. Nova %s" % versao.get("version")) in leituras
        and "1.11.0" in leituras       # histórico preservado
        and "assinatura" in leituras.lower()),
}

falhas = [nome for nome, ok in checagens.items() if not ok]
for nome, ok in checagens.items():
    print(("OK: " if ok else "FALHA: ") + nome)
if falhas:
    print("\n%d verificação(ões) da revisão 1.12 falharam." % len(falhas))
    sys.exit(1)
print("\n%d verificações da revisão 1.12 aprovadas." % len(checagens))
