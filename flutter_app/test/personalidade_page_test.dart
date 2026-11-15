import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/personalidade.dart';
import 'package:jarvis_nova/services/personalidade_page.dart';
import 'package:jarvis_nova/services/personalidade_store.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late PersonalidadeStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = PersonalidadeStore(prefs);
  });

  testWidgets('abre no nível salvo e mostra a prévia correspondente', (tester) async {
    await prefs.setString(PersonalidadeStore.chave, NivelHumor.avancado.name);
    await tester.pumpWidget(MaterialApp(home: PersonalidadePage(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('Prévia — Avançado'), findsOneWidget);
    expect(find.textContaining('revolucionário'), findsOneWidget);
    expect(find.textContaining('humor é suspenso por completo'), findsOneWidget);
    expect(find.textContaining('não autentica'), findsOneWidget);
  });

  testWidgets('trocar para Discreto atualiza a prévia sem gravar sozinho', (tester) async {
    await tester.pumpWidget(MaterialApp(home: PersonalidadePage(store: store)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nivel-discreto')));
    await tester.pumpAndSettle();

    expect(find.text('Prévia — Discreto'), findsOneWidget);
    expect(find.textContaining('revolucionário'), findsNothing);
    expect(store.carregar().nivel, NivelHumor.equilibrado);
  });

  testWidgets('salvar grava o nível escolhido e informa o usuário', (tester) async {
    await tester.pumpWidget(MaterialApp(home: PersonalidadePage(store: store)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nivel-avancado')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Salvar personalidade'));
    await tester.pumpAndSettle();

    expect(store.carregar().nivel, NivelHumor.avancado);
    expect(find.textContaining('Personalidade salva: Avançado'), findsOneWidget);
  });
}
