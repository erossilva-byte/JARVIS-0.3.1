"""Contrato do painel de pessoas: campos, botões, voz, exportação e privacidade."""
import pathlib
import re
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent


def texto(nome):
    return (RAIZ / nome).read_text(encoding='utf-8')


html = texto('index.html')
app = texto('app.js')
mod = texto('pessoas.js')
css = texto('style.css')
falhas = []


def checar(nome, ok):
    print(('OK: ' if ok else 'FALHA: ') + nome)
    if not ok:
        falhas.append(nome)


painel = html.split('id="painel-pessoas"')[1].split('</aside>')[0] if 'id="painel-pessoas"' in html else ''

# ---------- 1. Campos e limites ----------
campos = {
    'nome': ('60', True), 'apelido': ('40', False), 'relacao': ('60', False),
    'descricao': ('400', False), 'preferencias': ('400', False),
    'observacoes': ('800', False), 'contato': ('120', False),
}
for campo, (limite, obrigatorio) in campos.items():
    marca = 'id="pessoa-%s"' % campo
    trecho = painel.split(marca)[1][:160] if marca in painel else ''
    checar('campo %s presente' % campo, marca in painel)
    checar('campo %s com limite %s' % (campo, limite), ('maxlength="%s"' % limite) in trecho)
    checar('limite %s coerente no módulo' % campo, re.search(r"%s:\s*%s" % (campo, limite), mod) is not None)
checar('nome é obrigatório no módulo', "if (!p.nome) return 'Informe o nome" in mod)
checar('nome marcado como obrigatório na tela', 'obrigatório' in painel or 'Nome ou identificação' in painel)

# ---------- 2. Botões e ações ligadas ----------
botoes = ['pessoa-salvar', 'pessoa-novo', 'pessoa-exportar', 'pessoa-copiar-export',
          'pessoa-apagar-tudo', 'pessoa-fechar']
for b in botoes:
    checar('botão %s existe' % b, ('id="%s"' % b) in painel)
    checar('botão %s tem ação' % b, ("#%s" % b) in app)
checar('salvar pergunta antes de nome repetido', 'Já existe um perfil com o nome' in app and 'confirm(' in app)
checar('excluir pede confirmação', 'Apagar o perfil de' in app)
checar('apagar todos pede confirmação', 'Apagar os ' in app)

# ---------- 3. Consulta por voz chega ao cadastro ----------
checar('função de consulta por voz existe', 'function responderPessoaPorVoz' in app)
checar('voz é chamada antes do Hermes', app.index('responderPessoaPorVoz(texto)') <
      app.index('Hermes.anotarTexto(texto)'))
checar('voz devolve null sem perfil (não sequestra assunto geral)',
      "if (r.tipo === 'nenhum') return null;" in app)
checar('voz pergunta quando ambíguo', 'Qual deles' in app and 'candidatos.length' in app)
checar('regex de voz aceita "quem é"', 'quem (?:e|eh)' in app)
trecho_voz = app.split('function responderPessoaPorVoz')[1].split('\n}\n')[0] if 'function responderPessoaPorVoz' in app else ''
checar('regex de voz sem escape duplicado', (chr(92)*2 + 's+') not in trecho_voz and (chr(92) + 's+') in trecho_voz)

# ---------- 4. Persistência, exportação e privacidade ----------
checar('chave própria de armazenamento', "CHAVE = 'jv_pessoas'" in mod)
checar('exportação gera JSON', "'jarvis-pessoas-1'" in mod)
checar('JSON visível quando o download falha', 'id="pessoa-exportacao"' in painel and
      "saida.textContent = texto" in app)
checar('copiar exportação usa clipboard com alternativa', 'copiarExportPessoas' in app and 'execCommand' in app)
checar('contato fora do contexto', "' · prefere '" in mod and 'contato' not in mod.split('function contexto')[1].split('function exportar')[0])
checar('contexto limitado a 12', "slice(0, 12)" in mod)
checar('perfis como contexto da IA', 'pessoasCtx' in app and 'Perfis de pessoas cadastrados' in app)
checar('opção de desligar contexto', "store.set('pessoas_contexto'" in app)
checar('contato não vira contexto automaticamente', 'números' not in mod.lower() or 'contato' not in mod.split('function contexto')[1].split('function exportar')[0])
checar('renderização sem innerHTML', 'innerHTML' not in app.split('function renderPessoas')[1].split('function abrirPessoas')[0])
checar('dados via textContent', 'textContent = p.nome' in app)

# ---------- 5. Navegação, rolagem e diagnóstico ----------
checar('atalho no menu lateral', 'data-lat="pessoas"' in html)
checar('painel entra na lista de painéis', "'#painel-pessoas'" in app)
checar('painel rola verticalmente', '#painel-pessoas{overflow-y:auto' in css.replace(' ', ''))
checar('diagnóstico lê os perfis gravados', "PESSOAS.listar()" in app and "'Cadastro de pessoas'" in app)
checar('diagnóstico aponta nomes repetidos', 'nome(s) repetido(s)' in app)

# ---------- 6. Fontes e segurança ----------
checar('scripts carregados antes do app', html.index('pessoas.js') < html.index('app.js'))
checar('sem chaves no painel', 'sk-' not in painel and 'AIza' not in painel)
checar('sem biometria no cadastro', 'biometr' not in painel.lower())

if falhas:
    print('\n%d falha(s): %s' % (len(falhas), ', '.join(falhas)))
    sys.exit(1)
print('\ntest_pessoas_ui: todas as verificações passaram')
