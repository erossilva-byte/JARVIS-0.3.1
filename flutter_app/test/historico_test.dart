import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/conversa.dart';
import 'package:jarvis_nova/services/conversa_store.dart';
import 'package:jarvis_nova/services/historico_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('vazio explica e oferece nova conversa', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await ConversaStore.abrir();

    await tester.pumpWidget(MaterialApp(home: HistoricoPage(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma conversa ainda'), findsOneWidget);
    expect(find.byTooltip('Nova conversa'), findsOneWidget);
  });

  testWidgets('lista conversas salvas e filtra pela busca', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await ConversaStore.abrir();
    final motor = Conversa.nova(id: 'a', agora: DateTime(2026, 11, 1))
      ..adicionar(const MensagemConversa(autor: 'user', texto: 'motor 220 V'));
    final tempo = Conversa.nova(id: 'b', agora: DateTime(2026, 11, 2))
      ..adicionar(
          const MensagemConversa(autor: 'user', texto: 'previsão do tempo'));
    await store.salvar(motor);
    await store.salvar(tempo);

    await tester.pumpWidget(MaterialApp(home: HistoricoPage(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('motor 220 V'), findsOneWidget);
    expect(find.text('previsão do tempo'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'tempo');
    await tester.pump();

    expect(find.text('motor 220 V'), findsNothing);
    expect(find.text('previsão do tempo'), findsOneWidget);
  });

  testWidgets('busca sem resultado avisa em vez de mostrar lista vazia',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await ConversaStore.abrir();
    await store.salvar(Conversa.nova(id: 'a', agora: DateTime(2026, 11, 1))
      ..adicionar(
          const MensagemConversa(autor: 'user', texto: 'assunto qualquer')));

    await tester.pumpWidget(MaterialApp(home: HistoricoPage(store: store)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'inexistente');
    await tester.pump();

    expect(find.text('Nenhuma conversa corresponde à busca.'), findsOneWidget);
  });
}
