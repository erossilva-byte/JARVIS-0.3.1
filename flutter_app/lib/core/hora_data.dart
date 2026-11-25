/// Hora e data respondidas no próprio aparelho, sem provedor de IA.
///
/// O segundo plano já fazia isso (`JarvisFundo.Tipo.HORA` e `Tipo.DATA`); com a
/// tela aberta a pergunta ia para a IA, gastando chave e demorando. Esta regra
/// é o espelho Dart das mesmas frases e das mesmas respostas.
///
/// Não é comando do aparelho: nada é alterado, nada é lido de fora. Hora e data
/// vêm do relógio do próprio aparelho, que não revela nada guardado.
library;

/// Pergunta pelas horas: “que horas são”, “horas agora”, “quantas horas”.
final _horas = RegExp(
  r'\b(?:que|quantas)\s+horas\b|\bhoras\s+(?:sao|agora)\b|\bhora\s+agora\b|^horas$',
);

/// Pergunta pela data: “que dia é hoje”, “qual a data”, “dia da semana”.
final _data = RegExp(
  r'\b(?:que|qual)\s+dia\b|\bdata\s+de\s+hoje\b|\bqual\s+(?:e\s+)?a\s+data\b|'
  r'\bdia\s+da\s+semana\b|^data$',
);

const _dias = [
  'domingo',
  'segunda-feira',
  'terça-feira',
  'quarta-feira',
  'quinta-feira',
  'sexta-feira',
  'sábado',
];

const _meses = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

/// Resposta pronta para falar e o rótulo do histórico.
class RespostaRelogio {
  const RespostaRelogio({required this.fala, required this.acao});

  final String fala;
  final String acao;
}

/// Minúsculas, sem acento e sem pontuação — o mesmo tratamento do Kotlin.
String _normalizar(String texto) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const para = 'aaaaaeeeeiiiiooooouuuuc';
  final saida = StringBuffer();
  for (final rune in texto.toLowerCase().runes) {
    final caractere = String.fromCharCode(rune);
    final indice = de.indexOf(caractere);
    saida.write(indice < 0 ? caractere : para[indice]);
  }
  return saida.toString()
      .replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Hora em frase falável: os dois-pontos não são lidos em voz alta.
String horaFalada([DateTime? agora]) {
  final quando = agora ?? DateTime.now();
  return quando.minute == 0
      ? 'Agora são ${quando.hour} horas em ponto.'
      : 'Agora são ${quando.hour} horas e ${quando.minute} minutos.';
}

/// Data em frase falável, com o dia da semana na frente.
String dataFalada([DateTime? agora]) {
  final quando = agora ?? DateTime.now();
  final dia = _dias[quando.weekday % 7];
  final mes = _meses[quando.month - 1];
  return 'Hoje é $dia, ${quando.day} de $mes de ${quando.year}.';
}

/// Entende a pergunta de hora/data; `null` quando é outra coisa.
///
/// “Por que” fica de fora: pergunta de explicação não é pedido de relógio.
RespostaRelogio? respostaHoraData(String texto, {DateTime? agora}) {
  final limpo = _normalizar(texto);
  if (limpo.isEmpty || limpo.contains('por que')) return null;
  if (_horas.hasMatch(limpo)) {
    return RespostaRelogio(
      fala: horaFalada(agora),
      acao: 'informar as horas',
    );
  }
  if (_data.hasMatch(limpo)) {
    return RespostaRelogio(
      fala: dataFalada(agora),
      acao: 'informar a data de hoje',
    );
  }
  return null;
}
