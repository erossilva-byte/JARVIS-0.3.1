import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/services/hermes_page.dart';
import 'package:material_ui/material_ui.dart';


/// Tela alta: as listas destas telas são longas e o teste padrão de 800×600
/// deixa os botões de baixo fora da árvore, como aconteceria no aparelho sem
/// rolagem.
void _telaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('o plano aparece antes de executar e cita o agente', (tester) async {
    _telaAlta(tester);
    await tester.pumpWidget(
        MaterialApp(home: HermesPage(responder: (_) async => 'passo ok')));

    await tester.enterText(find.byKey(const ValueKey('hermes-campo')),
        'monta um divisor de tensão de 12 V');
    await tester.tap(find.byKey(const ValueKey('hermes-planejar')));
    await tester.pumpAndSettle();

    expect(find.text('Agente: Eletrônica'), findsOneWidget);
    expect(find.textContaining('Fixar o pedido'), findsOneWidget);
    expect(find.byKey(const ValueKey('hermes-aviso')), findsOneWidget);
    // Nada foi executado antes do botão: nenhuma resposta na lista.
    expect(find.byKey(const ValueKey('hermes-resposta-0')), findsNothing);
  });

  testWidgets('executar os passos mostra a resposta de cada um', (tester) async {
    _telaAlta(tester);
    await tester.pumpWidget(
        MaterialApp(home: HermesPage(responder: (_) async => 'passo ok')));

    await tester.enterText(find.byKey(const ValueKey('hermes-campo')),
        'monta um divisor de tensão de 12 V');
    await tester.tap(find.byKey(const ValueKey('hermes-planejar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hermes-executar')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('hermes-resposta-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('hermes-resposta-3')), findsOneWidget);
    expect(find.text('passo ok'), findsNWidgets(4));
  });

  testWidgets('sem provedor, o erro é dito e o plano continua na tela',
      (tester) async {
    _telaAlta(tester);
    await tester.pumpWidget(MaterialApp(
        home: HermesPage(
            responder: (_) async => throw Exception('sem provedor configurado'))));

    await tester.enterText(
        find.byKey(const ValueKey('hermes-campo')), 'bom dia');
    await tester.tap(find.byKey(const ValueKey('hermes-planejar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hermes-executar')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('hermes-erro')), findsOneWidget);
    expect(find.textContaining('passo 1'), findsOneWidget);
    // O plano não desapareceu por causa da falha.
    expect(find.text('Agente: Conversa'), findsOneWidget);
  });

  testWidgets('pedido elétrico oferece o projetista', (tester) async {
    _telaAlta(tester);
    await tester.pumpWidget(
        MaterialApp(home: HermesPage(responder: (_) async => 'ok')));

    await tester.enterText(find.byKey(const ValueKey('hermes-campo')),
        'partida direta de um motor de 24 V');
    await tester.tap(find.byKey(const ValueKey('hermes-planejar')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('hermes-montar')), findsOneWidget);
  });

  testWidgets('a lista de agentes mostra os doze domínios e roteia',
      (tester) async {
    _telaAlta(tester);
    await tester.pumpWidget(const MaterialApp(home: AgentesPage()));

    expect(find.text('Conversa'), findsOneWidget);
    expect(find.text('Eletrônica'), findsOneWidget);
    expect(find.text('Engenharia'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('agentes-campo')), 'aumenta o volume');
    await tester.pumpAndSettle();
    expect(find.text('Vai para: Dispositivo'), findsOneWidget);
  });
}
