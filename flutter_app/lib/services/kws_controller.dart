import 'dart:async';
import 'package:flutter/foundation.dart';
import 'kws_bridge.dart';

enum KwsPhase { unknown, unavailable, idle, starting, listening, stopping, error }

class KwsController extends ChangeNotifier {
  KwsController({KwsGateway? gateway}) : _gateway = gateway ?? JarvisKwsBridge();

  static final StreamController<KwsCommandEvent> _commandBus = StreamController<KwsCommandEvent>.broadcast();
  static Stream<KwsCommandEvent> get commandBus => _commandBus.stream;

  final KwsGateway _gateway;
  StreamSubscription<String>? _wakeSubscription;
  StreamSubscription<KwsCommandEvent>? _commandSubscription;
  KwsPhase _phase = KwsPhase.unknown;
  KwsStatus _status = const KwsStatus(available: false, listening: false, engine: '', detail: 'Diagnóstico ainda não executado.');
  String? _lastWake;
  String? _lastCommand;
  String? _commandMessage;
  String? _error;
  bool _busy = false;
  bool _disposed = false;

  KwsPhase get phase => _phase;
  KwsStatus get status => _status;
  String? get lastWake => _lastWake;
  String? get lastCommand => _lastCommand;
  String? get commandMessage => _commandMessage;
  String? get error => _error;
  bool get busy => _busy;

  Future<KwsStatus> initialize() async {
    if (_disposed) return _status;
    try {
      await _listenForEvents();
    } catch (e) {
      _fail(e);
      return _status;
    }
    return refresh();
  }

  Future<KwsStatus> refresh() async {
    if (_disposed) return _status;
    try { _apply(await _gateway.status()); } catch (e) { _fail(e); }
    return _status;
  }

  Future<KwsStatus> start() => _run(transitional: KwsPhase.starting, action: _gateway.start);
  Future<KwsStatus> stop() => _run(transitional: KwsPhase.stopping, action: _gateway.stop);
  Future<KwsStatus> startTest({int seconds = 20}) => _run(
        transitional: KwsPhase.starting,
        action: () => _gateway.startTest(seconds: seconds),
      );

  Future<KwsStatus> _run({required KwsPhase transitional, required Future<KwsStatus> Function() action}) async {
    if (_disposed || _busy) return _status;
    _busy = true;
    _error = null;
    _phase = transitional;
    _notify();
    try {
      if (transitional == KwsPhase.starting) await _listenForEvents();
      final result = await action();
      _apply(result);
      return _status;
    } catch (e) {
      _fail(e);
      return _status;
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> _listenForEvents() async {
    _wakeSubscription ??= _gateway.wakeEvents.listen((keyword) {
      if (_disposed) return;
      _lastWake = keyword;
      _notify();
    }, onError: (Object error) {
      if (_disposed) return;
      _error = 'Falha no fluxo de eventos KWS: $error';
      _notify();
    });

    _commandSubscription ??= _gateway.commandEvents.listen((event) {
      if (_disposed) return;
      if (event.type == 'command_result' && event.text.trim().isNotEmpty) {
        _lastCommand = event.text.trim();
        _commandMessage = null;
      } else if (event.type == 'command_partial' && event.text.trim().isNotEmpty) {
        _commandMessage = 'Reconhecendo: ${event.text.trim()}';
      } else if (event.type == 'command_status') {
        _commandMessage = event.message;
      } else if (event.type == 'command_error') {
        _commandMessage = event.message;
      }
      _commandBus.add(event);
      _notify();
    }, onError: (Object error) {
      if (_disposed) return;
      _commandMessage = 'Falha no fluxo de transcrição: $error';
      _notify();
    });
  }

  void _apply(KwsStatus value) {
    _status = value;
    _error = null;
    if (!value.available) {
      _phase = KwsPhase.unavailable;
    } else if (value.listening) {
      _phase = KwsPhase.listening;
    } else {
      _phase = KwsPhase.idle;
    }
    _notify();
  }

  void _fail(Object error) {
    _error = error.toString();
    _phase = KwsPhase.error;
    _status = KwsStatus(available: _status.available, listening: false, engine: _status.engine, detail: _error!);
    _notify();
  }

  void _notify() { if (!_disposed) notifyListeners(); }

  @override
  void dispose() {
    _disposed = true;
    _wakeSubscription?.cancel();
    _commandSubscription?.cancel();
    super.dispose();
  }
}
