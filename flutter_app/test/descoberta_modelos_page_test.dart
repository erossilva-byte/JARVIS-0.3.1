import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jarvis_nova/provider_settings_page.dart';
import 'package:jarvis_nova/services/modelo_store.dart';
import 'package:jarvis_nova/services/provider_service.dart';
import 'package:jarvis_nova/services/zero_key_store.dart';
import 'package:material_ui/material_ui.dart';

class MemorySecrets implements SecretStore {
  final values = <String, String>{'groq': 'gsk_secret_test'};
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
  @override
  Future<bool> ativo() async => false;
  @override
  Future<void> definir(bool ativo) async {}
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

class ListaClient extends http.BaseClient {
  ListaClient(this.corpoModelos);
  final String corpoModelos;
  final chamadas = <http.Request>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final pedido = request as http.Request;
    chamadas.add(pedido);
    final corpo = pedido.method == 'GET'
        ? corpoModelos
        : '{"choices":[{"message":{"content":"OK"}}]}';
    return http.StreamedResponse(
        Stream<List<int>>.value(Uint8List.fromList(utf8.encode(corpo))), 200,
        request: request);
  }
}

Future<void> abrir(WidgetTester tester, MemoryModelos modelos) async {
  tester.view.physicalSize = const Size(430, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
      home: ProviderSettingsPage(
          service: ProviderService(
              secrets: MemorySecrets(),
              client: ListaClient('{"data":['
                  '{"id":"alpha-model","name":"Alpha Model"},'
                  '{"id":"beta-model"},'
                  '{"id":"gamma-model"}]}'),
              zeroKey: FakeZeroKey(),
              modelos: modelos))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mostra o modelo em uso e lista o que o provedor devolveu',
      (tester) async {
    final modelos = MemoryModelos();
    await abrir(tester, modelos);

    expect(find.byKey(const ValueKey('modelo-atual-groq')), findsOneWidget);
    expect(find.textContaining('(padrão do app)'), findsWidgets);

    final botao = find.byKey(const ValueKey('modelos-groq'));
    await tester.ensureVisible(botao);
    await tester.tap(botao);
    await tester.pumpAndSettle();

    expect(find.text('Modelos do Groq'), findsOneWidget);
    expect(find.byKey(const ValueKey('modelo-alpha-model')), findsOneWidget);
    expect(find.byKey(const ValueKey('modelo-padrao')), findsOneWidget);
    expect(find.textContaining('não garante'), findsOneWidget);
  });

  testWidgets('filtra a lista e guarda o modelo escolhido', (tester) async {
    final modelos = MemoryModelos();
    await abrir(tester, modelos);

    final botao = find.byKey(const ValueKey('modelos-groq'));
    await tester.ensureVisible(botao);
    await tester.tap(botao);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('modelos-busca')), 'beta');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('modelo-beta-model')), findsOneWidget);
    expect(find.byKey(const ValueKey('modelo-alpha-model')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('modelo-beta-model')));
    await tester.pumpAndSettle();

    expect(modelos.values['groq'], 'beta-model');
    expect(find.textContaining('Modelo escolhido: beta-model'), findsOneWidget);
    expect(find.textContaining('beta-model (escolhido)'), findsOneWidget);
    expect(find.byKey(const ValueKey('modelos-groq')), findsOneWidget);
  });

  testWidgets('sem consentimento, o Zero-Key não oferece a lista',
      (tester) async {
    final modelos = MemoryModelos();
    await abrir(tester, modelos);

    final botao = find.byKey(const ValueKey('modelos-zerokey'));
    await tester.ensureVisible(botao);
    expect(tester.widget<OutlinedButton>(botao).onPressed, isNull);
  });
}
