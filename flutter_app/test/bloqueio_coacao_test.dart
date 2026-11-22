import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/services/bloqueio_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Cofre implements CofreBloqueio {
  final dados = <String, String>{};

  @override
  Future<String?> read(String chave) async => dados[chave];

  @override
  Future<void> write(String chave, String valor) async => dados[chave] = valor;

  @override
  Future<void> delete(String chave) async => dados.remove(chave);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Cofre cofre;
  late BloqueioStore porta;
  final agora = DateTime(2026, 11, 21, 10, 30);

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    cofre = _Cofre();
    porta = BloqueioStore(
      cofre: cofre,
      abrirPreferencias: SharedPreferences.getInstance,
      agora: () => agora,
      random: Random(3),
    );
    await porta.definirPin('2583');
  });

  test('sem coação definida, o PIN principal abre normalmente', () async {
    expect(await porta.temCoacao(), isFalse);
    final resultado = await porta.conferir('2583');
    expect(resultado.ok, isTrue);
    expect(resultado.coacao, isFalse);
  });

  test('PIN de coação abre o modo de visita e não fica em texto', () async {
    final definido = await porta.definirCoacao('2583', '4719');
    expect(definido.ok, isTrue);
    expect(await porta.temCoacao(), isTrue);
    expect(cofre.dados.values.any((v) => v.contains('4719')), isFalse,
        reason: 'o PIN de coação não pode ficar em texto no cofre');

    final visita = await porta.conferir('4719');
    expect(visita.ok, isTrue);
    expect(visita.coacao, isTrue);
    expect((await porta.coacaoUsadaEm()), agora);

    final principal = await porta.conferir('2583');
    expect(principal.ok, isTrue);
    expect(principal.coacao, isFalse);
  });

  test('coação recusa PIN igual ao principal e PIN fraco', () async {
    final igual = await porta.definirCoacao('2583', '2583');
    expect(igual.ok, isFalse);
    expect(igual.mensagem, contains('diferente'));

    final fraco = await porta.definirCoacao('2583', '1234');
    expect(fraco.ok, isFalse);
    expect(await porta.temCoacao(), isFalse);
  });

  test('definir coação exige o PIN principal correto', () async {
    final errado = await porta.definirCoacao('9999', '4719');
    expect(errado.ok, isFalse);
    expect(await porta.temCoacao(), isFalse);
  });

  test('o PIN de coação não serve para trocar nem remover a coação', () async {
    await porta.definirCoacao('2583', '4719');

    final removerComCoacao = await porta.removerCoacao('4719');
    expect(removerComCoacao.ok, isFalse);
    expect(removerComCoacao.mensagem, contains('PIN principal'));
    expect(await porta.temCoacao(), isTrue);

    final remover = await porta.removerCoacao('2583');
    expect(remover.ok, isTrue);
    expect(await porta.temCoacao(), isFalse);
  });

  test('desligar o bloqueio apaga o PIN de coação', () async {
    await porta.definirCoacao('2583', '4719');
    final desligado = await porta.desligar('2583');
    expect(desligado.ok, isTrue);
    expect(await porta.temCoacao(), isFalse);
    expect(cofre.dados.keys.where((k) => k.contains('coacao')), isEmpty);
  });
}
