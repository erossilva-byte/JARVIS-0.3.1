import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/memoria.dart';
import 'package:jarvis_nova/services/memoria_page.dart';
import 'package:jarvis_nova/services/memoria_store.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

NotaMemoria nota(String titulo, String texto) => NotaMemoria(
      id: titulo.toLowerCase(),
      titulo: titulo,
      texto: texto,
      criadaEm: DateTime(2026, 11, 1),
      atualizadaEm: DateTime(2026, 11, 1),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('cofre vazio explica o que existe e o que não existe',
      (tester) async {
    final store = await MemoriaStore.abrir();
    await tester.pumpWidget(MaterialApp(home: MemoriaPage(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma nota no cofre'), findsOneWidget);
    expect(find.textContaining('SAF'), findsOneWidget);
    expect(find.text('Nova nota'), findsOneWidget);
  });

  testWidgets('cria nota pelo editor e ela aparece na lista', (tester) async {
    final store = await MemoriaStore.abrir();
    await tester.pumpWidget(MaterialApp(home: MemoriaPage(store: store)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nova nota'));
    await tester.pumpAndSettle();

    final campos = find.byType(TextField);
    await tester.enterText(campos.at(0), 'Motor da bancada');
    await tester.enterText(campos.at(1), 'Ligação em estrela-triângulo.');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Motor da bancada'), findsOneWidget);
    expect(store.listar().single.titulo, 'Motor da bancada');
  });

  testWidgets('busca mostra o motivo do resultado', (tester) async {
    final store = await MemoriaStore.abrir();
    await store.salvar(nota('Motor da bancada', 'ligação trifásica'));
    await store.salvar(nota('Receita', 'bolo de cenoura'));

    await tester.pumpWidget(MaterialApp(home: MemoriaPage(store: store)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'motor');
    await tester.pump();

    expect(find.text('Motor da bancada'), findsOneWidget);
    expect(find.textContaining('título contém o termo'), findsOneWidget);
    expect(find.text('Receita'), findsNothing);
  });

  testWidgets('busca sem resultado avisa em vez de lista vazia',
      (tester) async {
    final store = await MemoriaStore.abrir();
    await store.salvar(nota('Motor', 'trifásico'));

    await tester.pumpWidget(MaterialApp(home: MemoriaPage(store: store)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'astronomia');
    await tester.pump();

    expect(find.textContaining('Nenhuma nota corresponde'), findsOneWidget);
  });
}
