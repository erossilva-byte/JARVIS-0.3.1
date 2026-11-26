import 'dart:async';

import 'package:http/http.dart' as http;

import '../core/clima.dart';
import '../core/localizacao.dart';
import 'localizacao_service.dart';

/// Falha do clima já explicada para a tela e para a voz.
class ClimaIndisponivel implements Exception {
  const ClimaIndisponivel(this.mensagem);
  final String mensagem;
  @override
  String toString() => mensagem;
}

/// Consulta o clima do lugar onde o aparelho está.
///
/// Usa a última localização guardada ([LocalizacaoService]) e o Open-Meteo, que
/// responde sem chave. O resultado fica em memória por [validade] para uma
/// pergunta atrás da outra não repetir a chamada.
class ClimaService {
  ClimaService({
    http.Client? client,
    LocalizacaoService? localizacao,
    DateTime Function()? relogio,
  })  : _client = client ?? http.Client(),
        _localizacao = localizacao ?? LocalizacaoService(),
        _agora = relogio ?? DateTime.now;

  final http.Client _client;
  final LocalizacaoService _localizacao;
  final DateTime Function() _agora;

  static const validade = Duration(minutes: 10);

  ClimaAgora? _cache;
  String _lugarCache = '';
  DateTime? _buscadoEm;

  /// `true` só quando existe posição conhecida: sem ela não há previsão.
  Future<bool> temLocalizacao() async =>
      (await _localizacao.ultima(exigirValidade: false)) != null;

  /// Clima do lugar atual. Lança [ClimaIndisponivel] com o motivo.
  Future<({ClimaAgora clima, String lugar})> atual({bool forcar = false}) async {
    final emCache = _vivo();
    if (emCache != null && !forcar) return emCache;

    final LocalizacaoAparelho? local = await _localizacao.atualizar();
    if (local == null || !local.valida) {
      throw const ClimaIndisponivel(
          'Ainda não sei onde você está. Abra a Central do aparelho, toque em '
          '“Ver minha localização” e autorize o GPS para eu falar a temperatura certa.');
    }

    late http.Response resposta;
    try {
      resposta = await _client
          .get(Uri.parse(urlDoClima(local.latitude!, local.longitude!)))
          .timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw const ClimaIndisponivel(
          'O serviço de clima demorou mais de 12 segundos. Tente de novo.');
    } on http.ClientException {
      throw const ClimaIndisponivel(
          'Não consegui alcançar o serviço de clima. Confira o Wi-Fi ou o 5G.');
    }
    if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
      throw ClimaIndisponivel(
          'O serviço de clima não respondeu agora (HTTP ${resposta.statusCode}).');
    }
    final clima = lerClima(resposta.body);
    if (clima == null) {
      throw const ClimaIndisponivel(
          'O serviço de clima respondeu num formato que o app não entendeu.');
    }
    final lugar = local.endereco.trim();
    _cache = clima;
    _lugarCache = lugar;
    _buscadoEm = _agora();
    return (clima: clima, lugar: lugar);
  }

  /// Frase pronta para falar.
  Future<String> frase() async {
    final achado = await atual();
    return fraseClima(achado.clima, lugar: achado.lugar);
  }

  ({ClimaAgora clima, String lugar})? _vivo() {
    final quando = _buscadoEm;
    final clima = _cache;
    if (quando == null || clima == null) return null;
    if (_agora().difference(quando) > validade) return null;
    return (clima: clima, lugar: _lugarCache);
  }

  void close() => _client.close();
}
