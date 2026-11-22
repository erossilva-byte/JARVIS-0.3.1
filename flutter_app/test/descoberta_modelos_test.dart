import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jarvis_nova/services/modelo_store.dart';
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

class MemoryModelos implements ModeloStore {
  final values = <String, String>{};
  @override
  Future<String?> ler(String providerId) async => values[providerId];
  @override
  Future<void> gravar(String providerId, String? modelo) async {
    if (modelo == null) {
      values.remove(providerId);
    } else {
      values[providerId] = modelo;
    }
  }
}

/// Atende GET (lista de modelos) e POST (conversa), guardando tudo.
class RoteadorClient extends http.BaseClient {
  RoteadorClient({
    this.statusModelos = 200,
    this.corpoModelos = '{"data":[{"id":"modelo-a"},{"id":"modelo-b"}]}',
    this.corpoChat = '{"choices":[{"message":{"content":"OK"}}]}',
    this.statusPrimeiroChat,
  });

  final int statusModelos;
  final String corpoModelos;
  final String corpoChat;
  final int? statusPrimeiroChat;
  final requests = <http.Request>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final pedido = request as http.Request;
    requests.add(pedido);
    if (pedido.method == 'GET') {
      return _resposta(statusModelos,
          statusModelos == 200 ? corpoModelos : '{"error":"segredo-nao-vaza"}');
    }
    final primeiro =
        requests.where((r) => r.method == 'POST').length == 1;
    final status =
        primeiro && statusPrimeiroChat != null ? statusPrimeiroChat! : 200;
    return _resposta(status, status == 200 ? corpoChat : '{"error":"404"}');
  }

  http.StreamedResponse _resposta(int status, String corpo) =>
      http.StreamedResponse(
          Stream<List<int>>.value(Uint8List.fromList(utf8.encode(corpo))),
          status,
          request: http.Request('GET', Uri.parse('https://exemplo.test')));

  http.Request get ultimoPost =>
      requests.lastWhere((r) => r.method == 'POST');
}

