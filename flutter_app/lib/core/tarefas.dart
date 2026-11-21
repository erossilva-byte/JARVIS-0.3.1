/// Tarefas, automações, fila offline e histórico — Fase 11.
///
/// Este arquivo não depende de Flutter nem do Android: decide o que venceu, o
/// que precisa de confirmação e o que fica na fila. A execução fica em
/// `services/tarefas_page.dart`; o agendamento real, no canal nativo.
/// Nada aqui inventa sucesso: um item só sai da fila quando o chamador confirma
/// que a ação aconteceu.
library;

import 'dart:convert';

import 'aparelho.dart' show appMensagemPorId;

const limiteTarefas = 100;
const limiteAutomacoes = 40;
const limiteFila = 100;
const limiteHistorico = 200;
const maxTentativasFila = 3;
const limiteBytesAgenda = 128 * 1024;

/// Janela em que um horário ainda conta como vencido quando o app é aberto atrasado.
const janelaHorarioMinutos = 5;

/// Automação por bateria não repete antes disso, mesmo com a tela aberta.
const intervaloBateriaHoras = 6;

enum PrioridadeTarefa { baixa, normal, alta }

enum TipoGatilho { horario, bateriaAbaixo }

enum TipoAcaoAutomacao { avisar, criarTarefa, abrirApp, mensagem }

enum EstadoEvento { executada, aguardandoConfirmacao, falhou, ignorada }

enum EstadoFila { pendente, aguardandoConfirmacao, feito, falhou, cancelado }

String doisDigitos(int valor) => valor.toString().padLeft(2, '0');

String horarioRotulo(int hora, int minuto) =>
    '${doisDigitos(hora)}:${doisDigitos(minuto)}';

extension RotuloPrioridade on PrioridadeTarefa {
  String get rotulo => switch (this) {
        PrioridadeTarefa.baixa => 'Baixa',
        PrioridadeTarefa.normal => 'Normal',
        PrioridadeTarefa.alta => 'Alta',
      };
}

extension RotuloGatilho on TipoGatilho {
  String get rotulo => switch (this) {
        TipoGatilho.horario => 'Todo dia em um horário',
        TipoGatilho.bateriaAbaixo => 'Quando a bateria estiver baixa',
      };
}

extension RotuloAcao on TipoAcaoAutomacao {
  String get rotulo => switch (this) {
        TipoAcaoAutomacao.avisar => 'Mostrar um aviso',
        TipoAcaoAutomacao.criarTarefa => 'Criar uma tarefa',
        TipoAcaoAutomacao.abrirApp => 'Abrir um app',
        TipoAcaoAutomacao.mensagem => 'Preparar uma mensagem (pede confirmação)',
      };

  /// Só a mensagem é sensível: o texto é preparado, mas o envio é do usuário.
  bool get sensivel => this == TipoAcaoAutomacao.mensagem;
}

extension RotuloEstadoEvento on EstadoEvento {
  String get rotulo => switch (this) {
        EstadoEvento.executada => 'Executada',
        EstadoEvento.aguardandoConfirmacao => 'Aguardando confirmação',
        EstadoEvento.falhou => 'Falhou',
        EstadoEvento.ignorada => 'Ignorada',
      };
}

extension RotuloEstadoFila on EstadoFila {
  String get rotulo => switch (this) {
        EstadoFila.pendente => 'Pendente',
        EstadoFila.aguardandoConfirmacao => 'Aguardando confirmação',
        EstadoFila.feito => 'Concluída',
        EstadoFila.falhou => 'Falhou',
        EstadoFila.cancelado => 'Cancelada',
      };
}

/// Remove controle e `<>`, normaliza espaços e corta no limite.
String limparTextoTarefa(String? texto, int limite) {
  var limpo = (texto ?? '')
      .replaceAll(
          RegExp(r'[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]'), ' ')
      .replaceAll(RegExp(r'[<>]'), '')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  if (limpo.length > limite) limpo = limpo.substring(0, limite).trim();
  return limpo;
}

