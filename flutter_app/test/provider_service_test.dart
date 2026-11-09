import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jarvis_nova/services/provider_service.dart';

class MemorySecrets implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async { values[key] = value; }
  @override
  Future<void> delete(String key) async { values.remove(key); }
}

class FakeClient extends http.BaseClient {
  FakeClient(this.status, this.body);
  final int status;
  final String body;
  http.Request? lastRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request as http.Request;
    return http.StreamedResponse(
      Stream<List<int>>.value(Uint8List.fromList(utf8.encode(body))),
      status,
      request: request,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('salva chave normalizada e não a devolve para a interface', () async {
    final secrets = MemorySecrets();
    final service = ProviderService(secrets: secrets, client: FakeClient(200, '{"choices":[{"message":{"content":"OK"}}]}'));

    await service.saveKey('groq', 'Bearer gsk_test_12345678');
    expect(secrets.values['groq'], 'gsk_test_12345678');
    expect(await service.isConfigured('groq'), isTrue);
    await service.removeKey('groq');
    expect(await service.isConfigured('groq'), isFalse);
    service.close();
  });

  test('rejeita chave vazia, curta ou com espaços e provedor desconhecido', () async {
    final service = ProviderService(secrets: MemorySecrets(), client: FakeClient(200, '{}'));
    await expectLater(service.saveKey('groq', '   '), throwsArgumentError);
    await expectLater(service.saveKey('groq', 'short'), throwsArgumentError);
    await expectLater(service.saveKey('groq', 'invalid key 12345'), throwsArgumentError);
    await expectLater(service.saveKey('unknown', '123456789'), throwsArgumentError);
    service.close();
  });

  test('testa endpoint real e envia a chave apenas no cabeçalho', () async {
    final secrets = MemorySecrets()..values['groq'] = 'gsk_secret_test';
    final client = FakeClient(200, '{"choices":[{"message":{"content":"OK"}}]}');
    final service = ProviderService(secrets: secrets, client: client);

    final result = await service.testConnection('groq');
    expect(result.ok, isTrue);
    expect(result.model, 'openai/gpt-oss-20b');
    expect(client.lastRequest!.headers['Authorization'], 'Bearer gsk_secret_test');
    expect(client.lastRequest!.url.toString(), aiProviders.first.endpoint);
    expect(client.lastRequest!.body, contains('"max_tokens":8'));
    service.close();
  });

  test('não revela corpo de erro nem chave quando o provedor recusa', () async {
    final secrets = MemorySecrets()..values['mistral'] = 'sk_secret_test';
    final service = ProviderService(secrets: secrets, client: FakeClient(401, '{"error":"sk_secret_test invalid"}'));

    final result = await service.testConnection('mistral');
    expect(result.ok, isFalse);
    expect(result.message, contains('chave foi recusada'));
    expect(result.message, isNot(contains('sk_secret_test')));
    service.close();
  });

  test('não tenta rede quando não há chave cadastrada', () async {
    final service = ProviderService(secrets: MemorySecrets(), client: FakeClient(200, '{}'));
    final result = await service.testConnection('gemini');
    expect(result.ok, isFalse);
    expect(result.message, contains('Cadastre a chave'));
    service.close();
  });
}
