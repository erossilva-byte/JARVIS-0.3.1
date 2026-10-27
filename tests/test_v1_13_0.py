"""Verificações da 1.13.0 — detector de ativação próprio, roteador de motores, visão e release.

Checagem estática de propósito: o comportamento do núcleo já é exercitado por
tests/test_ativacao.js e tests/test_hermes.js em Node, e o serviço Android só roda em
aparelho. Aqui se confere que as peças existem, que estão ligadas umas nas outras e que
nenhuma referência ao Picovoice sobrou no caminho ativo.
"""
import json
import re
import sys
from pathlib import Path

raiz = Path(__file__).resolve().parents[1]


def ler(nome):
    return (raiz / nome).read_text(encoding="utf-8")


app = ler("app.js")
html = ler("index.html")
css = ler("style.css")
hermes = ler("hermes.js")
servico = ler("JarvisService.java")
ativacao_java = ler("JarvisAtivacao.java")
prefs = ler("JarvisPrefs.java")
plugin = ler("JarvisBackgroundPlugin.java")
patch_gradle = ler("patch_gradle.py")
build_wf = ler(".github/workflows/build-apk.yml")
release_wf = ler(".github/workflows/release-apk.yml")
versao = json.loads(ler("VERSAO.json"))
pacote = json.loads(ler("package.json"))
leituras = ler("LEIA-ME.md") + ler("CHANGELOG.md")
gradle_path = raiz / "android/app/build.gradle"
gradle = gradle_path.read_text(encoding="utf-8") if gradle_path.exists() else ""
script_teste = pacote.get("scripts", {}).get("test:all", "")

# Fontes que rodam no aparelho: nenhuma pode citar o detector de terceiro que saiu,
# nem sequer em comentário. Nos comentários de JarvisAtivacao/JarvisPrefs a citação existe
# de propósito, para registrar que o detector de terceiro foi removido.
fontes_ativas = " ".join([app, html, css, hermes, servico, plugin, patch_gradle, ler("main.js")]).lower()