ProviderService servico({
  MemorySecrets? secrets,
  RoteadorClient? client,
  FakeZeroKey? zeroKey,
  MemoryModelos? modelos,
}) =>
    ProviderService(
        secrets: secrets ?? MemorySecrets(),
        client: client ?? RoteadorClient(),
        zeroKey: zeroKey ?? FakeZeroKey(false),
        modelos: modelos ?? MemoryModelos());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('endereço de /models é derivado do endpoint de conversa', () {
    expect(urlDeModelos(aiProviders.first),
        'https://api.groq.com/openai/v1/models');
    expect(urlDeModelos(aiProviders[1]),
        'https://openrouter.ai/api/v1/models');
    expect(urlDeModelos(provedorSemChave),
        'https://text.pollinations.ai/openai/models');
    expect(urlDeModelos(aiProviders[4]),
        'https://generativelanguage.googleapis.com/v1beta/models');
  });

  test('lê a lista do formato OpenAI, sem duplicar e com nome', () {
    const corpo = '{"data":[{"id":"b-model"},{"id":"a-model","name":"A Model"},'
        '{"id":"a-model"}]}';
    final lista = lerModelos(corpo);
    expect(lista.map((m) => m.id), ['a-model', 'b-model']);
    expect(lista.first.nome, 'A Model');
  });

  test('lê a lista nativa do Gemini e descarta embedding', () {
    const corpo = '{"models":['
        '{"name":"models/gemini-3.8-flash","displayName":"Gemini 3.8 Flash",'
        '"supportedGenerationMethods":["generateContent","countTokens"]},'
        '{"name":"models/text-embedding-004",'
        '"supportedGenerationMethods":["embedContent"]}]}';
    final lista = lerModelos(corpo);
    expect(lista, hasLength(1));
    expect(lista.single.id, 'gemini-3.8-flash');
    expect(lista.single.nome, 'Gemini 3.8 Flash');
  });

  test('resposta inválida não vira lista inventada', () {
    expect(lerModelos('<html>'), isEmpty);
    expect(lerModelos('{"data":"nada"}'), isEmpty);
  });

  test('descoberta manda a chave e nada da conversa', () async {
    final secrets = MemorySecrets()..values['groq'] = 'gsk_secret_test';
    final client = RoteadorClient(
        corpoModelos: '{"data":[{"id":"openai/gpt-oss-20b"},'
            '{"id":"llama-3.3-70b-versatile"}]}');
    final service = servico(secrets: secrets, client: client);

    final lista = await service.descobrirModelos('groq');
    expect(lista.map((m) => m.id),
        ['llama-3.3-70b-versatile', 'openai/gpt-oss-20b']);
    final pedido = client.requests.single;
    expect(pedido.method, 'GET');
    expect(pedido.url.toString(), 'https://api.groq.com/openai/v1/models');
    expect(pedido.headers['Authorization'], 'Bearer gsk_secret_test');
    expect(pedido.body, isEmpty);
    service.close();
  });

  test('Gemini lista pelo endereço nativo com x-goog-api-key', () async {
    final secrets = MemorySecrets()..values['gemini'] = 'gem_secret_test';
    final client = RoteadorClient(
        corpoModelos: '{"models":[{"name":"models/gemini-3.8-flash",'
            '"supportedGenerationMethods":["generateContent"]}]}');
    final service = servico(secrets: secrets, client: client);

    final lista = await service.descobrirModelos('gemini');
    expect(lista.single.id, 'gemini-3.8-flash');
    final pedido = client.requests.single;
    expect(pedido.headers['x-goog-api-key'], 'gem_secret_test');
    expect(pedido.headers.containsKey('Authorization'), isFalse);
    service.close();
  });

  test('Zero-Key lista modelos só com consentimento e sem Authorization',
      () async {
    final client = RoteadorClient(
        corpoModelos: '{"data":[{"id":"openai-fast"}]}');
    final bloqueado = servico(client: client, zeroKey: FakeZeroKey(false));
    await expectLater(
        bloqueado.descobrirModelos('zerokey'),
        throwsA(isA<ProviderException>()
            .having((e) => e.message, 'mensagem', contains('desligado'))));
    bloqueado.close();

    final liberado = servico(client: client, zeroKey: FakeZeroKey(true));
    final lista = await liberado.descobrirModelos('zerokey');
    expect(lista.single.id, 'openai-fast');
    final pedido = client.requests.last;
    expect(pedido.headers.containsKey('Authorization'), isFalse);
    liberado.close();
  });

  test('falha ao listar é explicada sem repetir o corpo do provedor', () async {
    final secrets = MemorySecrets()..values['groq'] = 'gsk_secret_test';
    final service = servico(
        secrets: secrets, client: RoteadorClient(statusModelos: 401));

    await expectLater(
        service.descobrirModelos('groq'),
        throwsA(isA<ProviderException>().having(
            (e) => e.message,
            'mensagem',
            allOf(contains('recusada'), isNot(contains('segredo-nao-vaza'))))));
    service.close();
  });

  test('sem chave, a descoberta nem chama a rede', () async {
    final client = RoteadorClient();
    final service = servico(client: client);

    await expectLater(
        service.descobrirModelos('groq'),
        throwsA(isA<ProviderException>()
            .having((e) => e.message, 'mensagem', contains('Cadastre a chave'))));
    expect(client.requests, isEmpty);
    service.close();
  });

  test('modelo escolhido passa a ser o primeiro tentado na conversa',
      () async {
    final secrets = MemorySecrets()..values['groq'] = 'gsk_secret_test';
    final modelos = MemoryModelos()..values['groq'] = 'llama-3.3-70b-versatile';
    final client = RoteadorClient();
    final service =
        servico(secrets: secrets, client: client, modelos: modelos);

    await service.complete('groq', [
      {'role': 'user', 'content': 'oi'},
    ]);
    expect(jsonDecode(client.ultimoPost.body)['model'],
        'llama-3.3-70b-versatile');

    await service.escolherModelo('groq', null);
    await service.complete('groq', [
      {'role': 'user', 'content': 'oi'},
    ]);
    expect(jsonDecode(client.ultimoPost.body)['model'],
        aiProviders.first.model);
    service.close();
  });

  test('modelo escolhido que foi retirado cai para o padrão', () async {
    final secrets = MemorySecrets()..values['groq'] = 'gsk_secret_test';
    final modelos = MemoryModelos()..values['groq'] = 'modelo-aposentado';
    final client = RoteadorClient(statusPrimeiroChat: 404);
    final service =
        servico(secrets: secrets, client: client, modelos: modelos);

    final texto = await service.complete('groq', [
      {'role': 'user', 'content': 'oi'},
    ]);
    expect(texto, 'OK');
    final enviados = [
      for (final r in client.requests.where((r) => r.method == 'POST'))
        jsonDecode(r.body)['model'],
    ];
    expect(enviados, ['modelo-aposentado', aiProviders.first.model]);
    service.close();
  });

  test('escolha fica nas preferências e apagar volta ao padrão', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferencesModeloStore();

    expect(await store.ler('groq'), isNull);
    await store.gravar('groq', '  modelo-x  ');
    expect(await store.ler('groq'), 'modelo-x');
    expect(chaveModeloDe('groq'), 'jarvis.ai.modelo.groq');
    await store.gravar('groq', null);
    expect(await store.ler('groq'), isNull);
  });
}
