import 'package:jarvis_nova/core/pedido_apelido.dart';

void main() {
  void confere(String texto, String nome, String apelido) {
    final pedido = pedidoApelido(texto);
    assert(pedido != null, '“$texto” não foi reconhecido');
    if (pedido == null) return;
    assert(!pedido.esquecer, '“$texto” virou esquecimento');
    assert(pedido.nome == nome,
        '“$texto” usou o nome “${pedido.nome}”, esperado “$nome”');
    assert(pedido.apelido == apelido,
        '“$texto” usou o apelido “${pedido.apelido}”, esperado “$apelido”');
  }

  // 1. Formas de ensinar.
  confere('o apelido do Murilo é Murilin', 'Murilo', 'Murilin');
  confere('apelido de Murilo: Murilin', 'Murilo', 'Murilin');
  confere('chama o Murilo de Murilin', 'Murilo', 'Murilin');
  confere('pode chamar o Murilo de Murilin', 'Murilo', 'Murilin');
  confere('conhece o Murilo como Murilin', 'Murilo', 'Murilin');
  confere('jarvis, o apelido da Ana é Aninha', 'Ana', 'Aninha');
  confere('chama a Beatriz de Bia', 'Beatriz', 'Bia');
  confere('o apelido do Murilo Silva é Murilin', 'Murilo Silva', 'Murilin');

  // 2. Esquecer.
  for (final texto in [
    'esquece o apelido Murilin',
    'apaga o apelido Murilin',
    'remove o apelido de Murilin',
  ]) {
    final pedido = pedidoApelido(texto);
    assert(pedido != null, '“$texto” não foi reconhecido');
    if (pedido == null) continue;
    assert(pedido.esquecer, '“$texto” não virou esquecimento');
    assert(pedido.apelido == 'Murilin',
        '“$texto” guardou “${pedido.apelido}”');
  }

  // 3. Conversa comum, pergunta e outros comandos não viram apelido.
  for (final texto in [
    'o céu é azul',
    'meu nome é Murilo',
    'qual o apelido do Murilo?',
    'como chamo o Murilo?',
    'manda mensagem para o Murilo no WhatsApp dizendo que chego às 9',
    'abre a memória',
    'bom dia',
  ]) {
    assert(pedidoApelido(texto) == null, '“$texto” virou apelido');
  }

  // 4. Resumo e frase falada.
  final ensinar = pedidoApelido('chama o Murilo de Murilin')!;
  assert(ensinar.resumo == 'apelido de Murilo: Murilin',
      'resumo veio “${ensinar.resumo}”');
  assert(
      ensinar.fraseFalada ==
          'Pronto. Quando você falar Murilin, eu entendo Murilo.',
      'frase falada veio “${ensinar.fraseFalada}”');
  final esquecer = pedidoApelido('esquece o apelido Murilin')!;
  assert(esquecer.resumo == 'esquecer o apelido Murilin',
      'resumo veio “${esquecer.resumo}”');
  assert(esquecer.fraseFalada.contains('esquecido'),
      'frase falada veio “${esquecer.fraseFalada}”');
}
