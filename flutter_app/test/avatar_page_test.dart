import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/avatar3d.dart';
import 'package:jarvis_nova/catalog.dart';
import 'package:jarvis_nova/pages.dart';
import 'package:jarvis_nova/services/avatar_page.dart';
import 'package:material_ui/material_ui.dart';

/// A tela anima em repetição. Trocar por uma árvore vazia antes do fim do
/// teste desliga o controlador e não deixa quadro pendente.
Future<void> _encerrar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void _telaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('o avatar 3D desenha e gira com o dedo', (tester) async {
    _telaAlta(tester);
    await tester.pumpWidget(const MaterialApp(home: AvatarPage()));
    // A tela anima em repetição: pumpAndSettle nunca terminaria.
    await tester.pump(const Duration(milliseconds: 120));

    final quadro = find.byKey(const ValueKey('avatar-3d'));
    expect(quadro, findsOneWidget);

    final pintura = tester.widget<CustomPaint>(
      find.descendant(of: quadro, matching: find.byType(CustomPaint)).first,
    );
    final antes = (pintura.painter! as Avatar3DPainter).giro;

    await tester.drag(quadro, const Offset(80, 0));
    await tester.pump();

    final depois = tester.widget<CustomPaint>(
      find.descendant(of: quadro, matching: find.byType(CustomPaint)).first,
    );
    expect((depois.painter! as Avatar3DPainter).giro, isNot(antes));
    await _encerrar(tester);
  });

  testWidgets('o estado escolhido muda a legenda do avatar', (tester) async {
    _telaAlta(tester);
    await tester.pumpWidget(const MaterialApp(home: AvatarPage()));
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.textContaining('Em espera'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('avatar-estado-falando')));
    await tester.pump();

    expect(find.textContaining('Falando'), findsWidgets);
    final pintura = tester.widget<CustomPaint>(
      find
          .descendant(
            of: find.byKey(const ValueKey('avatar-3d')),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    expect((pintura.painter! as Avatar3DPainter).estado, AvatarEstado.falando);
    await _encerrar(tester);
  });

  testWidgets('o interruptor do giro automático desliga o balanço',
      (tester) async {
    _telaAlta(tester);
    await tester.pumpWidget(const MaterialApp(home: AvatarPage()));
    await tester.pump(const Duration(milliseconds: 120));

    await tester.tap(find.byKey(const ValueKey('avatar-girar-sozinho')));
    await tester.pump();

    final pintura = tester.widget<CustomPaint>(
      find
          .descendant(
            of: find.byKey(const ValueKey('avatar-3d')),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    expect((pintura.painter! as Avatar3DPainter).autoGiro, isFalse);
    await _encerrar(tester);
  });

  testWidgets('o módulo Avatar 3D abre a tela própria', (tester) async {
    _telaAlta(tester);
    final avatar = modules.firstWhere((m) => m.name == 'Avatar 3D');
    await tester.pumpWidget(MaterialApp(home: ModulePage(module: avatar)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Busto 3D desenhado no aparelho'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('abrir-avatar-3d')), findsOneWidget);
    expect(find.text('Integração em auditoria'), findsNothing);
  });
}
