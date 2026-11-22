import 'dart:io';

import 'package:jarvis_nova/core/circuito.dart';
import 'package:jarvis_nova/core/projetista.dart';

void main() {
  // 1. Cada família tem um texto que a identifica.
  final casos = <String, FamiliaCircuito>{
    'lâmpada de 12 V e 5 W com interruptor': FamiliaCircuito.lampada,
    'LED de 12 V com resistor': FamiliaCircuito.led,
    'duas lâmpadas de 12 V em série': FamiliaCircuito.serie,
    'duas lâmpadas de 12 V em paralelo': FamiliaCircuito.paralelo,
    'divisor de tensão de 12 V': FamiliaCircuito.divisor,
    'partida direta de um motor de 24 V': FamiliaCircuito.partidaDireta,
    'reversão de motor com intertravamento': FamiliaCircuito.reversao,
    'acender a lâmpada 5 segundos depois de apertar o botão':
        FamiliaCircuito.temporizador,
  };
  casos.forEach((texto, esperado) {
    final lido = PedidoCircuito.ler(texto);
    assert(lido.familia == esperado,
        '“$texto” caiu em ${lido.familia}, esperado $esperado');
  });

  // 2. Os números do pedido são lidos, não chutados.
  final lampada = PedidoCircuito.ler('lâmpada de 24 V e 7 W com interruptor');
  assert(lampada.tensao == 24, 'tensão não lida: ${lampada.tensao}');
  assert(lampada.potencia == 7, 'potência não lida: ${lampada.potencia}');
  final temporizado =
      PedidoCircuito.ler('acender a lâmpada 10 segundos depois de apertar');
  assert(temporizado.segundos == 10, 'atraso não lido');
  final tres = PedidoCircuito.ler('três lâmpadas em paralelo');
  assert(tres.quantidade == 3, 'quantidade por extenso não lida');

  // 3. Todo exemplo da tela monta e fecha a simulação. Este é o contrato
  // central: o botão só aparece com simulação fechada.
  for (final exemplo in exemplosDePedido) {
    final projeto = montarProjetoDe(exemplo);
    assert(projeto.ok, 'exemplo não montou: “$exemplo” → ${projeto.motivo}');
    assert(projeto.circuito != null, 'exemplo sem circuito: $exemplo');
    final simulacao = projeto.circuito!.simular();
    assert(simulacao.calculado, 'simulação não fechou: $exemplo');
    assert(!simulacao.avisos.any((a) => a.gravidade == GravidadeAviso.erro),
        'simulação com erro: $exemplo → '
        '${simulacao.avisos.map((a) => a.texto).join('; ')}');
    assert(projeto.explicacao.isNotEmpty, 'exemplo sem explicação: $exemplo');
  }

  // 4. O resistor do LED é calculado: 12 V, queda de 2 V e 20 mA = 500 Ω.
  final led = montarProjetoDe('LED de 12 V');
  assert(led.ok, 'LED não montou: ${led.motivo}');
  final resistor = led.circuito!.elementos
      .firstWhere((e) => e.tipo == TipoElemento.resistor);
  assert(resistor.valor == 500, 'resistor do LED: ${resistor.valor}');

  // 5. Divisor de 12 V com os valores padrão entrega 8 V.
  final divisor = montarProjetoDe('divisor de tensão de 12 V');
  assert(divisor.ok, 'divisor não montou: ${divisor.motivo}');
  assert(divisor.explicacao.contains('8 V'),
      'divisor não anunciou 8 V: ${divisor.explicacao}');

  // 6. Recusas honestas: nada de circuito inventado.
  final vazio = montarProjetoDe('   ');
  assert(!vazio.ok && vazio.motivo.contains('Descreva'),
      'pedido vazio não foi recusado');
  final trifasico = montarProjetoDe('painel industrial trifásico qualquer');
  assert(!trifasico.ok,
      'pedido fora das famílias foi entregue como pronto');
  assert(trifasico.motivo.contains('Eu monto'), 'recusa sem o que ele monta');

  // 7. Pedido com tensão impossível para o LED é recusado com motivo.
  final ledImpossivel = montarProjetoDe('LED em 2 V');
  assert(!ledImpossivel.ok, 'LED em 2 V deveria ser recusado');

  stdout.writeln('OK: ${casos.length} famílias, ${exemplosDePedido.length} exemplos '
      'montados e simulados, recusas honestas conferidas');
}
