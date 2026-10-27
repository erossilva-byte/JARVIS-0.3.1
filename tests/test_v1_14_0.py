"""Verificações da 1.14.0 — escuta contínua pela Groq, menu Informações, conversa em tela própria,
fim das mensagens/falas duplicadas e conjunto coeso de animações.

São checagens estáticas de propósito: elas travam o que foi prometido no código (nomes, ligações e
regras), e os testes de comportamento já existentes (test_hermes.js, test_ativacao.js) cobrem a
execução do núcleo.
"""
from pathlib import Path
import json
import sys

raiz = Path(__file__).resolve().parents[1]


def ler(p):
    return (raiz / p).read_text(encoding='utf-8')


app = ler('app.js')
html = ler('index.html')
css = ler('style.css')
hermes = ler('hermes.js')
ativacao_java = ler('JarvisAtivacao.java')
versao = json.loads(ler('VERSAO.json'))
pacote = json.loads(ler('package.json'))
leituras = ler('CHANGELOG.md') + ler('LEIA-ME.md')
script_teste = pacote.get('scripts', {}).get('test:all', '')

checagens = {
    # 1. Motor de escuta contínua pela Groq
    "Escuta contínua pela Groq implementada": all(t in app for t in (
        'function iniciarEscutaGroq', 'function pararEscutaGroq', 'function cicloEscutaGroq',
        'function capturarTrechoGroq', 'async function testarTranscricaoGroq', 'function retomarEscuta')),
    "Transcrição usa a API de transcrição da Groq": (
        "/audio/transcriptions" in app and "whisper-large-v3" in app),
    "Palavra de ativação conferida pelas regras do núcleo": (
        'Hermes.ativacao.presente(texto, configAtivacaoAtual())' in app
        and 'function ativacaoPresente' in hermes),
    "Porteiro de ruído antes de gastar cota": (
        'trecho.voz' in app and 'cfg.ruidoDb' in app and 'pico >= (cfg.ruidoDb || -40)' in app),
    "Erros de rede, limite, chave e áudio tratados": all(t in hermes for t in (
        "tipo: 'limite'", "tipo: 'chave'", "tipo: 'rede'", "tipo: 'audio'", "tipo: 'fora'")),
    "Falha de permissão de microfone tratada": (
        'NotAllowedError' in app and 'Permissão de microfone negada' in app),
    "Limite de uso espera e tenta de novo (com espera por erro)": (
        'await esperaMs(info.esperaMs)' in app and "s === 429" in hermes),
    "Escuta pela Groq é opcional e desligada por padrão": (
        "store.get('escuta_groq', '0') === '1'" in app and 'id="c-escuta-groq"' in html
        and '"id=\"c-escuta-groq\"' not in html.replace('id="c-escuta-groq"', '')),
    "Dois motores nunca disputam o microfone": (
        'if (escutaGroqLigada()) { iniciarEscutaGroq(); return; }' in app
        and 'if (escutaGroqAtiva) await pararEscutaGroq(true);' in app
        and 'if (ocupado || document.hidden || paradaAtiva) { await esperaMs(400); continue; }' in app),
    "Variações pedidas existem nas duas listas": (
        all(("'%s'" % v) in hermes for v in ('jerves', 'gerves', 'garves', 'jaive', 'jaives'))
        and all(('"%s"' % v) in ativacao_java for v in ('jerves', 'gerves', 'garves', 'jaive', 'jaives'))),
    "Teste da transcrição não abre o reconhecedor do Android": (
        '!testandoTranscricaoGroq' in app and "testandoTranscricaoGroq = true" in app),
    "Status da escuta reflete o motor em uso": (
        "'Ouvindo pela Groq'" in app and 'escutaGroqAtiva ? ' in app and 'escutaGroqLigada())' in app),

    # 2. Menu Informações
    "Painel Informações completo no HTML": all(t in html for t in (
        'id="painel-info"', 'id="cel-info-bateria"', 'id="cel-info-ram"', 'id="cel-info-arm"',
        'id="cel-info-conexao"', 'id="cel-info-aparelho"', 'id="cel-info-temp"',
        'id="cel-info-clima"', 'id="cel-info-manchetes"', 'id="cel-info-fontes"',
        'id="info-status"', 'id="info-atualizar"', 'id="info-fechar"', 'data-lat="info"')),
    "Informações consultam o aparelho, o clima e as notícias": (
        'async function dadosDoAparelho' in app and "nativo('statusDispositivo'" in app
        and 'clima(0)' in app and 'noticiasDeHoje()' in app),
    "Painel Informações entra no navegador de painéis": (
        "'#painel-info'" in app and "'#painel-info'" in ler('tests/test_panel_navigation.py')),
    "Voz abre o menu Informações (habilidade do núcleo)": (
        "id: 'informacoes'" in hermes and 'RX_INFO' in hermes
        and 'abrirInformacoes: () => abrirInformacoes()' in app),
    "Menu é alcançável pelo card, pela barra lateral e por voz": (
        "cardInfo.onclick = abrirInformacoesUI" in app and "if (alvo === 'info')" in app
        and 'abrirInformacoes()' in app),

    # 3. Chat: histórico inteiro e conversa em tela própria
    "Chat saiu do menu: conversa tem tela própria": (
        'body:not(.modo-conversa) .chat-area' in css and 'body.modo-conversa #chat{max-height:none' in css
        and 'function definirConversa' in app and 'id="btn-conversa"' in html
        and 'id="dash-conversa"' in html),
    "Rolagem não é mais limitada por dvh nem por clip de pintura": (
        '#chat{contain:none;' in css
        and css.count('body:not(.modo-conversa) #chat{max-height:') == 4
        and 'contain:layout paint' not in css.split('body.chat-ampliado #chat')[0].split('#chat{')[-1]),
    "Fim da última mensagem não fica cortado": (
        'requestAnimationFrame(() => { chat.scrollTop = chat.scrollHeight || 1e9; })' in app),
    "Entrar na conversa também pelo microfone e pelo comando": (
        'function ciclo() {\n  vibrar(12);\n  entrarConversa();' in app
        and 'entrarConversa();   // a resposta aparece na tela de conversa, não no menu' in app),

    # 4. Duplicação de mensagens e de falas
    "Portão de eco único no núcleo": (
        'function ecoUnico' in hermes and 'eco: { unico: ecoUnico, janelaMs: 3000 }' in hermes),
    "Balões repetidos são descartados": (
        "if (tipo !== 'sis' && Hermes.eco.unico(ecoBalao" in app),
    "Falas repetidas são descartadas": (
        'function falaRepetida' in app and 'if (falaRepetida(texto)) return;' in app
        and "registrar('eco', 'fala repetida ignorada: '" in app),

    # 5. Animações
    "Ondas de voz reagem ao microfone": (
        'id="ondas-voz"' in html and 'function setNivel' in app
        and "ondas.style.setProperty('--nv', nivelPend.toFixed(3))" in app
        and '.ondas-voz.com-sinal' in css),
    "Verificação do sistema é uma animação única e reutilizada": (
        'id="verifica-anim"' in html and 'function animarVerificacao' in app
        and 'animarVerificacao(true)' in app and 'animarVerificacao(false)' in app
        and '.verifica-anim span' in css),
    "Transições de tela, painel e status": (
        'function animarEntrada' in app and 'animarEntrada(document.querySelector' in app
        and '.dash-card.atalhos{' in css.replace(' ', '') and '@keyframes hud-ouvindo' in css
        and '@keyframes onda-voz' in css and '@keyframesonda-voz' in css.replace(' ', '')),
    "Movimento reduzido continua respeitado": (
        '@media(prefers-reduced-motion:reduce)' in css),

    # 6. Versão, documentação e suíte
    "Versão a partir da 1.14.0 com versionCode >= 10140": (
        [int(x) for x in str(versao.get('version', '0')).split('.')] >= [1, 14, 0]
        and versao.get('versionCode', 0) >= 10140
        and pacote.get('version') == versao.get('version')
        and ("const VERSAO_APP = '%s';" % versao.get('version')) in app),
    "Versão na interface acompanha o release": (
        ('<span class="orb-sub" aria-hidden="true">v%s</span>' % versao.get('version')) in html
        and ('<span class="versao-chip">v%s</span>' % versao.get('version')) in html),
    "Mudança registrada no CHANGELOG e no LEIA-ME": (
        '## 1.14.0' in leituras and ('# J.A.R.V.I.S. Nova %s' % versao.get('version')) in leituras
        and 'escuta contínua pela transcrição da Groq' in leituras),
    "Notas da versão descrevem o que foi entregue": (
        '## 1.14.0' in leituras
        and all(t in leituras.lower() for t in ('groq', 'informações', 'conversa', 'animações'))),
    "Suíte roda o teste novo": 'python3 tests/test_v1_14_0.py' in script_teste,
    "Núcleo e detector se identificam por versão": (
        "const VERSAO = '1.2.0'" in hermes and 'VERSAO = "1.1.0"' in ativacao_java),
}

falhas = [nome for nome, ok in checagens.items() if not ok]
for nome, ok in checagens.items():
    print(("OK: " if ok else "FALHA: ") + nome)
if falhas:
    print("\n%d verificação(ões) da 1.14.0 falharam." % len(falhas))
    sys.exit(1)
print("\n%d verificações da 1.14.0 aprovadas." % len(checagens))
