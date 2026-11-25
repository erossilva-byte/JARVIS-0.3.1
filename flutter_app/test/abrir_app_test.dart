import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/services/abrir_app.dart';
import 'package:jarvis_nova/services/aparelho_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const canal = MethodChannel('teste.jarvis.abrir.app');
  late List<MethodCall> chamadas;

  setUp(() {
    chamadas = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (chamada) async {
      chamadas.add(chamada);
      if (chamada.arguments['app'] == 'maps') {
        return {'ok': false, 'mensagem': 'O mapa não abriu.'};
      }
      return {
        'ok': true,
        'mensagem': 'Abri o WhatsApp na conversa com Ana.',
      };
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);
  });

  test('manda app, ação e alvo para o Android', () async {
    final resultado = await AbrirAppComAcao.executar(
      'abre o WhatsApp na conversa da Ana',
      aparelho: AparelhoService(canal: canal),
    );

    expect(resultado, isNotNull);
    expect(resultado!.ok, isTrue);
    expect(resultado.mensagem, 'Abri o WhatsApp na conversa com Ana.');
    expect(resultado.acao, 'abrir o WhatsApp na conversa com Ana');
    expect(chamadas, hasLength(1));
    expect(chamadas.single.method, 'abrirComAcao');
    expect(chamadas.single.arguments['app'], 'whatsapp');
    expect(chamadas.single.arguments['acao'], 'conversa');
    expect(chamadas.single.arguments['alvo'], 'Ana');
  });

  test('devolve null quando o texto não é pedido de app', () async {
    final resultado = await AbrirAppComAcao.executar(
      'abre o WhatsApp',
      aparelho: AparelhoService(canal: canal),
    );
    expect(resultado, isNull);
    expect(chamadas, isEmpty);
  });

  test('repassa a recusa do Android sem inventar sucesso', () async {
    final resultado = await AbrirAppComAcao.executar(
      'abre o mapa até a Rua das Flores',
      aparelho: AparelhoService(canal: canal),
    );
    expect(resultado, isNotNull);
    expect(resultado!.ok, isFalse);
    expect(resultado.mensagem, 'O mapa não abriu.');
  });
}
