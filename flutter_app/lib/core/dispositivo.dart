/// Dados reais do aparelho para a central da Fase 11.
///
/// Tudo vem do canal nativo; o modelo só formata o que o Android respondeu.
/// Campo ausente vira `null` e a tela mostra "não informado" — nunca um número
/// inventado.
library;

class AppInstalado {
  const AppInstalado({required this.pacote, required this.nome});

  final String pacote;
  final String nome;

  static AppInstalado? deMapa(Object? bruto) {
    if (bruto is! Map) return null;
    final pacote = bruto['pacote'];
    final nome = bruto['nome'];
    if (pacote is! String || pacote.trim().isEmpty) return null;
    return AppInstalado(
      pacote: pacote,
      nome: nome is String && nome.trim().isNotEmpty ? nome : pacote,
    );
  }
}

class InfoDispositivo {
  const InfoDispositivo({
    this.memoriaTotalMb,
    this.memoriaLivreMb,
    this.memoriaBaixa = false,
    this.armazenamentoTotalGb,
    this.armazenamentoLivreGb,
    this.uptimeMin,
    this.bateria,
    this.carregando = false,
    this.rede,
    this.apps = const [],
  });

  final int? memoriaTotalMb;
  final int? memoriaLivreMb;
  final bool memoriaBaixa;
  final double? armazenamentoTotalGb;
  final double? armazenamentoLivreGb;
  final int? uptimeMin;
  final int? bateria;
  final bool carregando;

  /// `wifi`, `movel` ou `offline`, como o Android informou.
  final String? rede;
  final List<AppInstalado> apps;

  bool get temMemoria => memoriaTotalMb != null && memoriaTotalMb! > 0;

  double? get memoriaLivrePct => temMemoria
      ? ((memoriaLivreMb ?? 0) / memoriaTotalMb! * 100).clamp(0, 100)
      : null;

  double? get armazenamentoLivrePct =>
      armazenamentoTotalGb != null && armazenamentoTotalGb! > 0
          ? ((armazenamentoLivreGb ?? 0) / armazenamentoTotalGb! * 100)
              .clamp(0, 100)
          : null;

  String get redeRotulo => switch (rede) {
        'wifi' => 'Wi-Fi',
        'movel' => 'Dados móveis',
        'offline' => 'Sem rede',
        _ => 'Não informado',
      };

  String get uptimeRotulo {
    final minutos = uptimeMin;
    if (minutos == null) return 'não informado';
    final dias = minutos ~/ 1440;
    final horas = (minutos % 1440) ~/ 60;
    final mins = minutos % 60;
    if (dias > 0) return '${dias}d ${horas}h';
    if (horas > 0) return '${horas}h ${mins}min';
    return '${mins}min';
  }

  static InfoDispositivo deMapa(Map<Object?, Object?>? dados) {
    if (dados == null) return const InfoDispositivo();
    final apps = <AppInstalado>[];
    final lista = dados['apps'];
    if (lista is List) {
      for (final item in lista) {
        final app = AppInstalado.deMapa(item);
        if (app != null) apps.add(app);
      }
    }
    return InfoDispositivo(
      memoriaTotalMb: _inteiro(dados['memoriaTotalMb']),
      memoriaLivreMb: _inteiro(dados['memoriaLivreMb']),
      memoriaBaixa: dados['memoriaBaixa'] == true,
      armazenamentoTotalGb: _decimal(dados['armazenamentoTotalGb']),
      armazenamentoLivreGb: _decimal(dados['armazenamentoLivreGb']),
      uptimeMin: _inteiro(dados['uptimeMin']),
      bateria: _inteiro(dados['bateria']),
      carregando: dados['carregando'] == true,
      rede: dados['rede'] is String ? dados['rede'] as String : null,
      apps: List.unmodifiable(apps),
    );
  }
}

int? _inteiro(Object? valor) => switch (valor) {
      int v => v,
      num v => v.toInt(),
      _ => null,
    };

double? _decimal(Object? valor) => switch (valor) {
      num v => v.toDouble(),
      _ => null,
    };
