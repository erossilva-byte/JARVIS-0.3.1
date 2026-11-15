import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/arquivos.dart';
import 'package:jarvis_nova/services/arquivos_page.dart';
import 'package:jarvis_nova/services/arquivo_sandbox.dart';
import 'package:material_ui/material_ui.dart';

class SandboxFalso implements ArquivoSandbox {
  final Map<String, String> conteudos = {};
  Object? erroAoAbrir;

  @override
  Future<List<ArquivoResumo>> listar() async {
    final nomes = conteudos.keys.toList()..sort();
    return [
      for (final nome in nomes)
        ArquivoResumo(nome: nome, bytes: conteudos[nome]!.length, modificadoEm: DateTime(2026, 11, 15, 10)),
    ];
  }

  @override
  Future<String> ler(String nome) async {
    if (!conteudos.containsKey(nome)) throw StateError('Arquivo não encontrado.');
    return conteudos[nome]!;
  }

  @override
  Future<void> criar(String nome, String conteudo) async {
    if (conteudos.containsKey(nome)) throw StateError('Já existe um arquivo com esse nome.');
    conteudos[nome] = conteudo;
  }

  @override
  Future<void> gravar(String nome, String conteudo) async {
    if (!conteudos.containsKey(nome)) throw StateError('Arquivo não encontrado.');
    conteudos[nome] = conteudo;
  }

  @override
  Future<void> renomear(String antigo, String novo) async {
    if (!conteudos.containsKey(antigo)) throw StateError('Arquivo não encontrado.');
    if (conteudos.containsKey(novo)) throw StateError('Já existe um arquivo com esse nome.');
    conteudos[novo] = conteudos.remove(antigo)!;
  }

  @override
  Future<void> apagar(String nome) async => conteudos.remove(nome);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sem arquivo, explica a pasta isolada e o que não existe', (tester) async {
    final sandbox = SandboxFalso();
    await tester.pumpWidget(MaterialApp(home: ArquivosPage(sandbox: sandbox)));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum arquivo ainda.'), findsOneWidget);
    expect(find.textContaining('Sem acesso a Downloads'), findsOneWidget);
    expect(find.textContaining('Execução de código não existe'), findsOneWidget);
  });

  testWidgets('criar grava o texto e acrescenta .txt', (tester) async {
    final sandbox = SandboxFalso();
    await tester.pumpWidget(MaterialApp(home: ArquivosPage(sandbox: sandbox)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('novo-arquivo')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('nome-arquivo')), 'nota');
    await tester.enterText(find.byKey(const ValueKey('conteudo-arquivo')), 'Conteúdo local.');
    await tester.tap(find.byKey(const ValueKey('salvar-arquivo')));
    await tester.pumpAndSettle();

    expect(sandbox.conteudos['nota.txt'], 'Conteúdo local.');
    expect(find.textContaining('Arquivo salvo'), findsOneWidget);

    await tester.tap(find.text('Voltar à lista'));
    await tester.pumpAndSettle();
    expect(find.text('nota.txt'), findsOneWidget);
  });

  testWidgets('nome com caminho é recusado antes de tocar no sandbox', (tester) async {
    final sandbox = SandboxFalso();
    await tester.pumpWidget(MaterialApp(home: ArquivosPage(sandbox: sandbox)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('novo-arquivo')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('nome-arquivo')), '../segredo');
    await tester.enterText(find.byKey(const ValueKey('conteudo-arquivo')), 'x');
    await tester.tap(find.byKey(const ValueKey('salvar-arquivo')));
    await tester.pumpAndSettle();

    expect(find.textContaining('não pode conter barras'), findsOneWidget);
    expect(sandbox.conteudos, isEmpty);
  });

  testWidgets('abrir, editar e salvar mantém o arquivo existente', (tester) async {
    final sandbox = SandboxFalso()..conteudos['nota.txt'] = 'Antigo.';
    await tester.pumpWidget(MaterialApp(home: ArquivosPage(sandbox: sandbox)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('arquivo-nota.txt')));
    await tester.pumpAndSettle();
    expect(find.text('Antigo.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('conteudo-arquivo')), 'Novo texto.');
    await tester.tap(find.byKey(const ValueKey('salvar-arquivo')));
    await tester.pumpAndSettle();

    expect(sandbox.conteudos['nota.txt'], 'Novo texto.');
  });

  testWidgets('renomear recusa nome com caminho e aceita nome simples', (tester) async {
    final sandbox = SandboxFalso()..conteudos['nota.txt'] = 'Texto.';
    await tester.pumpWidget(MaterialApp(home: ArquivosPage(sandbox: sandbox)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('arquivo-nota.txt')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('renomear-arquivo')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'outra');
    await tester.tap(find.text('Renomear'));
    await tester.pumpAndSettle();

    expect(sandbox.conteudos.containsKey('outra.txt'), isTrue);
    expect(sandbox.conteudos.containsKey('nota.txt'), isFalse);
  });

  testWidgets('apagar exige confirmação e some da lista', (tester) async {
    final sandbox = SandboxFalso()..conteudos['nota.txt'] = 'Texto.';
    await tester.pumpWidget(MaterialApp(home: ArquivosPage(sandbox: sandbox)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('arquivo-nota.txt')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apagar-arquivo')));
    await tester.pumpAndSettle();
    expect(find.text('Apagar este arquivo?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Apagar'));
    await tester.pumpAndSettle();

    expect(sandbox.conteudos, isEmpty);
    expect(find.text('Nenhum arquivo ainda.'), findsOneWidget);
  });

  testWidgets('sem pasta disponível, informa em vez de fingir lista vazia', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ArquivosPage(abrir: () async => throw StateError('sem pasta'))));
    await tester.pumpAndSettle();

    expect(find.textContaining('pasta isolada de arquivos não está disponível'), findsOneWidget);
  });

  testWidgets('sair com texto não salvo pede confirmação', (tester) async {
    final sandbox = SandboxFalso();
    await tester.pumpWidget(MaterialApp(home: ArquivosPage(sandbox: sandbox)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('novo-arquivo')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('conteudo-arquivo')), 'Não salvo');
    await tester.tap(find.text('Voltar à lista'));
    await tester.pumpAndSettle();

    expect(find.text('Descartar alterações?'), findsOneWidget);
    await tester.tap(find.text('Continuar editando'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('conteudo-arquivo')), findsOneWidget);
  });
}
