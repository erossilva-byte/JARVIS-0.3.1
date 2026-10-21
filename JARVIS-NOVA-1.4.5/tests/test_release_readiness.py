"""Verificações adicionais de preparação para o build Android do J.A.R.V.I.S. Nova."""
from html.parser import HTMLParser
from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
issues = []

class Parser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = []
    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        if values.get('id'):
            self.ids.append(values['id'])

html = (ROOT / 'index.html').read_text(encoding='utf-8')
parser = Parser()
parser.feed(html)
if len(parser.ids) != len(set(parser.ids)):
    issues.append('HTML contém IDs duplicados')
app = (ROOT / 'app.js').read_text(encoding='utf-8')
for target in re.findall(r"\$\(['\"]#([A-Za-z][A-Za-z0-9_-]*)['\"]\)", app):
    if target not in parser.ids and target not in {
        'rt-arg-dia','rt-arg-app','rt-arg-consulta','rt-arg-numero','rt-arg-texto',
        'rt-arg-contato','rt-arg-modo','rt-arg-valor','rt-arg-hora'
    }:
        issues.append(f'app.js seleciona ID inexistente: #{target}')
        break

workflow = (ROOT / '.github/workflows/build-apk.yml').read_text(encoding='utf-8')
extract = next((line.strip() for line in workflow.splitlines() if 'find "$SRC"' in line), '')
if not extract.endswith('\\;') or extract.endswith('\\\\;'):
    issues.append('Comando find do workflow tem escape incorreto; pode interromper a extração do ZIP')
for required in ['JARVIS-NOVA-*-fonte.zip', 'npm run test:all', 'python3 patch_manifest.py', 'python3 patch_gradle.py', './gradlew assembleDebug']:
    if required not in workflow:
        issues.append(f'Workflow não contém etapa obrigatória: {required}')

version = json.loads((ROOT / 'VERSAO.json').read_text(encoding='utf-8'))
pkg = json.loads((ROOT / 'package.json').read_text(encoding='utf-8'))
cap = json.loads((ROOT / 'capacitor.config.json').read_text(encoding='utf-8'))
if pkg.get('version') != version.get('version'):
    issues.append('package.json e VERSAO.json têm versões diferentes')
if cap.get('appId') != version.get('androidAppId'):
    issues.append('capacitor.config.json e VERSAO.json têm appId diferente')
if version.get('version') != '1.4.5' or version.get('versionCode') != 1405:
    issues.append('Versão de auditoria esperada: 1.4.5 / 1405')
if not isinstance(version.get('build'), dict) or version.get('build', {}).get('resultado') not in {'pendente', 'success'}:
    issues.append('Resultado de build deve ser pendente ou success')
if version.get('build', {}).get('resultado') == 'success' and not version.get('build', {}).get('sha256'):
    issues.append('Build success exige checksum')
readme = (ROOT / 'LEIA-ME.md').read_text(encoding='utf-8')
if 'GitHub Actions já compilou uma versão debug 1.2.7' not in readme or 'execute o workflow' not in readme:
    issues.append('LEIA-ME.md não distingue o build anterior da fonte revisada')
if "const bateria = Number(r.bateria)" not in app or "bateria >= 0 ? bateria + '%' : 'indisponível'" not in app:
    issues.append('Comando de estado do dispositivo deve tratar bateria desconhecida sem exibir -1%')

if "CHAVE_PICOVOICE ? 'Jarvis' : 'indisponível sem AccessKey Picovoice'" not in app:
    issues.append('Interface não informa a exigência de AccessKey para palavra de ativação')
if "if (ehAndroid) {\n    if (!s || typeof s.guardarSeguro !== 'function') throw new Error('Cofre seguro do Android indisponível." not in app:
    issues.append('Armazenamento de chaves não falha fechado no Android')
if "$('#c-salvar').onclick = () => salvarConfig().catch" not in app:
    issues.append('Falhas ao salvar configurações não são apresentadas ao usuário')

# O script de versão deve poder ser executado novamente sem falhar se já estiver correto.
patch = (ROOT / 'patch_android_version.py').read_text(encoding='utf-8')
if 'version já está correta' not in patch:
    issues.append('Patch de versão não é idempotente')

css = (ROOT / 'style.css').read_text(encoding='utf-8')
if 'flex-wrap:wrap' not in css or '#btn-config{order:99' not in css or 'visibility:visible' not in css:
    issues.append('Cabeçalho deve reorganizar os ícones em telas estreitas e preservar o botão Configurações')
native_wake = (ROOT / 'JarvisBackgroundPlugin.java').read_text(encoding='utf-8')
if 'OpenWakeWord' in native_wake:
    issues.append('Dependência openWakeWord não resolvida ainda está no plugin nativo')
if 'Porcupine integrado' not in (ROOT / 'index.html').read_text(encoding='utf-8') or 'Porcupine.BuiltInKeyword.JARVIS' not in native_wake:
    issues.append('Integração Porcupine não identificada na interface/código nativo')

if issues:
    print('FALHA na auditoria de prontidão:')
    for item in issues:
        print(' - ' + item)
    sys.exit(1)
print(f'Prontidão estática OK: {len(parser.ids)} IDs HTML únicos; workflow de extração/build; cofre de chaves Android; rótulos de ativação; versão {version["version"]}.')

# Status do celular: deve atualizar automaticamente sem manter consultas em segundo plano.
app_source = (ROOT / "app.js").read_text(encoding="utf-8")
html_source = (ROOT / "index.html").read_text(encoding="utf-8")
assert "setInterval(atualizarStatusCelularSeguro, 5000)" in app_source
assert "if (statusCelularEmConsulta || document.hidden) return" in app_source
assert 'id="cel-auto-atualiza"' in html_source
print("Status do celular validado: atualização automática de 5 s apenas com painel visível.")

# Comandos telefônicos devem ser resolvidos localmente, sem depender da API de IA.
app_source = (ROOT / "app.js").read_text(encoding="utf-8")
assert "Chamadas comuns são comandos locais" in app_source
assert "faz uma ligacao para" in app_source
assert "limite de uso (HTTP 429)" in app_source
print("Chamadas locais e mensagem de fallback para limite Groq 429 validadas.")
