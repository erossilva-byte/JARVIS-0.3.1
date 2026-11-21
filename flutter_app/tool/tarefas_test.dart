// ignore_for_file: avoid_print

import 'package:jarvis_nova/core/tarefas.dart';

int checks = 0;

void ok(String nome) {
  checks++;
  print('OK: $nome');
}

void exigir(bool condicao, String mensagem) {
  if (!condicao) throw StateError(mensagem);
}

Automacao automacao({
  String id = 'a1',
  String nome = 'Rotina',
  bool ativa = true,
  TipoGatilho gatilho = TipoGatilho.horario,
  int hora = 8,
  int minuto = 0,
  int bateriaLimite = 20,
  TipoAcaoAutomacao acao = TipoAcaoAutomacao.avisar,
  String texto = 'Alongar',
  String app = 'whatsapp',
  String destino = '',
  String pacote = '',
  DateTime? ultima,
}) =>
    Automacao(
      id: id,
      nome: nome,
      ativa: ativa,
      gatilho: gatilho,
      hora: hora,
      minuto: minuto,
      bateriaLimite: bateriaLimite,
      acao: acao,
      texto: texto,
      app: app,
      destino: destino,
      pacote: pacote,
      criadaEm: DateTime(2026, 11, 1),
      ultimaExecucaoEm: ultima,
    );

