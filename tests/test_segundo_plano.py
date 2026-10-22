"""Regressão estática da 1.6.0: escuta persistente, vigia, diagnóstico, teste e lembretes."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
app = (ROOT / "app.js").read_text(encoding="utf-8")
html = (ROOT / "index.html").read_text(encoding="utf-8")
prefs = (ROOT / "JarvisPrefs.java").read_text(encoding="utf-8")
servico = (ROOT / "JarvisService.java").read_text(encoding="utf-8")
vigia = (ROOT / "JarvisWatchdog.java").read_text(encoding="utf-8")
boot = (ROOT / "JarvisBootReceiver.java").read_text(encoding="utf-8")
plugin = (ROOT / "JarvisBackgroundPlugin.java").read_text(encoding="utf-8")
ouvir = (ROOT / "JarvisOuvirReceiver.java").read_text(encoding="utf-8")
manifesto = (ROOT / "patch_manifest.py").read_text(encoding="utf-8")
workflow = (ROOT / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")
css = (ROOT / "style.css").read_text(encoding="utf-8")

checks = {
    # ---- Estado persistente e segredo ----
    "Estado desejado persistido fora do WebView": "desejaOuvir" in prefs and "MODE_PRIVATE" in prefs,
    "AccessKey cifrada no Keystore": (
        "AndroidKeyStore" in prefs and "AES/GCM/NoPadding" in prefs and "PREFIXO" in prefs),
    "Chave não é gravada em texto puro": "sp(c).edit().remove(\"chave\")" in prefs and "cifrar(limpa)" in prefs,
    "Serviço restaura a chave salva": "JarvisPrefs.lerChave(this)" in servico,
    # ---- Serviço ----
    "Serviço é START_STICKY quando ouve": "return START_STICKY;" in servico,
    "Reinício sem intent retoma o estado salvo": (
        "if (acao == null) {" in servico and "JarvisPrefs.desejaOuvir(this)" in servico),
    "Saída dos recentes agenda reinício": "onTaskRemoved" in servico and "JarvisWatchdog.agendar(this, 8000L)" in servico,
    "Rearme quando a tela não responde": "agendarRearmeSeTelaNaoResponder" in servico and "9000" in servico,
    "Modo teste sem abrir o app": "testeAtivoInterno" in servico and "testeDeteccoes" in servico,
    "Notificação com Ouvir agora e Parar": (
        '"Ouvir agora"' in servico and '"Parar"' in servico and "JarvisOuvirReceiver" in servico),
    "Pausa da interface não desliga o estado desejado": (
        "pausadoPelaInterface" in servico and "static void pausarEscuta()" in servico),
    "Desligar cancela o vigia": "static void desligar(Context ctx)" in servico and "JarvisWatchdog.cancelar(ctx)" in servico,
    # ---- Vigia ----
    "Vigia usa alarme com isenção de idle": (
        "setAndAllowWhileIdle" in vigia and "INTERVALO" in vigia and "VERIFICAR_ESCUTA" in vigia),
    "Vigia reinicia somente se o usuário quer": "if (!JarvisPrefs.desejaOuvir(ctx))" in vigia,
    "Boot reagenda a escuta sem iniciar FGS direto": (
        "JarvisWatchdog.agendar(ctx, 20000L)" in boot and "startForegroundService" not in boot),
    # ---- Plugin e manifesto ----
    "Plugin expõe diagnóstico real": all(t in plugin for t in (
        "diagnosticoEscuta", "isIgnoringBatteryOptimizations", "canDrawOverlays",
        "enabled_notification_listeners", "areNotificationsEnabled")),
    "Plugin abre autostart por fabricante": (
        "abrirAutostart" in plugin and "AutoStartManagementActivity" in plugin and "ACTION_APPLICATION_DETAILS_SETTINGS" in plugin),
    "Plugin expõe teste e desligamento": all(t in plugin for t in (
        "iniciarTesteEscuta", "statusTesteEscuta", "pararTesteEscuta", "desligarEscuta", "consumirPedidoOuvir")),
    "Receptor do botão Ouvir agora": "JarvisOuvirReceiver" in manifesto and "pedidoOuvir" in ouvir,
    "Manifesto registra vigia e receptor": (".JarvisWatchdog" in manifesto and "VERIFICAR_ESCUTA" in manifesto
                                            and ".JarvisOuvirReceiver" in manifesto),
    # ---- Interface ----
    "Cartão de diagnóstico na aba Voz": (
        'id="bg-diag"' in html and 'id="bg-atualizar"' in html and 'id="bg-autostart"' in html),
    "Teste de ativação na interface": 'id="c-wake-teste"' in html and "testarEscutaAtivacao" in app,
    "Diagnóstico classifica pendências": (
        "function diagnosticoSegundoPlano" in app and "pendencias.push" in app and "bgDiagRow" in app),
    "Desligar a escuta encerra serviço": "pararWake(true)" in app,
    "Checkbox redundante de serviço removido": 'id="c-segplano"' not in html and "c-segplano" not in app,
    "Comando de voz do diagnóstico": "diagnostico|verificar|checar" in app and "por que" in app,
    "Estilo do cartão de diagnóstico": ".diag-card" in css and ".diag-row>div" in css,
    # ---- Lembretes de tarefas ----
    "Lembrete de tarefa no dia do prazo": (
        "function agendarAvisoTarefa" in app and "function idAvisoTarefa" in app and "'T09:00:00'" in app),
    "Concluir/excluir cancela o lembrete": (
        "cancelarAvisoTarefa(x)" in app and "cancelarAvisoTarefa(t)" in app),
    # ---- Build ----
    "Workflow copia as novas classes nativas": all(f in workflow for f in (
        "JarvisPrefs.java", "JarvisWatchdog.java", "JarvisOuvirReceiver.java")),
}

falhas = [nome for nome, ok in checks.items() if not ok]
for nome, ok in checks.items():
    print(("OK" if ok else "FALHA") + ": " + nome)
if falhas:
    raise SystemExit(1)
print(f"{len(checks)} verificações da 1.6.0 aprovadas.")
