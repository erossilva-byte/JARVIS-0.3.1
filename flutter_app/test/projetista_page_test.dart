import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/services/projetista_page.dart';
import 'package:material_ui/material_ui.dart';


/// Tela alta: as listas destas telas são longas e o teste padrão de 800×600
/// deixa os botões de baixo fora da árvore, como aconteceria no aparelho sem
/// rolagem.
void _telaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('monta a lâmpada pedida e mostra a simulação fechada',
      (tester) async {
    _telaAlta(tester);
    await tester.pumpWidget(const MaterialApp(home: ProjetistaPage()));

    await tester.enterText(
        find.byKey(const ValueKey('projetista-campo')),
        'lâmpada de 12 V e 5 W com interruptor');
    await tester.tap(find.byKey(const ValueKey('projetista-montar')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('projetista-resultado')), findsOneWidget);
    expect(find.textContaining('simulação fechada'), findsOneWidget);
    expect(find.byKey(const ValueKey('projetista-abrir')), findsOneWidget);
    expect(find.byKey(const ValueKey('projetista-motivo')), findsNothing);
  });

  testWidgets('pedido fora das famílias mostra o motivo, sem botão de abrir',
      (tester) async {
    _telaAlta(tester);
    await tester.pumpWidget(const MaterialApp(home: ProjetistaPage()));

    await tester.enterText(find.byKey(const ValueKey('projetista-campo')),
        'painel industrial trifásico completo');
    await tester.tap(find.byKey(const ValueKey('projetista-montar')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('projetista-motivo')), findsOneWidget);
    expect(find.textContaining('Eu monto'), findsOneWidget);
    expect(find.byKey(const ValueKey('projetista-abrir')), findsNothing);
  });

  testWidgets('tocar num exemplo preenche o campo e monta', (tester) async {
    _telaAlta(tester);
    await tester.pumpWidget(const MaterialApp(home: ProjetistaPage()));

    expect(find.text('LED de 12 V com resistor'), findsOneWidget);
    await tester.tap(find.text('LED de 12 V com resistor'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('projetista-resultado')), findsOneWidget);
  });

  testWidgets('a tela declara os limites do simulador', (tester) async {
    _telaAlta(tester);
    await tester.pumpWidget(const MaterialApp(home: ProjetistaPage()));
    await tester.pumpAndSettle();

    expect(find.textContaining('corrente contínua'), findsOneWidget);
    expect(find.textContaining('CADeSIMU'), findsOneWidget);
  });
}
