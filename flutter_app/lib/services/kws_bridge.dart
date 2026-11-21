import 'dart:async';
import 'package:flutter/services.dart';
import '../core/ativacao_sensibilidade.dart';

abstract interface class KwsGateway {
  Stream<String> get wakeEvents;
  Stream<KwsCommandEvent> get commandEvents;
  Future<KwsStatus> status();
  Future<KwsStatus> start();
  Future<KwsStatus> stop();
  Future<KwsStatus> startTest({int seconds = 20});

  /// Grava a sensibilidade da palavra de ativação no aparelho e devolve o
  /// estado já com o detector religado no limiar novo.
  Future<KwsStatus> definirSensibilidade(int valor);

  /// Relê as frases escolhidas nas preferências e religa o detector.
  ///
  /// As frases já foram gravadas pelo Flutter; o serviço Android lê as linhas
  /// tokenizadas direto de `FlutterSharedPreferences` também quando o app
  /// está fechado, então aqui só é preciso aplicar agora.
  Future<KwsStatus> aplicarHotword();
}

class KwsCommandEvent {
  const KwsCommandEvent(
      {required this.type, this.text = '', this.message = ''});
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
  const KwsStatus({
    required this.available,
    required this.listening,
    required this.engine,
    this.detail = '',
    this.ok = true,
    this.error = '',
    this.comandoAtivo = false,
    this.sensibilidade = AtivacaoSensibilidade.padrao,
    this.limiar = 0.25,
    this.hotword = 0,
  });
  final bool available;
  final bool listening;
  final String engine;
  final String detail;

  /// O microfone está com o comando por voz agora. Ligar o detector neste
  /// instante tomaria a captura e a transcrição voltaria vazia.
  final bool comandoAtivo;

  /// Saúde explícita do detector. `available` só diz que o plugin existe;
  /// não diz que a inferência iniciou. Erros de JNI chegam em [error].
  final bool ok;
  final String error;

  /// Sensibilidade da palavra de ativação em uso (0–100).
  final int sensibilidade;

  /// Limiar acústico que essa sensibilidade produziu no detector.
  final double limiar;

  /// Quantas frases de ativação o detector aceita agora.
  final int hotword;

  factory KwsStatus.fromMap(Map<Object?, Object?> map) {
    final detail = map['detail']?.toString() ?? '';
    final error = map['error']?.toString() ?? '';
    final ok = map['ok'] is bool ? map['ok'] as bool : error.isEmpty;
    return KwsStatus(
      available: map['available'] == true,
      listening: map['listening'] == true,
      engine: map['engine']?.toString() ?? '',
      detail: detail,
      ok: ok && error.isEmpty,
      error: error,
      comandoAtivo: map['comandoAtivo'] == true,
      sensibilidade: map['sensibilidade'] is num
          ? AtivacaoSensibilidade.segura(
              (map['sensibilidade'] as num).toInt())
          : AtivacaoSensibilidade.padrao,
      limiar: map['limiar'] is num
          ? (map['limiar'] as num).toDouble()
          : 0.25,
      hotword: map['hotword'] is num ? (map['hotword'] as num).toInt() : 0,
    );
  }
}

class JarvisKwsBridge implements KwsGateway {
  JarvisKwsBridge({MethodChannel? methods, EventChannel? events})
      : _methods = methods ?? const MethodChannel('com.jarvis.nova/kws'),
        _events = events ?? const EventChannel('com.jarvis.nova/kws/events');

  final MethodChannel _methods;
  final EventChannel _events;
  Stream<dynamic>? _nativeEvents;

  Stream<dynamic> get _eventStream =>
      _nativeEvents ??= _events.receiveBroadcastStream().asBroadcastStream();

  @override
  Stream<String> get wakeEvents => _eventStream
      .where((event) => event is Map && event['type'] == 'wake')
      .map((event) => (event as Map)['keyword']?.toString() ?? '')
      .where((keyword) => keyword.isNotEmpty);

  @override
  Stream<KwsCommandEvent> get commandEvents => _eventStream
      .where((event) =>
          event is Map &&
          event['type']?.toString().startsWith('command_') == true)
      .map(KwsCommandEvent.fromEvent);

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
            ok: false);
      }
      return KwsStatus.fromMap(result);
    } on MissingPluginException {
      return const KwsStatus(
          available: false,
          listening: false,
          engine: '',
          detail: 'KWS ainda não conectado ao runner Flutter desta plataforma.',
          ok: false);
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
      final result = await _methods
          .invokeMapMethod<Object?, Object?>('test', {'seconds': bounded});
      if (result == null) {
        throw PlatformException(
            code: 'empty_result',
            message: 'O plugin KWS não retornou o resultado do teste.');
      }
      return KwsStatus.fromMap(result);
    } on MissingPluginException {
      return const KwsStatus(
          available: false,
          listening: false,
          engine: '',
          detail: 'Teste KWS indisponível: plugin nativo ainda não integrado.',
          ok: false);
    }
  }

  @override
  Future<KwsStatus> definirSensibilidade(int valor) async {
    final seguro = AtivacaoSensibilidade.segura(valor);
    try {
      await _methods.invokeMethod<int>(
          'definirSensibilidade', {'valor': seguro});
    } on MissingPluginException {
      return const KwsStatus(
          available: false,
          listening: false,
          engine: '',
          detail: 'KWS ainda não conectado ao runner Flutter desta plataforma.',
          ok: false);
    }
    // Relê o estado para a tela mostrar o limiar que o Android realmente usa.
    return status();
  }

  @override
  Future<KwsStatus> aplicarHotword() async {
    try {
      final result =
          await _methods.invokeMapMethod<Object?, Object?>('aplicarHotword');
      if (result == null) {
        throw PlatformException(
            code: 'empty_result',
            message: 'O plugin KWS não retornou diagnóstico.');
      }
      return KwsStatus.fromMap(result);
    } on MissingPluginException {
      return const KwsStatus(
          available: false,
          listening: false,
          engine: '',
          detail: 'KWS ainda não conectado ao runner Flutter desta plataforma.',
          ok: false);
    }
  }

  Future<KwsStatus> _command(String method) async {
    try {
      final result = await _methods.invokeMapMethod<Object?, Object?>(method);
      if (result == null) {
        throw PlatformException(
            code: 'empty_result',
            message: 'O plugin KWS não retornou diagnóstico.');
      }
      return KwsStatus.fromMap(result);
    } on MissingPluginException {
      return const KwsStatus(
          available: false,
          listening: false,
          engine: '',
          detail: 'KWS ainda não conectado ao runner Flutter desta plataforma.',
          ok: false);
    }
  }
}
