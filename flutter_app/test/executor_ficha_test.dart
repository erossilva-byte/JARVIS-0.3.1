import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/services/executor_app.dart';
import 'package:jarvis_nova/services/pessoas_store.dart';

class MemoriaSegura implements ArmazenamentoSeguro {
  final Map<String, String> dados = {};

  @override
  Future<String?> ler(String chave) async => dados[chave];

  @override
  Future<void> gravar(String chave, String valor) async => dados[chave] = valor;

  @override
  Future<void> apagar(String chave) async => dados.remove(chave);
}

const _pedido = 'Jarvis, crie a ficha de Murilo, que tem 16 anos, seu apelido '
    'é Murilin e ele é meu melhor amigo';

PessoasStore _store() =>
    PessoasStore(MemoriaSegura(), agora: () => DateTime(2026, 11, 23, 10));

void main() {
  setUp(ExecutorApp.esquecerPendente);
  tearDown(ExecutorApp.esquecerPendente);

  test('pedido de ficha pergunta o consentimento e não grava ainda', () async {
    final store = _store();
    final acao = await ExecutorApp.executar(_pedido, fichas: store);

    expect(acao, isNotNull);
    expect(acao!.aguardandoConfirmacao, isTrue);
    expect(acao.mensagem, contains('confirmo'));
    expect(await store.listar(), isEmpty,
        reason: 'nada pode ser gravado antes do consentimento');
    expect(ExecutorApp.pendente?.nome, 'Murilo');
  });

  test('“confirmo” grava a ficha com os dados falados', () async {
    final store = _store();
    await ExecutorApp.executar(_pedido, fichas: store);
    final salvo = await ExecutorApp.executar('confirmo', fichas: store);

    expect(salvo!.ok, isTrue);
    expect(salvo.acao, 'ficha criada');
    final fichas = await store.listar();
    expect(fichas, hasLength(1));
    final murilo = fichas.single;
    expect(murilo.nome, 'Murilo');
    expect(murilo.apelido, 'Murilin');
    expect(murilo.relacao, 'melhor amigo');
    expect(murilo.observacoes, '16 anos');
    expect(murilo.consentimento, isTrue);
  });

  test('pedir de novo atualiza em vez de duplicar', () async {
    final store = _store();
    await ExecutorApp.executar(_pedido, fichas: store);
    await ExecutorApp.executar('confirmo', fichas: store);

    await ExecutorApp.executar(
        'salve a ficha de Murilo, 16 anos, ele é meu vizinho',
        fichas: store);
    final segundo = await ExecutorApp.executar('pode salvar', fichas: store);

    expect(segundo!.acao, 'ficha atualizada');
    final fichas = await store.listar();
    expect(fichas, hasLength(1));
    expect(fichas.single.nome, 'Murilo');
    expect(fichas.single.relacao, 'vizinho');
  });

  test('cancelar não grava nada', () async {
    final store = _store();
    await ExecutorApp.executar(_pedido, fichas: store);
    final cancelado = await ExecutorApp.executar('cancela', fichas: store);

    expect(cancelado!.acao, 'ficha cancelada');
    expect(await store.listar(), isEmpty);
    expect(ExecutorApp.pendente, isNull);
  });

  test('pergunta sobre ficha não é interceptada', () async {
    final store = _store();
    final acao =
        await ExecutorApp.executar('qual é a ficha de Murilo?', fichas: store);
    expect(acao, isNull);
    expect(await store.listar(), isEmpty);
  });

  test('sem armazenamento seguro, a falha é dita e nada é gravado', () async {
    final store = PessoasStore(_FalhaAoSalvar());
    await ExecutorApp.executar(_pedido, fichas: store);
    final acao = await ExecutorApp.executar('confirmo', fichas: store);

    expect(acao!.ok, isFalse);
    expect(acao.acao, 'ficha recusada');
    expect(acao.mensagem, contains('Não guardei'));
  });
}

class _FalhaAoSalvar implements ArmazenamentoSeguro {
  @override
  Future<String?> ler(String chave) async => null;

  @override
  Future<void> gravar(String chave, String valor) async =>
      throw StateError('cofre indisponível');

  @override
  Future<void> apagar(String chave) async {}
}
