import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/tarefas.dart';

/// Resultado de uma operação de escrita: `ok` com valor ou `falha` com motivo.
class ResultadoAgenda<T> {
  const ResultadoAgenda.ok(this.valor) : erro = null;
  const ResultadoAgenda.falha(this.erro) : valor = null;

  final T? valor;
  final String? erro;

  bool get ok => erro == null;
}

/// Armazenamento local das tarefas, automações, fila e histórico.
///
/// Usa `SharedPreferences` porque são dados de organização do próprio usuário,
/// não segredos. Falha de gravação vira mensagem na tela — nunca um "salvo"
/// inventado.
class TarefasStore {
  TarefasStore(this._prefs, {DateTime Function()? agora})
      : _agora = agora ?? DateTime.now;

  static const chaveTarefas = 'jarvis.tarefas.v1';
  static const chaveAutomacoes = 'jarvis.automacoes.v1';
  static const chaveFila = 'jarvis.fila.v1';
  static const chaveHistorico = 'jarvis.historico.v1';

  final SharedPreferences _prefs;
  final DateTime Function() _agora;

  int _sequencia = 0;

  static Future<TarefasStore> abrir() async =>
      TarefasStore(await SharedPreferences.getInstance());

  List<Tarefa> tarefas() =>
      ordenarTarefas(tarefasDeJson(_prefs.getString(chaveTarefas)));

  List<Automacao> automacoes() =>
      automacoesDeJson(_prefs.getString(chaveAutomacoes));

  List<ItemFila> fila() => filaDeJson(_prefs.getString(chaveFila));

  List<EventoAutomacao> historico() =>
      ordenarHistorico(historicoDeJson(_prefs.getString(chaveHistorico)));

  Tarefa? tarefa(String id) {
    for (final t in tarefas()) {
      if (t.id == id) return t;
    }
    return null;
  }

  Automacao? automacao(String id) {
    for (final a in automacoes()) {
      if (a.id == id) return a;
    }
    return null;
  }

  Future<ResultadoAgenda<Tarefa>> salvarTarefa(Tarefa dados) async {
    final limpa = dados.copiarCom(
      titulo: limparTextoTarefa(dados.titulo, 160),
      notas: limparTextoTarefa(dados.notas, 2000),
    );
    final quando = _agora();
    final existente = limpa.id.isEmpty ? null : tarefa(limpa.id);
    var ficha = limpa;
    if (ficha.id.isEmpty) {
      ficha = Tarefa(
        id: 't_${quando.microsecondsSinceEpoch}_${_sequencia++}',
        titulo: ficha.titulo,
        notas: ficha.notas,
        prazo: ficha.prazo,
        prioridade: ficha.prioridade,
        origem: ficha.origem,
        criadaEm: quando,
      );
    } else if (existente == null) {
      ficha = ficha.copiarCom(criadaEm: quando);
    }
    final erro = validarTarefa(ficha);
    if (erro != null) return ResultadoAgenda.falha(erro);

    final lista = tarefas();
    if (existente == null && lista.length >= limiteTarefas) {
      return const ResultadoAgenda.falha(
          'Limite de $limiteTarefas tarefas. Conclua ou apague alguma antes de criar outra.');
    }
    final proxima = existente == null
        ? [...lista, ficha]
        : lista.map((t) => t.id == ficha.id ? ficha : t).toList();
    final payload = jsonDeTarefas(proxima);
    if (!_cabe(chaveTarefas, payload)) {
      return const ResultadoAgenda.falha(
          'A agenda passou do limite de 128 kB. Apague itens antigos.');
    }
    try {
      final gravou = await _prefs.setString(chaveTarefas, payload);
      if (!gravou) {
        return const ResultadoAgenda.falha(
            'O Android não confirmou a gravação da tarefa.');
      }
    } catch (_) {
      return const ResultadoAgenda.falha(
          'Não foi possível gravar a tarefa neste aparelho.');
    }
    return ResultadoAgenda.ok(ficha);
  }

  Future<String?> marcarFeita(String id, bool feita) async {
    final atual = tarefa(id);
    if (atual == null) return 'Tarefa não encontrada.';
    final quando = _agora();
    final resultado = await salvarTarefa(atual.copiarCom(
      feita: feita,
      concluidaEm: feita ? quando : null,
      limparConclusao: !feita,
    ));
    return resultado.erro;
  }

  Future<bool> apagarTarefa(String id) async {
    if (id.isEmpty) return false;
    final lista = tarefas();
    final proxima = lista.where((t) => t.id != id).toList();
    if (proxima.length == lista.length) return false;
    try {
      return await _prefs.setString(chaveTarefas, jsonDeTarefas(proxima));
    } catch (_) {
      return false;
    }
  }