void main() {
  final agora = DateTime(2026, 11, 19, 10, 0);

  // 1. Leitura de prazo.
  exigir(lerPrazo('', agora).vazio, 'prazo vazio');
  final hoje = lerPrazo('19:30', agora);
  exigir(hoje.quando == DateTime(2026, 11, 19, 19, 30), 'prazo de hoje');
  final amanha = lerPrazo('09:00', agora);
  exigir(amanha.quando == DateTime(2026, 11, 20, 9), 'hora passada vira amanhã');
  ok('prazo em hh:mm usa hoje ou amanhã');

  exigir(lerPrazo('24/12 19:30', agora).quando == DateTime(2026, 12, 24, 19, 30),
      'prazo dd/mm');
  exigir(
      lerPrazo('24/12/2027 07:05', agora).quando ==
          DateTime(2027, 12, 24, 7, 5),
      'prazo completo');
  exigir(lerPrazo('2027-01-02 03:04', agora).quando == DateTime(2027, 1, 2, 3, 4),
      'prazo ISO');
  ok('prazo aceita dd/mm, dd/mm/aaaa e ISO');

  exigir(lerPrazo('31/02/2026 10:00', agora).erro != null, 'data inexistente');
  exigir(lerPrazo('25:00', agora).erro != null, 'hora inválida');
  exigir(lerPrazo('amanhã cedo', agora).erro != null, 'texto livre recusado');
  ok('data inválida é recusada em vez de adivinhada');

  // 2. Próxima ocorrência.
  exigir(proximaOcorrencia(11, 0, agora) == DateTime(2026, 11, 19, 11),
      'próxima hoje');
  exigir(proximaOcorrencia(9, 0, agora) == DateTime(2026, 11, 20, 9),
      'próxima amanhã');
  ok('próxima ocorrência do horário');

  // 3. Gatilho de horário com janela e sem repetição.
  exigir(automacaoVencida(automacao(), agora: DateTime(2026, 11, 19, 8, 0)),
      'na hora exata');
  exigir(automacaoVencida(automacao(), agora: DateTime(2026, 11, 19, 8, 4)),
      'dentro da janela');
  exigir(!automacaoVencida(automacao(), agora: DateTime(2026, 11, 19, 8, 6)),
      'fora da janela');
  exigir(
      !automacaoVencida(
        automacao(ultima: DateTime(2026, 11, 19, 8, 1)),
        agora: DateTime(2026, 11, 19, 8, 2),
      ),
      'já executou neste horário');
  exigir(!automacaoVencida(automacao(ativa: false), agora: DateTime(2026, 11, 19, 8)),
      'automação desligada');
  ok('horário respeita janela e última execução');

  // 4. Gatilho de bateria.
  final porBateria = automacao(gatilho: TipoGatilho.bateriaAbaixo);
  exigir(
      automacaoVencida(porBateria, agora: agora, bateria: 15),
      'bateria abaixo do limite');
  exigir(!automacaoVencida(porBateria, agora: agora, bateria: 50),
      'bateria acima do limite');
  exigir(!automacaoVencida(porBateria, agora: agora),
      'bateria desconhecida não dispara');
  exigir(
      !automacaoVencida(
        automacao(
            gatilho: TipoGatilho.bateriaAbaixo,
            ultima: agora.subtract(const Duration(hours: 2))),
        agora: agora,
        bateria: 15,
      ),
      'não repete antes do intervalo');
  exigir(
      automacaoVencida(
        automacao(
            gatilho: TipoGatilho.bateriaAbaixo,
            ultima: agora.subtract(const Duration(hours: 7))),
        agora: agora,
        bateria: 15,
      ),
      'repete depois do intervalo');
  ok('bateria baixa respeita limite e intervalo');

  exigir(
      automacoesVencidas(
        [automacao(), automacao(id: 'a2', ativa: false)],
        agora: DateTime(2026, 11, 19, 8),
      ).length ==
          1,
      'lista de vencidas');
  ok('lista de automações vencidas ignora desligadas');

  // 5. Validação.
  exigir(
      validarTarefa(Tarefa(id: '', titulo: ' ', criadaEm: agora)) != null,
      'tarefa sem título');
  exigir(
      validarTarefa(Tarefa(id: '', titulo: 'Comprar café', criadaEm: agora)) ==
          null,
      'tarefa válida');
  ok('validação de tarefa');

  exigir(validarAutomacao(automacao(nome: ' ')) != null, 'automação sem nome');
  exigir(
      validarAutomacao(automacao(acao: TipoAcaoAutomacao.abrirApp, pacote: '')) !=
          null,
      'abrir app sem pacote');
  exigir(
      validarAutomacao(automacao(
              acao: TipoAcaoAutomacao.mensagem, destino: '', texto: 'oi')) !=
          null,
      'mensagem sem destino');
  exigir(
      validarAutomacao(automacao(
              acao: TipoAcaoAutomacao.mensagem, app: 'app-inexistente')) !=
          null,
      'app de mensagem desconhecido');
  exigir(
      validarAutomacao(automacao(
              acao: TipoAcaoAutomacao.mensagem, destino: 'Ana', texto: 'oi')) ==
          null,
      'mensagem válida');
  ok('validação de automação e das ações sensíveis');

  // 6. Fila.
  final comum = itemFilaDeAutomacao(automacao(), agora);
  exigir(comum.estado == EstadoFila.pendente, 'ação comum nasce pendente');
  final sensivel = itemFilaDeAutomacao(
      automacao(
          acao: TipoAcaoAutomacao.mensagem, destino: 'Ana', texto: 'chego às 9'),
      agora);
  exigir(sensivel.estado == EstadoFila.aguardandoConfirmacao,
      'mensagem nasce aguardando confirmação');
  exigir(sensivel.sensivel && !comum.sensivel, 'sinalização de ação sensível');
  ok('mensagem exige confirmação; demais ações entram pendentes');

  var fila = comItemNaFila([], comum);
  fila = comItemNaFila(fila, comum);
  exigir(fila.length == 1, 'item duplicado não entra duas vezes');
  fila = marcarItemFalha(fila, comum.id, 'sem ponte');
  fila = marcarItemFalha(fila, comum.id, 'sem ponte');
  exigir(fila.single.estado == EstadoFila.pendente &&
      fila.single.tentativas == 2, 'duas tentativas continua pendente');
  fila = marcarItemFalha(fila, comum.id, 'sem ponte');
  exigir(fila.single.estado == EstadoFila.falhou,
      'terceira tentativa encerra a fila');
  ok('fila tenta de novo e desiste no limite');

  var outra = comItemNaFila([], sensivel);
  exigir(itensAguardando(outra) == 1, 'contagem de confirmações');
  outra = marcarItemFeito(outra, sensivel.id);
  exigir(outra.single.estado == EstadoFila.feito, 'item concluído');
  outra = comItemNaFila([], sensivel);
  outra = cancelarItem(outra, sensivel.id);
  exigir(outra.single.estado == EstadoFila.cancelado, 'item recusado');
  ok('contagem, conclusão e recusa da fila');

  // 7. Serialização.
  final tarefa = Tarefa(
    id: 't1',
    titulo: 'Pagar conta',
    notas: 'com juros',
    prazo: DateTime(2026, 12, 1, 9),
    prioridade: PrioridadeTarefa.alta,
    criadaEm: DateTime(2026, 11, 19),
  );
  final volta = Tarefa.deJson(tarefa.paraJson());
  exigir(volta != null && volta.titulo == tarefa.titulo, 'tarefa ida e volta');
  exigir(volta!.prazo == tarefa.prazo && volta.prioridade == PrioridadeTarefa.alta,
      'tarefa mantém prazo e prioridade');
  ok('tarefa exporta e relê');

  final automacaoVolta = Automacao.deJson(automacao(
    acao: TipoAcaoAutomacao.mensagem,
    destino: 'Ana',
  ).paraJson());
  exigir(automacaoVolta != null &&
      automacaoVolta.acao == TipoAcaoAutomacao.mensagem &&
      automacaoVolta.destino == 'Ana', 'automação ida e volta');
  exigir(Automacao.deJson({'id': 'x'}) == null, 'automação sem nome recusada');
  exigir(Tarefa.deJson('lixo') == null, 'lixo não vira tarefa');
  exigir(tarefasDeJson('{').isEmpty && automacoesDeJson('x').isEmpty,
      'json corrompido vira lista vazia');
  ok('serialização tolerante a dados inválidos');

  // 8. Id do alarme estável.
  final a = idLembrete('t_1');
  exigir(a == idLembrete('t_1') && a > 0, 'id estável');
  exigir(a != idLembrete('t_2'), 'ids diferentes não colidem');
  ok('id de lembrete estável e positivo');

  // 9. Ordem das tarefas.
  final lista = ordenarTarefas([
    Tarefa(id: '1', titulo: 'feita', feita: true, criadaEm: agora),
    Tarefa(
        id: '2',
        titulo: 'sem prazo',
        criadaEm: agora.subtract(const Duration(hours: 1))),
    Tarefa(
        id: '3',
        titulo: 'amanhã',
        prazo: DateTime(2026, 11, 20),
        criadaEm: agora),
    Tarefa(
        id: '4',
        titulo: 'hoje',
        prazo: DateTime(2026, 11, 19, 18),
        criadaEm: agora),
  ]);
  exigir(lista.map((t) => t.id).join(',') == '4,3,2,1',
      'ordem: prazo, sem prazo, concluídas');
  ok('ordenação coloca pendentes com prazo no topo');

  // 10. Texto limpo.
  exigir(limparTextoTarefa('  <b>oi</b>  ', 40) == 'boi/b', 'remove <>');
  exigir(limparTextoTarefa('a' * 200, 10).length == 10, 'corta no limite');
  ok('limpeza de texto remove marcação e corta no limite');

  print('\n$checks verificações de tarefas e automações aprovadas.');
}
