import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/services/voz_jarvis.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test.jarvis/voz');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('limpa marcação antes de falar', () {
    final texto = VozJarvis.limparParaFala(
        '**Olá**, senhor. Veja [o relatório](https://exemplo.com) agora.\n\n`código`');
    expect(texto, 'Olá, senhor. Veja o relatório agora. código');
    expect(texto, isNot(contains('*')));
    expect(texto, isNot(contains('https://')));
  });

  test('limita respostas longas sem cortar no meio de uma palavra', () {
    final longo = '${'Frase de teste. ' * 200}fim.';
    final texto = VozJarvis.limparParaFala(longo);
    expect(texto.length, lessThanOrEqualTo(1801));
    expect(texto.endsWith('.'), isTrue);
  });

  test('envia o texto limpo ao canal nativo e devolve sucesso', () async {
    String? recebido;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'falar');
      recebido = (call.arguments as Map)['texto'] as String;
      return true;
    });
    const voz = VozJarvis(channel: channel);
    final ok = await voz.falar('**Olá**, senhor.');
    expect(ok, isTrue);
    expect(recebido, 'Olá, senhor.');
  });

  test('não quebra a conversa quando a plataforma não tem voz', () async {
    const voz = VozJarvis(channel: channel);
    expect(await voz.falar('Olá'), isFalse);
    await voz.parar();
  });
}
