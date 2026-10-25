"""Verificações estáticas das correções de segundo plano da 1.10.1.

Cada checagem corresponde a um defeito real encontrado na revisão: serviço de mídia
sem primeiro plano, alarme do vigia sobrescrito, escuta presa em "espera" depois de
o app ser fechado, falha que deixava o serviço em primeiro plano para sempre,
lembretes que não voltavam depois de reiniciar e estado nativo/interface divergindo.
"""
import json
import pathlib

raiz = pathlib.Path(__file__).resolve().parent.parent
app = (raiz / "app.js").read_text(encoding="utf-8")
musica = (raiz / "JarvisMusicaService.java").read_text(encoding="utf-8")
servico = (raiz / "JarvisService.java").read_text(encoding="utf-8")
vigia = (raiz / "JarvisWatchdog.java").read_text(encoding="utf-8")
alarmes = (raiz / "JarvisAlarmScheduler.java").read_text(encoding="utf-8")
plugin = (raiz / "JarvisBackgroundPlugin.java").read_text(encoding="utf-8")
historico = (raiz / "CHANGELOG.md").read_text(encoding="utf-8")
versao = json.loads((raiz / "VERSAO.json").read_text(encoding="utf-8"))
pacote = json.loads((raiz / "package.json").read_text(encoding="utf-8"))

trecho_task_removed = servico[servico.index("public void onTaskRemoved"):]
trecho_task_removed = trecho_task_removed[:trecho_task_removed.index("super.onTaskRemoved")]
trecho_parar_falha = servico[servico.index("private void pararPorFalha"):]
trecho_parar_falha = trecho_parar_falha[:trecho_parar_falha.index("private void disparar")]

checagens = {
    "Comando de mídia promove o serviço a primeiro plano antes de controlar": (
        "iniciarPrimeiroPlano();\n                String c = intent.getStringExtra(EXTRA_COMANDO);" in musica),
    "Comando de mídia sem player encerra o serviço (nada para controlar)": (
        "if (player == null) {" in musica.split("ACAO_CONTROLE.equals(acao)")[1][:600]
        and "pararTudo();\n                    return START_NOT_STICKY;" in musica),
    "Reinício sem comando não fica sem notificação nem áudio": (
        "// Encerra em vez de ficar sem notificação nem áudio." in musica
        and "pararTudo();\n                return START_NOT_STICKY;" in musica),

    "Vigia tem alarme rápido separado do periódico": (
        "ID_RAPIDO = 90211" in vigia
        and "static void agendarRapido(Context c, long emMs)" in vigia
        and "agendarCom(c, emMs, ID_RAPIDO)" in vigia),
    "Cancelar o vigia cancela os dois alarmes": (
        "cancelarCom(c, ID);" in vigia and "cancelarCom(c, ID_RAPIDO);" in vigia),
    "Serviço destruído pede recuperação rápida": (
        "JarvisWatchdog.agendarRapido(this, 20000L)" in servico),
    "App fechado retoma a escuta pausada em vez de ficar em espera": (
        "pausadoPelaInterface = false;" in trecho_task_removed
        and "iniciarEscutaInterna();" in trecho_task_removed
        and "JarvisWatchdog.agendarRapido(this, 8000L)" in trecho_task_removed),
    "Falha fatal não deixa primeiro plano preso para sempre": (
        "}, 120000L);" in trecho_parar_falha and "stopSelf();" in trecho_parar_falha),

    "Restauração de alarmes não depende de canScheduleExactAlarms": (
        "am.canScheduleExactAlarms()" not in alarmes
        and "setAlarmClock" in alarmes),

    "Serviço que não sobe desfaz o pedido nativo": (
        "JarvisPrefs.desejaOuvir(getContext(), false);" in plugin
        and "JarvisWatchdog.cancelar(getContext());" in plugin),

    "Falha só do serviço em primeiro plano não desliga a ativação": (
        "let servicoPronto = false;" in app
        and "if (!servicoPronto) {" in app
        and "A ativação continua ligada e eu tento de novo quando você voltar ao app." in app),
    "Evento 'parou' pendente também desliga a preferência de escuta": (
        "if (chkWakeEv) chkWakeEv.checked = false;" in app
        and "store.set('wake', '0');\n          const chkWakeEv" in app),

    "Versão 1.10.1 e versionCode 10101": (
        versao.get("version") == "1.10.1"
        and versao.get("versionCode") == 10101
        and pacote.get("version") == "1.10.1"
        and "const VERSAO_APP = '1.10.1';" in app),
    "Correções registradas no CHANGELOG": "## 1.10.1" in historico,
}

falhas = [nome for nome, ok in checagens.items() if not ok]
for nome, ok in checagens.items():
    if ok:
        print("OK:", nome)
if falhas:
    print("\nFALHA:", "; ".join(falhas))
    raise SystemExit(1)
print("%d verificações da 1.10.1 aprovadas." % len(checagens))
