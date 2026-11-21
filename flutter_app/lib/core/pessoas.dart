import 'dart:convert';

import 'memoria_busca.dart' show normalizar;

/// Limites de cada campo. O perfil é digitado pelo usuário; nada é preenchido sozinho.
const limitesPessoa = <String, int>{
  'nome': 80,
  'apelido': 60,
  'relacao': 80,
  'contatos': 200,
  'preferencias': 500,
  'observacoes': 2000,
  'compromissos': 1000,
  'historico': 2000,
};

const limitePerfisPessoa = 50;

/// Perfis vão para o armazenamento seguro do aparelho; o teto evita empurrar blob grande.
const limiteBytesPessoas = 64 * 1024;

/// Ficha local de uma pessoa. Só existe o que o usuário digitou — campos vazios continuam vazios.
class Pessoa {
  const Pessoa({
    required this.id,
    required this.nome,
    this.apelido = '',
    this.relacao = '',
    this.contatos = '',
    this.preferencias = '',
    this.observacoes = '',
    this.compromissos = '',
    this.historico = '',
    this.consentimento = false,
    required this.criadaEm,
    required this.atualizadaEm,
  });

  final String id;
  final String nome;
  final String apelido;
  final String relacao;

  /// Contato autorizado. Nunca entra no contexto enviado à IA.
  final String contatos;
  final String preferencias;
  final String observacoes;
  final String compromissos;

  /// Histórico escrito pelo usuário. O app não deduz interação de conversa.
  final String historico;

  /// Declaração explícita de que o usuário tem o consentimento da pessoa (LGPD).
  final bool consentimento;

  final DateTime criadaEm;
  final DateTime atualizadaEm;

  Pessoa copiarCom({
    String? nome,
    String? apelido,
    String? relacao,
    String? contatos,
    String? preferencias,
    String? observacoes,
    String? compromissos,
    String? historico,
    bool? consentimento,
    DateTime? criadaEm,
    DateTime? atualizadaEm,
  }) =>
      Pessoa(
        id: id,
        nome: nome ?? this.nome,
        apelido: apelido ?? this.apelido,
        relacao: relacao ?? this.relacao,
        contatos: contatos ?? this.contatos,
        preferencias: preferencias ?? this.preferencias,
        observacoes: observacoes ?? this.observacoes,
        compromissos: compromissos ?? this.compromissos,
        historico: historico ?? this.historico,
        consentimento: consentimento ?? this.consentimento,
        criadaEm: criadaEm ?? this.criadaEm,
        atualizadaEm: atualizadaEm ?? this.atualizadaEm,
      );

  /// Devolve a ficha com todos os campos limpos e cortados no limite.
  Pessoa sanitizada() => Pessoa(
        id: id,
        nome: limparCampoPessoa(nome, limitesPessoa['nome']!),
        apelido: limparCampoPessoa(apelido, limitesPessoa['apelido']!),
        relacao: limparCampoPessoa(relacao, limitesPessoa['relacao']!),
        contatos: limparCampoPessoa(contatos, limitesPessoa['contatos']!),
        preferencias:
            limparCampoPessoa(preferencias, limitesPessoa['preferencias']!),
        observacoes:
            limparCampoPessoa(observacoes, limitesPessoa['observacoes']!),
        compromissos:
            limparCampoPessoa(compromissos, limitesPessoa['compromissos']!),
        historico: limparCampoPessoa(historico, limitesPessoa['historico']!),
        consentimento: consentimento,
        criadaEm: criadaEm,
        atualizadaEm: atualizadaEm,
      );

  Map<String, Object?> paraJson() => {
        'id': id,
        'nome': nome,
        'apelido': apelido,
        'relacao': relacao,
        'contatos': contatos,
        'preferencias': preferencias,
        'observacoes': observacoes,
        'compromissos': compromissos,
        'historico': historico,
        'consentimento': consentimento,
        'criadaEm': criadaEm.toIso8601String(),
        'atualizadaEm': atualizadaEm.toIso8601String(),
      };

  static Pessoa? deJson(Object? dados) {
    if (dados is! Map) return null;
    final id = dados['id'];
    final nome = dados['nome'];
    if (id is! String || id.isEmpty || nome is! String) return null;
    DateTime data(Object? valor) => valor is String
        ? DateTime.tryParse(valor) ?? DateTime.now()
        : DateTime.now();
    String texto(Object? valor) => valor is String ? valor : '';
    return Pessoa(
      id: id,
      nome: nome,
      apelido: texto(dados['apelido']),
      relacao: texto(dados['relacao']),
      contatos: texto(dados['contatos']),
      preferencias: texto(dados['preferencias']),
      observacoes: texto(dados['observacoes']),
      compromissos: texto(dados['compromissos']),
      historico: texto(dados['historico']),
      consentimento: dados['consentimento'] == true,
      criadaEm: data(dados['criadaEm']),
      atualizadaEm: data(dados['atualizadaEm']),
    );
  }
}

