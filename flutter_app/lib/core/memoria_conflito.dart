import 'memoria.dart';
import 'memoria_sync.dart';

/// Qual lado o usuário escolheu manter como oficial.
enum DecisaoConflito { aparelho, pasta }

/// O que fazer para resolver um conflito sem perder nenhuma das duas versões.
class PlanoResolucao {
  const PlanoResolucao({
    required this.notaOficial,
    required this.backup,
    required this.envio,
  });

  /// Nota local que passa a representar o caminho depois da escolha.
  final NotaMemoria notaOficial;

  /// A versão que perdeu, guardada como nota própria (sem caminho, para não sobrescrever nada).
  final NotaMemoria backup;

  /// Escrita necessária quando o lado do aparelho vence; nula quando a pasta já está certa.
  final EnvioNota? envio;
}

String _tituloBackup(String titulo, String origem) =>
    '$titulo (versão $origem)';

NotaMemoria _notaDeBackup({
  required NotaMemoria origem,
  required String titulo,
  required String texto,
  required DateTime agora,
  required String caminhoConflito,
}) =>
    NotaMemoria(
      id: 'conflito-${hashConteudo('$caminhoConflito|$titulo|${hashConteudo(texto)}')}',
      titulo: _tituloBackup(titulo, 'do conflito'),
      texto: texto,
      tema: origem.tema,
      tags: origem.tags,
      importancia: origem.importancia,
      criadaEm: agora,
      atualizadaEm: agora,
      extras: const {'origem': origemBackupConflito},
    );

/// Monta a resolução de um conflito. Nenhuma versão é descartada: a perdedora vira nota local
/// própria, sem caminho na pasta, então a próxima sincronização a envia como arquivo novo em vez
/// de sobrescrever o caminho que estava em disputa.
PlanoResolucao planejarResolucao(
  ConflitoSync conflito,
  DecisaoConflito decisao, {
  DateTime? agora,
}) {
  final quando = agora ?? DateTime.now();
  final local = conflito.local;
  if (local == null) {
    throw ArgumentError('conflito sem nota local não pode ser resolvido aqui');
  }
  final caminho = normalizarCaminho(conflito.remoto.caminho);
  final corpoRemoto = conflito.remoto.corpo;
  final hashRemoto = conflito.remoto.hash;

  if (decisao == DecisaoConflito.aparelho) {
    final oficial = local.copiarCom(
      caminho: caminho,
      hashSincronizado: hashConteudo(local.texto.trim()),
      atualizadaEm: quando,
    );
    return PlanoResolucao(
      notaOficial: oficial,
      backup: _notaDeBackup(
        origem: local,
        titulo: lerMarkdown(conflito.remoto.conteudo,
                tituloReserva: nomeSemExtensao(caminho))
            .titulo,
        texto: corpoRemoto,
        agora: quando,
        caminhoConflito: caminho,
      ),
      envio: EnvioNota(
        nota: oficial,
        caminho: caminho,
        conteudo: escreverMarkdown(oficial),
        novo: false,
      ),
    );
  }

  final tituloRemoto = lerMarkdown(conflito.remoto.conteudo,
          tituloReserva: nomeSemExtensao(caminho))
      .titulo;
  final oficial = local.copiarCom(
    titulo: tituloRemoto,
    texto: corpoRemoto,
    caminho: caminho,
    hashSincronizado: hashRemoto,
    atualizadaEm: quando,
  );
  return PlanoResolucao(
    notaOficial: oficial,
    backup: _notaDeBackup(
      origem: local,
      titulo: local.titulo,
      texto: local.texto,
      agora: quando,
      caminhoConflito: caminho,
    ),
    envio: null,
  );
}
