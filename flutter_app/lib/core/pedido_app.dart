/// Abrir um app de terceiro **já na ação**, não só na tela inicial.
///
/// "Abre o WhatsApp na conversa da Ana", "abre o Gmail para escrever para o
/// João", "abre o mapa até a Rua X", "abre o YouTube e pesquisa gatos": sem
/// esta regra o Android só encontrava o aplicativo e abria a primeira tela.
/// Aqui o pedido vira app + ação + alvo, e o Kotlin monta o link certo.
///
/// Regra conservadora: só age com verbo de abrir **e** uma ação reconhecida.
/// "Abre o WhatsApp" continua no comando de app que já existia (procura pelo
/// nome na lista de instalados), mensagem e ligação continuam no caminho delas,
/// e pergunta nunca vira ação.
library;

import 'aparelho.dart' show interpretarLigacao, interpretarMensagem;

/// Apps que aceitam abrir numa ação específica.
enum AppComAcao {
  whatsapp('whatsapp', 'o WhatsApp'),
  whatsappBusiness('whatsapp_business', 'o WhatsApp Business'),
  telegram('telegram', 'o Telegram'),
  instagram('instagram', 'o Instagram'),
  gmail('gmail', 'o Gmail'),
  email('email', 'o e-mail'),
  sms('sms', 'o SMS'),
  maps('maps', 'o mapa'),
  youtube('youtube', 'o YouTube'),
  spotify('spotify', 'o Spotify'),
  camera('camera', 'a câmera'),
  calculadora('calculadora', 'a calculadora');

  const AppComAcao(this.chave, this.rotulo);

  /// Chave estável: é a mesma no Dart e no Kotlin.
  final String chave;

  /// Como o app é chamado na fala.
  final String rotulo;

  static AppComAcao? porChave(String chave) {
    final alvo = chave.trim().toLowerCase();
    for (final app in values) {
      if (app.chave == alvo) return app;
    }
    return null;
  }
}

/// O que fazer dentro do app.
enum TipoAcaoApp {
  abrir('abrir'),
  conversa('conversa'),
  escrever('escrever'),
  pesquisar('pesquisar'),
  navegar('navegar'),
  tocar('tocar'),
  camera('camera');

  const TipoAcaoApp(this.chave);

  /// Chave estável: é a mesma no Dart e no Kotlin.
  final String chave;

  static TipoAcaoApp? porChave(String chave) {
    final alvo = chave.trim().toLowerCase();
    for (final acao in values) {
      if (acao.chave == alvo) return acao;
    }
    return null;
  }
}

/// Alias de fala → app. A ordem não importa: o casamento testa o alias mais
/// longo primeiro, para "whatsapp business" não virar "whatsapp".
const _aliases = <String, AppComAcao>{
  'whatsapp business': AppComAcao.whatsappBusiness,
  'wpp business': AppComAcao.whatsappBusiness,
  'mensagem de texto': AppComAcao.sms,
  'google maps': AppComAcao.maps,
  'google mail': AppComAcao.gmail,
  'whatsapp': AppComAcao.whatsapp,
  'whats': AppComAcao.whatsapp,
  'zap': AppComAcao.whatsapp,
  'wpp': AppComAcao.whatsapp,
  'telegram': AppComAcao.telegram,
  'instagram': AppComAcao.instagram,
  'insta': AppComAcao.instagram,
  'gmail': AppComAcao.gmail,
  'e-mail': AppComAcao.email,
  'email': AppComAcao.email,
  'correio': AppComAcao.email,
  'sms': AppComAcao.sms,
  'torpedo': AppComAcao.sms,
  'mapa': AppComAcao.maps,
  'mapas': AppComAcao.maps,
  'maps': AppComAcao.maps,
  'youtube': AppComAcao.youtube,
  'you tube': AppComAcao.youtube,
  'spotify': AppComAcao.spotify,
  'camera': AppComAcao.camera,
  'calculadora': AppComAcao.calculadora,
};