/// Limpa um campo: remove controle e `<>`, normaliza espaços e corta no limite.
String limparCampoPessoa(String? texto, int limite) {
  var limpo = (texto ?? '')
      .replaceAll(
          RegExp(r'[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]'), ' ')
      .replaceAll(RegExp(r'[<>]'), '')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  if (limpo.length > limite) limpo = limpo.substring(0, limite).trim();
  return limpo;
}

List<Pessoa> pessoasDeJson(String? bruto) {
  if (bruto == null || bruto.isEmpty) return const [];
  try {
    final dados = jsonDecode(bruto);
    if (dados is! List) return const [];
    return dados.map(Pessoa.deJson).whereType<Pessoa>().toList();
  } catch (_) {
    return const [];
  }
}

String jsonDePessoas(List<Pessoa> pessoas) =>
    jsonEncode(pessoas.map((p) => p.paraJson()).toList());

/// Nome só com espaços não vale; consentimento é obrigatório.
String? validarPessoa(Pessoa pessoa) {
  if (pessoa.nome.trim().isEmpty) {
    return 'Informe o nome ou uma identificação para a pessoa.';
  }
  if (!pessoa.consentimento) {
    return 'Confirme que você tem o consentimento desta pessoa para guardar estas informações neste aparelho.';
  }
  return null;
}

int _compararNome(Pessoa a, Pessoa b) =>
    normalizar(a.nome).compareTo(normalizar(b.nome));

List<Pessoa> ordenarPessoas(List<Pessoa> pessoas) =>
    pessoas.toList()..sort(_compararNome);

List<Pessoa> buscarPessoas(List<Pessoa> pessoas, String termo) {
  final busca = normalizar(termo);
  if (busca.isEmpty) return ordenarPessoas(pessoas);
  return ordenarPessoas(pessoas)
      .where((p) =>
          normalizar(p.nome).contains(busca) ||
          normalizar(p.apelido).contains(busca))
      .toList();
}

enum TipoResolucaoPessoa { exato, unico, ambiguo, nenhum }

class ResolucaoPessoa {
  const ResolucaoPessoa(this.tipo, {this.perfil, this.candidatos = const []});

  final TipoResolucaoPessoa tipo;

  /// Só existe quando o tipo é `exato` ou `unico`; ambiguidade nunca escolhe sozinha.
  final Pessoa? perfil;
  final List<Pessoa> candidatos;
}

/// Resolve um nome dito pelo usuário sem adivinhar: dois "João" viram pergunta, não escolha.
ResolucaoPessoa resolverPessoa(List<Pessoa> pessoas, String termo) {
  final busca = normalizar(termo);
  if (busca.isEmpty) return const ResolucaoPessoa(TipoResolucaoPessoa.nenhum);
  final ordenadas = ordenarPessoas(pessoas);
  final exatos = ordenadas
      .where((p) =>
          normalizar(p.nome) == busca ||
          (p.apelido.isNotEmpty && normalizar(p.apelido) == busca))
      .toList();
  if (exatos.length == 1) {
    return ResolucaoPessoa(TipoResolucaoPessoa.exato,
        perfil: exatos.single, candidatos: exatos);
  }
  if (exatos.length > 1) {
    return ResolucaoPessoa(TipoResolucaoPessoa.ambiguo, candidatos: exatos);
  }
  final parciais = ordenadas
      .where((p) =>
          normalizar(p.nome).contains(busca) ||
          normalizar(p.apelido).contains(busca))
      .toList();
  if (parciais.length == 1) {
    return ResolucaoPessoa(TipoResolucaoPessoa.unico,
        perfil: parciais.single, candidatos: parciais);
  }
  if (parciais.length > 1) {
    return ResolucaoPessoa(TipoResolucaoPessoa.ambiguo, candidatos: parciais);
  }
  return const ResolucaoPessoa(TipoResolucaoPessoa.nenhum);
}

/// Descrição falada para "quem é essa pessoa?": só o que está preenchido.
String descreverPessoa(Pessoa? pessoa) {
  if (pessoa == null) return '';
  final partes = <String>[];
  if (pessoa.apelido.isNotEmpty) {
    partes.add('também conhecida como ${pessoa.apelido}');
  }
  if (pessoa.relacao.isNotEmpty) partes.add(pessoa.relacao);
  if (pessoa.preferencias.isNotEmpty) {
    partes.add('preferências: ${pessoa.preferencias}');
  }
  if (pessoa.observacoes.isNotEmpty) {
    partes.add('observações: ${pessoa.observacoes}');
  }
  if (pessoa.compromissos.isNotEmpty) {
    partes.add('compromissos: ${pessoa.compromissos}');
  }
  final nome = pessoa.nome.isEmpty ? 'sem nome' : pessoa.nome;
  if (partes.isEmpty) return '$nome — nenhuma informação além do nome.';
  return '$nome — ${partes.join('. ')}.';
}

/// Última linha do histórico escrito pelo usuário; nulo quando ele não anotou nada.
String? ultimaInteracao(Pessoa pessoa) {
  final linhas = pessoa.historico
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  return linhas.isEmpty ? null : linhas.last;
}

enum TipoContextoPessoas { nenhum, detalhe, ambiguo, ausente }

