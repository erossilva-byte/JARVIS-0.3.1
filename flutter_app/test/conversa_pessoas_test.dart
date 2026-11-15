import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/conversa.dart';
import 'package:jarvis_nova/services/voice_conversation_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _bloco = 'FICHA DE PESSOA — dados fornecidos pelo próprio usuário; use apenas o que está aqui.\n'
    '- Nome: Ana\n'
    '- Relação: irmã\n'
    '\n'
    'Contato, anotações, compromissos e histórico não estão disponíveis para envio.';

Conversa _conversa({required List<String> fichas, required String bloco}) {
  final conversa = Conversa(
    id: 'c1',
    titulo: 'Ana',
    criadaEm: DateTime(2026, 11, 15, 10),
    atualizadaEm: DateTime(2026, 11, 15, 10),
  );
  conversa.adicionar(MensagemConversa(autor: 'user', texto: 'quem é a Ana?'));
  conversa.adicionar(MensagemConversa(
    autor: 'assistant',
    texto: 'A Ana é sua irmã.',
    fichas: fichas,
    contextoPessoas: bloco,
  ));
  return conversa;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a resposta mostra a ficha usada e o bloco exato enviado', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: VoiceConversationPage(initialCommand: '', conversa: _conversa(fichas: ['Ana'], bloco: _bloco)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Ficha usada: Ana'), findsOneWidget);
    expect(find.textContaining('FICHA DE PESSOA'), findsNothing);

    await tester.tap(find.text('Ficha usada: Ana'));
    await tester.pumpAndSettle();

    expect(find.textContaining('FICHA DE PESSOA'), findsOneWidget);
    expect(find.textContaining('- Nome: Ana'), findsOneWidget);
  });

  testWidgets('sem correspondência a bolha diz isso, sem inventar nome', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: VoiceConversationPage(
        initialCommand: '',
        conversa: _conversa(fichas: const [], bloco: 'FICHAS DE PESSOAS — nenhuma ficha corresponde ao nome perguntado.'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Fichas: nenhuma correspondência'), findsOneWidget);
    expect(find.textContaining('Ficha usada'), findsNothing);
  });

  testWidgets('resposta sem ficha não ganha o bloco de transparência', (tester) async {
    final conversa = Conversa(
      id: 'c2',
      titulo: 'Sem ficha',
      criadaEm: DateTime(2026, 11, 15, 10),
      atualizadaEm: DateTime(2026, 11, 15, 10),
    );
    conversa.adicionar(MensagemConversa(autor: 'user', texto: 'qual a capital da França?'));
    conversa.adicionar(const MensagemConversa(autor: 'assistant', texto: 'Paris.'));
    await tester.pumpWidget(MaterialApp(home: VoiceConversationPage(initialCommand: '', conversa: conversa)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ficha usada'), findsNothing);
    expect(find.textContaining('Fichas: nenhuma'), findsNothing);
    expect(find.text('Paris.'), findsOneWidget);
  });
}
