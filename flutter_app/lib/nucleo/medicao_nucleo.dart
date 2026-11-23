/// Medição do desenho do núcleo: quadros e tempo em cada modo.
///
/// Os números vêm do próprio desenho no Android, não de estimativa. Eles não
/// prometem bateria: dizem quantos quadros por segundo o núcleo desenhou em
/// cada modo e por quanto tempo. Amostra curta não vira conclusão.
class MedicaoNucleo {
  const MedicaoNucleo({
    this.quadrosNormal = 0,
    this.msNormal = 0,
    this.quadrosEconomico = 0,
    this.msEconomico = 0,
  });

  final int quadrosNormal;
  final int msNormal;
  final int quadrosEconomico;
  final int msEconomico;

  /// Quadros por segundo desenhados no modo normal.
  double get fpsNormal => msNormal <= 0 ? 0 : quadrosNormal * 1000 / msNormal;

  /// Quadros por segundo desenhados no modo econômico.
  double get fpsEconomico =>
      msEconomico <= 0 ? 0 : quadrosEconomico * 1000 / msEconomico;

  bool get temAmostra => msNormal > 0 && msEconomico > 0;

  /// Pelo menos 5 s em cada modo: abaixo disso a comparação não conclui nada.
  bool get conclusiva => msNormal >= 5000 && msEconomico >= 5000;

  /// Diferença percentual de quadros por segundo (negativa = econômico menor).
  double? get diferencaPercentual {
    if (!temAmostra || fpsNormal <= 0) return null;
    return (fpsEconomico - fpsNormal) / fpsNormal * 100;
  }

  double get segundosNormais => msNormal / 1000;
  double get segundosEconomicos => msEconomico / 1000;

  static MedicaoNucleo deMapa(Object? dados) {
    if (dados is! Map) return const MedicaoNucleo();
    int inteiro(String chave) {
      final valor = dados[chave];
      if (valor is int) return valor;
      if (valor is num) return valor.toInt();
      return 0;
    }

    return MedicaoNucleo(
      quadrosNormal: inteiro('normalQuadros'),
      msNormal: inteiro('normalMs'),
      quadrosEconomico: inteiro('ecoQuadros'),
      msEconomico: inteiro('ecoMs'),
    );
  }
}
