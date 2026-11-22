import 'package:flutter/services.dart';

class QuadroVideo {
  const QuadroVideo({
    required this.bytes,
    required this.tempoMs,
    required this.largura,
    required this.altura,
  });

  final Uint8List bytes;
  final int tempoMs;
  final int largura;
  final int altura;

  String get tempo => formatarTempoVideo(tempoMs);
}

class VideoQuadros {
  const VideoQuadros({required this.duracaoMs, required this.quadros});

  final int duracaoMs;
  final List<QuadroVideo> quadros;
}

abstract interface class ExtratorQuadros {
  Future<VideoQuadros> extrair(String caminho, {int maximo = 6});
}

class ExtratorQuadrosAndroid implements ExtratorQuadros {
  static const _canal = MethodChannel('com.jarvis.nova/visao-video');

  @override
  Future<VideoQuadros> extrair(String caminho, {int maximo = 6}) async {
    try {
      final dados =
          await _canal.invokeMethod<Map<Object?, Object?>>('extrairQuadros', {
        'caminho': caminho,
        'max': maximo.clamp(1, 8),
        'larguraMax': 1024,
      });
      if (dados == null) {
        throw StateError('O vídeo não devolveu quadros.');
      }
      final duracao = (dados['duracaoMs'] as num?)?.toInt() ?? 0;
      final lista = dados['quadros'];
      if (lista is! List) {
        throw StateError('O vídeo não devolveu quadros.');
      }
      final quadros = <QuadroVideo>[];
      for (final item in lista) {
        if (item is! Map) continue;
        final bytes = item['bytes'];
        if (bytes is! Uint8List) continue;
        quadros.add(QuadroVideo(
          bytes: bytes,
          tempoMs: (item['tempoMs'] as num?)?.toInt() ?? 0,
          largura: (item['largura'] as num?)?.toInt() ?? 1,
          altura: (item['altura'] as num?)?.toInt() ?? 1,
        ));
      }
      if (quadros.isEmpty) {
        throw StateError('Nenhum quadro pôde ser extraído do vídeo.');
      }
      return VideoQuadros(duracaoMs: duracao, quadros: quadros);
    } on MissingPluginException {
      throw StateError('A análise de vídeo está disponível no app Android.');
    } on PlatformException catch (erro) {
      throw StateError(erro.message?.trim().isNotEmpty == true
          ? erro.message!.trim()
          : 'Não foi possível ler o vídeo.');
    }
  }
}

String formatarTempoVideo(int tempoMs) {
  final total = (tempoMs / 1000).floor().clamp(0, 24 * 60 * 60);
  final minutos = total ~/ 60;
  final segundos = total % 60;
  return '$minutos:${segundos.toString().padLeft(2, '0')}';
}
