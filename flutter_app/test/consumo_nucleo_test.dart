import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/nucleo/consumo_nucleo.dart';

AmostraConsumo _amostra({
  String modo = 'normal',
  int duracaoMs = 60000,
  int cpuMs = 3000,
  int bateriaInicio = 80,
  int bateriaFim = 79,
  bool carregando = false,
  bool telaApagou = false,
}) =>
    AmostraConsumo(
      modo: modo,
      duracaoMs: duracaoMs,
      cpuMs: cpuMs,
      bateriaInicio: bateriaInicio,
      bateriaFim: bateriaFim,
      carregando: carregando,
      telaApagou: telaApagou,
    );

void main() {
  test('CPU por segundo e bateria por hora', () {
    final amostra = _amostra();
    expect(amostra.cpuMsPorSegundo, closeTo(50, 0.001));
    // 1% em 60 s = 60% por hora.
    expect(amostra.bateriaPorHora, closeTo(60, 0.001));
    expect(amostra.conclusiva, isTrue);
    expect(amostra.motivoInconclusivo, isEmpty);
  });

  test('janela curta não conclui', () {
    final amostra = _amostra(duracaoMs: 10000);
    expect(amostra.duracaoSuficiente, isFalse);
    expect(amostra.conclusiva, isFalse);
    expect(amostra.motivoInconclusivo, contains('Janela curta'));
  });

  test('carregando não vira taxa de bateria nem conclusão', () {
    final amostra = _amostra(carregando: true);
    expect(amostra.bateriaPorHora, isNull);
    expect(amostra.conclusiva, isFalse);
    expect(amostra.motivoInconclusivo, contains('carregando'));
  });

  test('tela apagada não conclui', () {
    final amostra = _amostra(telaApagou: true);
    expect(amostra.conclusiva, isFalse);
    expect(amostra.motivoInconclusivo, contains('tela apagou'));
  });

  test('sem queda de bateria não inventa taxa', () {
    final amostra = _amostra(bateriaFim: 80);
    expect(amostra.temQuedaDeBateria, isFalse);
    expect(amostra.bateriaPorHora, isNull);
    expect(amostra.motivoInconclusivo, contains('não caiu'));
  });

  test('diferença de CPU entre os modos', () {
    final consumo = ConsumoNucleo(
      normal: _amostra(cpuMs: 3000),
      economico: _amostra(modo: 'economico', cpuMs: 1500),
    );
    expect(consumo.diferencaCpuPercentual, closeTo(-50, 0.001));
    expect(consumo.comparacaoConclusiva, isTrue);
  });

  test('uma amostra inconclusiva deixa a comparação sem conclusão', () {
    final consumo = ConsumoNucleo(
      normal: _amostra(cpuMs: 3000),
      economico: _amostra(modo: 'economico', cpuMs: 1500, telaApagou: true),
    );
    expect(consumo.comparacaoConclusiva, isFalse);
    expect(consumo.diferencaCpuPercentual, closeTo(-50, 0.001));
  });

  test('lê o estado do canal e ignora amostra vazia', () {
    final consumo = ConsumoNucleo.deMapa({
      'medindo': true,
      'modoAtual': 'economico',
      'normal': {
        'modo': 'normal',
        'duracaoMs': 60000,
        'cpuMs': 3000,
        'bateriaInicio': 80,
        'bateriaFim': 79,
        'carregando': false,
        'telaApagou': false,
      },
      'economico': <String, Object?>{},
    });
    expect(consumo.medindo, isTrue);
    expect(consumo.normal?.cpuMsPorSegundo, closeTo(50, 0.001));
    expect(consumo.economico, isNull);
    expect(consumo.temComparacao, isFalse);
    expect(const ConsumoNucleo().diferencaCpuPercentual, isNull);
  });
}
