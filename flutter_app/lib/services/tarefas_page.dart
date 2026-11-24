import 'package:material_ui/material_ui.dart';

import '../core/aparelho.dart';
import '../core/tarefas.dart';
import '../ui_common.dart';
import 'agenda_service.dart';
import 'aparelho_service.dart';
import 'tarefas_store.dart';

/// Tarefas e automações — segundo bloco da Fase 11.
///
/// Tarefas e automações ficam no armazenamento local. O aviso de horário é
/// agendado no `AlarmManager` do Android; as demais ações rodam quando o app
/// está aberto (ou são tentadas de novo na abertura, pela fila offline).
/// Mensagem é ação sensível: a tela só prepara a conversa depois do toque em
/// "Confirmar"; o envio continua sendo do usuário.
class TarefasPage extends StatefulWidget {
  const TarefasPage({super.key, this.store, this.agenda, this.aparelho});

  final TarefasStore? store;
  final AgendaService? agenda;
  final AparelhoService? aparelho;

  @override
  State<TarefasPage> createState() => _TarefasPageState();
}

class _TarefasPageState extends State<TarefasPage> {
  late final AgendaService _agenda = widget.agenda ?? AgendaService();
  late final AparelhoService _aparelho = widget.aparelho ?? AparelhoService();

  TarefasStore? _store;
  List<Tarefa> _tarefas = const [];
  List<Automacao> _automacoes = const [];
  List<ItemFila> _fila = const [];
  List<EventoAutomacao> _historico = const [];

