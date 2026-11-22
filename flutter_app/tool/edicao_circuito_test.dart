import 'dart:io';

import 'package:jarvis_nova/core/circuito.dart';
import 'package:jarvis_nova/core/circuito_em_uso.dart';
import 'package:jarvis_nova/core/edicao_circuito.dart';
import 'package:jarvis_nova/core/projetista.dart';

String rotuloDe(Circuito c, TipoElemento tipo) {
  final rotulos = c.rotulos();
  for (final e in c.elementos) {
    if (e.tipo == tipo) return rotulos[e.id]!;
  }
  throw StateError('sem $tipo');
}

Elemento elementoDe(Circuito c, TipoElemento tipo) =>
    c.elementos.firstWhere((e) => e.tipo == tipo);

void main() {
  CircuitoEmUso.limpar();

  final divisor = montarProjetoDe('monta um divisor de tensão de 12 V').circuito!;
  final antes = divisor.simular();
  final r1 = rotuloDe(divisor, TipoElemento.resistor);

  // 1. Troca de valor pelo rótulo: R1 vai para 470 Ω e a conta é refeita.
  final troca = responderEdicaoDeCircuito('troca o $r1 por 470 ohms', divisor)!;
  assert(troca.ok, 'edição recusada: ${troca.texto}');
  assert(troca.mudancas.length == 1, 'esperava uma mudança');
  assert(troca.circuito!.porId(elementoDe(divisor, TipoElemento.resistor).id)!
          .valor ==
      470, 'R1 não ficou em 470 Ω');
  assert(troca.simulacao!.calculado, 'simulação não foi refeita');
  assert(troca.simulacao!.potenciaTotal != antes.potenciaTotal,
      'potência não mudou: a simulação não foi refeita de verdade');
  assert(troca.texto.contains('Refiz a simulação'), 'texto sem o recálculo');
  assert(troca.texto.contains('470'), 'texto sem o valor novo');
  assert(!troca.textoFalado.contains('→'), 'fala com a seta, que não se lê');

  // 2. Fonte em volts, com número solto e com unidade.
  final fonte24 =
      responderEdicaoDeCircuito('muda a fonte para 24', divisor)!;
  assert(fonte24.ok, 'fonte recusada: ${fonte24.texto}');
  assert(elementoDe(fonte24.circuito!, TipoElemento.fonte).valor == 24,
      'fonte não foi para 24 V');
  final tensao = responderEdicaoDeCircuito('aumenta a tensão para 24 V', divisor)!;
  assert(tensao.ok, 'tensão recusada: ${tensao.texto}');

  // 3. Só recalcular não muda peça nenhuma.
  final recalc = responderEdicaoDeCircuito('simula de novo', divisor)!;
  assert(recalc.ok, 'recalcular recusado');
  assert(recalc.mudancas.isEmpty, 'recalcular inventou mudança');
  assert(recalc.circuito!.elementos.length == divisor.elementos.length,
      'recalcular mexeu no circuito');

  // 4. Dois resistores e pedido genérico: pergunta qual, em vez de adivinhar.
  final ambiguo =
      responderEdicaoDeCircuito('troca o resistor por 470 ohms', divisor)!;
  assert(!ambiguo.ok, 'adivinhou qual resistor mudar');
  assert(ambiguo.texto.contains('Tem 2 resistores'), ambiguo.texto);
  assert(ambiguo.texto.contains(r1), 'não listou os rótulos');

  // 5. Peça que não existe e valor que falta: recusa com o motivo.
  final semPeca = responderEdicaoDeCircuito('troca o KT1 para 5 s', divisor)!;
  assert(!semPeca.ok && semPeca.texto.contains('Não achei KT1'),
      semPeca.texto);
  final semValor = responderEdicaoDeCircuito('troca o $r1 por azul', divisor)!;
  assert(!semValor.ok && semValor.texto.contains('ohms'), semValor.texto);

  // 6. Sem circuito aberto, a resposta é honesta (não monta nada).
  final vazio = responderEdicaoDeCircuito('troca o R1 por 470', null)!;
  assert(!vazio.ok, 'editou sem circuito');
  assert(vazio.texto.contains('Não tenho um circuito aberto'),
      vazio.texto);

  // 7. O que não é edição não é interceptado.
  for (final outro in [
    'o que é um resistor',
    'monta um circuito de lâmpada de 12 V',
    'aumenta o volume',
    'abre o simulador',
    'como funciona um contator',
  ]) {
    assert(responderEdicaoDeCircuito(outro, divisor) == null,
        'interceptou o que não é edição: “$outro”');
  }

  // 8. Interruptor abre e fecha, e a simulação acompanha.
  final lampada = montarProjetoDe(
          'monta um circuito de lâmpada de 12 V e 5 W com interruptor')
      .circuito!;
  final s1 = rotuloDe(lampada, TipoElemento.interruptor);
  final abre = responderEdicaoDeCircuito('abre o $s1', lampada)!;
  assert(abre.ok, 'não abriu o interruptor: ${abre.texto}');
  assert(!elementoDe(abre.circuito!, TipoElemento.interruptor).fechado,
      'interruptor continuou fechado');
  assert(abre.simulacao!.potenciaTotal == 0,
      'com o interruptor aberto a lâmpada deveria apagar');

  // 9. Temporizador por segundos.
  final temporizado =
      montarProjetoDe('acender a lâmpada 3 segundos depois de apertar o botão')
          .circuito!;
  if (temporizado.elementos.any((e) => e.tipo == TipoElemento.temporizador)) {
    final kt = rotuloDe(temporizado, TipoElemento.temporizador);
    final atraso = responderEdicaoDeCircuito('muda o $kt para 5 segundos',
        temporizado)!;
    assert(atraso.ok, 'atraso recusado: ${atraso.texto}');
    assert(
        elementoDe(atraso.circuito!, TipoElemento.temporizador).atraso == 5,
        'atraso não foi para 5 s');
  }

  // 10. O circuito do simulador é o que a conversa edita.
  CircuitoEmUso.definir(divisor);
  assert(CircuitoEmUso.atual != null, 'circuito em uso não guardou nada');
  CircuitoEmUso.limpar();
  assert(CircuitoEmUso.atual == null, 'circuito em uso não limpou');

  stdout.writeln('OK: edição de circuito — valor, fonte, interruptor, atraso, '
      'recálculo, ambiguidade e recusas conferidas');
}
