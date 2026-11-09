import 'dart:async';
import 'package:flutter/services.dart';

/// Contrato independente da plataforma para controlar o KWS local.
abstract interface class KwsGateway {
  Stream<String> get wakeEvents;
  Future<KwsStatus> status();
  Future<KwsStatus> start();
  Future<KwsStatus> stop();
  Future<KwsStatus> startTest({int seconds = 20});
}

/// Estado reportado pelo serviço nativo. Disponibilidade não significa que esteja ouvindo.
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

/// Implementação Flutter dos canais que o plugin Android deverá registrar.
/// Se o plugin não estiver instalado, o resultado é indisponível — nunca simula KWS.
class JarvisKwsBridge implements KwsGateway {
  JarvisKwsBridge({
    MethodChannel? methods,
    EventChannel? events,
  })  : _methods = methods ?? const MethodChannel('com.jarvis.nova/kws'),
        _events = events ?? const EventChannel('com.jarvis.nova/kws/events');

  final MethodChannel _methods;
  final EventChannel _events;
  Stream<String>? _wakeEvents;

  @override
  Stream<String> get wakeEvents => _wakeEvents ??= _events
      .receiveBroadcastStream()
      .map((event) => event?.toString() ?? '')
      .where((keyword) => keyword.isNotEmpty)
      .asBroadcastStream();

  @override
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

  @override
  Future<KwsStatus> start() => _command('start');

  @override
  Future<KwsStatus> stop() => _command('stop');

  @override
  Future<KwsStatus> startTest({int seconds = 20}) async {
    final bounded = seconds.clamp(10, 60).toInt();
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
