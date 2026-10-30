"""Contrato da aba Identificação de Pessoas: cartões, editor, foto, voz, privacidade e integração."""
import pathlib
import re
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent


def texto(nome):
    return (RAIZ / nome).read_text(encoding='utf-8')


html = texto('index.html')
app = texto('app.js')
core = texto('identidade.js')
ui = texto('identidade_ui.js')
css = texto('style.css')
falhas = []


def checar(nome, ok):
    print(('OK: ' if ok else 'FALHA: ') + nome)
    if not ok:
        falhas.append(nome)


painel = html.split('id="painel-pessoas"')[1].split('</aside>')[0] if 'id="painel-pessoas"' in html else ''
config = html.split('data-category="identificacao"')[1].split('</section>')[0] if 'data-category="identificacao"' in html else ''

# ---------- 1. Estrutura e lista ----------
for marca in ['id="pessoa-busca"', 'id="pessoa-lista"', 'id="idp-novo"', 'id="idp-exportar"',
              'id="idp-importar"', 'id="idp-abrir-config"', 'id="pessoa-fechar"']:
    checar('painel: ' + marca, marca in painel)
checar('cartões modernos com foto e selo de voz', '.idp-card{' in css.replace(' ', '') and
      '.idp-selo{' in css.replace(' ', '') and 'idp-foto' in ui)
checar('grade responsiva', 'grid-template-columns:repeat(auto-fill' in css.replace(' ', ''))
checar('painel rola verticalmente', '#painel-pessoas{overflow-y:auto' in css.replace(' ', ''))

# ---------- 2. Cadastro completo ----------
campos = ['nome', 'apelido', 'nascimento', 'alturaCm', 'profissao', 'relacao', 'telefone',
          'email', 'endereco', 'cidade', 'descricao', 'preferencias', 'interesses',
          'observacoes', 'contexto']
for campo in campos:
    checar('campo %s presente' % campo, ('id="pessoa-%s"' % campo) in painel)
    checar('campo %s no núcleo' % campo, re.search(r'%s:\s*\d+' % campo, core) is not None)
checar('nome é o único obrigatório', "'Informe o nome" in core)
checar('idade calculada', 'id="idp-idade"' in painel and 'function idade' in core)
checar('campos personalizados', 'id="idp-campo-rotulo"' in painel and 'camposPersonalizados' in core)
checar('nada é preenchido por suposição', 'nunca invente' in core.lower() or 'não invente' in core.lower() or
      'nada é inventado' in core.lower())

# ---------- 3. Foto ----------
checar('galeria e câmera', 'id="idp-foto-arquivo"' in painel and 'id="idp-foto-camera"' in painel and 'capture="user"' in painel)
checar('prévia e recorte', 'id="idp-foto-preview"' in painel and 'id="idp-foto-canvas"' in painel and 'id="idp-foto-aplicar"' in painel)
checar('remover e substituir', 'id="idp-foto-remover"' in painel and 'definirFoto' in core and 'removerFoto' in core)
checar('foto limitada e persistida', 'FOTO_MAX_BYTES' in core and 'data:image' in core and "CHAVE = 'jv_identidade'" in core)

# ---------- 4. Voz e consentimento ----------
for marca in ['id="idp-voz-gravar"', 'id="idp-voz-testar"', 'id="idp-voz-apagar"',
              'id="idp-voz-amostras"', 'id="idp-voz-frase"', 'id="idp-consent-voz"']:
    checar('voz: ' + marca, marca in painel)
checar('consentimento antes de gravar', 'autoriza' in painel.lower() and "consentir(" in core and
      "'A pessoa precisa autorizar" in core)
