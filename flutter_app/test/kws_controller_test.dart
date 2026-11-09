import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/services/kws_bridge.dart';
import 'package:jarvis_nova/services/kws_controller.dart';

class FakeKwsGateway implements KwsGateway {
  final StreamController<String> events = StreamController<String>.broadcast();
  KwsStatus current = const KwsStatus(
    available: false,
    listening: false,
    engine: '',
    detail: 'plugin ausente',
  );
  bool throwOnStart = false;
  bool emitDuringStart = false;

  @override
  Stream<String> get wakeEvents => events.stream;

  @override
  Future<KwsStatus> status() async => current;

  @override
  Future<KwsStatus> start() async {
    if (throwOnStart) throw StateError('falha simulada');
    current = const KwsStatus(
      available: true,
      listening: true,
      engine: 'sherpa-onnx',
      detail: 'serviço confirmou escuta',
    );
    if (emitDuringStart) events.add('Jarvis');
    return current;
  }

  @override
  Future<KwsStatus> stop() async => current = const KwsStatus(
        available: true,
        listening: false,
        engine: 'sherpa-onnx',
        detail: 'escuta parada',
      );

  @override
  Future<KwsStatus> startTest({int seconds = 20}) async {
    expect(seconds, inInclusiveRange(10, 60));
    return start();
  }
}

void main() {
  late FakeKwsGateway gateway;
  late KwsController controller;

  setUp(() {
    gateway = FakeKwsGateway();
    controller = KwsController(gateway: gateway);
  });

  tearDown(() async {
    controller.dispose();
    await gateway.events.close();
  });

  test('plugin ausente nunca é apresentado como KWS ativo', () async {
    final status = await controller.refresh();
    expect(status.available, isFalse);
    expect(controller.phase, KwsPhase.unavailable);
    expect(controller.status.listening, isFalse);
  });

  test('só marca escuta ativa após confirmação do serviço', () async {
    final status = await controller.start();
    expect(status.available, isTrue);
    expect(status.listening, isTrue);
    expect(controller.phase, KwsPhase.listening);
  });

  test('parada retorna ao estado ocioso sem perder disponibilidade', () async {
    await controller.start();
    final status = await controller.stop();
    expect(status.available, isTrue);
    expect(status.listening, isFalse);
    expect(controller.phase, KwsPhase.idle);
  });

  test('propaga palavra detectada pelo fluxo nativo', () async {
    await controller.start();
    gateway.events.add('Jarvis');
    await Future<void>.delayed(Duration.zero);
    expect(controller.lastWake, 'Jarvis');
  });

  test('não perde ativação emitida imediatamente ao iniciar', () async {
    gateway.emitDuringStart = true;
    await controller.start();
    await Future<void>.delayed(Duration.zero);
    expect(controller.lastWake, 'Jarvis');
  });

  test('falha no comando não deixa estado falsamente ativo', () async {
    gateway.throwOnStart = true;
    await controller.start();
    expect(controller.phase, KwsPhase.error);
    expect(controller.status.listening, isFalse);
    expect(controller.error, contains('falha simulada'));
  });
}
