/// Pergunta livre respondida pelo provedor de IA fora da tela de conversa.
///
/// O mesmo provedor da conversa (Groq, OpenRouter, Cerebras, Mistral, Gemini) é
/// usado, mas a resposta é falada em voz alta: por isso o pedido é curto, sem
/// markdown e sem listas. Fica em Dart puro para o formato do pedido poder ser
/// testado sem aparelho e sem rede.
library;

import 'memoria_busca.dart';

/// Instrução de voz. Ela entra junto da personalidade escolhida pelo usuário.
const instrucaoPerguntaVoz = '''
Você é o J.A.R.V.I.S. Nova respondendo por voz, em português do Brasil.
Responda em no máximo três frases curtas, em texto corrido.
Não use markdown, listas, tabelas, emojis, código nem endereços de site.
Se não souber ou precisar de um dado que não recebeu, diga isso em uma frase e
sugira o que o usuário pode fazer. Nunca invente nomes, horários ou números.
''';

/// Mensagens enviadas ao provedor para uma pergunta vinda da voz ou do segundo
/// plano. Sem histórico: o pedido é uma pergunta isolada, e a resposta é falada.
List<Map<String, String>> mensagensPerguntaLivre(
  String pergunta, {
  String personalidade = '',
  String? pessoas,
  String? habilidades,
}) {
  final texto = pergunta.trim();
  final sistema = [
    if (personalidade.trim().isNotEmpty) personalidade.trim(),
    instrucaoPerguntaVoz,
  ].join('\n\n');
  return montarMensagens(
    [
      {'role': 'user', 'content': texto},
    ],
    const ContextoMemoria(texto: '', usados: [], caracteres: 0),
    pessoas: pessoas,
    personalidade: sistema,
    habilidades: habilidades,
  );
}

/// Prepara o texto da IA para ser falado: tira markdown e corta o excesso.
///
/// A síntese de voz do Android lê os símbolos em voz alta ("asterisco
/// asterisco"), então o texto é limpo antes de ir para o alto-falante.
String respostaFalada(String bruto, {int limite = 700}) {
  var texto = bruto.replaceAll(RegExp(r'```[a-zA-Z]*'), ' ');
  texto = texto
      .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*\d+[.)]\s+', multiLine: true), '')
      .replaceAll(RegExp(r'\*\*|__|`'), '')
      .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]*\)'), r'$1')
      .replaceAll(RegExp(r'\s*\n\s*'), ' ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
  if (texto.length <= limite) return texto;
  final corte = texto.substring(0, limite);
  final ponto = corte.lastIndexOf(RegExp(r'[.!?]'));
  if (ponto > limite ~/ 2) return corte.substring(0, ponto + 1);
  return '${corte.trimRight()}…';
}