checagens = {
    # 1. Picovoice saiu por completo do caminho ativo
    "Nenhuma referência ativa ao Picovoice/Porcupine/openWakeWord": (
        not re.search(r"(picovoice|porcupine|openwakeword)", fontes_ativas)),
    "Nomes de chave e estado do motor antigo não existem mais": (
        "CHAVE_PICOVOICE" not in app and "NOME_CHAVE_PICOVOICE" not in app
        and "wake_motor" not in app and "motor: store.get" not in app),
    "Gradle sem SDK de palavra de ativação": (
        "picovoice" not in gradle.lower() and "picovoice" not in patch_gradle.lower()),
    "Cofre da AccessKey removido das preferências": (
        "guardarChave" not in prefs and "lerChave" not in prefs and "temChave" not in prefs
        and "AndroidKeyStore" not in prefs),
    "Nomes de chave do desktop sem picovoice": (
        "groq|cerebras|mistral|gemini" in ler("main.js") and "picovoice" not in ler("main.js")),

    # 2. Detector próprio, nos dois lados, com as mesmas regras
    "JarvisAtivacao.java existe e tem as três regras": (
        "class JarvisAtivacao" in ativacao_java
        and "static boolean casaToken" in ativacao_java
        and "static boolean presente" in ativacao_java
        and "static int distancia" in ativacao_java
        and "static String esqueleto" in ativacao_java),
    "Trava do v e do j inicial protegem palavras comuns": (
        "t.indexOf('v') < 0" in ativacao_java and "t.charAt(0) != 'j'" in ativacao_java
        and "indexOf('v') < 0" in hermes and "/^j/.test(t)" in hermes),
    "Serviço confere parcial, todas as hipóteses e ruído": (
        "conferirEmLote" in servico and "onPartialResults" in servico
        and "picoDb" in servico and "cfg.ruidoDb" in servico
        and "JarvisPrefs.rejeitadas(this," in servico),
    "Serviço lê a calibragem salva a cada sessão": (
        "JarvisPrefs.sensibilidade(this)" in servico and "JarvisPrefs.variantes(this)" in servico
        and "iniciarSessao" in servico and "agendarSessao" in servico),
    "Nenhum resto do motor antigo": (
        "motorPedido" not in servico and "JarvisPrefs.motor" not in servico
        and "wake_motor" not in app and "CHAVE_PICOVOICE" not in app),
    "Calibragem trafega da tela para o serviço": (
        "wakeCalibragem" in app and "sensibilidade: " in app
        and 'getInt("sensibilidade"' in plugin and 'getString("variantes"' in plugin),
    "Detector próprio aparece no diagnóstico": (
        "descartesRuido" in plugin and "calibragem" in plugin
        and "porteiro de ruído" in app),

    # 3. Roteador de motores de IA
    "Núcleo tem o roteador com nota por tarefa": (
        "function planejarIA" in hermes and "function tarefaDe" in hermes
        and "rapida:" in hermes and "raciocinio:" in hermes and "visao:" in hermes),
    "Latência medida alimenta o roteador (média móvel)": (
        "function registrarLatencia" in hermes and "0.7" in hermes
        and "Hermes.registrarLatencia" in app),
    "Provedor em pausa e falhas recentes entram na conta": (
        "indisponiveis" in hermes and "errosIA" in app and "erros:" in app),
    "Fila do roteador substitui a ordem fixa": (
        "planoIA.ordem.map" in app and "Hermes.anotarEscolha(planoIA.motivo" in app
        and "registrar('ia', 'roteador · '" in app),
    "Modelo e tempo-limite vêm do roteador": (
        "modelosPreferidos" in app and "timeoutIA" in app
        and "Math.max(8000, Math.min(40000, timeoutIA))" in app),
    "Fallback automático por provedor continua": (
        "falhas.push({ p, r })" in app and "pausar(p, r)" in app
        and "MOTIVO_FALHA" in app),

    # 4. Visão: câmera, um quadro, balões
    "Câmera abre, captura um quadro e para ao fechar": (
        "getUserMedia" in app and "function capturarQuadro" in app
        and "function pararCamera" in app and "pararCamera()" in app),
    "Câmera não fica ligada em segundo plano": (
        "visibilitychange', () => { if (document.hidden) pararCamera(); }" in app
        and "window.addEventListener('pagehide', pararCamera)" in app),
    "Visão usa o roteador e os modelos que enxergam": (
        "function pedirVisaoIA" in app and "tarefa: 'visao'" in app
        and "modelosVisao" in hermes and "meta-llama/llama-4-scout-17b-16e-instruct" in hermes),
    "Balões são desenhados com a caixa normalizada": (
        "function desenharBaloes" in app and "function selecionarObjeto" in app
        and "visao-baloes" in html and ".balao{" in css.replace(" ", "")),
    "Resposta de visão é saneada antes de virar tela": (
        "function normalizarObjetos" in hermes and "Hermes.visao.normalizar" in app
        and "function descreverObjetos" in hermes),
    "Visão é habilidade do núcleo, por voz": (
        "id: 'visao'" in hermes and "analisarVisao" in app
        and "analisarVisao: (o) => analisarVisao(o)" in app and "RX_VISAO" in hermes),
    "Painel de visão completo e navegável": (
        all(t in html for t in ('id="painel-visao"', 'id="visao-video"', 'id="visao-canvas"',
                                'id="visao-baloes"', 'id="visao-status"', 'id="visao-botao-analisar"',
                                'id="visao-botao-nova"', 'id="visao-fechar"', 'data-lat="visao"'))
        and "'#painel-visao'" in app),

    # 5. Área de mensagens e animações
    "Estado de carregamento da conversa": (
        "function msgPensando" in app and "function removerPensando" in app
        and "removerPensando();\n  if (!semMsg)" in app and "msgPensando();" in app),
    "Estilos novos de conversa, balão e indicador de espera": (
        ".msg.pensando" in css.replace(" ", "") and ".pensando-pontos" in css.replace(" ", "")
        and "@keyframes pulsar" in css),
    "Balão da visão e movimento reduzido": (
        ".balao{" in css.replace(" ", "")
        and re.search(r"@media\s*\(prefers-reduced-motion:reduce\)\{[^}]*\.balao", css.replace(" ", ""))
        and "#lateral{overflow-y:auto" in css.replace(" ", "").replace("\n", "")),
    "Rolagem só acompanha quando você já está no fim": (
        "(chat.scrollHeight - chat.scrollTop - chat.clientHeight) < 120" in app),

    # 6. Diagnóstico ampliado
    "Diagnóstico cobre câmera, motores e calibragem": (
        "async function estadoCamera" in app and "'Câmera (visão)'" in app
        and "'Motores de IA (roteador)'" in app and "escolhasIA[0]" in app),
    "Resumo falado do núcleo cita as checagens de verdade": (
        "listar(lista.map((i) => i.nome))" in hermes),

    # 7. Personalidade
    "Humor seco com limites explícitos": (
        "sarcasmo seco" in app and "Nunca rude, nunca ofensivo, nunca humilhante" in app
        and "o humor desaparece por completo" in app and "nunca repete o mesmo comentário" in app),
    "Frases próprias novas passam pelo portão de humor": (
        "visaoSemObjeto" in app and "roteadorTroca" in app
        and "humor >= 40 && !tom.serio && !tom.pressa" in app),

    # 8. Empacotamento e release
    "hermes.js vai para o www nos dois workflows": (
        build_wf.count("cp index.html style.css app.js apps.js hermes.js www/") == 1
        and release_wf.count("cp index.html style.css app.js apps.js hermes.js www/") == 1),
    "JarvisAtivacao.java é exigido no build e no release": (
        "JarvisAtivacao.java" in build_wf and "JarvisAtivacao.java" in release_wf
        and "JarvisAtivacao.java" not in ler(".gitignore")),
    "Suíte roda os testes novos": (
        "node tests/test_ativacao.js" in script_teste
        and "python3 tests/test_ativacao_propria.py" in script_teste
        and "python3 tests/test_java_refs.py" in script_teste
        and "python3 tests/test_v1_13_0.py" in script_teste),
    "Teste do Picovoice foi substituído": not (raiz / "tests/test_porcupine_personality.py").exists(),

    # 9. Versão e documentação
    "Versão a partir da 1.14.0 com versionCode >= 10140": (
        [int(x) for x in str(versao.get("version", "0")).split(".")] >= [1, 14, 0]
        and versao.get("versionCode", 0) >= 10140
        and pacote.get("version") == versao.get("version")
        and ("const VERSAO_APP = '%s';" % versao.get("version")) in app
        and (not gradle or ("versionCode %d" % versao.get("versionCode") in gradle
                            and 'versionName "%s"' % versao.get("version") in gradle))),
    "Versão na interface acompanha o release": (
        ('<span class="orb-sub" aria-hidden="true">v%s</span>' % versao.get("version")) in html
        and ('<span class="versao-chip">v%s</span>' % versao.get("version")) in html),
    "Mudança registrada no CHANGELOG e no LEIA-ME": (
        "## 1.14.0" in leituras and ("# J.A.R.V.I.S. Nova %s" % versao.get("version")) in leituras
        and "1.13.0" in leituras),
    "Núcleo Hermes e detector próprios se identificam por versão": (
        "const VERSAO = '1.2.0'" in hermes and 'VERSAO = "1.1.0"' in ativacao_java),
    "Notas da versão descrevem o que a versão publicada entregou": (
        "## 1.13.0" in leituras
        and all(t in versao.get("notas", "") for t in ("Groq", "Informações", "Conversa"))),
}

falhas = [nome for nome, ok in checagens.items() if not ok]
for nome, ok in checagens.items():
    print(("OK: " if ok else "FALHA: ") + nome)
if falhas:
    print("\n%d verificação(ões) da 1.13.0 falharam." % len(falhas))
    sys.exit(1)
print("\n%d verificações da 1.13.0 aprovadas." % len(checagens))
