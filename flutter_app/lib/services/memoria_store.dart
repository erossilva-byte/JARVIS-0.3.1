import 'package:shared_preferences/shared_preferences.dart';

import '../core/memoria.dart';
import '../core/memoria_busca.dart';

/// Cofre local de notas: persistência em `shared_preferences` e busca lexical.
///
/// A pasta do Obsidian fica em `CofreSaf` (Android): aqui só há nota local e busca. Importar é
/// colar Markdown ou importar a pasta; sincronizar é uma ação explícita da tela de memória.
class MemoriaStore {
  MemoriaStore(this._prefs);

  static const chave = 'jarvis.memoria.v1';

  final SharedPreferences _prefs;

  static Future<MemoriaStore> abrir() async => MemoriaStore(await SharedPreferences.getInstance());

  List<NotaMemoria> listar() {
    final notas = notasDeJson(_prefs.getString(chave));
    notas.sort((a, b) => b.atualizadaEm.compareTo(a.atualizadaEm));
    return notas;
  }

  Future<void> salvar(NotaMemoria nota) async {
    final notas = notasDeJson(_prefs.getString(chave));
    final indice = notas.indexWhere((n) => n.id == nota.id);
    if (indice >= 0) {
      notas[indice] = nota;
    } else {
      notas.insert(0, nota);
    }
    await _gravar(notas);
  }

  Future<void> apagar(String id) async {
    final notas = notasDeJson(_prefs.getString(chave))..removeWhere((n) => n.id == id);
    await _gravar(notas);
  }

  /// Marca uso pelas notas efetivamente enviadas à IA. Não mexe em `atualizadaEm`: usar não é
  /// editar, e inflar recência falsearia a ordenação.
  Future<void> registrarUso(Iterable<String> ids) async {
    final alvo = ids.toSet();
    if (alvo.isEmpty) return;
    final notas = notasDeJson(_prefs.getString(chave));
    final atualizadas = notas
        .map((nota) => alvo.contains(nota.id) ? nota.copiarCom(usos: nota.usos + 1) : nota)
        .toList();
    await _gravar(atualizadas);
  }

  Future<ImportacaoMemoria> importar(List<({String nome, String conteudo})> arquivos) async {
    final notas = notasDeJson(_prefs.getString(chave));
    final resultado = importarMarkdowns(arquivos, notas);
    if (resultado.adicionadas.isNotEmpty) {
      await _gravar([...resultado.adicionadas, ...notas]);
    }
    return resultado;
  }

  List<ResultadoMemoria> buscar(String consulta, {int limite = 20}) =>
      buscarNotas(listar(), consulta, limite: limite);

  ContextoMemoria contexto(String consulta, {int orcamento = 1800}) =>
      contextoRelevante(listar(), consulta, orcamento: orcamento);

  Future<void> _gravar(List<NotaMemoria> notas) => _prefs.setString(chave, jsonDeNotas(notas));
}
