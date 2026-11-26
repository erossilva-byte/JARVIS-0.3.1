/// Conteúdo do QR de pareamento — Dart puro, sem Flutter.
///
/// Fica separado do desenho (`services/qr_pareamento.dart`) para o formato
/// poder ser testado sem `dart:ui`. O QR carrega o endereço do celular na rede
/// local e o código de 6 dígitos; nunca o token nem o desafio.
library;

/// `jarvis://parear?host=<ip>&porta=<porta>&codigo=<6 dígitos>`
String payloadPareamento({
  required String host,
  required int porta,
  required String codigo,
}) {
  final limpo = codigo.replaceAll(RegExp(r'\D'), '');
  return 'jarvis://parear?host=${host.trim()}&porta=$porta&codigo=$limpo';
}

/// Lê o payload de volta. Devolve `null` quando não é um QR do JARVIS.
({String host, int porta, String codigo})? lerPayloadPareamento(String texto) {
  final bruto = texto.trim();
  if (!bruto.startsWith('jarvis://parear')) return null;
  final query = bruto.contains('?') ? bruto.split('?').last : '';
  final campos = <String, String>{};
  for (final parte in query.split('&')) {
    final corte = parte.indexOf('=');
    if (corte <= 0) continue;
    campos[parte.substring(0, corte)] = Uri.decodeComponent(
        parte.substring(corte + 1));
  }
  final host = (campos['host'] ?? '').trim();
  final codigo = (campos['codigo'] ?? '').replaceAll(RegExp(r'\D'), '');
  final porta = int.tryParse(campos['porta'] ?? '');
  if (host.isEmpty || codigo.length != 6 || porta == null) return null;
  if (porta <= 0 || porta > 65535) return null;
  return (host: host, porta: porta, codigo: codigo);
}
