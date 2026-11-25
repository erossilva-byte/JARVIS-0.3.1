/// Modo palco — contrato puro, sem Flutter e sem rede.
///
/// O palco pesquisa imagens, vídeos ou notícias e mostra o resultado na tela.
/// Aqui ficam só as decisões que dá para conferir sem aparelho: o que o pedido
/// quer dizer, qual endereço consultar e como ler a resposta de cada fonte.
/// Nenhuma fonte exige chave: Wikimedia Commons (imagens), Google Notícias
/// (RSS) e Dailymotion (vídeos). Quando a fonte falha, o app diz isso — não
/// inventa resultado.
library;

import 'dart:convert';

/// O que o palco exibe.
enum TipoPalco { imagem, video, noticia }

extension TipoPalcoDados on TipoPalco {
  String get rotulo => switch (this) {
        TipoPalco.imagem => 'Imagem',
        TipoPalco.video => 'Vídeo',
        TipoPalco.noticia => 'Notícia',
      };

  /// Nome da fonte usada por este tipo.
  String get fonte => switch (this) {
        TipoPalco.imagem => 'Wikimedia Commons',
        TipoPalco.video => 'Dailymotion',
        TipoPalco.noticia => 'Google Notícias',
      };

  /// O que o palco faz com o resultado, sem prometer player embutido.
  String get comoExibe => switch (this) {
        TipoPalco.imagem =>
          'A imagem aparece no palco, com o crédito da fonte.',
        TipoPalco.video =>
          'A capa e o título aparecem no palco; o vídeo abre no navegador, '
              'porque este APK não tem player embutido.',
        TipoPalco.noticia =>
          'O título e o resumo aparecem no palco; a matéria completa abre no '
              'navegador.',
      };
}

/// Pedido de palco reconhecido no texto do usuário.
class PedidoPalco {
  const PedidoPalco({required this.consulta, required this.tipo});

  /// O que pesquisar, já sem o verbo e sem a palavra de mídia.
  final String consulta;
  final TipoPalco tipo;

  Map<String, Object?> paraJson() => {'consulta': consulta, 'tipo': tipo.name};

  @override
  String toString() => 'PedidoPalco(${tipo.name}: $consulta)';
}

/// Um resultado pronto para a tela.
class ItemPalco {
  const ItemPalco({
    required this.tipo,
    required this.titulo,
    required this.url,
    this.resumo = '',
    this.miniatura = '',
    this.fonte = '',
    this.detalhe = '',
    this.largura = 0,
    this.altura = 0,
  });

  final TipoPalco tipo;
  final String titulo;

  /// Endereço da página original (imagem, vídeo ou matéria).
  final String url;

  /// Texto curto exibido abaixo do título.
  final String resumo;

  /// Endereço da imagem mostrada no palco (capa do vídeo, miniatura da notícia).
  final String miniatura;

  final String fonte;

  /// Informação curta da fonte: autoria, duração ou data.
  final String detalhe;

  /// Tamanho declarado da imagem, quando a fonte informa. Zero é "não sei".
  final int largura;
  final int altura;

  /// Proporção da mídia; 0 quando não há imagem nem tamanho declarado.
  double get proporcao {
    if (largura > 0 && altura > 0) return largura / altura;
    return miniatura.isEmpty ? 0 : 4 / 3;
  }
}

/// Como a mídia cabe no palco. Muda com a forma da imagem, do vídeo e da
/// notícia — antes tudo era uma caixa de 210 px com recorte.
enum MolduraPalco { capaLarga, retratoAlto, quadrada, capaVideo, capaNoticia, semImagem }

class Moldura {
  const Moldura({
    required this.tipo,
    required this.proporcao,
    required this.alturaRelativa,
    required this.cabeInteira,
  });

  final MolduraPalco tipo;

  /// Proporção usada na caixa (largura / altura).
  final double proporcao;

  /// Altura em fração da tela (0 a 1).
  final double alturaRelativa;

  /// `true` mostra a mídia inteira (contain); `false` recorta para preencher.
  final bool cabeInteira;

  /// Altura em pixels para a tela informada, com teto de 62% da tela.
  double alturaEm(double alturaTela) =>
      (alturaTela * alturaRelativa).clamp(110.0, alturaTela * 0.62);
}

/// Uma regra de enquadramento: quanto da tela a mídia ocupa e se recorta.
class RegraMoldura {
  const RegraMoldura({required this.altura, required this.cabeInteira});

