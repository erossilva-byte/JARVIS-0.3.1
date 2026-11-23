/// Ficha pedida na conversa ou na voz, antes da confirmação de consentimento.
///
/// O app guarda fichas com dados de outra pessoa e só aceita gravar com
/// consentimento declarado. Por isso o pedido é lido aqui em duas etapas: a
/// primeira reconhece o que foi dito, a segunda só grava depois de um
/// “confirmo”. Nada é inventado: campo que não foi falado fica vazio.
library;

import 'memoria_busca.dart' show normalizar;

/// Dados reconhecidos em “cria a ficha de Murilo, que tem 16 anos…”.
class PedidoFicha {
  const PedidoFicha({
    required this.nome,
    this.apelido = '',
    this.relacao = '',
    this.idade,
    this.observacoes = '',
  });

  final String nome;
  final String apelido;
  final String relacao;
  final int? idade;

  /// O que não tem campo próprio na ficha (por exemplo, a idade) fica aqui.
  final String observacoes;

  /// Resumo curto para a pergunta de confirmação.
  String get resumo {
    final partes = <String>[
      if (idade != null) '$idade anos',
      if (apelido.isNotEmpty) 'apelido $apelido',
      if (relacao.isNotEmpty) relacao,
    ];
    return partes.isEmpty ? nome : '$nome (${partes.join(', ')})';
  }
}

/// Verbos que pedem para guardar uma ficha.
const _verbosFicha = r'(?:crie|cria|criar|salve|salva|salvar|cadastre|cadastra|'
    r'cadastrar|anote|anota|anotar|registre|registra|registrar|adicione|'
    r'adiciona|adicionar)';

final _pedidoFicha = RegExp(
  '(?:$_verbosFicha)\\s+(?:(?:uma|a|o)\\s+)?ficha\\s+'
  '(?:de|do|da|para|pra)\\s+([^,;.!?]+)',
  caseSensitive: false,
);

final _idade = RegExp(r'(\d{1,3})\s*anos?\b', caseSensitive: false);

final _apelido = RegExp(
  r'apelido\s*(?:é|eh|e|:)?\s*(?:o\s+|a\s+)?([^,.;]+)',
  caseSensitive: false,
);

final _relacaoComPronome = RegExp(
  r'(?:ele|ela)\s+[ée]\s+(?:o\s+|a\s+)?(meu|minha)\s+([^,.;]+)',
  caseSensitive: false,
);

/// Reconhece um pedido de ficha; `null` quando o texto é outra coisa.
///
/// Pergunta (“qual é a ficha de Murilo”) não tem verbo de guardar e passa
/// adiante, para a IA responder em vez de criar dado sem pedido.
PedidoFicha? pedidoDeFicha(String texto) {
  final limpo = texto.trim();
  if (limpo.isEmpty) return null;
  final achado = _pedidoFicha.firstMatch(limpo);
  if (achado == null) return null;
  final nome = _limparNome(achado.group(1) ?? '');
  if (nome.isEmpty) return null;
  final anos = _idade.firstMatch(limpo)?.group(1);
  final idade = anos == null ? null : int.tryParse(anos);
  return PedidoFicha(
    nome: nome,
    apelido: _valorDepoisDeApelido(limpo),
    relacao: _relacao(limpo),
    idade: idade,
    observacoes: idade == null ? '' : '$idade anos',
  );
}

String _limparNome(String bruto) {
  var nome = bruto.split(RegExp(r'\s+que\s+', caseSensitive: false)).first;
  nome =
      nome.split(RegExp(r'\s+e\s+(?:ele|ela)\b', caseSensitive: false)).first;
  nome = nome.replaceAll(RegExp(r'^[\s"“”]+|[\s"“”]+$'), '');
  nome =
      nome.replaceAll(RegExp(r'^(?:o|a|os|as)\s+', caseSensitive: false), '');
  nome = nome.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (nome.isEmpty) return '';
  return nome[0].toUpperCase() + nome.substring(1);
}

String _valorDepoisDeApelido(String texto) {
  final bruto = _apelido.firstMatch(texto)?.group(1)?.trim() ?? '';
  if (bruto.isEmpty) return '';
  return bruto
      .split(RegExp(r'\s+e\s+(?:ele|ela|o|a)\b', caseSensitive: false))
      .first
      .trim();
}

String _relacao(String texto) {
  final comPronome = _relacaoComPronome.firstMatch(texto);
  if (comPronome == null) return '';
  return comPronome
      .group(2)!
      .split(RegExp(r'\s+e\s+', caseSensitive: false))
      .first
      .trim();
}

/// “Confirmo”, “pode salvar”, “tenho o consentimento”: autoriza a gravação.
bool confirmacaoDeFicha(String texto) => RegExp(
      r'^(?:jarvis )?(?:sim )?(?:confirmo|confirmado|pode salvar(?: a ficha)?|'
      r'salve a ficha|salvar a ficha|tenho o consentimento(?: dela| dele)?|'
      r'autorizo)$',
    ).hasMatch(_limpo(texto));

/// “Cancela”, “não”: joga fora a ficha que estava esperando confirmação.
bool cancelamentoDeFicha(String texto) => RegExp(
      r'^(?:jarvis )?(?:cancela|cancele|cancelar|deixa|deixe|nao|nao quero)'
      r'(?: a ficha)?$',
    ).hasMatch(_limpo(texto));

String _limpo(String texto) => normalizar(texto)
    .replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
