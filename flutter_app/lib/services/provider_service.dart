import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../core/sse.dart';
import 'modelo_store.dart';
import 'zero_key_store.dart';

class AiProvider {
  const AiProvider(
      {required this.id,
      required this.name,
      required this.endpoint,
      required this.model,
      this.fallbackModels = const [],
      this.semChave = false});
  final String id;
  final String name;
  final String endpoint;
  final String model;

  /// Não usa chave: fala com um serviço público anônimo. Só entra quando o
  /// usuário liga o Zero-Key em Provedores de IA (ver [ZeroKeyStore]).
  final bool semChave;

  /// Modelos tentados somente quando o principal responde 404 (modelo retirado
  /// para chaves novas). Nunca troca a chave, apenas o identificador do modelo.
  final List<String> fallbackModels;
}

const aiProviders = <AiProvider>[
  AiProvider(
      id: 'groq',
      name: 'Groq',
      endpoint: 'https://api.groq.com/openai/v1/chat/completions',
      model: 'openai/gpt-oss-20b'),
  AiProvider(
      id: 'openrouter',
      name: 'OpenRouter · DeepSeek',
      endpoint: 'https://openrouter.ai/api/v1/chat/completions',
      model: 'deepseek/deepseek-chat'),
  AiProvider(
      id: 'cerebras',
      name: 'Cerebras',
      endpoint: 'https://api.cerebras.ai/v1/chat/completions',
      model: 'gpt-oss-120b'),
  AiProvider(
      id: 'mistral',
      name: 'Mistral',
      endpoint: 'https://api.mistral.ai/v1/chat/completions',
      model: 'mistral-small-2603',
      fallbackModels: ['mistral-small-latest']),
  AiProvider(
      id: 'gemini',
      name: 'Gemini',
      endpoint:
          'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
      model: 'gemini-3.8-flash',
      fallbackModels: [
        'gemini-3.6-flash',
        'gemini-3.5-flash',
        'gemini-2.5-flash',
        'gemini-flash-latest'
      ]),
  provedorSemChave,
];

/// Provedor sem chave (Zero-Key).
///
/// Endpoint Classic aberto da Pollinations, compatível com OpenAI: responde
/// sem cadastro e sem cabeçalho `Authorization`, identificando só o IP. O limite
/// publicado é de uma resposta a cada 45 segundos por IP, sujeito a 402/429/503.
/// Fica **por último** na prioridade de propósito: nunca passa na frente de um
/// provedor com chave do usuário.
const provedorSemChave = AiProvider(
    id: 'zerokey',
    name: 'Zero-Key · Pollinations',
    endpoint: 'https://text.pollinations.ai/openai/chat/completions',
    model: 'openai-fast',
    semChave: true);

abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PlatformSecretStore implements SecretStore {
  PlatformSecretStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: 'jarvis.ai.$key');

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: 'jarvis.ai.$key', value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: 'jarvis.ai.$key');
}

class ProviderCheck {
  const ProviderCheck({required this.ok, required this.message, this.model});
  final bool ok;
  final String message;
  final String? model;
}

/// Modelo que o provedor declarou na lista de `/models`.
class ModeloDoProvedor {
  const ModeloDoProvedor({required this.id, this.nome});
  final String id;
  final String? nome;
}

/// Endereço da lista de modelos de cada provedor.
///
/// Cinco são compatíveis com OpenAI: basta trocar `/chat/completions` por
/// `/models` no mesmo endereço. O Gemini é a exceção: a lista fica na API
/// nativa, não no caminho de compatibilidade (que responde 404).
String urlDeModelos(AiProvider provider) {
  if (provider.id == 'gemini') {
    return 'https://generativelanguage.googleapis.com/v1beta/models';
  }
  final base =
      provider.endpoint.replaceFirst(RegExp(r'/chat/completions$'), '');
  return '$base/models';
}

