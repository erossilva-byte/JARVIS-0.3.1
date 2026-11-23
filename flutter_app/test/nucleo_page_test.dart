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
  var pausado = false;
  var economico = false;

  setUp(() {
    chamadas.clear();
    ativo = false;
    permissao = true;
    pausado = false;
    economico = false;
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
            'pausado': pausado,
            'economico': economico,
          };
        case 'iniciar':
          ativo = true;
          economico = call.arguments['economico'] == true;
          return {
            'ativo': true,
            'tamanho': call.arguments['tamanho'],
            'intervalo': call.arguments['intervalo'],
            'permissao': true,
            'pausado': pausado,
            'economico': economico,
            'iniciado': true,
          };
        case 'parar':
          ativo = false;
          pausado = false;
          economico = false;
          return {
            'ativo': false,
            'tamanho': 112,
            'intervalo': 7000,
            'permissao': permissao,
            'pausado': false,
            'economico': false,
          };
        case 'definirPausado':
          pausado = call.arguments['pausado'] == true;
          return {
            'ativo': ativo,
            'tamanho': 112,
            'intervalo': 7000,
            'permissao': permissao,
            'pausado': pausado,
            'economico': economico,
          };
        case 'consumo':
          return {
            'medindo': false,
            'modoAtual': '',
            'normal': <String, Object?>{},
            'economico': <String, Object?>{},
          };
        case 'iniciarConsumo':
          return {
            'medindo': true,
            'modoAtual': 'normal',
            'normal': <String, Object?>{},
            'economico': <String, Object?>{},
          };
        case 'pararConsumo':
          return {
            'medindo': false,
            'modoAtual': 'normal',
            'normal': {
              'modo': 'normal',
              'duracaoMs': 60000,
              'cpuMs': 3000,
              'bateriaInicio': 80,
              'bateriaFim': 79,
              'carregando': false,
              'telaApagou': false,
            },
            'economico': <String, Object?>{},
          };
        case 'zerarConsumo':
          return {
            'medindo': false,
            'modoAtual': '',
            'normal': <String, Object?>{},
            'economico': <String, Object?>{},
          };
        case 'medicao':
          return {
            'normalQuadros': 600,
            'normalMs': 10000,
            'ecoQuadros': 200,
            'ecoMs': 10000,
          };
        case 'zerarMedicao':
          return {
            'normalQuadros': 0,
            'normalMs': 0,
            'ecoQuadros': 0,
            'ecoMs': 0,
          };
        case 'definirEconomico':
          economico = call.arguments['economico'] == true;
          return {
            'ativo': ativo,
            'tamanho': 112,
            'intervalo': 7000,
            'permissao': permissao,
            'pausado': pausado,
            'economico': economico,
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

  testWidgets('pausar congela; retomar volta; teletransporte fica parado',
      (tester) async {
    await abrir(tester);
    await tester.tap(find.byKey(const ValueKey('nucleo-ativo')));
    await tester.pump(const Duration(milliseconds: 60));

    await tester.ensureVisible(find.byKey(const ValueKey('nucleo-pausar')));
    await tester.tap(find.byKey(const ValueKey('nucleo-pausar')));
    await tester.pump(const Duration(milliseconds: 60));

    final pausou = chamadas
        .where((c) => c.method == 'definirPausado')
        .last
        .arguments['pausado'];
    expect(pausou, isTrue);
    expect(find.text('Retomar o núcleo'), findsOneWidget);
    expect(find.byKey(const ValueKey('nucleo-pausado-aviso')), findsOneWidget);

    final botao = tester.widget<OutlinedButton>(find.ancestor(
      of: find.text('Teletransportar agora'),
      matching: find.byType(OutlinedButton),
    ));
    expect(botao.onPressed, isNull,
        reason: 'pausado, o teletransporte manual não pode disparar');
    await tester.tap(find.byKey(const ValueKey('nucleo-teleportar')));
    await tester.pump(const Duration(milliseconds: 40));
    expect(chamadas.any((c) => c.method == 'teleportar'), isFalse);

    await tester.ensureVisible(find.byKey(const ValueKey('nucleo-pausar')));
    await tester.tap(find.byKey(const ValueKey('nucleo-pausar')));
    await tester.pump(const Duration(milliseconds: 60));

    final retomou = chamadas
        .where((c) => c.method == 'definirPausado')
        .last
        .arguments['pausado'];
    expect(retomou, isFalse);
    expect(find.text('Pausar o núcleo'), findsOneWidget);
    expect(find.byKey(const ValueKey('nucleo-pausado-aviso')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('nucleo-teleportar')));
    await tester.pump(const Duration(milliseconds: 40));
    expect(chamadas.any((c) => c.method == 'teleportar'), isTrue);
  });

  testWidgets('modo econômico manda a escolha e aparece no estado',
      (tester) async {
    await abrir(tester);
    await tester.tap(find.byKey(const ValueKey('nucleo-ativo')));
    await tester.pump(const Duration(milliseconds: 60));

    await tester.ensureVisible(find.byKey(const ValueKey('nucleo-economico')));
    await tester.tap(find.byKey(const ValueKey('nucleo-economico')));
    await tester.pump(const Duration(milliseconds: 60));

    expect(
        chamadas
            .where((c) => c.method == 'definirEconomico')
            .last
            .arguments['economico'],
        isTrue);
    expect(
        tester
            .widget<SwitchListTile>(
                find.byKey(const ValueKey('nucleo-economico')))
            .value,
        isTrue);
  });

  testWidgets('a medição mostra os dois modos, a diferença e zera',
      (tester) async {
    await abrir(tester);
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.textContaining('60.0 quadros/s'), findsOneWidget);
    expect(find.textContaining('20.0 quadros/s'), findsOneWidget);
    expect(find.textContaining('-67%'), findsOneWidget);

    await tester
        .ensureVisible(find.byKey(const ValueKey('nucleo-medicao-zerar')));
    await tester.tap(find.byKey(const ValueKey('nucleo-medicao-zerar')));
    await tester.pump(const Duration(milliseconds: 60));

    expect(chamadas.any((c) => c.method == 'zerarMedicao'), isTrue);
    expect(find.textContaining('Sem amostra'), findsOneWidget);
  });

  testWidgets('consumo: inicia, para com amostra e zera', (tester) async {
    await abrir(tester);
    await tester.tap(find.byKey(const ValueKey('nucleo-ativo')));
    await tester.pump(const Duration(milliseconds: 60));

    await tester
        .ensureVisible(find.byKey(const ValueKey('nucleo-consumo-iniciar')));
    await tester.tap(find.byKey(const ValueKey('nucleo-consumo-iniciar')));
    await tester.pump(const Duration(milliseconds: 60));

    expect(chamadas.any((c) => c.method == 'iniciarConsumo'), isTrue);
    expect(
        find.byKey(const ValueKey('nucleo-consumo-medindo')), findsOneWidget);

    await tester
        .ensureVisible(find.byKey(const ValueKey('nucleo-consumo-parar')));
    await tester.tap(find.byKey(const ValueKey('nucleo-consumo-parar')));
    await tester.pump(const Duration(milliseconds: 60));

    expect(chamadas.any((c) => c.method == 'pararConsumo'), isTrue);
    expect(find.textContaining('50.0 ms de CPU/s'), findsOneWidget);

    await tester
        .ensureVisible(find.byKey(const ValueKey('nucleo-consumo-zerar')));
    await tester.tap(find.byKey(const ValueKey('nucleo-consumo-zerar')));
    await tester.pump(const Duration(milliseconds: 60));

    expect(chamadas.any((c) => c.method == 'zerarConsumo'), isTrue);
    expect(find.textContaining('Normal · sem amostra'), findsOneWidget);
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
