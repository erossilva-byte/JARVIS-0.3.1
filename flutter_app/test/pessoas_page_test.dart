import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/pessoas.dart';
import 'package:jarvis_nova/services/pessoas_page.dart';
import 'package:jarvis_nova/services/pessoas_store.dart';
import 'package:material_ui/material_ui.dart';

class ArmazenamentoFalso implements ArmazenamentoSeguro {
  ArmazenamentoFalso({this.falharAoGravar = false});

  final Map<String, String> valores = {};
  bool falharAoGravar;

  @override
  Future<String?> ler(String chave) async => valores[chave];

  @override
  Future<void> gravar(String chave, String valor) async {
    if (falharAoGravar) throw StateError('sem espaço');
    valores[chave] = valor;
  }

  @override
  Future<void> apagar(String chave) async => valores.remove(chave);
}

Future<void> _rolarAte(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ArmazenamentoFalso armazenamento;
  late PessoasStore store;

  setUp(() {
    armazenamento = ArmazenamentoFalso();
    store =
        PessoasStore(armazenamento, agora: () => DateTime(2026, 11, 15, 10));
  });

  test(
      'salvar exige nome e consentimento, grava no armazenamento seguro e não inventa campo',
      () async {
    final semConsentimento = await store.salvar(Pessoa(
      id: '',
      nome: 'Ana',
      criadaEm: DateTime(2026),
      atualizadaEm: DateTime(2026),
    ));
    expect(semConsentimento.ok, isFalse);
    expect(semConsentimento.erro, contains('consentimento'));

    final salva = await store.salvar(Pessoa(
      id: '',
      nome: 'Ana',
      consentimento: true,
      criadaEm: DateTime(2026),
      atualizadaEm: DateTime(2026),
    ));
    expect(salva.ok, isTrue);
    expect(salva.pessoa!.id, isNotEmpty);
    expect(salva.pessoa!.relacao, isEmpty);
    expect(armazenamento.valores[PessoasStore.chave], contains('Ana'));

    final relida = await store.listar();
    expect(relida, hasLength(1));
    expect(relida.single.apelido, isEmpty);
  });

  test('falha do armazenamento é informada, não engolida', () async {
    armazenamento.falharAoGravar = true;
    final resultado = await store.salvar(Pessoa(
      id: '',
      nome: 'Ana',
      consentimento: true,
      criadaEm: DateTime(2026),
      atualizadaEm: DateTime(2026),
    ));
    expect(resultado.ok, isFalse);
    expect(resultado.erro, contains('armazenamento seguro'));
    expect(await store.listar(), isEmpty);
  });

  testWidgets(
      'cria ficha, exige consentimento e mostra relação como não informada',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: PessoasPage(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma ficha ainda'), findsOneWidget);

    await tester.tap(find.text('Criar primeira ficha'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Ana');
    await tester.tap(find.byTooltip('Salvar ficha'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Confirme que você tem o consentimento'),
        findsOneWidget);
    expect(await store.listar(), isEmpty);

    await _rolarAte(tester, find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Salvar ficha'));
    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Relação não informada'), findsOneWidget);
    expect((await store.listar()).single.nome, 'Ana');
  });

  testWidgets('edita, busca e exclui a ficha por inteiro', (tester) async {
    await store.salvar(Pessoa(
        id: '',
        nome: 'Ana',
        consentimento: true,
        criadaEm: DateTime(2026),
        atualizadaEm: DateTime(2026)));
    await store.salvar(Pessoa(
        id: '',
        nome: 'Carlos',
        consentimento: true,
        criadaEm: DateTime(2026),
        atualizadaEm: DateTime(2026)));
    await tester.pumpWidget(MaterialApp(home: PessoasPage(store: store)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'ana');
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Carlos'), findsNothing);

    await tester.tap(find.text('Ana').first);
    await tester.pumpAndSettle();
    await _rolarAte(tester, find.widgetWithText(TextField, 'Relação'));
    await tester.enterText(find.widgetWithText(TextField, 'Relação'), 'irmã');
    await tester.tap(find.byTooltip('Salvar ficha'));
    await tester.pumpAndSettle();
    expect((await store.listar()).firstWhere((p) => p.nome == 'Ana').relacao,
        'irmã');

    await tester.tap(find.text('Ana').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Excluir ficha'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir esta ficha?'), findsOneWidget);
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    final restantes = await store.listar();
    expect(restantes.map((p) => p.nome), ['Carlos']);
  });

  testWidgets('consultar uma ficha mostra só o que foi preenchido',
      (tester) async {
    await store.salvar(Pessoa(
      id: '',
      nome: 'Ana',
      apelido: 'Aninha',
      relacao: 'irmã',
      preferencias: 'café sem açúcar',
      consentimento: true,
      criadaEm: DateTime(2026),
      atualizadaEm: DateTime(2026),
    ));
    await tester.pumpWidget(MaterialApp(home: PessoasPage(store: store)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana').first);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Aninha'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'irmã'), findsOneWidget);
    await _rolarAte(tester, find.widgetWithText(TextField, 'café sem açúcar'));
    expect(find.widgetWithText(TextField, 'café sem açúcar'), findsOneWidget);
  });
}
