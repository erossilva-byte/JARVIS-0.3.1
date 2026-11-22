import 'memoria.dart';
import 'memoria_busca.dart';

/// Arquivo lido da pasta do Obsidian.
class ArquivoRemoto {
  ArquivoRemoto({required this.caminho, required this.conteudo})
      : corpo = lerMarkdown(conteudo, tituloReserva: nomeSemExtensao(caminho))
            .texto
            .trim();

  final String caminho;
  final String conteudo;

  /// Corpo sem frontmatter: é o que se compara com a nota local.
  final String corpo;

  String get hash => hashConteudo(corpo);
}

/// Nota local que vai para a pasta. `novo` diz se o arquivo ainda não existe lá.
class EnvioNota {
  const EnvioNota(
      {required this.nota,
      required this.caminho,
      required this.conteudo,
      required this.novo});

  final NotaMemoria nota;
  final String caminho;
  final String conteudo;
  final bool novo;
}

/// Arquivo da pasta que vira (ou atualiza) nota local.
class RecebidaNota {
  const RecebidaNota({required this.nota, required this.caminho});

  final NotaMemoria nota;
  final String caminho;
}

class ConflitoSync {
  const ConflitoSync({this.local, required this.remoto, required this.motivo});

  final NotaMemoria? local;
  final ArquivoRemoto remoto;
  final String motivo;

  String get titulo => remoto.caminho;
}

/// O que fazer numa sincronização. Nenhuma lista aqui apaga nota: o pior caso é conflito.
class PlanoSync {
  PlanoSync({
    List<EnvioNota>? envios,
    List<RecebidaNota>? recebidas,
    List<NotaMemoria>? marcar,
    List<ConflitoSync>? conflitos,
    List<NotaMemoria>? ausentesNaPasta,
    List<String>? caminhosDuplicados,
    this.iguais = 0,
  })  : envios = envios ?? [],
        recebidas = recebidas ?? [],
        marcar = marcar ?? [],
        conflitos = conflitos ?? [],
        ausentesNaPasta = ausentesNaPasta ?? [],
        caminhosDuplicados = caminhosDuplicados ?? [];

  final List<EnvioNota> envios;
  final List<RecebidaNota> recebidas;

  /// Notas cujo conteúdo já bate com a pasta: só adotam caminho e hash, sem escrita.
  final List<NotaMemoria> marcar;
  final List<ConflitoSync> conflitos;

  /// Nota local cujo arquivo sumiu da pasta. Continua intacta; nada é apagado sozinho.
  final List<NotaMemoria> ausentesNaPasta;
  final List<String> caminhosDuplicados;
  int iguais;

  bool get vazio =>
      envios.isEmpty &&
      recebidas.isEmpty &&
      marcar.isEmpty &&
      conflitos.isEmpty &&
      ausentesNaPasta.isEmpty;
}

String normalizarCaminho(String caminho) => caminho
    .replaceAll('\\', '/')
    .split('/')
    .where((parte) => parte.isNotEmpty)
    .join('/');

String nomeSemExtensao(String caminho) {
  final nome = normalizarCaminho(caminho).split('/').last;
  return nome.toLowerCase().endsWith('.md')
      ? nome.substring(0, nome.length - 3)
      : nome;
}

/// Nome de arquivo seguro para uma nota nova: sem acento, sem espaço e sem caractere proibido.
String caminhoParaTitulo(String titulo) {
  final base = normalizar(titulo)
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return '${base.isEmpty ? 'nota' : base}.md';
}

NotaMemoria _notaDeRemoto(ArquivoRemoto remoto, DateTime agora) {
  final lido = lerMarkdown(remoto.conteudo,
      tituloReserva: nomeSemExtensao(remoto.caminho));
  final importance =
      int.tryParse(lido.extras['importancia'] ?? '')?.clamp(0, 3) ?? 1;
  final tags = (lido.extras['tags'] ?? '')
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();
  return NotaMemoria(
    id: 'saf-${hashConteudo('${remoto.caminho}|${remoto.hash}')}',
    titulo: lido.titulo,
    texto: lido.texto,
    tema: temaValido(lido.extras['tema'] ?? 'contextos'),
    tags: tags,
    importancia: importance,
    criadaEm: agora,
    atualizadaEm: agora,
    caminho: remoto.caminho,
    hashSincronizado: remoto.hash,
    extras: Map<String, String>.from(lido.extras)
      ..removeWhere((chave, _) => const {
            'id',
            'titulo',
            'title',
            'nome',
            'tema',
            'tags',
            'importancia'
          }.contains(chave)),
  );
}

