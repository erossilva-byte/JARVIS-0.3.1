/// Status de um aparelho — celular ou PC — num único modelo.
///
/// O mesmo painel precisa mostrar os dois lados: o PC onde o JARVIS roda e o
/// celular que ele acompanha. Cada plataforma entrega campos diferentes, e este
/// arquivo é o que impede duas telas de formatarem o mesmo número de dois jeitos.
///
/// Regra de honestidade: campo ausente não vira zero nem “desconhecido” com
/// número inventado — a linha simplesmente não aparece, e [semDados] diz que
/// aquele lado não respondeu.
library;

/// De onde veio o status.
enum OrigemStatus { celular, pc }

/// Linha pronta para a tela: rótulo curto e valor já formatado.
class LinhaStatus {
  const LinhaStatus(this.rotulo, this.valor);

  final String rotulo;
  final String valor;
}

/// Status de um aparelho, já normalizado.
class StatusPlataforma {
  const StatusPlataforma({
    required this.origem,
    this.cpu,
    this.ramTotal,
    this.ramLivre,
    this.discoTotal,
    this.discoLivre,
    this.uptimeTexto = '',
    this.bateria,
    this.carregando,
    this.temperatura,
    this.sistema = '',
    this.conexao = '',
  });

  final OrigemStatus origem;

  /// Carga do processador em %, quando a plataforma mede.
  final int? cpu;

  /// Memória e disco em bytes, como o Android e o Electron entregam.
  final int? ramTotal;
  final int? ramLivre;
  final int? discoTotal;
  final int? discoLivre;

  /// Tempo ligado já em texto (“2 dia(s) e 3 h”, “45 min”).
  final String uptimeTexto;

  /// Bateria em %, só no celular e em notebooks.
  final int? bateria;
  final bool? carregando;

  /// Temperatura em °C, quando o aparelho informa.
  final double? temperatura;

  /// Sistema ou modelo (“Android 14”, “Windows 11 · x64”).
  final String sistema;

  /// Rede ativa (“Wi-Fi”, “dados móveis”, “cabo”).
  final String conexao;

  bool get ehPc => origem == OrigemStatus.pc;

  /// Título do painel — é aqui que “PC” e “celular” se separam.
  String get titulo => ehPc ? 'Status do PC' : 'Status do celular';

  /// `true` quando nada de útil veio: a tela deve dizer isso, não inventar.
  bool get semDados =>
      cpu == null &&
      ramTotal == null &&
      discoTotal == null &&
      uptimeTexto.isEmpty &&
      bateria == null &&
      sistema.isEmpty &&
      conexao.isEmpty;

  /// Lê o mapa de qualquer uma das duas plataformas.
  ///
  /// Celular (Android): `bateria`, `temperatura`, `ramTotal`, `ramLivre`,
  /// `discoTotal`, `discoLivre`, `uptimeMin`, `conexao`, `modelo`.
  /// PC (Electron `status_pc`): `cpu`, `ramTotal`, `ramLivre`, `discoTotal`,
  /// `discoLivre`, `uptime` (texto), `aparelho`.
  static StatusPlataforma? deMapa(
    Map<Object?, Object?>? dados, {
    required OrigemStatus origem,
  }) {
    if (dados == null || dados.isEmpty) return null;
    final minutos = _inteiro(dados['uptimeMin']);
    return StatusPlataforma(
      origem: origem,
      cpu: _inteiro(dados['cpu']),
      ramTotal: _inteiro(dados['ramTotal']),
      ramLivre: _inteiro(dados['ramLivre']),
      discoTotal: _inteiro(dados['discoTotal']),
      discoLivre: _inteiro(dados['discoLivre']),
      uptimeTexto: _texto(dados['uptime']).isNotEmpty
          ? _texto(dados['uptime'])
          : minutos == null
              ? ''
              : _uptimeDeMinutos(minutos),
      bateria: _inteiro(dados['bateria']),
      carregando: dados['carregando'] is bool
          ? dados['carregando'] as bool
          : null,
      temperatura: _decimal(dados['temperatura']),
      sistema: _primeiroNaoVazio([dados['sistema'], dados['modelo']]),
      conexao: _texto(dados['conexao']),
    );
  }

  /// Linhas do painel, na ordem em que fazem sentido para a plataforma.
  List<LinhaStatus> get linhas {
    final saida = <LinhaStatus>[];
    if (cpu != null) {
      saida.add(LinhaStatus('Processador', '$cpu% de uso'));
    }
    final ram = _memoria(ramTotal, ramLivre);
    if (ram != null) saida.add(LinhaStatus('Memória', ram));
    final disco = _memoria(discoTotal, discoLivre);
    if (disco != null) saida.add(LinhaStatus('Disco', disco));
    if (uptimeTexto.isNotEmpty) {
      saida.add(LinhaStatus('Ligado há', uptimeTexto));
    }
    if (bateria != null) {
      final carga = carregando == true ? ' (carregando)' : '';
      saida.add(LinhaStatus('Bateria', '$bateria%$carga'));
    }
    if (temperatura != null) {
      saida.add(LinhaStatus('Temperatura', '${_numero(temperatura!)} °C'));
    }
    if (conexao.isNotEmpty) saida.add(LinhaStatus('Rede', conexao));
    if (sistema.isNotEmpty) saida.add(LinhaStatus('Sistema', sistema));
    return saida;
  }
}

int? _inteiro(Object? valor) {
  if (valor is int) return valor;
  if (valor is double) return valor.round();
  if (valor is String) return int.tryParse(valor.trim());
  return null;
}

double? _decimal(Object? valor) {
  if (valor is double) return valor;
  if (valor is int) return valor.toDouble();
  if (valor is String) return double.tryParse(valor.trim().replaceAll(',', '.'));
  return null;
}

String _texto(Object? valor) => valor is String ? valor.trim() : '';

String _primeiroNaoVazio(List<Object?> valores) {
  for (final valor in valores) {
    final texto = _texto(valor);
    if (texto.isNotEmpty) return texto;
  }
  return '';
}

/// “7,4 GB livres de 15,6 GB”; nulo quando não há os dois lados.
String? _memoria(int? total, int? livre) {
  if (total == null || total <= 0) return null;
  final usados = livre == null ? null : total - livre;
  if (usados == null) return '${_gigabytes(total)} no total';
  final percentual = (usados / total * 100).round();
  return '${_gigabytes(usados)} de ${_gigabytes(total)} em uso ($percentual%)';
}

String _gigabytes(int bytes) {
  final valor = bytes / 1024 / 1024 / 1024;
  final texto = valor >= 100
      ? valor.round().toString()
      : valor.toStringAsFixed(1).replaceAll('.', ',');
  return '$texto GB';
}

String _numero(double valor) =>
    valor == valor.roundToDouble() ? valor.round().toString() : valor.toStringAsFixed(1).replaceAll('.', ',');

String _uptimeDeMinutos(int minutos) {
  if (minutos < 60) return '$minutos min';
  final horas = minutos ~/ 60;
  if (horas < 24) return '$horas h';
  final dias = horas ~/ 24;
  final resto = horas % 24;
  return resto == 0 ? '$dias dia(s)' : '$dias dia(s) e $resto h';
}
