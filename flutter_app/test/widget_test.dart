import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/main.dart';

void main() {
  testWidgets('exibe núcleo e navega para catálogo com os módulos', (tester) async {
    await tester.view.setPhysicalSize(const Size(430, 900));
    await tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const JarvisApp());

    expect(find.text('J.A.R.V.I.S. NOVA'), findsOneWidget);
    expect(find.text('À sua disposição.'), findsOneWidget);
    expect(find.text('NÚCLEO HOLOGRÁFICO'), findsOneWidget);

    await tester.tap(find.text('Sistemas'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Capacidades do J.A.R.V.I.S.'), findsOneWidget);
    expect(find.text('Hermes Agent'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('CADeSIMU e elétrica'),
      280,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('CADeSIMU e elétrica'), findsOneWidget);

    await tester.view.resetPhysicalSize();
    await tester.view.resetDevicePixelRatio();
  });

  testWidgets('busca e filtro reduzem o catálogo', (tester) async {
    await tester.view.setPhysicalSize(const Size(430, 900));
    await tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const JarvisApp());
    await tester.tap(find.text('Sistemas'));
    await tester.pump(const Duration(milliseconds: 350));

    await tester.enterText(find.byType(TextField), 'Obsidian');
    await tester.pump();
    expect(find.text('Obsidian'), findsOneWidget);
    expect(find.text('Hermes Agent'), findsNothing);

    await tester.tap(find.text('Todos'));
    await tester.pump();
    expect(find.text('Obsidian'), findsOneWidget);

    await tester.view.resetPhysicalSize();
    await tester.view.resetDevicePixelRatio();
  });

  testWidgets('configurações e detalhes deixam claras as integrações pendentes', (tester) async {
    await tester.view.setPhysicalSize(const Size(430, 900));
    await tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const JarvisApp());

    await tester.tap(find.byTooltip('Configurações'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Central de ajustes'), findsOneWidget);
    expect(find.textContaining('Picovoice não será utilizado.'), findsOneWidget);

    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Sistemas'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Hermes Agent'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Integração em auditoria'), findsOneWidget);

    await tester.view.resetPhysicalSize();
    await tester.view.resetDevicePixelRatio();
  });
}
