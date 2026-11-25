import 'package:jarvis_nova/core/mapa_voz.dart';
import 'package:jarvis_nova/core/pedido_abrir.dart';

void main() {
  // 1. A pergunta é respondida no aparelho.
  for (final texto in [
    'quais telas você abre',
    'que telas você tem',
    'me mostra as telas',
    'lista os comandos de voz',
    'quais são os comandos que você entende',
    'o que você faz por voz',
  ]) {
    final resposta = respostaMapaDaVoz(texto);
    assert(resposta != null, '“$texto” não foi respondida');
    assert(resposta!.contains('$totalDeTelasPorVoz telas'),
        '“$texto” não disse quantas telas: $resposta');
  }

  // 2. Não é pergunta de mapa.
  for (final texto in [
    'abre o mapa da voz',
    'abre a memória',
    'como abro a memória',
    'quais são as capitais da Europa',
    'bom dia',
    'manda mensagem para a Ana',
    'toca na tela para mim',
  ]) {
    assert(respostaMapaDaVoz(texto) == null, '“$texto” virou resposta de mapa');
  }

  // 3. O catálogo nasce da tabela de telas, sem lista paralela.
  final categorias = mapaDaVoz();
  assert(categorias.length == 2, 'categorias vieram ${categorias.length}');
  assert(totalDeTelasPorVoz == TelaJarvis.values.length,
      'o total de telas não bate com TelaJarvis');
  final telas = categorias.first;
  assert(telas.itens.length == TelaJarvis.values.length,
      'o mapa não lista todas as telas');
  for (final tela in TelaJarvis.values) {
    assert(telas.itens.contains('abre ${tela.rotulo}'),
        'a tela ${tela.chave} ficou fora do mapa');
  }
  for (final item in categorias.expand((c) => c.itens)) {
    assert(item.trim().isNotEmpty, 'item vazio no mapa da voz');
  }
  assert(categorias.last.itens.any((i) => i.contains('apelido')),
      'o mapa não ensina apelido');
  assert(categorias.last.itens.any((i) => i.contains('WhatsApp')),
      'o mapa não mostra mensagem por app');
}
