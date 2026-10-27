"""Checks do detector de ativação próprio e da personalidade (substitui o teste do Picovoice).

O ponto crítico aqui é a paridade: o serviço Android (JarvisAtivacao.java) e o WebView
(hermes.js) precisam concordar sobre quais palavras acordam o assistente, senão a ativação
funciona na tela e falha com o app fechado — ou o contrário.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
app = (ROOT / 'app.js').read_text(encoding='utf-8')
html = (ROOT / 'index.html').read_text(encoding='utf-8')
hermes = (ROOT / 'hermes.js').read_text(encoding='utf-8')
servico = (ROOT / 'JarvisService.java').read_text(encoding='utf-8')
ativacao = (ROOT / 'JarvisAtivacao.java').read_text(encoding='utf-8')
prefs = (ROOT / 'JarvisPrefs.java').read_text(encoding='utf-8')
plugin = (ROOT / 'JarvisBackgroundPlugin.java').read_text(encoding='utf-8')
patch_gradle = (ROOT / 'patch_gradle.py').read_text(encoding='utf-8')
gradle = (ROOT / 'android/app/build.gradle').read_text(encoding='utf-8')
main_js = (ROOT / 'main.js').read_text(encoding='utf-8')
css = (ROOT / 'style.css').read_text(encoding='utf-8')

issues = []

# 1. Nada de Picovoice/porcupine/openWakeWord em nenhum lugar do projeto.
alvos = {
    'JarvisService.java': servico, 'JarvisAtivacao.java': ativacao, 'JarvisPrefs.java': prefs,
    'JarvisBackgroundPlugin.java': plugin, 'app.js': app, 'index.html': html,
    'main.js': main_js, 'patch_gradle.py': patch_gradle, 'build.gradle': gradle,
}
for nome, texto in alvos.items():
    baixo = texto.lower()
    for termo in ('picovoice', 'porcupine', 'openwakeword'):
        if termo in baixo:
            # As menções remanescentes só podem ser explicativas, nunca código ativo.
            for linha in texto.splitlines():
                if termo in linha.lower() and not re.search(r'(sem |nenhum|removid|não há|nunca)', linha.lower()):
                    issues.append(f'{nome}: referência ativa a {termo}: {linha.strip()[:90]}')

# 2. O detector próprio existe e está ligado ao serviço em primeiro plano.
if 'JarvisAtivacao.presente' not in servico:
    issues.append('Serviço não usa as regras do detector próprio')
if 'JarvisAtivacao.config(' not in servico:
    issues.append('Serviço não monta a calibragem do detector próprio')
if 'onPartialResults' not in servico or 'conferirEmLote' not in servico:
    issues.append('Detector não confere resultado parcial (latência da ativação)')
if 'picoDb' not in servico or 'cfg.ruidoDb' not in servico:
    issues.append('Detector não tem porteiro de ruído')
if 'JarvisPrefs.rejeitadas(' not in servico:
    issues.append('Descartes por ruído não são contabilizados para o diagnóstico')
if 'construir duas sessões' in servico:
    issues.append('Serviço ainda tem lógica de duplicidade de sessões')
if 'JarvisPrefs.sensibilidade(this)' not in servico or 'JarvisPrefs.variantes(this)' not in servico:
    issues.append('Serviço não lê a calibragem salva (sensibilidade/palavras extras)')

# 3. Interface e plug-in expõem a calibragem e o detector.
for token, onde, nome in (
    ('id="c-wake-sensibilidade"', html, 'controle de sensibilidade'),
    ('id="c-wake-variantes"', html, 'campo de palavras extras'),
    ('id="c-wake-calibragem"', html, 'resumo da calibragem'),
    ('Detector próprio', html, 'cartão do detector próprio'),
    ('wakeCalibragem', app, 'calibragem no aplicativo'),
    ('Hermes.ativacao.casaToken', app, 'mesmas regras do núcleo no WebView'),
    ('getInt("sensibilidade"', plugin, 'calibragem chegando ao serviço'),
    ('descartesRuido', plugin, 'descartes expostos no diagnóstico'),
):
    if token not in onde:
        issues.append(f'Falta {nome} ({token})')

# 4. Nenhuma preferência morta do motor antigo.
for morto in ('JarvisPrefs.motor', 'wake_motor', 'CHAVE_PICOVOICE'):
    if morto in servico or morto in app:
        issues.append(f'Preferência do detector antigo continua em uso: {morto}')

# 5. Paridade das listas de variantes entre o Java e o JavaScript.
def lista_java(texto):
    bloco = re.search(r'VARIANTES\s*=\s*\{(.*?)\};', texto, re.S)
    return sorted(re.findall(r'"([a-z]+)"', bloco.group(1))) if bloco else []

def lista_js(texto):
    bloco = re.search(r'ATIVACAO_VARIANTES\s*=\s*\[(.*?)\];', texto, re.S)
    return sorted(re.findall(r"'([a-z]+)'", bloco.group(1))) if bloco else []

vj, vjs = lista_java(ativacao), lista_js(hermes)
if not vj or not vjs:
    issues.append('Não consegui ler as listas de variantes para comparar')
else:
    if len(set(vj)) != len(vj) or len(set(vjs)) != len(vjs):
        issues.append('Lista de variantes tem repetição (Java ou JavaScript)')
    if set(vj) != set(vjs):
        issues.append('Listas de variantes divergem entre Java e JavaScript: só no Java '
                      + repr(sorted(set(vj) - set(vjs))) + ', só no JS ' + repr(sorted(set(vjs) - set(vj))))
    if 'jarvis' not in vj:
        issues.append('A palavra canônica não está na lista de variantes')
    vj = sorted(set(vj))

# 6. A regra que evita falso positivo está nos dois lados.
if "indexOf('v') < 0" not in hermes or "indexOf('v') < 0" not in ativacao:
    issues.append('A trava do "v" (contra "jardim"/"jargão") não está nos dois lados')

# 7. Personalidade: humor seco com limites e frases próprias novas.
for token, nome in (
    ('sarcasmo seco', 'caráter do humor'),
    ('Nunca rude, nunca ofensivo, nunca humilhante', 'limites do humor'),
    ('o humor desaparece por completo', 'suspensão do humor em assunto sério'),
    ('visaoSemObjeto', 'frase própria da visão'),
    ('roteadorTroca', 'frase própria da troca de motor'),
):
    if token not in app:
        issues.append(f'Personalidade/frases: falta {nome}')

# 8. Animação de abertura e conversa: o estado de carregamento existe e é estilizado.
if 'function msgPensando' not in app or 'function removerPensando' not in app:
    issues.append('Falta o estado de carregamento da conversa')
if '.pensando-pontos' not in css or '.msg.pensando' not in css:
    issues.append('Estado de carregamento sem estilo (bolinhas animadas)')
if '@media(prefers-reduced-motion:reduce)' not in css.replace(' ', ''):
    issues.append('Movimento reduzido não é respeitado nas animações novas')

if issues:
    print('FALHA na auditoria do detector de ativação próprio:')
    for item in issues:
        print(' - ' + item)
    raise SystemExit(1)

print('Detector de ativação próprio validado: sem Picovoice, calibragem exposta nos dois lados, '
      + str(len(vj)) + ' variantes idênticas em Java e JavaScript, porteiro de ruído, '
      'listas extras e personalidade com humor seco documentados.')
