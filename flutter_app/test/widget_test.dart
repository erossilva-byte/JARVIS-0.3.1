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

    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Obsidian'), findsOneWidget);
  });

  testWidgets('a busca filtra os módulos apresentados', (tester) async {
    await tester.pumpWidget(const JarvisApp());
    await tester.tap(find.text('Sistemas'));
    await tester.pump(const Duration(milliseconds: 350));

    await tester.enterText(find.byType(TextField), 'Obsidian');
    await tester.pump();
    expect(find.text('Hermes Agent'), findsNothing);
    expect(find.text('Memória semântica'), findsNothing);

    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Obsidian'), findsOneWidget);
  });

  testWidgets('o botão de ajustes abre a página informativa', (tester) async {
    await tester.pumpWidget(const JarvisApp());

    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Central de ajustes'), findsOneWidget);
    expect(find.textContaining('Picovoice não será utilizado.'), findsOneWidget);
    expect(find.textContaining('Nenhum controle simula gravação'), findsOneWidget);
  });
}
