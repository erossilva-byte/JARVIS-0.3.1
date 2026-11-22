import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/catalog.dart';
import 'package:jarvis_nova/core/estado_modulos.dart';
import 'package:jarvis_nova/drawer.dart';
import 'package:jarvis_nova/pages.dart';
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
  final programacao =
      modules.firstWhere((m) => m.name == 'Programação (sem execução)');

  test('o catálogo não promete execução isolada', () {
    expect(programacao.description, contains('não disponíveis'));
    expect(programacao.description, isNot(contains('execução isolada.')));
    expect(modules.where((m) => m.name == 'Programação e sandbox'), isEmpty);
  });

  test('todo módulo do catálogo tem estado declarado', () {
    for (final modulo in modules) {
      expect(situacoesModulos.where((s) => s.nome == modulo.name).length, 1,
          reason: '${modulo.name} sem situação na tabela');
      expect(situacaoDe(modulo.name).detalhe, isNotEmpty);
    }
  });

  testWidgets('a tela do módulo diz que execução não existe', (tester) async {
    _telaAlta(tester);
    await tester.pumpWidget(MaterialApp(home: ModulePage(module: programacao)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Execução de código não disponível'),
        findsOneWidget);
    expect(find.textContaining('Não há sandbox, terminal'), findsOneWidget);
    expect(find.textContaining('Não existe neste APK'), findsOneWidget);
    expect(find.text('Integração em auditoria'), findsNothing);
  });

  testWidgets('o Hermes abre a tela própria em vez do aviso genérico',
      (tester) async {
    _telaAlta(tester);
    final hermes = modules.firstWhere((m) => m.name == 'Hermes Agent');
    await tester.pumpWidget(MaterialApp(home: ModulePage(module: hermes)));
    await tester.pumpAndSettle();

    expect(find.text('Integração em auditoria'), findsNothing);
    expect(find.textContaining('Plano local e execução pelo provedor'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('abrir-hermes')), findsOneWidget);
  });

  testWidgets('CADeSIMU oferece importador, simulador e o projetista',
      (tester) async {
    _telaAlta(tester);
    final cadesimu = modules.firstWhere((m) => m.name == 'CADeSIMU e elétrica');
    await tester.pumpWidget(MaterialApp(home: ModulePage(module: cadesimu)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('abrir-importador-cad')), findsOneWidget);
    expect(find.byKey(const ValueKey('abrir-simulador-circuitos')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('abrir-projetista')), findsOneWidget);
    expect(find.text('Integração em auditoria'), findsNothing);
  });

  testWidgets('módulo sem tela diz onde a tela mora', (tester) async {
    _telaAlta(tester);
    final memoria = modules.firstWhere((m) => m.name == 'Memória semântica');
    await tester.pumpWidget(MaterialApp(home: ModulePage(module: memoria)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Gaveta → Memória'), findsOneWidget);
    expect(find.text('Integração em auditoria'), findsNothing);
  });

  testWidgets('a gaveta não chama o módulo de sandbox', (tester) async {
    _telaAlta(tester);
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
