/// Regras locais das capacidades do aparelho: mensagens, Spotify, contatos,
/// ligações, status, notificações e fichas de pessoas.
///
/// Este arquivo não depende de Flutter nem do Android: ele só decide **o que**
/// foi pedido, com qual app e qual texto. A execução fica em
/// `services/aparelho_service.dart` e no Kotlin (`JarvisAparelho.kt`).
/// Nada aqui inventa sucesso: quando o Android não concluir, o resultado diz.
library;

import 'pessoas.dart';

/// Como o texto chega ao app de destino. Só o SMS é enviado direto pelo
/// aparelho; nos demais o Jarvis preenche a conversa e o toque final em
/// "enviar" é do usuário — nenhum app de terceiro aceita envio silencioso.
enum TipoEnvio { conversa, compartilhar, sms }

class AppMensagem {
  const AppMensagem({
    required this.id,
    required this.nome,
    required this.pacote,
    required this.tipo,
    this.esquema = '',
    this.dominio = '',
  });

  final String id;
  final String nome;
  final String pacote;
  final TipoEnvio tipo;

  /// Esquema do link (ex.: `whatsapp://send?phone=`).
  final String esquema;

  /// Domínio https que abre a conversa quando o app não expõe esquema.
  final String dominio;
}

/// Apps de mensagem conhecidos. A lista é fixa e auditável; o Android confirma
/// quais estão instalados antes de qualquer envio.
const appsMensagem = <AppMensagem>[
  AppMensagem(
    id: 'whatsapp',
    nome: 'WhatsApp',
    pacote: 'com.whatsapp',
    tipo: TipoEnvio.conversa,
    esquema: 'whatsapp://send',
    dominio: 'https://wa.me/',
  ),
  AppMensagem(
    id: 'whatsapp_business',
    nome: 'WhatsApp Business',
    pacote: 'com.whatsapp.w4b',
    tipo: TipoEnvio.conversa,
    esquema: 'whatsapp://send',
    dominio: 'https://wa.me/',
  ),
  AppMensagem(
    id: 'sms',
    nome: 'SMS',
    pacote: '',
    tipo: TipoEnvio.sms,
    esquema: 'smsto:',
  ),
  AppMensagem(
    id: 'gmail',
    nome: 'Gmail',
    pacote: 'com.google.android.gm',
    tipo: TipoEnvio.compartilhar,
    esquema: 'mailto:',
  ),
  AppMensagem(
    id: 'discord',
    nome: 'Discord',
    pacote: 'com.discord',
    tipo: TipoEnvio.compartilhar,
  ),
  AppMensagem(
    id: 'instagram',
    nome: 'Instagram',
    pacote: 'com.instagram.android',
    tipo: TipoEnvio.compartilhar,
  ),
  AppMensagem(
    id: 'telegram',
    nome: 'Telegram',
    pacote: 'org.telegram.messenger',
    tipo: TipoEnvio.conversa,
    esquema: 'https://t.me/',
  ),
  AppMensagem(
    id: 'messenger',
    nome: 'Messenger',
    pacote: 'com.facebook.orca',
    tipo: TipoEnvio.compartilhar,
  ),
  AppMensagem(
    id: 'signal',
    nome: 'Signal',
    pacote: 'org.thoughtcrime.securesms',
    tipo: TipoEnvio.compartilhar,
  ),
  AppMensagem(
    id: 'email',
    nome: 'E-mail',
    pacote: '',
    tipo: TipoEnvio.compartilhar,
    esquema: 'mailto:',
  ),
];

AppMensagem? appMensagemPorId(String id) {
  for (final app in appsMensagem) {
    if (app.id == id) return app;
  }
  return null;
}

/// Reconhece o app citado no texto, inclusive por apelido e sem acento.
AppMensagem? appMensagemCitado(String texto) {
  final t = _limpar(texto);
  for (final app in appsMensagem) {
    for (final apelido in _apelidos(app)) {
      if (RegExp('\\b${RegExp.escape(apelido)}\\b').hasMatch(t)) return app;
    }
  }
  return null;
}