checar('três frases guiadas', 'FRASES' in ui and ui.count('Jarvis') >= 2)
checar('recusa áudio insuficiente', 'avaliarQualidade' in core and 'falaSeg' in core and 'snrDb' in core)
checar('vetor, nunca áudio', 'analise.v' in core and ('o áudio nunca é guardado' in ui.lower() or 'nunca armazenado' in core.lower()))
checar('motor de locutor reaproveitado', 'VozMotor' in core and 'voz_motor.js' in html)
checar('identificação com três estados', all(x in core for x in ['IDENTIFICADO', 'NAO_IDENTIFICADO', 'INCONCLUSIVO']))
checar('limiar e margem', 'limiar' in core and 'margem' in core and 'perfisVoz' in core)
checar('atualizar amostras', 'removerVoz' in core and 'LIMITE_AMOSTRAS' in core)
checar('nunca associa desconhecido', 'nunca associa' in core.lower() or 'não force' in core.lower() or
      'sem-perfil' in core)

# ---------- 5. Referência visual opcional ----------
checar('referência visual opcional', 'id="idp-consent-rosto"' in painel and 'id="idp-rosto-criar"' in painel)
checar('rosto desligado por padrão', "rosto: false" in core)
checar('nunca é prova de identidade', 'provaDeIdentidade: false' in core and 'não é biometria facial' in core)
checar('hash de imagem real', 'dhash' in core and 'dhashDoCanvas' in ui)

# ---------- 6. Configurações ----------
for marca in ['data-config-tab="identificacao"', 'id="idp-cfg-voz"', 'id="idp-cfg-rosto"',
              'id="idp-cfg-limiar"', 'id="idp-cfg-margem"', 'id="idp-cfg-fala"', 'id="idp-cfg-snr"',
              'id="idp-cfg-mic"', 'id="idp-cfg-testar"', 'id="idp-cfg-apagar-bio"']:
    checar('configuração: ' + marca, marca in html)
checar('limiar mínimo seguro', 'min="0.68"' in html and '0.68' in core)
checar('categoria aceita pelo roteador', "'identificacao'" in app and 'mudarCategoriaConfig' in app)
checar('apagar biometria não apaga cadastro', 'removerBiometria' in core and 'O perfil civil continua' in ui)

# ---------- 7. Integração com a IA ----------
checar('perfis no prompt', 'pessoasCtx' in app and 'Perfis de pessoas cadastrados' in app)
checar('pessoa identificada no prompt', 'pessoaAtual' in app and 'Pessoa falando agora' in app)
checar('consulta por voz', 'responderPessoaPorVoz' in app and 'quem (?:e|eh)' in app)
checar('lista por voz', 'quais|que|quantas' in app and 'cadastradas' in app and 'pessoas' in app)
checar('identificar por comando', 'identificarPessoaAgora' in app and 'identifique' in app)
checar('migração do cadastro antigo', 'migrarDe' in core and 'PessoasJarvis' in ui)
checar('consentimento e voz na ativação', 'perfisIdentidadeVoz' in app and 'IDENT.identificar' in app)

# ---------- 8. Privacidade e armazenamento ----------
checar('biometria cifrada', 'AES-GCM' in core and 'cifrar' in core and 'subtle' in core)
checar('chave local declarada', 'chave local' in core.lower())
checar('contato fora do contexto', 'telefone' not in core.split('function contexto')[1].split('function resumo')[0])
checar('histórico por perfil', 'historico' in core and 'id="idp-historico"' in painel)
checar('exportação sem biometria', 'jarvis-identidade-2' in core and 'incluiBiometria' in core)
checar('renderização sem innerHTML', 'innerHTML' not in ui)
checar('scripts na ordem certa', html.index('pessoas.js') < html.index('identidade.js') <
      html.index('identidade_ui.js') < html.index('app.js'))
checar('sem biometria em log', 'registrar(\'identidade\'' in ui and 'voz identificada' in app)

if falhas:
    print('\n%d falha(s): %s' % (len(falhas), ', '.join(falhas)))
    sys.exit(1)
print('\ntest_pessoas_ui: todas as verificações passaram')
