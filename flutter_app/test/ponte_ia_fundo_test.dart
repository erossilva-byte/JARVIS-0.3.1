import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/services/ponte_ia_fundo.dart';
import 'package:jarvis_nova/services/provider_service.dart';

class _SemChave implements SecretStore {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sem chave cadastrada, a ponte avisa sem_provedor ao serviço', () async {
    final servico = ProviderService(secrets: _SemChave());
    await expectLater(
      PonteIaFundo.responderPergunta('como está tudo, Jarvis?',
          servico: servico),
      throwsA(isA<PlatformException>()
          .having((erro) => erro.code, 'código', 'sem_provedor')),
    );
  });
}
