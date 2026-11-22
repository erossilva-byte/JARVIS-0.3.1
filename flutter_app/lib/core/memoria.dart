import 'dart:convert';

/// Tema da nota; o mesmo conjunto do legado, para o cofre continuar compatível.
const temasMemoria = <String, String>{
  'contextos': 'Contextos',
  'pessoas': 'Pessoas',
  'projetos': 'Projetos',
  'preferencias': 'Preferências',
  'aprendizados': 'Aprendizados',
  'rotinas': 'Rotinas',
};

String temaValido(String id) => temasMemoria.containsKey(id) ? id : 'contextos';

/// Nota do cofre local.
///
/// `extras` guarda chaves de frontmatter que este app não conhece: elas sobrevivem à leitura e à
/// gravação, para não apagar metadado de outro editor (Obsidian, por exemplo).
class NotaMemoria {
  NotaMemoria({
    required this.id,
    required this.titulo,
    required this.texto,
    this.tema = 'contextos',
    List<String>? tags,
    this.importancia = 1,
    required this.criadaEm,
    required this.atualizadaEm,
    this.usos = 0,
    this.caminho,
    this.hashSincronizado,
    Map<String, String>? extras,
  })  : tags = List<String>.unmodifiable(tags ?? const <String>[]),
        extras = Map<String, String>.unmodifiable(
            extras ?? const <String, String>{});

  final String id;
  final String titulo;
  final String texto;
  final String tema;
  final List<String> tags;

  /// 0 a 3, definida por quem escreve a nota.
  final int importancia;
  final DateTime criadaEm;
  final DateTime atualizadaEm;
  final int usos;

  /// Caminho relativo na pasta do Obsidian, quando a nota veio de lá ou já foi enviada.
  final String? caminho;

  /// Hash do conteúdo na última sincronização; é o que permite saber quem mudou.
  final String? hashSincronizado;

  final Map<String, String> extras;

  NotaMemoria copiarCom({
    String? titulo,
    String? texto,
    String? tema,
    List<String>? tags,
    int? importancia,
    DateTime? atualizadaEm,
    int? usos,
    String? caminho,
    String? hashSincronizado,
  }) =>
      NotaMemoria(
        id: id,
        titulo: titulo ?? this.titulo,
        texto: texto ?? this.texto,
        tema: tema ?? this.tema,
        tags: tags ?? this.tags,
        importancia: (importancia ?? this.importancia).clamp(0, 3),
        criadaEm: criadaEm,
        atualizadaEm: atualizadaEm ?? this.atualizadaEm,
        usos: usos ?? this.usos,
        caminho: caminho ?? this.caminho,
        hashSincronizado: hashSincronizado ?? this.hashSincronizado,
        extras: extras,
      );

  Map<String, Object?> paraJson() => {
        'id': id,
        'titulo': titulo,
        'texto': texto,
        'tema': tema,
        'tags': tags,
        'importancia': importancia,
        'criadaEm': criadaEm.toIso8601String(),
        'atualizadaEm': atualizadaEm.toIso8601String(),
        'usos': usos,
        'caminho': caminho,
        'hashSincronizado': hashSincronizado,
        'extras': extras,
      };

  static NotaMemoria? deJson(Object? dados) {
    if (dados is! Map) return null;
    final id = dados['id'];
    final titulo = dados['titulo'];
    final texto = dados['texto'];
    if (id is! String ||
        id.isEmpty ||
        titulo is! String ||
        titulo.trim().isEmpty ||
        texto is! String) {
      return null;
    }
    DateTime lerData(Object? valor, DateTime padrao) =>
        valor is String ? (DateTime.tryParse(valor) ?? padrao) : padrao;
    final agora = DateTime.now();
    final tags = dados['tags'];
    final extras = dados['extras'];
    final importancia = dados['importancia'];
    return NotaMemoria(
      id: id,
      titulo: titulo.trim(),
      texto: texto,
      tema: temaValido(
          dados['tema'] is String ? dados['tema'] as String : 'contextos'),
      tags: tags is List
          ? tags
              .whereType<String>()
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toList()
          : const [],
      importancia: importancia is int ? importancia.clamp(0, 3) : 1,
      criadaEm: lerData(dados['criadaEm'], agora),
      atualizadaEm: lerData(dados['atualizadaEm'], agora),
      usos: dados['usos'] is int ? (dados['usos'] as int).clamp(0, 100000) : 0,
      caminho: dados['caminho'] is String &&
              (dados['caminho'] as String).trim().isNotEmpty
          ? (dados['caminho'] as String).trim()
          : null,
      hashSincronizado: dados['hashSincronizado'] is String
          ? dados['hashSincronizado'] as String
          : null,
      extras: extras is Map
          ? extras.map((chave, valor) => MapEntry('$chave', '$valor'))
          : const {},
    );
  }
}

