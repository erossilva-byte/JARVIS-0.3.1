import 'dart:io';

import 'package:jarvis_nova/core/voz_externa.dart';

void main() {
  // 1. O ID pedido é o padrão do app e passa na validação.
  assert(idVozPadrao == '82d13948027e4be69892dd3d0104e681',
      'o ID padrão mudou: $idVozPadrao');
  assert(idVozValido(idVozPadrao), 'o ID padrão não é aceito pela validação');
  assert(nomeServicoVoz == 'Fish Audio', 'o serviço mudou: $nomeServicoVoz');

  // 2. ID malformado cai no padrão em vez de quebrar a chamada.
  for (final ruim in ['', '   ', 'abc', 'id com espaço', List.filled(41, 'x').join()]) {
    assert(!idVozValido(ruim), 'ID inválido aceito: “$ruim”');
    assert(normalizarIdVoz(ruim) == idVozPadrao,
        'ID inválido não caiu no padrão: “$ruim”');
  }
  assert(idVozValido('21m00Tcm4TlvDq8ikWAM'),
      'ID alfanumérico de 20 caracteres deveria ser aceito');
  assert(normalizarIdVoz('  21m00Tcm4TlvDq8ikWAM ') == '21m00Tcm4TlvDq8ikWAM',
      'normalização não aparou os espaços');

  // 3. A URL é o endereço do Fish Audio e não carrega o ID nem o texto: o ID
  //    vai no corpo, como o serviço pede.
  final url = urlVozExterna();
  assert(url == 'https://api.fish.audio/v1/tts', 'endereço errado: $url');
  assert(!url.contains(idVozPadrao), 'o ID não deveria ir na URL');
  assert(!url.contains('Bom dia'), 'texto vazou para a URL');

  // 4. O corpo leva o texto, o ID da voz e o formato, e só isso.
  final corpo = corpoVozExterna('  Bom dia.  ');
  assert(corpo['text'] == 'Bom dia.', 'texto não foi aparado');
  assert(corpo['reference_id'] == idVozPadrao, 'ID da voz errado no corpo');
  assert(corpo['format'] == 'mp3', 'formato errado no corpo');
  assert(corpo.length == 3, 'corpo com campo inesperado: ${corpo.keys}');
  assert(corpoVozExterna('oi', id: 'nao-vale').length == 3,
      'corpo com ID inválido mudou de formato');
  assert(corpoVozExterna('oi', id: 'nao-vale')['reference_id'] == idVozPadrao,
      'ID inválido não caiu no padrão no corpo');
  final escolhido = corpoVozExterna('oi', id: 'abc123abc123abc1');
  assert(escolhido['reference_id'] == 'abc123abc123abc1',
      'ID válido escolhido não foi usado');

  // 5. O resumo distingue os três estados, sem prometer voz sem chave.
  final semChave = resumoVozExterna(idVozPadrao, ativa: true, temChave: false);
  assert(semChave.contains('sem chave'), 'resumo sem chave não avisa');
  assert(semChave.contains(idVozPadrao), 'resumo sem o ID');
  final desligada = resumoVozExterna(idVozPadrao, ativa: false, temChave: true);
  assert(desligada.contains('desligada'), 'resumo não mostra desligada');
  final ligada = resumoVozExterna(idVozPadrao, ativa: true, temChave: true);
  assert(ligada.contains('ligada'), 'resumo não mostra ligada');

  // 6. Os limites estão escritos e incluem o custo e a rede.
  final texto = limitesVozExterna.join(' ').toLowerCase();
  for (final termo in ['sai do aparelho', 'internet', 'cota', 'cofre']) {
    assert(texto.contains(termo), 'limite ausente: $termo');
  }
  assert(texto.contains('fish audio'), 'limite não diz qual é o serviço');

  stdout.writeln('OK: ID padrão validado, serviço $nomeServicoVoz, '
      '${limitesVozExterna.length} limites declarados, URL e corpo conferidos');
}