  bool _carregando = true;
  bool _processando = false;
  String? _erro;
  bool? _alarmeHorarioOk;
  int? _bateria;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final store = widget.store ?? await TarefasStore.abrir();
      _store = store;
      _tarefas = store.tarefas();
      _automacoes = store.automacoes();
      _fila = store.fila();
      _historico = store.historico();
      if (!mounted) return;
      setState(() => _carregando = false);
      await _lerBateria();
      await _sincronizarAlarmes();
      await _processarFila();
      await _verificarAutomacoes();
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não consegui abrir a agenda local: $erro';
        _carregando = false;
      });
    }
  }

  Future<void> _lerBateria() async {
    try {
      final info = await _aparelho.infoDispositivo();
      _bateria = info.bateria;
    } on AparelhoIndisponivel {
      _bateria = null;
    }
  }

  Future<void> _sincronizarAlarmes() async {
    final store = _store;
    if (store == null) return;
    var algumFalhou = false;
    for (final automacao in _automacoes) {
      if (!automacao.ativa ||
          automacao.gatilho != TipoGatilho.horario ||
          automacao.acao != TipoAcaoAutomacao.avisar) {
        continue;
      }
      final quando = proximaOcorrenciaAutomacao(automacao, DateTime.now());
      if (quando == null) continue;
      final ok = await _agenda.agendar(
        id: idLembrete(automacao.id),
        titulo: 'JARVIS · ${automacao.nome}',
        texto: automacao.texto,
        quando: quando,
        repeticao: automacao.recorrencia,
      );
      if (!ok) algumFalhou = true;
    }
    if (mounted) setState(() => _alarmeHorarioOk = !algumFalhou);
  }

  Future<void> _verificarAutomacoes() async {
    final store = _store;
    if (store == null) return;
    final agora = DateTime.now();
    final vencidas =
        automacoesVencidas(_automacoes, agora: agora, bateria: _bateria);
    for (final automacao in vencidas) {
      await _executarAutomacao(automacao, agora);
    }
    if (mounted) setState(() {});
  }

  Future<void> _executarAutomacao(Automacao automacao, DateTime agora) async {
    final store = _store;
    if (store == null) return;
    final item = itemFilaDeAutomacao(automacao, agora);
    _fila = comItemNaFila(_fila, item);
    _automacoes = _automacoes
        .map((a) => a.id == automacao.id
            ? a.copiarCom(ultimaExecucaoEm: agora)
            : a)
        .toList();
    await store.salvarFila(_fila);
    await store.marcarExecucao(automacao.id, agora);
    if (automacao.sensivel) {
      await _registrarEvento(automacao.nome, EstadoEvento.aguardandoConfirmacao,
          'Confirme para abrir a conversa; o envio continua seu.');
    } else {
      await _processarFila();
    }
    if (mounted) setState(() {});
  }

  /// Tenta de novo tudo que ficou pendente — é a fila offline.
  Future<void> _processarFila() async {
    if (_processando) return;
    final store = _store;
    if (store == null) return;
    _processando = true;
    final eventos = <EventoAutomacao>[];
    for (final item in List.of(_fila)) {
      if (item.estado != EstadoFila.pendente) continue;
      final (ok, detalhe) = await _executarItem(item);
      if (ok) {
        _fila = marcarItemFeito(_fila, item.id);
        eventos.add(_evento(item.titulo, EstadoEvento.executada, detalhe));
      } else {
        _fila = marcarItemFalha(_fila, item.id, detalhe);
        final atual = _fila.firstWhere((i) => i.id == item.id);
        if (atual.estado == EstadoFila.falhou) {
          eventos.add(_evento(item.titulo, EstadoEvento.falhou, detalhe));
        }
      }
    }
    await store.salvarFila(_fila);
    for (final evento in eventos.reversed) {
      _historico = [evento, ..._historico];
    }
    if (eventos.isNotEmpty) {
      await store.salvarHistorico(
          _historico.take(limiteHistorico).toList());
    }
    _processando = false;
    if (mounted) setState(() {});
  }

  Future<(bool, String)> _executarItem(ItemFila item) async {
    switch (item.acao) {
      case TipoAcaoAutomacao.avisar:
        final ok = await _agenda.agendar(
          id: idLembrete(item.id),
          titulo: 'JARVIS · ${item.titulo}',
          texto: item.texto,
          quando: DateTime.now().add(const Duration(seconds: 2)),
        );
        return (
          ok,
          ok
              ? 'Aviso entregue ao Android.'
              : 'O Android não confirmou o agendamento do aviso.'
        );
      case TipoAcaoAutomacao.criarTarefa:
        final resultado = await _store!.salvarTarefa(Tarefa(
          id: '',
          titulo: item.texto,
          notas: 'Criada pela automação "${item.titulo}".',
          origem: 'automacao',
          criadaEm: DateTime.now(),
        ));
        if (resultado.ok) _tarefas = _store!.tarefas();
        return (
          resultado.ok,
          resultado.erro ?? 'Tarefa criada pela automação.'
        );
      case TipoAcaoAutomacao.abrirApp:
        try {
          final resultado = await _aparelho.abrirApp(item.pacote);
          return (resultado.ok, resultado.mensagem);
        } on AparelhoIndisponivel catch (erro) {
          return (false, erro.mensagem);
        }
      case TipoAcaoAutomacao.mensagem:
        return (false, 'Ação sensível: precisa do seu toque em Confirmar.');
    }
  }

  Future<void> _confirmar(ItemFila item) async {
    final app = appMensagemPorId(item.app);
    if (app == null) {
      _snack('O app de mensagem "${item.app}" não está na lista conhecida.');
      return;
    }
    try {
      final resultado = await _aparelho.enviarMensagem(PedidoMensagem(
        app: app,
        destino: item.destino,
        texto: item.texto,
      ));
      _fila = resultado.ok
          ? marcarItemFeito(_fila, item.id)
          : marcarItemFalha(_fila, item.id, resultado.mensagem);
      await _store?.salvarFila(_fila);
      await _registrarEvento(
        item.titulo,
        resultado.ok ? EstadoEvento.executada : EstadoEvento.falhou,
        resultado.mensagem,
      );
      if (mounted) setState(() {});
      _snack(resultado.mensagem);
    } on AparelhoIndisponivel catch (erro) {
      _snack(erro.mensagem);
    }
  }

  Future<void> _recusar(ItemFila item) async {
    _fila = cancelarItem(_fila, item.id);
    await _store?.salvarFila(_fila);
    await _registrarEvento(
        item.titulo, EstadoEvento.ignorada, 'Você recusou esta ação.');
    if (mounted) setState(() {});
  }

  Future<void> _registrarEvento(
      String nome, EstadoEvento estado, String detalhe) async {
    final evento = _evento(nome, estado, detalhe);
    _historico = [evento, ..._historico];
    await _store?.salvarHistorico(_historico.take(limiteHistorico).toList());
    if (mounted) setState(() {});
  }

  int _sequenciaEvento = 0;

  EventoAutomacao _evento(
      String nome, EstadoEvento estado, String detalhe) {
    final agora = DateTime.now();
    return EventoAutomacao(
      id: 'e_${agora.microsecondsSinceEpoch}_${_sequenciaEvento++}',
      automacaoId: '',
      nome: nome,
      quando: agora,
      estado: estado,
      detalhe: detalhe,
    );
  }

  Future<void> _novaTarefa({Tarefa? existente}) async {
    final titulo = TextEditingController(text: existente?.titulo ?? '');
    final prazo = TextEditingController(
        text: existente?.prazo == null ? '' : _prazoTexto(existente!.prazo!));
    final notas = TextEditingController(text: existente?.notas ?? '');
    var prioridade = existente?.prioridade ?? PrioridadeTarefa.normal;
    var recorrencia = existente?.recorrencia ?? Recorrencia.umaVez;
    final salvar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, atualizar) => AlertDialog(
          title: Text(existente == null ? 'Nova tarefa' : 'Editar tarefa',
              style: const TextStyle(fontSize: 15)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                key: const ValueKey('tarefa-titulo'),
                controller: titulo,
                autofocus: true,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('tarefa-prazo'),
                controller: prazo,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'Prazo (opcional)',
                  hintText: '19:30, 24/12 19:30 ou 24/12/2026 19:30',
                  hintStyle: TextStyle(fontSize: 10, color: muted),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<PrioridadeTarefa>(
                key: ValueKey('tarefa-prioridade-${prioridade.name}'),
                initialValue: prioridade,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Prioridade'),
                items: [
                  for (final p in PrioridadeTarefa.values)
                    DropdownMenuItem(value: p, child: Text(p.rotulo)),
                ],
                onChanged: (valor) {
                  if (valor == null) return;
                  atualizar(() => prioridade = valor);
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<Recorrencia>(
                key: ValueKey('tarefa-recorrencia-${recorrencia.name}'),
                initialValue: recorrencia,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Repetir'),
                items: [
                  for (final r in Recorrencia.values)
                    DropdownMenuItem(
                        value: r,
                        child: Text(r.rotulo,
                            style: const TextStyle(fontSize: 11))),
                ],
                onChanged: (valor) {
                  if (valor == null) return;
                  atualizar(() => recorrencia = valor);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('tarefa-notas'),
                controller: notas,
                maxLines: 2,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(labelText: 'Notas (opcional)'),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const ValueKey('tarefa-salvar'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (salvar != true) return;
    final lido = lerPrazo(prazo.text, DateTime.now());
    if (lido.erro != null) {
      _snack(lido.erro!);
      return;
    }
    final resultado = await _store!.salvarTarefa(Tarefa(
      id: existente?.id ?? '',
      titulo: titulo.text,
      notas: notas.text,
      prazo: lido.quando,
      prioridade: prioridade,
      origem: existente?.origem ?? 'manual',
      recorrencia: recorrencia,
      criadaEm: existente?.criadaEm ?? DateTime.now(),
      concluidaEm: existente?.concluidaEm,
    ));
    if (!resultado.ok) {
      _snack(resultado.erro!);
      return;
    }
    _tarefas = _store!.tarefas();
    final tarefa = resultado.valor!;
    if (tarefa.prazo != null && tarefa.prazo!.isAfter(DateTime.now())) {
      final agendou = await _agenda.agendar(
        id: tarefa.lembreteId,
        titulo: 'JARVIS · tarefa',
        texto: tarefa.titulo,
        quando: tarefa.prazo!,
      );
      if (!agendou) {
        _snack('Tarefa salva; o Android não confirmou o lembrete.');
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _alternarTarefa(Tarefa tarefa) async {
    final ficouFeita = !tarefa.feita;
    final erro = await _store!.marcarFeita(tarefa.id, ficouFeita);
    if (erro != null) {
      _snack(erro);
      return;
    }
    if (ficouFeita) {
      await _agenda.cancelar(tarefa.lembreteId);
      // Tarefa que repete gera a próxima data com o mesmo horário.
      if (tarefa.recorrencia.repete && tarefa.prazo != null) {
        final proximo = proximaDataTarefa(tarefa.prazo!, tarefa.recorrencia);
        final nova = await _store!.salvarTarefa(Tarefa(
          id: '',
          titulo: tarefa.titulo,
          notas: tarefa.notas,
          prazo: proximo,
          prioridade: tarefa.prioridade,
          origem: tarefa.origem,
          recorrencia: tarefa.recorrencia,
          criadaEm: DateTime.now(),
        ));
        if (nova.ok) {
          await _agenda.agendar(
            id: nova.valor!.lembreteId,
            titulo: 'JARVIS · tarefa',
            texto: nova.valor!.titulo,
            quando: proximo,
            repeticao: tarefa.recorrencia,
          );
          _snack('Tarefa concluída; a próxima ficou para ${nova.valor!.prazoRotulo}.');
        }
      }
    } else if (tarefa.prazo != null &&
        tarefa.prazo!.isAfter(DateTime.now())) {
      await _agenda.agendar(
        id: tarefa.lembreteId,
        titulo: 'JARVIS · tarefa',
        texto: tarefa.titulo,
        quando: tarefa.prazo!,
      );
    }
    _tarefas = _store!.tarefas();
    if (mounted) setState(() {});
  }

  Future<void> _apagarTarefa(Tarefa tarefa) async {
    await _agenda.cancelar(tarefa.lembreteId);
    final apagou = await _store!.apagarTarefa(tarefa.id);
    if (!apagou) {
      _snack('Não foi possível apagar a tarefa.');
      return;
    }
    _tarefas = _store!.tarefas();
    if (mounted) setState(() {});
  }

  Future<void> _novaAutomacao({Automacao? existente}) async {
    final nome = TextEditingController(text: existente?.nome ?? '');
    final hora = TextEditingController(
        text: existente == null
            ? '08:00'
            : horarioRotulo(existente.hora, existente.minuto));
    final bateria =
        TextEditingController(text: '${existente?.bateriaLimite ?? 20}');
    final texto = TextEditingController(text: existente?.texto ?? '');
    final destino = TextEditingController(text: existente?.destino ?? '');
    final pacote = TextEditingController(text: existente?.pacote ?? '');
    final diaMes = TextEditingController(text: '${existente?.diaDoMes ?? 1}');
    final diaAno = TextEditingController(
        text: existente == null
            ? '01/01'
            : '${doisDigitos(existente.diaAno)}/${doisDigitos(existente.mesAno)}');
    var gatilho = existente?.gatilho ?? TipoGatilho.horario;
    var acao = existente?.acao ?? TipoAcaoAutomacao.avisar;
    var app = existente?.app ?? 'whatsapp';
    var recorrencia = existente != null && existente.recorrencia.repete
        ? existente.recorrencia
        : Recorrencia.diaria;
    final diasSemana = <int>{...?existente?.diasSemana};
    final salvar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, atualizar) => AlertDialog(
          title: Text(existente == null ? 'Nova automação' : 'Editar automação',
              style: const TextStyle(fontSize: 15)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                key: const ValueKey('automacao-nome'),
                controller: nome,
                autofocus: true,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<TipoGatilho>(
                key: ValueKey('automacao-gatilho-${gatilho.name}'),
                initialValue: gatilho,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Quando'),
                items: [
                  for (final g in TipoGatilho.values)
                    DropdownMenuItem(value: g, child: Text(g.rotulo)),
                ],
                onChanged: (valor) {
                  if (valor == null) return;
                  atualizar(() => gatilho = valor);
                },
              ),
              const SizedBox(height: 8),
              if (gatilho == TipoGatilho.horario)
                TextField(
                  key: const ValueKey('automacao-hora'),
                  controller: hora,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                      labelText: 'Horário', hintText: '07:30'),
                )
              else
                TextField(
                  key: const ValueKey('automacao-bateria'),
                  controller: bateria,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 12),
                  decoration:
                      const InputDecoration(labelText: 'Bateria abaixo de (%)'),
                ),
              if (gatilho == TipoGatilho.horario) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<Recorrencia>(
                  key: ValueKey('automacao-recorrencia-${recorrencia.name}'),
                  initialValue: recorrencia,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Repetir'),
                  items: [
                    for (final r in [
                      Recorrencia.diaria,
                      Recorrencia.semanal,
                      Recorrencia.mensal,
                      Recorrencia.anual,
                    ])
                      DropdownMenuItem(
                          value: r,
                          child: Text(r.rotulo,
                              style: const TextStyle(fontSize: 11))),
                  ],
                  onChanged: (valor) {
                    if (valor == null) return;
                    atualizar(() => recorrencia = valor);
                  },
                ),
                if (recorrencia == Recorrencia.semanal) ...[
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Dias da semana',
                        style: TextStyle(fontSize: 11, color: muted)),
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (var dia = 1; dia <= 7; dia++)
                        FilterChip(
                          key: ValueKey('automacao-dia-semana-$dia'),
                          label: Text(nomeDoDia(dia),
                              style: const TextStyle(fontSize: 10)),
                          selected: diasSemana.contains(dia),
                          onSelected: (marcado) => atualizar(() {
                            if (marcado) {
                              diasSemana.add(dia);
                            } else {
                              diasSemana.remove(dia);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
                if (recorrencia == Recorrencia.mensal) ...[
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('automacao-dia-mes'),
                    controller: diaMes,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                        labelText: 'Dia do mês (1 a 31)',
                        helperText:
                            'Mês sem esse dia usa o último dia do mês.',
                        helperStyle: TextStyle(fontSize: 9, color: muted)),
                  ),
                ],
                if (recorrencia == Recorrencia.anual) ...[
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('automacao-dia-ano'),
                    controller: diaAno,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                        labelText: 'Dia e mês do ano',
                        hintText: '25/12'),
                  ),
                ],
              ],
              const SizedBox(height: 8),
              DropdownButtonFormField<TipoAcaoAutomacao>(
                key: ValueKey('automacao-acao-${acao.name}'),
                initialValue: acao,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Ação'),
                items: [
                  for (final a in TipoAcaoAutomacao.values)
                    DropdownMenuItem(
                        value: a,
                        child: Text(a.rotulo,
                            style: const TextStyle(fontSize: 11))),
                ],
                onChanged: (valor) {
                  if (valor == null) return;
                  atualizar(() => acao = valor);
                },
              ),
              const SizedBox(height: 8),
              if (acao == TipoAcaoAutomacao.mensagem) ...[
                DropdownButtonFormField<String>(
                  key: ValueKey('automacao-app-$app'),
                  initialValue: app,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'App'),
                  items: [
                    for (final aplicativo in appsMensagem)
                      DropdownMenuItem(
                          value: aplicativo.id,
                          child: Text(aplicativo.nome,
                              style: const TextStyle(fontSize: 11))),
                  ],
                  onChanged: (valor) {
                    if (valor == null) return;
                    atualizar(() => app = valor);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('automacao-destino'),
                  controller: destino,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                      labelText: 'Para quem (nome ou número)'),
                ),
                const SizedBox(height: 8),
              ],
              if (acao == TipoAcaoAutomacao.abrirApp)
                TextField(
                  key: const ValueKey('automacao-pacote'),
                  controller: pacote,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                      labelText: 'Pacote do app',
                      hintText: 'com.spotify.music'),
                ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('automacao-texto'),
                controller: texto,
                maxLines: 2,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                    labelText: 'Texto (aviso, tarefa ou mensagem)'),
              ),
              const SizedBox(height: 10),
              const Text(
                'Mensagem é ação sensível: a automação prepara a conversa e '
                'espera o seu "Confirmar". Nada é enviado sozinho.',
                style: TextStyle(fontSize: 10, color: muted, height: 1.4),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const ValueKey('automacao-salvar'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (salvar != true) return;

    var horaValor = 8;
    var minutoValor = 0;
    if (gatilho == TipoGatilho.horario) {
      final partes = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hora.text.trim());
      if (partes == null) {
        _snack('Informe o horário como 07:30.');
        return;
      }
      horaValor = int.parse(partes.group(1)!);
      minutoValor = int.parse(partes.group(2)!);
    }
    final limite = int.tryParse(bateria.text.trim()) ?? 20;

    // Recorrência só vale para gatilho de horário; bateria não tem dia.
    var diasEscolhidos = <int>[];
    var diaDoMesValor = 1;
    var mesValor = 1;
    var diaDoAnoValor = 1;
    var recorrenciaValor = Recorrencia.diaria;
    if (gatilho == TipoGatilho.horario) {
      recorrenciaValor = recorrencia;
      if (recorrencia == Recorrencia.semanal) {
        if (diasSemana.isEmpty) {
          _snack('Escolha pelo menos um dia da semana.');
          return;
        }
        diasEscolhidos = diasSemana.toList()..sort();
      }
      if (recorrencia == Recorrencia.mensal) {
        final dia = int.tryParse(diaMes.text.trim());
        if (dia == null || dia < 1 || dia > 31) {
          _snack('Informe o dia do mês entre 1 e 31.');
          return;
        }
        diaDoMesValor = dia;
      }
      if (recorrencia == Recorrencia.anual) {
        final partes =
            RegExp(r'^(\d{1,2})/(\d{1,2})$').firstMatch(diaAno.text.trim());
        final dia = partes == null ? null : int.tryParse(partes.group(1)!);
        final mes = partes == null ? null : int.tryParse(partes.group(2)!);
        if (dia == null || mes == null || dia < 1 || dia > 31 || mes < 1 || mes > 12) {
          _snack('Informe dia e mês como 25/12.');
          return;
        }
        diaDoAnoValor = dia;
        mesValor = mes;
      }
    }

    final resultado = await _store!.salvarAutomacao(Automacao(
      id: existente?.id ?? '',
      nome: nome.text,
      ativa: existente?.ativa ?? true,
      gatilho: gatilho,
      hora: horaValor,
      minuto: minutoValor,
      recorrencia: recorrenciaValor,
      diasSemana: diasEscolhidos,
      diaDoMes: diaDoMesValor,
      mesAno: mesValor,
      diaAno: diaDoAnoValor,
      bateriaLimite: limite,
      acao: acao,
      texto: texto.text,
      app: app,
      destino: destino.text,
      pacote: pacote.text,
      criadaEm: existente?.criadaEm ?? DateTime.now(),
      ultimaExecucaoEm: existente?.ultimaExecucaoEm,
    ));
    if (!resultado.ok) {
      _snack(resultado.erro!);
      return;
    }
    _automacoes = _store!.automacoes();
    await _sincronizarAlarmes();
    if (mounted) setState(() {});
  }

  Future<void> _alternarAutomacao(Automacao automacao, bool ativa) async {
    final resultado =
        await _store!.salvarAutomacao(automacao.copiarCom(ativa: ativa));
    if (!resultado.ok) {
      _snack(resultado.erro!);
      return;
    }
    if (!ativa) await _agenda.cancelar(idLembrete(automacao.id));
    _automacoes = _store!.automacoes();
    await _sincronizarAlarmes();
    if (mounted) setState(() {});
  }

  Future<void> _apagarAutomacao(Automacao automacao) async {
    await _agenda.cancelar(idLembrete(automacao.id));
    final apagou = await _store!.apagarAutomacao(automacao.id);
    if (!apagou) {
      _snack('Não foi possível apagar a automação.');
      return;
    }
    _automacoes = _store!.automacoes();
    if (mounted) setState(() {});
  }

  void _snack(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title:
              const Text('Tarefas e automações', style: TextStyle(fontSize: 15)),
          actions: [
            IconButton(
              key: const ValueKey('agenda-atualizar'),
              onPressed: _carregando ? null : _carregar,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Atualizar',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tarefas'),
              Tab(text: 'Automações'),
              Tab(text: 'Histórico'),
            ],
          ),
        ),
        body: _carregando
            ? const Center(child: CircularProgressIndicator())
            : _erro != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Text(_erro!,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFFFF8A80))),
                    ),
                  )
                : TabBarView(
                    children: [
                      _abaTarefas(),
                      _abaAutomacoes(),
                      _abaHistorico(),
                    ],
                  ),
      ),
    );
  }

  Widget _abaTarefas() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      FilledButton.icon(
        key: const ValueKey('tarefa-nova'),
        onPressed: _novaTarefa,
        icon: const Icon(Icons.add_task_rounded, size: 18),
        label: const Text('Nova tarefa'),
      ),
      const SizedBox(height: 14),
      if (_tarefas.isEmpty)
        const Text('Nenhuma tarefa ainda.',
            style: TextStyle(fontSize: 11, color: muted))
      else
        for (final tarefa in _tarefas)
          Container(
            key: ValueKey('tarefa-${tarefa.id}'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: cyan.withValues(alpha: .10)),
            ),
            child: Row(children: [
              Checkbox(
                key: ValueKey('tarefa-feita-${tarefa.id}'),
                value: tarefa.feita,
                onChanged: (_) => _alternarTarefa(tarefa),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tarefa.titulo,
                      style: TextStyle(
                        fontSize: 12,
                        decoration:
                            tarefa.feita ? TextDecoration.lineThrough : null,
                        color: tarefa.feita ? muted : null,
                      ),
                    ),
                    Text(
                      '${tarefa.prioridade.rotulo} · ${tarefa.prazoRotulo}'
                      '${tarefa.atrasada(DateTime.now()) ? ' · atrasada' : ''}'
                      '${tarefa.origem == 'automacao' ? ' · criada por automação' : ''}',
                      style: const TextStyle(fontSize: 10, color: muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey('tarefa-apagar-${tarefa.id}'),
                onPressed: () => _apagarTarefa(tarefa),
              ),
              TextButton(
                key: ValueKey('tarefa-editar-${tarefa.id}'),
                onPressed: () => _novaTarefa(existente: tarefa),
                child: const Text('Editar',
                    style: TextStyle(fontSize: 10, color: cyan)),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                tooltip: 'Apagar',
              ),
            ]),
          ),
      const SizedBox(height: 12),
      const Text(
        'O prazo aceita 19:30 (hoje ou amanhã), 24/12 19:30 ou '
        '24/12/2026 19:30. Com prazo, o Android recebe um alarme; sem prazo, '
        'a tarefa fica só na lista. Tarefas e prazos ficam neste aparelho.',
        style: TextStyle(fontSize: 10, color: muted, height: 1.5),
      ),
    ]);
  }

  Widget _abaAutomacoes() {
    final aguardando =
        _fila.where((i) => i.estado == EstadoFila.aguardandoConfirmacao).toList();
    final naFila = _fila
        .where((i) =>
            i.estado == EstadoFila.pendente || i.estado == EstadoFila.falhou)
        .toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Expanded(
          child: FilledButton.icon(
            key: const ValueKey('automacao-nova'),
            onPressed: _novaAutomacao,
            icon: const Icon(Icons.bolt_rounded, size: 18),
            label: const Text('Nova automação'),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          key: const ValueKey('automacoes-verificar'),
          onPressed: () async {
            await _verificarAutomacoes();
            if (mounted) setState(() {});
            _snack(_automacoes.isEmpty
                ? 'Nenhuma automação criada.'
                : 'Verifiquei as automações para agora.');
          },
          child: const Text('Verificar', style: TextStyle(fontSize: 11)),
        ),
      ]),
      if (_bateria != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Bateria lida agora: $_bateria%',
              style: const TextStyle(fontSize: 10, color: muted)),
        ),
      if (_alarmeHorarioOk == false)
        _aviso(
            'O Android não confirmou o alarme de uma automação de horário. '
            'A rotina continua salva, mas o aviso pode não tocar.',
            const Color(0xFFFFD27F)),
      if (aguardando.isNotEmpty) ...[
        const SizedBox(height: 16),
        Eyebrow('AGUARDANDO CONFIRMAÇÃO (${aguardando.length})'),
        for (final item in aguardando)
          Container(
            key: ValueKey('fila-${item.id}'),
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD27F).withValues(alpha: .08),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: const Color(0xFFFFD27F).withValues(alpha: .25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.descricao,
                    style: const TextStyle(fontSize: 11, height: 1.4)),
                const SizedBox(height: 6),
                Row(children: [
                  FilledButton(
                    key: ValueKey('fila-confirmar-${item.id}'),
                    onPressed: () => _confirmar(item),
                    child: const Text('Confirmar',
                        style: TextStyle(fontSize: 10)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    key: ValueKey('fila-recusar-${item.id}'),
                    onPressed: () => _recusar(item),
                    child: const Text('Recusar',
                        style: TextStyle(fontSize: 10)),
                  ),
                ]),
              ],
            ),
          ),
      ],
      if (naFila.isNotEmpty) ...[
        const SizedBox(height: 16),
        Eyebrow('FILA (${naFila.length})'),
        for (final item in naFila)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${item.descricao} · ${item.estado.rotulo} '
              '(${item.tentativas}/$maxTentativasFila)'
              '${item.ultimoErro.isEmpty ? '' : ' · ${item.ultimoErro}'}',
              style: const TextStyle(fontSize: 10, color: muted, height: 1.4),
            ),
          ),
        const SizedBox(height: 6),
        TextButton(
          key: const ValueKey('fila-reenviar'),
          onPressed: _processarFila,
          child: const Text('Tentar de novo agora',
              style: TextStyle(fontSize: 10)),
        ),
      ],
      const SizedBox(height: 16),
      Eyebrow('AUTOMAÇÕES (${_automacoes.length})'),
      if (_automacoes.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('Nenhuma automação criada.',
              style: TextStyle(fontSize: 11, color: muted)),
        ),
      for (final automacao in _automacoes)
        Container(
          key: ValueKey('automacao-${automacao.id}'),
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: cyan.withValues(alpha: .10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(automacao.nome,
                      style: const TextStyle(fontSize: 12)),
                ),
                Switch(
                  key: ValueKey('automacao-ativa-${automacao.id}'),
                  value: automacao.ativa,
                  onChanged: (valor) => _alternarAutomacao(automacao, valor),
                ),
              ]),
              Text(
                '${automacao.descricaoGatilho}\n${automacao.descricaoAcao}',
                style: const TextStyle(fontSize: 10, color: muted, height: 1.4),
              ),
              if (automacao.ultimaExecucaoEm != null)
                Text(
                  'Última execução: ${automacao.ultimaExecucaoEm!.day.toString().padLeft(2, '0')}/'
                  '${automacao.ultimaExecucaoEm!.month.toString().padLeft(2, '0')} '
                  '${horarioRotulo(automacao.ultimaExecucaoEm!.hour, automacao.ultimaExecucaoEm!.minute)}',
                  style: const TextStyle(fontSize: 10, color: muted),
                ),
              Row(children: [
                TextButton(
                  key: ValueKey('automacao-executar-${automacao.id}'),
                  onPressed: () async {
                    await _executarAutomacao(automacao, DateTime.now());
                    _snack(automacao.sensivel
                        ? 'Ação sensível: confirme na lista acima.'
                        : 'Automação executada.');
                  },
                  child: const Text('Executar agora',
                      style: TextStyle(fontSize: 10)),
                ),
                TextButton(
                  key: ValueKey('automacao-editar-${automacao.id}'),
                  onPressed: () => _novaAutomacao(existente: automacao),
                  child: const Text('Editar',
                      style: TextStyle(fontSize: 10)),
                ),
                TextButton(
                  key: ValueKey('automacao-apagar-${automacao.id}'),
                  onPressed: () => _apagarAutomacao(automacao),
                  child: const Text('Apagar',
                      style: TextStyle(fontSize: 10, color: muted)),
                ),
              ]),
            ],
          ),
        ),
      const SizedBox(height: 14),
      const Text(
        'Automação de horário com aviso é entregue ao AlarmManager do '
        'Android, inclusive com o app fechado. A repetição escolhe os dias: '
        'diária e semanal o Android repete sozinho; mensal e anual são '
        'agendadas para a próxima data e reprogramadas quando o app abre. Automações de bateria, de abrir app e de '
        'criar tarefa são avaliadas quando o app está aberto (ou ao tocar em '
        'Verificar); a fila tenta de novo o que falhou, até '
        '$maxTentativasFila vezes. Mensagem nunca é enviada sozinha.',
        style: TextStyle(fontSize: 10, color: muted, height: 1.5),
      ),
    ]);
  }

  Widget _abaHistorico() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Eyebrow('HISTÓRICO (${_historico.length})'),
      const SizedBox(height: 8),
      if (_historico.isEmpty)
        const Text('Nenhuma execução registrada ainda.',
            style: TextStyle(fontSize: 11, color: muted))
      else
        for (final evento in _historico)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${evento.quandoRotulo} · ${evento.nome} · '
                  '${evento.estado.rotulo}',
                  style: const TextStyle(fontSize: 11),
                ),
                if (evento.detalhe.isNotEmpty)
                  Text(evento.detalhe,
                      style: const TextStyle(fontSize: 10, color: muted)),
              ],
            ),
          ),
      const SizedBox(height: 14),
      const Text(
        'O histórico guarda as últimas $limiteHistorico execuções neste '
        'aparelho. Ele registra o que o Android respondeu — não uma promessa '
        'de que o efeito aconteceu.',
        style: TextStyle(fontSize: 10, color: muted, height: 1.5),
      ),
    ]);
  }

  /// Texto do prazo no formato que o próprio campo aceita.
  String _prazoTexto(DateTime quando) =>
      '${doisDigitos(quando.day)}/${doisDigitos(quando.month)}/'
      '${quando.year} ${horarioRotulo(quando.hour, quando.minute)}';

  Widget _aviso(String texto, Color cor) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: cor.withValues(alpha: .25)),
        ),
        child: Text(texto, style: TextStyle(fontSize: 11, color: cor)),
      );
}
