/// Resumo tático das mensagens lidas nas notificações.
///
/// O aparelho já entrega as notificações (app, título, texto e se aceitam
/// resposta). Aqui ficam as regras puras: o que parece ruído de grupo, o que
/// parece urgente, o pedido enviado ao provedor de IA e a leitura da resposta.
/// Nada de rede neste arquivo — quem chama o provedor é o serviço.
library;

import 'dart:convert';

import 'aparelho.dart';

/// Palavras que costumam marcar um recado que não pode esperar.
const palavrasUrgentes = <String>[
  'urgente',
  'emergencia',
  'imediato',
  'agora',
  'hoje',
  'amanha',
  'prazo',
  'vencimento',
  'vence',
  'pix',
  'senha',
  'codigo',
  'confirmar',
  'confirme',
  'cancelar',
  'cancelamento',
  'ligar',
  'ligue',
  'acidente',
  'hospital',
  'atrasado',
  'perdido',
  'reuniao',
  'entrevista',
  'entrega',
  'boleto',
  'pagamento',
  'prova',
  'falta',
];

/// Sinais de conversa de grupo na notificação. Servem só como pista: a
/// classificação final é do provedor de IA, com o texto completo.
const sinaisDeGrupo = <String>[
  'grupo',
  'grupos',
  'membro',
  'membros',
  'nova mensagem',
  'novas mensagens',
  'mensagens nao lidas',
  'turma',
  'comunidade',
  'e mais',
];

String _semAcento(String texto) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const para = 'aaaaaeeeeiiiiooooouuuuc';
  final saida = StringBuffer();
  for (final rune in texto.toLowerCase().runes) {
    final caractere = String.fromCharCode(rune);
    final indice = de.indexOf(caractere);
    saida.write(indice < 0 ? caractere : para[indice]);
  }
  return saida.toString();
}

String _textoDa(NotificacaoAparelho n) =>
    _semAcento('${n.titulo} ${n.texto}').replaceAll(RegExp(r'\s+'), ' ').trim();

/// A notificação menciona um assunto que costuma exigir resposta rápida.
bool mensagemUrgente(NotificacaoAparelho n) {
  final texto = _textoDa(n);
  if (texto.isEmpty) return false;
  return palavrasUrgentes.any((palavra) => texto.contains(palavra));
}

/// A notificação parece conversa de grupo (muitas mensagens, vários membros).
bool ruidoDeGrupo(NotificacaoAparelho n) {
  final texto = _textoDa(n);
  if (texto.isEmpty) return false;
  if (RegExp(r'\b\d+\s*(?:mensagens|mensagem|novas)\b').hasMatch(texto)) {
    return true;
  }
  return sinaisDeGrupo.any(texto.contains);
}

/// Separação local, sem IA: urgente primeiro, depois ruído de grupo, depois o
/// resto. Serve para a tela mostrar algo verdadeiro mesmo sem provedor.
class TriagemMensagens {
  const TriagemMensagens({
    required this.urgentes,
    required this.ruido,
    required this.restantes,
  });

  final List<NotificacaoAparelho> urgentes;
  final List<NotificacaoAparelho> ruido;
  final List<NotificacaoAparelho> restantes;

  int get total => urgentes.length + ruido.length + restantes.length;
}

TriagemMensagens triarMensagens(List<NotificacaoAparelho> lista) {
  final urgentes = <NotificacaoAparelho>[];
  final ruido = <NotificacaoAparelho>[];
  final restantes = <NotificacaoAparelho>[];
  for (final n in lista) {
    if (mensagemUrgente(n)) {
      urgentes.add(n);
    } else if (ruidoDeGrupo(n)) {
      ruido.add(n);
    } else {
      restantes.add(n);
    }
  }
  return TriagemMensagens(
      urgentes: urgentes, ruido: ruido, restantes: restantes);
}

/// Uma resposta sugerida para uma das mensagens urgentes.
class SugestaoResposta {
  const SugestaoResposta({required this.app, required this.texto});

  final String app;
  final String texto;

  static SugestaoResposta? deJson(Object? bruto) {
    if (bruto is! Map) return null;
    final app = bruto['app'] is String ? (bruto['app'] as String).trim() : '';
    final texto =
        bruto['texto'] is String ? (bruto['texto'] as String).trim() : '';
    if (texto.isEmpty) return null;
    return SugestaoResposta(app: app, texto: texto);
  }
}

/// Resultado do resumo tático: o texto curto, o que é urgente, o que foi
/// filtrado como ruído e as respostas sugeridas.
class ResumoTatico {
  const ResumoTatico({
    required this.resumo,
    this.urgentes = const [],
    this.ruido = const [],
    this.respostas = const [],
    this.daIa = true,
  });

  final String resumo;
  final List<String> urgentes;
  final List<String> ruido;
  final List<SugestaoResposta> respostas;

