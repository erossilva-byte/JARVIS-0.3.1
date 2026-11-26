/// Clima a partir das coordenadas — contrato puro, sem Flutter e sem rede.
///
/// A fonte é o Open-Meteo, que responde sem chave e sem cadastro. Este arquivo
/// só monta o endereço, lê a resposta e escreve a frase em português; quem faz
/// a chamada é `services/clima_service.dart`.
///
/// Regra: campo ausente vira `null` e a frase não inventa número. Sem
/// coordenada não há previsão.
library;

import 'dart:convert';

/// Clima atual lido do provedor.
class ClimaAgora {
  const ClimaAgora({
    required this.temperatura,
    this.sensacao,
    this.codigo = -1,
    this.ventoKmh,
    this.umidade,
    this.chovendoMm = 0,
    this.minima,
    this.maxima,
    this.dia = false,
  });

  final double temperatura;
  final double? sensacao;
  final int codigo;
  final double? ventoKmh;
  final int? umidade;
  final double chovendoMm;
  final double? minima;
  final double? maxima;
  final bool dia;

  String get descricaoCodigo => descricaoClima(codigo);

  String get temperaturaRotulo => '${_graus(temperatura)} °C';
  String get sensacaoRotulo =>
      sensacao == null ? 'não informada' : '${_graus(sensacao!)} °C';

  /// `true` quando o provedor devolveu ao menos a temperatura.
  bool get valido => temperatura > -90 && temperatura < 70;
}

String _graus(double valor) {
  if (valor == valor.roundToDouble()) return valor.round().toString();
  return valor.toStringAsFixed(1).replaceAll('.', ',');
}

/// Códigos WMO usados pelo Open-Meteo, em português do Brasil.
String descricaoClima(int codigo) => switch (codigo) {
      0 => 'céu limpo',
      1 => 'predominantemente limpo',
      2 => 'parcialmente nublado',
      3 => 'nublado',
      45 || 48 => 'nevoeiro',
      51 || 53 || 55 => 'garoa',
      56 || 57 => 'garoa congelante',
      61 => 'chuva fraca',
      63 => 'chuva moderada',
      65 => 'chuva forte',
      66 || 67 => 'chuva congelante',
      71 || 73 || 75 => 'neve',
      77 => 'grãos de neve',
      80 || 81 || 82 => 'pancadas de chuva',
      85 || 86 => 'pancadas de neve',
      95 => 'trovoada',
      96 || 99 => 'trovoada com granizo',
      _ => 'condição não informada',
    };

/// Endereço do Open-Meteo para o ponto informado.
///
/// `timezone=auto` faz o provedor usar o fuso do próprio lugar — a mínima e a
/// máxima são do dia local, não do UTC.
String urlDoClima(double latitude, double longitude) {
  final lat = latitude.toStringAsFixed(4);
  final lon = longitude.toStringAsFixed(4);
  return 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
      '&current=temperature_2m,apparent_temperature,relative_humidity_2m,'
      'weather_code,wind_speed_10m,precipitation,is_day'
      '&daily=temperature_2m_max,temperature_2m_min'
      '&timezone=auto&forecast_days=1';
}

double? _numero(Object? valor) {
  if (valor is num) {
    final n = valor.toDouble();
    return n.isFinite ? n : null;
  }
  if (valor is String) {
    final n = double.tryParse(valor.replaceAll(',', '.'));
    return n != null && n.isFinite ? n : null;
  }
  return null;
}

/// Lê a resposta do Open-Meteo. Devolve `null` quando não há temperatura.
ClimaAgora? lerClima(String corpo) {
  late final Object? dados;
  try {
    dados = jsonDecode(corpo);
  } on FormatException {
    return null;
  }
  if (dados is! Map) return null;
  final atual = dados['current'];
  if (atual is! Map) return null;
  final temperatura = _numero(atual['temperature_2m']);
  if (temperatura == null) return null;

  double? minima;
  double? maxima;
  final diario = dados['daily'];
  if (diario is Map) {
    final mins = diario['temperature_2m_min'];
    final maxs = diario['temperature_2m_max'];
    if (mins is List && mins.isNotEmpty) minima = _numero(mins.first);
    if (maxs is List && maxs.isNotEmpty) maxima = _numero(maxs.first);
  }
  final codigo = _numero(atual['weather_code']);
  final umidade = _numero(atual['relative_humidity_2m']);
  return ClimaAgora(
    temperatura: temperatura,
    sensacao: _numero(atual['apparent_temperature']),
    codigo: codigo == null ? -1 : codigo.round(),
    ventoKmh: _numero(atual['wind_speed_10m']),
    umidade: umidade?.round(),
    chovendoMm: _numero(atual['precipitation']) ?? 0,
    minima: minima,
    maxima: maxima,
    dia: atual['is_day'] == 1 || atual['is_day'] == true,
  );
}

/// Frase falada e escrita. Usa o lugar quando ele é conhecido.
String fraseClima(ClimaAgora clima, {String lugar = ''}) {
  final onde = lugar.trim().isEmpty ? '' : ' em ${lugar.trim()}';
  final partes = <String>[
    'Agora faz ${clima.temperaturaRotulo}$onde',
    if (clima.sensacao != null) 'com sensação de ${clima.sensacaoRotulo}',
    clima.descricaoCodigo,
    if (clima.ventoKmh != null)
      'vento de ${clima.ventoKmh!.round()} km/h',
  ];
  final agora = '${partes.join(', ')}.';
  final extremos = clima.minima != null && clima.maxima != null
      ? ' Hoje a mínima é ${_graus(clima.minima!)} °C e a máxima, '
          '${_graus(clima.maxima!)} °C.'
      : '';
  return '$agora$extremos';
}

/// O texto pede clima? Só entra em pedido explícito de tempo/temperatura.
///
/// "Quanto tempo falta" e "quanto tempo dura" não são clima: por isso o verbo
/// de duração é descartado antes.
bool pedidoDeClima(String texto) {
  final limpo = _semAcento(texto).replaceAll(RegExp(r'\s+'), ' ').trim();
  if (limpo.isEmpty) return false;
  if (RegExp(r'\b(quanto tempo|tempo (?:falta|dura|leva|de)|'
          r'tempo todo|ao mesmo tempo|por quanto tempo)\b')
      .hasMatch(limpo)) {
    return false;
  }
  // Pedido explícito vem antes da guarda de pergunta: "como está o tempo?"
  // começa com "como" e mesmo assim é clima.
  if (RegExp(r'\b(como (?:esta|estao) o tempo|previsao do tempo|'
          r'tempo (?:hoje|agora|la fora)|clima|temperatura|'
          r'quantos graus|vai chover|vai fazer (?:frio|calor)|'
          r'esta (?:frio|calor)|faz (?:frio|calor))\b')
      .hasMatch(limpo)) {
    return true;
  }
  if (RegExp(r'\b(como|por que|porque)\b').hasMatch(limpo)) return false;
  return false;
}

String _semAcento(String texto) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const para = 'aaaaaeeeeiiiiooooouuuuc';
  final saida = StringBuffer();
  for (final rune in texto.toLowerCase().runes) {
    final caractere = String.fromCharCode(rune);
    final indice = de.indexOf(caractere);
    saida.write(indice < 0 ? caractere : para[indice]);
  }
  return saida.toString();
}
