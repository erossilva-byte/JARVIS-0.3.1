"""Valida invariantes de HTML, identidade e recursos do J.A.R.V.I.S. Nova."""
from html.parser import HTMLParser
from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]

class Auditor(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.ids = []
        self.scripts = []
        self.elements = []
    def handle_starttag(self, tag, attrs):
        d = dict(attrs)
        if 'id' in d:
            self.ids.append(d['id'])
            self.elements.append((tag, d['id']))
        if tag == 'script' and d.get('src'):
            self.scripts.append(d['src'])

issues = []
html = (ROOT / 'index.html').read_text(encoding='utf-8')
parser = Auditor(); parser.feed(html)
for k in sorted({x for x in parser.ids if parser.ids.count(x) > 1}):
    issues.append(f'ID duplicado: {k}')
ids = set(parser.ids)
for required in ['painel-config','painel-tarefas','btn-tarefas','tarefas-lista','tarefa-adicionar','c-offline-auto','c-pitch-valor','c-rate-valor','config-tabs','c-audio-meter-fill','ctx-historico','ctx-memoria','rt-acao','rt-passos','c-diagnostico','c-priv-status','btn-wake-toggle','btn-chat-ampliado','c-atualizar-celular','cel-bateria','cel-temperatura','cel-armazenamento','cel-ram','cel-conexao','cel-aparelho','cel-ultimo-app','wake-mini','wake-mini-close','c-offline','c-offline-status','c-notificacoes-acesso','c-anunciar-chamadas','c-parar-apagar']:
    if required not in ids: issues.append(f'Elemento obrigatório ausente: #{required}')
for script in ['apps.js','app.js']:
    if script not in parser.scripts: issues.append(f'Script não incluído: {script}')
app = (ROOT / 'app.js').read_text(encoding='utf-8')
# IDs criados em runtime pelo editor de rotinas não aparecem no HTML estático.
dinamicos = {'rt-arg-dia','rt-arg-app','rt-arg-consulta','rt-arg-numero','rt-arg-texto','rt-arg-contato','rt-arg-modo','rt-arg-valor','rt-arg-hora'}
for m in re.finditer(r"\$\(['\"]#([A-Za-z][A-Za-z0-9_-]*)['\"]\)", app):
    target = m.group(1)
    if target not in ids and target not in dinamicos:
        issues.append(f'Seleção literal aponta para ID inexistente: #{target}')
        break
cfg = json.loads((ROOT / 'capacitor.config.json').read_text(encoding='utf-8'))
pkg = json.loads((ROOT / 'package.json').read_text(encoding='utf-8'))
version = json.loads((ROOT / 'VERSAO.json').read_text(encoding='utf-8'))
if cfg.get('appId') != 'com.jarvis.nova': issues.append('appId deve permanecer com.jarvis.nova')
if cfg.get('appId') in {'com.jarvis.app','com.jarvis.assistente'}: issues.append('appId conflita com versões legadas conhecidas')
if pkg.get('version') != version.get('version'): issues.append('package.json e VERSAO.json divergem na versão')
if version.get('version') != '1.6.0' or version.get('versionCode') != 1600: issues.append('VERSAO.json deve ser 1.6.0/versionCode 1600')
if not (ROOT / 'JarvisBootReceiver.java').exists(): issues.append('Receiver de reinicialização não encontrado')
if not (ROOT / 'JarvisNotificationListener.java').exists(): issues.append('Listener de notificações não encontrado')
if not (ROOT / 'JarvisAlarmScheduler.java').exists(): issues.append('Agendador persistente de alarmes não encontrado')
listener = (ROOT / 'JarvisNotificationListener.java').read_text(encoding='utf-8')
if 'status == TextToSpeech.SUCCESS && tts != null && ttsPronto' in listener: issues.append('Inicialização TTS das chamadas contém condição que impede ativação')
if 'ttsPronto = idioma != TextToSpeech.LANG_MISSING_DATA' not in listener: issues.append('Inicialização TTS não valida o idioma corretamente')
util = (ROOT / 'JarvisUtilPlugin.java').read_text(encoding='utf-8')
if 'canScheduleExactAlarms()' not in util or 'ACTION_REQUEST_SCHEDULE_EXACT_ALARM' not in util: issues.append('Agendador não trata permissão de alarmes exatos no Android 12+')
if 'restaurarAgendamentos' not in util or 'restaurarAgendamentos' not in app: issues.append('Agendamentos não são reavaliados quando o app é aberto')
if 'android.permission.SCHEDULE_EXACT_ALARM' not in (ROOT / 'patch_manifest.py').read_text(encoding='utf-8'): issues.append('Manifesto não declara permissão de alarmes exatos')
if 'android.permission.INTERNET' not in (ROOT / 'patch_manifest.py').read_text(encoding='utf-8'): issues.append('Manifesto não declara acesso à internet')
scheduler = (ROOT / 'JarvisAlarmScheduler.java').read_text(encoding='utf-8')
for token in ['jarvis_agendamentos', 'setAlarmClock', 'System.currentTimeMillis()', 'restaurar', 'canScheduleExactAlarms', 'Não apaga o lembrete']:
    if token not in scheduler: issues.append(f'Agendamento persistente sem mecanismo esperado: {token}')
manifest_patch = (ROOT / 'patch_manifest.py').read_text(encoding='utf-8')
for token in ['RECEIVE_BOOT_COMPLETED', '.JarvisBootReceiver', 'stopWithTask=\"false']:
    if token not in manifest_patch: issues.append(f'Patch do manifesto sem configuração esperada: {token}')
if not (ROOT / '.github/workflows/build-apk.yml').exists(): issues.append('Workflow de build APK não encontrado')
if 'groq/compound-mini' in app: issues.append('Modelo legado groq/compound-mini ainda aparece no código')
if 'browser_search' not in app: issues.append('Pesquisa browser_search não aparece no código')
if 'data-config-tab="celular"' not in html: issues.append('Aba de estado do celular ausente')
if 'https://console.groq.com/keys' not in html or 'https://aistudio.google.com/apikey' not in html: issues.append('Links oficiais para chaves de IA ausentes')
if 'Porcupine integrado' not in html or 'c-key-picovoice' not in html or 'CHAVE_PICOVOICE' not in app: issues.append('Campo Picovoice ou indicação de integração ausente')
if 'ai.picovoice:porcupine-android:4.0.2' not in (ROOT / 'patch_gradle.py').read_text(encoding='utf-8'): issues.append('SDK Porcupine Android não configurado no patch Gradle')
if 'Porcupine.BuiltInKeyword.JARVIS' not in (ROOT / 'JarvisService.java').read_text(encoding='utf-8') or 'picovoice-porcupine' not in (ROOT / 'JarvisService.java').read_text(encoding='utf-8'): issues.append('Detector Porcupine não conectado ao serviço de escuta')
if 'prefers-reduced-motion' not in (ROOT / 'style.css').read_text(encoding='utf-8'): issues.append('Falta respeito a prefers-reduced-motion')
for token in [
    'function chaveContato', 'WAKE_WORD_DISPONIVEL = true', 'Personalidade-base: sofisticado', 'Fonte retornada pela pesquisa', 'não validado de forma independente',
    "statusFonte === 'navegador' ? normalizarDataFonte(data) : ''",
    'usarContextoNestaConversa', 'usarMemoriaNestaConversa',
    'function mostrarNivelAudio', 'function salvarRotinaEditor',
    'function executarDiagnostico', 'c-apagar-historico'
]:
    if token not in app and token not in html:
        issues.append(f'Recurso selecionado sem marcador/código esperado: {token}')
workflow = (ROOT / '.github/workflows/build-apk.yml').read_text(encoding='utf-8')
if 'READ_CONTACTS' not in (ROOT / 'patch_manifest.py').read_text(encoding='utf-8'): issues.append('Permissão READ_CONTACTS ausente no patch de manifesto')
if 'com.github.msnilsen:openwakeword-android:0.1.0' in (ROOT / 'patch_gradle.py').read_text(encoding='utf-8'): issues.append('Dependência openWakeWord não resolvida continua no patch Gradle')
if 'minSdkVersion 26' not in (ROOT / 'patch_gradle.py').read_text(encoding='utf-8'): issues.append('Patch Gradle não define API mínima 26 exigida pelo detector local')
if 'https://jitpack.io' in (ROOT / 'patch_gradle.py').read_text(encoding='utf-8'): issues.append('JitPack desnecessário continua no patch Gradle')
if 'OpenWakeWord' in (ROOT / 'JarvisBackgroundPlugin.java').read_text(encoding='utf-8'): issues.append('Plugin nativo ainda depende da classe openWakeWord não resolvida')
if 'setAccessKey(chave)' not in (ROOT / 'JarvisService.java').read_text(encoding='utf-8'): issues.append('Porcupine não recebe a AccessKey salva')
if 'iniciarSessaoLivre' not in (ROOT / 'JarvisService.java').read_text(encoding='utf-8') or 'JarvisWakeBus.acordou' not in (ROOT / 'JarvisService.java').read_text(encoding='utf-8'): issues.append('Serviço não entrega o evento de ativação para a interface')
if 'patch_gradle.py android/app/build.gradle' not in workflow: issues.append('Workflow não adiciona a dependência do detector local')
if 'listarContatos' not in (ROOT / 'JarvisUtilPlugin.java').read_text(encoding='utf-8'): issues.append('Método nativo listarContatos ausente')
if 'c-importar-contatos' not in (ROOT / 'index.html').read_text(encoding='utf-8') or 'c-importar-contatos' not in (ROOT / 'app.js').read_text(encoding='utf-8'): issues.append('Interface de importação de contatos ausente')
if 'JarvisBootReceiver.java' not in workflow or 'JarvisAlarmScheduler.java' not in workflow or 'JarvisNotificationListener.java' not in workflow or not any(x in workflow for x in ['JARVIS-Nova-1.4.5-APK', 'JARVIS-Nova-1.5.0-APK', 'JARVIS-Nova-1.5.1-APK', 'JARVIS-Nova-1.6.0-APK']): issues.append('Workflow não inclui os recursos nativos/artefato atual')
if './gradlew assembleDebug' not in workflow or 'test -s app/build/outputs/apk/debug/app-debug.apk' not in workflow:
    issues.append('Workflow não valida a existência do APK após o Gradle')
if 'cache: gradle' in workflow:
    issues.append('Workflow não deve tentar restaurar cache do Gradle antes de gerar android/')
if 'chat-ampliado' not in (ROOT / 'style.css').read_text(encoding='utf-8') or 'definirChatAmpliado' not in app: issues.append('Modo de conversa ampliada sem estilo ou controle')
for token in ['Modo offline ativado','somenteLocal: true','function adicionarTarefa','alternarOfflinePorRede','Modo offline ativo: o áudio não será enviado','Modo offline: consulta de clima bloqueada','c-voz-grave','c-voz-rapida','controleMidia','responderUltimaNotificacao','abrirAgenda','definirAnuncioChamadas','limparNotificacoes','atualizarStatusCelular','mostrarWakeMini','abrirConfiguracaoSistema','temperaturaC','armazenamentoUsadoPct']:
    if token not in app and token not in (ROOT / 'JarvisUtilPlugin.java').read_text(encoding='utf-8') and token not in (ROOT / 'JarvisBackgroundPlugin.java').read_text(encoding='utf-8'):
        issues.append(f'Melhoria selecionada sem implementação/marcador esperado: {token}')

# Detect accidental duplicate Java method signatures in native source files.
for java_file in ROOT.glob("*.java"):
    source = java_file.read_text(encoding="utf-8")
    signatures = re.findall(
        r"(?m)^\s*(?:public|protected|private)\s+(?:static\s+)?[\w<>?,.\[\] ]+\s+(\w+)\s*\(([^)]*)\)\s*(?:throws\s+[\w., ]+)?\s*\{",
        source,
    )
    seen = set()
    for name, args in signatures:
        types = []
        for arg in args.split(","):
            arg = arg.strip()
            if not arg:
                continue
            parts = arg.split()
            types.append(" ".join(parts[:-1]) if len(parts) > 1 else arg)
        signature = (name, tuple(types))
        if signature in seen:
            issues.append(f"Assinatura de método Java duplicada em {java_file.name}: {name}({', '.join(types)})")
        seen.add(signature)

# Revisão 1.2.7: personalização de personalidade e abertura explícita de conversa WhatsApp.
html = (ROOT / 'index.html').read_text(encoding='utf-8')
appjs = (ROOT / 'app.js').read_text(encoding='utf-8')
if 'id="c-humor"' not in html or 'id="c-estilo"' not in html: issues.append('Controles de humor/estilo ausentes na interface')
if "store.set('humor'" not in appjs or "store.set('estilo_resposta'" not in appjs: issues.append('Preferências de personalidade não são persistidas')
if 'c-personalidade-preview' not in html or 'atualizarPreviaPersonalidade' not in appjs: issues.append('Prévia de humor/estilo não está ligada aos controles')
if 'Aplique de forma perceptível e consistente o estilo selecionado' not in appjs: issues.append('Prompt não reforça a aplicação efetiva do estilo selecionado')
if 'abrir_conversa_whatsapp' not in appjs or 'waCallMatch' not in appjs: issues.append('Fluxo de abertura de conversa WhatsApp não implementado')
if issues:
    print('FALHA na validação do projeto:')
    for item in issues: print(' -', item)
    sys.exit(1)
print(f'Projeto validado: {len(ids)} IDs únicos; identidade {cfg["appId"]}; versão {pkg["version"]}; tarefas locais, alternância offline, controles de voz, chat ampliado, rotinas e alarmes presentes.')
