import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/memoria.dart';
import 'package:jarvis_nova/services/cofre_saf.dart';
import 'package:jarvis_nova/services/memoria_store.dart';
import 'package:jarvis_nova/services/sincronizador.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CofreFalso implements CofreRemoto {
  CofreFalso([Map<String, String>? arquivos]) : arquivos = arquivos ?? {};

  final Map<String, String> arquivos;
  final Map<String, String> enviados = {};
  bool falharLeitura = false;
  bool falharEscrita = false;

  @override
  Future<ResultadoSaf<LeituraSaf>> listarNotas() async {
    if (falharLeitura) return const ResultadoSaf.falha('pasta indisponível');
    return ResultadoSaf.ok(LeituraSaf(notas: [
      for (final item in arquivos.entries)
        NotaSaf(
            nome: item.key.split('/').last,
            caminho: item.key,
            conteudo: item.value),
    ]));
  }

  @override
  Future<ResultadoSaf<bool>> escreverNota(
      {required String caminho, required String conteudo}) async {
    if (falharEscrita) return const ResultadoSaf.falha('disco cheio');
    enviados[caminho] = conteudo;
    arquivos[caminho] = conteudo;
    return const ResultadoSaf.ok(true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoriaStore store;
  final quando = DateTime(2026, 11, 14, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = MemoriaStore(await SharedPreferences.getInstance());
  });

  Sincronizador sincronizador(CofreFalso cofre) =>
      Sincronizador(store: store, cofre: cofre, agora: () => quando);

  test('nota nova do aparelho vai para a pasta e fica marcada', () async {
    await store.salvar(NotaMemoria(
        id: 'a',
        titulo: 'Minha nota',
        texto: 'conteúdo local',
        criadaEm: quando,
        atualizadaEm: quando));
    final cofre = CofreFalso();
    final resultado = await sincronizador(cofre).sincronizar();

    expect(resultado.ok, isTrue);
    expect(resultado.enviadas, ['minha-nota.md']);
    expect(cofre.arquivos.keys, contains('minha-nota.md'));
    final salva = store.listar().single;
    expect(salva.caminho, 'minha-nota.md');
    expect(salva.hashSincronizado, hashConteudo('conteúdo local'));
    expect(resultado.resumo, contains('1 enviada(s)'));
  });

  test('arquivo novo da pasta vira nota local', () async {
    final cofre =
        CofreFalso({'Normas/Segurança.md': '# Segurança\n\nUse EPI.'});
    final resultado = await sincronizador(cofre).sincronizar();

    expect(resultado.recebidas, ['Normas/Segurança.md']);
    final nota = store.listar().single;
    expect(nota.titulo, 'Segurança');
    expect(nota.caminho, 'Normas/Segurança.md');
    expect(nota.texto, contains('Use EPI.'));
    expect(nota.hashSincronizado, hashConteudo(nota.texto.trim()));
  });

  test('segunda sincronização sem mudanças não escreve nada', () async {
    await store.salvar(NotaMemoria(
        id: 'a',
        titulo: 'Motor',
        texto: 'texto',
        criadaEm: quando,
        atualizadaEm: quando));
    final cofre = CofreFalso();
    await sincronizador(cofre).sincronizar();
    cofre.enviados.clear();

    final segunda = await sincronizador(cofre).sincronizar();

    expect(cofre.enviados, isEmpty, reason: 'a sincronização entrou em laço');
    expect(segunda.enviadas, isEmpty);
    expect(segunda.plano.iguais, 1);
  });

  test('mudança na pasta depois de sincronizar é recebida', () async {
    await store.salvar(NotaMemoria(
        id: 'a',
        titulo: 'Motor',
        texto: 'versão 1',
        criadaEm: quando,
        atualizadaEm: quando));
    final cofre = CofreFalso();
    await sincronizador(cofre).sincronizar();
    cofre.arquivos['motor.md'] =
        escreverMarkdown(store.listar().single.copiarCom(texto: 'versão 2'));

    final resultado = await sincronizador(cofre).sincronizar();

    expect(resultado.recebidas, ['motor.md']);
    expect(store.listar().single.texto, 'versão 2');
  });

  test('conflito não sobrescreve nenhum dos lados', () async {
    final base = NotaMemoria(
      id: 'a',
      titulo: 'Motor',
      texto: 'base alterada no aparelho',
      caminho: 'motor.md',
      hashSincronizado: hashConteudo('base'),
      criadaEm: quando,
      atualizadaEm: quando,
    );
    await store.salvar(base);
    final cofre = CofreFalso({'motor.md': 'mudou no Obsidian'});

    final resultado = await sincronizador(cofre).sincronizar();

    expect(resultado.plano.conflitos, hasLength(1));
    expect(resultado.plano.envios, isEmpty);
    expect(resultado.plano.recebidas, isEmpty);
    expect(cofre.arquivos['motor.md'], 'mudou no Obsidian');
    expect(store.listar().single.texto, 'base alterada no aparelho');
  });

  test('falha de escrita é reportada e a nota continua local', () async {
    await store.salvar(NotaMemoria(
        id: 'a',
        titulo: 'Nova',
        texto: 'texto',
        criadaEm: quando,
        atualizadaEm: quando));
    final cofre = CofreFalso()..falharEscrita = true;

    final resultado = await sincronizador(cofre).sincronizar();

    expect(resultado.falhas, hasLength(1));
    expect(resultado.falhas.single, contains('disco cheio'));
    expect(resultado.enviadas, isEmpty);
    expect(store.listar().single.caminho, isNull);
  });

  test('falha de leitura interrompe sem tocar no cofre', () async {
    await store.salvar(NotaMemoria(
        id: 'a',
        titulo: 'Nova',
        texto: 'x',
        criadaEm: quando,
        atualizadaEm: quando));
    final cofre = CofreFalso()..falharLeitura = true;

    final resultado = await sincronizador(cofre).sincronizar();

    expect(resultado.ok, isFalse);
    expect(resultado.erroGeral, contains('pasta indisponível'));
    expect(cofre.enviados, isEmpty);
  });

  test('nota cujo arquivo sumiu da pasta continua no aparelho', () async {
    final nota = NotaMemoria(
      id: 'a',
      titulo: 'Sumida',
      texto: 'conteúdo',
      caminho: 'sumida.md',
      hashSincronizado: hashConteudo('conteúdo'),
      criadaEm: quando,
      atualizadaEm: quando,
    );
    await store.salvar(nota);
    final cofre = CofreFalso({'outra.md': 'outra nota'});

    final resultado = await sincronizador(cofre).sincronizar();

    expect(resultado.plano.ausentesNaPasta.single.titulo, 'Sumida');
    expect(store.listar().map((n) => n.titulo), contains('Sumida'));
    expect(cofre.arquivos, contains('outra.md'));
    expect(resultado.falhas, isEmpty);
  });
}
