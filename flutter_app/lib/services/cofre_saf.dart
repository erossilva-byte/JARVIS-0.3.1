import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Pasta do sistema escolhida pelo usuário (SAF no Android).
class PastaSaf {
  const PastaSaf({required this.uri, required this.nome});

  final String uri;
  final String nome;

  static PastaSaf? deMapa(Object? dados) {
    if (dados is! Map) return null;
    final uri = dados['uri'];
    final nome = dados['nome'];
    if (uri is! String || uri.isEmpty) return null;
    return PastaSaf(uri: uri, nome: nome is String && nome.trim().isNotEmpty ? nome.trim() : 'Pasta do Obsidian');
  }
}

/// Nota lida da pasta, com o caminho relativo dentro dela.
class NotaSaf {
  const NotaSaf({required this.nome, required this.caminho, required this.conteudo});

  final String nome;
  final String caminho;
  final String conteudo;

  static NotaSaf? deMapa(Object? dados) {
    if (dados is! Map) return null;
    final nome = dados['nome'];
    final caminho = dados['caminho'];
    final conteudo = dados['conteudo'];
    if (nome is! String || conteudo is! String) return null;
    return NotaSaf(
      nome: nome,
      caminho: caminho is String && caminho.isNotEmpty ? caminho : nome,
      conteudo: conteudo,
    );
  }
}

/// Resultado da leitura da pasta: o que entrou e o que foi recusado pelo caminho.
class LeituraSaf {
  const LeituraSaf({required this.notas, this.ignoradas = 0, this.truncadas = 0});

  final List<NotaSaf> notas;
  final int ignoradas;
  final int truncadas;

  static LeituraSaf? deMapa(Object? dados) {
    if (dados is! Map) return null;
    final brutas = dados['notas'];
    if (brutas is! List) return null;
    final notas = brutas.map(NotaSaf.deMapa).whereType<NotaSaf>().toList();
    int inteiro(Object? valor) => valor is int && valor >= 0 ? valor : 0;
    return LeituraSaf(
      notas: notas,
      ignoradas: inteiro(dados['ignoradas']),
      truncadas: inteiro(dados['truncadas']),
    );
  }
}

/// Resultado explícito: nunca inventa sucesso quando a plataforma não respondeu.
class ResultadoSaf<T> {
  const ResultadoSaf.ok(this.valor) : erro = null;
  const ResultadoSaf.falha(this.erro) : valor = null;

  final T? valor;
  final String? erro;

  bool get ok => erro == null;
}

/// Leitura da pasta do Obsidian via SAF.
///
/// A permissão é pedida pelo Kotlin com `takePersistableUriPermission` e reconferida a cada
/// abertura; se o sistema revogar, a pasta deixa de aparecer em vez de falhar em silêncio.
/// Fora do Android o canal não existe: a tela explica que o recurso é do aparelho.
class CofreSaf {
  CofreSaf._();

  static const canal = MethodChannel('com.jarvis.nova/memoria');

  static const mensagemIndisponivel =
      'A leitura da pasta do Obsidian só existe no Android; nesta plataforma use a importação de Markdown.';

  /// Fora do Android o canal nem é chamado: evita confundir "plataforma sem recurso" com
  /// "usuário cancelou a escolha", que na resposta do canal são ambos nulos.
  static bool get disponivel => defaultTargetPlatform == TargetPlatform.android;

  static Future<ResultadoSaf<PastaSaf?>> pastaAtual() async {
    if (!disponivel) return const ResultadoSaf.falha(mensagemIndisponivel);
    try {
      return ResultadoSaf.ok(PastaSaf.deMapa(await canal.invokeMethod<Object?>('pastaAtual')));
    } on MissingPluginException {
      return const ResultadoSaf.falha(mensagemIndisponivel);
    } on PlatformException catch (erro) {
      return ResultadoSaf.falha(erro.message ?? 'Não foi possível consultar a pasta conectada.');
    }
  }

  /// Abre o seletor do sistema. `ok` com valor nulo significa que o usuário cancelou.
  static Future<ResultadoSaf<PastaSaf?>> escolherPasta() async {
    if (!disponivel) return const ResultadoSaf.falha(mensagemIndisponivel);
    try {
      return ResultadoSaf.ok(PastaSaf.deMapa(await canal.invokeMethod<Object?>('escolherPasta')));
    } on MissingPluginException {
      return const ResultadoSaf.falha(mensagemIndisponivel);
    } on PlatformException catch (erro) {
      return ResultadoSaf.falha(erro.message ?? 'O seletor de pasta não concluiu a escolha.');
    }
  }

  static Future<ResultadoSaf<LeituraSaf>> listarNotas() async {
    if (!disponivel) return const ResultadoSaf.falha(mensagemIndisponivel);
    try {
      final leitura = LeituraSaf.deMapa(await canal.invokeMethod<Object?>('listarNotas'));
      if (leitura == null) {
        return const ResultadoSaf.falha('A pasta respondeu em formato inesperado; nada foi importado.');
      }
      return ResultadoSaf.ok(leitura);
    } on MissingPluginException {
      return const ResultadoSaf.falha(mensagemIndisponivel);
    } on PlatformException catch (erro) {
      return ResultadoSaf.falha(erro.message ?? 'Não foi possível ler a pasta do Obsidian.');
    }
  }

  static Future<ResultadoSaf<bool>> esquecerPasta() async {
    if (!disponivel) return const ResultadoSaf.falha(mensagemIndisponivel);
    try {
      await canal.invokeMethod<void>('esquecerPasta');
      return const ResultadoSaf.ok(true);
    } on MissingPluginException {
      return const ResultadoSaf.falha(mensagemIndisponivel);
    } on PlatformException catch (erro) {
      return ResultadoSaf.falha(erro.message ?? 'Não foi possível desconectar a pasta.');
    }
  }
}
