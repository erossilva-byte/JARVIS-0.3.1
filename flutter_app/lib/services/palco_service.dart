import 'dart:async';

import 'package:http/http.dart' as http;

import '../core/palco.dart';

/// Falha da pesquisa do palco, já traduzida para a tela.
///
/// Nunca carrega corpo bruto da resposta: só a frase que o usuário pode usar.
class PalcoException implements Exception {
  const PalcoException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Busca imagens, vídeos e notícias nas fontes públicas que não pedem chave.
///
/// Nenhuma conta é necessária: Wikimedia Commons, RSS do Google Notícias e a
/// API pública do Dailymotion. Se a fonte não responder ou mudar o formato, a
/// tela recebe [PalcoException] e diz o motivo — o palco nunca inventa
/// resultado.
class PalcoService {
  PalcoService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<ItemPalco>> buscar(PedidoPalco pedido) async {
    final direto = itemDeLink(pedido.consulta);
    if (direto != null) return [direto];
    final consulta = pedido.consulta.trim();
    if (consulta.length < 2) {
      throw const PalcoException(
          'Diga o que pesquisar, por exemplo: “mostra fotos de motor trifásico”.');
    }

    late http.Response resposta;
    try {
      resposta = await _client.get(
        Uri.parse(urlDoPedido(pedido)),
        headers: const {
          'Accept': 'application/json, application/rss+xml, text/xml, */*',
          'User-Agent': 'JARVIS-Nova/1.88.5 (app Android)',
        },
      ).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw PalcoException(
          'O ${pedido.tipo.fonte} demorou mais de 15 segundos para responder. '
          'Verifique a conexão e tente de novo.');
    } on http.ClientException {
      throw PalcoException(
          'Não foi possível alcançar o ${pedido.tipo.fonte}. Confira o '
          'Wi-Fi/5G e tente de novo.');
    } on ArgumentError {
      throw const PalcoException(
          'O endereço de pesquisa ficou inválido. Tente outras palavras.');
    }

    if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
      throw PalcoException(_mensagemHttp(pedido.tipo, resposta.statusCode));
    }

    final itens = switch (pedido.tipo) {
      TipoPalco.imagem => lerImagensDoCommons(resposta.body),
      TipoPalco.video => lerVideosDoDailymotion(resposta.body),
      TipoPalco.noticia => lerNoticiasDoRss(resposta.body),
    };
    if (itens.isEmpty) {
      throw PalcoException('O ${pedido.tipo.fonte} respondeu, mas não devolveu '
          '${pedido.tipo.rotulo.toLowerCase()} para “$consulta”. Tente outras '
          'palavras.');
    }
    return itens;
  }

  String _mensagemHttp(TipoPalco tipo, int status) {
    if (status == 429) {
      return 'O ${tipo.fonte} recusou por excesso de pedidos. Aguarde um '
          'minuto e tente de novo.';
    }
    if (status == 403) {
      return 'O ${tipo.fonte} recusou a consulta anônima. Tente de novo em '
          'alguns minutos.';
    }
    if (status >= 500) {
      return 'O ${tipo.fonte} está instável agora (HTTP $status). Tente mais '
          'tarde.';
    }
    return 'O ${tipo.fonte} não concluiu a pesquisa (HTTP $status).';
  }
}
