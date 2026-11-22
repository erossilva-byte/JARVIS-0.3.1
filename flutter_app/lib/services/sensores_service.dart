import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/gestos.dart';

/// Falha explicada do canal de sensores; nunca vira “ligado” sem confirmação.
class SensoresIndisponivel implements Exception {
  const SensoresIndisponivel(this.mensagem);
  final String mensagem;
  @override
  String toString() => mensagem;
}

/// Ponte com os sensores e o brilho do aparelho.
///
/// Tudo roda no Android instalado: o acelerômetro, o brilho da janela e a
/// preferência guardada. Fora dele o canal não existe e a tela explica.
class SensoresService {
  const SensoresService();

  static const canal = MethodChannel('com.jarvis.nova/sensores');
  static const mensagemIndisponivel =
      'Gestos e modo noturno só existem no app Android instalado.';

  static bool get disponivel => defaultTargetPlatform == TargetPlatform.android;

  Future<EstadoGestos> estado() async {
    if (!disponivel) throw const SensoresIndisponivel(mensagemIndisponivel);
    try {
      return EstadoGestos.deMapa(await canal.invokeMethod<Object?>('estado'));
    } on MissingPluginException {
      throw const SensoresIndisponivel(mensagemIndisponivel);
    } on PlatformException catch (erro) {
      throw SensoresIndisponivel(
          erro.message ?? 'Não foi possível consultar os sensores.');
    }
  }

  Future<EstadoGestos> definirCalarAoVirar(bool ativo) async {
    if (!disponivel) throw const SensoresIndisponivel(mensagemIndisponivel);
    try {
      final dados = await canal
          .invokeMethod<Object?>('definirCalarAoVirar', {'ativo': ativo});
      return EstadoGestos.deMapa(dados);
    } on MissingPluginException {
      throw const SensoresIndisponivel(mensagemIndisponivel);
    } on PlatformException catch (erro) {
      throw SensoresIndisponivel(
          erro.message ?? 'Não foi possível guardar a opção.');
    }
  }

  Future<EstadoGestos> definirModoNoturno(bool ativo) async {
    if (!disponivel) throw const SensoresIndisponivel(mensagemIndisponivel);
    try {
      final dados = await canal
          .invokeMethod<Object?>('definirModoNoturno', {'ativo': ativo});
      return EstadoGestos.deMapa(dados);
    } on MissingPluginException {
      throw const SensoresIndisponivel(mensagemIndisponivel);
    } on PlatformException catch (erro) {
      throw SensoresIndisponivel(
          erro.message ?? 'Não foi possível guardar o modo noturno.');
    }
  }

  /// Ajusta o brilho (10–100) e devolve o valor realmente aplicado.
  Future<EstadoGestos> definirBrilho(int brilho) async {
    if (!disponivel) throw const SensoresIndisponivel(mensagemIndisponivel);
    try {
      final dados = await canal.invokeMethod<Object?>(
          'definirBrilho', {'brilho': brilhoSeguro(brilho)});
      return EstadoGestos.deMapa(dados);
    } on MissingPluginException {
      throw const SensoresIndisponivel(mensagemIndisponivel);
    } on PlatformException catch (erro) {
      throw SensoresIndisponivel(
          erro.message ?? 'Não foi possível aplicar o brilho.');
    }
  }

  /// Cala a fala agora, sem esperar o fim da resposta.
  Future<bool> calar() async {
    if (!disponivel) return false;
    try {
      final resposta = await canal.invokeMethod<bool>('calar');
      return resposta == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
