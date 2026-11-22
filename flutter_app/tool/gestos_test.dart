import 'dart:io';

import 'package:jarvis_nova/core/gestos.dart';

void main() {
  // 1. De bruços é Z bem negativo; voltar para cima tem folga (histerese).
  assert(viradoParaBaixo(-9.8), 'gravidade de bruços deveria calar');
  assert(viradoParaBaixo(limiarViradoParaBaixo), 'o limiar exato deveria calar');
  assert(!viradoParaBaixo(-7.9), 'quase de bruços não deveria calar');
  assert(!viradoParaBaixo(9.8), 'tela para cima não deveria calar');
  assert(voltouParaCima(limiarVoltouParaCima), 'limiar de volta deveria rearmar');
  assert(!voltouParaCima(-5.0), 'ainda inclinado não deveria rearmar');

  // 2. Brilho é limitado à faixa que o app usa.
  assert(brilhoSeguro(0) == brilhoMinimoGestos, 'brilho 0 deveria virar o mínimo');
  assert(brilhoSeguro(150) == brilhoMaximoGestos, 'brilho 150 deveria virar o máximo');
  assert(brilhoSeguro(35) == 35, 'brilho válido foi alterado');
  assert(fatorBrilho(50) == 0.5, 'fator de 50% errado');
  assert((fatorBrilho(1) - 0.1).abs() < 0.0001, 'fator mínimo errado');

  // 3. O mapa do Android vira estado tipado; valor estranho cai no padrão.
  final lido = EstadoGestos.deMapa({
    'temAcelerometro': true,
    'calarAoVirar': true,
    'modoNoturno': true,
    'brilho': 200,
  });
  assert(lido.temAcelerometro, 'acelerômetro perdido');
  assert(lido.calarAoVirar, 'opção de calar perdida');
  assert(lido.modoNoturno, 'modo noturno perdido');
  assert(lido.brilho == brilhoMaximoGestos, 'brilho não foi limitado');
  final vazio = EstadoGestos.deMapa(null);
  assert(!vazio.temAcelerometro && !vazio.calarAoVirar && !vazio.modoNoturno,
      'mapa nulo deveria virar o estado vazio');
  assert(vazio.brilho == brilhoPadraoGestos, 'mapa nulo perdeu o brilho padrão');
  assert(!EstadoGestos.deMapa(<Object?, Object?>{'brilho': 'x'}).temAcelerometro,
      'valor inválido ligou o acelerômetro');

  // 4. Copiar preserva o resto e limita o brilho novo.
  final copiado = lido.copiarCom(modoNoturno: false, brilho: 3);
  assert(!copiado.modoNoturno, 'modo noturno não foi desligado');
  assert(copiado.calarAoVirar, 'copiar perdeu a opção de calar');
  assert(copiado.brilho == brilhoMinimoGestos, 'copiar não limitou o brilho');

  // 5. O resumo diz a verdade em cada caso.
  final semSensor = EstadoGestos.vazio;
  assert(resumoGestos(semSensor).contains('não informou acelerômetro'),
      'sem sensor deveria ser explícito');
  final ligado = EstadoGestos(
    temAcelerometro: true,
    calarAoVirar: true,
    modoNoturno: true,
    brilho: brilhoPadraoGestos,
  );
  assert(resumoGestos(ligado).contains('virar para calar ligado'),
      'resumo não cita o gesto ligado');
  assert(resumoGestos(ligado).contains('brilho em 35%'),
      'resumo não cita o brilho');

  // 6. Os limites não escondem o que o app não faz.
  assert(limitesGestos.any((l) => l.contains('WRITE_SETTINGS')),
      'limite de brilho do sistema ausente');
  assert(limitesGestos.any((l) => l.contains('bateria')),
      'limite do sensor em segundo plano ausente');
  assert(limitesGestos.any((l) => l.contains('45%')),
      'volume do modo noturno não declarado');

  stdout.writeln('OK: gestos — eixos, histerese, brilho, estado, resumo e limites');
}
