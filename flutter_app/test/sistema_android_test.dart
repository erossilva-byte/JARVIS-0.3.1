import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/services/sistema_android.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final canal = SistemaAndroid.canal;
  final chamadas = <MethodCall>[];
  Object? respostaPendente;

  setUp(() {
    chamadas.clear();
    respostaPendente = null;
    SistemaAndroid.reiniciarParaTeste();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(canal, (chamada) async {
      chamadas.add(chamada);
      if (chamada.method == 'intencaoPendente') return respostaPendente;
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(canal, null);
    SistemaAndroid.reiniciarParaTeste();
  });

  test('consome a intenção que abriu o app', () async {
    respostaPendente = {'acao': 'voz', 'texto': ''};
    final recebidas = <IntencaoSistema>[];
    final assinatura = SistemaAndroid.intencoes.listen(recebidas.add);

    await SistemaAndroid.iniciar();
    await Future<void>.delayed(Duration.zero);

    expect(recebidas, hasLength(1));
    expect(recebidas.single.abrirVoz, isTrue);
    expect(chamadas.first.method, 'intencaoPendente');
    await assinatura.cancel();
  });

  test('recebe compartilhamento com o app aberto', () async {
    final recebidas = <IntencaoSistema>[];
    final assinatura = SistemaAndroid.intencoes.listen(recebidas.add);
    await SistemaAndroid.iniciar();

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      canal.name,
      const StandardMethodCodec().encodeMethodCall(const MethodCall('intencao', {
        'acao': 'compartilhar',
        'texto': 'motor 220 V com folga',
      })),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);

    expect(recebidas.single.textoCompartilhado, isTrue);
    expect(recebidas.single.texto, 'motor 220 V com folga');
    await assinatura.cancel();
  });

  test('atalho de histórico e de conversa chegam como ações distintas', () async {
    final recebidas = <IntencaoSistema>[];
    final assinatura = SistemaAndroid.intencoes.listen(recebidas.add);
    await SistemaAndroid.iniciar();

    for (final acao in ['historico', 'conversa']) {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        canal.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall('intencao', {'acao': acao, 'texto': ''})),
        (_) {},
      );
    }
    await Future<void>.delayed(Duration.zero);

    expect(recebidas.map((i) => i.acao).toList(), ['historico', 'conversa']);
    expect(recebidas.first.abrirHistorico, isTrue);
    expect(recebidas.last.abrirConversa, isTrue);
    await assinatura.cancel();
  });

  test('compartilhar envia o texto pelo canal', () async {
    await SistemaAndroid.iniciar();
    chamadas.clear();

    final enviado = await SistemaAndroid.compartilhar('resumo da conversa');

    expect(enviado, isTrue);
    expect(chamadas.single.method, 'compartilhar');
    expect(chamadas.single.arguments, {'texto': 'resumo da conversa'});
  });

  test('texto vazio não chama o sistema', () async {
    await SistemaAndroid.iniciar();
    chamadas.clear();

    expect(await SistemaAndroid.compartilhar('   '), isFalse);
    expect(chamadas, isEmpty);
  });

  test('widget recebe o texto de estado', () async {
    await SistemaAndroid.iniciar();
    chamadas.clear();

    await SistemaAndroid.atualizarWidget('KWS ESCUTANDO');

    expect(chamadas.single.method, 'atualizarWidget');
    expect(chamadas.single.arguments, {'texto': 'KWS ESCUTANDO'});
  });

  test('intenção desconhecida é ignorada', () async {
    final recebidas = <IntencaoSistema>[];
    final assinatura = SistemaAndroid.intencoes.listen(recebidas.add);
    await SistemaAndroid.iniciar();

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      canal.name,
      const StandardMethodCodec().encodeMethodCall(const MethodCall('intencao', {'acao': ''})),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);

    expect(recebidas, isEmpty);
    await assinatura.cancel();
  });
}
