import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/main.dart';

void main() {
  testWidgets('exibe núcleo e navega para catálogo e detalhes', (tester) async {
    await tester.pumpWidget(const JarvisApp());

    expect(find.text('J.A.R.V.I.S. NOVA'), findsOneWidget);
    expect(find.text('À sua disposição.'), findsOneWidget);
    expect(find.text('NÚCLEO HOLOGRÁFICO'), findsOneWidget);

    await tester.tap(find.text('Sistemas'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Capacidades do J.A.R.V.I.S.'), findsOneWidget);
    expect(find.text('Hermes Agent'), findsOneWidget);

    await tester.tap(find.text('Hermes Agent'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Integração em auditoria'), findsOneWidget);
  });

  testWidgets('busca e filtros atualizam o catálogo', (tester) async {
    await tester.pumpWidget(const JarvisApp());
    await tester.tap(find.text('Sistemas'));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byType(TextField), 'Obsidian');
    await tester.pump();
    expect(find.text('Hermes Agent'), findsNothing);
    expect(find.text('Memória semântica'), findsNothing);
    expect(find.text('Obsidian'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Todos'));
    await tester.pump();
    expect(find.text('Obsidian'), findsNWidgets(2));

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Engenharia'));
    await tester.pump();
    expect(find.text('CADeSIMU e elétrica'), findsOneWidget);
    expect(find.text('Hermes Agent'), findsNothing);
  });

  testWidgets('configurações explicam integrações pendentes sem simular gravação', (tester) async {
    await tester.pumpWidget(const JarvisApp());

    await tester.tap(find.byTooltip('Configurações'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Central de ajustes'), findsOneWidget);
    expect(find.textContaining('Picovoice não será utilizado.'), findsOneWidget);
    expect(find.textContaining('Nenhum controle simula gravação'), findsOneWidget);
  });
}
