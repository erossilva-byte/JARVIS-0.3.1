// ignore_for_file: avoid_print

import 'package:jarvis_nova/core/tarefas.dart';

int checks = 0;

void ok(String nome) {
  checks++;
  print('OK: $nome');
}

void exigir(bool condicao, String mensagem) {
  if (!condicao) {
    print('FALHOU: $mensagem');
    throw StateError(mensagem);
  }
}

Automacao automacao({
  Recorrencia recorrencia = Recorrencia.diaria,
  List<int> diasSemana = const [],
  int diaDoMes = 1,
  int mesAno = 1,
  int diaAno = 1,
  int hora = 8,
  int minuto = 0,
  DateTime? ultima,
}) =>
    Automacao(
      id: 'a1',
      nome: 'teste',
      recorrencia: recorrencia,
      diasSemana: diasSemana,
      diaDoMes: diaDoMes,
      mesAno: mesAno,
      diaAno: diaAno,
      hora: hora,
      minuto: minuto,
      criadaEm: DateTime(2026, 1, 1),
      ultimaExecucaoEm: ultima,
    );

void main() {
  // 1. Todo dia combina com qualquer data.
  final diaria = automacao();
  for (var dia = 1; dia <= 10; dia++) {
    exigir(diaCombinaCom(diaria, DateTime(2026, 3, dia)),
        'diária deveria combinar com 03/$dia');
  }
  ok('recorrência diária combina com todos os dias');

  // 2. Semanal só nos dias escolhidos (1 = segunda … 7 = domingo).
  final semanal = automacao(recorrencia: Recorrencia.semanal, diasSemana: [1, 3]);
  exigir(diaCombinaCom(semanal, DateTime(2026, 3, 2)), 'segunda deveria valer');
  exigir(diaCombinaCom(semanal, DateTime(2026, 3, 4)), 'quarta deveria valer');
  exigir(!diaCombinaCom(semanal, DateTime(2026, 3, 3)), 'terça não foi escolhida');
  exigir(!diaCombinaCom(semanal, DateTime(2026, 3, 8)), 'domingo não foi escolhido');
  ok('recorrência semanal respeita os dias marcados');

  // 3. Mensal no dia 31 cai no último dia de fevereiro.
  final mensal = automacao(recorrencia: Recorrencia.mensal, diaDoMes: 31);
  exigir(diaCombinaCom(mensal, DateTime(2026, 1, 31)), 'janeiro tem dia 31');
  exigir(diaCombinaCom(mensal, DateTime(2026, 2, 28)),
      'fevereiro de 2026 termina no 28');
  exigir(!diaCombinaCom(mensal, DateTime(2026, 2, 27)), '27 não é o último dia');
  ok('recorrência mensal usa o último dia quando o mês é curto');

  // 4. Anual no dia e mês escolhidos.
  final anual = automacao(recorrencia: Recorrencia.anual, mesAno: 12, diaAno: 25);
  exigir(diaCombinaCom(anual, DateTime(2026, 12, 25)), '25/12 deveria valer');
  exigir(!diaCombinaCom(anual, DateTime(2026, 12, 24)), '24/12 não foi escolhido');
  exigir(!diaCombinaCom(anual, DateTime(2026, 11, 25)), 'novembro não foi escolhido');
  ok('recorrência anual respeita dia e mês');

  // 5. Próxima ocorrência pula os dias que não combinam.
  final proximaSemanal = proximaOcorrenciaAutomacao(
      automacao(recorrencia: Recorrencia.semanal, diasSemana: [5], hora: 9),
      DateTime(2026, 3, 2, 10)); // segunda
  exigir(proximaSemanal == DateTime(2026, 3, 6, 9),
      'próxima sexta às 09:00, veio $proximaSemanal');
  ok('próxima ocorrência pula para o próximo dia escolhido');

  // 6. No mesmo dia, horário que ainda não passou conta.
  final hoje = proximaOcorrenciaAutomacao(diaria, DateTime(2026, 3, 2, 7));
  exigir(hoje == DateTime(2026, 3, 2, 8), 'deveria ser hoje às 08:00, veio $hoje');
  final amanha = proximaOcorrenciaAutomacao(diaria, DateTime(2026, 3, 2, 9));
  exigir(amanha == DateTime(2026, 3, 3, 8),
      'deveria ser amanhã às 08:00, veio $amanha');
  ok('próxima ocorrência respeita a hora já passada');

  // 7. Automação vencida só no dia certo e uma vez por horário.
  final segunda = automacao(
      recorrencia: Recorrencia.semanal, diasSemana: [1], hora: 8, minuto: 0);
  exigir(
      automacaoVencida(segunda, agora: DateTime(2026, 3, 2, 8, 1)),
      'segunda às 08:01 deveria estar vencida');
  exigir(
      !automacaoVencida(segunda, agora: DateTime(2026, 3, 3, 8, 1)),
      'terça não deveria disparar');
  exigir(
      automacaoVencida(segunda,
          agora: DateTime(2026, 3, 2, 8, 1), bateria: null),
      'sem bateria a automação de horário continua valendo');
  final jaRodou = automacao(
      recorrencia: Recorrencia.semanal,
      diasSemana: [1],
      hora: 8,
      minuto: 0,
      ultima: DateTime(2026, 3, 2, 8, 0));
  exigir(
      !automacaoVencida(jaRodou, agora: DateTime(2026, 3, 2, 8, 2)),
      'não deveria rodar duas vezes no mesmo horário');
  ok('automação vencida respeita dia da semana e execução única');

  // 8. Uma vez só nunca entra na conta de automação.
  final unica = automacao(recorrencia: Recorrencia.umaVez, hora: 8);
  exigir(!diaCombinaCom(unica, DateTime(2026, 3, 2)), 'uma vez não combina');
  exigir(
      !automacaoVencida(unica, agora: DateTime(2026, 3, 2, 8, 1)),
      'uma vez não deve disparar como automação');
  ok('automação de uma vez só não dispara');

  // 9. Tarefa que repete calcula a próxima data com o mesmo horário.
  final prazo = DateTime(2026, 1, 31, 19, 30);
  exigir(proximaDataTarefa(prazo, Recorrencia.diaria) == DateTime(2026, 2, 1, 19, 30),
      'diária deveria ir para o dia seguinte');
  exigir(proximaDataTarefa(prazo, Recorrencia.semanal) == DateTime(2026, 2, 7, 19, 30),
      'semanal deveria somar sete dias');
  exigir(
      proximaDataTarefa(prazo, Recorrencia.mensal) == DateTime(2026, 2, 28, 19, 30),
      'mensal de 31/01 deveria cair em 28/02');
  final bissexto = DateTime(2028, 2, 29, 9, 0);
  exigir(proximaDataTarefa(bissexto, Recorrencia.anual) == DateTime(2029, 2, 28, 9, 0),
      'anual de 29/02 deveria cair em 28/02 do ano seguinte');
  ok('tarefa que repete calcula a próxima data sem perder o horário');

  // 10. Persistência preserva a recorrência e os dias.
  final salva = automacao(
      recorrencia: Recorrencia.semanal, diasSemana: [2, 6], diaDoMes: 10,
      mesAno: 7, diaAno: 4);
  final lida = Automacao.deJson(salva.paraJson());
  exigir(lida != null, 'automação deveria voltar do JSON');
  exigir(lida!.recorrencia == Recorrencia.semanal, 'recorrência perdida');
  exigir(lida.diasSemana.join(',') == '2,6', 'dias perdidos: ${lida.diasSemana}');
  exigir(lida.diaDoMes == 10 && lida.mesAno == 7 && lida.diaAno == 4,
      'dia do mês ou do ano perdidos');
  ok('automação guarda e relê a recorrência');

  print('recorrência: $checks verificações');
}
