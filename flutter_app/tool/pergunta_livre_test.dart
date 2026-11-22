import 'dart:io';

import 'package:jarvis_nova/core/pergunta_livre.dart';

void main() {
  // 1. O pedido leva a pergunta do usuário e a instrução de voz.
  final mensagens = mensagensPerguntaLivre('  que horas são? ');
  assert(mensagens.length == 2, 'pedido deveria ter sistema e pergunta');
  assert(mensagens.last['role'] == 'user', 'a pergunta precisa ser do usuário');
  assert(mensagens.last['content'] == 'que horas são?',
      'a pergunta não foi aparada');
  final sistema = mensagens.first['content'] ?? '';
  assert(mensagens.first['role'] == 'system', 'falta a instrução de sistema');
  assert(sistema.contains(instrucaoPerguntaVoz), 'instrução de voz ausente');
  assert(sistema.contains('português do Brasil'), 'idioma não declarado');
  assert(sistema.contains('Não use markdown'), 'limite de fala ausente');

  // 2. A personalidade escolhida entra antes da instrução de voz.
  final comPersonalidade = mensagensPerguntaLivre('quem é você?',
      personalidade: 'Tom seco e direto.');
  final comSistema = comPersonalidade.first['content'] ?? '';
  assert(comSistema.startsWith('Tom seco e direto.'),
      'personalidade deveria vir primeiro');
  assert(comSistema.contains('Não use markdown'),
      'a instrução de voz continua obrigatória');

  // 3. Pergunta vazia não vira pedido inventado, mas continua rastreável.
  final vazia = mensagensPerguntaLivre('   ');
  assert(vazia.last['content'] == '', 'texto vazio deveria continuar vazio');

  // 4. A resposta falada perde markdown e símbolos que a voz leria em voz alta.
  final falada = respostaFalada(
      '**Claro.**\n- O Brasil fica na América do Sul.\n- Veja [aqui](https://x.y).');
  assert(!falada.contains('*'), 'asteriscos deveriam sair');
  assert(!falada.contains(']('), 'link markdown deveria virar texto');
  assert(falada.contains('Claro.'), 'conteúdo perdido na limpeza');
  assert(falada.contains('América do Sul'), 'conteúdo perdido na limpeza');
  assert(!falada.contains('\n'), 'quebras de linha deveriam virar espaço');

  // 5. Resposta longa é cortada no fim de uma frase.
  final longa = respostaFalada(
      List<String>.filled(40, 'Frase curta.').join(' '),
      limite: 120);
  assert(longa.length <= 121, 'corte não foi aplicado');
  assert(longa.endsWith('.'), 'corte deveria respeitar a frase');

  stdout.writeln('OK: pergunta livre — pedido, personalidade, limpeza e corte');
}
