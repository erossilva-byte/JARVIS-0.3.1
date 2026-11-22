import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jarvis_nova/provider_settings_page.dart';
import 'package:jarvis_nova/services/provider_service.dart';
import 'package:jarvis_nova/services/zero_key_store.dart';
import 'package:material_ui/material_ui.dart';

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

class EmptyClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
          Stream<List<int>>.value(Uint8List.fromList(utf8.encode('{}'))), 200,
          request: request);
}

Future<void> abrir(WidgetTester tester, FakeZeroKey zeroKey) async {
  tester.view.physicalSize = const Size(430, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
      home: ProviderSettingsPage(
          service: ProviderService(
              secrets: MemorySecrets(),
              client: EmptyClient(),
              zeroKey: zeroKey))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Zero-Key aparece desligado e diz o que sai do aparelho',
      (tester) async {
    await abrir(tester, FakeZeroKey(false));

    final chave = find.byKey(const ValueKey('zerokey-ativar'));
    expect(chave, findsOneWidget);
    expect(tester.widget<Switch>(chave).value, isFalse);
    expect(find.text('Zero-Key · Pollinations'), findsOneWidget);
    expect(find.textContaining('45 segundos'), findsOneWidget);
    expect(find.textContaining('pelo IP'), findsOneWidget);
    // No Zero-Key não existe campo para colar chave.
    expect(find.text('Salvar chave'), findsNWidgets(5));
  });

  testWidgets('ligar o Zero-Key grava o consentimento e muda o estado',
      (tester) async {
    final zeroKey = FakeZeroKey(false);
    await abrir(tester, zeroKey);

    final chave = find.byKey(const ValueKey('zerokey-ativar'));
    await tester.ensureVisible(chave);
    await tester.tap(chave);
    await tester.pumpAndSettle();

    expect(zeroKey.valor, isTrue);
    expect(tester.widget<Switch>(chave).value, isTrue);
    expect(find.textContaining('Zero-Key ativado'), findsOneWidget);
  });
}