  /// Altura em fração da tela (0,15 a 0,62).
  final double altura;

  /// `true` mostra inteira; `false` recorta para preencher.
  final bool cabeInteira;

  static const double alturaMinima = 0.15;
  static const double alturaMaxima = 0.62;

  double get alturaLimitada => altura.clamp(alturaMinima, alturaMaxima);

  RegraMoldura copiarCom({double? altura, bool? cabeInteira}) => RegraMoldura(
        altura: (altura ?? this.altura).clamp(alturaMinima, alturaMaxima),
        cabeInteira: cabeInteira ?? this.cabeInteira,
      );

  Map<String, Object?> paraJson() =>
      {'altura': alturaLimitada, 'cabeInteira': cabeInteira};

  static RegraMoldura deJson(Object? dados, RegraMoldura padrao) {
    if (dados is! Map) return padrao;
    final valor = dados['altura'];
    final inteira = dados['cabeInteira'];
    return RegraMoldura(
      altura: valor is num
          ? valor.toDouble().clamp(alturaMinima, alturaMaxima)
          : padrao.altura,
      cabeInteira: inteira is bool ? inteira : padrao.cabeInteira,
    );
  }

  @override
  String toString() =>
      'RegraMoldura(${alturaLimitada.toStringAsFixed(2)}, '
      '${cabeInteira ? "inteira" : "recorte"})';
}

/// As regras do palco, editáveis pelo usuário e guardadas no aparelho.
///
/// Cada tipo de moldura tem altura e recorte próprios; os dois limiares
/// decidem quando uma imagem é capa larga, quase quadrada ou retrato.
class RegrasPalco {
  const RegrasPalco({
    this.capaLarga = const RegraMoldura(altura: 0.38, cabeInteira: false),
    this.retratoAlto = const RegraMoldura(altura: 0.56, cabeInteira: true),
    this.quadrada = const RegraMoldura(altura: 0.44, cabeInteira: true),
    this.capaVideo = const RegraMoldura(altura: 0.34, cabeInteira: false),
    this.capaNoticia = const RegraMoldura(altura: 0.26, cabeInteira: false),
    this.limiarLargo = 1.5,
    this.limiarEstreito = 0.8,
  });

  static const padrao = RegrasPalco();

  static const double limiarLargoMinimo = 1.1;
  static const double limiarLargoMaximo = 2.5;
  static const double limiarEstreitoMinimo = 0.5;
  static const double limiarEstreitoMaximo = 0.95;

  final RegraMoldura capaLarga;
  final RegraMoldura retratoAlto;
  final RegraMoldura quadrada;
  final RegraMoldura capaVideo;
  final RegraMoldura capaNoticia;

  /// Proporção a partir da qual a imagem vira capa larga.
  final double limiarLargo;

  /// Proporção até a qual a imagem é tratada como retrato em pé.
  final double limiarEstreito;

  RegraMoldura regraDe(MolduraPalco tipo) => switch (tipo) {
        MolduraPalco.capaLarga => capaLarga,
        MolduraPalco.retratoAlto => retratoAlto,
        MolduraPalco.quadrada => quadrada,
        MolduraPalco.capaVideo => capaVideo,
        MolduraPalco.capaNoticia => capaNoticia,
        MolduraPalco.semImagem =>
          const RegraMoldura(altura: 0.24, cabeInteira: false),
      };

  RegrasPalco comRegra(MolduraPalco tipo, RegraMoldura regra) => RegrasPalco(
        capaLarga: tipo == MolduraPalco.capaLarga ? regra : capaLarga,
        retratoAlto: tipo == MolduraPalco.retratoAlto ? regra : retratoAlto,
        quadrada: tipo == MolduraPalco.quadrada ? regra : quadrada,
        capaVideo: tipo == MolduraPalco.capaVideo ? regra : capaVideo,
        capaNoticia: tipo == MolduraPalco.capaNoticia ? regra : capaNoticia,
        limiarLargo: limiarLargo,
        limiarEstreito: limiarEstreito,
      );