/// Decide o que fazer para conciliar cofre local e pasta, sem apagar nada.
///
/// Regras:
/// - conteúdo igual: nada a fazer (no máximo adotar caminho/hash);
/// - só no local: envia como arquivo novo; se já existe arquivo com o mesmo nome e conteúdo
///   diferente, vira conflito;
/// - só na pasta: importa como nota nova; se já existe nota local de mesmo título, conflito;
/// - nos dois: quem mudou desde o último hash é enviado/recebido; se as duas mudaram (ou nunca
///   sincronizaram e diferem), conflito, sem sobrescrever nenhum dos lados;
/// - nota local cujo arquivo sumiu: fica registrada como ausente, nada é apagado.
PlanoSync planejarSincronizacao(
  List<NotaMemoria> locais,
  List<ArquivoRemoto> remotos, {
  DateTime? agora,
}) {
  final quando = agora ?? DateTime.now();
  final plano = PlanoSync();
  final porCaminho = <String, ArquivoRemoto>{};
  for (final remoto in remotos) {
    final caminho = normalizarCaminho(remoto.caminho);
    if (porCaminho.containsKey(caminho)) {
      plano.caminhosDuplicados.add(caminho);
      continue;
    }
    porCaminho[caminho] = remoto;
  }

  final usados = <String>{};
  final locaisPorTitulo = <String, NotaMemoria>{};
  for (final nota in locais) {
    locaisPorTitulo.putIfAbsent(chaveTitulo(nota.titulo), () => nota);
  }

  for (final nota in locais) {
    final hashLocal = hashConteudo(nota.texto.trim());
    final caminhoDaNota =
        nota.caminho == null ? null : normalizarCaminho(nota.caminho!);

    if (caminhoDaNota != null) {
      final remoto = porCaminho[caminhoDaNota];
      if (remoto == null) {
        plano.ausentesNaPasta.add(nota);
        continue;
      }
      usados.add(caminhoDaNota);
      if (hashLocal == remoto.hash) {
        plano.iguais++;
        if (nota.hashSincronizado != remoto.hash) plano.marcar.add(nota);
        continue;
      }
      final base = nota.hashSincronizado;
      if (base != null && base == hashLocal) {
        plano.recebidas.add(RecebidaNota(
          nota: nota.copiarCom(
            titulo: lerMarkdown(remoto.conteudo,
                    tituloReserva: nomeSemExtensao(caminhoDaNota))
                .titulo,
            texto: remoto.corpo,
            atualizadaEm: quando,
            caminho: caminhoDaNota,
            hashSincronizado: remoto.hash,
          ),
          caminho: caminhoDaNota,
        ));
        continue;
      }
      if (base != null && base == remoto.hash) {
        plano.envios.add(EnvioNota(
          nota: nota,
          caminho: caminhoDaNota,
          conteudo: escreverMarkdown(nota),
          novo: false,
        ));
        continue;
      }
      plano.conflitos.add(ConflitoSync(
        local: nota,
        remoto: remoto,
        motivo: base == null
            ? 'as cópias nunca foram sincronizadas e o texto é diferente'
            : 'as duas cópias mudaram desde a última sincronização',
      ));
      continue;
    }

    // Nota local ainda sem caminho: destino pelo título.
    final alvo = caminhoParaTitulo(nota.titulo);
    final remoto = porCaminho[alvo];
    if (remoto != null) {
      usados.add(alvo);
      if (remoto.hash == hashLocal) {
        plano.iguais++;
        plano.marcar.add(nota);
      } else {
        plano.conflitos.add(ConflitoSync(
          local: nota,
          remoto: remoto,
          motivo: 'já existe arquivo com esse nome e conteúdo diferente',
        ));
      }
      continue;
    }
    plano.envios.add(EnvioNota(
      nota: nota,
      caminho: alvo,
      conteudo: escreverMarkdown(nota),
      novo: true,
    ));
  }

  for (final remoto in porCaminho.values) {
    if (usados.contains(normalizarCaminho(remoto.caminho))) continue;
    final titulo = lerMarkdown(remoto.conteudo,
            tituloReserva: nomeSemExtensao(remoto.caminho))
        .titulo;
    final localMesmoTitulo = locaisPorTitulo[chaveTitulo(titulo)];
    if (localMesmoTitulo != null && localMesmoTitulo.caminho == null) {
      plano.conflitos.add(ConflitoSync(
        local: localMesmoTitulo,
        remoto: remoto,
        motivo: 'nota local com o mesmo título veio de outro caminho',
      ));
      continue;
    }
    plano.recebidas.add(RecebidaNota(
      nota: _notaDeRemoto(remoto, quando),
      caminho: normalizarCaminho(remoto.caminho),
    ));
  }

  return plano;
}
