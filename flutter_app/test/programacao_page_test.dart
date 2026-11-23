import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/arquivos.dart';
import 'package:jarvis_nova/services/arquivo_sandbox.dart';
import 'package:jarvis_nova/services/programacao_page.dart';
import 'package:material_ui/material_ui.dart';

/// Pasta isolada em memória: o teste sabe o que foi salvo sem tocar no disco.
class _SandboxFalso implements ArquivoSandbox {
  final arquivos = <String, String>{};

  @override
  Future<List<ArquivoResumo>> listar() async => [
        for (final entrada in arquivos.entries)
          ArquivoResumo(nome: entrada.key, bytes: entrada.value.length),
      ];

  @override
  Future<String> ler(String nome) async => arquivos[nome] ?? '';

  @override
  Future<void> criar(String nome, String conteudo) async {
    if (arquivos.containsKey(nome)) {
      throw StateError('Já existe um arquivo com esse nome.');
    }
    arquivos[nome] = conteudo;
  }

  @override
  Future<void> gravar(String nome, String conteudo) async {
    arquivos[nome] = conteudo;
  }

  @override
  Future<void> renomear(String antigo, String novo) async {
    final conteudo = arquivos.remove(antigo);
    if (conteudo != null) arquivos[novo] = conteudo;
  }

  @override
  Future<void> apagar(String nome) async {
    arquivos.remove(nome);
  }
}

void _telaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('pedido vazio é recusado com o motivo, sem chamar o provedor',
      (tester) async {
    _telaAlta(tester);
    var chamadas = 0;
    await tester.pumpWidget(MaterialApp(
      home: ProgramacaoPage(
        responder: (mensagens) async {
          chamadas++;
          return 'não deveria ser chamado';
        },
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('programacao-enviar')));
    await tester.pumpAndSettle();

    expect(chamadas, 0);
    expect(find.byKey(const ValueKey('programacao-erro-tela')), findsOneWidget);
    expect(find.textContaining('Descreva o que o código deve fazer'),
        findsOneWidget);
  });

  testWidgets('analisar sem código para antes de gastar a chamada',
      (tester) async {
    _telaAlta(tester);
    var chamadas = 0;
    await tester.pumpWidget(MaterialApp(
      home: ProgramacaoPage(
        responder: (_) async {
          chamadas++;
          return 'nada';
        },
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('programacao-tarefa-analisar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('programacao-enviar')));
    await tester.pumpAndSettle();

    expect(chamadas, 0);
    expect(find.textContaining('Cole o código na área'), findsOneWidget);
  });

  testWidgets('a resposta aparece com o bloco de código e o aviso honesto',
      (tester) async {
    _telaAlta(tester);
    List<Map<String, String>>? enviado;
    await tester.pumpWidget(MaterialApp(
      home: ProgramacaoPage(
        responder: (mensagens) async {
          enviado = mensagens;
          return 'Um contador simples:\n\n```dart\nvoid main() {\n  print(1);\n}\n```\n';
        },
        sandbox: _SandboxFalso(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('programacao-pedido')), 'um contador');
    await tester.tap(find.byKey(const ValueKey('programacao-enviar')));
    await tester.pumpAndSettle();

    expect(enviado, isNotNull);
    expect(enviado!.last['content'], contains('um contador'));
    expect(find.byKey(const ValueKey('programacao-bloco-0')), findsOneWidget);
    expect(find.textContaining('void main'), findsWidgets);
    expect(find.textContaining('Nada foi executado'), findsOneWidget);
    expect(find.textContaining('Salvar em Arquivos'), findsOneWidget);
  });

  testWidgets('usar na área devolve o código para a área de código',
      (tester) async {
    _telaAlta(tester);
    await tester.pumpWidget(MaterialApp(
      home: ProgramacaoPage(
        responder: (_) async => '```python\nprint("oi")\n```',
        sandbox: _SandboxFalso(),
      ),
    ));
    await tester.pumpAndSettle();

    // A área de código só existe nas tarefas que usam código colado, e
    // “modificar” precisa do código e do pedido.
    await tester.tap(find.byKey(const ValueKey('programacao-tarefa-modificar')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('programacao-codigo')), 'print(1)');
    await tester.enterText(
        find.byKey(const ValueKey('programacao-pedido')), 'troque por oi');
    await tester.tap(find.byKey(const ValueKey('programacao-enviar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('programacao-usar-0')));
    await tester.pumpAndSettle();

    final campo = tester.widget<TextField>(
        find.byKey(const ValueKey('programacao-codigo')));
    expect(campo.controller!.text, contains('print("oi")'));
    expect(find.textContaining('colocado na área de código'), findsOneWidget);
  });

  testWidgets('salvar grava o código na pasta isolada como texto',
      (tester) async {
    _telaAlta(tester);
    final sandbox = _SandboxFalso();
    await tester.pumpWidget(MaterialApp(
      home: ProgramacaoPage(
        responder: (_) async => '```dart\nvoid main() {}\n```',
        sandbox: sandbox,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('programacao-pedido')), 'um programa');
    await tester.tap(find.byKey(const ValueKey('programacao-enviar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('programacao-salvar')));
    await tester.pumpAndSettle();

    expect(sandbox.arquivos.keys, contains('codigo_dart'));
    expect(sandbox.arquivos['codigo_dart'], contains('void main'));
    expect(find.textContaining('salvo em Arquivos como codigo_dart.txt'),
        findsOneWidget);
  });

  testWidgets('o prompt de código é montado no aparelho, sem provedor',
      (tester) async {
    _telaAlta(tester);
    var chamadas = 0;
    await tester.pumpWidget(MaterialApp(
      home: ProgramacaoPage(
        responder: (_) async {
          chamadas++;
          return 'não deveria ser chamado';
        },
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('programacao-tarefa-prompt')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('programacao-pedido')),
        'somar horas trabalhadas');
    await tester.enterText(
        find.byKey(const ValueKey('programacao-restricoes')), 'sem biblioteca');
    await tester.tap(find.byKey(const ValueKey('programacao-enviar')));
    await tester.pumpAndSettle();

    expect(chamadas, 0);
    expect(find.textContaining('Objetivo: somar horas trabalhadas'),
        findsOneWidget);
    expect(find.textContaining('Restrições: sem biblioteca'), findsOneWidget);
    final status = tester.widget<Text>(
        find.byKey(const ValueKey('programacao-status')));
    expect(status.data, contains('montado no aparelho'));
  });
}
