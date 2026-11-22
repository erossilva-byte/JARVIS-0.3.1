import 'dart:convert';

/// Extrai o texto incremental de um fluxo SSE no formato usado pelos provedores compatíveis
/// com OpenAI (`data: {"choices":[{"delta":{"content":"..."}}]}`).
///
/// O fluxo chega em pedaços que não respeitam linha: um pedaço pode cortar uma linha no meio.
/// Por isso o parser guarda o resto e só interpreta linhas completas.
class SseParser {
  SseParser({this.aoErro});

  /// Recebe o motivo quando uma linha `data:` vem malformada. O chamador decide se registra.
  final void Function(String motivo)? aoErro;

  String _resto = '';

  /// Consome um pedaço do fluxo e devolve os textos completos que já podem ser exibidos.
  List<String> alimentar(String pedaco) {
    if (pedaco.isEmpty) {
      return const [];
    }
    _resto += pedaco;
    final textos = <String>[];
    while (true) {
      final corte = _resto.indexOf('\n');
      if (corte < 0) {
        break;
      }
      final linha = _resto.substring(0, corte).trimRight();
      _resto = _resto.substring(corte + 1);
      final texto = _linha(linha);
      if (texto != null) {
        textos.add(texto);
      }
    }
    return textos;
  }

  String? _linha(String linha) {
    if (!linha.startsWith('data:')) {
      // `event:`, `id:`, comentários `:` e linhas vazias não carregam texto.
      return null;
    }
    final dados = linha.substring(5).trim();
    if (dados.isEmpty || dados == '[DONE]') {
      return null;
    }
    try {
      final json = jsonDecode(dados);
      if (json is! Map) {
        return null;
      }
      final escolhas = json['choices'];
      if (escolhas is! List || escolhas.isEmpty) {
        return null;
      }
      final primeira = escolhas.first;
      if (primeira is! Map) {
        return null;
      }
      // Streaming normal.
      final delta = primeira['delta'];
      if (delta is Map && delta['content'] is String) {
        final texto = delta['content'] as String;
        return texto.isEmpty ? null : texto;
      }
      // Provedor que respondeu sem streaming, mas com o mesmo envelope.
      final mensagem = primeira['message'];
      if (mensagem is Map && mensagem['content'] is String) {
        final texto = mensagem['content'] as String;
        return texto.isEmpty ? null : texto;
      }
      return null;
    } catch (_) {
      aoErro?.call('linha de streaming inválida');
      return null;
    }
  }
}