  /// Falso quando o texto veio só da triagem local, sem provedor.
  final bool daIa;

  bool get vazio =>
      resumo.trim().isEmpty &&
      urgentes.isEmpty &&
      ruido.isEmpty &&
      respostas.isEmpty;

  /// Frase para leitura em voz alta do cartão.
  String get fala {
    final partes = <String>[
      if (resumo.trim().isNotEmpty) resumo.trim(),
      if (urgentes.isNotEmpty)
        'Urgente: ${urgentes.take(3).join('; ')}.',
      if (ruido.isNotEmpty)
        '${ruido.length} mensagem(ns) de grupo foram filtradas como ruído.',
      if (respostas.isNotEmpty)
        'Sugestão de resposta: ${respostas.first.texto}',
    ];
    return partes.join(' ');
  }
}

/// Limite de notificações enviadas ao provedor: o pedido curto cabe na cota e
/// cada item é cortado para não estourar o contexto.
const limiteResumoIa = 24;

List<Map<String, String>> mensagensResumoTatico(
  List<NotificacaoAparelho> lista, {
  DateTime? agora,
  int limite = limiteResumoIa,
}) {
  final quando = agora ?? DateTime.now();
  final quantas = limite.clamp(1, limiteResumoIa);
  final linhas = <String>[];
  for (final n in lista.take(quantas)) {
    final corpo = '${n.titulo} ${n.texto}'.replaceAll(RegExp(r'\s+'), ' ').trim();
    final curto = corpo.length <= 220 ? corpo : '${corpo.substring(0, 220)}…';
    linhas.add('- ${n.app} (${_hora(n.hora, quando)}): $curto');
  }
  final instrucao = '''
Você organiza notificações de celular para o usuário, em português do Brasil.
Regras:
- Separe o que é conversa de grupo (assunto coletivo, muitas mensagens, avisos
  de comunidade) do que é recado direto para o usuário.
- Destaque como urgente só o que pede ação ou resposta rápida hoje; não invente
  urgência.
- Sugira no máximo três respostas curtas, uma por mensagem urgente, com o nome
  do aplicativo de onde ela veio.
- Não invente remetente, valor, horário ou conteúdo que não esteja na lista.
Responda SOMENTE com um JSON válido, sem texto antes ou depois, neste formato:
{"resumo":"até 3 frases","urgentes":["..."],"ruido":["..."],"respostas":[{"app":"WhatsApp","texto":"..."}]}
Se não houver nada urgente, use "urgentes": []. Se não houver ruído, use [].''';
  return [
    {'role': 'system', 'content': instrucao},
    {
      'role': 'user',
      'content': 'Notificações lidas agora (mais recentes primeiro):\n'
          '${linhas.join('\n')}',
    },
  ];
}

String _hora(DateTime hora, DateTime agora) {
  if (hora.millisecondsSinceEpoch <= 0) return 'sem horário';
  final diferenca = agora.difference(hora);
  if (!diferenca.isNegative && diferenca.inMinutes < 60) {
    return 'há ${diferenca.inMinutes} min';
  }
  return '${hora.hour.toString().padLeft(2, '0')}:'
      '${hora.minute.toString().padLeft(2, '0')}';
}

/// Lê o JSON do provedor com tolerância a cercas de código e texto em volta.
ResumoTatico? lerResumoTatico(String bruto) {
  var texto = bruto.trim();
  if (texto.isEmpty) return null;
  texto = texto.replaceAll(RegExp(r'```[a-zA-Z]*'), '').trim();
  final inicio = texto.indexOf('{');
  final fim = texto.lastIndexOf('}');
  if (inicio < 0 || fim <= inicio) return null;
  final Object? dados;
  try {
    dados = _decodificar(texto.substring(inicio, fim + 1));
  } catch (_) {
    return null;
  }
  if (dados is! Map) return null;
  List<String> textos(Object? valor) => valor is List
      ? valor
          .whereType<String>()
          .map((item) => item.replaceAll(RegExp(r'\s+'), ' ').trim())
          .where((item) => item.isNotEmpty)
          .toList()
      : const <String>[];
  final respostas = <SugestaoResposta>[];
  final brutas = dados['respostas'];
  if (brutas is List) {
    for (final item in brutas) {
      final sugestao = SugestaoResposta.deJson(item);
      if (sugestao != null) respostas.add(sugestao);
    }
  }
  final resumo = dados['resumo'] is String
      ? (dados['resumo'] as String).replaceAll(RegExp(r'\s+'), ' ').trim()
      : '';
  final resultado = ResumoTatico(
    resumo: resumo,
    urgentes: textos(dados['urgentes']),
    ruido: textos(dados['ruido']),
    respostas: respostas.take(3).toList(),
  );
  return resultado.vazio ? null : resultado;
}

/// `dart:convert` é da biblioteca padrão: não adiciona dependência ao app.
Object? _decodificar(String texto) => jsonDecode(texto);
