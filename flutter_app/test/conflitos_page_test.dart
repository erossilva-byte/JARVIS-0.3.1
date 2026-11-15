import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/memoria.dart';
import 'package:jarvis_nova/core/memoria_sync.dart';
import 'package:jarvis_nova/services/cofre_saf.dart';
import 'package:jarvis_nova/services/conflitos_page.dart';
import 'package:jarvis_nova/services/memoria_store.dart';
import 'package:jarvis_nova/services/sincronizador.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CofreFalso implements CofreRemoto {
  final Map<String, String> arquivos = {};

  @override
  Future<ResultadoSaf<LeituraSaf>> listarNotas() async => ResultadoSaf.ok(LeituraSaf(notas: const []));

  @override
  Future<ResultadoSaf<bool>> escreverNota({required String caminho, required String conteudo}) async {
    arquivos[caminho] = conteudo;
    return const ResultadoSaf.ok(true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mostra as duas versões e mantém a escolhida sem apagar a outra', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await MemoriaStore.abrir();
    final quando = DateTime(2026, 11, 15);
    await store.salvar(NotaMemoria(
      id: 'motor',
      titulo: 'Motor',
      texto: 'texto do aparelho',
      caminho: 'Oficina/Motor.md',
      hashSincronizado: hashConteudo('base'),
      criadaEm: quando,
      atualizadaEm: quando,
    ));
    final conflito = ConflitoSync(
      local: store.listar().single,
      remoto: ArquivoRemoto(caminho: 'Oficina/Motor.md', conteudo: '---\ntitulo: Motor\n---\ntexto da pasta'),
      motivo: 'as duas cópias mudaram',
    );
    final cofre = CofreFalso();

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (contexto) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(contexto).push(MaterialPageRoute<void>(
                builder: (_) => ConflitosPage(conflitos: [conflito], store: store, cofre: cofre),
              )),
              child: const Text('abrir conflitos'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir conflitos'));
    await tester.pumpAndSettle();

    expect(find.text('Neste aparelho'), findsOneWidget);
    expect(find.text('Na pasta do Obsidian'), findsOneWidget);
    expect(find.textContaining('texto do aparelho'), findsWidgets);
    expect(find.textContaining('texto da pasta'), findsWidgets);

    await tester.tap(find.text('Manter a do aparelho'));
    await tester.pumpAndSettle();
    expect(find.text('Manter esta versão?'), findsOneWidget);
    await tester.tap(find.text('Manter'));
    await tester.pumpAndSettle();

    expect(cofre.arquivos['Oficina/Motor.md'], contains('texto do aparelho'));
    final textos = store.listar().map((n) => n.texto).toList();
    expect(textos, contains('texto do aparelho'));
    expect(textos, contains('texto da pasta'));
    expect(find.textContaining('nota de backup'), findsOneWidget);

    await tester.tap(find.text('Voltar ao cofre'));
    await tester.pumpAndSettle();
    expect(find.text('abrir conflitos'), findsOneWidget);
  });
}
