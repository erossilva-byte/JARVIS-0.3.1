import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/memoria.dart';
import 'package:jarvis_nova/core/memoria_conflito.dart';
import 'package:jarvis_nova/core/memoria_sync.dart';
import 'package:jarvis_nova/services/cofre_saf.dart';
import 'package:jarvis_nova/services/memoria_store.dart';
import 'package:jarvis_nova/services/resolvedor_conflito.dart';
import 'package:jarvis_nova/services/sincronizador.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CofreFalso implements CofreRemoto {
  CofreFalso([Map<String, String>? arquivos]) : arquivos = arquivos ?? {};

  final Map<String, String> arquivos;
  bool falharEscrita = false;

  @override
  Future<ResultadoSaf<LeituraSaf>> listarNotas() async =>
      ResultadoSaf.ok(LeituraSaf(notas: const []));

  @override
  Future<ResultadoSaf<bool>> escreverNota(
      {required String caminho, required String conteudo}) async {
    if (falharEscrita) return const ResultadoSaf.falha('sem espaço');
    arquivos[caminho] = conteudo;
    return const ResultadoSaf.ok(true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoriaStore store;
  final quando = DateTime(2026, 11, 15, 9);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = MemoriaStore(await SharedPreferences.getInstance());
    await store.salvar(NotaMemoria(
      id: 'motor',
      titulo: 'Motor',
      texto: 'texto do aparelho',
      caminho: 'Oficina/Motor.md',
      hashSincronizado: hashConteudo('base'),
      criadaEm: quando,
      atualizadaEm: quando,
    ));
  });

  ConflitoSync conflito() => ConflitoSync(
        local: store.listar().single,
        remoto: ArquivoRemoto(
            caminho: 'Oficina/Motor.md',
            conteudo: '---\ntitulo: Motor\n---\ntexto da pasta'),
        motivo: 'as duas cópias mudaram',
      );

  ResolvedorConflito resolvedor(CofreFalso cofre) =>
      ResolvedorConflito(store: store, cofre: cofre, agora: () => quando);

  test('manter a do aparelho grava na pasta e preserva a da pasta', () async {
    final cofre = CofreFalso();
    final resultado =
        await resolvedor(cofre).resolver(conflito(), DecisaoConflito.aparelho);

    expect(resultado.ok, isTrue);
    expect(resultado.enviado, isTrue);
    expect(cofre.arquivos['Oficina/Motor.md'], contains('texto do aparelho'));
    final oficial = store.listar().firstWhere((n) => n.id == 'motor');
    expect(oficial.texto, 'texto do aparelho');
    expect(oficial.hashSincronizado, hashConteudo('texto do aparelho'));
    final backup = store.listar().firstWhere((n) => n.id != 'motor');
    expect(backup.texto, 'texto da pasta');
    expect(backup.caminho, isNull);
    expect(backup.titulo, contains('versão'));
    expect(ehBackupConflito(backup), isTrue);
    expect(tituloSemSufixoBackup(backup.titulo), 'Motor');
  });

  test('manter a da pasta adota o texto remoto e preserva o local', () async {
    final cofre = CofreFalso();
    final resultado =
        await resolvedor(cofre).resolver(conflito(), DecisaoConflito.pasta);

    expect(resultado.ok, isTrue);
    expect(resultado.enviado, isFalse);
    expect(cofre.arquivos, isEmpty);
    final oficial = store.listar().firstWhere((n) => n.id == 'motor');
    expect(oficial.texto, 'texto da pasta');
    expect(oficial.hashSincronizado, hashConteudo('texto da pasta'));
    final backup = store.listar().firstWhere((n) => n.id != 'motor');
    expect(backup.texto, 'texto do aparelho');
    expect(backup.caminho, isNull);
  });

  test('falha ao gravar na pasta não mexe em nada e avisa', () async {
    final cofre = CofreFalso()..falharEscrita = true;
    final resultado =
        await resolvedor(cofre).resolver(conflito(), DecisaoConflito.aparelho);

    expect(resultado.ok, isFalse);
    expect(resultado.erro, contains('continuam como estavam'));
    expect(cofre.arquivos, isEmpty);
    expect(store.listar(), hasLength(1));
    expect(store.listar().single.texto, 'texto do aparelho');
    expect(store.listar().single.hashSincronizado, hashConteudo('base'));
  });
}
