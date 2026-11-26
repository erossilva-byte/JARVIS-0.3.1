import 'package:material_ui/material_ui.dart';
import 'package:qr/qr.dart';

import '../core/payload_qr.dart';

/// QR do pareamento, desenhado no próprio app (sem imagem na rede).
///
/// O conteúdo é o endereço do celular na rede local e o código de 6 dígitos. O
/// app do PC lê pela câmera e preenche os dois campos; quem digita continua
/// funcionando igual. O QR é só um atalho: o código e o prazo de 2 minutos
/// continuam valendo, e nada é autenticado sem a prova HMAC.
class QrPareamento extends StatelessWidget {
  const QrPareamento({super.key, required this.dados, this.tamanho = 208});

  final String dados;
  final double tamanho;

  /// Conteúdo lido pelo PC. Formato estável e curto, só com o necessário.
  static String payload({
    required String host,
    required int porta,
    required String codigo,
  }) =>
      payloadPareamento(host: host, porta: porta, codigo: codigo);

  @override
  Widget build(BuildContext context) {
    if (dados.trim().isEmpty) return const SizedBox.shrink();
    late final QrImage imagem;
    try {
      imagem = QrImage(QrCode(
        payload: QrPayload.fromString(dados),
        errorCorrectLevel: QrErrorCorrectLevel.medium,
      ));
    } catch (_) {
      return const SizedBox.shrink();
    }
    return Semantics(
      label: 'QR do pareamento. Se a câmera do PC não ler, digite o endereço '
          'e o código mostrados na tela.',
      child: Container(
        key: const ValueKey('pareamento-qr'),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: CustomPaint(
          size: Size.square(tamanho),
          painter: _PintorQr(imagem),
        ),
      ),
    );
  }
}

class _PintorQr extends CustomPainter {
  _PintorQr(this.imagem);

  final QrImage imagem;

  @override
  void paint(Canvas canvas, Size size) {
    final modulos = imagem.moduleCount;
    if (modulos <= 0) return;
    final lado = size.shortestSide / modulos;
    final tinta = Paint()..color = Colors.black;
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.white);
    for (var linha = 0; linha < modulos; linha++) {
      for (var coluna = 0; coluna < modulos; coluna++) {
        if (!imagem.isDark(linha, coluna)) continue;
        canvas.drawRect(
          Rect.fromLTWH(coluna * lado, linha * lado, lado.ceilToDouble(),
              lado.ceilToDouble()),
          tinta,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PintorQr antigo) => antigo.imagem != imagem;
}
