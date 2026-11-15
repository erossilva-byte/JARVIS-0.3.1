import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/services/cofre_saf.dart';
import 'package:jarvis_nova/services/memoria_page.dart';
import 'package:jarvis_nova/services/memoria_store.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final canal = CofreSaf.canal;
  Object? respostaPasta;
  Object? respostaLeitura;
  final chamadas = <String>[];

  setUp(() {
    chamadas.clear();
    respostaPasta = null;
    respostaLeitura = null;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(canal, (chamada) async {
      chamadas.add(chamada.method);
      switch (chamada.method) {
        case 'pastaAtual':
        case 'escolherPasta':
          return respostaPasta;
        case 'listarNotas':
          return respostaLeitura;
        case 'esquecerPasta':
          return true;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(canal, null);
  });

  test('pasta ausente é ok com valor nulo, não erro', () async {
    final resultado = await CofreSaf.pastaAtual();
    expect(resultado.ok, isTrue);
    expect(resultado.valor, isNull);
  });

  test('leitura em formato inesperado falha sem importar nada', () async {
    respostaLeitura = {'notas': 'quebrado'};
    final resultado = await CofreSaf.listarNotas();
    expect(resultado.ok, isFalse);
    expect(resultado.erro, contains('formato inesperado'));
  });

  test('leitura ignora nota sem nome e conta ignoradas/truncadas', () async {
    respostaLeitura = {
      'notas': [
        {'nome': 'Motor.md', 'caminho': 'Oficina/Motor.md', 'conteudo': '# Motor'},
        {'conteudo': 'sem nome'},
      ],
      'ignoradas': 2,
      'truncadas': 1,
    };
    final resultado = await CofreSaf.listarNotas();
    expect(resultado.ok, isTrue);
    expect(resultado.valor!.notas, hasLength(1));
    expect(resultado.valor!.notas.single.caminho, 'Oficina/Motor.md');
    expect(resultado.valor!.ignoradas, 2);
    expect(resultado.valor!.truncadas, 1);
  });

  testWidgets('conecta pasta e importa as notas para o cofre', (tester) async {
    final store = await MemoriaStore.abrir();
    await tester.pumpWidget(MaterialApp(home: MemoriaPage(store: store)));
    await tester.pumpAndSettle();

    respostaPasta = {'uri': 'content://com.android.externalstorage.documents/tree/primary%3AObsidian', 'nome': 'Obsidian'};
    await tester.tap(find.text('Conectar pasta do Obsidian'));
    await tester.pumpAndSettle();

    expect(find.text('Obsidian'), findsOneWidget);
    expect(chamadas, contains('escolherPasta'));

    respostaLeitura = {
      'notas': [
        {'nome': 'Motor.md', 'caminho': 'Oficina/Motor.md', 'conteudo': '---\ntitulo: Motor da bancada\n---\nLigação em estrela-triângulo.'},
        {'nome': 'Receita.md', 'caminho': 'Cozinha/Receita.md', 'conteudo': '---\ntitulo: Receita\n---\nBolo de cenoura.'},
      ],
      'ignoradas': 1,
      'truncadas': 0,
    };
    await tester.tap(find.text('Importar notas'));
    await tester.pumpAndSettle();
    // O aviso da conexão ainda estava na fila: avance para o da importação aparecer.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(store.listar(), hasLength(2));
    expect(store.listar().map((n) => n.titulo), contains('Motor da bancada'));
    expect(find.textContaining('2 nova(s)'), findsOneWidget);
    expect(find.textContaining('1 arquivo(s) ignorado(s)'), findsOneWidget);
  });

  testWidgets('desconectar remove o cartão da pasta', (tester) async {
    final store = await MemoriaStore.abrir();
    respostaPasta = {'uri': 'content://tree/obsidian', 'nome': 'Meu cofre'};
    await tester.pumpWidget(MaterialApp(home: MemoriaPage(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('Meu cofre'), findsOneWidget);
    await tester.tap(find.byTooltip('Desconectar pasta'));
    await tester.pumpAndSettle();

    expect(find.text('Meu cofre'), findsNothing);
    expect(chamadas, contains('esquecerPasta'));
  });

  testWidgets('fora do Android a tela explica em vez de falhar calada', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final store = await MemoriaStore.abrir();
    await tester.pumpWidget(MaterialApp(home: MemoriaPage(store: store)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Conectar pasta do Obsidian'));
    await tester.pumpAndSettle();
    // Resetar ainda dentro do teste: a verificação de invariantes roda depois do tearDown.
    debugDefaultTargetPlatformOverride = null;

    expect(find.textContaining('só existe no Android'), findsOneWidget);
  });
}
