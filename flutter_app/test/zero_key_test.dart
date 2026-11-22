import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jarvis_nova/services/provider_service.dart';
import 'package:jarvis_nova/services/zero_key_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemorySecrets implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class FakeZeroKey implements ZeroKeyStore {
  FakeZeroKey(this.valor);
  bool valor;

  @override
  Future<bool> ativo() async => valor;

  @override
  Future<void> definir(bool ativo) async {
    valor = ativo;
  }
}

/// Responde com o envelope de conversa e guarda o último pedido.
class CapturingClient extends http.BaseClient {
  CapturingClient(this.status, this.body);
  final int status;
  final String body;
  final requests = <http.Request>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request as http.Request);
    return http.StreamedResponse(
      Stream<List<int>>.value(Uint8List.fromList(utf8.encode(body))),
      status,
      request: request,
    );
  }
}

/// Primeira resposta falha, a segunda entrega um evento SSE.
class FailThenStreamClient extends http.BaseClient {
  final requests = <http.Request>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request as http.Request);
    final falhou = requests.length == 1;
    return http.StreamedResponse(
      Stream<List<int>>.value(Uint8List.fromList(utf8.encode(falhou
          ? '{"error":"indisponível"}'
          : 'data: {"choices":[{"delta":{"content":"OK"}}]}\n\n'))),
      falhou ? 500 : 200,
      request: request,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Zero-Key é o último da prioridade e é o único sem chave', () {
    expect(aiProviders.last.id, 'zerokey');
    expect(aiProviders.last.semChave, isTrue);
    expect(aiProviders.where((p) => p.semChave), hasLength(1));
    expect(aiProviders.last.endpoint,
        'https://text.pollinations.ai/openai/chat/completions');
    expect(aiProviders.last.model, 'openai-fast');
  });

  test('desligado por padrão: não conta como configurado nem é escolhido',
      () async {
    final service = ProviderService(
        secrets: MemorySecrets(),
        client: CapturingClient(200, '{}'),
        zeroKey: FakeZeroKey(false));

    expect(await service.isConfigured('zerokey'), isFalse);
    expect(await service.firstConfiguredProvider(), isNull);

    final teste = await service.testConnection('zerokey');
    expect(teste.ok, isFalse);
    expect(teste.message, contains('desligado'));

    await expectLater(
      service.complete('zerokey', [
        {'role': 'user', 'content': 'oi'},
      ]),
      throwsA(isA<ProviderException>()
          .having((e) => e.message, 'mensagem', contains('desligado'))),
    );
    service.close();
  });

  test('ativado: conversa sem chave e sem cabeçalho Authorization', () async {
    final client =
        CapturingClient(200, '{"choices":[{"message":{"content":"OK"}}]}');
    final zeroKey = FakeZeroKey(true);
    final service = ProviderService(
        secrets: MemorySecrets(), client: client, zeroKey: zeroKey);

    expect(await service.isConfigured('zerokey'), isTrue);
    expect((await service.firstConfiguredProvider())?.id, 'zerokey');

    final texto = await service.complete('zerokey', [
      {'role': 'user', 'content': 'oi'},
    ]);
    expect(texto, 'OK');
    final pedido = client.requests.single;
    expect(pedido.headers.containsKey('Authorization'), isFalse);
    expect(pedido.url.toString(),
        'https://text.pollinations.ai/openai/chat/completions');
    expect(jsonDecode(pedido.body)['model'], 'openai-fast');

    // Nada foi gravado no cofre de chaves.
    expect(await service.isConfigured('groq'), isFalse);
    service.close();
  });

  test('teste de conexão sem chave confirma o modelo público', () async {
    final client =
        CapturingClient(200, '{"choices":[{"message":{"content":"OK"}}]}');
    final service = ProviderService(
        secrets: MemorySecrets(),
        client: client,
        zeroKey: FakeZeroKey(true));

    final resultado = await service.testConnection('zerokey');
    expect(resultado.ok, isTrue);
    expect(resultado.model, 'openai-fast');
    expect(client.requests.single.headers.containsKey('Authorization'),
        isFalse);
    service.close();
  });

  test('402 do serviço público é explicado com o limite, sem culpar a rede',
      () async {
    final service = ProviderService(
        secrets: MemorySecrets(),
        client: CapturingClient(402, '{"error":"limite"}'),
        zeroKey: FakeZeroKey(true));

    final resultado = await service.testConnection('zerokey');
    expect(resultado.ok, isFalse);
    expect(resultado.message, contains('45'));
    expect(resultado.message, isNot(contains('Verifique a conexão')));
    service.close();
  });

  test('provedor sem chave não guarda nem remove chave', () async {
    final service = ProviderService(
        secrets: MemorySecrets(),
        client: CapturingClient(200, '{}'),
        zeroKey: FakeZeroKey(true));

    await expectLater(
        service.saveKey('zerokey', 'chave_qualquer_123'), throwsArgumentError);
    await expectLater(service.removeKey('zerokey'), throwsArgumentError);
    service.close();
  });

  test('streaming só tenta o Zero-Key depois dos provedores com chave',
      () async {
    final secrets = MemorySecrets()..values['groq'] = 'gsk_secret_test';
    final client = FailThenStreamClient();
    final service = ProviderService(
        secrets: secrets, client: client, zeroKey: FakeZeroKey(true));

    final texto = await service
        .streamComplete('groq', [
          {'role': 'user', 'content': 'oi'},
        ])
        .join();
    expect(texto, 'OK');
    expect(client.requests, hasLength(2));
    expect(client.requests.first.headers['Authorization'],
        'Bearer gsk_secret_test');
    expect(client.requests.last.headers.containsKey('Authorization'), isFalse);
    service.close();
  });

  test('consentimento fica nas preferências, desligado por padrão', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferencesZeroKey();

    expect(await store.ativo(), isFalse);
    await store.definir(true);
    expect(await store.ativo(), isTrue);
    expect(chaveZeroKeyAtiva, 'jarvis.zerokey.ativo');
  });
}
