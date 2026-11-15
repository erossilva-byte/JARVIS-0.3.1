/// Modelo de conversa da interface nativa.
///
/// Fica em Dart puro (sem Flutter) para o formato salvo e o título automático poderem ser
/// testados sem emulador. A conversa é serializada como JSON e guardada pelo `ConversaStore`.
library;

class MensagemConversa {
  const MensagemConversa({
    required this.autor,
    required this.texto,
    this.fontes = const [],
    this.fichas = const [],
    this.contextoPessoas = '',
  });

  /// `user` ou `assistant`.
  final String autor;
  final String texto;

  /// Notas da memória usadas na resposta (Fase 7 preenche; vazio é o normal hoje).
  final List<String> fontes;

  /// Nomes das fichas de pessoas citadas na pergunta, para a interface mostrar o que foi usado.
  final List<String> fichas;

  /// Bloco de pessoas exatamente como foi enviado ao provedor (vazio quando não houve).
  final String contextoPessoas;

  bool get doUsuario => autor == 'user';

  Map<String, Object?> paraJson() => {
        'autor': autor,
        'texto': texto,
        if (fontes.isNotEmpty) 'fontes': fontes,
        if (fichas.isNotEmpty) 'fichas': fichas,
        if (contextoPessoas.isNotEmpty) 'contextoPessoas': contextoPessoas,
      };

  static MensagemConversa? deJson(Object? bruto) {
    if (bruto is! Map) {
      return null;
    }
    final autor = bruto['autor'];
    final texto = bruto['texto'];
    if (autor is! String || texto is! String || texto.trim().isEmpty) {
      return null;
    }
    if (autor != 'user' && autor != 'assistant') {
      return null;
    }
    final fontes = bruto['fontes'];
    return MensagemConversa(
      autor: autor,
      texto: texto,
      fontes: fontes is List ? fontes.whereType<String>().toList() : const [],
      fichas: bruto['fichas'] is List ? (bruto['fichas'] as List).whereType<String>().toList() : const [],
      contextoPessoas: bruto['contextoPessoas'] is String ? bruto['contextoPessoas'] as String : '',
    );
  }
}

class Conversa {
  Conversa({
    required this.id,
    required this.titulo,
    required this.criadaEm,
    required this.atualizadaEm,
    this.fixada = false,
    List<MensagemConversa>? mensagens,
  }) : mensagens = mensagens ?? [];

  final String id;
  String titulo;
  final DateTime criadaEm;
  DateTime atualizadaEm;
  bool fixada;
  final List<MensagemConversa> mensagens;

  static const tituloPadrao = 'Nova conversa';
  static const _limiteTitulo = 48;

  factory Conversa.nova({required String id, required DateTime agora}) => Conversa(
        id: id,
        titulo: tituloPadrao,
        criadaEm: agora,
        atualizadaEm: agora,
      );

  /// Acrescenta a mensagem e, se ainda não houver título, usa o começo da primeira pergunta.
  void adicionar(MensagemConversa mensagem, {DateTime? agora}) {
    mensagens.add(mensagem);
    atualizadaEm = agora ?? DateTime.now();
    if (mensagem.doUsuario && (titulo == tituloPadrao || titulo.trim().isEmpty)) {
      titulo = tituloDe(mensagem.texto);
    }
  }

  /// Título curto: primeira linha, espaços normalizados, corte sem quebrar palavra no limite.
  static String tituloDe(String texto) {
    final linha = texto.trim().split(RegExp(r'\s*\n\s*')).first;
    final limpo = linha.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (limpo.isEmpty) {
      return tituloPadrao;
    }
    if (limpo.length <= _limiteTitulo) {
      return limpo;
    }
    final corte = limpo.substring(0, _limiteTitulo);
    final espaco = corte.lastIndexOf(' ');
    return '${(espaco > 12 ? corte.substring(0, espaco) : corte).trimRight()}…';
  }

  Map<String, Object?> paraJson() => {
        'id': id,
        'titulo': titulo,
        'criadaEm': criadaEm.toIso8601String(),
        'atualizadaEm': atualizadaEm.toIso8601String(),
        'fixada': fixada,
        'mensagens': mensagens.map((m) => m.paraJson()).toList(),
      };

  static Conversa? deJson(Object? bruto) {
    if (bruto is! Map) {
      return null;
    }
    final id = bruto['id'];
    if (id is! String || id.isEmpty) {
      return null;
    }
    final criada = DateTime.tryParse(bruto['criadaEm'] as String? ?? '');
    if (criada == null) {
      return null;
    }
    final atualizada = DateTime.tryParse(bruto['atualizadaEm'] as String? ?? '') ?? criada;
    final mensagens = bruto['mensagens'];
    return Conversa(
      id: id,
      titulo: (bruto['titulo'] as String?)?.trim().isNotEmpty == true ? bruto['titulo'] as String : tituloPadrao,
      criadaEm: criada,
      atualizadaEm: atualizada,
      fixada: bruto['fixada'] == true,
      mensagens: mensagens is List
          ? mensagens.map(MensagemConversa.deJson).whereType<MensagemConversa>().toList()
          : <MensagemConversa>[],
    );
  }
}
