import 'package:jarvis_nova/core/payload_qr.dart';

void exigir(bool ok, String mensagem) {
  if (!ok) {
    // ignore: avoid_print
    print('FALHOU: $mensagem');
    throw StateError(mensagem);
  }
}

void main() {
  final payload =
      payloadPareamento(host: '192.168.0.20', porta: 47600, codigo: '123456');
  exigir(payload.startsWith('jarvis://parear?'), 'esquema do QR mudou');
  exigir(payload.contains('host=192.168.0.20'), 'faltou o host');
  exigir(payload.contains('porta=47600'), 'faltou a porta');
  exigir(payload.contains('codigo=123456'), 'faltou o código');
  // O QR não carrega token nem desafio: nada secreto vai no código impresso.
  for (final proibido in ['token', 'desafio', 'senha', 'chave']) {
    exigir(!payload.contains(proibido), 'QR carrega $proibido');
  }

  final lido = lerPayloadPareamento(payload);
  exigir(lido != null, 'não leu de volta o próprio QR');
  exigir(lido!.host == '192.168.0.20', 'host voltou errado');
  exigir(lido.porta == 47600, 'porta voltou errada');
  exigir(lido.codigo == '123456', 'código voltou errado');

  // Código com espaço e QR de outro app são recusados.
  exigir(
      lerPayloadPareamento(
              payloadPareamento(host: '10.0.0.2', porta: 1, codigo: '12 34 56'))!
          .codigo ==
      '123456',
      'não normalizou o código');
  exigir(lerPayloadPareamento('https://exemplo.com') == null,
      'aceitou link que não é do pareamento');
  exigir(lerPayloadPareamento('jarvis://parear?host=&porta=1&codigo=123456') ==
      null, 'aceitou QR sem host');

  // ignore: avoid_print
  print('OK: QR do pareamento (host, porta e código, sem segredo)');
}
