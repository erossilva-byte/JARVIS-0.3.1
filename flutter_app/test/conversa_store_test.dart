import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/conversa.dart';
import 'package:jarvis_nova/services/conversa_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('salva, relê e mantém o título automático', () async {
    final store = await ConversaStore.abrir();
    final conversa = Conversa.nova(id: '1', agora: DateTime(2026, 11, 14))
      ..adicionar(
          const MensagemConversa(autor: 'user', texto: 'Bom dia, Jarvis'));
    await store.salvar(conversa);

    final lidas = store.listar();
    expect(lidas, hasLength(1));
    expect(lidas.single.titulo, 'Bom dia, Jarvis');
    expect(lidas.single.mensagens, hasLength(1));
  });

  test('fixadas vêm primeiro e a mais recente logo depois', () async {
    final store = await ConversaStore.abrir();
    final antiga = Conversa.nova(id: 'a', agora: DateTime(2026, 11, 1));
    final recente = Conversa.nova(id: 'b', agora: DateTime(2026, 11, 10));
    final fixada = Conversa.nova(id: 'c', agora: DateTime(2026, 11, 5))
      ..fixada = true;
    await store.salvar(antiga);
    await store.salvar(recente);
    await store.salvar(fixada);

    expect(store.ordenadas().map((c) => c.id).toList(), ['c', 'b', 'a']);
  });

  test('apaga só a conversa pedida', () async {
    final store = await ConversaStore.abrir();
    await store.salvar(Conversa.nova(id: 'a', agora: DateTime(2026, 11, 1)));
    await store.salvar(Conversa.nova(id: 'b', agora: DateTime(2026, 11, 2)));
    await store.apagar('a');
    expect(store.listar().map((c) => c.id).toList(), ['b']);
  });

  test('alterna fixada e guarda', () async {
    final store = await ConversaStore.abrir();
    await store.salvar(Conversa.nova(id: 'a', agora: DateTime(2026, 11, 1)));
    await store.alternarFixada('a');
    expect(store.listar().single.fixada, isTrue);
    await store.alternarFixada('a');
    expect(store.listar().single.fixada, isFalse);
  });

  test('rascunho vazio é removido', () async {
    final store = await ConversaStore.abrir();
    await store.salvarRascunho('texto pela metade');
    expect(store.rascunho, 'texto pela metade');
    await store.salvarRascunho('   ');
    expect(store.rascunho, isEmpty);
  });

  test('PIN ditado não entra no histórico da conversa', () async {
    final store = await ConversaStore.abrir();
    final conversa = Conversa.nova(id: 'p', agora: DateTime(2026, 11, 25))
      ..adicionar(const MensagemConversa(autor: 'user', texto: 'meu pin é 4321'))
      ..adicionar(
          const MensagemConversa(autor: 'assistant', texto: 'Anotado: 4321.'));
    await store.salvar(conversa);

    // Na sessão aberta, o texto continua como foi dito.
    expect(conversa.mensagens.first.texto, 'meu pin é 4321');

    final salva = store.listar().single;
    expect(salva.titulo, 'meu pin é [oculto]');
    expect(salva.mensagens.map((m) => m.texto).toList(),
        ['meu pin é [oculto]', 'Anotado: [oculto].']);
  });

  test('telefone continua no histórico da conversa', () async {
    final store = await ConversaStore.abrir();
    final conversa = Conversa.nova(id: 't', agora: DateTime(2026, 11, 25))
      ..adicionar(const MensagemConversa(
          autor: 'user', texto: 'liga para 11999998888'));
    await store.salvar(conversa);

    expect(store.listar().single.mensagens.single.texto,
        'liga para 11999998888');
  });

  test('rascunho com PIN é mascarado', () async {
    final store = await ConversaStore.abrir();
    await store.salvarRascunho('o pin do cofre é 87654321');
    expect(store.rascunho, 'o pin do cofre é [oculto]');
  });

  test('lista corrompida não derruba a tela', () async {
    SharedPreferences.setMockInitialValues(
        {ConversaStore.chaveConversas: '{quebrado'});
    final store = await ConversaStore.abrir();
    expect(store.listar(), isEmpty);
  });
}
