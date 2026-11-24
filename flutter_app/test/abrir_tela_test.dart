import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/pedido_abrir.dart';
import 'package:jarvis_nova/services/abrir_tela.dart';
import 'package:jarvis_nova/services/hermes_page.dart';

void main() {
  testWidgets('tela pedida por voz abre por cima da tela atual',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      navigatorKey: AbrirTela.navegador,
      home: const Scaffold(body: Text('início')),
    ));
    expect(find.text('início'), findsOneWidget);

    final resultado = await AbrirTela.abrir(TelaJarvis.agentes);
    await tester.pumpAndSettle();

    expect(resultado.ok, isTrue);
    expect(resultado.acao, 'abrir os agentes');
    expect(resultado.mensagem, 'Abrindo os agentes.');
    expect(find.byType(AgentesPage), findsOneWidget);
    // A tela anterior continua embaixo: voltar devolve o usuário para onde ele
    // estava, em vez de reiniciar o app.
    expect(find.text('início', skipOffstage: false), findsOneWidget);
  });
}
