"""Regressão estática da 1.5.0: wake word sem Picovoice, novas ações, atualizador,
cérebro local, humor e central de comando."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
app = (ROOT / "app.js").read_text(encoding="utf-8")
html = (ROOT / "index.html").read_text(encoding="utf-8")
css = (ROOT / "style.css").read_text(encoding="utf-8")
fundo = (ROOT / "JarvisBackgroundPlugin.java").read_text(encoding="utf-8")
servico = (ROOT / "JarvisService.java").read_text(encoding="utf-8")
util = (ROOT / "JarvisUtilPlugin.java").read_text(encoding="utf-8")
atualiza = (ROOT / "JarvisUpdatePlugin.java").read_text(encoding="utf-8")
main_java = (ROOT / "MainActivity.java").read_text(encoding="utf-8")
manifesto = (ROOT / "patch_manifest.py").read_text(encoding="utf-8")
workflow = (ROOT / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")
release = (ROOT / ".github/workflows/release-apk.yml").read_text(encoding="utf-8")

checks = {
    # ---- Palavra de ativação sem Picovoice ----
    "Detector livre completo no serviço": all(t in servico for t in (
        "iniciarSessaoLivre", "agendarSessaoLivre", "RX_WAKE_NATIVO")),
    "Plugin apenas delega a escuta ao serviço": "JarvisService.iniciarEscuta" in fundo and "JarvisWakeBus.registrar" in fundo,
    "Porcupine continua sendo o detector preferido": (
        "Porcupine.BuiltInKeyword.JARVIS" in servico and "setAccessKey(chave)" in servico),
    "Sem dependência openWakeWord": "OpenWakeWord" not in fundo and "OpenWakeWord" not in servico,
    "Backoff do detector livre (bateria)": "livreFalhas" in servico and "Math.min(8000" in servico,
    "Detector usa reconhecimento no dispositivo quando existe": "createOnDeviceSpeechRecognizer" in servico,
    "Interface não exige mais AccessKey para escutar": (
        "Detector de ativação ligado" in app and "indisponível sem AccessKey Picovoice" not in app),
    "Evento de ativação continua conectado": "pj.addListener('wake'" in app,
    # ---- Reconhecimento do usuário pela voz ----
    "Perfil de voz verificado na ativação": (
        "confirmarVozDoUsuario" in app and "if (!await confirmarVozDoUsuario()) return;" in app),
    "Checkbox do perfil de voz": 'id="c-wake-perfil"' in html and "store.get('wake_perfil'" in app,
    # ---- Novas ações e comandos ----
    "Ações de sistema cadastradas": all(t in app for t in (
        "lanterna:", "brilho:", "painel:", "email:", "fechar_app:", "versao:",
        "verificar_atualizacao:", "atualizar_app:")),
    "Comandos rápidos novos": all(t in app for t in (
        "rapido('lanterna')", "rapido('brilho')", "rapido('painel')", "rapido('versao')",
        "rapido('atualizar')", "rapido('email')", "rapido('piada')")),
    "Volume por stream e percentual": (
        "STREAM_ALARM" in util and "STREAM_NOTIFICATION" in util and "percentual" in util and "mapaTipo" in app),
    "Lanterna nativa com permissão": "setTorchMode" in util and 'alias = "camera"' in util,
    "Brilho nativo com autorização": "SCREEN_BRIGHTNESS" in util and "canWrite" in util,
    "Painel com fallback honesto": "expandNotificationsPanel" in util and "bloqueou a abertura direta" in util,
    "E-mail pelo app do aparelho": "ACTION_SENDTO" in util and "enviarEmail" in util and "enviarEmail" in app,
    "Fechar app abre os detalhes": "ACTION_APPLICATION_DETAILS_SETTINGS" in util and "fecharAplicativo" in util,
    "Versão instalada consultável": "versionName" in util and "versaoApp" in util and "ACOES.versao" in app,
    "Novos apps com fallback por fabricante": (
        "com.android.settings" in util and "com.android.vending" in util and "primeiroInstalado" in util),
    # ---- Atualizador (Atualizador + ApkProvider + release no GitHub) ----
    "Plugin do atualizador registrado": "registerPlugin(JarvisUpdatePlugin.class)" in main_java,
    "Atualizador verifica, baixa e instala": all(t in atualiza for t in (
        "verificarAtualizacao", "baixarAtualizacao", "instalarAtualizacao", "SHA-256",
        "FileProvider.getUriForFile", "api.github.com")),
    "FileProvider e permissão de instalação": (
        "com.jarvis.nova.fileprovider" in manifesto and "REQUEST_INSTALL_PACKAGES" in manifesto
        and "jarvis_paths.xml" in manifesto),
    "Workflow copia o atualizador e fixa a assinatura": (
        "JarvisUpdatePlugin.java" in workflow and "ci/debug.keystore" in workflow
        and (ROOT / "ci" / "debug.keystore").exists()),
    "Workflow de release publica o APK": (
        "tags:" in release and "softprops/action-gh-release" in release and "assembleDebug" in release),
    "CSP permite consultar o GitHub": "https://api.github.com" in html,
    "Progresso do download na interface": "atualizacao-progresso" in app and "upd-status" in html,
    # ---- Cérebro local básico e humor ----
    "Cérebro local nos três fallbacks": (
        "async function tentarBrainLocal" in app and app.count("tentarBrainLocal") >= 3
        and "localbasica" in app),
    "Humor local sob demanda": "PIADAS" in app and "function contarPiada" in app and "saudacaoInicial" in app,
    # ---- Central de comando e dashboard ----
    "Sidebar da central de comando": 'id="lateral"' in html and "[data-lat]" in app and "#lateral" in css,
    "Dashboard com comandos rápidos": (
        'id="dash-atualizar"' in html and "data-cmd=" in html and ".cmd[data-cmd]" in app),
    "Medidores do sistema": all(t in html for t in (
        "g-bateria-aro", "g-ram-aro", "g-arm-aro")) and "function setGauge" in app,
    "Aba de atualização no painel": 'data-config-tab="atualizacao"' in html and "'atualizacao'" in app,
    "Painel de atualização completo": all(t in html for t in (
        "upd-verificar", "upd-baixar", "upd-status", "upd-versao")),
    "Marca central e varredura no HUD": (
        'class="orb-marca"' in html and 'class="cam ticks"' in html and ".orb-marca" in css),
}

falhas = [nome for nome, ok in checks.items() if not ok]
for nome, ok in checks.items():
    print(("OK" if ok else "FALHA") + ": " + nome)
if falhas:
    raise SystemExit(1)
print(f"{len(checks)} verificações da 1.5.0 aprovadas.")
