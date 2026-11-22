import 'dart:io';

import 'package:jarvis_nova/core/timbre_voz.dart';

void main() {
  // 1. São três perfis, com ids únicos e os nomes do comparativo.
  assert(perfisTimbre.length == 3, 'deveriam existir três perfis');
  final ids = perfisTimbre.map((p) => p.id).toSet();
  assert(ids.length == 3, 'id repetido entre perfis');
  final nomes = perfisTimbre.map((p) => p.nome).toList();
  assert(nomes.contains('Grave') &&
      nomes.contains('Natural') &&
      nomes.contains('Ágil'), 'nomes dos perfis errados');

  // 2. O grave é o timbre original do app: 0,72 de tom e 0,88 de ritmo.
  final grave = timbreDe('grave');
  assert(grave.pitch == 0.72, 'tom do grave mudou');
  assert(grave.velocidade == 0.88, 'ritmo do grave mudou');

  // 3. Id desconhecido ou vazio cai no padrão, sem quebrar a tela.
  assert(timbreDe(null).id == timbrePadrao, 'nulo deveria usar o padrão');
  assert(timbreDe('').id == timbrePadrao, 'vazio deveria usar o padrão');
  assert(timbreDe('inexistente').id == timbrePadrao,
      'id desconhecido deveria usar o padrão');
  assert(timbreDe(' NATURAL ').id == 'natural',
      'caixa e espaços deveriam ser tolerados');

  // 4. Ágil é mais agudo e mais rápido que o natural; natural é neutro.
  final natural = timbreDe('natural');
  final agil = timbreDe('agil');
  assert(natural.pitch == 1.0 && natural.velocidade == 1.0,
      'natural deveria ser o tom e o ritmo nativos');
  assert(agil.pitch > natural.pitch, 'ágil deveria ser mais agudo');
  assert(agil.velocidade > natural.velocidade,
      'ágil deveria ser mais rápido');
  assert(grave.pitch < natural.pitch, 'grave deveria ser mais baixo');

  // 5. Todo perfil fica na faixa aceita pelo Android.
  for (final perfil in perfisTimbre) {
    assert(pitchSeguro(perfil.pitch) == perfil.pitch,
        '${perfil.id}: tom fora da faixa');
    assert(velocidadeSegura(perfil.velocidade) == perfil.velocidade,
        '${perfil.id}: ritmo fora da faixa');
    assert(perfil.descricao.trim().isNotEmpty,
        '${perfil.id}: perfil sem descrição');
  }
  assert(pitchSeguro(0.1) == pitchMinimo, 'tom baixo deveria ser limitado');
  assert(pitchSeguro(3.0) == pitchMaximo, 'tom alto deveria ser limitado');
  assert(velocidadeSegura(0) == velocidadeMinima,
      'ritmo lento deveria ser limitado');
  assert(velocidadeSegura(5) == velocidadeMaxima,
      'ritmo rápido deveria ser limitado');

  // 6. O resumo mostra o que está sendo usado, não só o nome.
  final resumo = resumoTimbre(agil);
  assert(resumo.contains('Ágil'), 'resumo sem o nome do perfil');
  assert(resumo.contains('1.15') && resumo.contains('1.12'),
      'resumo sem tom e ritmo');

  // 7. Os limites não escondem que a voz é a do aparelho.
  assert(limitesTimbre.any((l) => l.contains('síntese')),
      'limite da síntese ausente');
  assert(limitesTimbre.any((l) => l.contains('45%')),
      'limite do modo noturno ausente');
  assert(limitesTimbre.any((l) => l.contains('segundo plano')),
      'validade no segundo plano não declarada');

  // 8. A frase de exemplo é curta e sem marcação que a voz leria.
  assert(fraseExemploTimbre.length <= 90, 'frase de exemplo longa demais');
  assert(!fraseExemploTimbre.contains('*') &&
      !fraseExemploTimbre.contains('#') &&
      !fraseExemploTimbre.contains('['), 'frase de exemplo com marcação');

  stdout.writeln(
      'OK: timbre — perfis, paridade do grave, faixas, resumo e limites');
}
