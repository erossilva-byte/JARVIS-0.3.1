import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:gal/gal.dart';
import 'package:material_ui/material_ui.dart';
import 'package:image/image.dart' as img;

import '../core/visao.dart';
import '../core/visao_estruturada.dart';

const _ciano = Color(0xFF64E6FF);

/// Redimensiona para no máximo 1024 px no maior lado e recodifica em JPEG 80%.
///
/// O envio nunca usa o arquivo original da câmera: isso reduz o consumo de
/// tokens e mantém a imagem abaixo do limite de 4 MB.
Future<ImagemParaAnalise> prepararImagemParaEnvio(
  Uint8List bytes, {
  String nome = 'foto.jpg',
  String mime = 'image/jpeg',
}) async {
  final original = img.decodeImage(bytes);
  if (original == null) {
    throw StateError('A imagem não pôde ser lida. Escolha outra foto.');
  }
  final maior = math.max(original.width, original.height);
  final redimensionada = maior > 1024
      ? img.copyResize(
          original,
          width: original.width >= original.height ? 1024 : null,
          height: original.height > original.width ? 1024 : null,
          interpolation: img.Interpolation.average,
        )
      : original;
  final jpeg = Uint8List.fromList(img.encodeJpg(redimensionada, quality: 80));
  final recusa = validarImagemVisao(jpeg, 'image/jpeg');
  if (recusa != null) throw StateError(recusa);
  return ImagemParaAnalise(
    bytes: jpeg,
    mime: 'image/jpeg',
    nome: nome.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_'),
  );
}

Future<({int largura, int altura})> dimensoesImagem(Uint8List bytes) async {
  final decodificada = img.decodeImage(bytes);
  if (decodificada == null) {
    throw StateError('A imagem não pôde ser lida.');
  }
  return (largura: decodificada.width, altura: decodificada.height);
}

/// Desenha a foto original com as caixas e os rótulos dos objetos.
Future<Uint8List> imagemComBaloes({
  required Uint8List bytes,
  required AnaliseVisao analise,
}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final imagem = frame.image;
  final largura = imagem.width.toDouble();
  final altura = imagem.height.toDouble();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, largura, altura));
  canvas.drawImage(imagem, Offset.zero, Paint());

  final espessura = math.max(2.0, largura / 300);
  for (final objeto in analise.objetos) {
    final caixa = objeto.caixa;
    if (caixa == null || !caixa.valida) continue;
    final rect = Rect.fromLTWH(
      caixa.x * largura,
      caixa.y * altura,
      caixa.w * largura,
      caixa.h * altura,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = espessura
        ..color = _ciano,
    );

    final texto = rotuloSeguro(objeto.rotulo);
    if (texto.isEmpty) continue;
    final painter = TextPainter(
      text: TextSpan(
        text: texto,
        style: TextStyle(
          color: Colors.black,
          fontSize: (largura / 42).clamp(12.0, 28.0),
          fontWeight: FontWeight.w700,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: largura - 8);
    final etiqueta = Rect.fromLTWH(
      caixa.x * largura,
      math.max(0, caixa.y * altura - painter.height - 8),
      painter.width + 12,
      painter.height + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(etiqueta, const Radius.circular(4)),
      Paint()..color = _ciano,
    );
    painter.paint(canvas, Offset(etiqueta.left + 6, etiqueta.top + 3));
    painter.dispose();
  }

  final picture = recorder.endRecording();
  final saida = await picture.toImage(imagem.width, imagem.height);
  final dados = await saida.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  saida.dispose();
  imagem.dispose();
  if (dados == null) {
    throw StateError('Não foi possível gerar a imagem com os balões.');
  }
  return dados.buffer.asUint8List();
}

Future<void> salvarImagemNaGaleria(Uint8List bytes,
    {String nome = 'jarvis-visao'}) async {
  try {
    if (!await Gal.hasPermission()) {
      final autorizado = await Gal.requestPermission();
      if (!autorizado) {
        throw StateError('A permissão para salvar na galeria foi recusada.');
      }
    }
    await Gal.putImageBytes(bytes,
        name: '${nome}_${DateTime.now().millisecondsSinceEpoch}');
  } on GalException catch (erro) {
    throw StateError(_mensagemGal(erro));
  }
}

Future<void> salvarVideoNaGaleria(String caminho) async {
  try {
    if (!await Gal.hasPermission()) {
      final autorizado = await Gal.requestPermission();
      if (!autorizado) {
        throw StateError('A permissão para salvar na galeria foi recusada.');
      }
    }
    await Gal.putVideo(caminho);
  } on GalException catch (erro) {
    throw StateError(_mensagemGal(erro));
  }
}

String _mensagemGal(GalException erro) {
  return switch (erro.type) {
    GalExceptionType.permissionDenied =>
      'A permissão para salvar na galeria foi recusada.',
    GalExceptionType.notEnoughSpace =>
      'Não há espaço suficiente para salvar o arquivo.',
    GalExceptionType.notSupportedFormat =>
      'O formato do arquivo não é aceito pela galeria.',
    GalExceptionType.unexpected => 'Não foi possível salvar na galeria.',
  };
}