  RegrasPalco copiarCom({
    double? limiarLargo,
    double? limiarEstreito,
  }) {
    final largo = (limiarLargo ?? this.limiarLargo)
        .clamp(limiarLargoMinimo, limiarLargoMaximo);
    final estreito = (limiarEstreito ?? this.limiarEstreito)
        .clamp(limiarEstreitoMinimo, limiarEstreitoMaximo);
    // O limiar largo tem de ficar acima do estreito, senão nada seria "médio".
    return RegrasPalco(
      capaLarga: capaLarga,
      retratoAlto: retratoAlto,
      quadrada: quadrada,
      capaVideo: capaVideo,
      capaNoticia: capaNoticia,
      limiarLargo: largo <= estreito + 0.1 ? estreito + 0.1 : largo,
      limiarEstreito: estreito,
    );
  }

  Map<String, Object?> paraJson() => {
        'capaLarga': capaLarga.paraJson(),
        'retratoAlto': retratoAlto.paraJson(),
        'quadrada': quadrada.paraJson(),
        'capaVideo': capaVideo.paraJson(),
        'capaNoticia': capaNoticia.paraJson(),
        'limiarLargo': limiarLargo,
        'limiarEstreito': limiarEstreito,
      };

  static RegrasPalco deJson(Object? dados) {
    Object? cru = dados;
    if (cru is String) {
      try {
        cru = jsonDecode(cru);
      } catch (_) {
        return padrao;
      }
    }
    if (cru is! Map) return padrao;
    final largo = cru['limiarLargo'];
    final estreito = cru['limiarEstreito'];
    final regras = RegrasPalco(
      capaLarga: RegraMoldura.deJson(cru['capaLarga'], padrao.capaLarga),
      retratoAlto: RegraMoldura.deJson(cru['retratoAlto'], padrao.retratoAlto),
      quadrada: RegraMoldura.deJson(cru['quadrada'], padrao.quadrada),
      capaVideo: RegraMoldura.deJson(cru['capaVideo'], padrao.capaVideo),
      capaNoticia: RegraMoldura.deJson(cru['capaNoticia'], padrao.capaNoticia),
      limiarLargo: largo is num ? largo.toDouble() : padrao.limiarLargo,
      limiarEstreito:
          estreito is num ? estreito.toDouble() : padrao.limiarEstreito,
    );
    return regras.copiarCom(
      limiarLargo: regras.limiarLargo,
      limiarEstreito: regras.limiarEstreito,
    );
  }
}

/// Escolhe a moldura pela forma real da mídia, obedecendo às regras do usuário.
/// Imagem declarada em pé fica inteira; foto larga vira capa; notícia e vídeo
/// têm tratamento próprio.
Moldura molduraDoItem(ItemPalco item,
    {RegrasPalco regras = RegrasPalco.padrao}) {
  if (item.miniatura.isEmpty) {
    return const Moldura(
      tipo: MolduraPalco.semImagem,
      proporcao: 16 / 9,
      alturaRelativa: 0.24,
      cabeInteira: false,
    );
  }

  Moldura com(MolduraPalco tipo, double proporcao, RegraMoldura regra) =>
      Moldura(
        tipo: tipo,
        proporcao: proporcao,
        alturaRelativa: regra.alturaLimitada,
        cabeInteira: regra.cabeInteira,
      );

  switch (item.tipo) {
    case TipoPalco.video:
      return com(MolduraPalco.capaVideo, 16 / 9, regras.capaVideo);
    case TipoPalco.noticia:
      return com(MolduraPalco.capaNoticia, 16 / 9, regras.capaNoticia);
    case TipoPalco.imagem:
      final proporcao = item.proporcao;
      if (proporcao >= regras.limiarLargo) {
        return com(MolduraPalco.capaLarga, 16 / 9, regras.capaLarga);
      }
      if (proporcao <= regras.limiarEstreito) {
        return com(MolduraPalco.retratoAlto, proporcao, regras.retratoAlto);
      }
      return com(MolduraPalco.quadrada, proporcao, regras.quadrada);
  }
}

/// Verbos que pedem para trazer algo à tela.
const _verbosPalco = r'(mostra|mostre|mostrar|exibe|exibir|exiba|traz|traga|'
    r'trazer|pesquisa|pesquise|pesquisar|procura|procure|procurar|busca|'
    r'busque|buscar|quero ver|ver)';

const _palavrasImagem =
    r'(fotos?|imagens?|figuras?|ilustra[cç][aã]o|desenhos?)';
const _palavrasVideo = r'(v[ií]deos?|clipes?|filmes?)';
const _palavrasNoticia = r'(not[ií]cias?|manchetes?|reportagens?)';

