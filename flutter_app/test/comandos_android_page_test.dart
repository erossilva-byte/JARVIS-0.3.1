import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/services/comandos_android_page.dart';
import 'package:jarvis_nova/services/comandos_android_service.dart';
import 'package:jarvis_nova/services/voice_conversation_page.dart';
import 'package:jarvis_nova/services/conversa_store.dart';
import 'package:material_ui/material_ui.dart';

class ExecutorFalso extends ExecutorComandosAndroid {
  ExecutorFalso() : super(ativo: false);
  String? ultimo;

  @override
  Future<ResultadoComando?> executar(String texto) async {
    ultimo = texto;
    if (!texto.toLowerCase().contains('lanterna')) return null;
    return const ResultadoComando(
        ok: true, mensagem: 'Lanterna ligada de verdade.');
  }
}

void main() {
  setUp(ConversaStore.reiniciarSessaoParaTeste);
  testWidgets('executa pelo campo e mostra a confirmação', (tester) async {
    final executor = ExecutorFalso();
    await tester
        .pumpWidget(MaterialApp(home: ComandosAndroidPage(executor: executor)));
    await tester.enterText(find.byKey(const ValueKey('comando-android-campo')),
        'ligar a lanterna');
    await tester.tap(find.byKey(const ValueKey('executar-comando-android')));
    await tester.pumpAndSettle();

    expect(executor.ultimo, 'ligar a lanterna');
    expect(find.text('Lanterna ligada de verdade.'), findsOneWidget);
    expect(find.text('REGISTRO DE AÇÕES'), findsOneWidget);
  });

  testWidgets('texto sem comando não inventa execução', (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: ComandosAndroidPage(executor: ExecutorFalso())));
    await tester.enterText(
        find.byKey(const ValueKey('comando-android-campo')), 'Bom dia');
    await tester.tap(find.byKey(const ValueKey('executar-comando-android')));
    await tester.pumpAndSettle();
    expect(find.textContaining('não é um comando'), findsOneWidget);
  });

  testWidgets('comando por voz executa antes de exigir provedor de IA',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.jarvis.nova/comandos'),
      (call) async => {
        'ligada': true,
        'mensagem': 'Lanterna ligada pelo canal nativo.',
      },
    );
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.jarvis.nova/comandos'), null));

    await tester.pumpWidget(const MaterialApp(
        home: VoiceConversationPage(
            initialCommand: 'ligar a lanterna', fromVoice: true)));
    await tester.pumpAndSettle();

    expect(find.text('Lanterna ligada pelo canal nativo.'), findsOneWidget);
    expect(find.textContaining('Nenhum provedor configurado'), findsNothing);
  });

  testWidgets('sem ponte Android explica a indisponibilidade', (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: ComandosAndroidPage(ativo: false)));
    await tester.enterText(
        find.byKey(const ValueKey('comando-android-campo')), 'volume 40');
    await tester.tap(find.byKey(const ValueKey('executar-comando-android')));
    await tester.pumpAndSettle();
    expect(find.textContaining('só funcionam no app Android'), findsOneWidget);
  });
}