String _semAcento(String texto) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const para = 'aaaaaeeeeiiiiooooouuuuc';
  final saida = StringBuffer();
  for (final rune in texto.toLowerCase().runes) {
    final caractere = String.fromCharCode(rune);
    final indice = de.indexOf(caractere);
    saida.write(indice < 0 ? caractere : para[indice]);
  }
  return saida.toString();
}

String _limpar(String texto) =>
    _semAcento(texto).replaceAll(RegExp(r'\s+'), ' ').trim();

String _tirarCortesia(String texto) => texto
    .replaceFirst(RegExp(r'^(?:jarvis|ei jarvis|oi jarvis)[\s,]*'), '')
    .replaceFirst(RegExp(r'^(?:por favor|pfv)[\s,]*'), '')
    .trim();

/// Verbo de abrir: sem ele o pedido não é de abrir nada.
final _verboAbrir = RegExp(
    r'\b(abrir|abre|abra|abri|mostrar|mostra|mostre|exibir|exibe|exiba|'
    r'entrar em|entra em|entre em|ir para|vai para|va para)\b');

final _pergunta = RegExp(r'^(como|por que|porque|quando|quem|onde|qual|quais|o que)\b');

/// Pedido de mensagem dita: tem caminho próprio e o texto ainda vai ser dito.
final _bloqueioMensagem = RegExp(
    r'\b(mensagem|manda|mandar|mande|envia|enviar|envie|dizendo)\b');

/// Controle de música: “abre o Spotify e toca Legião Urbana”.
final _tocar = RegExp(r'\b(toca|tocar|toque|coloca|colocar|poe|poem)\b');

final _pesquisar = RegExp(r'\b(pesquisa|pesquisar|pesquise|busca|buscar|busque|'
    r'procura|procurar|procure)\b');

final _navegar = RegExp(r'\b(rota|navega|navegar|navegue|ir ate|vai ate|va ate|'
    r'me leva|leva me|como chego|caminho ate)\b');

/// “abre o mapa até a Rua X” também é rota, mesmo sem a palavra “rota”.
final _rota = RegExp(r'\b(rota|navega|navegar|navegue|ir ate|vai ate|va ate|'
    r'me leva|leva me|como chego|caminho ate|ate)\b');

/// “na conversa da Ana”, “falar com a Ana”, “conversar com”, “direct do João”.
final _conversa = RegExp(r'\b(?:na\s+)?(?:conversa|conversar|falar|fala|direct)'
    r'\s+(?:com|da|do|de)\s+');

/// “para escrever para o João”, “novo e-mail para”.
final _escrever = RegExp(r'\b(?:escrever|escreve|nova mensagem|novo email|'
    r'novo e-mail|compor)\b');

/// Conectores que sobram antes do alvo.
final _conectores = RegExp(
    r'^(?:e-mail|email|e|o|a|os|as|um|uma|para|pra|pro|ao|aos|no|na|nos|nas|'
    r'com|da|do|das|dos|de|sobre|por|pelo|pela|ate|que|nova|novo|mensagem|'
    r'conversa|direct|pesquisa|pesquisar|busca|buscar|procura|'
    r'procurar|toca|tocar|escrever|escreve|falar|conversar|mapa|rota)\b\s*');