  Future<ResultadoAgenda<Automacao>> salvarAutomacao(Automacao dados) async {
    final limpa = dados.copiarCom(
      nome: limparTextoTarefa(dados.nome, 80),
      texto: limparTextoTarefa(dados.texto, 1000),
      destino: limparTextoTarefa(dados.destino, 120),
      pacote: limparTextoTarefa(dados.pacote, 120),
    );
    final quando = _agora();
    final existente = limpa.id.isEmpty ? null : automacao(limpa.id);
    var ficha = limpa;
    if (ficha.id.isEmpty) {
      ficha = Automacao(
        id: 'a_${quando.microsecondsSinceEpoch}_${_sequencia++}',
        nome: ficha.nome,
        ativa: ficha.ativa,
        gatilho: ficha.gatilho,
        hora: ficha.hora,
        minuto: ficha.minuto,
        bateriaLimite: ficha.bateriaLimite,
        acao: ficha.acao,
        texto: ficha.texto,
        app: ficha.app,
        destino: ficha.destino,
        pacote: ficha.pacote,
        criadaEm: quando,
      );
    } else if (existente == null) {
      ficha = ficha.copiarCom(criadaEm: quando);
    }
    final erro = validarAutomacao(ficha);
    if (erro != null) return ResultadoAgenda.falha(erro);

    final lista = automacoes();
    if (existente == null && lista.length >= limiteAutomacoes) {
      return const ResultadoAgenda.falha(
          'Limite de $limiteAutomacoes automações. Apague alguma antes de criar outra.');
    }
    final proxima = existente == null
        ? [...lista, ficha]
        : lista.map((a) => a.id == ficha.id ? ficha : a).toList();
    final payload = jsonDeAutomacoes(proxima);
    if (!_cabe(chaveAutomacoes, payload)) {
      return const ResultadoAgenda.falha(
          'A agenda passou do limite de 128 kB. Apague itens antigos.');
    }
    try {
      final gravou = await _prefs.setString(chaveAutomacoes, payload);
      if (!gravou) {
        return const ResultadoAgenda.falha(
            'O Android não confirmou a gravação da automação.');
      }
    } catch (_) {
      return const ResultadoAgenda.falha(
          'Não foi possível gravar a automação neste aparelho.');
    }
    return ResultadoAgenda.ok(ficha);
  }

  Future<bool> apagarAutomacao(String id) async {
    if (id.isEmpty) return false;
    final lista = automacoes();
    final proxima = lista.where((a) => a.id != id).toList();
    if (proxima.length == lista.length) return false;
    try {
      return await _prefs.setString(chaveAutomacoes, jsonDeAutomacoes(proxima));
    } catch (_) {
      return false;
    }
  }

  Future<bool> marcarExecucao(String id, DateTime quando) async {
    final lista = automacoes();
    var achou = false;
    final proxima = lista.map((a) {
      if (a.id != id) return a;
      achou = true;
      return a.copiarCom(ultimaExecucaoEm: quando);
    }).toList();
    if (!achou) return false;
    try {
      return await _prefs.setString(chaveAutomacoes, jsonDeAutomacoes(proxima));
    } catch (_) {
      return false;
    }
  }

  Future<bool> adicionarEvento(EventoAutomacao evento) async {
    final lista = [...historico(), evento];
    final proxima = lista.length > limiteHistorico
        ? lista.sublist(lista.length - limiteHistorico)
        : lista;
    try {
      return await _prefs.setString(chaveHistorico, jsonDeHistorico(proxima));
    } catch (_) {
      return false;
    }
  }

  Future<bool> salvarHistorico(List<EventoAutomacao> eventos) async {
    final proxima = eventos.length > limiteHistorico
        ? eventos.sublist(0, limiteHistorico)
        : eventos;
    try {
      return await _prefs.setString(chaveHistorico, jsonDeHistorico(proxima));
    } catch (_) {
      return false;
    }
  }

  Future<bool> salvarFila(List<ItemFila> itens) async {
    final proxima =
        itens.length > limiteFila ? itens.sublist(itens.length - limiteFila) : itens;
    try {
      return await _prefs.setString(chaveFila, jsonDeFila(proxima));
    } catch (_) {
      return false;
    }
  }

  bool _cabe(String chave, String payload) {
    var total = 0;
    for (final k in const [
      chaveTarefas,
      chaveAutomacoes,
      chaveFila,
      chaveHistorico,
    ]) {
      final atual = k == chave ? payload : (_prefs.getString(k) ?? '');
      total += utf8.encode(atual).length;
      if (total > limiteBytesAgenda) return false;
    }
    return true;
  }
}
