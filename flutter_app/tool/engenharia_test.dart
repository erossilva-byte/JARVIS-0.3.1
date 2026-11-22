// ignore_for_file: avoid_print

import 'package:jarvis_nova/core/circuito.dart';
import 'package:jarvis_nova/core/clp.dart';
import 'package:jarvis_nova/core/engenharia.dart';

int checks = 0;

void ok(String nome) {
  checks++;
  print('OK: $nome');
}

void exigir(bool condicao, String mensagem) {
  if (!condicao) throw StateError(mensagem);
}

void perto(double a, double b, String nome, {double tolerancia = 0.01}) {
  exigir((a - b).abs() <= tolerancia, '$nome: esperado $b, obtido $a');
}

void main() {
  // Sensor de fim de curso: NF em repouso fecha o circuito e acende a lâmpada.
  final sensor = circuitoExemplo('Sensor de fim de curso');
  exigir(sensor.elementos.any((e) => e.sensor), 'exemplo sem sensor');
  final n = sensor.no;
  final idLampada = chaveTrecho(n(2, 0), n(3, 0));
  final repouso = sensor.simular();
  exigir(repouso.calculado, 'simulação em repouso falhou: ${repouso.erro}');
  final potenciaRepouso = repouso.medidas[idLampada]!.potencia;
  exigir(potenciaRepouso > 4, 'lâmpada deveria acender em repouso');
  ok('sensor NF em repouso mantém a lâmpada acesa');

  final sensorAcionado = sensor.elementos
      .firstWhere((e) => e.sensor)
      .copiarCom(pressionada: true);
  final acionado = sensor.atualizar(sensorAcionado).simular();
  exigir(acionado.calculado, 'simulação acionada falhou: ${acionado.erro}');
  final potenciaAcionada = acionado.medidas[idLampada]!.potencia;
  exigir(potenciaAcionada < 0.01, 'lâmpada deveria apagar com o sensor acionado');
  ok('sensor NF acionado interrompe a carga');
  exigir(sensor.rotulos()[sensorAcionado.id]!.startsWith('S'), 'rótulo do sensor');
  ok('rótulo do sensor usa S, não SB');

  // Diagnóstico: o curto do exemplo é reconhecido.
  final curto = circuitoExemplo('Curto protegido por fusível');
  final achadosCurto = diagnosticarCircuito(curto);
  exigir(achadosCurto.any((d) => d.tipo == TipoDiagnostico.curto),
      'curto não detectado');
  ok('diagnóstico detecta curto entre os polos da fonte');

  // Circuito normal não acusa curto e a continuidade entre polos é falsa.
  final normal = circuitoExemplo('Lâmpada e interruptor');
  final achadosNormal = diagnosticarCircuito(normal);
  exigir(!achadosNormal.any((d) => d.tipo == TipoDiagnostico.curto),
      'falso positivo de curto');
  final nn = normal.no;
  final fonte = normal.elementos.firstWhere((e) => e.tipo == TipoElemento.fonte);
  exigir(!haContinuidade(normal, fonte.a, fonte.b),
      'não há continuidade galvânica entre os polos com carga no meio');
  exigir(haContinuidade(normal, nn(0, 1), nn(1, 1)),
      'fio deveria dar continuidade entre nós vizinhos');
  ok('diagnóstico e continuidade coerentes no circuito normal');

  // Circuito incompleto: sem fonte, sem carga e contato órfão.
  final vazio = Circuito(elementos: [
    Elemento(id: chaveTrecho(0, 1), tipo: TipoElemento.contatoSelo, a: 0, b: 1, contatoDe: '9_9'),
  ]);
  final achadosVazio = diagnosticarCircuito(vazio);
  exigir(achadosVazio.any((d) => d.tipo == TipoDiagnostico.semFonte), 'sem fonte');
  exigir(achadosVazio.any((d) => d.tipo == TipoDiagnostico.semCarga), 'sem carga');
  exigir(achadosVazio.any((d) => d.tipo == TipoDiagnostico.contatoOrfao), 'órfão');
  ok('diagnóstico aponta fonte, carga e contato órfão ausentes');

  // Lista de materiais conta e nomeia.
  final bom = listaDeMateriais(normal);
  exigir(bom.contains('Lâmpada 5 W / 12 V'), 'BOM sem lâmpada');
  exigir(bom.contains('Fio de ligação'), 'BOM sem fios');
  exigir(bom.contains('Total: ${normal.elementos.length} elementos'), 'total do BOM');
  ok('lista de materiais gerada a partir do circuito');

  // Formato .circ: ida e volta preserva tudo, inclusive o sensor.
  final texto = circuitoParaTexto(sensor);
  final voltou = circuitoDeTexto(texto);
  exigir(voltou.colunas == sensor.colunas && voltou.linhas == sensor.linhas,
      'grade perdida no .circ');
  exigir(voltou.elementos.length == sensor.elementos.length, 'elementos perdidos');
  final sensorVolta = voltou.elementos.firstWhere((e) => e.sensor);
  exigir(sensorVolta.normalmenteFechado, 'NF do sensor perdido');
  exigir(sensorVolta.id == sensor.elementos.firstWhere((e) => e.sensor).id,
      'id do sensor perdido');
  final simVolta = voltou.simular();
  exigir(simVolta.calculado, 'circuito importado não simula');
  perto(simVolta.medidas[idLampada]!.potencia, potenciaRepouso,
      'potência após ida e volta');
  ok('exportar e importar .circ devolve o mesmo circuito');

  for (final invalido in [
    'não é json',
    '{"formato":"outro"}',
    '{"formato":"jarvis.circ","versao":99,"colunas":4,"linhas":3,"elementos":[]}',
    '{"formato":"jarvis.circ","versao":1,"colunas":4,"linhas":3,"elementos":[{"tipo":"foguete","a":0,"b":1}]}',
  ]) {
    var falhou = false;
    try {
      circuitoDeTexto(invalido);
    } on FormatException {
      falhou = true;
    }
    exigir(falhou, 'aceitou arquivo inválido: $invalido');
  }
  ok('importação recusa JSON inválido, formato errado e versão futura');

  // Dimensionamento: 1000 W em 220 V, 20 m.
  final d = dimensionarCarga(potenciaW: 1000, tensaoV: 220, comprimentoM: 20);
  perto(d.correnteNominal, 4.5454, 'corrente nominal', tolerancia: 0.01);
  perto(d.correnteProjeto, 5.6818, 'corrente de projeto', tolerancia: 0.01);
  perto(d.secaoMm2, 1.5, 'seção mínima');
  perto(d.disjuntor, 6, 'disjuntor');
  perto(d.quedaPercentual, 1.18, 'queda percentual', tolerancia: 0.05);
  exigir(d.aprovado, 'dimensionamento deveria aprovar');
  ok('dimensionamento de 1000 W / 220 V / 20 m: 1,5 mm², 6 A, queda 1,2%');

  final longo = dimensionarCarga(potenciaW: 3000, tensaoV: 127, comprimentoM: 60);
  exigir(!longo.aprovado, 'trecho longo deveria reprovar pela queda');
  exigir(longo.observacoes.any((o) => o.contains('Acima do limite')), 'aviso de queda');
  ok('dimensionamento reprova queda acima de 4% e explica');

  final motor = dimensionarMotor(potenciaW: 750, tensaoV: 220, comprimentoM: 15);
  perto(motor.correnteNominal, 5.0147, 'corrente do motor', tolerancia: 0.05);
  exigir(motor.observacoes.any((o) => o.contains('partida estimada')), 'partida');
  ok('dimensionamento de motor informa corrente de partida');

  var recusou = false;
  try {
    dimensionarCarga(potenciaW: 0, tensaoV: 220, comprimentoM: 10);
  } on ArgumentError {
    recusou = true;
  }
  exigir(recusou, 'aceitou potência zero');
  ok('dimensionamento recusa entrada inválida');

  // CLP didático: partida com selo mantém Q1 e a parada derruba.
  final clp = clpPartidaComSelo();
  exigir(entradasDoClp(clp).join(',') == 'I1,I2', 'entradas do CLP');
  var r = clp.executar({'I1': false, 'I2': false});
  exigir(r.estabilizou && r.saidas['Q1'] == false, 'Q1 deveria começar desligada');
  r = clp.executar({'I1': true, 'I2': false});
  exigir(r.saidas['Q1'] == true, 'partida deveria ligar Q1');
  r = clp.executar({'I1': false, 'I2': false}, saidasIniciais: r.saidas);
  exigir(r.saidas['Q1'] == true, 'selo deveria manter Q1 ligada');
  r = clp.executar({'I1': false, 'I2': true}, saidasIniciais: r.saidas);
  exigir(r.saidas['Q1'] == false, 'parada deveria derrubar Q1');
  ok('CLP: partida com selo liga, mantém e a parada derruba');

  final outra = clpLigaDesliga();
  final r2 = outra.executar({'I1': true, 'I2': false});
  exigir(r2.estabilizou, 'programa deveria estabilizar');
  exigir(r2.saidas['Q1'] == true && r2.saidas['Q2'] == true, 'Q1 e Q2');
  final r3 = outra.executar({'I1': true, 'I2': true},
      saidasIniciais: r2.saidas);
  exigir(r3.saidas['Q2'] == false, 'I2 deveria desligar Q2');
  ok('CLP: segundo programa encadeia Q1 em Q2');

  print('\n$checks verificações de engenharia aprovadas.');
}
