import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/services/kws_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methods = MethodChannel('test.jarvis/kws');
  const events = EventChannel('test.jarvis/kws/events');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(methods, null);
  });

  test('não declara KWS ativo quando o plugin nativo não existe', () async {
    final bridge = JarvisKwsBridge(methods: methods, events: events);
    final status = await bridge.status();
    expect(status.available, isFalse);
    expect(status.listening, isFalse);
    expect(status.detail, contains('não conectado'));
  });

  test('interpreta o estado real retornado pelo plugin', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(methods, (call) async {
        expect(call.method, 'status');
        return {
          'available': true,
          'listening': true,
          'engine': 'sherpa-onnx-kws',
          'detail': 'AudioRecord ativo',
        };
      });
    final bridge = JarvisKwsBridge(methods: methods, events: events);
    final status = await bridge.status();
    expect(status.available, isTrue);
    expect(status.listening, isTrue);
    expect(status.engine, 'sherpa-onnx-kws');
  });

  test('limita janela do teste KWS entre 10 e 60 segundos', () async {
    int? receivedSeconds;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(methods, (call) async {
        receivedSeconds = (call.arguments as Map)['seconds'] as int;
        return {
          'available': true,
          'listening': true,
          'engine': 'sherpa-onnx-kws',
        };
      });
    final bridge = JarvisKwsBridge(methods: methods, events: events);
    await bridge.startTest(seconds: 120);
    expect(receivedSeconds, 60);
  });
}
