import '../core/pedido_apelido.dart';
import 'aparelho_service.dart';

/// Resultado de ensinar ou esquecer um apelido.
class ResultadoApelido {
  const ResultadoApelido({
    required this.ok,
    required this.mensagem,
    required this.acao,
  });

  final bool ok;
  final String mensagem;
  final String acao;
}

/// Ensina o Android a chamar um contato pelo apelido dito na conversa.
///
/// A regra de fala vem do núcleo puro ([pedidoApelido]); o vínculo com a agenda
/// e a gravação ficam no aparelho (`JarvisApelidos` + `JarvisContatos`), porque
/// é lá que o nome salvo está. Devolve `null` quando a frase é outra coisa.
class AprenderApelido {
  AprenderApelido._();

  static Future<ResultadoApelido?> executar(
    String texto, {
    AparelhoService? aparelho,
  }) async {
    final pedido = pedidoApelido(texto);
    if (pedido == null) return null;
    try {
      final resposta = await (aparelho ?? AparelhoService())
          .aprenderApelido(pedido);
      return ResultadoApelido(
        ok: resposta.ok,
        mensagem: resposta.mensagem.trim().isEmpty
            ? 'O aparelho não confirmou o apelido.'
            : resposta.mensagem,
        acao: pedido.resumo,
      );
    } on AparelhoIndisponivel catch (erro) {
      return ResultadoApelido(
          ok: false, mensagem: erro.mensagem, acao: pedido.resumo);
    } catch (_) {
      return ResultadoApelido(
        ok: false,
        acao: pedido.resumo,
        mensagem: 'Não foi possível guardar o apelido agora.',
      );
    }
  }
}