/// Resultado do bloco de pessoas: o texto exato enviado e quem foi citado.
class ContextoPessoasConversa {
  const ContextoPessoasConversa(
      {required this.bloco, required this.nomes, required this.tipo});

  const ContextoPessoasConversa.nenhum()
      : bloco = '',
        nomes = const [],
        tipo = TipoContextoPessoas.nenhum;

  final String bloco;
  final List<String> nomes;
  final TipoContextoPessoas tipo;

  bool get vazio => bloco.isEmpty;
}

/// Monta o bloco seguro e diz o que ele representa (ficha única, ambiguidade, ausência ou nada).
///
/// Só entram nome, apelido, relação e preferências. Contato, anotações, compromissos e histórico
/// nunca são enviados. Quando não há ficha, o bloco manda dizer que não encontrou em vez de
/// deixar a IA completar com invenção. Pergunta que não é sobre pessoa devolve bloco vazio.
ContextoPessoasConversa contextoPessoasParaConsulta(
    List<Pessoa> pessoas, String consulta) {
  final pergunta = ' ${normalizar(consulta)} ';
  if (pergunta.trim().isEmpty) return const ContextoPessoasConversa.nenhum();

  bool citado(String termo) {
    final alvo = normalizar(termo);
    return alvo.length >= 2 && pergunta.contains(' $alvo ');
  }

  var citadas = pessoas.where((p) => citado(p.nome)).toList();
  if (citadas.isNotEmpty) {
    // Nome completo vence primeiro nome: "Ana Paula" não vira ambiguidade com "Ana".
    final maior = citadas
        .map((p) => normalizar(p.nome).length)
        .reduce((a, b) => a > b ? a : b);
    citadas = citadas.where((p) => normalizar(p.nome).length == maior).toList();
  } else {
    citadas = pessoas
        .where((p) => citado(p.apelido) || citado(p.nome.split(' ').first))
        .toList();
  }

  const pistas = [
    'quem e',
    'quem sao',
    'ficha',
    'fichas',
    'sobre a',
    'sobre o',
    'o que sabe',
    'o que voce sabe',
    'ultima interacao',
    'ultima conversa',
  ];
  final falaDePessoa = citadas.isNotEmpty ||
      pistas.any(pergunta.contains) ||
      pergunta.contains(' pessoa ');
  if (!falaDePessoa) return const ContextoPessoasConversa.nenhum();

  if (citadas.isEmpty) {
    return const ContextoPessoasConversa(
      bloco:
          'FICHAS DE PESSOAS — nenhuma ficha corresponde ao nome perguntado. Diga que não encontrou; '
          'não invente dados nem atribua informações a outra pessoa.',
      nomes: [],
      tipo: TipoContextoPessoas.ausente,
    );
  }
  if (citadas.length > 1) {
    final nomes = citadas.map((p) => p.nome).toList();
    return ContextoPessoasConversa(
      bloco:
          'FICHAS DE PESSOAS — mais de uma ficha corresponde: ${nomes.join(', ')}. Pergunte qual delas; '
          'não escolha sozinho e não invente.',
      nomes: nomes,
      tipo: TipoContextoPessoas.ambiguo,
    );
  }

  final pessoa = citadas.single;
  final linhas = <String>[
    'FICHA DE PESSOA — dados fornecidos pelo próprio usuário; use apenas o que está aqui.',
    '- Nome: ${pessoa.nome}',
    if (pessoa.apelido.isNotEmpty) '- Apelido: ${pessoa.apelido}',
    if (pessoa.relacao.isNotEmpty) '- Relação: ${pessoa.relacao}',
    if (pessoa.preferencias.isNotEmpty)
      '- Preferências: ${pessoa.preferencias}',
    '',
    'Contato, anotações, compromissos e histórico não estão disponíveis para envio. Se a pergunta '
        'pedir algo que não está acima, diga que não encontrou — não invente.',
  ];
  return ContextoPessoasConversa(
    bloco: linhas.join('\n'),
    nomes: [pessoa.nome],
    tipo: TipoContextoPessoas.detalhe,
  );
}

/// Compatibilidade: texto puro do bloco (usado pelos testes e por quem só precisa do conteúdo).
String blocoPessoasParaConsulta(List<Pessoa> pessoas, String consulta) =>
    contextoPessoasParaConsulta(pessoas, consulta).bloco;

/// Contexto compacto para a IA: nomes, apelidos, relação e preferências.
///
/// Contato, observações, compromissos e histórico **não** entram: são dados sensíveis que o
/// usuário não autorizou enviar.
String contextoPessoas(List<Pessoa> pessoas, {int limite = 12}) {
  final lista = ordenarPessoas(pessoas).take(limite);
  return lista
      .map((p) => '- ${p.nome}${p.apelido.isNotEmpty ? ' (${p.apelido})' : ''}'
          '${p.relacao.isNotEmpty ? ' · ${p.relacao}' : ''}'
          '${p.preferencias.isNotEmpty ? ' · prefere ${p.preferencias}' : ''}')
      .join('\n');
}
