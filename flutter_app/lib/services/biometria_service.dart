import 'package:flutter/services.dart';

import '../core/seguranca.dart';

/// Resultado de um pedido de biometria ou de credencial do aparelho.
class ResultadoBiometria {
  const ResultadoBiometria({required this.ok, required this.mensagem});

  final bool ok;
  final String mensagem;

  static const cancelado = ResultadoBiometria(
      ok: false, mensagem: 'Autenticação cancelada.');
}

abstract interface class BiometriaGateway {
  Future<BiometriaStatus> status();
  Future<ResultadoBiometria> autenticar({String motivo = ''});
  Future<ResultadoBiometria> confirmarCredencialDoAparelho({String motivo = ''});
}

/// Biometria pelo `BiometricPrompt`/impressão digital do Android.
///
/// Fora do Android o canal não existe: a resposta é "indisponível" e o PIN
/// continua sendo o único caminho, sem fingir que houve leitura biométrica.
class BiometriaService implements BiometriaGateway {
  BiometriaService({MethodChannel? canal})
      : _canal = canal ?? const MethodChannel('com.jarvis.nova/biometria');

  final MethodChannel _canal;

  @override
  Future<BiometriaStatus> status() async {
    try {
      final resposta = await _canal.invokeMapMethod<Object?, Object?>('estado');
      if (resposta == null) return BiometriaStatus.indisponivel;
      return BiometriaStatus.fromMap(resposta);
    } on MissingPluginException {
      return BiometriaStatus.indisponivel;
    } on PlatformException {
      return BiometriaStatus.indisponivel;
    }
  }

  @override
  Future<ResultadoBiometria> autenticar({String motivo = ''}) async {
    try {
      final resposta = await _canal.invokeMapMethod<Object?, Object?>(
          'autenticar', {'motivo': motivo});
      if (resposta == null) {
        return const ResultadoBiometria(
            ok: false, mensagem: 'O Android não respondeu ao pedido de biometria.');
      }
      return ResultadoBiometria(
        ok: resposta['ok'] == true,
        mensagem: resposta['mensagem']?.toString() ?? '',
      );
    } on MissingPluginException {
      return const ResultadoBiometria(
          ok: false, mensagem: 'Biometria só existe no app Android instalado.');
    } on PlatformException catch (erro) {
      return ResultadoBiometria(
        ok: false,
        mensagem: erro.message?.trim().isNotEmpty == true
            ? erro.message!
            : 'O Android recusou o pedido de biometria.',
      );
    }
  }

  @override
  Future<ResultadoBiometria> confirmarCredencialDoAparelho(
      {String motivo = ''}) async {
    try {
      final resposta = await _canal.invokeMapMethod<Object?, Object?>(
          'credencialAparelho', {'motivo': motivo});
      if (resposta == null) {
        return const ResultadoBiometria(
            ok: false,
            mensagem: 'O Android não respondeu ao pedido de credencial.');
      }
      return ResultadoBiometria(
        ok: resposta['ok'] == true,
        mensagem: resposta['mensagem']?.toString() ?? '',
      );
    } on MissingPluginException {
      return const ResultadoBiometria(
          ok: false,
          mensagem: 'A credencial do aparelho só existe no app Android instalado.');
    } on PlatformException catch (erro) {
      return ResultadoBiometria(
        ok: false,
        mensagem: erro.message?.trim().isNotEmpty == true
            ? erro.message!
            : 'O Android recusou a credencial do aparelho.',
      );
    }
  }
}
