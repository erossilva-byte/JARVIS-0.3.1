import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Porta da câmera usada pela tela de visão.
///
/// A implementação real fica em [CameraAoVivo]. Testes e a prévia em desktop
/// podem usar uma implementação em memória sem tocar no plugin nativo.
abstract interface class CameraVisao {
  bool get disponivel;
  bool get gravando;
  bool get temFlash;
  bool get flashLigado;
  bool get suportada;
  double get zoom;
  double get zoomMin;
  double get zoomMax;
  int get totalCameras;
  String? get erro;

  Future<void> inicializar();
  Future<void> liberar();
  Widget construirPreview();
  Future<Uint8List> tirarFoto();
  Future<void> alternarCamera();
  Future<void> alternarFlash();
  Future<void> definirZoom(double valor);
  Future<void> iniciarVideo();
  Future<String> pararVideo();
}

String mensagemCamera(Object erro) {
  if (erro is CameraException) {
    switch (erro.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'cameraPermission':
        return 'A permissão da câmera foi recusada. Autorize a câmera nas configurações do Android.';
      case 'AudioAccessDenied':
      case 'AudioAccessDeniedWithoutPrompt':
        return 'A permissão do microfone foi recusada. Ela é necessária para gravar vídeo.';
      case 'cameraNotFound':
      case 'CameraNotFound':
        return 'Nenhuma câmera foi encontrada neste aparelho. Use a galeria para escolher uma imagem.';
      case 'CameraNotInitialized':
        return 'A câmera ainda não terminou de iniciar. Tente de novo em instantes.';
      default:
        return 'Não foi possível abrir a câmera (${erro.code}). Use a galeria ou tente de novo.';
    }
  }
  return 'Não foi possível abrir a câmera. Use a galeria ou tente de novo.';
}

class CameraAoVivo implements CameraVisao {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _indice = 0;
  bool _inicializada = false;
  bool _gravando = false;
  bool _flashLigado = false;
  FlashMode _flash = FlashMode.off;
  double _zoom = 1;
  double _zoomMin = 1;
  double _zoomMax = 5;
  String? _erro;

  @override
  bool get disponivel => _inicializada && _controller != null;
  @override
  bool get gravando => _gravando;
  @override
  bool get temFlash =>
      _controller?.description.lensDirection == CameraLensDirection.back;
  @override
  bool get flashLigado => _flashLigado;
  @override
  bool get suportada =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  @override
  double get zoom => _zoom;
  @override
  double get zoomMin => _zoomMin;
  @override
  double get zoomMax => _zoomMax;
  @override
  int get totalCameras => _cameras.length;
  @override
  String? get erro => _erro;

  @override
  Future<void> inicializar() async {
    if (!suportada) {
      _erro =
          'A câmera ao vivo está disponível no app Android. No computador, use a galeria.';
      return;
    }
    if (_inicializada) return;
    _erro = null;
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _erro = 'Nenhuma câmera foi encontrada neste aparelho. Use a galeria.';
        return;
      }
      _indice = 0;
      await _abrir(_cameras.first);
    } catch (erro) {
      _erro = mensagemCamera(erro);
      await _fecharControlador();
    }
  }

  Future<void> _abrir(CameraDescription descricao) async {
    await _fecharControlador();
    final controller = CameraController(
      descricao,
      ResolutionPreset.high,
      enableAudio: true,
    );
    _controller = controller;
    try {
      await controller.initialize();
      _inicializada = true;
      _flash = FlashMode.off;
      _flashLigado = false;
      _zoom = 1;
      try {
        _zoomMin = await controller.getMinZoomLevel();
        _zoomMax = await controller.getMaxZoomLevel();
      } catch (_) {
        _zoomMin = 1;
        _zoomMax = 5;
      }
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {
        // Alguns aparelhos não expõem flash; a câmera continua utilizável.
      }
    } catch (erro) {
      _inicializada = false;
      _erro = mensagemCamera(erro);
      await _fecharControlador();
      rethrow;
    }
  }

  Future<void> _fecharControlador() async {
    final controller = _controller;
    _controller = null;
    _inicializada = false;
    _gravando = false;
    if (controller != null) {
      try {
        if (controller.value.isRecordingVideo) {
          await controller.stopVideoRecording();
        }
      } catch (_) {
        // Fechar a câmera não pode derrubar a tela.
      }
      await controller.dispose();
    }
  }

  @override
  Future<void> liberar() async {
    await _fecharControlador();
    _erro = null;
  }

  @override
  Widget construirPreview() {
    final controller = _controller;
    if (controller == null || !_inicializada) {
      return const SizedBox.shrink();
    }
    return CameraPreview(controller);
  }

  CameraController get _ativo {
    final controller = _controller;
    if (controller == null || !_inicializada) {
      throw StateError('A câmera não está pronta.');
    }
    return controller;
  }

  @override
  Future<Uint8List> tirarFoto() async {
    final arquivo = await _ativo.takePicture();
    return arquivo.readAsBytes();
  }

  @override
  Future<void> alternarCamera() async {
    if (_gravando) {
      throw StateError('Pare a gravação antes de trocar de câmera.');
    }
    if (_cameras.length < 2) return;
    _indice = (_indice + 1) % _cameras.length;
    try {
      await _abrir(_cameras[_indice]);
    } catch (erro) {
      _erro = mensagemCamera(erro);
      rethrow;
    }
  }

  @override
  Future<void> alternarFlash() async {
    if (!temFlash) return;
    _flash = switch (_flash) {
      FlashMode.off => FlashMode.torch,
      FlashMode.torch => FlashMode.auto,
      _ => FlashMode.off,
    };
    _flashLigado = _flash == FlashMode.torch;
    try {
      await _ativo.setFlashMode(_flash);
    } catch (_) {
      _flash = FlashMode.off;
      _flashLigado = false;
      throw StateError('Este aparelho não permite controlar o flash.');
    }
  }

  @override
  Future<void> definirZoom(double valor) async {
    final alvo = valor.clamp(_zoomMin, _zoomMax);
    await _ativo.setZoomLevel(alvo);
    _zoom = alvo;
  }

  @override
  Future<void> iniciarVideo() async {
    if (_gravando) return;
    await _ativo.startVideoRecording();
    _gravando = true;
  }

  @override
  Future<String> pararVideo() async {
    if (!_gravando) throw StateError('Não há gravação em andamento.');
    try {
      final arquivo = await _ativo.stopVideoRecording();
      return arquivo.path;
    } finally {
      _gravando = false;
    }
  }
}
