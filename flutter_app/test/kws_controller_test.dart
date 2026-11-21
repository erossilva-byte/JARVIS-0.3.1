import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/ativacao_sensibilidade.dart';
import 'package:jarvis_nova/services/kws_bridge.dart';
import 'package:jarvis_nova/services/kws_controller.dart';

class FakeKwsGateway implements KwsGateway {
  final StreamController<String> events = StreamController<String>.broadcast();
  final StreamController<KwsCommandEvent> commands =
      StreamController<KwsCommandEvent>.broadcast();
  KwsStatus current = const KwsStatus(
    available: false,
    listening: false,
    engine: '',
    detail: 'plugin ausente',
  );
  bool throwOnStart = false;
  bool emitDuringStart = false;
  final List<int> sensibilidades = <int>[];
  int hotwordsAplicadas = 0;

  @override
  Stream<String> get wakeEvents => events.stream;

  @override
  Stream<KwsCommandEvent> get commandEvents => commands.stream;

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

  @override
  Future<KwsStatus> aplicarHotword() async {
    hotwordsAplicadas++;
    return current;
  }

  @override
  Future<KwsStatus> definirSensibilidade(int valor) async {
    sensibilidades.add(valor);
    current = KwsStatus(
      available: true,
      listening: current.listening,
      engine: 'sherpa-onnx',
      detail: 'sensibilidade gravada',
      sensibilidade: valor,
      limiar: AtivacaoSensibilidade.limiar(valor),
    );
    return current;
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
    await gateway.commands.close();
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

  test('erro de JNI não é apresentado como pronto', () async {
    gateway.current = const KwsStatus(
      available: true,
      listening: false,
      engine: 'sherpa-onnx',
      detail: 'Falha no KWS local: Failed to get field ID for maxActivePaths',
      ok: false,
      error: 'Failed to get field ID for maxActivePaths',
    );
    await controller.refresh();
    expect(controller.phase, KwsPhase.error);
    expect(controller.status.ok, isFalse);
    expect(controller.error, contains('maxActivePaths'));
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

  test('encaminha transcrição reconhecida para o barramento do aplicativo',
      () async {
    final received = <KwsCommandEvent>[];
    final subscription = KwsController.commandBus.listen(received.add);
    await controller.initialize();
    gateway.commands.add(
        const KwsCommandEvent(type: 'command_result', text: 'Que horas são?'));
    await Future<void>.delayed(Duration.zero);
    expect(controller.lastCommand, 'Que horas são?');
    expect(received.last.text, 'Que horas são?');
    await subscription.cancel();
  });

  test('sensibilidade é gravada e volta no estado com o limiar novo', () async {
    await controller.start();
    final status = await controller.definirSensibilidade(95);
    expect(gateway.sensibilidades, [95]);
    expect(status.sensibilidade, 95);
    expect(status.limiar, 0.20);
    expect(controller.sensibilidade, 95);
    // O detector continua escutando depois do ajuste.
    expect(controller.phase, KwsPhase.listening);
  });

  test('valor fora da faixa não chega maior do que 100 ao serviço', () async {
    await controller.definirSensibilidade(140);
    expect(gateway.sensibilidades.single, lessThanOrEqualTo(100));
    expect(controller.sensibilidade, 100);
  });

  test('falha no comando não deixa estado falsamente ativo', () async {
    gateway.throwOnStart = true;
    await controller.start();
    expect(controller.phase, KwsPhase.error);
    expect(controller.status.listening, isFalse);
    expect(controller.error, contains('falha simulada'));
  });
}
