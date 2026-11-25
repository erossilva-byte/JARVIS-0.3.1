import 'package:jarvis_nova/core/aparelho.dart';

void main() {
  // 1. Os mesmos verbos do segundo plano (JarvisMensagens.VERBO_LIGACAO).
  for (final frase in [
    'liga para o Murilo',
    'ligue para a Ana',
    'liga pro Murilo',
    'disca para o Murilo',
    'discar 11999998888',
    'chama o Murilo',
    'chamar a Ana',
  ]) {
    final pedido = interpretarLigacao(frase);
    assert(pedido != null, 'não reconheceu ligação em: $frase');
  }

  // 2. O destino sai sem conector nem artigo.
  assert(interpretarLigacao('liga para o Murilo')!.destino == 'Murilo',
      'destino saiu com conector: ${interpretarLigacao('liga para o Murilo')}');
  assert(interpretarLigacao('chama o Murilo')!.destino == 'Murilo',
      'destino saiu errado em “chama o Murilo”');
  assert(interpretarLigacao('disca 11999998888')!.destino == '11999998888',
      'número discado saiu errado');

  // 3. Não é ligação: desligar, lanterna, volume e pergunta.
  for (final frase in [
    'desliga a luz',
    'ligar a lanterna',
    'liga o volume',
    'como liga o bluetooth',
  ]) {
    assert(interpretarLigacao(frase) == null,
        'confundiu ligação com: $frase');
  }

  // 4. Mensagem e ligação não se atropelam.
  final mensagem = interpretarMensagem(
      'manda mensagem para o Murilo no WhatsApp dizendo que chego às 9');
  assert(mensagem != null && mensagem.texto.isNotEmpty,
      'a mensagem deixou de ser reconhecida');
  assert(interpretarLigacao('manda mensagem para o Murilo') == null,
      '“manda mensagem” virou ligação');
}
