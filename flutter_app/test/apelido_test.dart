import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/services/aparelho_service.dart';
import 'package:jarvis_nova/services/apelido.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const canal = MethodChannel('teste.jarvis.apelido');
  late List<MethodCall> chamadas;

  setUp(() {
    chamadas = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (chamada) async {
      chamadas.add(chamada);
      if (chamada.method == 'apelidos') {
        return {
          'itens': {'murilin': 'murilo', 'aninha': 'ana'},
        };
      }
      if (chamada.arguments['nome'] == 'Zuleica') {
        return {'ok': false, 'mensagem': 'Não achei Zuleica nos contatos.'};
      }
      return {
        'ok': true,
        'mensagem': 'Pronto. Quando você falar Murilin, eu entendo Murilo.',
      };
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);
  });

  test('ensina o apelido mandando apelido, nome e esquecer', () async {
    final resultado = await AprenderApelido.executar(
      'chama o Murilo de Murilin',
      aparelho: AparelhoService(canal: canal),
    );
    expect(resultado, isNotNull);
    expect(resultado!.ok, isTrue);
    expect(resultado.acao, 'apelido de Murilo: Murilin');
    expect(chamadas, hasLength(1));
    expect(chamadas.single.method, 'aprenderApelido');
    expect(chamadas.single.arguments['apelido'], 'Murilin');
    expect(chamadas.single.arguments['nome'], 'Murilo');
    expect(chamadas.single.arguments['esquecer'], isFalse);
  });

  test('manda o pedido de esquecer', () async {
    await AprenderApelido.executar(
      'esquece o apelido Murilin',
      aparelho: AparelhoService(canal: canal),
    );
    expect(chamadas.single.arguments['esquecer'], isTrue);
    expect(chamadas.single.arguments['apelido'], 'Murilin');
  });

  test('devolve null quando a frase não é apelido', () async {
    final resultado = await AprenderApelido.executar(
      'abre a memória',
      aparelho: AparelhoService(canal: canal),
    );
    expect(resultado, isNull);
    expect(chamadas, isEmpty);
  });

  test('repassa a recusa do aparelho sem inventar sucesso', () async {
    final resultado = await AprenderApelido.executar(
      'chama a Zuleica de Zu',
      aparelho: AparelhoService(canal: canal),
    );
    expect(resultado!.ok, isFalse);
    expect(resultado.mensagem, 'Não achei Zuleica nos contatos.');
  });

  test('lê a lista de apelidos aprendidos', () async {
    final lista = await AparelhoService(canal: canal).apelidos();
    expect(lista, {'murilin': 'murilo', 'aninha': 'ana'});
    expect(chamadas.single.method, 'apelidos');
  });
}