/// Nota lida de um Markdown, com o nome do arquivo para usar como título reserva.
class MarkdownLido {
  const MarkdownLido(
      {required this.titulo, required this.texto, required this.extras});
  final String titulo;
  final String texto;
  final Map<String, String> extras;
}

/// Lê frontmatter opcional (entre `---` na primeira e na última linha do bloco).
///
/// Só o primeiro bloco é frontmatter: uma nota cujo corpo começa com `---` mantém o texto depois
/// dele. Foi essa a perda de texto corrigida no cofre legado em 1.42.
MarkdownLido lerMarkdown(String bruto, {String tituloReserva = 'Sem título'}) {
  final linhas = bruto.replaceAll('\r\n', '\n').split('\n');
  final extras = <String, String>{};
  var inicioCorpo = 0;

  if (linhas.isNotEmpty && linhas.first.trim() == '---') {
    final fim = linhas.indexWhere((linha) => linha.trim() == '---', 1);
    if (fim > 0) {
      for (final linha in linhas.sublist(1, fim)) {
        final separador = linha.indexOf(':');
        if (separador <= 0) continue;
        final chave = linha.substring(0, separador).trim();
        var valor = linha.substring(separador + 1).trim();
        if (valor.startsWith('[') && valor.endsWith(']')) {
          valor = valor.substring(1, valor.length - 1);
        }
        if (chave.isNotEmpty) extras[chave] = valor;
      }
      inicioCorpo = fim + 1;
    }
  }

  final corpo = linhas.sublist(inicioCorpo).join('\n');
  var titulo = extras['titulo'] ?? extras['title'] ?? extras['nome'] ?? '';
  if (titulo.trim().isEmpty) {
    final cabecalho = corpo
        .split('\n')
        .firstWhere((linha) => linha.trim().startsWith('# '), orElse: () => '');
    if (cabecalho.isNotEmpty) titulo = cabecalho.trim().substring(2).trim();
  }
  if (titulo.trim().isEmpty) titulo = tituloReserva;
  return MarkdownLido(
      titulo: titulo.trim(), texto: corpo.trim(), extras: extras);
}

/// Gera Markdown com frontmatter estável; chaves desconhecidas são preservadas.
String escreverMarkdown(NotaMemoria nota) {
  String data(DateTime valor) => valor.toUtc().toIso8601String();
  final cabecalho = <String>[
    '---',
    'id: ${nota.id}',
    'titulo: ${nota.titulo}',
    'tema: ${nota.tema}',
    'tags: [${nota.tags.join(', ')}]',
    'importancia: ${nota.importancia}',
    'criada: ${data(nota.criadaEm)}',
    'atualizada: ${data(nota.atualizadaEm)}',
    for (final entrada in nota.extras.entries)
      if (!const {
        'id',
        'titulo',
        'title',
        'nome',
        'tema',
        'tags',
        'importancia',
        'criada',
        'atualizada'
      }.contains(entrada.key))
        '${entrada.key}: ${entrada.value}',
    '---',
  ];
  return '${cabecalho.join('\n')}\n\n${nota.texto.trim()}\n';
}

/// Importação de vários Markdowns, com o mesmo critério do legado: título repetido com conteúdo
/// igual é repetição; título repetido com conteúdo diferente vira conflito e não sobrescreve nada.
class ImportacaoMemoria {
  ImportacaoMemoria(
      {List<NotaMemoria>? adicionadas,
      this.repetidas = 0,
      List<String>? conflitos})
      : adicionadas = adicionadas ?? [],
        conflitos = conflitos ?? [];

