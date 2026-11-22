import 'dart:io';

import 'package:jarvis_nova/core/voz_externa.dart';

void main() {
  // 1. O ID pedido é o padrão do app e passa na validação.
  assert(idVozPadrao == '82d13948027e4be69892dd3d0104e681',
      'o ID padrão mudou: $idVozPadrao');
  assert(idVozValido(idVozPadrao), 'o ID padrão não é aceito pela validação');

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

  // 3. A URL leva o ID e o formato; nada do texto vai para a URL.
  final url = urlVozExterna(idVozPadrao);
  assert(url.contains(idVozPadrao), 'URL sem o ID: $url');
  assert(url.contains('output_format=$formatoVozPadrao'), 'URL sem formato');
  assert(!url.contains('Bom dia'), 'texto vazou para a URL');

  // 4. O corpo leva o texto e o modelo, e só isso.
  final corpo = corpoVozExterna('  Bom dia.  ');
  assert(corpo['text'] == 'Bom dia.', 'texto não foi aparado');
  assert(corpo['model_id'] == modeloVozPadrao, 'modelo errado');
  assert(corpo.length == 3, 'corpo com campo inesperado: ${corpo.keys}');

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

  stdout.writeln('OK: ID padrão validado, ${limitesVozExterna.length} limites '
      'declarados, URL e corpo conferidos');
}
