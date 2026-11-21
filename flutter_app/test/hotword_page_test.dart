import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/hotword_portugues.dart';
import 'package:jarvis_nova/services/hotword_store.dart';
import 'package:jarvis_nova/services/kws_bridge.dart';
import 'package:jarvis_nova/services/kws_controller.dart';
import 'package:jarvis_nova/services/kws_settings_page.dart';
import 'package:material_ui/material_ui.dart';

class FakeGateway implements KwsGateway {
  final StreamController<String> events = StreamController<String>.broadcast();
  final StreamController<KwsCommandEvent> commands =
      StreamController<KwsCommandEvent>.broadcast();
  int aplicadas = 0;

  KwsStatus current = const KwsStatus(
    available: true,
    listening: true,
    engine: 'sherpa-onnx KWS',
    detail: 'escuta ativa',
    hotword: 11,
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
  Future<KwsStatus> definirSensibilidade(int valor) async => current;

  @override
  Future<KwsStatus> aplicarHotword() async {
    aplicadas++;
    return current;
  }
}

class FakeStore implements PreferenciasHotword {
  FakeStore(this.ids);

  Set<String> ids;
  final List<Set<String>> gravados = <Set<String>>[];

  @override
  Future<Set<String>> carregar() async => ids;

  @override
  Future<Set<String>> gravar(Set<String> novos) async {
    final seguras = HotwordPortugues.seguras(novos);
    ids = seguras;
    gravados.add(seguras);
    return seguras;
  }

  @override
  Future<Set<String>> restaurarPadrao() => gravar(HotwordPortugues.idsPadrao);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> montar(
    WidgetTester tester,
    FakeGateway gateway,
    FakeStore store,
  ) async {
    tester.view.physicalSize = const Size(1200, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = KwsController(gateway: gateway);
    await controller.refresh();
    await tester.pumpWidget(MaterialApp(
        home: KwsSettingsPage(controller: controller, hotwordStore: store)));
    await tester.pumpAndSettle();
  }

  testWidgets('a tela mostra as frases em português e o padrão ligado',
      (tester) async {
    final gateway = FakeGateway();
    final store = FakeStore(HotwordPortugues.idsPadrao);
    await montar(tester, gateway, store);

    expect(find.text('Palavras que acordam o JARVIS'), findsOneWidget);
    expect(find.text('Ei Jarvis'), findsOneWidget);
    expect(find.text('Olá Jarvis'), findsOneWidget);
    expect(
        tester
            .widget<Checkbox>(find.byKey(const ValueKey('hotword-jarvis')))
            .value,
        isTrue);
    expect(
        tester
            .widget<Checkbox>(find.byKey(const ValueKey('hotword-ei-jarvis')))
            .value,
        isFalse);
  });

  testWidgets('ligar uma frase grava a escolha e religa o detector',
      (tester) async {
    final gateway = FakeGateway();
    final store = FakeStore(HotwordPortugues.idsPadrao);
    await montar(tester, gateway, store);

    await tester.tap(find.byKey(const ValueKey('hotword-ei-jarvis')));
    await tester.pumpAndSettle();

    expect(store.gravados.single, contains('ei-jarvis'));
    expect(store.ids, containsAll(['jarvis', 'ei-jarvis']));
    expect(gateway.aplicadas, 1);
    expect(
        tester
            .widget<Checkbox>(find.byKey(const ValueKey('hotword-ei-jarvis')))
            .value,
        isTrue);
  });

  testWidgets('não deixa a escuta sem nenhuma frase', (tester) async {
    final gateway = FakeGateway();
    final store = FakeStore({'jarvis'});
    await montar(tester, gateway, store);

    await tester.tap(find.byKey(const ValueKey('hotword-jarvis')));
    await tester.pumpAndSettle();

    expect(store.gravados, isEmpty);
    expect(gateway.aplicadas, 0);
    expect(find.textContaining('pelo menos uma frase'), findsOneWidget);
    expect(
        tester
            .widget<Checkbox>(find.byKey(const ValueKey('hotword-jarvis')))
            .value,
        isTrue);
  });
}
