import '../core/memoria.dart';
import '../core/memoria_conflito.dart';
import '../core/memoria_sync.dart';
import 'memoria_store.dart';
import 'sincronizador.dart';

class ResultadoResolucao {
  const ResultadoResolucao.ok({this.backup, this.enviado = false})
      : erro = null;

  const ResultadoResolucao.falha(this.erro)
      : backup = null,
        enviado = false;

  final String? erro;
  final NotaMemoria? backup;
  final bool enviado;

  bool get ok => erro == null;
}

/// Aplica a escolha do usuário num conflito.
///
/// Quando o aparelho vence, o arquivo da pasta é reescrito antes de mexer no cofre; se a escrita
/// falhar, nada muda e o usuário pode tentar de novo. Em qualquer escolha a versão perdedora é
/// salva como nota própria, sem caminho, para não sobrescrever o arquivo em disputa.
class ResolvedorConflito {
  ResolvedorConflito(
      {required this.store, required this.cofre, DateTime Function()? agora})
      : _agora = agora ?? DateTime.now;

  final MemoriaStore store;
  final CofreRemoto cofre;
  final DateTime Function() _agora;

  Future<ResultadoResolucao> resolver(
      ConflitoSync conflito, DecisaoConflito decisao) async {
    final PlanoResolucao plano;
    try {
      plano = planejarResolucao(conflito, decisao, agora: _agora());
    } on ArgumentError catch (erro) {
      return ResultadoResolucao.falha(erro.message);
    }

    final envio = plano.envio;
    if (envio != null) {
      final escrita = await cofre.escreverNota(
          caminho: envio.caminho, conteudo: envio.conteudo);
      if (!escrita.ok) {
        return ResultadoResolucao.falha(
          'A versão do aparelho não foi gravada na pasta (${escrita.erro}); as duas versões continuam como estavam.',
        );
      }
    }

    await store.salvar(plano.backup);
    await store.salvar(plano.notaOficial);
    return ResultadoResolucao.ok(backup: plano.backup, enviado: envio != null);
  }
}