/// Identificador inteiro estável para o `AlarmManager` (FNV-1a, sem depender
/// do `hashCode` da String, que não é garantido entre execuções).
int idLembrete(String id) {
  var hash = 0x811c9dc5;
  for (final unidade in id.codeUnits) {
    hash ^= unidade;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return 1000 + (hash % 1000000000);
}

DateTime? _data(Object? valor) =>
    valor is String ? DateTime.tryParse(valor) : null;

String _texto(Object? valor) => valor is String ? valor : '';

class Tarefa {
  const Tarefa({
    required this.id,
    required this.titulo,
    this.notas = '',
    this.prazo,
    this.prioridade = PrioridadeTarefa.normal,
    this.feita = false,
    this.origem = 'manual',
    required this.criadaEm,
    this.concluidaEm,
  });

  final String id;
  final String titulo;
  final String notas;
  final DateTime? prazo;
  final PrioridadeTarefa prioridade;
  final bool feita;

  /// `manual` ou `automacao`.
  final String origem;
  final DateTime criadaEm;
  final DateTime? concluidaEm;

  int get lembreteId => idLembrete(id);

  bool atrasada(DateTime agora) =>
      !feita && prazo != null && prazo!.isBefore(agora);

  String get prazoRotulo {
    if (prazo == null) return 'sem prazo';
    final p = prazo!;
    return '${doisDigitos(p.day)}/${doisDigitos(p.month)}/${p.year} '
        '${horarioRotulo(p.hour, p.minute)}';
  }

  Tarefa copiarCom({
    String? titulo,
    String? notas,
    DateTime? prazo,
    bool limparPrazo = false,
    PrioridadeTarefa? prioridade,
    bool? feita,
    String? origem,
    DateTime? criadaEm,
    DateTime? concluidaEm,
    bool limparConclusao = false,
  }) =>
      Tarefa(
        id: id,
        titulo: titulo ?? this.titulo,
        notas: notas ?? this.notas,
        prazo: limparPrazo ? null : (prazo ?? this.prazo),
        prioridade: prioridade ?? this.prioridade,
        feita: feita ?? this.feita,
        origem: origem ?? this.origem,
        criadaEm: criadaEm ?? this.criadaEm,
        concluidaEm: limparConclusao ? null : (concluidaEm ?? this.concluidaEm),
      );

  Map<String, Object?> paraJson() => {
        'id': id,
        'titulo': titulo,
        'notas': notas,
        'prazo': prazo?.toIso8601String(),
        'prioridade': prioridade.name,
        'feita': feita,
        'origem': origem,
        'criadaEm': criadaEm.toIso8601String(),
        'concluidaEm': concluidaEm?.toIso8601String(),
      };

  static Tarefa? deJson(Object? dados) {
    if (dados is! Map) return null;
    final id = dados['id'];
    final titulo = dados['titulo'];
    if (id is! String || id.isEmpty || titulo is! String) return null;
    return Tarefa(
      id: id,
      titulo: titulo,
      notas: _texto(dados['notas']),
      prazo: _data(dados['prazo']),
      prioridade: PrioridadeTarefa.values.firstWhere(
        (p) => p.name == dados['prioridade'],
        orElse: () => PrioridadeTarefa.normal,
      ),
      feita: dados['feita'] == true,
      origem: _texto(dados['origem']).isEmpty ? 'manual' : _texto(dados['origem']),
      criadaEm: _data(dados['criadaEm']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      concluidaEm: _data(dados['concluidaEm']),
    );
  }
}

class Automacao {
  const Automacao({
    required this.id,
    required this.nome,
    this.ativa = true,
    this.gatilho = TipoGatilho.horario,
    this.hora = 8,
    this.minuto = 0,
    this.bateriaLimite = 20,
    this.acao = TipoAcaoAutomacao.avisar,
    this.texto = '',
    this.app = 'whatsapp',
    this.destino = '',
    this.pacote = '',
    required this.criadaEm,
    this.ultimaExecucaoEm,
  });

  final String id;
  final String nome;
  final bool ativa;
  final TipoGatilho gatilho;
  final int hora;
  final int minuto;
  final int bateriaLimite;
  final TipoAcaoAutomacao acao;
  final String texto;
  final String app;
  final String destino;
  final String pacote;
  final DateTime criadaEm;
  final DateTime? ultimaExecucaoEm;

  bool get sensivel => acao.sensivel;

  String get descricaoGatilho => switch (gatilho) {
        TipoGatilho.horario =>
          'Todo dia às ${horarioRotulo(hora, minuto)}',
        TipoGatilho.bateriaAbaixo =>
          'Quando a bateria estiver em $bateriaLimite% ou menos',
      };

  String get descricaoAcao => switch (acao) {
        TipoAcaoAutomacao.avisar => 'Aviso: $texto',
        TipoAcaoAutomacao.criarTarefa => 'Criar tarefa: $texto',
        TipoAcaoAutomacao.abrirApp =>
          'Abrir app: ${pacote.isEmpty ? 'sem pacote' : pacote}',
        TipoAcaoAutomacao.mensagem =>
          'Conversa no ${appMensagemPorId(app)?.nome ?? app} para '
              '${destino.isEmpty ? 'sem destino' : destino}',
      };

  Automacao copiarCom({
    String? nome,
    bool? ativa,
    TipoGatilho? gatilho,
    int? hora,
    int? minuto,
    int? bateriaLimite,
    TipoAcaoAutomacao? acao,
    String? texto,
    String? app,
    String? destino,
    String? pacote,
    DateTime? criadaEm,
    DateTime? ultimaExecucaoEm,
    bool limparExecucao = false,
  }) =>
      Automacao(
        id: id,
        nome: nome ?? this.nome,
        ativa: ativa ?? this.ativa,
        gatilho: gatilho ?? this.gatilho,
        hora: hora ?? this.hora,
        minuto: minuto ?? this.minuto,
        bateriaLimite: bateriaLimite ?? this.bateriaLimite,
        acao: acao ?? this.acao,
        texto: texto ?? this.texto,
        app: app ?? this.app,
        destino: destino ?? this.destino,
        pacote: pacote ?? this.pacote,
        criadaEm: criadaEm ?? this.criadaEm,
        ultimaExecucaoEm:
            limparExecucao ? null : (ultimaExecucaoEm ?? this.ultimaExecucaoEm),
      );

  Map<String, Object?> paraJson() => {
        'id': id,
        'nome': nome,
        'ativa': ativa,
        'gatilho': gatilho.name,
        'hora': hora,
        'minuto': minuto,
        'bateriaLimite': bateriaLimite,
        'acao': acao.name,
        'texto': texto,
        'app': app,
        'destino': destino,
        'pacote': pacote,
        'criadaEm': criadaEm.toIso8601String(),
        'ultimaExecucaoEm': ultimaExecucaoEm?.toIso8601String(),
      };

  static Automacao? deJson(Object? dados) {
    if (dados is! Map) return null;
    final id = dados['id'];
    final nome = dados['nome'];
    if (id is! String || id.isEmpty || nome is! String) return null;
    int inteiro(Object? valor, int padrao, int minimo, int maximo) {
      final n = valor is num ? valor.toInt() : padrao;
      return n.clamp(minimo, maximo);
    }

    return Automacao(
      id: id,
      nome: nome,
      ativa: dados['ativa'] != false,
      gatilho: TipoGatilho.values.firstWhere(
        (g) => g.name == dados['gatilho'],
        orElse: () => TipoGatilho.horario,
      ),
      hora: inteiro(dados['hora'], 8, 0, 23),
      minuto: inteiro(dados['minuto'], 0, 0, 59),
      bateriaLimite: inteiro(dados['bateriaLimite'], 20, 1, 100),
      acao: TipoAcaoAutomacao.values.firstWhere(
        (a) => a.name == dados['acao'],
        orElse: () => TipoAcaoAutomacao.avisar,
      ),
      texto: _texto(dados['texto']),
      app: _texto(dados['app']).isEmpty ? 'whatsapp' : _texto(dados['app']),
      destino: _texto(dados['destino']),
      pacote: _texto(dados['pacote']),
      criadaEm: _data(dados['criadaEm']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      ultimaExecucaoEm: _data(dados['ultimaExecucaoEm']),
    );
  }
}

class EventoAutomacao {
  const EventoAutomacao({
    required this.id,
    required this.automacaoId,
    required this.nome,
    required this.quando,
    required this.estado,
    this.detalhe = '',
  });

  final String id;
  final String automacaoId;
  final String nome;
  final DateTime quando;
  final EstadoEvento estado;
  final String detalhe;

  String get quandoRotulo {
    final q = quando;
    return '${doisDigitos(q.day)}/${doisDigitos(q.month)} '
        '${horarioRotulo(q.hour, q.minute)}';
  }

  Map<String, Object?> paraJson() => {
        'id': id,
        'automacaoId': automacaoId,
        'nome': nome,
        'quando': quando.toIso8601String(),
        'estado': estado.name,
        'detalhe': detalhe,
      };

  static EventoAutomacao? deJson(Object? dados) {
    if (dados is! Map) return null;
    final id = dados['id'];
    final nome = dados['nome'];
    final quando = _data(dados['quando']);
    if (id is! String || id.isEmpty || nome is! String || quando == null) {
      return null;
    }
    return EventoAutomacao(
      id: id,
      automacaoId: _texto(dados['automacaoId']),
      nome: nome,
      quando: quando,
      estado: EstadoEvento.values.firstWhere(
        (e) => e.name == dados['estado'],
        orElse: () => EstadoEvento.executada,
      ),
      detalhe: _texto(dados['detalhe']),
    );
  }
}

/// Item da fila: uma ação decidida que ainda não foi confirmada pelo Android.
class ItemFila {
  const ItemFila({
    required this.id,
    required this.automacaoId,
    required this.acao,
    this.titulo = '',
    this.texto = '',
    this.app = 'whatsapp',
    this.destino = '',
    this.pacote = '',
    required this.criadoEm,
    this.estado = EstadoFila.pendente,
    this.tentativas = 0,
    this.ultimoErro = '',
  });

  final String id;
  final String automacaoId;
  final TipoAcaoAutomacao acao;
  final String titulo;
  final String texto;
  final String app;
  final String destino;
  final String pacote;
  final DateTime criadoEm;
  final EstadoFila estado;
  final int tentativas;
  final String ultimoErro;

  bool get sensivel => acao.sensivel;

  String get descricao => switch (acao) {
        TipoAcaoAutomacao.avisar => 'Aviso: $texto',
        TipoAcaoAutomacao.criarTarefa => 'Criar tarefa: $texto',
        TipoAcaoAutomacao.abrirApp => 'Abrir app: $pacote',
        TipoAcaoAutomacao.mensagem =>
          'Mensagem no ${appMensagemPorId(app)?.nome ?? app} para '
              '$destino: "$texto"',
      };

  ItemFila copiarCom({
    EstadoFila? estado,
    int? tentativas,
    String? ultimoErro,
  }) =>
      ItemFila(
        id: id,
        automacaoId: automacaoId,
        acao: acao,
        titulo: titulo,
        texto: texto,
        app: app,
        destino: destino,
        pacote: pacote,
        criadoEm: criadoEm,
        estado: estado ?? this.estado,
        tentativas: tentativas ?? this.tentativas,
        ultimoErro: ultimoErro ?? this.ultimoErro,
      );

  Map<String, Object?> paraJson() => {
        'id': id,
        'automacaoId': automacaoId,
        'acao': acao.name,
        'titulo': titulo,
        'texto': texto,
        'app': app,
        'destino': destino,
        'pacote': pacote,
        'criadoEm': criadoEm.toIso8601String(),
        'estado': estado.name,
        'tentativas': tentativas,
        'ultimoErro': ultimoErro,
      };

  static ItemFila? deJson(Object? dados) {
    if (dados is! Map) return null;
    final id = dados['id'];
    final criadoEm = _data(dados['criadoEm']);
    if (id is! String || id.isEmpty || criadoEm == null) return null;
    return ItemFila(
      id: id,
      automacaoId: _texto(dados['automacaoId']),
      acao: TipoAcaoAutomacao.values.firstWhere(
        (a) => a.name == dados['acao'],
        orElse: () => TipoAcaoAutomacao.avisar,
      ),
      titulo: _texto(dados['titulo']),
      texto: _texto(dados['texto']),
      app: _texto(dados['app']).isEmpty ? 'whatsapp' : _texto(dados['app']),
      destino: _texto(dados['destino']),
      pacote: _texto(dados['pacote']),
      criadoEm: criadoEm,
      estado: EstadoFila.values.firstWhere(
        (e) => e.name == dados['estado'],
        orElse: () => EstadoFila.pendente,
      ),
      tentativas: dados['tentativas'] is num
          ? (dados['tentativas'] as num).toInt().clamp(0, 99)
          : 0,
      ultimoErro: _texto(dados['ultimoErro']),
    );
  }
}

ItemFila itemFilaDeAutomacao(Automacao automacao, DateTime quando) => ItemFila(
      id: 'f_${automacao.id}_${quando.microsecondsSinceEpoch}',
      automacaoId: automacao.id,
      acao: automacao.acao,
      titulo: automacao.nome,
      texto: automacao.texto,
      app: automacao.app,
      destino: automacao.destino,
      pacote: automacao.pacote,
      criadoEm: quando,
      estado: automacao.sensivel
          ? EstadoFila.aguardandoConfirmacao
          : EstadoFila.pendente,
    );

/// Próxima ocorrência do horário; hoje se ainda não passou, senão amanhã.
DateTime proximaOcorrencia(int hora, int minuto, DateTime apos) {
  final hoje = DateTime(apos.year, apos.month, apos.day, hora, minuto);
  if (hoje.isAfter(apos)) return hoje;
  return hoje.add(const Duration(days: 1));
}

/// Verdadeiro quando a automação deve rodar agora.
///
/// O horário aceita uma janela curta para o app aberto depois da hora; a
/// bateria usa o último disparo para não repetir a cada abertura.
bool automacaoVencida(
  Automacao automacao, {
  required DateTime agora,
  int? bateria,
}) {
  if (!automacao.ativa) return false;
  final ultima = automacao.ultimaExecucaoEm;
  switch (automacao.gatilho) {
    case TipoGatilho.horario:
      final alvo = DateTime(
          agora.year, agora.month, agora.day, automacao.hora, automacao.minuto);
      final fim = alvo.add(const Duration(minutes: janelaHorarioMinutos));
      if (agora.isBefore(alvo) || agora.isAfter(fim)) return false;
      return ultima == null || ultima.isBefore(alvo);
    case TipoGatilho.bateriaAbaixo:
      if (bateria == null || bateria > automacao.bateriaLimite) return false;
      return ultima == null ||
          agora.difference(ultima).inHours >= intervaloBateriaHoras;
  }
}

List<Automacao> automacoesVencidas(
  List<Automacao> automacoes, {
  required DateTime agora,
  int? bateria,
}) =>
    automacoes
        .where((a) => automacaoVencida(a, agora: agora, bateria: bateria))
        .toList();

/// Interpreta o prazo digitado. Vazio é `vazio` (sem prazo); texto malformado é
/// `invalido` e a tela pede de novo em vez de adivinhar uma data.
class PrazoLido {
  const PrazoLido.vazio()
      : quando = null,
        erro = null;
  const PrazoLido.ok(this.quando) : erro = null;
  const PrazoLido.invalido(this.erro) : quando = null;

  final DateTime? quando;
  final String? erro;

  bool get vazio => quando == null && erro == null;
}

PrazoLido lerPrazo(String texto, DateTime agora) {
  final limpo = texto.trim();
  if (limpo.isEmpty) return const PrazoLido.vazio();

  final somenteHora = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(limpo);
  if (somenteHora != null) {
    final hora = int.parse(somenteHora.group(1)!);
    final minuto = int.parse(somenteHora.group(2)!);
    if (hora > 23 || minuto > 59) {
      return const PrazoLido.invalido('Horário inválido.');
    }
    var quando = DateTime(agora.year, agora.month, agora.day, hora, minuto);
    if (!quando.isAfter(agora)) {
      quando = quando.add(const Duration(days: 1));
    }
    return PrazoLido.ok(quando);
  }

  final curto = RegExp(r'^(\d{1,2})/(\d{1,2})\s+(\d{1,2}):(\d{2})$')
      .firstMatch(limpo);
  if (curto != null) {
    return _montar(
      ano: agora.year,
      mes: int.parse(curto.group(2)!),
      dia: int.parse(curto.group(1)!),
      hora: int.parse(curto.group(3)!),
      minuto: int.parse(curto.group(4)!),
    );
  }

  final completo =
      RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{1,2}):(\d{2})$')
          .firstMatch(limpo);
  if (completo != null) {
    return _montar(
      ano: int.parse(completo.group(3)!),
      mes: int.parse(completo.group(2)!),
      dia: int.parse(completo.group(1)!),
      hora: int.parse(completo.group(4)!),
      minuto: int.parse(completo.group(5)!),
    );
  }

  final iso =
      RegExp(r'^(\d{4})-(\d{2})-(\d{2})\s+(\d{1,2}):(\d{2})$').firstMatch(limpo);
  if (iso != null) {
    return _montar(
      ano: int.parse(iso.group(1)!),
      mes: int.parse(iso.group(2)!),
      dia: int.parse(iso.group(3)!),
      hora: int.parse(iso.group(4)!),
      minuto: int.parse(iso.group(5)!),
    );
  }

  return const PrazoLido.invalido(
      'Use 19:30, 24/12 19:30 ou 24/12/2026 19:30.');
}

PrazoLido _montar({
  required int ano,
  required int mes,
  required int dia,
  required int hora,
  required int minuto,
}) {
  if (mes < 1 || mes > 12 || dia < 1 || dia > 31) {
    return const PrazoLido.invalido('Data inválida.');
  }
  if (hora > 23 || minuto > 59) {
    return const PrazoLido.invalido('Horário inválido.');
  }
  final quando = DateTime(ano, mes, dia, hora, minuto);
  // DateTime normaliza 31/02 para março; recusar em vez de aceitar outra data.
  if (quando.day != dia || quando.month != mes || quando.year != ano) {
    return const PrazoLido.invalido('Data inválida.');
  }
  return PrazoLido.ok(quando);
}

String? validarTarefa(Tarefa tarefa) {
  if (tarefa.titulo.trim().isEmpty) {
    return 'Informe o título da tarefa.';
  }
  if (tarefa.titulo.length > 160) return 'O título passa de 160 caracteres.';
  if (tarefa.notas.length > 2000) return 'As notas passam de 2000 caracteres.';
  return null;
}

String? validarAutomacao(Automacao automacao) {
  if (automacao.nome.trim().isEmpty) return 'Dê um nome à automação.';
  if (automacao.nome.length > 80) return 'O nome passa de 80 caracteres.';
  if (automacao.gatilho == TipoGatilho.horario &&
      (automacao.hora < 0 ||
          automacao.hora > 23 ||
          automacao.minuto < 0 ||
          automacao.minuto > 59)) {
    return 'Informe um horário entre 00:00 e 23:59.';
  }
  if (automacao.gatilho == TipoGatilho.bateriaAbaixo &&
      (automacao.bateriaLimite < 1 || automacao.bateriaLimite > 100)) {
    return 'O limite de bateria precisa ficar entre 1% e 100%.';
  }
  switch (automacao.acao) {
    case TipoAcaoAutomacao.avisar:
    case TipoAcaoAutomacao.criarTarefa:
      if (automacao.texto.trim().isEmpty) {
        return 'Escreva o texto da ação.';
      }
      if (automacao.texto.length > 1000) {
        return 'O texto passa de 1000 caracteres.';
      }
    case TipoAcaoAutomacao.abrirApp:
      if (automacao.pacote.trim().isEmpty) {
        return 'Informe o pacote do app (ex.: com.spotify.music).';
      }
    case TipoAcaoAutomacao.mensagem:
      if (appMensagemPorId(automacao.app) == null) {
        return 'Escolha um dos apps de mensagem conhecidos.';
      }
      if (automacao.destino.trim().isEmpty) {
        return 'Informe para quem é a mensagem.';
      }
      if (automacao.texto.trim().isEmpty) {
        return 'Escreva o texto da mensagem.';
      }
  }
  return null;
}

List<Tarefa> ordenarTarefas(List<Tarefa> tarefas) {
  final copia = tarefas.toList();
  copia.sort((a, b) {
    if (a.feita != b.feita) return a.feita ? 1 : -1;
    final pa = a.prazo;
    final pb = b.prazo;
    if (pa != null && pb != null) return pa.compareTo(pb);
    if (pa != null) return -1;
    if (pb != null) return 1;
    return b.criadaEm.compareTo(a.criadaEm);
  });
  return copia;
}

List<EventoAutomacao> ordenarHistorico(List<EventoAutomacao> eventos) =>
    eventos.toList()..sort((a, b) => b.quando.compareTo(a.quando));

int itensAguardando(List<ItemFila> fila) =>
    fila.where((i) => i.estado == EstadoFila.aguardandoConfirmacao).length;

int itensPendentes(List<ItemFila> fila) =>
    fila.where((i) => i.estado == EstadoFila.pendente).length;

List<ItemFila> comItemNaFila(List<ItemFila> fila, ItemFila item) {
  final semDuplicado = fila.where((i) => i.id != item.id).toList();
  final proxima = [...semDuplicado, item];
  return proxima.length > limiteFila
      ? proxima.sublist(proxima.length - limiteFila)
      : proxima;
}

List<ItemFila> marcarItemFeito(List<ItemFila> fila, String id) =>
    _mudarItem(fila, id, (i) => i.copiarCom(estado: EstadoFila.feito));

List<ItemFila> marcarItemFalha(
    List<ItemFila> fila, String id, String erro) =>
    _mudarItem(fila, id, (i) {
      final tentativas = i.tentativas + 1;
      return i.copiarCom(
        tentativas: tentativas,
        estado: tentativas >= maxTentativasFila
            ? EstadoFila.falhou
            : EstadoFila.pendente,
        ultimoErro: limparTextoTarefa(erro, 240),
      );
    });

List<ItemFila> cancelarItem(List<ItemFila> fila, String id) =>
    _mudarItem(fila, id, (i) => i.copiarCom(estado: EstadoFila.cancelado));

List<ItemFila> _mudarItem(
        List<ItemFila> fila, String id, ItemFila Function(ItemFila) muda) =>
    fila.map((i) => i.id == id ? muda(i) : i).toList();

List<Tarefa> tarefasDeJson(String? bruto) {
  if (bruto == null || bruto.isEmpty) return const [];
  try {
    final dados = jsonDecode(bruto);
    if (dados is! List) return const [];
    return dados.map(Tarefa.deJson).whereType<Tarefa>().toList();
  } catch (_) {
    return const [];
  }
}

List<Automacao> automacoesDeJson(String? bruto) {
  if (bruto == null || bruto.isEmpty) return const [];
  try {
    final dados = jsonDecode(bruto);
    if (dados is! List) return const [];
    return dados.map(Automacao.deJson).whereType<Automacao>().toList();
  } catch (_) {
    return const [];
  }
}

List<ItemFila> filaDeJson(String? bruto) {
  if (bruto == null || bruto.isEmpty) return const [];
  try {
    final dados = jsonDecode(bruto);
    if (dados is! List) return const [];
    return dados.map(ItemFila.deJson).whereType<ItemFila>().toList();
  } catch (_) {
    return const [];
  }
}

List<EventoAutomacao> historicoDeJson(String? bruto) {
  if (bruto == null || bruto.isEmpty) return const [];
  try {
    final dados = jsonDecode(bruto);
    if (dados is! List) return const [];
    return dados.map(EventoAutomacao.deJson).whereType<EventoAutomacao>().toList();
  } catch (_) {
    return const [];
  }
}

String jsonDeTarefas(List<Tarefa> tarefas) =>
    jsonEncode(tarefas.map((t) => t.paraJson()).toList());

String jsonDeAutomacoes(List<Automacao> automacoes) =>
    jsonEncode(automacoes.map((a) => a.paraJson()).toList());

String jsonDeFila(List<ItemFila> fila) =>
    jsonEncode(fila.map((i) => i.paraJson()).toList());

String jsonDeHistorico(List<EventoAutomacao> eventos) =>
    jsonEncode(eventos.map((e) => e.paraJson()).toList());
