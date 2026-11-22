import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/hotword_portugues.dart';
import 'package:jarvis_nova/services/hotword_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sem nada gravado, vale o conjunto de fábrica', () async {
    final store = HotwordStore();
    expect(await store.carregar(), HotwordPortugues.idsPadrao);
  });

  test('grava a escolha e as linhas tokenizadas para o serviço Android',
      () async {
    final store = HotwordStore();
    final escolhidas = await store.gravar({'jarvis', 'ei-jarvis'});
    expect(escolhidas, {'jarvis', 'ei-jarvis'});
    expect(await store.carregar(), {'jarvis', 'ei-jarvis'});

    final prefs = await SharedPreferences.getInstance();
    final linhas = prefs.getString(chaveHotwordLinhas);
    expect(linhas, '▁JA R VI S\n▁E I ▁JA R VI S');
    expect(prefs.getStringList(chaveHotwordAtivos), ['ei-jarvis', 'jarvis']);
  });

  test('identificador desconhecido nunca chega ao detector', () async {
    final store = HotwordStore();
    await store.gravar({'jarvis', 'inventado'});
    expect(await store.carregar(), {'jarvis'});
  });

  test('lista só com valores desconhecidos cai no padrão', () async {
    SharedPreferences.setMockInitialValues({
      chaveHotwordAtivos: ['inventado', 'outro'],
    });
    expect(await HotwordStore().carregar(), HotwordPortugues.idsPadrao);
  });

  test('restaurar o padrão devolve o conjunto de fábrica', () async {
    final store = HotwordStore();
    await store.gravar({'ei-jarvis', 'ola-jarvis'});
    expect(await store.restaurarPadrao(), HotwordPortugues.idsPadrao);
    expect(await store.carregar(), HotwordPortugues.idsPadrao);
  });
}