List<String> _apelidos(AppMensagem app) => switch (app.id) {
      'whatsapp' => const ['whatsapp', 'whats', 'zap', 'wpp'],
      'whatsapp_business' => const ['whatsapp business', 'wpp business'],
      'sms' => const ['sms', 'mensagem de texto', 'torpedo'],
      'gmail' => const ['gmail', 'google mail'],
      'discord' => const ['discord'],
      'instagram' => const ['instagram', 'insta', 'direct'],
      'telegram' => const ['telegram'],
      'messenger' => const ['messenger', 'facebook messenger'],
      'signal' => const ['signal'],
      'email' => const ['e-mail', 'email', 'correio'],
      _ => [app.id],
    };

class PedidoMensagem {
  const PedidoMensagem({
    required this.app,
    required this.destino,
    required this.texto,
  });

  final AppMensagem app;

  /// Nome ou número da pessoa, exatamente como foi dito.
  final String destino;
  final String texto;

  bool get pronto => destino.trim().isNotEmpty && texto.trim().isNotEmpty;

  String get resumo {
    final alvo = destino.trim().isEmpty ? 'sem destinatário' : destino.trim();
    return '${app.nome} para $alvo: "$texto"';
  }
}

/// Interpreta "manda mensagem para Ana no WhatsApp dizendo que chego às 9".
///
/// Devolve `null` quando o texto não é um pedido de mensagem; a conversa normal
/// continua funcionando para o resto.
PedidoMensagem? interpretarMensagem(String texto) {
  final original = texto.trim();
  final limpo = _limpar(original);
  if (limpo.isEmpty) return null;
  final pedeMensagem = RegExp(
          r'\b(manda|mandar|mande|envia|enviar|envie|escreve|escrever|fala|falar)\b')
      .hasMatch(limpo);
  final temDestino = RegExp(
          r'\b(para|pra|pro|a|ao|no|na|pelo|pela|via)\b')
      .hasMatch(limpo);
  if (!pedeMensagem) return null;
  final app = appMensagemCitado(original);
  if (app == null) return null;
  if (!temDestino && !limpo.contains('mensagem')) return null;

  // Texto: tudo depois de "dizendo|dizendo que|falando|com o texto|que".
  final marcador = RegExp(
      r'\b(?:dizendo(?:\s+que)?|falando(?:\s+que)?|com\s+o\s+texto|texto|que)\b',
      caseSensitive: false);
  final achado = marcador.firstMatch(original);
  var corpo = achado == null ? '' : original.substring(achado.end).trim();
  corpo = corpo.replaceFirst(RegExp(r'^[:,\-–—]\s*'), '').trim();
  corpo = corpo.replaceFirst(RegExp(r'^que\s+', caseSensitive: false), '').trim();
  if (corpo.isEmpty) return null;

  // Destino: o que vem antes do texto pedido, sem a citação do app.
  var trecho = original;
  final achadoTexto = marcador.firstMatch(trecho);
  if (achadoTexto != null) trecho = trecho.substring(0, achadoTexto.start);
  for (final apelido in _apelidos(app)) {
    trecho = trecho.replaceAll(
        RegExp('\\b${RegExp.escape(apelido)}\\b', caseSensitive: false), ' ');
  }
  final destino = _extrairDestino(trecho);
  if (destino.isEmpty) return null;
  return PedidoMensagem(app: app, destino: destino, texto: corpo);
}

