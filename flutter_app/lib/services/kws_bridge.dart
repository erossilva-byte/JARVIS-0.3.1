import 'dart:async';
import 'package:flutter/services.dart';

/// Contrato tipado entre Flutter e o serviço Android sherpa-onnx.
/// A ausência do plugin é reportada como indisponibilidade; nunca simula KWS ativo.
class KwsStatus {
  const KwsStatus({
    required this.available,
    required this.listening,
    required this.engine,
    this.detail = '',
  });

  final bool available;
  final bool listening;
  final String engine;
  final String detail;

  factory KwsStatus.fromMap(Map<Object?, Object?> map) => KwsStatus(
        available: map['available'] == true,
        listening: map['listening'] == true,
        engine: map['engine']?.toString() ?? '',
        detail: map['detail']?.toString() ?? '',
      );
}

class JarvisKwsBridge {
  JarvisKwsBridge({
    MethodChannel? methods,
    EventChannel? events,
  })  : _methods = methods ?? const MethodChannel('com.jarvis.nova/kws'),
        _events = events ?? const EventChannel('com.jarvis.nova/kws/events');

  final MethodChannel _methods;
  final EventChannel _events;

  Stream<String> get wakeEvents => _events
      .receiveBroadcastStream()
      .map((event) => event?.toString() ?? '')
      .where((keyword) => keyword.isNotEmpty)
      .asBroadcastStream();

  Future<KwsStatus> status() async {
    try {
      final result = await _methods.invokeMapMethod<Object?, Object?>('status');
      if (result == null) {
        return const KwsStatus(
          available: false,
          listening: false,
          engine: '',
          detail: 'O plugin nativo KWS não retornou diagnóstico.',
        );
      }
      return KwsStatus.fromMap(result);
    } on MissingPluginException {
      return const KwsStatus(
        available: false,
        listening: false,
        engine: '',
        detail: 'KWS ainda não conectado ao runner Flutter desta plataforma.',
      );
    }
  }

  Future<KwsStatus> start() => _command('start');
  Future<KwsStatus> stop() => _command('stop');
  Future<KwsStatus> startTest({int seconds = 20}) async {
    final bounded = seconds.clamp(10, 60);
    try {
      final result = await _methods.invokeMapMethod<Object?, Object?>(
        'test',
        {'seconds': bounded},
      );
      if (result == null) {
        throw PlatformException(
          code: 'empty_result',
          message: 'O plugin KWS não retornou o resultado do teste.',
        );
      }
      return KwsStatus.fromMap(result);
    } on MissingPluginException {
      return const KwsStatus(
        available: false,
        listening: false,
        engine: '',
        detail: 'Teste KWS indisponível: plugin nativo ainda não integrado.',
      );
    }
  }

  Future<KwsStatus> _command(String method) async {
    try {
      final result =
          await _methods.invokeMapMethod<Object?, Object?>(method);
      if (result == null) {
        throw PlatformException(
          code: 'empty_result',
          message: 'O plugin KWS não retornou diagnóstico.',
        );
      }
      return KwsStatus.fromMap(result);
    } on MissingPluginException {
      return const KwsStatus(
        available: false,
        listening: false,
        engine: '',
        detail: 'KWS ainda não conectado ao runner Flutter desta plataforma.',
      );
    }
  }
}
