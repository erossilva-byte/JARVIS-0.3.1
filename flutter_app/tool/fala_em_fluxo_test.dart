import 'dart:io';

import 'package:jarvis_nova/core/fala_em_fluxo.dart';

void main() {
  // 1. Frase fechada sai antes do fim da resposta.
  final fluxo = FalasEmFluxo();
  var prontas = fluxo.acrescentar('Bom dia. Tudo bem');
  assert(prontas.length == 1, 'esperava uma frase, veio ${prontas.length}');
  assert(prontas.single == 'Bom dia.', 'frase errada: ${prontas.single}');

  // 2. O resto sem pontuação espera o fim.
  prontas = fluxo.acrescentar('Bom dia. Tudo bem');
  assert(prontas.isEmpty, 'falou texto sem pontuação: $prontas');

  // 3. Finalizar devolve o que sobrou.
  prontas = fluxo.acrescentar('Bom dia. Tudo bem', finalizar: true);
  assert(prontas.length == 1 && prontas.single == 'Tudo bem',
      'resto errado: $prontas');
  assert(!fluxo.temPendente, 'sobrou texto depois de finalizar');

  // 4. Ponto de número não fecha frase.
  final numeros = FalasEmFluxo();
  prontas = numeros.acrescentar('A versão 1.89 saiu hoje.');
  assert(prontas.length == 1, 'cortou no ponto do número: $prontas');
  assert(prontas.single == 'A versão 1.89 saiu hoje.',
      'frase cortada errada: $prontas');

  // 5. Sem pontuação nenhuma, o texto é cortado no limite da fala.
  final longo = FalasEmFluxo();
  final texto = List.filled(60, 'palavra').join(' ');
  prontas = longo.acrescentar(texto);
  assert(prontas.isNotEmpty, 'texto longo sem corte');
  assert(prontas.first.length <= 220, 'corte grande demais: ${prontas.first.length}');
  assert(!prontas.first.endsWith(' '), 'corte deixou espaço no fim');

  // 6. Parcial que encolhe é resposta nova: não repete o que já foi lido.
  final outra = FalasEmFluxo();
  outra.acrescentar('Primeira frase. Segunda fra');
  prontas = outra.acrescentar('Outra! Fim de papo.');
  assert(prontas.length == 2, 'resposta nova não recomeçou: $prontas');
  assert(prontas.first == 'Outra!', 'leu texto antigo: $prontas');

  stdout.writeln('OK: frases em fluxo, resto no fim, número protegido e '
      'resposta nova recomeçando');
}
