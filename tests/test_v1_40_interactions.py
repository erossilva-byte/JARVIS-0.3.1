"""Regressão 1.40: áreas, ações de toque, histórico secundário e navegação."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
html = (ROOT / "index.html").read_text(encoding="utf-8")
app = (ROOT / "app.js").read_text(encoding="utf-8")
interface = (ROOT / "interface.js").read_text(encoding="utf-8")
css = (ROOT / "style.css").read_text(encoding="utf-8") + (ROOT / "core.css").read_text(encoding="utf-8")
workflow = (ROOT / ".github/workflows/auditoria-android-windows.yml").read_text(encoding="utf-8")
package = json.loads((ROOT / "package.json").read_text(encoding="utf-8"))
emulator_step = re.search(
    r"- name: Inicializar emulador e testar instalação, abertura e estabilidade\s+uses: reactivecircus/android-emulator-runner@v2\s+timeout-minutes:\s*(\d+)",
    workflow,
)

install_timeout = re.search(r"timeout\s+(\d+)s\s+adb install -r", workflow)

checks = {
    "splash já visível no primeiro quadro": '<div id="boot" class="boot">' in html and '<div id="boot" class="boot" hidden>' not in html,
    "menu principal oculto durante a inicialização": '<body data-state="idle" class="travado">' in html and "visibility:hidden;pointer-events:none;opacity:0" in css,
    "bloqueio é verificado antes de esconder o splash": (lambda start: app.find("try { iniciarBloqueioSeAtivo(); }", start) < app.find("tela.classList.add('saindo')", start))(app.find("function liberarApp()")),
    "opção Conversa removida do cabeçalho": 'id="btn-conversa"' not in html,
    "referência antiga do cartão Conversa removida do JavaScript": "$('#dash-conversa')" not in app,
    "atalho Conversa removido do dashboard": 'id="dash-conversa"' not in html,
    "histórico continua acessível por botão secundário": 'id="btn-historico"' in html and "btnHistorico.onclick = alternarTelaConversa" in app,
    "transcrição e campo de comando preservados": 'id="chat"' in html and 'id="entrada"' in html and 'id="btn-enviar"' in html,
    "resposta resumida aparece junto ao núcleo": 'id="nucleo-resposta"' in html and "$('#nucleo-resposta')" in app,
    "cartões de áreas recebem clique diretamente": "b.addEventListener('click', function () { abrirArea(area.id); });" in interface,
    "ações das áreas recebem clique diretamente": "b.addEventListener('click', function () { acao(a.acao); });" in interface,
    "retorno da área recebe clique diretamente": "voltar.addEventListener('click', function () { abrirArea(''); });" in interface,
    "não depende mais de delegação global para áreas": "doc.addEventListener('click', function (e)" not in interface,
    "painel de áreas tem botão fechar explícito": 'id="areas-fechar"' in html and "fecharAreas.addEventListener('click'" in interface,
    "atalhos de áreas têm retorno visível quando navegação não carregou": "O núcleo de navegação ainda está inicializando" in interface,
    "ações não suportadas não fingem sucesso": "resultado === false" in interface and "return false;" in app,
    "áreas voltam ao índice quando reabertas": "window.JarvisAreas.abrir('')" in app,
    "transcrição fica fora do menu principal": "body:not(.modo-conversa) .chat-area" in css and "body.modo-conversa .dash" in css,
    "botões de área aceitam toque e foco": "touch-action:manipulation" in css and ".area-card:focus-visible" in css,
    "instalação do APK tem timeout compatível com artefato grande": bool(install_timeout) and int(install_timeout.group(1)) >= 180,
    "bloqueio opcional e memória continuam na configuração": 'data-config-tab="memoria"' in html and 'data-category="seguranca"' in html,
    "emulador tem tempo suficiente para iniciar": bool(emulator_step) and int(emulator_step.group(1)) >= 30 and "emulator-boot-timeout: 1800" in workflow,
    "teste de interação incluído na suíte completa": "tests/test_v1_40_interactions.py" in package["scripts"]["test:all"],
}

ids = re.findall('id="([^"]+)"', html)
checks["HTML sem IDs duplicados"] = len(ids) == len(set(ids))

area_actions = set(re.findall("acao: '([^']+)'", interface))
router_start = app.find("function acaoNavegacao(nome)")
router_end = app.find(chr(10) + "}", router_start)
router = app[router_start:router_end + 2] if router_start >= 0 and router_end >= 0 else ""
routes = set(re.findall("case '([^']+)':", router))
checks["todas as ações das áreas têm rota no núcleo"] = bool(area_actions) and area_actions <= routes

for label, ok in checks.items():
    print(("OK: " if ok else "FALHOU: ") + label)
if not all(checks.values()):
    raise SystemExit(1)
print()
print("Interações 1.40: contratos de navegação, toque, histórico e regressão verificados.")
