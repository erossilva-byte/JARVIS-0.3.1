import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/drawer.dart';
import 'package:material_ui/material_ui.dart';

/// A voz por ID e o núcleo flutuante existiam, mas só dentro de outros módulos.
/// Este teste trava os dois atalhos na gaveta: um toque, sem adivinhar caminho.
Future<void> _abrirGaveta(WidgetTester tester) async {
  tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a gaveta leva à voz externa e ao núcleo em um toque',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var vozExterna = 0;
    var nucleo = 0;
    var modulo = '';

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        drawer: JarvisDrawer(
          onSelectTab: (_) {},
          onProviders: () {},
          onKws: () {},
          onVozExterna: () => vozExterna++,
          onNucleo: () => nucleo++,
          onModule: (nome) => modulo = nome,
          onSettings: () {},
          kwsLabel: 'PRONTO · EM ESPERA',
          kwsColor: const Color(0xFF64E6B1),
        ),
      ),
    ));

    await _abrirGaveta(tester);
    expect(find.text('Voz externa'), findsOneWidget);
    expect(find.text('Núcleo flutuante'), findsOneWidget);

    // Cada item abre a tela própria, e não um módulo do catálogo.
    await tester.tap(find.text('Voz externa'));
    await tester.pumpAndSettle();
    expect(vozExterna, 1);
    expect(modulo, isEmpty);

    await _abrirGaveta(tester);
    await tester.tap(find.text('Núcleo flutuante'));
    await tester.pumpAndSettle();
    expect(nucleo, 1);
    expect(modulo, isEmpty);
  });

  testWidgets('a gaveta mantém os itens de antes', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        drawer: JarvisDrawer(
          onSelectTab: (_) {},
          onProviders: () {},
          onKws: () {},
          onVozExterna: () {},
          onNucleo: () {},
          onModule: (_) {},
          onSettings: () {},
          kwsLabel: 'PRONTO · EM ESPERA',
          kwsColor: const Color(0xFF64E6B1),
        ),
      ),
    ));

    await _abrirGaveta(tester);
    for (final titulo in ['Comando', 'IA Core', 'Voz', 'Visão', 'Timbre',
        'Segurança', 'Configurações']) {
      expect(find.text(titulo), findsOneWidget, reason: 'sumiu: $titulo');
    }
  });
}
