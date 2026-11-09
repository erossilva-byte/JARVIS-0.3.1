import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AiProvider {
  const AiProvider({required this.id, required this.name, required this.endpoint, required this.model});
  final String id;
  final String name;
  final String endpoint;
  final String model;
}

const aiProviders = <AiProvider>[
  AiProvider(id: 'groq', name: 'Groq', endpoint: 'https://api.groq.com/openai/v1/chat/completions', model: 'openai/gpt-oss-20b'),
  AiProvider(id: 'openrouter', name: 'OpenRouter · DeepSeek', endpoint: 'https://openrouter.ai/api/v1/chat/completions', model: 'deepseek/deepseek-chat'),
  AiProvider(id: 'cerebras', name: 'Cerebras', endpoint: 'https://api.cerebras.ai/v1/chat/completions', model: 'gpt-oss-120b'),
  AiProvider(id: 'mistral', name: 'Mistral', endpoint: 'https://api.mistral.ai/v1/chat/completions', model: 'mistral-small-latest'),
  AiProvider(id: 'gemini', name: 'Gemini', endpoint: 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions', model: 'gemini-2.5-flash'),
];

abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PlatformSecretStore implements SecretStore {
  PlatformSecretStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: 'jarvis.ai.$key');

  @override
  Future<void> write(String key, String value) => _storage.write(key: 'jarvis.ai.$key', value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: 'jarvis.ai.$key');
}

class ProviderCheck {
  const ProviderCheck({required this.ok, required this.message, this.model});
  final bool ok;
  final String message;
  final String? model;
}

class ProviderService {
  ProviderService({required SecretStore secrets, http.Client? client})
      : _secrets = secrets,
        _client = client ?? http.Client();

  final SecretStore _secrets;
  final http.Client _client;

  Future<bool> isConfigured(String providerId) async =>
      (await _secrets.read(providerId))?.isNotEmpty ?? false;

  Future<void> saveKey(String providerId, String rawKey) async {
    _provider(providerId);
    final key = rawKey.trim().replaceFirst(RegExp(r'^Bearer\\s+', caseSensitive: false), '');
    if (key.length < 8 || key.length > 512 || key.contains(RegExp(r'\\s'))) {
      throw ArgumentError('A chave informada parece inválida. Confira o valor e tente novamente.');
    }
    await _secrets.write(providerId, key);
  }

  Future<void> removeKey(String providerId) async {
    _provider(providerId);
    await _secrets.delete(providerId);
  }

  Future<ProviderCheck> testConnection(String providerId) async {
    final provider = _provider(providerId);
    final key = await _secrets.read(providerId);
    if (key == null || key.isEmpty) {
      return const ProviderCheck(ok: false, message: 'Cadastre a chave deste provedor antes de testar.');
    }

    try {
      final response = await _client
          .post(
            Uri.parse(provider.endpoint),
            headers: {'Authorization': 'Bearer $key', 'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': provider.model,
              'messages': [
                {'role': 'user', 'content': 'Responda somente: OK'}
              ],
              'max_tokens': 8,
              'temperature': 0,
            }),
          )
          .timeout(const Duration(seconds: 18));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final content = data is Map ? data['choices'] : null;
        if (content is List && content.isNotEmpty) {
          return ProviderCheck(ok: true, message: 'Conexão confirmada; o provedor respondeu.', model: provider.model);
        }
        return const ProviderCheck(ok: false, message: 'O provedor respondeu, mas o formato da resposta não foi reconhecido.');
      }

      // Não repassa o corpo bruto: alguns gateways ecoam metadados que não devem aparecer na UI.
      final message = switch (response.statusCode) {
        401 || 403 => 'A chave foi recusada. Confira a credencial e as permissões da conta.',
        404 => 'O modelo ou endpoint configurado não está disponível neste provedor.',
        429 => 'Limite de requisições atingido. Aguarde e tente novamente.',
        >= 500 => 'O serviço do provedor está instável. Tente novamente mais tarde.',
        _ => 'O provedor recusou o teste (HTTP ${response.statusCode}).',
      };
      return ProviderCheck(ok: false, message: message);
    } on http.ClientException {
      return const ProviderCheck(ok: false, message: 'Não foi possível alcançar o provedor. Verifique a conexão.');
    } on FormatException {
      return const ProviderCheck(ok: false, message: 'O provedor retornou uma resposta inválida.');
    } catch (error) {
      if (error.toString().contains('TimeoutException')) {
        return const ProviderCheck(ok: false, message: 'O teste excedeu 18 segundos e foi interrompido.');
      }
      return const ProviderCheck(ok: false, message: 'Falha inesperada ao testar o provedor.');
    }
  }

  Future<String> complete(String providerId, List<Map<String, String>> messages) async {
    final provider = _provider(providerId);
    final key = await _secrets.read(providerId);
    if (key == null || key.isEmpty) throw StateError('O provedor ${provider.name} não tem chave cadastrada.');

    final response = await _client
        .post(
          Uri.parse(provider.endpoint),
          headers: {'Authorization': 'Bearer $key', 'Content-Type': 'application/json'},
          body: jsonEncode({'model': provider.model, 'messages': messages, 'temperature': 0.4}),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('O provedor ${provider.name} não concluiu a solicitação (HTTP ${response.statusCode}).');
    }
    final data = jsonDecode(response.body);
    final choices = data is Map ? data['choices'] : null;
    final content = choices is List && choices.isNotEmpty && choices.first is Map
        ? choices.first['message']?['content']
        : null;
    if (content is! String || content.trim().isEmpty) {
      throw StateError('O provedor ${provider.name} retornou uma resposta vazia.');
    }
    return content.trim();
  }

  AiProvider _provider(String id) => aiProviders.firstWhere(
        (provider) => provider.id == id,
        orElse: () => throw ArgumentError('Provedor desconhecido.'),
      );

  void close() => _client.close();
}
