import 'dart:io';

import 'package:jarvis_nova/core/pedido_ficha.dart';

void main() {
  // 1. O pedido do exemplo: nome, idade, apelido e relação.
  final encontrado = pedidoDeFicha(
      'Jarvis, crie a ficha de Murilo, que tem 16 anos, seu apelido é '
      'Murilin e ele é meu melhor amigo');
  assert(encontrado != null, 'pedido de ficha não reconhecido');
  final pedido = encontrado!;
  assert(pedido.nome == 'Murilo', 'nome veio “${pedido.nome}”');
  assert(pedido.idade == 16, 'idade veio ${pedido.idade}');
  assert(pedido.apelido == 'Murilin', 'apelido veio “${pedido.apelido}”');
  assert(pedido.relacao == 'melhor amigo', 'relação veio “${pedido.relacao}”');
  assert(pedido.observacoes == '16 anos', 'idade não foi preservada');

  // 2. Formas alternativas de pedir.
  final outra = pedidoDeFicha('salve uma ficha para Ana, 52 anos');
  assert(outra != null && outra.nome == 'Ana',
      'pedido alternativo não reconhecido');
  final alternativa = outra!;
  assert(alternativa.idade == 52, 'idade da alternativa errada');

  final semIdadeBruto = pedidoDeFicha('cadastre a ficha do Murilo');
  assert(semIdadeBruto != null && semIdadeBruto.nome == 'Murilo',
      'pedido sem idade não reconhecido');
  final semIdade = semIdadeBruto!;
  assert(semIdade.idade == null && semIdade.observacoes.isEmpty,
      'idade inventada em pedido sem idade');

  // 3. Pergunta não vira gravação.
  for (final pergunta in [
    'qual é a ficha de Murilo',
    'mostra as fichas que você tem',
    'o que é uma ficha de pessoa',
    'apaga a ficha de Murilo',
  ]) {
    assert(pedidoDeFicha(pergunta) == null,
        'pergunta virou pedido de ficha: “$pergunta”');
  }

  // 4. Confirmação só com as palavras certas.
  for (final sim in [
    'confirmo',
    'Confirmo!',
    'pode salvar',
    'sim, confirmo',
    'tenho o consentimento'
  ]) {
    assert(confirmacaoDeFicha(sim), 'confirmação não aceita: “$sim”');
  }
  for (final nao in ['claro', 'talvez', 'confirma depois', 'não sei']) {
    assert(!confirmacaoDeFicha(nao), 'confirmação aceitou: “$nao”');
  }

  // 5. Cancelamento reconhecido.
  for (final cancela in ['cancela', 'não', 'deixa pra lá', 'cancele a ficha']) {
    assert(cancelamentoDeFicha(cancela), 'cancelamento não aceito: “$cancela”');
  }

  stdout.writeln('OK: pedido de ficha — dados, pergunta poupada, confirmação e '
      'cancelamento conferidos');
}
