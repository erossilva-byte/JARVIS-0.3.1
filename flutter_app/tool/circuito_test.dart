// ignore_for_file: avoid_print

import 'package:jarvis_nova/core/circuito.dart';

int checks = 0;

void ok(String nome) {
  checks++;
  print('OK: $nome');
}

void exigir(bool condicao, String mensagem) {
  if (!condicao) throw StateError(mensagem);
}

Elemento _e(TipoElemento tipo, int a, int b,
        {double valor = 0,
        double tensao = 12,
        bool fechado = true,
        bool queimado = false,
        bool pressionada = false,
        bool nf = false,
        String? contatoDe}) =>
    Elemento(
      id: chaveTrecho(a, b),
      tipo: tipo,
      a: a,
      b: b,
      valor: valor,
      tensaoNominal: tensao,
      fechado: fechado,
      queimado: queimado,
      pressionada: pressionada,
      normalmenteFechado: nf,
      contatoDe: contatoDe,
    );

void main() {
  final base = Circuito();
  final n = base.no;

  // 1. Dois resistores em série: 12 V em 200 Ω = 60 mA, 6 V em cada um.
  final serie = Circuito(elementos: [
    _e(TipoElemento.fonte, n(0, 0), n(0, 1), valor: 12),
    _e(TipoElemento.fio, n(0, 0), n(1, 0)),
    _e(TipoElemento.resistor, n(1, 0), n(2, 0), valor: 100),
    _e(TipoElemento.resistor, n(2, 0), n(3, 0), valor: 100),
    _e(TipoElemento.fio, n(3, 0), n(3, 1)),
    _e(TipoElemento.fio, n(3, 1), n(2, 1)),
    _e(TipoElemento.fio, n(2, 1), n(1, 1)),
    _e(TipoElemento.fio, n(1, 1), n(0, 1)),
  ]).simular();
  exigir(serie.calculado, 'série não calculou');
  final r1 = serie.medidas[chaveTrecho(n(1, 0), n(2, 0))]!;
  final r2 = serie.medidas[chaveTrecho(n(2, 0), n(3, 0))]!;
  exigir((r1.corrente - 0.06).abs() < 1e-6, 'corrente da série: ${r1.corrente}');
  exigir((r1.tensao - 6).abs() < 1e-6, 'tensão de R1: ${r1.tensao}');
  exigir((r1.potencia - 0.36).abs() < 1e-6, 'potência de R1: ${r1.potencia}');
  exigir((r1.tensao + r2.tensao - 12).abs() < 1e-6, 'soma das tensões');
  ok('dois resistores em série somam tensão e dividem corrente');

  // 2. Duas lâmpadas em paralelo recebem a tensão inteira.
  final paraleloCircuito = circuitoExemplo('Duas lâmpadas em paralelo');
  final paralelo = paraleloCircuito.simular();
  final lamps = paraleloCircuito.elementos
      .where((e) => e.tipo == TipoElemento.lampada)
      .map((e) => paralelo.medidas[e.id]!)
      .toList();
  exigir(paralelo.calculado, 'paralelo não calculou');
  exigir(lamps.length == 2, 'lâmpadas do paralelo: ${lamps.length}');
  exigir(lamps.every((m) => (m.tensao.abs() - 12).abs() < 1e-4),
      'lâmpada do paralelo sem 12 V: ${lamps.map((m) => m.tensao)}');
  final correnteFonteParalelo =
      paralelo.medidas[paraleloCircuito.elementos
              .firstWhere((e) => e.tipo == TipoElemento.fonte)
              .id]!
          .corrente;
  exigir((correnteFonteParalelo - 0.8333).abs() < 1e-3,
      'corrente total do paralelo: $correnteFonteParalelo');
  ok('duas lâmpadas em paralelo ficam com 12 V cada');

  // 3. Duas lâmpadas em série dividem a tensão e acendem fracas.
  final duasSerie = circuitoExemplo('Duas lâmpadas em série').simular();
  final tensoesSerie = duasSerie.medidas.values
      .map((m) => m.tensao.abs())
      .where((t) => t > 0.01)
      .toList();
  exigir(duasSerie.calculado, 'série de lâmpadas não calculou');
  exigir(
      tensoesSerie.any((t) => (t - 6).abs() < 0.01),
      'nenhuma lâmpada com 6 V: $tensoesSerie');
  exigir(duasSerie.avisos.any((a) => a.texto.contains('acende fraca')),
      'série de lâmpadas sem aviso de brilho baixo');
  ok('lâmpadas em série dividem a tensão e avisam que acendem fracas');

  // 4. Divisor de tensão: 1 kΩ + 2 kΩ em 12 V entrega 8 V no meio.
  final divisor = circuitoExemplo('Divisor de tensão').simular();
  final r2divisor = divisor.medidas[chaveTrecho(n(2, 1), n(2, 2))]!;
  exigir(divisor.calculado, 'divisor não calculou');
  exigir((r2divisor.tensao - 8).abs() < 1e-6,
      'tensão do divisor: ${r2divisor.tensao}');
  exigir((r2divisor.corrente - 0.004).abs() < 1e-9,
      'corrente do divisor: ${r2divisor.corrente}');
  ok('divisor de tensão entrega 8 V de 12 V em 1 kΩ e 2 kΩ');

  // 5. Lâmpada de 12 V / 5 W recebe 5 W a 12 V.
  final lampada = circuitoExemplo('Lâmpada e interruptor').simular();
  final lamp = lampada.medidas.values
      .firstWhere((m) => (m.potencia - 5).abs() < 1e-2);
  exigir((lamp.corrente - 0.4166666).abs() < 1e-4,
      'corrente da lâmpada: ${lamp.corrente}');
  exigir(formatarNumero(lamp.corrente, casas: 3) == '0,417',
      'formatação da corrente: ${formatarNumero(lamp.corrente, casas: 3)}');
  exigir(lampada.potenciaTotal > 4.9 && lampada.potenciaTotal < 5.1,
      'potência total: ${lampada.potenciaTotal}');
  ok('lâmpada de 12 V / 5 W dissipa 5 W e 0,417 A');

  // 6. Interruptor aberto interrompe o circuito e o aviso explica.
  final exemplo = circuitoExemplo('Lâmpada e interruptor');
  final chaveInterruptor = exemplo.elementos
      .firstWhere((e) => e.tipo == TipoElemento.interruptor);
  final aberto = exemplo
      .atualizar(chaveInterruptor.copiarCom(fechado: false))
      .simular();
  exigir(aberto.calculado, 'circuito aberto não calculou');
  final correnteAberta = aberto.medidas.values
      .map((m) => m.corrente.abs())
      .fold<double>(0, (a, b) => a > b ? a : b);
  exigir(correnteAberta < 1e-9, 'corrente com interruptor aberto: $correnteAberta');
  exigir(aberto.avisos.any((a) => a.texto.startsWith('Circuito aberto')),
      'sem aviso de circuito aberto');
  exigir(aberto.avisos.any((a) => a.texto.contains('aberto: nada passa')),
      'sem aviso do interruptor');
  ok('interruptor aberto zera a corrente e explica o motivo');

  // 7. Curto direto é apontado como erro.
  final curto = Circuito(elementos: [
    _e(TipoElemento.fonte, n(0, 0), n(0, 1), valor: 12),
    _e(TipoElemento.fio, n(0, 0), n(1, 0)),
    _e(TipoElemento.fio, n(1, 0), n(1, 1)),
    _e(TipoElemento.fio, n(1, 1), n(0, 1)),
  ]).simular();
  exigir(curto.calculado, 'curto não calculou');
  exigir(curto.curto, 'curto não foi classificado como curto');
  exigir(curto.avisos.first.texto.startsWith('Curto-circuito'),
      'primeiro aviso não é curto: ${curto.avisos.first.texto}');
  ok('curto direto entre os polos é apontado como erro');

  // 8. Fusível de 1 A rompe no curto e o circuito fica aberto.
  final comFusivel = circuitoExemplo('Curto protegido por fusível').simular();
  exigir(comFusivel.calculado, 'circuito com fusível não calculou');
  exigir(comFusivel.fusiveisQueimados.length == 1,
      'fusível não rompeu: ${comFusivel.fusiveisQueimados}');
  exigir(comFusivel.avisos.any((a) => a.texto.contains('queimou')),
      'sem aviso de fusível queimado');
  exigir(comFusivel.avisos.any((a) => a.texto.startsWith('Circuito aberto')),
      'fusível rompido não abriu o circuito');
  ok('fusível de 1 A rompe no curto e deixa o circuito aberto');

  // 9. Componente fora da malha é avisado, não inventa corrente.
  final ilhado = Circuito(elementos: [
    ...circuitoExemplo('Lâmpada e interruptor').elementos,
    _e(TipoElemento.resistor, n(5, 2), n(5, 3), valor: 10),
  ]).simular();
  exigir(ilhado.calculado, 'circuito com ilha não calculou');
  exigir(ilhado.avisos.any((a) => a.texto.contains('fora da malha')),
      'sem aviso de componente fora da malha');
  exigir(ilhado.medidas[chaveTrecho(n(5, 2), n(5, 3))]!.corrente.abs() < 1e-9,
      'componente ilhado recebeu corrente');
  ok('componente fora da malha é avisado e fica sem corrente');

  // 10. Sem fonte não há simulação, com mensagem clara.
  final semFonte = Circuito(elementos: [
    _e(TipoElemento.fio, n(0, 0), n(1, 0)),
    _e(TipoElemento.resistor, n(1, 0), n(1, 1), valor: 10),
  ]).simular();
  exigir(!semFonte.calculado, 'circuito sem fonte calculou');
  exigir(semFonte.erro!.contains('Falta uma fonte'),
      'mensagem sem fonte: ${semFonte.erro}');
  ok('circuito sem fonte é recusado com mensagem clara');

  // 11. Sobretensão na lâmpada e resistor sobrecarregado geram aviso.
  final sobretensao = Circuito(elementos: [
    _e(TipoElemento.fonte, n(0, 0), n(0, 1), valor: 24),
    _e(TipoElemento.lampada, n(0, 0), n(0, 1), valor: 5, tensao: 12),
  ]).simular();
  exigir(sobretensao.avisos.any((a) => a.texto.contains('vai queimar')),
      'sem aviso de sobretensão');
  final resistorQuente = Circuito(elementos: [
    _e(TipoElemento.fonte, n(0, 0), n(0, 1), valor: 12),
    _e(TipoElemento.resistor, n(0, 0), n(0, 1), valor: 100),
  ]).simular();
  exigir(resistorQuente.avisos.any((a) => a.texto.contains('dissipa')),
      'sem aviso de potência no resistor');
  ok('sobretensão e resistor sobrecarregado geram aviso');

  // 12. Formatação em português.
  exigir(formatarNumero(0.5) == '0,5', 'formatação 0,5');
  exigir(formatarNumero(1000) == '1000', 'formatação 1000');
  exigir(formatarNumero(-0.0001, casas: 3) == '0', 'formatação de zero');
  ok('números aparecem com vírgula decimal');

  exigir(exemplosCircuito.length >= 6, 'poucos exemplos');
  exigir(exemplosCircuito.every((e) => e.montar().simular().calculado),
      'exemplo que não calcula');
  ok('todos os exemplos prontos calculam');

  // 13. Partida direta parada: bobina desligada e sem corrente.
  final parada = circuitoExemplo('Partida direta com selo');
  final bobinaId = parada.elementos
      .firstWhere((e) => e.tipo == TipoElemento.bobina)
      .id;
  final botoeiraPartida = parada.elementos.firstWhere(
      (e) => e.tipo == TipoElemento.botoeira && !e.normalmenteFechado);
  final botoeiraParada = parada.elementos.firstWhere(
      (e) => e.tipo == TipoElemento.botoeira && e.normalmenteFechado);
  final paradoCalculo = parada.simular();
  exigir(paradoCalculo.calculado, 'partida direta parada não calculou');
  exigir(paradoCalculo.bobinasLigadas.isEmpty,
      'bobina já ligada com a partida solta');
  exigir(paradoCalculo.medidas[bobinaId]!.corrente.abs() < 1e-9,
      'corrente na bobina com a partida solta: '
          '${paradoCalculo.medidas[bobinaId]!.corrente}');
  exigir(paradoCalculo.avisos.any((a) => a.texto.contains('solta (NA)')),
      'sem aviso da botoeira de partida solta');
  ok('partida direta começa parada, com a bobina desligada');

  // 14. Apertar a partida energiza a bobina: 24 V / 240 Ω = 100 mA.
  final apertada = parada.atualizar(
      botoeiraPartida.copiarCom(pressionada: true));
  final comPartida = apertada.simular();
  final medidaBobina = comPartida.medidas[bobinaId]!;
  exigir(comPartida.bobinasLigadas.contains(bobinaId),
      'a bobina não puxou com a partida apertada');
  exigir((medidaBobina.tensao.abs() - 24).abs() < 1e-4,
      'tensão da bobina: ${medidaBobina.tensao}');
  exigir((medidaBobina.corrente.abs() - 0.1).abs() < 1e-6,
      'corrente da bobina: ${medidaBobina.corrente}');
  ok('botoeira de partida energiza a bobina com 24 V e 100 mA');

  // 15. Soltar a partida com o selo fechado mantém o contator ligado.
  final selado = apertada
      .atualizar(botoeiraPartida.copiarCom(pressionada: false))
      .simular(bobinasLigadas: comPartida.bobinasLigadas);
  exigir(selado.bobinasLigadas.contains(bobinaId),
      'o contato de selo não manteve a bobina');
  exigir((selado.medidas[bobinaId]!.corrente.abs() - 0.1).abs() < 1e-6,
      'corrente com o selo fechado: ${selado.medidas[bobinaId]!.corrente}');
  ok('contato de selo mantém a bobina ligada depois de soltar a partida');

  // 16. Botoeira de parada (NF) derruba o contator.
  final comParada = parada
      .atualizar(botoeiraParada.copiarCom(pressionada: true))
      .simular(bobinasLigadas: selado.bobinasLigadas);
  exigir(comParada.bobinasLigadas.isEmpty,
      'a botoeira de parada não desligou o contator');
  exigir(comParada.medidas[bobinaId]!.corrente.abs() < 1e-9,
      'corrente na bobina depois da parada: '
          '${comParada.medidas[bobinaId]!.corrente}');
  ok('botoeira de parada NF desliga o contator na hora');

  // 17. Soltar a parada não religa o contator sozinho.
  final soltoDeNovo =
      parada.simular(bobinasLigadas: comParada.bobinasLigadas);
  exigir(soltoDeNovo.bobinasLigadas.isEmpty,
      'o circuito religou sozinho ao soltar a parada');
  ok('depois da parada o circuito não religa sozinho');

  // 18. Bobina com 55% da tensão não puxa.
  final meiaTensao = Circuito(elementos: [
    _e(TipoElemento.fonte, n(0, 0), n(0, 1), valor: 24),
    _e(TipoElemento.resistor, n(0, 0), n(1, 0), valor: 200),
    _e(TipoElemento.bobina, n(1, 0), n(1, 1), valor: 240, tensao: 24),
    _e(TipoElemento.fio, n(1, 1), n(0, 1)),
  ]).simular();
  exigir(meiaTensao.calculado, 'bobina em série não calculou');
  final bobinaFraca = meiaTensao.medidas[chaveTrecho(n(1, 0), n(1, 1))]!;
  exigir((bobinaFraca.tensao.abs() - 13.0909).abs() < 1e-3,
      'tensão da bobina em série: ${bobinaFraca.tensao}');
  exigir(meiaTensao.bobinasLigadas.isEmpty,
      'bobina puxou com 13,09 V de uma nominal de 24 V');
  exigir(meiaTensao.avisos.any((a) => a.texto.contains('não puxa')),
      'sem aviso de bobina fraca');
  ok('bobina com 55% da tensão não puxa e o app avisa');

  // 19: Contato de selo sem bobina fica aberto e é avisado.
  final seloSemBobina = Circuito(elementos: [
    _e(TipoElemento.fonte, n(0, 0), n(0, 1), valor: 24),
    _e(TipoElemento.contatoSelo, n(0, 0), n(1, 0)),
    _e(TipoElemento.resistor, n(1, 0), n(1, 1), valor: 100),
    _e(TipoElemento.fio, n(1, 1), n(0, 1)),
  ]).simular();
  exigir(seloSemBobina.calculado, 'selo sem bobina não calculou');
  exigir(
      seloSemBobina.avisos.any((a) => a.texto.contains('sem bobina')),
      'sem aviso de contato de selo sem bobina');
  exigir(
      seloSemBobina
          .medidas[chaveTrecho(n(1, 0), n(1, 1))]!
          .corrente
          .abs() <
          1e-9,
      'o selo sem bobina conduziu');
  ok('contato de selo sem bobina fica aberto e o app explica');

  // 20. Reversão: a partida 1 liga K1 e o intertravamento segura K2.
  final reversao = circuitoExemplo('Reversão com intertravamento');
  final bobinas = reversao.elementos
      .where((e) => e.tipo == TipoElemento.bobina)
      .map((e) => e.id)
      .toList();
  exigir(bobinas.length == 2, 'bobinas da reversão: ${bobinas.length}');
  final contatosNf = reversao.elementos
      .where((e) => e.tipo == TipoElemento.contatoNf)
      .toList();
  exigir(contatosNf.length == 2,
      'contatos NF da reversão: ${contatosNf.length}');
  exigir(
      contatosNf.every((e) =>
          e.contatoDe != null && bobinas.contains(e.contatoDe)),
      'contato NF sem bobina válida na reversão');
  final k1 = bobinas.first;
  final k2 = bobinas.last;
  Elemento botoeiraEm(int x, int y) => reversao.elementos.firstWhere(
      (e) => e.a == reversao.no(x, y) && e.tipo == TipoElemento.botoeira);
  final partida1 = botoeiraEm(1, 1);
  final partida2 = botoeiraEm(4, 1);
  final paradaGeral = botoeiraEm(0, 0);
  exigir(paradaGeral.normalmenteFechado, 'a parada da reversão não é NF');

  final semNada = reversao.simular();
  exigir(semNada.calculado, 'reversão parada não calculou');
  exigir(semNada.bobinasLigadas.isEmpty,
      'reversão já ligada com as partidas soltas');
  ok('reversão começa com os dois contatores desligados');

  final comK1 =
      reversao.atualizar(partida1.copiarCom(pressionada: true)).simular();
  exigir(comK1.bobinasLigadas.contains(k1), 'a partida 1 não ligou K1');
  exigir(!comK1.bobinasLigadas.contains(k2),
      'K2 ligou junto com K1 (intertravamento falhou)');
  exigir((comK1.medidas[k1]!.corrente.abs() - 0.1).abs() < 1e-6,
      'corrente de K1: ${comK1.medidas[k1]!.corrente}');
  ok('partida 1 liga K1 com 100 mA e não liga K2');

  final comSelo =
      reversao.atualizar(partida1.copiarCom(pressionada: false)).simular(
          bobinasLigadas: comK1.bobinasLigadas);
  exigir(comSelo.bobinasLigadas.contains(k1),
      'o selo de K1 não segurou depois de soltar a partida');
  ok('o selo mantém K1 ligado com a partida solta');

  final tentativaK2 =
      reversao.atualizar(partida2.copiarCom(pressionada: true)).simular(
          bobinasLigadas: comSelo.bobinasLigadas);
  exigir(!tentativaK2.bobinasLigadas.contains(k2),
      'K2 ligou com K1 ligado: intertravamento não funcionou');
  exigir(tentativaK2.bobinasLigadas.contains(k1),
      'K1 caiu sozinho ao apertar a partida 2');
  exigir(
      tentativaK2.avisos
          .any((a) => a.texto.contains('intertravamento agindo')),
      'sem aviso do contato NF aberto');
  ok('contato NF de K1 impede K2 de ligar com K1 ligado');

  final desligado =
      reversao.atualizar(paradaGeral.copiarCom(pressionada: true)).simular(
          bobinasLigadas: comSelo.bobinasLigadas);
  exigir(desligado.bobinasLigadas.isEmpty,
      'a parada não derrubou os contatores da reversão');

  // Soltar a parada e apertar a partida 2: agora K2 pode ligar.
  final comK2 = reversao
      .atualizar(partida2.copiarCom(pressionada: true))
      .simular(bobinasLigadas: desligado.bobinasLigadas);
  exigir(comK2.bobinasLigadas.contains(k2), 'a partida 2 não ligou K2');
  exigir(!comK2.bobinasLigadas.contains(k1), 'K1 ligou junto com K2');
  ok('depois da parada, a partida 2 liga K2 sem ligar K1');

  // 21. As duas partidas apertadas juntas não estabilizam: o app avisa.
  final duasPartidas = reversao
      .atualizar(partida1.copiarCom(pressionada: true))
      .atualizar(partida2.copiarCom(pressionada: true))
      .simular();
  exigir(duasPartidas.calculado, 'duas partidas não calcularam');
  exigir(
      duasPartidas.avisos
          .any((a) => a.texto.contains('não se estabiliza')),
      'sem aviso de comando instável');
  ok('duas partidas ao mesmo tempo avisam que o comando não estabiliza');

  // 22. Partida direta de motor: contato de potência só fecha com a bobina.
  final motorPartida = circuitoExemplo('Partida direta de motor DC');
  final motorId = motorPartida.elementos
      .firstWhere((e) => e.tipo == TipoElemento.motor)
      .id;
  final bobinaMotor = motorPartida.elementos
      .firstWhere((e) => e.tipo == TipoElemento.bobina)
      .id;
  final partidaMotor = motorPartida.elementos.firstWhere(
      (e) => e.tipo == TipoElemento.botoeira && !e.normalmenteFechado);
  final paradaMotor = motorPartida.elementos.firstWhere(
      (e) => e.tipo == TipoElemento.botoeira && e.normalmenteFechado);

  final motorParado = motorPartida.simular();
  exigir(motorParado.calculado, 'partida de motor parada não calculou');
  exigir(motorParado.medidas[motorId]!.corrente.abs() < 1e-9,
      'motor com corrente desligado: '
          '${motorParado.medidas[motorId]!.corrente}');
  exigir(motorParado.bobinasLigadas.isEmpty,
      'bobina ligada com o motor parado');
  exigir(motorParado.avisos.any((a) => a.texto.contains('contator não puxou')),
      'sem aviso do contato de potência aberto');
  ok('motor parado: contato de potência aberto e sem corrente');

  final motorLigado = motorPartida
      .atualizar(partidaMotor.copiarCom(pressionada: true))
      .simular();
  final medidaMotor = motorLigado.medidas[motorId]!;
  exigir(motorLigado.bobinasLigadas.contains(bobinaMotor),
      'K1 não puxou ao apertar a partida');
  exigir((medidaMotor.tensao.abs() - 24).abs() < 1e-4,
      'tensão do motor: ${medidaMotor.tensao}');
  exigir((medidaMotor.corrente.abs() - 1).abs() < 1e-6,
      'corrente do motor: ${medidaMotor.corrente}');
  exigir((medidaMotor.potencia.abs() - 24).abs() < 1e-4,
      'potência do motor: ${medidaMotor.potencia}');
  ok('partida liga o motor: 24 V, 1 A e 24 W');

  final motorSelado = motorPartida
      .atualizar(partidaMotor.copiarCom(pressionada: false))
      .simular(bobinasLigadas: motorLigado.bobinasLigadas);
  exigir((motorSelado.medidas[motorId]!.corrente.abs() - 1).abs() < 1e-6,
      'motor parou ao soltar a partida: '
          '${motorSelado.medidas[motorId]!.corrente}');
  ok('o selo mantém o motor girando depois de soltar a partida');

  final motorDesligado = motorPartida
      .atualizar(paradaMotor.copiarCom(pressionada: true))
      .simular(bobinasLigadas: motorSelado.bobinasLigadas);
  exigir(motorDesligado.medidas[motorId]!.corrente.abs() < 1e-9,
      'motor não parou com a parada: '
          '${motorDesligado.medidas[motorId]!.corrente}');
  ok('a parada desliga o motor junto com o contator');

  final fonteMotor = motorPartida.elementos
      .firstWhere((e) => e.tipo == TipoElemento.fonte);
  exigir((motorLigado.medidas[fonteMotor.id]!.corrente.abs() - 1.1).abs() < 1e-6,
      'corrente da fonte: ${motorLigado.medidas[fonteMotor.id]!.corrente}');
  ok('a fonte entrega 1,1 A: 1 A do motor mais 100 mA da bobina');

  // 23. Motor acima da tensão nominal é avisado.
  final motorSobretensao = Circuito(elementos: [
    _e(TipoElemento.fonte, n(0, 0), n(0, 1), valor: 48),
    _e(TipoElemento.motor, n(0, 0), n(1, 0), valor: 24, tensao: 24),
    _e(TipoElemento.fio, n(1, 0), n(1, 1)),
    _e(TipoElemento.fio, n(1, 1), n(0, 1)),
  ]).simular();
  exigir(motorSobretensao.calculado, 'motor em sobretensão não calculou');
  exigir(motorSobretensao.avisos.any((a) => a.texto.contains('sobreaquece')),
      'sem aviso de motor acima da nominal');
  ok('motor acima da tensão nominal é avisado');

  // 24. Relé térmico ajustado acima da corrente do motor não desarma.
  final protegida = circuitoExemplo('Partida com relé de sobrecarga');
  final motorProtegido =
      protegida.elementos.firstWhere((e) => e.tipo == TipoElemento.motor).id;
  final releId = protegida.elementos
      .firstWhere((e) => e.tipo == TipoElemento.releTermico)
      .id;
  final partidaProtegida = protegida.elementos.firstWhere(
      (e) => e.tipo == TipoElemento.botoeira && !e.normalmenteFechado);
  final comProtecao = protegida
      .atualizar(partidaProtegida.copiarCom(pressionada: true))
      .simular();
  exigir(comProtecao.calculado, 'partida com relé não calculou');
  exigir(comProtecao.relesDesarmados.isEmpty,
      'o relé desarmou com o motor em corrente normal');
  exigir((comProtecao.medidas[motorProtegido]!.corrente.abs() - 1).abs() < 1e-6,
      'corrente do motor protegido: '
          '${comProtecao.medidas[motorProtegido]!.corrente}');
  ok('relé ajustado em 1,5 A deixa o motor de 1 A rodar');

  // 25. Ajuste abaixo da corrente do motor: o relé desarma o comando.
  final ajusteBaixo = protegida
      .atualizar(protegida.porId(releId)!.copiarCom(valor: 0.5));
  final disparado = ajusteBaixo
      .atualizar(partidaProtegida.copiarCom(pressionada: true))
      .simular();
  exigir(disparado.calculado, 'relé desarmado não calculou');
  exigir(disparado.relesDesarmados.contains(releId),
      'o relé não desarmou com 1 A num ajuste de 0,5 A');
  exigir(disparado.bobinasLigadas.isEmpty,
      'a bobina continuou ligada depois do desarme');
  exigir(disparado.medidas[motorProtegido]!.corrente.abs() < 1e-9,
      'o motor continuou com corrente: '
          '${disparado.medidas[motorProtegido]!.corrente}');
  exigir(disparado.avisos.any((a) => a.texto.contains('desarmou')),
      'sem aviso de relé desarmado');
  ok('relé térmico desarma, derruba o contator e corta o motor');

  // 26. Rearmar o relé não religa o motor sozinho.
  final rearmado = protegida
      .desarmar(disparado.relesDesarmados)
      .rearmarReles()
      .simular(bobinasLigadas: disparado.bobinasLigadas);
  exigir(rearmado.relesDesarmados.isEmpty, 'o relé continuou desarmado');
  exigir(rearmado.medidas[motorProtegido]!.corrente.abs() < 1e-9,
      'o motor religou sozinho só com o rearme');
  ok('rearmar o relé não religa o motor sem apertar a partida');

  // 27. Temporizador energizado ainda não fecha o contato 67/68.
  final sequencia = circuitoExemplo('Sequência com temporizador');
  final kt = sequencia.elementos
      .firstWhere((e) => e.tipo == TipoElemento.temporizador);
  final lampadaSequencia =
      sequencia.elementos.firstWhere((e) => e.tipo == TipoElemento.lampada);
  final partidaSequencia = sequencia.elementos.firstWhere(
      (e) => e.tipo == TipoElemento.botoeira && !e.normalmenteFechado);
  final paradaSequencia = sequencia.elementos.firstWhere(
      (e) => e.tipo == TipoElemento.botoeira && e.normalmenteFechado);
  final sequenciaLigada = sequencia
      .atualizar(partidaSequencia.copiarCom(pressionada: true));
  final noZero = sequenciaLigada.simular();
  exigir(noZero.calculado, 'sequência não calculou');
  exigir(noZero.temporizadoresAtivos.contains(kt.id),
      'KT1 não energizou com o comando ligado');
  exigir(noZero.medidas[lampadaSequencia.id]!.potencia.abs() < 1e-9,
      'a lâmpada acendeu antes do atraso');
  ok('temporizador energizado, sem atraso completo, não acende a lâmpada');

  // 28. Com 2 s de 3 s ainda nada; com 3 s o 67/68 fecha e a lâmpada acende.
  final comDoisSegundos = sequenciaLigada.simular(tempos: {kt.id: 2});
  exigir(comDoisSegundos.medidas[lampadaSequencia.id]!.potencia.abs() < 1e-9,
      'a lâmpada acendeu com 2 s de 3 s');
  final comTresSegundos = sequenciaLigada.simular(tempos: {kt.id: 3});
  exigir(
      (comTresSegundos.medidas[lampadaSequencia.id]!.tensao.abs() - 24).abs() <
          1e-3,
      'tensão da lâmpada depois do atraso: '
          '${comTresSegundos.medidas[lampadaSequencia.id]!.tensao}');
  exigir(
      (comTresSegundos.medidas[lampadaSequencia.id]!.potencia.abs() - 5).abs() <
          1e-3,
      'potência da lâmpada depois do atraso: '
          '${comTresSegundos.medidas[lampadaSequencia.id]!.potencia}');
  ok('contato 67/68 fecha aos 3 s e a lâmpada de 24 V / 5 W acende');

  // 29. Sem energia o temporizador não conta e o contato abre de novo.
  final desligada = sequenciaLigada
      .atualizar(paradaSequencia.copiarCom(pressionada: true))
      .atualizar(partidaSequencia.copiarCom(pressionada: false));
  final sequenciaParada = desligada.simular(
      bobinasLigadas: comTresSegundos.bobinasLigadas, tempos: {kt.id: 3});
  exigir(sequenciaParada.temporizadoresAtivos.isEmpty,
      'KT1 continuou contando com o comando desligado');
  exigir(sequenciaParada.medidas[lampadaSequencia.id]!.potencia.abs() < 1e-9,
      'a lâmpada continuou acesa depois da parada');
  ok('sem energia o temporizador zera e o 67/68 abre a lâmpada');

  // 30. Desligamento em sequência: a partida puxa K1 e o motor roda na hora.
  final desligamento = circuitoExemplo('Desligamento em sequência');
  final ktDesliga = desligamento.elementos
      .firstWhere((e) => e.tipo == TipoElemento.temporizador);
  final motorDesliga =
      desligamento.elementos.firstWhere((e) => e.tipo == TipoElemento.motor);
  final bobinaDesliga =
      desligamento.elementos.firstWhere((e) => e.tipo == TipoElemento.bobina);
  final nfDesliga = desligamento.elementos
      .firstWhere((e) => e.tipo == TipoElemento.contatoTemporizadoNf);
  final partidaDesliga = desligamento.elementos.firstWhere(
      (e) => e.tipo == TipoElemento.botoeira && !e.normalmenteFechado);
  final ligadoDesliga = desligamento
      .atualizar(partidaDesliga.copiarCom(pressionada: true));
  final comMotor = ligadoDesliga.simular();
  exigir(comMotor.calculado, 'desligamento em sequência não calculou');
  exigir(comMotor.temporizadoresAtivos.contains(ktDesliga.id),
      'KT1 não energizou com o comando ligado');
  exigir(comMotor.bobinasLigadas.contains(bobinaDesliga.id),
      'K1 não puxou na partida');
  exigir(
      (comMotor.medidas[motorDesliga.id]!.potencia.abs() - 24).abs() < 1e-3,
      'potência do motor na partida: '
          '${comMotor.medidas[motorDesliga.id]!.potencia}');
  ok('partida puxa K1 e o motor de 24 V / 24 W roda com 1 A');

  // 31. Solta a partida (o selo mantém K1) e, com 2 s de 3 s, o motor roda.
  final soltoDesliga = ligadoDesliga
      .atualizar(partidaDesliga.copiarCom(pressionada: false));
  final comDoisDesliga = soltoDesliga.simular(
      bobinasLigadas: comMotor.bobinasLigadas, tempos: {ktDesliga.id: 2});
  exigir(comDoisDesliga.bobinasLigadas.contains(bobinaDesliga.id),
      'o selo não manteve K1 depois de soltar a partida');
  exigir(comDoisDesliga.bobinasLigadas.contains(bobinaDesliga.id),
      'K1 caiu antes do atraso');
  exigir(
      (comDoisDesliga.medidas[motorDesliga.id]!.potencia.abs() - 24).abs() <
          1e-3,
      'o motor parou com 2 s de 3 s');
  ok('com 2 s de 3 s o 67/68 NF continua fechado e o motor roda');

  // 32. Aos 3 s o 67/68 NF abre, derruba K1 e o motor para sozinho.
  final comTresDesliga = soltoDesliga.simular(
      bobinasLigadas: comMotor.bobinasLigadas, tempos: {ktDesliga.id: 3});
  exigir(!comTresDesliga.bobinasLigadas.contains(bobinaDesliga.id),
      'K1 continuou ligado depois do atraso');
  exigir(comTresDesliga.temporizadoresAtivos.isEmpty,
      'KT1 continuou energizado depois de derrubar K1');
  exigir(comTresDesliga.medidas[motorDesliga.id]!.potencia.abs() < 1e-9,
      'o motor continuou rodando depois do atraso: '
          '${comTresDesliga.medidas[motorDesliga.id]!.potencia} W');
  ok('aos 3 s o 67/68 NF abre, derruba K1 e o motor para sem apertar a parada');

  // 33. Sem energia o NF volta a fechar, mas K1 só religa com nova partida.
  exigir(nfDesliga.ativaEm(const {}, contatosTemporizados: const {}),
      'o 67/68 NF devia ficar fechado com o temporizador sem energia');
  exigir(!nfDesliga.ativaEm(const {}, contatosTemporizados: {nfDesliga.id}),
      'o 67/68 NF devia abrir quando o atraso se completa');
  final religado = ligadoDesliga.simular(bobinasLigadas: const {});
  exigir(religado.bobinasLigadas.contains(bobinaDesliga.id),
      'uma nova partida não puxou K1 depois do desligamento');
  ok('depois de desligar, o NF fecha e uma nova partida religa o motor');

  // 34. Desligamento temporizado: a partida liga K1 e o motor roda.
  final desligamentoQueda = circuitoExemplo('Desligamento temporizado');
  final ktQueda = desligamentoQueda.elementos
      .firstWhere((e) => e.tipo == TipoElemento.temporizador);
  final motorQueda = desligamentoQueda.elementos
      .firstWhere((e) => e.tipo == TipoElemento.motor);
  final bobinaQueda = desligamentoQueda.elementos
      .firstWhere((e) => e.tipo == TipoElemento.bobina);
  final contatoQueda = desligamentoQueda.elementos
      .firstWhere((e) => e.tipo == TipoElemento.contatoTemporizado);
  final partidaQueda = desligamentoQueda.elementos.firstWhere(
      (e) => e.tipo == TipoElemento.botoeira && !e.normalmenteFechado);
  final paradaQueda = desligamentoQueda.elementos.firstWhere(
      (e) => e.tipo == TipoElemento.botoeira && e.normalmenteFechado);
  exigir(ktQueda.atrasoQueda == 3, 'o exemplo não tem 3 s de retardo na queda');
  final partidaQ = desligamentoQueda
      .atualizar(partidaQueda.copiarCom(pressionada: true));
  final ligadoQ = partidaQ.simular();
  exigir(ligadoQ.bobinasLigadas.contains(bobinaQueda.id), 'K1 não puxou');
  exigir(ligadoQ.temporizadoresAtivos.contains(ktQueda.id),
      'KT1 não energizou');
  exigir((ligadoQ.medidas[motorQueda.id]!.potencia.abs() - 24).abs() < 1e-3,
      'o motor não rodou com 24 W: ${ligadoQ.medidas[motorQueda.id]!.potencia}');
  ok('partida liga K1 e o motor de 24 V / 24 W roda com 1 A');

  // 35. Solta a partida: o selo mantém, e aos 3 s o 67/68 fecha.
  final soltoQ = desligamentoQueda
      .atualizar(partidaQueda.copiarCom(pressionada: false));
  final comSeloQ =
      soltoQ.simular(bobinasLigadas: ligadoQ.bobinasLigadas);
  exigir(comSeloQ.bobinasLigadas.contains(bobinaQueda.id),
      'o selo não manteve K1 depois de soltar a partida');
  final carregadoQ = soltoQ.simular(
      bobinasLigadas: comSeloQ.bobinasLigadas,
      tempos: {ktQueda.id: ktQueda.atraso});
  exigir(contatoQueda.ativaEm(const {}, contatosTemporizados: {contatoQueda.id}),
      'o 67/68 não fechou com o atraso completo');
  ok('o selo mantém K1 e o 67/68 fecha aos 3 s de subida');

  // 36. Aperta a parada: K1 cai, mas o motor continua pelo retardo na queda.
  final paradoQ = soltoQ
      .atualizar(paradaQueda.copiarCom(pressionada: true))
      .simular(
          bobinasLigadas: carregadoQ.bobinasLigadas,
          tempos: {ktQueda.id: ktQueda.atraso},
          temposQueda: {ktQueda.id: 0});
  exigir(!paradoQ.bobinasLigadas.contains(bobinaQueda.id),
      'K1 continuou ligado depois da parada');
  exigir(paradoQ.temporizadoresAtivos.isEmpty,
      'KT1 continuou energizado depois da parada');
  exigir((paradoQ.medidas[motorQueda.id]!.potencia.abs() - 24).abs() < 1e-3,
      'o motor parou na hora, sem o retardo na queda: '
          '${paradoQ.medidas[motorQueda.id]!.potencia} W');
  ok('parada derruba K1, mas o motor continua pelo retardo na queda');

  // 37. Com 2 s de queda ainda roda; aos 3 s o contato abre e o motor para.
  final queda2s = soltoQ
      .atualizar(paradaQueda.copiarCom(pressionada: true))
      .simular(
          bobinasLigadas: carregadoQ.bobinasLigadas,
          tempos: {ktQueda.id: ktQueda.atraso},
          temposQueda: {ktQueda.id: 2});
  exigir((queda2s.medidas[motorQueda.id]!.potencia.abs() - 24).abs() < 1e-3,
      'o motor parou com 2 s de 3 s de queda');
  final queda3s = soltoQ
      .atualizar(paradaQueda.copiarCom(pressionada: true))
      .simular(
          bobinasLigadas: carregadoQ.bobinasLigadas,
          tempos: {ktQueda.id: ktQueda.atraso},
          temposQueda: {ktQueda.id: 3});
  exigir(queda3s.medidas[motorQueda.id]!.potencia.abs() < 1e-9,
      'o motor não parou no fim da queda: '
          '${queda3s.medidas[motorQueda.id]!.potencia} W');
  ok('o motor só para quando o retardo na queda completa os 3 s');

  // 38. Sem retardo na queda (0 s) o contato abre na hora.
  final semQueda = desligamentoQueda
      .atualizar(ktQueda.copiarCom(atrasoQueda: 0))
      .atualizar(partidaQueda.copiarCom(pressionada: false))
      .atualizar(paradaQueda.copiarCom(pressionada: true))
      .simular(
          bobinasLigadas: carregadoQ.bobinasLigadas,
          tempos: {ktQueda.id: ktQueda.atraso},
          temposQueda: {ktQueda.id: 0});
  exigir(semQueda.medidas[motorQueda.id]!.potencia.abs() < 1e-9,
      'com retardo na queda zero o motor devia parar na hora');
  ok('retardo na queda zero abre o contato na hora');

  // 39. Dois contatos do temporizador: partida liga K1 e KT1; o NF acende L2.
  final doisContatos = circuitoExemplo('Dois contatos do temporizador');
  final ktDois = doisContatos.elementos
      .firstWhere((e) => e.tipo == TipoElemento.temporizador);
  final naDois = doisContatos.elementos
      .firstWhere((e) => e.tipo == TipoElemento.contatoTemporizado);
  final nfDois = doisContatos.elementos
      .firstWhere((e) => e.tipo == TipoElemento.contatoTemporizadoNf);
  final bobinaDois = doisContatos.elementos
      .firstWhere((e) => e.tipo == TipoElemento.bobina);
  final lampadasDois =
      doisContatos.elementos.where((e) => e.tipo == TipoElemento.lampada).toList();
  final luzPronto = lampadasDois[0];
  final luzAguarde = lampadasDois[1];
  final partidaDois = doisContatos.elementos.firstWhere(
      (e) => e.tipo == TipoElemento.botoeira && !e.normalmenteFechado);
  final paradaDois = doisContatos.elementos
      .firstWhere((e) => e.tipo == TipoElemento.botoeira && e.normalmenteFechado);
  exigir(naDois.contatoDe == nfDois.contatoDe && naDois.contatoDe == ktDois.id,
      'os dois contatos do exemplo não apontam para o mesmo temporizador');
  exigir(ktDois.atraso == 3, 'o exemplo não tem atraso de 3 s');

  final ligadoDois = doisContatos
      .atualizar(partidaDois.copiarCom(pressionada: true))
      .simular();
  exigir(ligadoDois.bobinasLigadas.contains(bobinaDois.id), 'K1 não puxou');
  exigir(ligadoDois.temporizadoresAtivos.contains(ktDois.id),
      'KT1 não energizou');
  exigir(ligadoDois.medidas[luzAguarde.id]!.potencia.abs() - 5 < 1e-3,
      'a lâmpada do NF não acendeu antes do atraso');
  exigir(ligadoDois.medidas[luzPronto.id]!.potencia.abs() < 1e-9,
      'a lâmpada do NA acendeu antes do atraso');
  ok('partida liga K1 e KT1: o 67/68 NF acende L2 e o NA deixa L1 apagada');

  // 40. Aos 3 s o mesmo temporizador troca as duas lâmpadas.
  final soltoDois = doisContatos
      .atualizar(partidaDois.copiarCom(pressionada: false));
  final comSeloDois =
      soltoDois.simular(bobinasLigadas: ligadoDois.bobinasLigadas);
  exigir(comSeloDois.bobinasLigadas.contains(bobinaDois.id),
      'o selo não manteve K1 depois de soltar a partida');
  final tresDois = soltoDois.simular(
      bobinasLigadas: comSeloDois.bobinasLigadas,
      tempos: {ktDois.id: ktDois.atraso});
  exigir(tresDois.medidas[luzPronto.id]!.potencia.abs() - 5 < 1e-3,
      'a lâmpada do NA não acendeu aos 3 s');
  exigir(tresDois.medidas[luzAguarde.id]!.potencia.abs() < 1e-9,
      'a lâmpada do NF não apagou aos 3 s');
  ok('aos 3 s o 67/68 NA acende L1 e o 67/68 NF apaga L2');

  // 41. Os dois contatos são escolhidos um a um: dá para trocar o tipo de cada.
  final naViradoNf = naDois.copiarCom(tipo: TipoElemento.contatoTemporizadoNf);
  final nfViradoNa = nfDois.copiarCom(tipo: TipoElemento.contatoTemporizado);
  exigir(naViradoNf.tipo == TipoElemento.contatoTemporizadoNf,
      'o contato NA não virou NF');
  exigir(!naViradoNf.ativaEm(const {}, contatosTemporizados: {naViradoNf.id}),
      'o contato trocado para NF devia abrir com o atraso completo');
  exigir(nfViradoNa.ativaEm(const {}, contatosTemporizados: {nfViradoNa.id}),
      'o contato trocado para NA devia fechar com o atraso completo');
  final doisNas = doisContatos.atualizar(nfViradoNa);
  final rotulos = doisNas.rotulos();
  exigir(rotulos[naDois.id] != rotulos[nfDois.id],
      'dois contatos NA do mesmo temporizador ficaram com o mesmo rótulo');
  ok('cada contato troca de NA para NF sozinho e os rótulos não se repetem');

  // 42. Parada com retardo na queda zero: os dois contatos voltam ao repouso.
  final paradoDois = soltoDois
      .atualizar(paradaDois.copiarCom(pressionada: true))
      .simular(
          bobinasLigadas: tresDois.bobinasLigadas,
          tempos: {ktDois.id: ktDois.atraso},
          temposQueda: {ktDois.id: 0});
  exigir(!paradoDois.bobinasLigadas.contains(bobinaDois.id),
      'K1 continuou ligado depois da parada');
  exigir(paradoDois.medidas[luzPronto.id]!.potencia.abs() < 1e-9,
      'a lâmpada do NA não apagou com o temporizador sem energia');
  exigir(paradoDois.medidas[luzAguarde.id]!.potencia.abs() - 5 < 1e-3,
      'a lâmpada do NF não voltou a acender com o temporizador sem energia');
  ok('parada derruba K1 e os dois contatos voltam ao repouso');

  // 43. Contatos com tempos diferentes: cada contato usa o próprio atraso.
  final temposDiferentes = circuitoExemplo('Contatos com tempos diferentes');
  final ktTempos = temposDiferentes.elementos
      .firstWhere((e) => e.tipo == TipoElemento.temporizador);
  final naTempos = temposDiferentes.elementos
      .firstWhere((e) => e.tipo == TipoElemento.contatoTemporizado);
  final nfTempos = temposDiferentes.elementos
      .firstWhere((e) => e.tipo == TipoElemento.contatoTemporizadoNf);
  final luzRapida = temposDiferentes.elementos
      .where((e) => e.tipo == TipoElemento.lampada)
      .toList()[0];
  final luzLenta = temposDiferentes.elementos
      .where((e) => e.tipo == TipoElemento.lampada)
      .toList()[1];
  final bobinaTempos = temposDiferentes.elementos
      .firstWhere((e) => e.tipo == TipoElemento.bobina);
  final partidaTempos = temposDiferentes.elementos.firstWhere(
      (e) => e.tipo == TipoElemento.botoeira && !e.normalmenteFechado);
  final paradaTempos = temposDiferentes.elementos.firstWhere(
      (e) => e.tipo == TipoElemento.botoeira && e.normalmenteFechado);
  exigir(temposDiferentes.atrasoDoContato(naTempos) == 1,
      'o contato NA devia ter atraso próprio de 1 s');
  exigir(temposDiferentes.atrasoDoContato(nfTempos) == 5,
      'o contato NF devia ter atraso próprio de 5 s');
  exigir(ktTempos.atraso == 3, 'o ajuste base do temporizador devia ser 3 s');

  final ligadoTempos = temposDiferentes
      .atualizar(partidaTempos.copiarCom(pressionada: true))
      .simular();
  exigir(ligadoTempos.bobinasLigadas.contains(bobinaTempos.id), 'K1 não puxou');
  exigir(ligadoTempos.temporizadoresAtivos.contains(ktTempos.id),
      'KT1 não energizou');
  exigir(ligadoTempos.medidas[luzLenta.id]!.potencia.abs() - 5 < 1e-3,
      'a lâmpada do NF (5 s) não acendeu no começo');
  exigir(ligadoTempos.medidas[luzRapida.id]!.potencia.abs() < 1e-9,
      'a lâmpada do NA (1 s) acendeu antes do primeiro segundo');
  ok('os dois contatos do exemplo têm tempos próprios (1 s e 5 s)');

  // 44. Com 1 s o NA de 1 s fecha; o NF de 5 s continua fechado.
  final soltoTempos = temposDiferentes
      .atualizar(partidaTempos.copiarCom(pressionada: false));
  final umSegundo = soltoTempos.simular(
      bobinasLigadas: ligadoTempos.bobinasLigadas, tempos: {ktTempos.id: 1});
  exigir(umSegundo.medidas[luzRapida.id]!.potencia.abs() - 5 < 1e-3,
      'a lâmpada do NA não acendeu com 1 s');
  exigir(umSegundo.medidas[luzLenta.id]!.potencia.abs() - 5 < 1e-3,
      'a lâmpada do NF apagou antes dos 5 s');
  ok('com 1 s o 67/68 NA acende L1 e o 67/68 NF mantém L2 acesa');

  // 45. Com 5 s o NF de 5 s abre, e a lâmpada do NA continua acesa.
  final cincoSegundos = soltoTempos.simular(
      bobinasLigadas: ligadoTempos.bobinasLigadas, tempos: {ktTempos.id: 5});
  exigir(cincoSegundos.medidas[luzLenta.id]!.potencia.abs() < 1e-9,
      'a lâmpada do NF continuou acesa depois dos 5 s');
  exigir(cincoSegundos.medidas[luzRapida.id]!.potencia.abs() - 5 < 1e-3,
      'a lâmpada do NA apagou aos 5 s');
  ok('aos 5 s o 67/68 NF abre e L2 apaga, sem mexer em L1');

  // 46. Contato sem atraso próprio (0 s) usa o ajuste base do temporizador.
  final doisContatosBase = circuitoExemplo('Dois contatos do temporizador');
  final ktBase = doisContatosBase.elementos
      .firstWhere((e) => e.tipo == TipoElemento.temporizador);
  final naBase = doisContatosBase.elementos
      .firstWhere((e) => e.tipo == TipoElemento.contatoTemporizado);
  exigir(naBase.atraso == 0, 'o exemplo de base devia deixar o contato em 0 s');
  exigir(doisContatosBase.atrasoDoContato(naBase) == ktBase.atraso,
      'o contato em 0 s não herdou o atraso base do temporizador');
  final ligadoBase = doisContatosBase
      .atualizar(doisContatosBase.elementos
          .firstWhere((e) => e.tipo == TipoElemento.botoeira &&
              !e.normalmenteFechado)
          .copiarCom(pressionada: true))
      .simular();
  exigir(ligadoBase.temporizadoresAtivos.contains(ktBase.id),
      'KT1 não energizou no exemplo de base');
  ok('contato deixado em 0 s continua usando o ajuste base do temporizador');

  // 47. Parada com retardo na queda zero devolve os dois contatos ao repouso.
  final paradoTempos = soltoTempos
      .atualizar(paradaTempos.copiarCom(pressionada: true))
      .simular(
          bobinasLigadas: cincoSegundos.bobinasLigadas,
          tempos: {ktTempos.id: 5},
          temposQueda: {ktTempos.id: 0});
  exigir(!paradoTempos.bobinasLigadas.contains(bobinaTempos.id),
      'K1 continuou ligado depois da parada');
  exigir(paradoTempos.medidas[luzRapida.id]!.potencia.abs() < 1e-9,
      'a lâmpada do NA não apagou com o temporizador sem energia');
  exigir(paradoTempos.medidas[luzLenta.id]!.potencia.abs() - 5 < 1e-3,
      'a lâmpada do NF não voltou a acender sem energia no temporizador');
  ok('parada desenergiza o KT1 e os dois contatos voltam ao repouso');

  // 48. Quedas diferentes: cada contato segura pela própria queda.
  final quedasDiferentes = circuitoExemplo('Quedas diferentes no temporizador');
  final ktQuedas = quedasDiferentes.elementos
      .firstWhere((e) => e.tipo == TipoElemento.temporizador);
  final naQuedas = quedasDiferentes.elementos
      .firstWhere((e) => e.tipo == TipoElemento.contatoTemporizado);
  final nfQuedas = quedasDiferentes.elementos
      .firstWhere((e) => e.tipo == TipoElemento.contatoTemporizadoNf);
  final lampadasQuedas = quedasDiferentes.elementos
      .where((e) => e.tipo == TipoElemento.lampada)
      .toList();
  final luzCurta = lampadasQuedas[0];
  final luzLonga = lampadasQuedas[1];
  final bobinaQuedas = quedasDiferentes.elementos
      .firstWhere((e) => e.tipo == TipoElemento.bobina);
  final partidaQuedas = quedasDiferentes.elementos.firstWhere(
      (e) => e.tipo == TipoElemento.botoeira && !e.normalmenteFechado);
  final paradaQuedas = quedasDiferentes.elementos.firstWhere(
      (e) => e.tipo == TipoElemento.botoeira && e.normalmenteFechado);
  exigir(quedasDiferentes.atrasoQuedaDoContato(naQuedas) == 1,
      'o contato NA devia segurar 1 s na queda');
  exigir(quedasDiferentes.atrasoQuedaDoContato(nfQuedas) == 4,
      'o contato NF devia segurar 4 s na queda');
  exigir(ktQuedas.atrasoQueda == 2, 'o retardo base devia ser 2 s');

  final ligadoQuedas = quedasDiferentes
      .atualizar(partidaQuedas.copiarCom(pressionada: true))
      .simular();
  exigir(ligadoQuedas.bobinasLigadas.contains(bobinaQuedas.id), 'K1 não puxou');
  exigir(ligadoQuedas.medidas[luzLonga.id]!.potencia.abs() - 5 < 1e-3,
      'a lâmpada do NF não acendeu no começo');
  exigir(ligadoQuedas.medidas[luzCurta.id]!.potencia.abs() < 1e-9,
      'a lâmpada do NA acendeu antes do atraso');
  ok('partida energiza o KT1: o 67/68 NF mantém L2 acesa e o NA deixa L1 apagada');

  // 49. Aos 2 s de subida o NA fecha e o NF abre (mesmo atraso, quedas diferentes).
  final soltoQuedas = quedasDiferentes
      .atualizar(partidaQuedas.copiarCom(pressionada: false));
  final doisQuedas = soltoQuedas.simular(
      bobinasLigadas: ligadoQuedas.bobinasLigadas,
      tempos: {ktQuedas.id: 2});
  exigir(doisQuedas.medidas[luzCurta.id]!.potencia.abs() - 5 < 1e-3,
      'a lâmpada do NA não acendeu aos 2 s');
  exigir(doisQuedas.medidas[luzLonga.id]!.potencia.abs() < 1e-9,
      'a lâmpada do NF não apagou aos 2 s');
  ok('aos 2 s o 67/68 NA acende L1 e o 67/68 NF apaga L2');

  // 50. Na parada, cada contato segura pela própria queda: 1 s e 4 s.
  final paradoQuedas = soltoQuedas
      .atualizar(paradaQuedas.copiarCom(pressionada: true))
      .simular(
          bobinasLigadas: doisQuedas.bobinasLigadas,
          tempos: {ktQuedas.id: 2},
          temposQueda: {ktQuedas.id: 0});
  exigir(!paradoQuedas.bobinasLigadas.contains(bobinaQuedas.id),
      'K1 continuou ligado depois da parada');
  exigir(paradoQuedas.medidas[luzCurta.id]!.potencia.abs() - 5 < 1e-3,
      'o contato NA não segurou L1 no instante da parada');
  final queda1 = soltoQuedas
      .atualizar(paradaQuedas.copiarCom(pressionada: true))
      .simular(
          bobinasLigadas: doisQuedas.bobinasLigadas,
          tempos: {ktQuedas.id: 2},
          temposQueda: {ktQuedas.id: 1});
  exigir(queda1.medidas[luzCurta.id]!.potencia.abs() < 1e-9,
      'a lâmpada do NA não apagou com 1 s de queda');
  exigir(queda1.medidas[luzLonga.id]!.potencia.abs() < 1e-9,
      'a lâmpada do NF não continuou apagada com 1 s de queda');
  ok('com 1 s de queda o contato de 1 s abre e o de 4 s ainda segura');

  // 51. Aos 4 s de queda o contato do NF fecha e L2 volta a acender.
  final queda4 = soltoQuedas
      .atualizar(paradaQuedas.copiarCom(pressionada: true))
      .simular(
          bobinasLigadas: doisQuedas.bobinasLigadas,
          tempos: {ktQuedas.id: 2},
          temposQueda: {ktQuedas.id: 4});
  exigir(queda4.medidas[luzLonga.id]!.potencia.abs() - 5 < 1e-3,
      'a lâmpada do NF não voltou a acender aos 4 s de queda');
  exigir(queda4.medidas[luzCurta.id]!.potencia.abs() < 1e-9,
      'a lâmpada do NA religou aos 4 s de queda');
  ok('aos 4 s de queda o 67/68 NF fecha e L2 volta a acender');

  // 52. Contato com queda 0 s usa o retardo base do temporizador.
  final naSemQueda = naQuedas.copiarCom(atrasoQueda: 0);
  final semQuedaPropria = quedasDiferentes.atualizar(naSemQueda);
  exigir(semQuedaPropria.atrasoQuedaDoContato(naSemQueda) == ktQuedas.atrasoQueda,
      'o contato com 0 s não herdou o retardo base do temporizador');
  ok('contato com queda 0 s herda o retardo base do temporizador');

  // 53. Relógios independentes: cada contato tem o próprio tempo (2 s e 7 s).
  final relogios = circuitoExemplo('Relógios independentes no temporizador');
  final ktRelogios = relogios.elementos
      .firstWhere((e) => e.tipo == TipoElemento.temporizador);
  final naRelogios = relogios.elementos
      .firstWhere((e) => e.tipo == TipoElemento.contatoTemporizado);
  final nfRelogios = relogios.elementos
      .firstWhere((e) => e.tipo == TipoElemento.contatoTemporizadoNf);
  final lampadasRelogios = relogios.elementos
      .where((e) => e.tipo == TipoElemento.lampada)
      .toList();
  final luzDois = lampadasRelogios[0];
  final luzSete = lampadasRelogios[1];
  final bobinaRelogios = relogios.elementos
      .firstWhere((e) => e.tipo == TipoElemento.bobina);
  final partidaRelogios = relogios.elementos.firstWhere(
      (e) => e.tipo == TipoElemento.botoeira && !e.normalmenteFechado);
  exigir(ktRelogios.atraso == 12,
      'o ajuste base do temporizador devia ser 12 s e não ser usado pelos contatos');
  exigir(relogios.atrasoDoContato(naRelogios) == 2,
      'o contato NA devia contar 2 s próprios');
  exigir(relogios.atrasoDoContato(nfRelogios) == 7,
      'o contato NF devia contar 7 s próprios');
  final ligadoRelogios = relogios
      .atualizar(partidaRelogios.copiarCom(pressionada: true))
      .simular();
  exigir(ligadoRelogios.bobinasLigadas.contains(bobinaRelogios.id),
      'K1 não puxou no exemplo dos relógios independentes');
  exigir(ligadoRelogios.medidas[luzSete.id]!.potencia.abs() - 5 < 1e-3,
      'a lâmpada do NF não acendeu no começo');
  exigir(ligadoRelogios.medidas[luzDois.id]!.potencia.abs() < 1e-9,
      'a lâmpada do NA acendeu antes dos 2 s do próprio relógio');
  ok('partida liga o comando e cada contato espera o próprio relógio (2 s e 7 s)');

  // 54. O relógio de cada contato vale mesmo com o temporizador em 0 s.
  final soRelogioDoContato = relogios.simular(
      bobinasLigadas: ligadoRelogios.bobinasLigadas,
      tempos: {ktRelogios.id: 0},
      temposContato: {naRelogios.id: 2, nfRelogios.id: 2});
  exigir(soRelogioDoContato.medidas[luzDois.id]!.potencia.abs() - 5 < 1e-3,
      'o contato NA não fechou com 2 s no relógio próprio e 0 s no temporizador');
  exigir(soRelogioDoContato.medidas[luzSete.id]!.potencia.abs() - 5 < 1e-3,
      'o contato NF não devia continuar fechado aos 2 s, antes dos 7 s próprios');
  ok('o contato fecha pelo relógio próprio, sem depender do relógio do temporizador');

  // 55. Aos 7 s do relógio próprio o NF também troca, e o KT1 continua em 0 s.
  final seteSegundos = relogios.simular(
      bobinasLigadas: ligadoRelogios.bobinasLigadas,
      tempos: {ktRelogios.id: 0},
      temposContato: {naRelogios.id: 2, nfRelogios.id: 7});
  exigir(seteSegundos.medidas[luzSete.id]!.potencia.abs() < 1e-9,
      'a lâmpada do NF continuou acesa depois dos 7 s próprios');
  exigir(seteSegundos.medidas[luzDois.id]!.potencia.abs() - 5 < 1e-3,
      'a lâmpada do NA apagou aos 7 s');
  ok('aos 7 s o 67/68 NF abre L2, com o relógio do KT1 ainda em 0 s');

  // 56. Sem relógio de contato informado, vale o relógio do temporizador.
  final semRelogioProprio = relogios.simular(
      bobinasLigadas: ligadoRelogios.bobinasLigadas, tempos: {ktRelogios.id: 2});
  exigir(semRelogioProprio.medidas[luzDois.id]!.potencia.abs() - 5 < 1e-3,
      'o fallback para o relógio do temporizador deixou de funcionar');
  ok('circuito antigo sem relógio de contato continua usando o relógio do temporizador');

  // 57. Os dois contadores são guardados por contato, não compartilhados.
  final contatoLento = relogios.simular(
      bobinasLigadas: ligadoRelogios.bobinasLigadas,
      temposContato: {naRelogios.id: 6, nfRelogios.id: 1});
  exigir(contatoLento.medidas[luzDois.id]!.potencia.abs() - 5 < 1e-3,
      'o contato NA não fechou com 6 s no relógio dele');
  exigir(contatoLento.medidas[luzSete.id]!.potencia.abs() - 5 < 1e-3,
      'o contato NF não continuou fechado com 1 s próprio');
  ok('cada contato usa o próprio contador, mesmo com valores trocados');

  print('\nSimulador de circuitos: $checks grupos de verificação aprovados.');
}
