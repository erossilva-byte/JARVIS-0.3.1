import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/services/timbre_page.dart';
import 'package:jarvis_nova/services/voz_jarvis.dart';
import 'package:material_ui/material_ui.dart';

const _canal = MethodChannel('test.jarvis/voz');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, null);
  });

  void responder(Future<Object?> Function(MethodCall call) aoChamar) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, aoChamar);
  }

  testWidgets('mostra o timbre gravado no aparelho', (tester) async {
    responder((call) async {
      if (call.method == 'timbre') {
        return {'timbre': 'natural', 'padrao': 'grave', 'perfis': <Object?>[]};
      }
      return null;
    });
    await tester.pumpWidget(
        const MaterialApp(home: TimbrePage(voz: VozJarvis(channel: _canal))));
    await tester.pumpAndSettle();

    expect(find.textContaining('Natural: tom 1.00'), findsOneWidget);
    expect(find.byKey(const ValueKey('timbre-opcao-grave')), findsOneWidget);
    expect(find.byKey(const ValueKey('timbre-opcao-agil')), findsOneWidget);
  });

  testWidgets('escolher ágil grava o perfil e confirma o aplicado',
      (tester) async {
    String? enviado;
    responder((call) async {
      if (call.method == 'timbre') {
        return {'timbre': 'grave'};
      }
      if (call.method == 'definirTimbre') {
        enviado = (call.arguments as Map)['id'] as String;
        return {'timbre': enviado, 'aplicado': true};
      }
      return null;
    });
    await tester.pumpWidget(
        const MaterialApp(home: TimbrePage(voz: VozJarvis(channel: _canal))));
    await tester.pumpAndSettle();

    final agil = find.byKey(const ValueKey('timbre-opcao-agil'));
    await tester.ensureVisible(agil);
    await tester.pumpAndSettle();
    await tester.tap(agil);
    await tester.pumpAndSettle();

    expect(enviado, 'agil');
    // Com quatro perfis a lista rola: volta ao topo para ler o cartão "VOZ ATUAL".
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ágil: tom 1.15'), findsOneWidget);
    expect(find.byKey(const ValueKey('timbre-aplicado')), findsNothing);
    expect(find.byKey(const ValueKey('timbre-erro')), findsNothing);
  });

  testWidgets('síntese não pronta avisa que o perfil só vale na próxima fala',
      (tester) async {
    responder((call) async {
      if (call.method == 'timbre') return {'timbre': 'grave'};
      if (call.method == 'definirTimbre') {
        return {'timbre': 'natural', 'aplicado': false};
      }
      return null;
    });
    await tester.pumpWidget(
        const MaterialApp(home: TimbrePage(voz: VozJarvis(channel: _canal))));
    await tester.pumpAndSettle();

    final natural = find.byKey(const ValueKey('timbre-opcao-natural'));
    await tester.ensureVisible(natural);
    await tester.pumpAndSettle();
    await tester.tap(natural);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('timbre-aplicado')), findsOneWidget);
  });

  testWidgets('“Ouvir exemplo” usa a mesma frase e a mesma síntese',
      (tester) async {
    String? falado;
    responder((call) async {
      if (call.method == 'timbre') return {'timbre': 'grave'};
      if (call.method == 'falar') {
        falado = (call.arguments as Map)['texto'] as String;
        return true;
      }
      return null;
    });
    await tester.pumpWidget(
        const MaterialApp(home: TimbrePage(voz: VozJarvis(channel: _canal))));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('timbre-ouvir')));
    await tester.pumpAndSettle();

    expect(falado, contains('Eu sou o JARVIS'));
    expect(find.byKey(const ValueKey('timbre-erro')), findsNothing);
  });

  testWidgets('canal sem resposta explica em vez de fingir um timbre',
      (tester) async {
    // Aparelho antigo ou fora do Android: o canal responde vazio.
    responder((call) async => null);
    await tester.pumpWidget(
        const MaterialApp(home: TimbrePage(voz: VozJarvis(channel: _canal))));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('timbre-erro')), findsOneWidget);
    expect(find.textContaining('só existem no app Android'), findsOneWidget);
    expect(find.textContaining('Lendo o timbre'), findsNothing);
  });
}
