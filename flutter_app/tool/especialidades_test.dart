import 'dart:io';

import 'package:jarvis_nova/core/especialidades.dart';

void main() {
  // 1. As duas áreas existem e têm instrução própria.
  assert(especialidadesJarvis.length == 2, 'deveriam ser duas especialidades');
  final cadesimu = especialidadePorId('cadesimu');
  final programacao = especialidadePorId('programacao');
  assert(cadesimu != null && programacao != null, 'id de especialidade sumiu');
  assert(especialidadePorId('inexistente') == null, 'id inventado virou área');

  // 2. CADeSIMU: comando, dimensionamento e ladder caem aqui.
  for (final texto in [
    'como montar uma partida direta com selo?',
    'dimensiona o disjuntor e o contator de um motor de 5 cv',
    'o que é o selo 13-14 do contator K1',
    'me explica esse ladder do CLP',
    'abre o arquivo .cad que eu importei',
    'qual a bitola do cabo para 30 A',
  ]) {
    assert(especialidadeDe(texto)?.id == 'cadesimu',
        'não reconheceu CADeSIMU em: $texto');
  }

  // 3. Programação: código, erro, revisão e teste.
  for (final texto in [
    'revisa essa função em Dart',
    'explica por que dá null check operator used on a null value',
    'escreve um teste unitário para esse parser',
    'esse código em Python está com bug',
    'refatora essa classe Kotlin',
    'como faço uma API em Node.js',
  ]) {
    assert(especialidadeDe(texto)?.id == 'programacao',
        'não reconheceu programação em: $texto');
  }

  // 4. “Programa do CLP” é engenharia, não programação: a ordem das regras manda.
  assert(
      especialidadeDe('faz um programa em ladder para o CLP')?.id == 'cadesimu',
      'programa de CLP caiu em programação');

  // 5. Conversa comum não recebe instrução extra.
  for (final texto in [
    'qual a capital da França',
    'que horas são',
    'bom dia, Jarvis',
    'toca uma música',
  ]) {
    assert(especialidadeDe(texto) == null, 'conversa comum virou área: $texto');
    assert(blocoDaEspecialidade(especialidadeDe(texto)).isEmpty,
        'bloco deveria ser vazio em: $texto');
  }

  // 6. A instrução cobre o domínio e declara os limites reais.
  final textoCadesimu = instrucaoDaEspecialidade(cadesimu!);
  assert(textoCadesimu.contains('CADeSIMU'), 'instrução sem o nome da área');
  assert(
      textoCadesimu.contains('.cad'), 'instrução não fala do formato nativo');
  assert(textoCadesimu.contains('proprietário'),
      'instrução não diz que o .cad é proprietário');
  assert(textoCadesimu.contains('ART'),
      'instrução não declara que não substitui laudo');

  final textoProgramacao = instrucaoDaEspecialidade(programacao!);
  assert(textoProgramacao.contains('não executa'),
      'instrução de código promete execução');
  assert(textoProgramacao.contains('sandbox'),
      'instrução não diz que não há sandbox');
  assert(textoProgramacao.contains('Nunca invente'),
      'instrução sem a regra de não inventar');

  // 7. O bloco pronto é exatamente a instrução; resumo cita as duas.
  assert(
      blocoDaEspecialidade(programacao) ==
          instrucaoDaEspecialidade(programacao),
      'bloco diferente da instrução');
  final resumo = resumoEspecialidades();
  assert(resumo.contains('CADeSIMU') && resumo.contains('Programação'),
      'resumo não cita as duas áreas');

  stdout.writeln('OK: especialidades — CADeSIMU e programação reconhecidos, '
      'limites declarados e conversa comum intacta.');
}
