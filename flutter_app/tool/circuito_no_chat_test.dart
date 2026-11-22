import 'dart:io';

import 'package:jarvis_nova/core/circuito_no_chat.dart';

void main() {
  // 1. Pedidos de montagem são reconhecidos.
  for (final pedido in [
    'monta um circuito de lâmpada de 12 V e 5 W com interruptor',
    'monte um divisor de tensão de 12 V',
    'faça um circuito com LED',
    'cria um esquema de partida direta de um motor de 24 V',
    'quero um circuito para acender uma lâmpada',
    'preciso de um circuito de reversão com intertravamento',
    'como monto um circuito com resistor de 1k',
  ]) {
    assert(pedidoDeCircuito(pedido), 'não reconheceu o pedido: “$pedido”');
    assert(responderPedidoDeCircuito(pedido) != null,
        'sem resposta para o pedido: “$pedido”');
  }

  // 2. Pergunta sobre eletrônica não é interceptada: segue para o provedor.
  for (final pergunta in [
    'o que é um resistor',
    'explica o divisor de tensão',
    'como funciona um contator',
    'qual a diferença entre série e paralelo',
    'por que o LED queima sem resistor',
    'quanto custa um motor trifásico',
  ]) {
    assert(!pedidoDeCircuito(pergunta), 'interceptou pergunta: “$pergunta”');
    assert(responderPedidoDeCircuito(pergunta) == null,
        'respondeu pergunta como circuito: “$pergunta”');
  }

  // 3. Assunto sem circuito e comando do aparelho continuam passando adiante.
  for (final outro in [
    'aumenta o volume',
    'abre o simulador de circuitos',
    'bom dia, Jarvis',
    'lembra que o R1 é de 1k',
    'ler a tela',
  ]) {
    assert(!pedidoDeCircuito(outro), 'interceptou o que não é pedido: “$outro”');
  }

  // 4. Circuito montado: texto completo, versão falada e simulação fechada.
  final pronto =
      responderPedidoDeCircuito('monta um divisor de tensão de 12 V')!;
  assert(pronto.ok, 'divisor deveria montar: ${pronto.texto}');
  assert(pronto.projeto.circuito != null, 'sem circuito no resultado');
  assert(pronto.projeto.circuito!.simular().calculado,
      'resultado entregue sem simulação fechada');
  assert(pronto.texto.contains('Montei o circuito'), 'texto sem o veredito');
  assert(pronto.texto.contains('simulação fechada'), 'texto sem a simulação');
  assert(pronto.texto.contains('Abrir no simulador') ||
      pronto.texto.contains('Abra no simulador'), 'texto sem o atalho');
  assert(!pronto.texto.contains('**') && !pronto.texto.contains('`'),
      'texto com markdown (a voz leria os símbolos)');
  assert(pronto.textoFalado.length < pronto.texto.length,
      'versão falada deveria ser mais curta');
  assert(!pronto.textoFalado.contains('“'), 'fala com aspas tipográficas');

  // 5. Pedido fora das famílias é recusado com motivo, não com esquema falso.
  final recusa = responderPedidoDeCircuito(
      'monta um circuito trifásico industrial completo')!;
  assert(!recusa.ok, 'trifásico não deveria virar pronto');
  assert(recusa.projeto.circuito == null, 'recusa com circuito anexado');
  assert(recusa.texto.startsWith('Não montei o circuito.'),
      'recusa sem frase honesta: ${recusa.texto}');
  assert(recusa.textoFalado.startsWith('Não montei'), 'fala da recusa errada');

  // 6. Texto vazio não é pedido.
  assert(!pedidoDeCircuito('   '), 'texto vazio virou pedido');

  stdout.writeln(
      'OK: circuito no chat — 7 pedidos reconhecidos, 6 perguntas poupadas, '
      'montagem e recusa conferidas');
}
