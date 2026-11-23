import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/nucleo/humor_nucleo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final enviados = <String>[];
  const canal = MethodChannel('com.jarvis.nova/nucleo');

  setUp(() {
    enviados.clear();
    HumorNucleoControle.reiniciarParaTeste();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (call) async {
      if (call.method == 'definirHumor') {
        enviados.add(call.arguments['humor'] as String);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);
    HumorNucleoControle.reiniciarParaTeste();
  });

  test('sem escuta e sem conversa, fica em espera', () {
    expect(HumorNucleoControle.atual, HumorNucleo.espera);
  });

  test('escuta liga o ouvindo e desliga ao fechar o microfone', () {
    HumorNucleoControle.definirEscuta(true);
    expect(HumorNucleoControle.atual, HumorNucleo.ouvindo);
    HumorNucleoControle.definirEscuta(false);
    expect(HumorNucleoControle.atual, HumorNucleo.espera);
  });

  test('pensando vence a escuta e volta a ouvir quando a resposta chega', () {
    HumorNucleoControle.definirEscuta(true);
    HumorNucleoControle.definirPensando(true);
    expect(HumorNucleoControle.atual, HumorNucleo.pensando);
    HumorNucleoControle.definirPensando(false);
    expect(HumorNucleoControle.atual, HumorNucleo.ouvindo);
  });

  test('fala vence o pensamento e duas leituras em fila contam', () {
    HumorNucleoControle.definirPensando(true);
    HumorNucleoControle.iniciarFala();
    expect(HumorNucleoControle.atual, HumorNucleo.falando);
    HumorNucleoControle.iniciarFala();
    HumorNucleoControle.terminarFala();
    expect(HumorNucleoControle.atual, HumorNucleo.falando);
    HumorNucleoControle.terminarFala();
    expect(HumorNucleoControle.atual, HumorNucleo.pensando);
  });

  test('fechar a conversa esquece pensamento e falas', () {
    HumorNucleoControle.definirEscuta(true);
    HumorNucleoControle.definirPensando(true);
    HumorNucleoControle.iniciarFala();
    HumorNucleoControle.esquecerConversa();
    expect(HumorNucleoControle.atual, HumorNucleo.ouvindo);
    HumorNucleoControle.iniciarFala();
    HumorNucleoControle.terminarFala();
    expect(HumorNucleoControle.atual, HumorNucleo.ouvindo);
  });

  test('envia ao Android só quando o humor muda', () async {
    HumorNucleoControle.definirEscuta(true);
    HumorNucleoControle.definirEscuta(true);
    HumorNucleoControle.definirPensando(true);
    HumorNucleoControle.iniciarFala();
    HumorNucleoControle.terminarFala();
    HumorNucleoControle.definirPensando(false);
    HumorNucleoControle.definirEscuta(false);
    await Future<void>.delayed(Duration.zero);

    expect(enviados, [
      'ouvindo',
      'pensando',
      'falando',
      'pensando',
      'ouvindo',
      'espera',
    ]);
  });
}
