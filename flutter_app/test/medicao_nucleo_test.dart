import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/nucleo/medicao_nucleo.dart';

void main() {
  test('calcula quadros por segundo de cada modo', () {
    const medicao = MedicaoNucleo(
      quadrosNormal: 600,
      msNormal: 10000,
      quadrosEconomico: 200,
      msEconomico: 10000,
    );
    expect(medicao.fpsNormal, closeTo(60, 0.001));
    expect(medicao.fpsEconomico, closeTo(20, 0.001));
    expect(medicao.segundosNormais, 10);
    expect(medicao.segundosEconomicos, 10);
    expect(medicao.conclusiva, isTrue);
  });

  test('diferença percentual entre os modos', () {
    const medicao = MedicaoNucleo(
      quadrosNormal: 600,
      msNormal: 10000,
      quadrosEconomico: 200,
      msEconomico: 10000,
    );
    // 20 fps contra 60 fps = dois terços a menos.
    expect(medicao.diferencaPercentual, closeTo(-66.666, 0.01));
  });

  test('amostra curta não conclui', () {
    const medicao = MedicaoNucleo(
      quadrosNormal: 120,
      msNormal: 2000,
      quadrosEconomico: 40,
      msEconomico: 2000,
    );
    expect(medicao.temAmostra, isTrue);
    expect(medicao.conclusiva, isFalse,
        reason: '2 s em cada modo é pouco para concluir');
  });

  test('sem tempo no modo normal não inventa diferença', () {
    const medicao = MedicaoNucleo(quadrosEconomico: 100, msEconomico: 5000);
    expect(medicao.temAmostra, isFalse);
    expect(medicao.diferencaPercentual, isNull);
    expect(medicao.fpsNormal, 0);
  });

  test('lê o mapa do canal sem quebrar com valores ausentes', () {
    final medicao = MedicaoNucleo.deMapa({
      'normalQuadros': 300,
      'normalMs': 5000,
      'ecoQuadros': 100,
      'ecoMs': 5000,
    });
    expect(medicao.fpsNormal, closeTo(60, 0.001));
    expect(medicao.fpsEconomico, closeTo(20, 0.001));

    final vazio = MedicaoNucleo.deMapa(null);
    expect(vazio.quadrosNormal, 0);
    expect(vazio.diferencaPercentual, isNull);
  });
}
