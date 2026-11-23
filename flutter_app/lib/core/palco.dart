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
    '(?:$palavras)?(?:\\s+(?:de|do|da|dos|das|sobre|com|em|no|na|'
    'nos|nas|para|pra|pelo|pela))?\\s*',
    caseSensitive: false,
  );
  saida = saida.replaceFirst(remover, '');
  // Sem verbo no começo: “fotos de gato” vira “gato”.
  saida = saida.replaceFirst(
    RegExp(
        '^(?:$palavras)\\s*(?:de|do|da|dos|das|sobre|com|em|no|na|'
        'nos|nas|para|pra)?\\s*',
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
    ));
  }
  return itens;
}

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

/// Data curta do RSS em pt-BR; texto original quando não dá para ler.
String _dataCurta(String bruto) {
  final data = DateTime.tryParse(bruto.trim());
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
