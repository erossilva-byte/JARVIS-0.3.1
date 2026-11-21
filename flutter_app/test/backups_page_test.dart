import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/memoria.dart';
import 'package:jarvis_nova/services/backups_page.dart';
import 'package:jarvis_nova/services/memoria_page.dart';
import 'package:jarvis_nova/services/memoria_store.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

NotaMemoria simples(String id, String titulo, [String texto = 'x']) =>
    NotaMemoria(
      id: id,
      titulo: titulo,
      texto: texto,
      criadaEm: DateTime(2026, 11, 15),
      atualizadaEm: DateTime(2026, 11, 15),
    );

NotaMemoria backup(String id, String titulo, String texto) => NotaMemoria(
      id: id,
      titulo: titulo,
      texto: texto,
      criadaEm: DateTime(2026, 11, 15),
      atualizadaEm: DateTime(2026, 11, 15),
      extras: const {'origem': origemBackupConflito},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoriaStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = MemoriaStore(await SharedPreferences.getInstance());
  });

  test(
      'reconhece backup pela marca e pelo prefixo antigo; título perde o sufixo',
      () {
    final marcado = backup('x1', 'Motor (versão do conflito)', 'texto');
    final antigo =
        simples('conflito-antigo', 'Antigo (versão do conflito)', 'x');
    final normal = simples('nota', 'Motor (versão do conflito)', 'x');
    expect(ehBackupConflito(marcado), isTrue);
    expect(ehBackupConflito(antigo), isTrue);
    expect(ehBackupConflito(normal), isFalse);
    expect(tituloSemSufixoBackup(marcado.titulo), 'Motor');
    expect(tituloSemSufixoBackup('Sem sufixo'), 'Sem sufixo');
  });

  testWidgets('restaura como nota normal e apaga o backup', (tester) async {
    await store.salvar(
        backup('conflito-a', 'Motor (versão do conflito)', 'texto perdido'));
    await store.salvar(simples('nota', 'Nota comum', 'normal'));
    await tester.pumpWidget(MaterialApp(home: BackupsPage(store: store)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Motor (versão do conflito)'), findsOneWidget);
    expect(find.textContaining('Nota comum'), findsNothing);

    await tester.tap(find.byTooltip('Restaurar como nota'));
    await tester.pumpAndSettle();

    expect(store.listar().any((n) => n.titulo == 'Motor'), isTrue);
    expect(store.listar().any((n) => n.id == 'conflito-a'), isFalse);
    expect(find.textContaining('Nenhum backup'), findsOneWidget);
  });

  testWidgets('apagar um backup pede confirmação e não toca na nota original',
      (tester) async {
    await store
        .salvar(backup('conflito-a', 'Motor (versão do conflito)', 'perdido'));
    await store.salvar(simples('motor', 'Motor', 'oficial'));
    await tester.pumpWidget(MaterialApp(home: BackupsPage(store: store)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Apagar backup'));
    await tester.pumpAndSettle();
    expect(find.text('Apagar este backup?'), findsOneWidget);
    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();

    expect(store.listar().map((n) => n.id), ['motor']);
    expect(find.textContaining('Nenhum backup'), findsOneWidget);
  });

  testWidgets('limpar todos remove só os backups', (tester) async {
    await store.salvar(backup('conflito-a', 'A (versão do conflito)', 'a'));
    await store.salvar(backup('conflito-b', 'B (versão do conflito)', 'b'));
    await store.salvar(simples('motor', 'Motor', 'oficial'));
    await tester.pumpWidget(MaterialApp(home: BackupsPage(store: store)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Apagar todos os backups'));
    await tester.pumpAndSettle();
    expect(find.text('Apagar 2 backup(s)?'), findsOneWidget);
    await tester.tap(find.text('Apagar todos'));
    await tester.pumpAndSettle();

    expect(store.listar().map((n) => n.titulo), ['Motor']);
    expect(find.textContaining('Nenhum backup'), findsOneWidget);
  });

  testWidgets('a tela de memória tem atalho para os backups', (tester) async {
    await store
        .salvar(backup('conflito-a', 'Motor (versão do conflito)', 'perdido'));
    await tester.pumpWidget(MaterialApp(home: MemoriaPage(store: store)));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Backups de conflito'), findsOneWidget);
    await tester.tap(find.byTooltip('Backups de conflito'));
    await tester.pumpAndSettle();
    expect(find.text('Backups de conflito'), findsWidgets);
    expect(find.textContaining('Motor (versão do conflito)'), findsOneWidget);
  });
}
