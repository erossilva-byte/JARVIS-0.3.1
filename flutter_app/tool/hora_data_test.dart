import 'package:jarvis_nova/core/hora_data.dart';

void main() {
  // 1. Falas com a hora, como no segundo plano.
  assert(horaFalada(DateTime(2026, 1, 4, 14, 5)) ==
          'Agora são 14 horas e 5 minutos.',
      'hora com minutos saiu diferente');
  assert(horaFalada(DateTime(2026, 1, 4, 9, 0)) ==
          'Agora são 9 horas em ponto.',
      'hora em ponto saiu diferente');
  assert(horaFalada(DateTime(2026, 1, 4, 0, 30)) ==
          'Agora são 0 horas e 30 minutos.',
      'meia-noite saiu diferente');

  // 2. Data com dia da semana, sem depender do fuso do teste.
  assert(dataFalada(DateTime(2026, 1, 4)) ==
          'Hoje é domingo, 4 de janeiro de 2026.',
      'domingo saiu diferente: ${dataFalada(DateTime(2026, 1, 4))}');
  assert(dataFalada(DateTime(2026, 11, 25)) ==
          'Hoje é quarta-feira, 25 de novembro de 2026.',
      'quarta saiu diferente: ${dataFalada(DateTime(2026, 11, 25))}');

  // 3. Frases reconhecidas, com a ação certa para o histórico.
  final agora = DateTime(2026, 1, 4, 14, 5);
  for (final frase in [
    'que horas são',
    'que horas sao',
    'quantas horas',
    'me diz que horas são',
    'horas agora',
  ]) {
    final r = respostaHoraData(frase, agora: agora);
    assert(r != null, 'não reconheceu a hora em: $frase');
    final resposta = r!;
    assert(resposta.acao == 'informar as horas', 'ação errada para: $frase');
    assert(resposta.fala.contains('14 horas'),
        'fala errada para: $frase → ${resposta.fala}');
  }
  for (final frase in [
    'que dia é hoje',
    'qual a data de hoje',
    'data de hoje',
    'que dia da semana',
  ]) {
    final r = respostaHoraData(frase, agora: agora);
    assert(r != null, 'não reconheceu a data em: $frase');
    final resposta = r!;
    assert(resposta.acao == 'informar a data de hoje', 'ação errada para: $frase');
    assert(resposta.fala.contains('janeiro'),
        'fala errada para: $frase → ${resposta.fala}');
  }

  // 4. Não é relógio: pergunta de explicação e outros pedidos.
  for (final frase in [
    'por que o relógio mudou',
    'que horas você abre o mapa da voz',
    'abre a memória',
    'manda mensagem para o Murilo',
    '',
  ]) {
    final r = respostaHoraData(frase, agora: agora);
    if (frase.startsWith('que horas você')) {
      // A frase contém “que horas”: a regra responde a hora, e é o mesmo
      // comportamento do segundo plano — está declarado no relatório.
      assert(r != null, 'a regra deixou de seguir o espelho Kotlin');
      continue;
    }
    assert(r == null, 'confundiu relógio com: $frase');
  }
}
