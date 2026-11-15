import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/catalog.dart';
import 'package:jarvis_nova/drawer.dart';
import 'package:jarvis_nova/pages.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final programacao = modules.firstWhere((m) => m.name == 'Programação (sem execução)');

  test('o catálogo não promete execução isolada', () {
    expect(programacao.description, contains('não disponíveis'));
    expect(programacao.description, isNot(contains('execução isolada.')));
    expect(modules.where((m) => m.name == 'Programação e sandbox'), isEmpty);
  });

  testWidgets('a tela do módulo diz que execução não existe', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ModulePage(module: programacao)));
    await tester.pumpAndSettle();

    expect(find.text('Execução de código não disponível'), findsOneWidget);
    expect(find.textContaining('Não há sandbox, terminal'), findsOneWidget);
    expect(find.text('Integração em auditoria'), findsNothing);
  });

  testWidgets('os outros módulos continuam com o aviso genérico', (tester) async {
    final outro = modules.firstWhere((m) => m.name == 'Hermes Agent');
    await tester.pumpWidget(MaterialApp(home: ModulePage(module: outro)));
    await tester.pumpAndSettle();

    expect(find.text('Integração em auditoria'), findsOneWidget);
    expect(find.text('Execução de código não disponível'), findsNothing);
  });

  testWidgets('a gaveta não chama o módulo de sandbox', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: JarvisDrawer(
          onSelectTab: (_) {},
          onProviders: () {},
          onKws: () {},
          onSettings: () {},
          onModule: (_) {},
          kwsLabel: 'KWS PRONTO',
          kwsColor: const Color(0xFF64E6B1),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Código sem execução'), findsOneWidget);
    expect(find.text('Dev. Arquivos'), findsNothing);
  });
}
