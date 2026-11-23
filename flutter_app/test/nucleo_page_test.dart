import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/nucleo/nucleo_controle.dart';
import 'package:jarvis_nova/nucleo/nucleo_page.dart';
import 'package:jarvis_nova/nucleo/nucleo_previa.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final chamadas = <MethodCall>[];
  var ativo = false;
  var permissao = true;

  setUp(() {
    chamadas.clear();
    ativo = false;
    permissao = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NucleoControle.canal, (call) async {
      chamadas.add(call);
      switch (call.method) {
        case 'estado':
          return {
            'ativo': ativo,
            'tamanho': 112,
            'intervalo': 7000,
            'permissao': permissao,
          };
        case 'iniciar':
          ativo = true;
          return {
            'ativo': true,
            'tamanho': call.arguments['tamanho'],
            'intervalo': call.arguments['intervalo'],
            'permissao': true,
            'iniciado': true,
          };
        case 'parar':
          ativo = false;
          return {
            'ativo': false,
            'tamanho': 112,
            'intervalo': 7000,
            'permissao': permissao,
          };
        default:
          return true;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NucleoControle.canal, null);
  });

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(520, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: NucleoPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
  }

  testWidgets('abre desligado, mostra a prévia e liga no switch',
      (tester) async {
    await abrir(tester);

    expect(find.byType(NucleoPrevia), findsOneWidget);
    final antes = tester
        .widget<SwitchListTile>(find.byKey(const ValueKey('nucleo-ativo')));
    expect(antes.value, isFalse);

    await tester.tap(find.byKey(const ValueKey('nucleo-ativo')));
    await tester.pump(const Duration(milliseconds: 60));

    expect(chamadas.any((c) => c.method == 'iniciar'), isTrue);
    final depois = tester
        .widget<SwitchListTile>(find.byKey(const ValueKey('nucleo-ativo')));
    expect(depois.value, isTrue);
    expect(find.textContaining('teletransporta a cada'), findsWidgets);
  });

  testWidgets('teletransportar só funciona com o núcleo ligado',
      (tester) async {
    await abrir(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('nucleo-teleportar')));
    await tester.tap(find.byKey(const ValueKey('nucleo-teleportar')));
    await tester.pump(const Duration(milliseconds: 40));
    expect(chamadas.any((c) => c.method == 'teleportar'), isFalse);

    await tester.tap(find.byKey(const ValueKey('nucleo-ativo')));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.ensureVisible(find.byKey(const ValueKey('nucleo-teleportar')));
    await tester.tap(find.byKey(const ValueKey('nucleo-teleportar')));
    await tester.pump(const Duration(milliseconds: 40));

    expect(chamadas.any((c) => c.method == 'teleportar'), isTrue);
  });

  testWidgets('sem autorização, explica e oferece o ajuste', (tester) async {
    permissao = false;
    await abrir(tester);

    await tester.ensureVisible(find.byKey(const ValueKey('nucleo-permissao')));
    expect(find.textContaining('Exibir sobre outros'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('nucleo-permissao')));
    await tester.pump(const Duration(milliseconds: 40));

    expect(chamadas.any((c) => c.method == 'abrirAjusteSobreposicao'), isTrue);
  });
}
