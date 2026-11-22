import 'package:flutter/services.dart';

import '../core/aparelho.dart';
import '../core/dispositivo.dart';
import '../core/localizacao.dart';

/// Ponte com o Android para as capacidades do aparelho.
///
/// Fora do Android (testes, Windows) o canal não existe: cada chamada devolve
/// erro explicado e a tela continua funcionando. Nada aqui declara sucesso sem
/// a resposta nativa.
class AparelhoService {
  AparelhoService({MethodChannel? canal})
      : _canal = canal ?? const MethodChannel('com.jarvis.nova/aparelho');

  final MethodChannel _canal;

  Future<Map<Object?, Object?>?> _chamar(
      String metodo, [Map<String, Object?> argumentos = const {}]) async {
    try {
      return await _canal
          .invokeMapMethod<Object?, Object?>(metodo, argumentos);
    } on MissingPluginException {
      throw const AparelhoIndisponivel(
          'Este aparelho não tem a ponte do Jarvis para os recursos do Android.');
    } on PlatformException catch (erro) {
      throw AparelhoIndisponivel(
          erro.message?.trim().isNotEmpty == true
              ? erro.message!
              : 'O Android recusou a ação.');
    }
  }

  Future<EstadoAparelho> status() async {
    final dados = await _chamar('status');
    return EstadoAparelho.deMapa(dados) ?? const EstadoAparelho();
  }

  /// Memória, armazenamento, bateria, rede e apps instalados, tudo do Android.
  Future<InfoDispositivo> infoDispositivo() async =>
      InfoDispositivo.deMapa(await _chamar('dispositivoInfo'));

  /// Abre o app pelo pacote e informa o que aconteceu de verdade.
  Future<ResultadoAparelho> abrirApp(String pacote) async =>
      ResultadoAparelho.deMapa(
          await _chamar('abrirApp', {'pacote': pacote}));

  Future<bool> temAcessoNotificacoes() async {
    final dados = await _chamar('notificacoesAcesso');
    return dados?['ativo'] == true;
  }

  Future<ResultadoAparelho> abrirAjustesNotificacoes() async =>
      ResultadoAparelho.deMapa(await _chamar('abrirAjustesNotificacoes'));

  Future<List<NotificacaoAparelho>> notificacoes({int limite = 30}) async {
    final dados = await _chamar('notificacoes', {'limite': limite});
    final lista = dados?['itens'];
    if (lista is! List) return const [];
    return lista
        .map(NotificacaoAparelho.deMapa)
        .whereType<NotificacaoAparelho>()
        .toList();
  }

  Future<ResultadoAparelho> limparNotificacoes() async =>
      ResultadoAparelho.deMapa(await _chamar('limparNotificacoes'));

  /// Responde pela propria notificacao (RemoteInput), sem abrir o app de
  /// mensagens. [chave] vem de [NotificacaoAparelho.chave]; sem ela, o Android
  /// usa a mensagem respondivel mais recente do [pacote].
  Future<ResultadoAparelho> responderNotificacao({
    required String texto,
    String chave = '',
    String? pacote,
  }) async {
    if (texto.trim().isEmpty) {
      return const ResultadoAparelho.erro(
          'Escreva a resposta antes de enviar.');
    }
    return ResultadoAparelho.deMapa(await _chamar('responderNotificacao', {
      'chave': chave,
      'pacote': pacote ?? '',
      'texto': texto.trim(),
    }));
  }

  /// Permissão e provedores de localização, sem pedir nenhuma leitura ainda.
  Future<EstadoLocalizacao> estadoLocalizacao() async =>
      EstadoLocalizacao.deMapa(await _chamar('localizacaoEstado'));

  /// Pede um ponto ao Android. Devolve a leitura, ou o motivo quando não dá.
  Future<LocalizacaoAparelho> localizacao() async =>
      LocalizacaoAparelho.deMapa(await _chamar('localizacao'));

  /// Ids dos apps de mensagem instalados, na ordem de [appsMensagem].
  Future<List<AppMensagem>> appsDisponiveis() async {
    final dados = await _chamar('appsMensagem');
    final lista = dados?['ids'];
    if (lista is List) {
      final ids = lista.whereType<String>().toSet();
      return appsMensagem.where((a) => ids.contains(a.id)).toList();
    }
    return const [];
  }

  Future<ResultadoAparelho> enviarMensagem(PedidoMensagem pedido) async {
    if (!pedido.pronto) {
      return const ResultadoAparelho.erro(
          'Informe o destinatário e o texto exato da mensagem.');
    }
    final dados = await _chamar('enviarMensagem', {
      'app': pedido.app.id,
      'destino': pedido.destino,
      'texto': pedido.texto,
    });
    return ResultadoAparelho.deMapa(dados);
  }

  Future<List<ContatoAparelho>> buscarContatos(String nome) async {
    final dados = await _chamar('buscarContatos', {'nome': nome});
    final lista = dados?['itens'];
    if (lista is! List) return const [];
    return lista.map(ContatoAparelho.deMapa).whereType<ContatoAparelho>().toList();
  }

  Future<ResultadoAparelho> ligar(String destino) async {
    if (destino.trim().isEmpty) {
      return const ResultadoAparelho.erro('Diga para quem ligar.');
    }
    return ResultadoAparelho.deMapa(
        await _chamar('ligar', {'destino': destino}));
  }

  Future<EstadoAparelho> spotifyEstado() async {
    final dados = await _chamar('spotifyEstado');
    final estado = EstadoAparelho.deMapa(dados?['estado']);
    return estado ?? const EstadoAparelho();
  }

  Future<ResultadoAparelho> spotify(PedidoSpotify pedido) async {
    final dados = await _chamar('spotify', {
      'acao': pedido.acao.name,
      'faixa': pedido.faixa,
      'uri': pedido.uri,
    });
    return ResultadoAparelho.deMapa(dados);
  }

  /// Traz o Jarvis para a frente, acende a tela e garante o microfone ativo.
  Future<ResultadoAparelho> ativarEmSegundoPlano() async =>
      ResultadoAparelho.deMapa(await _chamar('ativarEmSegundoPlano'));

  /// `microfone`, `contatos`, `sms`, `telefone`, `notificacoes` ou `localizacao`.
  Future<ResultadoAparelho> pedirPermissao(String recurso) async =>
      ResultadoAparelho.deMapa(
          await _chamar('pedirPermissao', {'recurso': recurso}));

  Future<ResultadoAparelho> abrirAjustes(String ajuste) async =>
      ResultadoAparelho.deMapa(await _chamar('abrirAjustes', {'ajuste': ajuste}));
}

class AparelhoIndisponivel implements Exception {
  const AparelhoIndisponivel(this.mensagem);
  final String mensagem;
  @override
  String toString() => mensagem;
}
