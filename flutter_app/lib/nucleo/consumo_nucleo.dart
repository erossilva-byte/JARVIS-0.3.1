/// Consumo medido do núcleo, em janelas controladas.
///
/// O Android não entrega energia por janela sobreposta. O que dá para medir é o
/// CPU do processo (ms de CPU por segundo) e a variação do nível de bateria do
/// aparelho (% por hora). Isto compara os modos; não promete watts por núcleo.
class AmostraConsumo {
  const AmostraConsumo({
    required this.modo,
    required this.duracaoMs,
    required this.cpuMs,
    required this.bateriaInicio,
    required this.bateriaFim,
    required this.carregando,
    required this.telaApagou,
  });

  final String modo;
  final int duracaoMs;
  final int cpuMs;
  final int bateriaInicio;
  final int bateriaFim;
  final bool carregando;
  final bool telaApagou;

  bool get temDados => duracaoMs > 0;

  /// CPU do processo por segundo de janela.
  double get cpuMsPorSegundo => duracaoMs <= 0 ? 0 : cpuMs * 1000 / duracaoMs;

  bool get temQuedaDeBateria =>
      bateriaInicio >= 0 && bateriaFim >= 0 && bateriaFim < bateriaInicio;

  /// Bateria do aparelho por hora; `null` quando não há queda medível.
  double? get bateriaPorHora {
    if (!temDados || carregando || !temQuedaDeBateria) return null;
    return (bateriaInicio - bateriaFim) * 3600000 / duracaoMs;
  }

  /// Janela mínima para a comparação valer alguma coisa.
  bool get duracaoSuficiente => duracaoMs >= 20000;

  bool get conclusiva =>
      duracaoSuficiente && !carregando && !telaApagou && temQuedaDeBateria;

  /// Por que a amostra não conclui; vazio quando conclui.
  String get motivoInconclusivo {
    if (!temDados) return 'Sem dados suficientes.';
    if (!duracaoSuficiente) return 'Janela curta: menos de 20 s.';
    if (telaApagou) return 'A tela apagou durante a medição.';
    if (carregando) return 'O aparelho estava carregando.';
    if (!temQuedaDeBateria) {
      return 'A bateria não caiu o bastante para medir.';
    }
    return '';
  }

  static AmostraConsumo deMapa(Object? dados) {
    if (dados is! Map) {
      return const AmostraConsumo(
        modo: '',
        duracaoMs: 0,
        cpuMs: 0,
        bateriaInicio: -1,
        bateriaFim: -1,
        carregando: false,
        telaApagou: false,
      );
    }
    int inteiro(String chave, [int padrao = 0]) {
      final valor = dados[chave];
      if (valor is int) return valor;
      if (valor is num) return valor.toInt();
      return padrao;
    }

    return AmostraConsumo(
      modo: dados['modo']?.toString() ?? '',
      duracaoMs: inteiro('duracaoMs'),
      cpuMs: inteiro('cpuMs'),
      bateriaInicio: inteiro('bateriaInicio', -1),
      bateriaFim: inteiro('bateriaFim', -1),
      carregando: dados['carregando'] == true,
      telaApagou: dados['telaApagou'] == true,
    );
  }
}

/// Estado da medição: janela em andamento e a última amostra de cada modo.
class ConsumoNucleo {
  const ConsumoNucleo({
    this.medindo = false,
    this.modoAtual = '',
    this.normal,
    this.economico,
  });

  final bool medindo;
  final String modoAtual;
  final AmostraConsumo? normal;
  final AmostraConsumo? economico;

  bool get temComparacao => normal != null && economico != null;

  /// Diferença percentual de CPU por segundo (negativa = econômico menor).
  double? get diferencaCpuPercentual {
    final base = normal;
    final economia = economico;
    if (base == null || economia == null) return null;
    if (base.cpuMsPorSegundo <= 0) return null;
    return (economia.cpuMsPorSegundo - base.cpuMsPorSegundo) /
        base.cpuMsPorSegundo *
        100;
  }

  bool get comparacaoConclusiva =>
      temComparacao && normal!.conclusiva && economico!.conclusiva;

  static ConsumoNucleo deMapa(Object? dados) {
    if (dados is! Map) return const ConsumoNucleo();
    AmostraConsumo? amostra(Object? bruto) {
      if (bruto is! Map) return null;
      final valor = AmostraConsumo.deMapa(bruto);
      return valor.temDados ? valor : null;
    }

    return ConsumoNucleo(
      medindo: dados['medindo'] == true,
      modoAtual: dados['modoAtual']?.toString() ?? '',
      normal: amostra(dados['normal']),
      economico: amostra(dados['economico']),
    );
  }
}
