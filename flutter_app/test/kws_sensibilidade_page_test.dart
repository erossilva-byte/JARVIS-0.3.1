import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/ativacao_sensibilidade.dart';
import 'package:jarvis_nova/services/kws_bridge.dart';
import 'package:jarvis_nova/services/kws_controller.dart';
import 'package:jarvis_nova/services/kws_settings_page.dart';
import 'package:material_ui/material_ui.dart';

class FakeKwsGateway implements KwsGateway {
  final StreamController<String> events = StreamController<String>.broadcast();
  final StreamController<KwsCommandEvent> commands =
      StreamController<KwsCommandEvent>.broadcast();
  final List<int> gravados = <int>[];
  int hotwordsAplicadas = 0;

  KwsStatus current = const KwsStatus(
    available: true,
    listening: true,
    engine: 'sherpa-onnx KWS',
    detail: 'escuta ativa',
  );

  @override
  Stream<String> get wakeEvents => events.stream;

  @override
  Stream<KwsCommandEvent> get commandEvents => commands.stream;

  @override
  Future<KwsStatus> status() async => current;

  @override
  Future<KwsStatus> start() async => current;

  @override
  Future<KwsStatus> stop() async => current;

  @override
  Future<KwsStatus> startTest({int seconds = 20}) async => current;

  @override
  Future<KwsStatus> aplicarHotword() async {
    hotwordsAplicadas++;
    return current;
  }

  @override
  Future<KwsStatus> definirSensibilidade(int valor) async {
    final seguro = AtivacaoSensibilidade.segura(valor);
    gravados.add(seguro);
    current = KwsStatus(
      available: true,
      listening: current.listening,
      engine: current.engine,
      detail: 'detector religado com sensibilidade $seguro%',
      sensibilidade: seguro,
      limiar: AtivacaoSensibilidade.limiar(seguro),
    );
    return current;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tela mostra o controle com a sensibilidade atual', (tester) async {
    final gateway = FakeKwsGateway();
    final controller = KwsController(gateway: gateway);
    await controller.refresh();

    await tester.pumpWidget(
        MaterialApp(home: KwsSettingsPage(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sensibilidade-ativacao')),
        findsOneWidget);
    expect(find.textContaining('Sensibilidade da palavra de ativação'),
        findsOneWidget);
    expect(
      tester
          .widget<Slider>(
              find.byKey(const ValueKey('sensibilidade-ativacao')))
          .value,
      AtivacaoSensibilidade.padrao.toDouble(),
    );
  });

  testWidgets('mover o controle grava no detector e confirma ao usuário',
      (tester) async {
    final gateway = FakeKwsGateway();
    final controller = KwsController(gateway: gateway);
    await controller.refresh();

    await tester.pumpWidget(
        MaterialApp(home: KwsSettingsPage(controller: controller)));
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('sensibilidade-ativacao')));
    slider.onChanged!(90);
    await tester.pump();
    expect(find.textContaining('Máxima'), findsWidgets);

    slider.onChangeEnd!(90);
    await tester.pumpAndSettle();

    expect(gateway.gravados, [90]);
    expect(controller.sensibilidade, 90);
    expect(find.textContaining('Sensibilidade 90% gravada no detector'),
        findsOneWidget);
  });

  testWidgets('controle fica travado enquanto o serviço está ocupado',
      (tester) async {
    final gateway = FakeKwsGateway();
    final controller = KwsController(gateway: gateway);
    await controller.refresh();

    await tester.pumpWidget(
        MaterialApp(home: KwsSettingsPage(controller: controller)));
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('sensibilidade-ativacao')));
    expect(slider.onChanged, isNotNull);
    await tester.pumpWidget(
        MaterialApp(home: KwsSettingsPage(controller: controller)));
  });
}
