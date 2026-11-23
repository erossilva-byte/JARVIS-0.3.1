import 'dart:io';

import 'package:jarvis_nova/core/palco.dart';

void main() {
  // 1. Pedido de imagem, vídeo e notícia — com o assunto limpo.
  final imagem = pedidoPalco('mostra fotos de motor trifásico');
  assert(imagem != null, 'pedido de imagem não reconhecido');
  final pedidoImagem = imagem!;
  assert(pedidoImagem.tipo == TipoPalco.imagem, 'tipo errado para imagem');
  assert(pedidoImagem.consulta == 'motor trifásico',
      'consulta deveria ser “motor trifásico”, veio “${pedidoImagem.consulta}”');

  final video = pedidoPalco('me mostra um vídeo sobre partida direta');
  assert(video != null, 'vídeo não reconhecido');
  final pedidoVideo = video!;
  assert(pedidoVideo.tipo == TipoPalco.video, 'tipo errado para vídeo');
  assert(pedidoVideo.consulta == 'partida direta',
      'consulta do vídeo veio “${pedidoVideo.consulta}”');

  final noticia = pedidoPalco('traz as últimas notícias de tecnologia');
  assert(noticia != null && noticia.tipo == TipoPalco.noticia,
      'notícia não reconhecida');

  final curto = pedidoPalco('ver imagens de gato');
  assert(curto != null, '“ver imagens” não reconhecido');
  final pedidoCurto = curto!;
  assert(pedidoCurto.tipo == TipoPalco.imagem, 'tipo errado no pedido curto');
  assert(pedidoCurto.consulta == 'gato',
      'consulta veio “${pedidoCurto.consulta}”');

  // 2. Conversa comum não abre o palco.
  for (final texto in [
    'qual a capital da França',
    'aumenta o volume',
    'bom dia',
    'mostra o volume atual',
    'quero saber sobre motores',
  ]) {
    assert(pedidoPalco(texto) == null, 'palco abriu à toa em: $texto');
  }

  // 3. Endereços: sem chave, com o termo codificado.
  assert(
      urlDeBuscaImagens('motor elétrico')
          .startsWith('https://commons.wikimedia.org/w/api.php'),
      'URL de imagens errada');
  assert(urlDeBuscaImagens('motor elétrico').contains('motor%20el%C3%A9trico'),
      'consulta de imagem não foi codificada');
  assert(
      urlDeBuscaNoticias('eleições')
          .startsWith('https://news.google.com/rss/search'),
      'URL de notícias errada');
  assert(urlDeBuscaVideos('aula').startsWith('https://api.dailymotion.com/'),
      'URL de vídeos errada');
  for (final url in [
    urlDeBuscaImagens('x'),
    urlDeBuscaNoticias('x'),
    urlDeBuscaVideos('x'),
  ]) {
    assert(!url.contains('api_key') && !url.contains('token'),
        'endereço do palco pede chave: $url');
  }

  // 4. Leitor da Wikimedia (formato novo, lista).
  const commons = '''
{"query":{"pages":[
 {"title":"File:Motor eletrico 01.jpg","imageinfo":[{"mime":"image/jpeg",
  "thumburl":"https://upload.wikimedia.org/a.jpg",
  "descriptionurl":"https://commons.wikimedia.org/wiki/File:Motor.jpg",
  "extmetadata":{"Artist":{"value":"<b>Fulano</b>"}}}]},
 {"title":"File:Diagrama.svg","imageinfo":[{"mime":"image/svg+xml",
  "thumburl":"https://upload.wikimedia.org/b.svg",
  "descriptionurl":"https://commons.wikimedia.org/wiki/File:Diagrama.svg"}]},
 {"title":"File:Audio.ogg","imageinfo":[{"mime":"audio/ogg",
  "thumburl":"https://upload.wikimedia.org/c.ogg"}]}
]}}''';
  final imagens = lerImagensDoCommons(commons);
  assert(imagens.length == 2,
      'deveriam sobrar 2 imagens, achei ${imagens.length}');
  assert(imagens.first.titulo == 'Motor eletrico 01',
      'título não foi limpo: ${imagens.first.titulo}');
  assert(imagens.first.miniatura == 'https://upload.wikimedia.org/a.jpg',
      'miniatura errada');
  assert(imagens.first.resumo.contains('Fulano'), 'crédito não foi lido');
  assert(imagens.first.resumo.contains('<b>') == false, 'crédito manteve HTML');

  // Formato antigo (mapa por página) continua sendo lido.
  const commonsAntigo = '''
{"query":{"pages":{"1":{"title":"File:Painel.jpg","imageinfo":[
 {"mime":"image/jpeg","url":"https://upload.wikimedia.org/p.jpg"}]}}}}''';
  assert(lerImagensDoCommons(commonsAntigo).length == 1,
      'formato antigo da Wikimedia não foi lido');

  // 5. Leitor do RSS de notícias.
  const rss = '''
<rss><channel><item>
<title>Nova regra de segurança &amp; norma - G1</title>
<link>https://g1.globo.com/economia/noticia/abc.ghtml</link>
<source url="https://g1.globo.com">G1</source>
<pubDate>Sun, 22 Nov 2026 10:30:00 GMT</pubDate>
<description><![CDATA[<a href="x">Resumo</a> da matéria &amp; detalhe]]></description>
</item><item><title>Sem link</title></item></channel></rss>''';
  final noticias = lerNoticiasDoRss(rss);
  assert(noticias.length == 1,
      'deveria sobrar 1 notícia, achei ${noticias.length}');
  assert(noticias.first.titulo == 'Nova regra de segurança & norma',
      'título da notícia veio “${noticias.first.titulo}”');
  assert(noticias.first.fonte == 'G1', 'fonte da notícia errada');
  assert(noticias.first.url.startsWith('https://g1.globo.com/'), 'link errado');
  assert(noticias.first.resumo.contains('Resumo'), 'resumo não foi lido');
  assert(!noticias.first.resumo.contains('<a'), 'resumo manteve HTML');
  assert(noticias.first.detalhe.contains('22 nov 2026'),
      'data veio “${noticias.first.detalhe}”');

  // 6. Leitor do Dailymotion.
  const videos = '''
{"list":[
 {"id":"x1","title":"Motor elétrico","url":"https://www.dailymotion.com/video/x1",
  "thumbnail_480_url":"https://s2.dmcdn.net/x1","duration":183},
 {"id":"x2","title":"","url":"https://www.dailymotion.com/video/x2"}
]}''';
  final achados = lerVideosDoDailymotion(videos);
  assert(
      achados.length == 1, 'deveria sobrar 1 vídeo, achei ${achados.length}');
  assert(achados.first.detalhe == '3 min 03 s',
      'duração veio “${achados.first.detalhe}”');
  assert(achados.first.miniatura == 'https://s2.dmcdn.net/x1', 'capa errada');

  // 7. Pedido vindo da voz de fundo: tipo pronto do Android ou inferido.
  final voz = pedidoDePalcoVoz('imagem', 'motor trifásico');
  assert(voz != null && voz.tipo == TipoPalco.imagem,
      'tipo imagem da voz não foi aceito');
  assert(voz!.consulta == 'motor trifásico', 'consulta da voz foi alterada');
  assert(pedidoDePalcoVoz('video', 'partida direta')?.tipo == TipoPalco.video,
      'tipo vídeo da voz não foi aceito');
  assert(pedidoDePalcoVoz('noticia', 'eleições')?.tipo == TipoPalco.noticia,
      'tipo notícia da voz não foi aceito');
  assert(pedidoDePalcoVoz('', 'mostra fotos de gato')?.tipo == TipoPalco.imagem,
      'tipo ausente deveria ser inferido do texto');
  assert(pedidoDePalcoVoz('imagem', '   ') == null,
      'pedido de voz sem assunto deveria ser recusado');
  assert(pedidoDePalcoVoz('', 'qual a capital da França') == null,
      'texto sem mídia não deveria virar palco');

  // 8. Link direto: imagem, vídeo e página — sem pesquisa.
  final direto = itemDeLink('olha https://exemplo.com/foto.png agora');
  assert(direto != null && direto.tipo == TipoPalco.imagem,
      'link de imagem não foi reconhecido');
  final videoDireto = itemDeLink('https://youtu.be/abc123');
  assert(videoDireto != null && videoDireto.tipo == TipoPalco.video,
      'link de vídeo não foi reconhecido');
  final pagina = itemDeLink('https://g1.globo.com/materia');
  assert(pagina != null && pagina.tipo == TipoPalco.noticia,
      'link comum não virou página');
  assert(itemDeLink('sem link aqui') == null, 'texto sem link virou item');

  // 9. Só http/https passa.
  assert(linkSeguro('https://a.com') && linkSeguro('http://a.com'),
      'http(s) deveria passar');
  for (final ruim in ['javascript:alert(1)', 'file:///etc/passwd', 'ftp://x']) {
    assert(!linkSeguro(ruim), 'esquema perigoso passou: $ruim');
  }

  // 10. Entidades e descrição do pedido.
  assert(decodificarEntidades('a &amp; b &#233; &#x41;') == 'a & b é A',
      'entidades não foram decodificadas');
  assert(descricaoDoPedido(pedidoImagem).contains('Wikimedia'),
      'descrição não cita a fonte');

  stdout.writeln('OK: palco — pedido, endereços sem chave, leitores das três '
      'fontes e links seguros.');
}
