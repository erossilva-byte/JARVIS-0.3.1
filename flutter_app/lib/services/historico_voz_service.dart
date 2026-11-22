import 'package:flutter/services.dart';

import '../core/historico_voz.dart';

/// Ponte com o histórico guardado pelo Android.
///
/// O histórico fica no aparelho, no mesmo armazenamento do serviço de segundo
/// plano, para registrar tanto o comando executado com a tela aberta quanto o que
/// rodou sem a tela. Fora do Android o canal não existe: a lista volta vazia e a
/// tela diz que o histórico só existe no app instalado.
abstract interface class HistoricoVozGateway {
  Future<List<RegistroExecucao>> carregar();

  Future<bool> limpar();

  Future<bool> registrar({
    required String pedido,
    required String acao,
    required bool ok,
    required String mensagem,
    required OrigemExecucao origem,
  });
}

class HistoricoVozService implements HistoricoVozGateway {
  HistoricoVozService({MethodChannel? canal})
      : _canal = canal ?? const MethodChannel('com.jarvis.nova/fundo');

  final MethodChannel _canal;

  @override
  Future<List<RegistroExecucao>> carregar() async {
    try {
      final bruto = await _canal.invokeListMethod<Object?>('historicoExecucoes');
      return registrosDeMapa(bruto);
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<bool> limpar() async {
    try {
      return await _canal.invokeMethod<bool>('limparHistorico') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> registrar({
    required String pedido,
    required String acao,
    required bool ok,
    required String mensagem,
    required OrigemExecucao origem,
  }) async {
    if (pedido.trim().isEmpty) return false;
    try {
      return await _canal.invokeMethod<bool>('registrarExecucao', {
            'pedido': pedido.trim(),
            'acao': acao.trim(),
            'ok': ok,
            'mensagem': mensagem.trim(),
            'origem': origem.id,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
