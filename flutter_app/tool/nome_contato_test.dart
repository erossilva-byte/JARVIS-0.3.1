import 'package:jarvis_nova/core/aparelho.dart';
import 'package:jarvis_nova/core/nome_contato.dart';

void main() {
  // 1. Normalização: emoji, acento, pontuação e letra repetida.
  assert(normalizarNomeContato('Biaa🩵🩵') == 'bia',
      'Biaa com emoji virou “${normalizarNomeContato('Biaa🩵🩵')}”');
  assert(normalizarNomeContato('João!!! 🎉') == 'joao',
      'João com enfeite virou “${normalizarNomeContato('João!!! 🎉')}”');
  assert(normalizarNomeContato('  Murilo   Silva ') == 'murilo silva',
      'espaços não foram normalizados');
  assert(normalizarNomeContato('Biaa') == normalizarNomeContato('Bia'),
      'letra repetida não foi compactada');
  assert(normalizarNomeContato('') == '', 'texto vazio devia continuar vazio');

  // 2. Nome falado diferente do salvo continua sendo a mesma pessoa.
  assert(semelhancaNome('Murilin', 'Murilo') >= notaMinimaContato,
      'Murilin não achou Murilo: ${semelhancaNome('Murilin', 'Murilo')}');
  assert(semelhancaNome('Murilinho', 'Murilo') >= notaMinimaContato,
      'Murilinho não achou Murilo');
  assert(semelhancaNome('Biaa🩵🩵', 'Bia') == 1.0,
      'Biaa🩵🩵 não achou Bia');
  assert(semelhancaNome('Bia', 'Beatriz') == 1.0,
      'Bia não achou Beatriz');
  assert(semelhancaNome('Bia', 'Bianca') == 1.0,
      'Bia não achou Bianca');
  assert(semelhancaNome('Zé', 'José') == 1.0, 'Zé não achou José');
  assert(semelhancaNome('Duda', 'Eduarda') == 1.0, 'Duda não achou Eduarda');
  assert(semelhancaNome('Nanda', 'Fernanda') == 1.0,
      'Nanda não achou Fernanda');
  assert(semelhancaNome('Tia Ana', 'Ana') == 1.0,
      '“Tia Ana” não achou Ana');
  assert(semelhancaNome('Ana', 'Mariana') < notaMinimaContato,
      'Ana não pode virar Mariana');

  // 3. Nome salvo com enfeite e sobrenome.
  assert(semelhancaNome('Murilo', 'Murilo 🐱 Trabalho') == 1.0,
      'nome com enfeite não foi entendido');
  assert(semelhancaNome('Murilo', 'Murilo Silva') >= 0.85,
      'nome com sobrenome não foi entendido');

  // 4. Escolha: um contato certo.
  final murilos = [const ContatoAparelho(nome: 'Murilo', telefones: ['11999'])];
  final murilo = escolherContato('Murilin', murilos);
  assert(murilo.contato?.nome == 'Murilo',
      'Murilin não escolheu Murilo: ${murilo.contato?.nome}');
  assert(!murilo.ambiguo, 'com um contato só não pode haver dúvida');

  // 5. Escolha: “Bia” pode ser Beatriz ou Bianca — nesse caso, perguntar.
  final bias = [
    const ContatoAparelho(nome: 'Beatriz Lima', telefones: ['1111']),
    const ContatoAparelho(nome: 'Bianca', telefones: ['2222']),
  ];
  final escolha = escolherContato('Bia', bias);
  assert(escolha.contato == null && escolha.ambiguo,
      '“Bia” com duas donas devia perguntar');
  assert(escolha.candidatos.length == 2,
      'candidatos vieram ${escolha.candidatos.length}');
  assert(escolha.candidatos.any((c) => c.nome == 'Beatriz Lima') &&
          escolha.candidatos.any((c) => c.nome == 'Bianca'),
      'os candidatos não são as duas Bia');

  // 6. Empate entre o nome e o nome com sobrenome fica com o curto.
  final doisMurilos = [
    const ContatoAparelho(nome: 'Murilo Silva', telefones: ['3333']),
    const ContatoAparelho(nome: 'Murilo', telefones: ['4444']),
  ];
  final curto = escolherContato('Murilin', doisMurilos);
  assert(curto.contato?.nome == 'Murilo',
      'empate devia ficar com Murilo, veio ${curto.contato?.nome}');

  // 7. Nada parecido, lista vazia e nome vazio.
  assert(escolherContato('Zuleica', murilos).contato == null,
      'nome sem relação não pode virar contato');
  assert(escolherContato('Murilo', const []).contato == null,
      'lista vazia devia devolver nada');
  assert(escolherContato('', murilos).contato == null,
      'nome vazio devia devolver nada');

  // 8. Lista ordenada pelo mais parecido.
  final ordenada = ordenarContatosPorNome('Bia', bias);
  assert(ordenada.length == 2, 'a ordenação perdeu contato');
  assert(ordenada.first.nome == 'Beatriz Lima' ||
          ordenada.first.nome == 'Bianca',
      'a ordenação devia começar por uma das Bia');
  assert(ordenarContatosPorNome('', bias).length == 2,
      'texto vazio devia manter a lista inteira');

  // 9. A tabela de apelidos tem os casos citados pelo usuário.
  assert(apelidosContato['bia']!.contains('beatriz'), 'Bia não aponta Beatriz');
  assert(apelidosContato['bia']!.contains('bianca'), 'Bia não aponta Bianca');
  assert(apelidosContato['ze']!.contains('jose'), 'Zé não aponta José');
}