final _pedidoImagem = RegExp(
    '($_verbosPalco\\b[^.!?]{0,40}\\b$_palavrasImagem\\b|'
    '\\b$_palavrasImagem\\b[^.!?]{0,20}\\b(no palco|na tela))',
    caseSensitive: false);
final _pedidoVideo = RegExp(
    '($_verbosPalco\\b[^.!?]{0,40}\\b$_palavrasVideo\\b|'
    '\\b$_palavrasVideo\\b[^.!?]{0,20}\\b(no palco|na tela))',
    caseSensitive: false);
final _pedidoNoticia = RegExp(
    '($_verbosPalco\\b[^.!?]{0,40}\\b$_palavrasNoticia\\b|'
    '\\b$_palavrasNoticia\\b[^.!?]{0,20}\\b(no palco|na tela))',
    caseSensitive: false);

/// Reconhece um pedido de palco no texto.
///
/// Devolve `null` quando o texto não pede mídia — o normal é a conversa
/// comum. A ordem importa: “mostra um vídeo sobre o motor” é vídeo, não
/// imagem, mesmo falando de motor.
PedidoPalco? pedidoPalco(String texto) {
  final limpo = texto.trim();
  if (limpo.length < 4) return null;
  final tipo = _tipoDoPedido(limpo);
  if (tipo == null) return null;
  final consulta = consultaDePalco(limpo, tipo);
  if (consulta.isEmpty) return null;
  return PedidoPalco(consulta: consulta, tipo: tipo);
}

/// Pedido de palco vindo da voz com o app fechado.
///
/// O serviço Android manda o assunto já limpo e o tipo reconhecido
/// (`imagem`, `video` ou `noticia`). Tipo ausente ou desconhecido volta a ser
/// inferido pelo próprio texto, para a intenção antiga continuar valendo.
PedidoPalco? pedidoDePalcoVoz(String tipo, String consulta) {
  final limpo = consulta.trim();
  if (limpo.isEmpty) return null;
  final escolhido = switch (tipo.trim().toLowerCase()) {
    'imagem' => TipoPalco.imagem,
    'video' => TipoPalco.video,
    'noticia' => TipoPalco.noticia,
    _ => _tipoDoPedido(limpo),
  };
  if (escolhido == null) return null;
  return PedidoPalco(consulta: limpo, tipo: escolhido);
}

TipoPalco? _tipoDoPedido(String texto) {
  // O primeiro verbo de mídia que aparece manda; empate resolve pelo mais
  // específico (vídeo e notícia antes de imagem).
  final posicoes = <TipoPalco, int>{
    if (_pedidoVideo.hasMatch(texto))
      TipoPalco.video: _pedidoVideo.firstMatch(texto)!.start,
    if (_pedidoNoticia.hasMatch(texto))
      TipoPalco.noticia: _pedidoNoticia.firstMatch(texto)!.start,
    if (_pedidoImagem.hasMatch(texto))
      TipoPalco.imagem: _pedidoImagem.firstMatch(texto)!.start,
  };
  if (posicoes.isEmpty) return null;
  final ordenados = posicoes.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  return ordenados.first.key;
}