String _limparAlvo(String trecho) {
  var t = trecho
      .replaceAll(RegExp(r'[:"“”?!.,;]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  var anterior = '';
  while (t != anterior) {
    anterior = t;
    // Comparar sem acento ("até" = "ate") sem perder a grafia do alvo: a
    // normalização troca caractere por caractere, então o índice vale no original.
    final achado = _conectores.firstMatch(_semAcento(t));
    if (achado != null) t = t.substring(achado.end).trim();
  }
  return t;
}

/// Corta o texto depois do marcador.
///
/// A busca acontece na versão sem acento e em minúsculas, que para o português
/// tem exatamente o mesmo comprimento do original — por isso o índice do
/// marcador vale no texto original e o alvo mantém maiúsculas e acentos.
String _depois(String original, RegExp marcador) {
  final achado = marcador.firstMatch(_semAcento(original));
  if (achado == null) return '';
  return _limparAlvo(original.substring(achado.end));
}

/// Tira o nome do app do alvo: “conversa com o João no WhatsApp” → “João”.
String _semApp(String alvo, AppComAcao app) {
  var t = alvo;
  for (final entrada in _aliases.entries) {
    if (entrada.value != app) continue;
    // O conector antes do app sai junto: “João no WhatsApp” → “João”, sem “no” sobrando.
    t = t.replaceAll(
        RegExp(
            r'(?:\b(?:no|na|do|da|de|pelo|pela|via)\s+)?\b' +
                RegExp.escape(entrada.key) +
                r'\b',
            caseSensitive: false),
        ' ');
  }
  return _limparAlvo(t);
}

class PedidoAppAcao {
  const PedidoAppAcao({
    required this.app,
    required this.acao,
    this.alvo = '',
    this.texto = '',
  });

  final AppComAcao app;
  final TipoAcaoApp acao;

  /// Pessoa, lugar, usuário ou busca ditos na frase.
  final String alvo;

  /// Texto que já vinha junto (assunto de e-mail, por exemplo).
  final String texto;

  String get resumo => switch (acao) {
        TipoAcaoApp.abrir => 'abrir ${app.rotulo}',
        TipoAcaoApp.conversa => 'abrir ${app.rotulo} na conversa com $alvo',
        TipoAcaoApp.escrever =>
          'abrir ${app.rotulo} para escrever${alvo.isEmpty ? '' : ' para $alvo'}',
        TipoAcaoApp.pesquisar => 'pesquisar "$alvo" no ${app.rotulo}',
        TipoAcaoApp.navegar => 'traçar rota até $alvo no ${app.rotulo}',
        TipoAcaoApp.tocar => 'tocar "$alvo" no ${app.rotulo}',
        TipoAcaoApp.camera => 'abrir a câmera',
      };

  String get fraseFalada => switch (acao) {
        TipoAcaoApp.abrir => 'Abrindo ${app.rotulo}.',
        TipoAcaoApp.conversa => 'Abrindo ${app.rotulo} na conversa com $alvo.',
        TipoAcaoApp.escrever => alvo.isEmpty
            ? 'Abrindo ${app.rotulo} para escrever.'
            : 'Abrindo ${app.rotulo} para escrever para $alvo.',
        TipoAcaoApp.pesquisar => 'Pesquisando "$alvo" no ${app.rotulo}.',
        TipoAcaoApp.navegar => 'Traçando a rota até $alvo.',
        TipoAcaoApp.tocar => 'Procurando "$alvo" no ${app.rotulo}.',
        TipoAcaoApp.camera => 'Abrindo a câmera.',
      };
}

/// Interpreta o pedido de abrir um app já numa ação; `null` quando não é isso.
PedidoAppAcao? pedidoAppComAcao(String texto) {
  final original = texto.trim();
  final limpo = _tirarCortesia(_limpar(original));
  if (limpo.isEmpty) return null;
  if (_pergunta.hasMatch(limpo)) return null;
  if (!_verboAbrir.hasMatch(limpo)) return null;
  // Mensagem e ligação já têm caminho próprio e não podem virar ação de app.
  if (_bloqueioMensagem.hasMatch(limpo)) return null;
  if (interpretarMensagem(original) != null) return null;
  if (interpretarLigacao(original) != null) return null;

  // Ganha o app citado primeiro no pedido; no mesmo ponto, o nome mais longo
  // (“WhatsApp Business” antes de “WhatsApp”). Assim “Gmail … novo e-mail”
  // abre o Gmail, não o app de e-mail genérico.
  AppComAcao? app;
  var melhorInicio = 1 << 30;
  var melhorTamanho = 0;
  for (final alias in _aliases.entries) {
    final achado =
        RegExp(r'\b' + RegExp.escape(alias.key) + r'\b').firstMatch(limpo);
    if (achado == null) continue;
    final tamanho = achado.end - achado.start;
    if (achado.start < melhorInicio ||
        (achado.start == melhorInicio && tamanho > melhorTamanho)) {
      app = alias.value;
      melhorInicio = achado.start;
      melhorTamanho = tamanho;
    }
  }
  if (app == null) return null;

  if (app == AppComAcao.camera) {
    return const PedidoAppAcao(app: AppComAcao.camera, acao: TipoAcaoApp.camera);
  }
  if (app == AppComAcao.calculadora) {
    return const PedidoAppAcao(
        app: AppComAcao.calculadora, acao: TipoAcaoApp.abrir);
  }

  // Ordem: conversa escrita com todas as letras, depois busca/rota, depois os
  // marcadores de conversa e de escrita.
  if (app == AppComAcao.spotify && (_pesquisar.hasMatch(limpo) || _tocar.hasMatch(limpo))) {
    final marcador = _pesquisar.hasMatch(limpo) ? _pesquisar : _tocar;
    final alvo = _semApp(_depois(original, marcador), app);
    if (alvo.isEmpty) return null;
    return PedidoAppAcao(
        app: app,
        acao: _pesquisar.hasMatch(limpo) ? TipoAcaoApp.pesquisar : TipoAcaoApp.tocar,
        alvo: alvo);
  }
  if (_pesquisar.hasMatch(limpo)) {
    final alvo = _semApp(_depois(original, _pesquisar), app);
    if (alvo.isEmpty) return null;
    return PedidoAppAcao(app: app, acao: TipoAcaoApp.pesquisar, alvo: alvo);
  }
  if (app == AppComAcao.maps) {
    final navegar = _navegar.hasMatch(limpo) || _rota.hasMatch(limpo);
    final alvo = _semApp(
        navegar
            ? _depois(original, _rota)
            : _depois(original, RegExp(r'\b(?:de|em|para|pra|ate|sobre)\s+')),
        app);
    if (alvo.isEmpty) return null;
    return PedidoAppAcao(
        app: app,
        acao: navegar ? TipoAcaoApp.navegar : TipoAcaoApp.pesquisar,
        alvo: alvo);
  }
  if (app == AppComAcao.camera) {
    return const PedidoAppAcao(app: AppComAcao.camera, acao: TipoAcaoApp.camera);
  }

  // Conversa com alguém: WhatsApp, Telegram, Instagram e SMS.
  if (app == AppComAcao.whatsapp ||
      app == AppComAcao.whatsappBusiness ||
      app == AppComAcao.telegram ||
      app == AppComAcao.instagram ||
      app == AppComAcao.sms) {
    final marcador = _conversa.hasMatch(limpo)
        ? _conversa
        : RegExp(r'\b(?:com|para|pra|pro)\s+');
    final alvo = _semApp(_depois(original, marcador), app);
    if (alvo.isEmpty) return null;
    return PedidoAppAcao(app: app, acao: TipoAcaoApp.conversa, alvo: alvo);
  }

  // Escrever: Gmail e e-mail. Sem pedido de escrita, abrir o app sozinho
  // continua sendo o comando de abrir app, não uma ação de escrever.
  if (app == AppComAcao.gmail || app == AppComAcao.email) {
    if (!_escrever.hasMatch(limpo)) return null;
    final alvo = _semApp(_depois(original, _escrever), app);
    if (alvo.isEmpty) {
      return PedidoAppAcao(app: app, acao: TipoAcaoApp.escrever);
    }
    final destinatario = _limparAlvo(
        alvo.replaceFirst(RegExp(r'^(?:para|pra|pro|a|ao)\s+'), ''));
    return PedidoAppAcao(
        app: app, acao: TipoAcaoApp.escrever, alvo: destinatario);
  }
  return null;
}
