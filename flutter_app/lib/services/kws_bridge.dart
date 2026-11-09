import 'dart:async';
import 'package:flutter/services.dart';

abstract interface class KwsGateway {
  Stream<String> get wakeEvents;
  Stream<KwsCommandEvent> get commandEvents;
  Future<KwsStatus> status();
  Future<KwsStatus> start();
  Future<KwsStatus> stop();
  Future<KwsStatus> startTest({int seconds = 20});
}

class KwsCommandEvent {
  const KwsCommandEvent({required this.type, this.text = '', this.message = ''});
  final String type;
  final String text;
  final String message;

  factory KwsCommandEvent.fromEvent(Object? event) {
    if (event is! Map) return const KwsCommandEvent(type: 'unknown');
    return KwsCommandEvent(
      type: event['type']?.toString() ?? 'unknown',
      text: event['text']?.toString() ?? '',
      message: event['message']?.toString() ?? '',
    );
  }
}

class KwsStatus {
  const KwsStatus({required this.available, required this.listening, required this.engine, this.detail = ''});
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

class JarvisKwsBridge implements KwsGateway {
  JarvisKwsBridge({MethodChannel? methods, EventChannel? events})
      : _methods = methods ?? const MethodChannel('com.jarvis.nova/kws'),
        _events = events ?? const EventChannel('com.jarvis.nova/kws/events');

  final MethodChannel _methods;
  final EventChannel _events;
  Stream<dynamic>? _nativeEvents;

  Stream<dynamic> get _eventStream => _nativeEvents ??= _events.receiveBroadcastStream().asBroadcastStream();

  @override
  Stream<String> get wakeEvents => _eventStream
      .where((event) => event is Map && event['type'] == 'wake')
      .map((event) => (event as Map)['keyword']?.toString() ?? '')
      .where((keyword) => keyword.isNotEmpty);

  @override
  Stream<KwsCommandEvent> get commandEvents => _eventStream
      .where((event) => event is Map && event['type']?.toString().startsWith('command_') == true)
      .map(KwsCommandEvent.fromEvent);

  @override
  Future<KwsStatus> status() async {
    try {
      final result = await _methods.invokeMapMethod<Object?, Object?>('status');
      if (result == null) {
        return const KwsStatus(available: false, listening: false, engine: '', detail: 'O plugin nativo KWS não retornou diagnóstico.');
      }
      return KwsStatus.fromMap(result);
    } on MissingPluginException {
      return const KwsStatus(available: false, listening: false, engine: '', detail: 'KWS ainda não conectado ao runner Flutter desta plataforma.');
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
      final result = await _methods.invokeMapMethod<Object?, Object?>('test', {'seconds': bounded});
      if (result == null) {
        throw PlatformException(code: 'empty_result', message: 'O plugin KWS não retornou o resultado do teste.');
      }
      return KwsStatus.fromMap(result);
    } on MissingPluginException {
      return const KwsStatus(available: false, listening: false, engine: '', detail: 'Teste KWS indisponível: plugin nativo ainda não integrado.');
    }
  }

  Future<KwsStatus> _command(String method) async {
    try {
      final result = await _methods.invokeMapMethod<Object?, Object?>(method);
      if (result == null) {
        throw PlatformException(code: 'empty_result', message: 'O plugin KWS não retornou diagnóstico.');
      }
      return KwsStatus.fromMap(result);
    } on MissingPluginException {
      return const KwsStatus(available: false, listening: false, engine: '', detail: 'KWS ainda não conectado ao runner Flutter desta plataforma.');
    }
  }
}
