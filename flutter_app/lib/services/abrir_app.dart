import '../core/pedido_app.dart';
import 'aparelho_service.dart';

/// Resultado de abrir um app já numa ação pedida por texto ou voz.
class ResultadoAppAcao {
  const ResultadoAppAcao({
    required this.ok,
    required this.mensagem,
    required this.acao,
  });

  final bool ok;
  final String mensagem;
  final String acao;
}

/// Abre o app de terceiro já na conversa, no rascunho, na busca ou na rota.
///
/// A regra de fala vem do núcleo puro ([pedidoAppComAcao]); aqui só se chama o
/// Android e se traduz a resposta. Devolve `null` quando o texto não é um
/// pedido deste tipo, para a conversa continuar o caminho dela.
class AbrirAppComAcao {
  AbrirAppComAcao._();

  static Future<ResultadoAppAcao?> executar(
    String texto, {
    AparelhoService? aparelho,
  }) async {
    final pedido = pedidoAppComAcao(texto);
    if (pedido == null) return null;
    try {
      final resposta = await (aparelho ?? AparelhoService())
          .abrirComAcao(pedido);
      return ResultadoAppAcao(
        ok: resposta.ok,
        mensagem: resposta.mensagem.trim().isEmpty
            ? 'O Android não confirmou a abertura do ${pedido.app.rotulo}.'
            : resposta.mensagem,
        acao: pedido.resumo,
      );
    } on AparelhoIndisponivel catch (erro) {
      return ResultadoAppAcao(
          ok: false, mensagem: erro.mensagem, acao: pedido.resumo);
    } catch (_) {
      return ResultadoAppAcao(
        ok: false,
        acao: pedido.resumo,
        mensagem: 'Não foi possível abrir ${pedido.app.rotulo} agora.',
      );
    }
  }
}
