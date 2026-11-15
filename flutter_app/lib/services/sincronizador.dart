import '../core/memoria.dart';
import '../core/memoria_sync.dart';
import 'cofre_saf.dart';
import 'memoria_store.dart';

/// O que a sincronização precisa da pasta. A interface existe para testar sem Android.
abstract interface class CofreRemoto {
  Future<ResultadoSaf<LeituraSaf>> listarNotas();

  Future<ResultadoSaf<bool>> escreverNota({required String caminho, required String conteudo});
}

class CofreSafGateway implements CofreRemoto {
  const CofreSafGateway();

  @override
  Future<ResultadoSaf<LeituraSaf>> listarNotas() => CofreSaf.listarNotas();

  @override
  Future<ResultadoSaf<bool>> escreverNota({required String caminho, required String conteudo}) =>
      CofreSaf.escreverNota(caminho: caminho, conteudo: conteudo);
}

/// Resultado observável: o que foi escrito, o que foi lido, o que ficou em conflito.
class ResultadoSincronizacao {
  ResultadoSincronizacao({PlanoSync? plano, this.erroGeral})
      : plano = plano ?? PlanoSync();

  final PlanoSync plano;
  final String? erroGeral;
  final List<String> enviadas = [];
  final List<String> recebidas = [];
  final List<String> marcadas = [];
  final List<String> falhas = [];

  bool get ok => erroGeral == null;

  String get resumo {
    final partes = <String>[
      '${enviadas.length} enviada(s)',
      '${recebidas.length} recebida(s)',
      '${plano.iguais} já igual(is)',
      if (plano.conflitos.isNotEmpty) '${plano.conflitos.length} conflito(s) preservado(s)',
      if (plano.ausentesNaPasta.isNotEmpty) '${plano.ausentesNaPasta.length} nota(s) só neste aparelho',
      if (plano.caminhosDuplicados.isNotEmpty) '${plano.caminhosDuplicados.length} arquivo(s) repetido(s) na pasta',
      if (falhas.isNotEmpty) '${falhas.length} falha(s)',
    ];
    return partes.join(', ');
  }
}

/// Concilia o cofre local com a pasta do Obsidian, nos dois sentidos.
///
/// Quem decide é `planejarSincronizacao`, que nunca apaga: quando não dá para saber quem mudou,
/// a nota fica em conflito e os dois lados permanecem como estão.
class Sincronizador {
  Sincronizador({required this.store, required this.cofre, DateTime Function()? agora}) : _agora = agora ?? DateTime.now;

  final MemoriaStore store;
  final CofreRemoto cofre;
  final DateTime Function() _agora;

  Future<ResultadoSincronizacao> sincronizar() async {
    final leitura = await cofre.listarNotas();
    if (!leitura.ok) return ResultadoSincronizacao(erroGeral: leitura.erro);
    final arquivos = [
      for (final nota in leitura.valor!.notas) ArquivoRemoto(caminho: nota.caminho, conteudo: nota.conteudo),
    ];
    final plano = planejarSincronizacao(store.listar(), arquivos, agora: _agora());
    final resultado = ResultadoSincronizacao(plano: plano);

    for (final envio in plano.envios) {
      final escrita = await cofre.escreverNota(caminho: envio.caminho, conteudo: envio.conteudo);
      if (!escrita.ok) {
        resultado.falhas.add('${envio.caminho}: ${escrita.erro}');
        continue;
      }
      await store.salvar(envio.nota.copiarCom(
        caminho: envio.caminho,
        hashSincronizado: hashConteudo(envio.nota.texto.trim()),
      ));
      resultado.enviadas.add(envio.caminho);
    }

    for (final recebida in plano.recebidas) {
      await store.salvar(recebida.nota);
      resultado.recebidas.add(recebida.caminho);
    }

    for (final nota in plano.marcar) {
      final caminho = nota.caminho ?? caminhoParaTitulo(nota.titulo);
      await store.salvar(nota.copiarCom(caminho: caminho, hashSincronizado: hashConteudo(nota.texto.trim())));
      resultado.marcadas.add(caminho);
    }

    return resultado;
  }
}
