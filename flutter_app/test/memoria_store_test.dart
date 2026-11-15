import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/memoria.dart';
import 'package:jarvis_nova/services/memoria_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

NotaMemoria nota(String titulo, String texto, {DateTime? atualizada, int importancia = 1}) => NotaMemoria(
      id: titulo.toLowerCase().replaceAll(' ', '-'),
      titulo: titulo,
      texto: texto,
      importancia: importancia,
      criadaEm: DateTime(2026, 11, 1),
      atualizadaEm: atualizada ?? DateTime(2026, 11, 1),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('salva, relê e ordena pela atualização mais recente', () async {
    final store = await MemoriaStore.abrir();
    await store.salvar(nota('Antiga', 'conteúdo', atualizada: DateTime(2026, 11, 1)));
    await store.salvar(nota('Recente', 'conteúdo', atualizada: DateTime(2026, 11, 9)));

    expect(store.listar().map((n) => n.titulo).toList(), ['Recente', 'Antiga']);
  });

  test('apaga só a nota pedida', () async {
    final store = await MemoriaStore.abrir();
    await store.salvar(nota('A', 'x'));
    await store.salvar(nota('B', 'y'));
    await store.apagar('a');
    expect(store.listar().map((n) => n.titulo).toList(), ['B']);
  });

  test('registrar uso soma apenas nas notas enviadas e não mexe na data', () async {
    final store = await MemoriaStore.abrir();
    await store.salvar(nota('A', 'x', atualizada: DateTime(2026, 11, 1)));
    await store.salvar(nota('B', 'y', atualizada: DateTime(2026, 11, 1)));

    await store.registrarUso(['a']);

    final porTitulo = {for (final n in store.listar()) n.titulo: n};
    expect(porTitulo['A']!.usos, 1);
    expect(porTitulo['B']!.usos, 0);
    expect(porTitulo['A']!.atualizadaEm, DateTime(2026, 11, 1));
  });

  test('importação não sobrescreve conflito e conta repetida', () async {
    final store = await MemoriaStore.abrir();
    await store.salvar(nota('Oficina', 'mesmo texto'));

    final resultado = await store.importar([
      (nome: 'a.md', conteudo: '---\ntitulo: Oficina\n---\nmesmo texto'),
      (nome: 'b.md', conteudo: '---\ntitulo: Oficina\n---\ntexto diferente'),
      (nome: 'c.md', conteudo: '---\ntitulo: Bancada\n---\nAlicate'),
    ]);

    expect(resultado.repetidas, 1);
    expect(resultado.conflitos, ['Oficina']);
    expect(resultado.adicionadas.single.titulo, 'Bancada');
    expect(store.listar().firstWhere((n) => n.titulo == 'Oficina').texto, 'mesmo texto');
    expect(store.listar(), hasLength(2));
  });

  test('contexto não envia cofre inteiro nem nota sem relação', () async {
    final store = await MemoriaStore.abrir();
    await store.salvar(nota('Motor', 'ligação do motor trifásico'));
    await store.salvar(nota('Receita', 'bolo de cenoura'));

    final contexto = store.contexto('motor trifásico');

    expect(contexto.usados.map((n) => n.titulo), ['Motor']);
    expect(contexto.texto, contains('Motor'));
    expect(contexto.texto, isNot(contains('bolo')));
  });

  test('contexto vazio sem consulta', () async {
    final store = await MemoriaStore.abrir();
    await store.salvar(nota('Motor', 'motor'));
    expect(store.contexto('').vazio, isTrue);
  });
}