/// Lê a resposta de `/models` nos dois formatos vistos no campo.
///
/// OpenAI e clones respondem `{"data":[{"id":…}]}`. O Gemini nativo responde
/// `{"models":[{"name":"models/…","supportedGenerationMethods":[…]}]}`, e
/// inclui modelos de embedding que não servem para conversa: esses são
/// descartados.
List<ModeloDoProvedor> lerModelos(String corpo) {
  late final Object? dados;
  try {
    dados = jsonDecode(corpo);
  } on FormatException {
    return const [];
  }
  if (dados is! Map) return const [];
  final abertos = dados['data'];
  final nativos = dados['models'];
  final brutos = abertos is List ? abertos : (nativos is List ? nativos : null);
  if (brutos == null) return const [];
  final vistos = <String>{};
  final lista = <ModeloDoProvedor>[];
  for (final item in brutos) {
    if (item is! Map) continue;
    final metodos = item['supportedGenerationMethods'];
    if (metodos is List && !metodos.contains('generateContent')) continue;
    var id = item['id'] is String ? (item['id'] as String) : '';
    if (id.isEmpty && item['name'] is String) {
      id = (item['name'] as String).replaceFirst(RegExp(r'^models/'), '');
    }
    id = id.trim();
    if (id.isEmpty || id.contains('embedding') || !vistos.add(id)) continue;
    final exibicao = item['displayName'] ?? item['display_name'];
    String? nome;
    if (exibicao is String && exibicao.trim().isNotEmpty) {
      nome = exibicao.trim();
    } else if (item['id'] is String && item['name'] is String) {
      nome = (item['name'] as String).trim();
    }
    lista.add(ModeloDoProvedor(id: id, nome: nome));
  }
  lista.sort((a, b) => a.id.toLowerCase().compareTo(b.id.toLowerCase()));
  return lista;
}

/// Falha já traduzida para a interface. Nunca carrega a chave nem o corpo bruto.
class ProviderException implements Exception {
  const ProviderException(this.message);
  final String message;
  @override
  String toString() => message;
}

const _zerokeyDesligado =
    'O provedor sem chave está desligado. Ative o Zero-Key em Provedores de IA '
    'para usar o serviço público anônimo.';

class ProviderService {
  ProviderService(
      {required SecretStore secrets,
      http.Client? client,
      ZeroKeyStore? zeroKey,
      ModeloStore? modelos})
      : _secrets = secrets,
        _client = client ?? http.Client(),
        _zeroKey = zeroKey ?? PreferencesZeroKey(),
        _modelos = modelos ?? PreferencesModeloStore();

  final SecretStore _secrets;
  final http.Client _client;
  final ZeroKeyStore _zeroKey;
  final ModeloStore _modelos;

  Future<bool> isConfigured(String providerId) async {
    final provider = _provider(providerId);
    if (provider.semChave) return _zeroKey.ativo();
    return (await _secrets.read(providerId))?.isNotEmpty ?? false;
  }

  Future<bool> zeroKeyAtiva() => _zeroKey.ativo();

  Future<void> definirZeroKey(bool ativo) => _zeroKey.definir(ativo);

  /// Modelo escolhido para o provedor, ou `null` quando vale o padrão do app.
  Future<String?> modeloEscolhido(String providerId) async {
    _provider(providerId);
    return _modelos.ler(providerId);
  }

  /// Grava (ou apaga, com `null`) o modelo escolhido para o provedor.
  Future<void> escolherModelo(String providerId, String? modelo) async {
    _provider(providerId);
    final limpo = modelo?.trim() ?? '';
    await _modelos.gravar(providerId, limpo.isEmpty ? null : limpo);
  }

  /// Consulta a lista de modelos do provedor. Só manda a chave, nada de conversa.
  Future<List<ModeloDoProvedor>> descobrirModelos(String providerId) async {
    final provider = _provider(providerId);
    String? key;
    if (provider.semChave) {
      if (!await _zeroKey.ativo()) {
        throw const ProviderException(_zerokeyDesligado);
      }
    } else {
      key = await _secrets.read(providerId);
      if (key == null || key.isEmpty) {
        throw const ProviderException(
            'Cadastre a chave deste provedor antes de ver os modelos.');
      }
    }

    late http.Response resposta;
    try {
      resposta = await _client
          .get(
            Uri.parse(urlDeModelos(provider)),
            headers: provider.id == 'gemini'
                ? {'x-goog-api-key': key ?? ''}
                : _cabecalhos(key),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw ProviderException(
          'A lista de modelos do ${provider.name} demorou mais de 15 segundos.');
    } on http.ClientException {
      throw ProviderException(
          'Não foi possível alcançar ${provider.name} para listar os modelos. Verifique o Wi-Fi/5G.');
    }
    if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
      throw ProviderException(
          _mensagemModelos(provider, resposta.statusCode));
    }
    final lista = lerModelos(resposta.body);
    if (lista.isEmpty) {
      throw ProviderException(
          'O ${provider.name} respondeu sem modelos. O modelo padrão continua valendo.');
    }
    return lista;
  }

