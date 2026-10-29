"""Revisão 1.22.0 — Visão 2.0 (balões, texto, vídeo) e cadastro de pessoas."""
import json
import pathlib
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent


def texto(nome):
    return (RAIZ / nome).read_text(encoding='utf-8')


app = texto('app.js')
html = texto('index.html')
css = texto('style.css')
meta = json.loads(texto('VERSAO.json'))
pkg = json.loads(texto('package.json'))
falhas = []


def checar(nome, ok):
    print(('OK: ' if ok else 'FALHA: ') + nome)
    if not ok:
        falhas.append(nome)


# ---------- 1. Versão única em todos os lugares ----------
checar('VERSAO.json em 1.22.0 ou posterior',
      [int(x) for x in meta.get('version', '0').split('.')] >= [1, 22, 0]
      and meta.get('versionCode', 0) >= 10220)
checar('package.json acompanha o VERSAO.json', pkg.get('version') == meta.get('version'))
checar('app.js acompanha o VERSAO.json', ("const VERSAO_APP = '%s';" % meta['version']) in app)
checar('interface na versão corrente', ('v' + meta['version']) in html and 'v1.21.5' not in html)

# ---------- 2. Módulos novos carregados antes do app ----------
checar('visao.js no pacote', (RAIZ / 'visao.js').exists())
checar('pessoas.js no pacote', (RAIZ / 'pessoas.js').exists())
checar('scripts na ordem certa', html.index('visao.js') < html.index('app.js') and
      html.index('pessoas.js') < html.index('app.js'))
checar('núcleo de visão lido pelo app', 'window.VisaoNova' in app and 'VIS.layoutBaloes' in app)
checar('cadastro lido pelo app', 'window.PessoasJarvis' in app and 'PESSOAS.resolver' in app)

# ---------- 3. Balões: colisão, limites, linha-guia e seleção ----------
checar('posicionamento delegado ao núcleo', 'VIS.layoutBaloes(visaoObjetos' in app)
checar('linha-guia desenhada em SVG', 'createElementNS' in app and 'id="visao-guias"' in html)
checar('balão selecionado tem estilo', '.balao.selecionado' in css)
checar('colisão impossível marcada', 'pos.colisao' in app and 'balao-agrupado' in css)
checar('balão interrompe a fala antes de falar', 'async function interromperFala' in app and
      'await interromperFala();' in app)
checar('interrupção cobre TTS, navegador e voz neural',
      'TTSN(); if (tn) await tn.stop()' in app and 'speechSynthesis.cancel()' in app and
      "neuralParar" in app)
checar('balão fala sem duplicar mensagem no chat', 'await falar(fala, true);' in app)

# ---------- 4. Texto da análise ----------
for marca in ['id="visao-texto"', 'id="visao-texto-modo"', 'id="visao-voltar-resumo"', 'id="visao-copiar"']:
    checar('texto: ' + marca, marca in html)
checar('texto rola e preserva resultado', '.visao-texto{' in css.replace(' ', '') and
      'overflow-y:auto' in css.replace(' ', '') and 'voltarResumoVisao' in app)
checar('copiar usa clipboard com alternativa', 'navigator.clipboard' in app and 'execCommand' in app)

# ---------- 5. Imagens e vídeos ----------
for marca in ['id="visao-arquivo-imagem"', 'id="visao-arquivo-video"', 'id="visao-video-max"',
              'id="visao-progresso"', 'id="visao-cancelar"', 'id="visao-video-lista"', 'id="visao-foto"']:
    checar('mídia: ' + marca, marca in html)
checar('imagem reduzida antes do envio', 'visaoReduzirImagem(file, 1024)' in app and '16 * 1024 * 1024' in app)
checar('vídeo extrai quadros por canvas', 'visaoQuadroDoVideo' in app and 'drawImage(video' in app)
checar('vídeo usa plano de quadros do núcleo', 'VIS.planoQuadros(el.duration, max)' in app)
checar('vídeo tem progresso real e cancelamento', 'visaoProgresso(' in app and 'visaoVideoCancelar = true' in app)
checar('resultado ligado ao timestamp', 'renderVideoLista(quadros)' in app and 'currentTime = Number(q.t)' in app)
checar('áudio não é declarado como analisado', 'O áudio não é analisado' in app)

# ---------- 6. Cadastro de pessoas ----------
for marca in ['data-lat="pessoas"', 'id="painel-pessoas"', 'id="pessoa-nome"', 'id="pessoa-apelido"',
              'id="pessoa-relacao"', 'id="pessoa-descricao"', 'id="pessoa-preferencias"',
              'id="pessoa-observacoes"', 'id="pessoa-contato"', 'id="pessoa-lista"',
              'id="pessoa-busca"', 'id="pessoa-contexto"', 'id="pessoa-exportar"']:
    checar('pessoas: ' + marca, marca in html)
checar('painel entra na navegação', "'#painel-pessoas'" in app and "alvo === 'pessoas'" in app)
checar('persistência com chave própria', "CHAVE = 'jv_pessoas'" in (RAIZ / 'pessoas.js').read_text(encoding='utf-8'))
checar('ambiguidade nunca escolhe sozinha', "tipo: 'ambiguo'" in (RAIZ / 'pessoas.js').read_text(encoding='utf-8') and
      'Qual deles?' in app)
checar('contato fora do contexto da IA', 'sem contatos' in (RAIZ / 'pessoas.js').read_text(encoding='utf-8').lower() or
      'sem contato' in (RAIZ / 'pessoas.js').read_text(encoding='utf-8').lower())
checar('perfis entram no prompt quando autorizado',
      'pessoasCtx' in app and "store.get('pessoas_contexto', '1')" in app and
      'Perfis de pessoas cadastrados' in app)
checar('desligar remove os perfis do contexto', "store.set('pessoas_contexto'" in app)
checar('sem biometria no cadastro', 'biometr' not in html.split('id="painel-pessoas"')[1].split('</aside>')[0].lower())

# ---------- 7. Diagnóstico e testes ----------
checar('módulos novos no diagnóstico', 'Visão 2.0 (balões sem sobreposição' in app and
      'Cadastro de pessoas' in app)
checar('testes novos na suíte', 'test_visao_nova.js' in pkg['scripts']['test:all'] and
      'test_pessoas.js' in pkg['scripts']['test:all'] and 'test_v1_22_0.py' in pkg['scripts']['test:all'])
checar('estilos do painel de pessoas', '.pessoa-card{' in css.replace(' ', ''))
checar('reduced motion cobre os novos elementos',
      '@media(prefers-reduced-motion:reduce)' in css.replace(' ', '') and
      '.pessoa-card' in css.replace(' ', '') and '.visao-video-item' in css.replace(' ', ''))

# ---------- 8. Segurança: nada de segredo no código ----------
import re
segredos = re.findall(r'(sk-[A-Za-z0-9]{20,}|gsk_[A-Za-z0-9]{20,}|AIza[A-Za-z0-9_-]{20,})', app + html)
checar('nenhuma chave de API no código', not segredos)

if falhas:
    print('\n%d falha(s): %s' % (len(falhas), ', '.join(falhas)))
    sys.exit(1)
print('\ntest_v1_22_0: todas as verificações passaram')