  final List<NotaMemoria> adicionadas;
  int repetidas;
  final List<String> conflitos;

  int get total => adicionadas.length + repetidas + conflitos.length;
}

String chaveTitulo(String titulo) => titulo.trim().toLowerCase();

ImportacaoMemoria importarMarkdowns(
  List<({String nome, String conteudo})> arquivos,
  List<NotaMemoria> existentes, {
  DateTime? agora,
}) {
  final quando = agora ?? DateTime.now();
  final porTitulo = {
    for (final nota in existentes) chaveTitulo(nota.titulo): nota
  };
  final resultado = ImportacaoMemoria();
  var sequencia = 0;

  for (final arquivo in arquivos) {
    final lido = lerMarkdown(arquivo.conteudo,
        tituloReserva: arquivo.nome.replaceAll('.md', ''));
    final chave = chaveTitulo(lido.titulo);
    final existente = porTitulo[chave];
    if (existente != null) {
      if (existente.texto.trim() == lido.texto.trim()) {
        resultado.repetidas++;
      } else {
        resultado.conflitos.add(lido.titulo);
      }
      continue;
    }
    final tags = (lido.extras['tags'] ?? '')
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final importancia =
        int.tryParse(lido.extras['importancia'] ?? '')?.clamp(0, 3) ?? 1;
    final tema = temaValido(lido.extras['tema'] ?? 'contextos');
    final nota = NotaMemoria(
      id: '${quando.microsecondsSinceEpoch}-${sequencia++}',
      titulo: lido.titulo,
      texto: lido.texto,
      tema: tema,
      tags: tags,
      importancia: importancia,
      criadaEm: quando,
      atualizadaEm: quando,
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
    resultado.adicionadas.add(nota);
    porTitulo[chave] = nota;
  }
  return resultado;
}

/// Identificador estável do conteúdo, só para detectar mudança.
///
/// Não é hash criptográfico: dois acumuladores FNV-1a de 32 bits formam 64 bits, suficiente para
/// dizer “mudou ou não mudou” sem trazer dependência. Conteúdo igual é sempre conferido à parte
/// quando a decisão importa.
String hashConteudo(String texto) {
  var a = 0x811c9dc5;
  var b = 0x9e3779b9;
  for (final unidade in texto.codeUnits) {
    a = ((a ^ unidade) * 0x01000193) & 0xffffffff;
    b = ((b ^ (unidade + 0x9e37)) * 0x85ebca6b) & 0xffffffff;
  }
  return a.toRadixString(16).padLeft(8, '0') +
      b.toRadixString(16).padLeft(8, '0');
}

/// Marca usada nas notas que guardam a versão perdedora de um conflito.
const origemBackupConflito = 'backup-conflito';

/// Nota criada pela resolução de conflito para não descartar a versão que perdeu.
///
/// O id também é conferido porque backups criados antes da marca existir têm só o prefixo.
bool ehBackupConflito(NotaMemoria nota) =>
    nota.extras['origem'] == origemBackupConflito ||
    nota.id.startsWith('conflito-');

/// Tira o sufixo que a resolução de conflito acrescenta ao título.
String tituloSemSufixoBackup(String titulo) {
  const sufixo = ' (versão do conflito)';
  final limpo = titulo.trim();
  return limpo.endsWith(sufixo)
      ? limpo.substring(0, limpo.length - sufixo.length).trim()
      : limpo;
}

String jsonDeNotas(List<NotaMemoria> notas) =>
    jsonEncode(notas.map((n) => n.paraJson()).toList());

List<NotaMemoria> notasDeJson(String? bruto) {
  if (bruto == null || bruto.isEmpty) return [];
  try {
    final dados = jsonDecode(bruto);
    if (dados is! List) return [];
    return dados.map(NotaMemoria.deJson).whereType<NotaMemoria>().toList();
  } catch (_) {
    return [];
  }
}
