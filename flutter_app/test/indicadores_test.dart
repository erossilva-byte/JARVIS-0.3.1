import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/main.dart';
import 'package:jarvis_nova/services/voice_conversation_page.dart';

void main() {
  testWidgets('comando digitado nao se apresenta como captura de voz', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: VoiceConversationPage(initialCommand: 'Bom dia')),
    );
    await tester.pump();

    expect(find.text('Comando digitado'), findsOneWidget);
    expect(find.text('Enviado pelo campo de conversa'), findsOneWidget);
    expect(find.text('Comando capturado por voz'), findsNothing);
    expect(find.text('Reconhecimento de fala no dispositivo \u00b7 pt-BR'), findsNothing);
  });

  testWidgets('comando do KWS se apresenta como captura de voz', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: VoiceConversationPage(initialCommand: 'Bom dia', fromVoice: true)),
    );
    await tester.pump();

    expect(find.text('Comando capturado por voz'), findsOneWidget);
    expect(find.text('Reconhecimento de fala no dispositivo \u00b7 pt-BR'), findsOneWidget);
    expect(find.text('Comando digitado'), findsNothing);
  });

  testWidgets('a gaveta mostra o diagnostico real da voz, nao um ONLINE fixo', (tester) async {
    await tester.pumpWidget(const JarvisApp());
    await tester.pump();

    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('ONLINE'), findsNothing);
    expect(find.text('VOZ LOCAL'), findsOneWidget);
    expect(find.textContaining('KWS'), findsWidgets);
  });
}