/// Tira verbo, palavra de mídia e preposições do começo, deixando só o assunto.
String consultaDePalco(String texto, [TipoPalco? tipo]) {
  var saida = texto.trim();
  if (saida.isEmpty) return '';
  final alvo = tipo ?? _tipoDoPedido(saida);
  final palavras = alvo == null ? '' : _palavraDoTipo(alvo);
  final remover = RegExp(
    '^(?:por favor[, ]*)?(?:me )?(?:$_verbosPalco)\\s+'
    '(?:(?:uma|um|uns|umas|a|o|as|os|algumas|alguns)\\s+)?'
    '(?:$palavras)?(?:\\s+(?:no palco|na tela))?'
    '(?:\\s+(?:de|do|da|dos|das|sobre|com|em|no|na|'
    'nos|nas|para|pra|pelo|pela))?\\s*',
    caseSensitive: false,
  );
  saida = saida.replaceFirst(remover, '');
  // Sem verbo no começo: “fotos de gato” vira “gato”.
  saida = saida.replaceFirst(
    RegExp(
        '^(?:$palavras)\\s*(?:no palco|na tela)?\\s*'
        '(?:de|do|da|dos|das|sobre|com|em|no|na|nos|nas|para|pra)?\\s*',
        caseSensitive: false),
    '',
  );
  saida = saida
      .replaceAll(RegExp(r'["“”]'), ' ')
      .replaceAll(
          RegExp(r'\s+(?:no palco|na tela)\s*$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  saida = saida.replaceAll(RegExp(r'^[.,;:!?-]+|[.,;:!?-]+$'), '').trim();
  return saida;
}

String _palavraDoTipo(TipoPalco tipo) => switch (tipo) {
      TipoPalco.imagem => _palavrasImagem,
      TipoPalco.video => _palavrasVideo,
      TipoPalco.noticia => _palavrasNoticia,
    };

/// Endereço de busca de imagens na Wikimedia Commons (sem chave).
///
/// Só o espaço de nomes 6 (arquivos) entra, com miniatura de 1200 px — o
/// suficiente para o palco e leve para o celular.
String urlDeBuscaImagens(String consulta) {
  final termo = Uri.encodeQueryComponent(consulta.trim());
  return 'https://commons.wikimedia.org/w/api.php?action=query'
      '&format=json&formatversion=2&generator=search'
      '&gsrsearch=$termo&gsrnamespace=6&gsrlimit=12'
      '&prop=imageinfo&iiprop=url%7Cmime%7Cextmetadata&iiurlwidth=1200';
}

/// RSS de notícias do Google, em português do Brasil e sem chave.
String urlDeBuscaNoticias(String consulta) {
  final termo = Uri.encodeQueryComponent(consulta.trim());
  return 'https://news.google.com/rss/search?q=$termo&hl=pt-BR&gl=BR'
      '&ceid=BR:pt-419';
}

/// Busca pública de vídeos no Dailymotion, sem chave.
String urlDeBuscaVideos(String consulta) {
  final termo = Uri.encodeQueryComponent(consulta.trim());
  return 'https://api.dailymotion.com/videos?search=$termo&limit=12'
      '&fields=id,title,url,thumbnail_480_url,duration';
}

/// Endereço consultado para o pedido.
String urlDoPedido(PedidoPalco pedido) => switch (pedido.tipo) {
      TipoPalco.imagem => urlDeBuscaImagens(pedido.consulta),
      TipoPalco.video => urlDeBuscaVideos(pedido.consulta),
      TipoPalco.noticia => urlDeBuscaNoticias(pedido.consulta),
    };

/// Frase curta mostrada enquanto a pesquisa acontece.
String descricaoDoPedido(PedidoPalco pedido) =>
    'Pesquisando ${pedido.tipo.rotulo.toLowerCase()} sobre '
    '“${pedido.consulta}” no ${pedido.tipo.fonte}…';

/// `true` só para http/https: o palco nunca abre outro esquema.
bool linkSeguro(String url) {
  final limpo = url.trim().toLowerCase();
  return limpo.startsWith('https://') || limpo.startsWith('http://');
}

/// Lê a resposta do gerador de busca da Wikimedia Commons.
///
/// Aceita `formatversion=2` (lista) e o formato antigo (mapa por página). O
/// que não for imagem ou não tiver endereço seguro fica de fora.
List<ItemPalco> lerImagensDoCommons(String corpo) {
  late final Object? dados;
  try {
    dados = jsonDecode(corpo);
  } on FormatException {
    return const [];
  }
  if (dados is! Map) return const [];
  final query = dados['query'];
  if (query is! Map) return const [];
  final pages = query['pages'];
  final brutos = <Map>[];
  if (pages is List) {
    for (final pagina in pages) {
      if (pagina is Map) brutos.add(pagina);
    }
  } else if (pages is Map) {
    for (final pagina in pages.values) {
      if (pagina is Map) brutos.add(pagina);
    }
  }
  if (brutos.isEmpty) return const [];

  final itens = <ItemPalco>[];
  for (final pagina in brutos) {
    final info = pagina['imageinfo'];
    final primeira = info is List && info.isNotEmpty ? info.first : null;
    if (primeira is! Map) continue;
    final mime = primeira['mime']?.toString() ?? '';
    if (mime.isNotEmpty && !mime.startsWith('image/')) continue;
    final imagem = (primeira['thumburl'] ?? primeira['url'] ?? '').toString();
    if (!linkSeguro(imagem)) continue;
    final paginaUrl = (primeira['descriptionurl'] ?? imagem).toString();
    final titulo = _tituloDeArquivo(pagina['title']?.toString() ?? '');
    if (titulo.isEmpty) continue;
    itens.add(ItemPalco(
      tipo: TipoPalco.imagem,
      titulo: titulo,
      url: linkSeguro(paginaUrl) ? paginaUrl : imagem,
      miniatura: imagem,
      resumo: _creditoDaImagem(primeira['extmetadata']),
      fonte: 'Wikimedia Commons',
      largura: _inteiro(primeira['width']),
      altura: _inteiro(primeira['height']),
    ));
  }
  return itens;
}

int _inteiro(Object? valor) =>
    valor is num ? valor.toInt().clamp(0, 100000) : 0;

/// “File:Motor elétrico 01.jpg” vira “Motor elétrico 01”.
String _tituloDeArquivo(String bruto) => bruto
    .replaceFirst(RegExp(r'^File:', caseSensitive: false), '')
    .replaceFirst(RegExp(r'\.[a-zA-Z0-9]{2,5}$'), '')
    .replaceAll('_', ' ')
    .trim();

/// Crédito quando a fonte informa; sem metadado, o texto fica vazio.
String _creditoDaImagem(Object? metadados) {
  if (metadados is! Map) return '';
  final artista = metadados['Artist'];
  final valor = artista is Map ? artista['value']?.toString() ?? '' : '';
  final limpo = _semTags(valor).trim();
  if (limpo.isEmpty) return '';
  if (limpo.length > 120) return '${limpo.substring(0, 120)}…';
  return 'Crédito: $limpo';
}

/// Lê o RSS do Google Notícias.
List<ItemPalco> lerNoticiasDoRss(String xml) {
  final itens = <ItemPalco>[];
  final blocos =
      RegExp(r'<item\b[^>]*>(.*?)</item>', caseSensitive: false, dotAll: true)
          .allMatches(xml);
  for (final bloco in blocos) {
    final corpo = bloco.group(1) ?? '';
    final titulo = _semTags(_tag(corpo, 'title')).trim();
    final link = _tag(corpo, 'link').trim();
    if (titulo.isEmpty || !linkSeguro(link)) continue;
    final fonte = _semTags(_tag(corpo, 'source')).trim();
    final data = _dataCurta(_tag(corpo, 'pubDate'));
    final resumo = _semTags(_tag(corpo, 'description')).trim();
    final tituloLimpo = _semSufixoDaFonte(titulo, fonte);
    itens.add(ItemPalco(
      tipo: TipoPalco.noticia,
      titulo: tituloLimpo.isEmpty ? titulo : tituloLimpo,
      url: link,
      resumo: resumo == titulo ? '' : resumo,
      fonte: fonte.isEmpty ? 'Google Notícias' : fonte,
      detalhe: data,
    ));
  }
  return itens;
}

/// Tira o “ - Fonte” que o Google acrescenta ao título, quando a fonte é a mesma.
String _semSufixoDaFonte(String titulo, String fonte) {
  if (fonte.isEmpty) return titulo;
  final sufixo = ' - $fonte';
  if (titulo.toLowerCase().endsWith(sufixo.toLowerCase())) {
    return titulo.substring(0, titulo.length - sufixo.length).trim();
  }
  return titulo;
}

/// Lê a busca pública de vídeos do Dailymotion.
List<ItemPalco> lerVideosDoDailymotion(String corpo) {
  late final Object? dados;
  try {
    dados = jsonDecode(corpo);
  } on FormatException {
    return const [];
  }
  if (dados is! Map) return const [];
  final lista = dados['list'];
  if (lista is! List) return const [];
  final itens = <ItemPalco>[];
  for (final bruto in lista) {
    if (bruto is! Map) continue;
    final titulo = (bruto['title']?.toString() ?? '').trim();
    final url = (bruto['url']?.toString() ?? '').trim();
    if (titulo.isEmpty || !linkSeguro(url)) continue;
    itens.add(ItemPalco(
      tipo: TipoPalco.video,
      titulo: titulo,
      url: url,
      miniatura: (bruto['thumbnail_480_url'] ?? '').toString(),
      fonte: 'Dailymotion',
      detalhe: _duracao(bruto['duration']),
    ));
  }
  return itens;
}

/// “183” segundos vira “3 min 03 s”.
String _duracao(Object? bruto) {
  final segundos = bruto is num ? bruto.toInt() : int.tryParse('$bruto') ?? 0;
  if (segundos <= 0) return '';
  final minutos = segundos ~/ 60;
  final resto = segundos % 60;
  if (minutos == 0) return '$resto s';
  return '$minutos min ${resto.toString().padLeft(2, '0')} s';
}

/// Data curta do RSS em pt-BR; vazio quando não dá para ler.
String _dataCurta(String bruto) {
  final texto = bruto.trim();
  final data = DateTime.tryParse(texto) ?? _dataDoRss(texto);
  if (data == null) return '';
  const meses = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];
  final local = data.toLocal();
  return '${local.day} ${meses[local.month - 1]} ${local.year}';
}

/// O RSS do Google usa RFC 822 (“Sun, 22 Nov 2026 10:30:00 GMT”), formato que
/// `DateTime.tryParse` não lê. Aqui é o bastante para a data curta da notícia.
DateTime? _dataDoRss(String bruto) {
  final achado = RegExp(
          r'(\d{1,2})\s+([A-Za-z]{3})\.?\s+(\d{4})(?:\s+(\d{1,2}):(\d{2}))?')
      .firstMatch(bruto);
  if (achado == null) return null;
  const meses = {
    'jan': 1,
    'fev': 2,
    'feb': 2,
    'mar': 3,
    'abr': 4,
    'apr': 4,
    'mai': 5,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'ago': 8,
    'aug': 8,
    'set': 9,
    'sep': 9,
    'out': 10,
    'oct': 10,
    'nov': 11,
    'dez': 12,
    'dec': 12,
  };
  final mes = meses[achado.group(2)!.toLowerCase()];
  if (mes == null) return null;
  return DateTime(
    int.parse(achado.group(3)!),
    mes,
    int.parse(achado.group(1)!),
    int.tryParse(achado.group(4) ?? '') ?? 0,
    int.tryParse(achado.group(5) ?? '') ?? 0,
  );
}

String _tag(String corpo, String nome) {
  final achado = RegExp(
    '<$nome\\b[^>]*>(.*?)</$nome>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(corpo);
  return achado?.group(1) ?? '';
}

/// Remove tags e decodifica as entidades que o RSS usa.
String _semTags(String bruto) => decodificarEntidades(
      bruto.replaceAll(RegExp(r'<[^>]*>'), ' '),
    ).replaceAll(RegExp(r'\s+'), ' ').trim();

/// Entidades nomeadas e numéricas, em texto simples.
String decodificarEntidades(String texto) {
  var saida = texto
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&nbsp;', ' ');
  saida = saida.replaceAllMapped(RegExp(r'&#(\d+);'), (achado) {
    final codigo = int.tryParse(achado.group(1) ?? '');
    if (codigo == null || codigo <= 0 || codigo > 0x10FFFF) return ' ';
    return String.fromCharCode(codigo);
  });
  saida = saida.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (achado) {
    final codigo = int.tryParse(achado.group(1) ?? '', radix: 16);
    if (codigo == null || codigo <= 0 || codigo > 0x10FFFF) return ' ';
    return String.fromCharCode(codigo);
  });
  return saida;
}

/// Item direto quando o pedido já é um endereço: o palco não pesquisa à toa.
///
/// Imagem por extensão vira imagem; vídeo do YouTube/Dailymotion vira vídeo;
/// qualquer outro link é exibido como notícia/página.
ItemPalco? itemDeLink(String texto) {
  final achado = RegExp(r'https?://[^\s<>"]+').firstMatch(texto);
  if (achado == null) return null;
  final url = achado.group(0)!;
  if (!linkSeguro(url)) return null;
  final limpo = url.toLowerCase().split('?').first;
  final ehImagem = RegExp(r'\.(png|jpe?g|gif|webp|bmp|avif)$').hasMatch(limpo);
  final ehVideo = limpo.contains('youtube.com/watch') ||
      limpo.contains('youtu.be/') ||
      limpo.contains('dailymotion.com/video') ||
      limpo.contains('vimeo.com/');
  if (ehImagem) {
    return ItemPalco(
      tipo: TipoPalco.imagem,
      titulo: 'Imagem do link',
      url: url,
      miniatura: url,
      fonte: 'Link informado',
    );
  }
  if (ehVideo) {
    return ItemPalco(
      tipo: TipoPalco.video,
      titulo: 'Vídeo do link',
      url: url,
      fonte: 'Link informado',
      detalhe: 'Abre no navegador',
    );
  }
  return ItemPalco(
    tipo: TipoPalco.noticia,
    titulo: 'Página do link',
    url: url,
    fonte: 'Link informado',
  );
}