String _extrairDestino(String trecho) {
  var t = trecho
      .replaceAll(RegExp(r'[:"“”]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  // Remove conectores e o nome do app em qualquer ordem, até estabilizar.
  final conectores = RegExp(
      r'^(manda|mandar|mande|envia|enviar|envie|escreve|escrever|fala|falar|'
      r'mensagem|msg|texto|um|uma|para|pra|pro|a|ao|no|na|pelo|pela|via|'
      r'o|os|as|contato|contatos)\b\s*',
      caseSensitive: false);
  var anterior = '';
  while (t != anterior) {
    anterior = t;
    t = t.replaceFirst(conectores, '').trim();
  }
  t = t.replaceFirst(
      RegExp(r'\s+(o|a|os|as|no|na|do|da)$', caseSensitive: false), '').trim();
  return t;
}

enum AcaoSpotify { pausar, continuar, proxima, anterior, reiniciar, tocar }

class PedidoSpotify {
  const PedidoSpotify(this.acao, {this.faixa = '', this.uri = ''});
  final AcaoSpotify acao;
  final String faixa;

  /// Link ou URI do Spotify dito pelo usuário (`spotify:track:…`).
  final String uri;

  String get resumo => switch (acao) {
        AcaoSpotify.pausar => 'pausar o Spotify',
        AcaoSpotify.continuar => 'continuar o Spotify',
        AcaoSpotify.proxima => 'avançar para a próxima música',
        AcaoSpotify.anterior => 'voltar para a música anterior',
        AcaoSpotify.reiniciar => 'reiniciar a música atual',
        AcaoSpotify.tocar => 'tocar "$faixa" no Spotify',
      };
}

/// Interpreta os controles de música. Só age quando o texto fala de música,
/// Spotify ou de um controle explícito — "voltar" numa conversa não pausa nada.
PedidoSpotify? interpretarSpotify(String texto) {
  final limpo = _limpar(texto);
  if (limpo.isEmpty) return null;
  final falaDeMusica = RegExp(
          r'\b(musica|spotify|faixa|som|playlist|album|tocando|tocar)\b')
      .hasMatch(limpo);
  final citouSpotify = limpo.contains('spotify');

  if (RegExp(r'\b(pausa|pausar|pause|para a musica|parar a musica)\b')
      .hasMatch(limpo) &&
      (falaDeMusica || limpo.length <= 16)) {
    return const PedidoSpotify(AcaoSpotify.pausar);
  }
  if (RegExp(r'\b(continua|continuar|retoma|retomar|volta a tocar|despausa)\b')
          .hasMatch(limpo) &&
      falaDeMusica) {
    return const PedidoSpotify(AcaoSpotify.continuar);
  }
  if (RegExp(r'\b(proxima|proximo|avanca|avancar|pula|pular|passa a musica)\b')
          .hasMatch(limpo) &&
      (falaDeMusica || limpo.length <= 16)) {
    return const PedidoSpotify(AcaoSpotify.proxima);
  }
  if (RegExp(
          r'\b(anterior|volta a musica|voltar a musica|volta uma|retrocede|retroceder)\b')
      .hasMatch(limpo)) {
    return const PedidoSpotify(AcaoSpotify.anterior);
  }
  if (RegExp(r'\b(reinicia|reiniciar|recomeca|recomecar|do comeco)\b')
          .hasMatch(limpo) &&
      (falaDeMusica || limpo.length <= 16)) {
    return const PedidoSpotify(AcaoSpotify.reiniciar);
  }
  if (RegExp(r'\b(toca|tocar|toque|coloca|colocar|poe|poem|bota|reproduz)\b')
          .hasMatch(limpo) &&
      (citouSpotify || falaDeMusica)) {
    final uri = uriSpotify(texto);
    var faixa = texto.trim();
    final corte = RegExp(
        r'\b(toca|tocar|toque|coloca|colocar|poe|poem|bota|reproduz)\b',
        caseSensitive: false);
    final achado = corte.firstMatch(faixa);
    if (achado != null) faixa = faixa.substring(achado.end);
    faixa = faixa
        .replaceFirst(RegExp(r'^(?:a|o|as|os)\s+', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^(?:musica|faixa|som|playlist)\s+',
            caseSensitive: false), '')
        .replaceFirst(RegExp(r'\b(no|do|pelo|pela)\s+spotify\b',
            caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(por favor|agora)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[:"“”]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (uri.isNotEmpty) faixa = faixa.replaceAll(uri, '').trim();
    if (faixa.isEmpty && uri.isEmpty) return null;
    return PedidoSpotify(AcaoSpotify.tocar, faixa: faixa, uri: uri);
  }
  return null;
}

/// Extrai um link/URI do Spotify dito pelo usuário.
///
/// O Android só deixa o Jarvis apontar uma faixa exata quando ele tem a URI
/// (`spotify:track:…`). Sem ela, o caminho é a busca de mídia do sistema.
String uriSpotify(String texto) {
  final uriDireta = RegExp(r'spotify:(?:track|album|playlist|artist):[A-Za-z0-9]+')
      .firstMatch(texto);
  if (uriDireta != null) return uriDireta.group(0)!;
  final link = RegExp(
          r'https?://open\.spotify\.com/(track|album|playlist|artist)/([A-Za-z0-9]+)')
      .firstMatch(texto);
  if (link != null) return 'spotify:${link.group(1)}:${link.group(2)}';
  return '';
}

String _normalizarFaixa(String texto) {
  var t = _semAcento(texto.toLowerCase());
  t = t.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  return t.replaceAll(RegExp(r'\s+'), ' ');
}

/// Confere se a faixa que o Spotify está tocando corresponde ao pedido.
///
/// É deliberadamente conservador: título igual, título contido ou **todas** as
/// palavras do pedido aparecendo em título/artista. Sem isso, o Jarvis não
/// diz "tocando" — o Android não garante qual faixa o app escolheu.
bool faixaConfere(String pedido, {required String titulo, String artista = ''}) {
  final alvo = _normalizarFaixa(pedido);
  final achado = _normalizarFaixa(titulo);
  if (alvo.isEmpty || achado.isEmpty) return false;
  if (achado == alvo || achado.contains(alvo) || alvo.contains(achado)) {
    return true;
  }
  final conjunto = '$achado ${_normalizarFaixa(artista)}';
  return alvo.split(' ').every((p) => conjunto.contains(p));
}

class PedidoLigacao {
  const PedidoLigacao(this.destino);
  final String destino;
  String get resumo => 'ligar para $destino';
}

PedidoLigacao? interpretarLigacao(String texto) {
  final limpo = _limpar(texto);
  if (limpo.isEmpty) return null;
  if (!RegExp(r'\b(liga|ligar|ligue|disca|discar|chama|chamar)\b')
      .hasMatch(limpo)) {
    return null;
  }
  if (RegExp(r'\b(desliga|desligar|ligar a|ligar o|ligue a|ligue o)\b')
      .hasMatch(limpo)) {
    return null;
  }
  var alvo = texto.trim();
  final achado = RegExp(
          r'\b(liga|ligar|ligue|disca|discar|chama|chamar)\b',
          caseSensitive: false)
      .firstMatch(alvo);
  if (achado != null) alvo = alvo.substring(achado.end).trim();
  alvo = alvo
      .replaceFirst(
          RegExp(r'^(?:para|pra|pro|a|ao|no|na)\s+', caseSensitive: false), '')
      .replaceFirst(
          RegExp(r'^(?:o|a|os|as)\s+(?:contato\s+)?', caseSensitive: false), '')
      .replaceAll(RegExp(r'[:"“”]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (alvo.isEmpty) return null;
  return PedidoLigacao(alvo);
}

/// Estado básico do aparelho, lido do Android. Campos ausentes ficam nulos em
/// vez de receberem valor inventado.
class EstadoAparelho {
  const EstadoAparelho({
    this.bateria,
    this.carregando = false,
    this.rede = '',
    this.modelo = '',
    this.android = '',
    this.volume,
    this.brilho,
    this.naoPerturbe = false,
    this.fones = false,
    this.mudo = false,
  });

  final int? bateria;
  final bool carregando;
  final String rede;
  final String modelo;
  final String android;
  final int? volume;
  final int? brilho;
  final bool naoPerturbe;
  final bool fones;
  final bool mudo;

  bool get vazio => bateria == null && rede.isEmpty && volume == null;

  static EstadoAparelho? deMapa(Object? dados) {
    if (dados is! Map) return null;
    int? inteiro(Object? valor) => valor is num ? valor.toInt() : null;
    bool sim(Object? valor) => valor == true;
    String texto(Object? valor) => valor is String ? valor : '';
    return EstadoAparelho(
      bateria: inteiro(dados['bateria']),
      carregando: sim(dados['carregando']),
      rede: texto(dados['rede']),
      modelo: texto(dados['modelo']),
      android: texto(dados['android']),
      volume: inteiro(dados['volume']),
      brilho: inteiro(dados['brilho']),
      naoPerturbe: sim(dados['naoPerturbe']),
      fones: sim(dados['fones']),
      mudo: sim(dados['mudo']),
    );
  }

  /// Frase curta com o que foi lido de verdade.
  String descrever() {
    final partes = <String>[
      if (bateria != null) 'bateria em $bateria%${carregando ? ' (carregando)' : ''}',
      if (volume != null) 'volume de mídia em $volume%',
      if (brilho != null) 'brilho em $brilho%',
      if (rede.isNotEmpty) 'rede $rede',
      if (naoPerturbe) 'Não Perturbe ligado',
      if (mudo) 'som no mudo',
      if (fones) 'fone conectado',
      if (modelo.isNotEmpty) 'aparelho $modelo',
      if (android.isNotEmpty) 'Android $android',
    ];
    if (partes.isEmpty) return 'O aparelho não informou o estado.';
    return '${partes.join(' · ')}.';
  }
}

class NotificacaoAparelho {
  const NotificacaoAparelho({
    required this.app,
    required this.titulo,
    required this.texto,
    required this.hora,
    this.chave = '',
    this.pacote = '',
    this.respondivel = false,
  });

  final String app;
  final String titulo;
  final String texto;
  final DateTime hora;

  /// Chave da notificação no Android, usada para responder sem abrir o app.
  final String chave;
  final String pacote;

  /// O Android informou um campo de resposta (RemoteInput) nesta notificação.
  final bool respondivel;

  /// Frase para leitura em voz alta — só o que existe, sem inventar remetente.
  String get fraseLeitura {
    final corpo = texto.trim().isEmpty ? titulo.trim() : texto.trim();
    final cabeca = titulo.trim().isEmpty || corpo == titulo.trim()
        ? app
        : '$app: ${titulo.trim()}';
    return corpo.isEmpty ? cabeca : '$cabeca. $corpo';
  }

  static NotificacaoAparelho? deMapa(Object? dados) {
    if (dados is! Map) return null;
    final app = dados['app'];
    if (app is! String) return null;
    final hora = dados['hora'];
    return NotificacaoAparelho(
      app: app,
      titulo: dados['titulo'] is String ? dados['titulo'] as String : '',
      texto: dados['texto'] is String ? dados['texto'] as String : '',
      hora: hora is String
          ? DateTime.tryParse(hora) ?? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(0),
      chave: dados['chave'] is String ? dados['chave'] as String : '',
      pacote: dados['pacote'] is String ? dados['pacote'] as String : '',
      respondivel: dados['respondivel'] == true,
    );
  }
}

/// A notificação mais recente que aceita resposta direta.
///
/// Sem [app], vale qualquer aplicativo. Devolve `null` quando nenhuma aceita —
/// a tela então explica em vez de prometer uma resposta que não sai.
NotificacaoAparelho? notificacaoParaResponder(
  List<NotificacaoAparelho> lista, {
  String? app,
}) {
  final alvo = app?.trim().toLowerCase() ?? '';
  for (final n in lista) {
    if (!n.respondivel || n.chave.isEmpty) continue;
    if (alvo.isEmpty ||
        n.app.toLowerCase().contains(alvo) ||
        n.pacote.toLowerCase().contains(alvo)) {
      return n;
    }
  }
  return null;
}

/// Frases para ler as mensagens em voz alta, uma por notificação.
List<String> frasesDeLeitura(List<NotificacaoAparelho> lista, {int limite = 5}) {
  final quantas = limite < 1 ? 1 : limite;
  return [
    for (final n in lista.take(quantas))
      if (n.fraseLeitura.trim().isNotEmpty) n.fraseLeitura,
  ];
}

class ContatoAparelho {
  const ContatoAparelho({
    required this.nome,
    this.telefones = const [],
    this.emails = const [],
  });

  final String nome;
  final List<String> telefones;
  final List<String> emails;

  String get primeiroTelefone => telefones.isEmpty ? '' : telefones.first;

  static ContatoAparelho? deMapa(Object? dados) {
    if (dados is! Map) return null;
    final nome = dados['nome'];
    if (nome is! String || nome.trim().isEmpty) return null;
    List<String> lista(Object? valor) =>
        valor is List ? valor.whereType<String>().toList() : const [];
    return ContatoAparelho(
      nome: nome.trim(),
      telefones: lista(dados['telefones']),
      emails: lista(dados['emails']),
    );
  }
}

/// Ficha sugerida a partir de um contato do aparelho. Nasce com consentimento
/// desligado e campos vazios: o usuário confirma e responde o básico.
Pessoa fichaDeContato(ContatoAparelho contato, {DateTime? agora}) {
  final quando = agora ?? DateTime.now();
  final nome = limparCampoPessoa(contato.nome, limitesPessoa['nome']!);
  return Pessoa(
    id: 'contato-${_limpar(nome).replaceAll(' ', '-')}-${quando.millisecondsSinceEpoch}',
    nome: nome,
    contatos: limparCampoPessoa(
        contato.telefones.isEmpty ? '' : 'tel: ${contato.telefones.first}',
        limitesPessoa['contatos']!),
    consentimento: false,
    criadaEm: quando,
    atualizadaEm: quando,
  );
}

/// Perguntas básicas feitas ao criar uma ficha. São exatamente as informações
/// mínimas para o Jarvis saber quem é a pessoa — nada é preenchido sozinho.
const perguntasBasicasPessoa = <String>[
  'Como você quer chamar essa pessoa? (nome ou apelido)',
  'Qual é a relação dela com você? (amigo, mãe, trabalho…)',
  'O que ela gosta ou prefere? (comida, música, horário…)',
  'Alguma observação importante? (alergia, jeito de falar…)',
  'Você tem o consentimento dela para guardar isso neste aparelho?',
];

/// Resultado de uma ação no aparelho.
class ResultadoAparelho {
  const ResultadoAparelho({
    required this.ok,
    required this.mensagem,
    this.detalhes = const {},
  });

  const ResultadoAparelho.erro(this.mensagem)
      : ok = false,
        detalhes = const {};

  final bool ok;
  final String mensagem;
  final Map<Object?, Object?> detalhes;

  static ResultadoAparelho deMapa(Object? dados) {
    if (dados is! Map) {
      return const ResultadoAparelho.erro(
          'O Android não devolveu o resultado da ação.');
    }
    final mensagem = dados['mensagem'];
    return ResultadoAparelho(
      ok: dados['ok'] == true,
      mensagem: mensagem is String && mensagem.trim().isNotEmpty
          ? mensagem
          : (dados['ok'] == true ? 'Ação concluída.' : 'A ação não foi concluída.'),
      detalhes: dados,
    );
  }
}

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