  /// Retorna o primeiro provedor configurado respeitando a prioridade oficial.
  /// A ordem de [aiProviders] mantém Groq como principal e OpenRouter como fallback.
  Future<AiProvider?> firstConfiguredProvider() async {
    for (final provider in aiProviders) {
      if (await isConfigured(provider.id)) return provider;
    }
    return null;
  }

  Future<List<AiProvider>> configuredProviders() async {
    final configurados = <AiProvider>[];
    for (final provider in aiProviders) {
      if (await isConfigured(provider.id)) configurados.add(provider);
    }
    return configurados;
  }

  Future<void> saveKey(String providerId, String rawKey) async {
    final provider = _provider(providerId);
    if (provider.semChave) {
      throw ArgumentError(
          'O provedor sem chave não guarda chave. Use a chave do Zero-Key na tela.');
    }
    final key = rawKey
        .trim()
        .replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'''^["']+|["']+$'''), '')
        .trim();
    if (key.length < 8 || key.length > 512 || key.contains(RegExp(r'\s'))) {
      throw ArgumentError(
          'A chave informada parece inválida. Confira o valor e tente novamente.');
    }
    await _secrets.write(providerId, key);
  }

  Future<void> removeKey(String providerId) async {
    final provider = _provider(providerId);
    if (provider.semChave) {
      throw ArgumentError(
          'O provedor sem chave não tem chave para remover. Desligue o Zero-Key na tela.');
    }
    await _secrets.delete(providerId);
  }

  Future<ProviderCheck> testConnection(String providerId) async {
    final provider = _provider(providerId);
    String? key;
    if (provider.semChave) {
      if (!await _zeroKey.ativo()) {
        return const ProviderCheck(ok: false, message: _zerokeyDesligado);
      }
    } else {
      key = await _secrets.read(providerId);
      if (key == null || key.isEmpty) {
        return const ProviderCheck(
            ok: false,
            message: 'Cadastre a chave deste provedor antes de testar.');
      }
    }

    try {
      var status = 0;
      var modeloTestado = provider.model;
      for (final modelo in await _modelosPara(provider)) {
        modeloTestado = modelo;
        final response = await _client
            .post(
              Uri.parse(provider.endpoint),
              headers: _cabecalhos(key),
              body: jsonEncode({
                'model': modelo,
                'messages': [
                  {'role': 'user', 'content': 'Responda somente: OK'}
                ],
                'max_tokens': 8,
                'temperature': 0,
              }),
            )
            .timeout(const Duration(seconds: 18));
        status = response.statusCode;

        if (status >= 200 && status < 300) {
          final data = jsonDecode(response.body);
          final content = data is Map ? data['choices'] : null;
          if (content is List && content.isNotEmpty) {
            return ProviderCheck(
                ok: true,
                message: 'Conexão confirmada; o provedor respondeu.',
                model: modelo);
          }
          return const ProviderCheck(
              ok: false,
              message:
                  'O provedor respondeu, mas o formato da resposta não foi reconhecido.');
        }

        // Só 404 indica modelo retirado; 401/403/429 não melhoram trocando o nome.
        if (status != 404) break;
      }

      // Não repassa o corpo bruto: alguns gateways ecoam metadados que não devem aparecer na UI.
      final message = switch (status) {
        402 when provider.semChave =>
          'O serviço público sem chave está no limite: uma resposta a cada 45 segundos por IP. Aguarde e teste de novo.',
        429 when provider.semChave =>
          'O serviço público sem chave está sem cota agora. Tente mais tarde ou cadastre a chave de outro provedor.',
        401 ||
        403 when provider.semChave =>
          'O serviço público sem chave recusou a chamada anônima. Tente novamente mais tarde.',
        401 ||
        403 =>
          'A chave foi recusada. Confira a credencial e as permissões da conta.',
        404 =>
          'O modelo $modeloTestado não está disponível para esta chave. Atualize o app ou escolha outro provedor.',
        429 =>
          'A chave foi aceita, mas a conta está sem cota ou no limite de requisições. Aguarde ou ative o faturamento; não é preciso trocar a chave.',
        >= 500 =>
          'O serviço do provedor está instável. Tente novamente mais tarde.',
        _ => 'O provedor recusou o teste (HTTP $status).',
      };
      return ProviderCheck(ok: false, message: message);
    } on http.ClientException {
      return const ProviderCheck(
          ok: false,
          message:
              'Não foi possível alcançar o provedor. Verifique a conexão.');
    } on FormatException {
      return const ProviderCheck(
          ok: false, message: 'O provedor retornou uma resposta inválida.');
    } catch (error) {
      if (error is TimeoutException) {
        return const ProviderCheck(
            ok: false,
            message: 'O teste excedeu 18 segundos e foi interrompido.');
      }
      return const ProviderCheck(
          ok: false, message: 'Falha inesperada ao testar o provedor.');
    }
  }

  Future<String> complete(
      String providerId, List<Map<String, String>> messages) async {
    final provider = _provider(providerId);
    final key = await _chaveDe(provider);

    late http.Response response;
    var modelo = provider.model;
    try {
      final modelos = await _modelosPara(provider);
      for (var i = 0; i < modelos.length; i++) {
        modelo = modelos[i];
        response = await _client
            .post(
              Uri.parse(provider.endpoint),
              headers: _cabecalhos(key),
              body: jsonEncode(
                  {'model': modelo, 'messages': messages, 'temperature': 0.4}),
            )
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 404 || i == modelos.length - 1) break;
      }
    } on TimeoutException {
      throw ProviderException(
          'O provedor ${provider.name} demorou mais de 30 segundos. Tente novamente.');
    } on http.ClientException {
      throw ProviderException(
          'Não foi possível alcançar ${provider.name}. Verifique o Wi-Fi/5G e tente de novo.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ProviderException(
          _mensagemHttp(provider, response.statusCode, modelo));
    }
    final data = jsonDecode(response.body);
    final choices = data is Map ? data['choices'] : null;
    final firstChoice =
        choices is List && choices.isNotEmpty ? choices.first : null;
    final message = firstChoice is Map ? firstChoice['message'] : null;
    final content = message is Map ? message['content'] : null;
    if (content is! String || content.trim().isEmpty) {
      throw ProviderException(
          'O provedor ${provider.name} retornou uma resposta vazia.');
    }
    return content.trim();
  }

  /// Cabeçalhos da chamada. No provedor sem chave não existe `Authorization`:
  /// o serviço público responde à chamada anônima.
  Map<String, String> _cabecalhos(String? chave, {bool streaming = false}) => {
        if (chave != null && chave.isNotEmpty)
          'Authorization': 'Bearer $chave',
        'Content-Type': 'application/json',
        if (streaming) 'Accept': 'text/event-stream',
      };

  /// Chave a enviar, ou `null` no provedor sem chave (com consentimento).
  Future<String?> _chaveDe(AiProvider provider) async {
    if (provider.semChave) {
      if (!await _zeroKey.ativo()) {
        throw const ProviderException(_zerokeyDesligado);
      }
      return null;
    }
    final key = await _secrets.read(provider.id);
    if (key == null || key.isEmpty) {
      throw ProviderException(
          'O provedor ${provider.name} não tem chave cadastrada.');
    }
    return key;
  }

  String _mensagemHttp(AiProvider provider, int status, [String? modelo]) {
    if (provider.semChave) {
      return switch (status) {
        402 =>
          'O serviço público sem chave está no limite (uma resposta a cada 45 s por IP). Aguarde e tente de novo.',
        429 =>
          'O serviço público sem chave está sem cota agora. Tente mais tarde ou use um provedor com chave.',
        503 =>
          'O serviço público sem chave está no limite neste momento. Tente em alguns segundos.',
        404 =>
          'O modelo ${modelo ?? provider.model} do serviço sem chave não está disponível agora.',
        >= 500 =>
          'O serviço público sem chave está instável. Tente novamente mais tarde.',
        _ => 'O provedor sem chave não concluiu a solicitação (HTTP $status).',
      };
    }
    return switch (status) {
        401 ||
        403 =>
          'A chave do ${provider.name} foi recusada. Confira a credencial em Provedores de IA.',
        404 =>
          'O modelo ${modelo ?? provider.model} do ${provider.name} não está disponível para esta chave.',
        429 =>
          'A conta do ${provider.name} está sem cota ou no limite de requisições. Aguarde ou ative o faturamento.',
        >= 500 =>
          'O serviço do ${provider.name} está instável. Tente novamente mais tarde.',
        _ => 'O ${provider.name} não concluiu a solicitação (HTTP $status).',
      };
  }

  /// Resposta em streaming: emite cada fragmento assim que o provedor manda.
  ///
  /// Cancelar a assinatura interrompe a leitura e libera a conexão — é o que o botão de parar
  /// usa. Provedor que ignora `stream` responde pelo envelope normal e o parser ainda entrega o
  /// texto (o chamador decide se cai para [complete] quando nada chega).
  Stream<String> streamComplete(
      String providerId, List<Map<String, String>> messages) async* {
    final preferido = _provider(providerId);
    final ordem = [
      preferido,
      ...aiProviders.where((p) => p.id != preferido.id)
    ];
    Object? ultimoErro;
    for (final provider in ordem) {
      String? key;
      if (provider.semChave) {
        if (!await _zeroKey.ativo()) continue;
      } else {
        key = await _secrets.read(provider.id);
        if (key == null || key.isEmpty) continue;
      }
      var entregouTexto = false;
      try {
        await for (final texto in _streamProvider(provider, key, messages)) {
          entregouTexto = true;
          yield texto;
        }
        return;
      } catch (erro) {
        ultimoErro = erro;
        // Depois do primeiro token não dá para trocar de provedor sem duplicar
        // a resposta na tela; nesse caso a falha sobe para o chamador.
        if (entregouTexto) rethrow;
      }
    }
    if (ultimoErro != null) throw ultimoErro;
    throw const ProviderException(
        'Nenhum provedor configurado. Cadastre uma chave em Provedores de IA ou ative o Zero-Key.');
  }

  Stream<String> _streamProvider(
    AiProvider provider,
    String? key,
    List<Map<String, String>> messages,
  ) async* {
    late http.StreamedResponse resposta;
    var modelo = provider.model;
    try {
      final modelos = await _modelosPara(provider);
      for (var i = 0; i < modelos.length; i++) {
        modelo = modelos[i];
        final requisicao = http.Request('POST', Uri.parse(provider.endpoint))
          ..headers.addAll(_cabecalhos(key, streaming: true))
          ..body = jsonEncode({
            'model': modelo,
            'messages': messages,
            'temperature': 0.4,
            'stream': true,
          });
        resposta =
            await _client.send(requisicao).timeout(const Duration(seconds: 30));
        if (resposta.statusCode != 404 || i == modelos.length - 1) break;
        await resposta.stream.drain<void>();
      }
    } on TimeoutException {
      throw ProviderException(
          'O provedor ${provider.name} demorou mais de 30 segundos. Tente novamente.');
    } on http.ClientException {
      throw ProviderException(
          'Não foi possível alcançar ${provider.name}. Verifique o Wi-Fi/5G e tente de novo.');
    }
    if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
      throw ProviderException(
          _mensagemHttp(provider, resposta.statusCode, modelo));
    }
    final parser = SseParser();
    await for (final pedaco in resposta.stream.transform(utf8.decoder)) {
      for (final texto in parser.alimentar(pedaco)) {
        yield texto;
      }
    }
  }

  /// Modelos tentados em ordem: o escolhido (se houver), o padrão do app e as
  /// reservas do código. Um modelo escolhido que foi retirado cai para o padrão
  /// em vez de deixar o provedor inutilizável.
  Future<List<String>> _modelosPara(AiProvider provider) async {
    final escolhido = await _modelos.ler(provider.id);
    final lista = [
      if (escolhido != null && escolhido.isNotEmpty) escolhido,
      provider.model,
      ...provider.fallbackModels,
    ];
    final vistos = <String>{};
    return [for (final modelo in lista) if (vistos.add(modelo)) modelo];
  }

  String _mensagemModelos(AiProvider provider, int status) =>
      switch (status) {
        401 ||
        403 =>
          'A chave do ${provider.name} foi recusada ao listar os modelos. Confira a credencial.',
        404 =>
          'O ${provider.name} não expõe a lista de modelos neste endereço. O modelo padrão continua valendo.',
        429 =>
          'O ${provider.name} está no limite de requisições agora; a lista de modelos não pôde ser lida.',
        >= 500 =>
          'O serviço do ${provider.name} está instável; a lista de modelos não pôde ser lida.',
        _ =>
          'O ${provider.name} recusou a lista de modelos (HTTP $status). O modelo padrão continua valendo.',
      };

  AiProvider _provider(String id) => aiProviders.firstWhere(
        (provider) => provider.id == id,
        orElse: () => throw ArgumentError('Provedor desconhecido.'),
      );

  void close() => _client.close();
}
