import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/main.dart';

void main() {
  testWidgets('exibe núcleo e abre o catálogo de sistemas', (tester) async {
    await tester.pumpWidget(const JarvisApp());

    expect(find.text('J.A.R.V.I.S. NOVA'), findsOneWidget);
    expect(find.text('À sua disposição.'), findsOneWidget);
    expect(find.text('NÚCLEO HOLOGRÁFICO'), findsOneWidget);

    await tester.tap(find.text('Sistemas'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Capacidades do J.A.R.V.I.S.'), findsOneWidget);
    expect(find.text('Hermes Agent'), findsOneWidget);

  });

  testWidgets('a busca filtra os módulos apresentados', (tester) async {
    await tester.pumpWidget(const JarvisApp());
    await tester.tap(find.text('Sistemas'));
    await tester.pump(const Duration(milliseconds: 350));

    await tester.enterText(find.byType(TextField), 'Obsidian');
    await tester.pump();
    expect(find.text('Hermes Agent'), findsNothing);
    expect(find.text('Memória semântica'), findsNothing);

    expect(find.text('Obsidian'), findsNWidgets(2));
  });

  testWidgets('o botão de ajustes abre a central com provedores reais', (tester) async {
    await tester.pumpWidget(const JarvisApp());

    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Central de ajustes'), findsOneWidget);
    expect(find.text('Provedores de IA'), findsOneWidget);
    expect(find.textContaining('sherpa-onnx'), findsOneWidget);
    expect(find.textContaining('ainda não estão integrados'), findsOneWidget);
  });
}

  testWidgets('núcleo responde ao toque e abre painel holográfico', (tester) async {
    await tester.pumpWidget(const JarvisApp());
    await tester.tap(find.text('NÚCLEO HOLOGRÁFICO'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('Núcleo holográfico'), findsOneWidget);
    expect(find.textContaining('A animação responde ao toque'), findsOneWidget);
  });
