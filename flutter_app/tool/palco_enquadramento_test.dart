// ignore_for_file: avoid_print

import 'package:jarvis_nova/core/palco.dart';

int checks = 0;

void ok(String nome) {
  checks++;
  print('OK: $nome');
}

void exigir(bool condicao, String mensagem) {
  if (!condicao) {
    print('FALHOU: $mensagem');
    throw StateError(mensagem);
  }
}

ItemPalco item({
  TipoPalco tipo = TipoPalco.imagem,
  String miniatura = 'https://exemplo/imagem.jpg',
  int largura = 0,
  int altura = 0,
}) =>
    ItemPalco(
      tipo: tipo,
      titulo: 'teste',
      url: 'https://exemplo/pagina',
      miniatura: miniatura,
      largura: largura,
      altura: altura,
    );

void main() {
  // 1. Sem imagem não há moldura de mídia.
  final semImagem = molduraDoItem(item(miniatura: ''));
  exigir(semImagem.tipo == MolduraPalco.semImagem, 'deveria ser sem imagem');
  exigir(semImagem.alturaRelativa < 0.3, 'sem imagem deve ocupar pouco espaço');
  ok('item sem imagem usa a moldura vazia');

  // 2. Vídeo tem capa larga e recorte de capa.
  final video = molduraDoItem(item(tipo: TipoPalco.video));
  exigir(video.tipo == MolduraPalco.capaVideo, 'vídeo deveria usar capa');
  exigir(!video.cabeInteira, 'capa de vídeo preenche a caixa');
  ok('vídeo usa moldura de capa');

  // 3. Notícia é menor que vídeo, para o texto aparecer.
  final noticia = molduraDoItem(item(tipo: TipoPalco.noticia));
  exigir(noticia.tipo == MolduraPalco.capaNoticia, 'notícia deveria ter capa');
  exigir(noticia.alturaRelativa < video.alturaRelativa,
      'notícia deve ocupar menos altura que vídeo');
  ok('notícia usa capa baixa, deixando espaço para o texto');

  // 4. Foto larga vira capa recortada.
  final larga = molduraDoItem(item(largura: 1600, altura: 900));
  exigir(larga.tipo == MolduraPalco.capaLarga, '16:9 deveria ser capa larga');
  exigir(!larga.cabeInteira, 'capa larga recorta para preencher');
  ok('imagem larga vira capa');

  // 5. Foto em pé aparece inteira.
  final emPe = molduraDoItem(item(largura: 800, altura: 1200));
  exigir(emPe.tipo == MolduraPalco.retratoAlto, '2:3 deveria ser retrato');
  exigir(emPe.cabeInteira, 'retrato deve caber inteiro');
  exigir(emPe.proporcao < 0.7, 'proporção deveria ser a da foto: ${emPe.proporcao}');
  ok('imagem em pé aparece inteira, sem corte');

  // 6. Foto quase quadrada fica inteira, em caixa média.
  final quadrada = molduraDoItem(item(largura: 1000, altura: 1000));
  exigir(quadrada.tipo == MolduraPalco.quadrada, '1:1 deveria ser quadrada');
  exigir(quadrada.cabeInteira, 'quadrada cabe inteira');
  ok('imagem quadrada cabe inteira');

  // 7. Sem tamanho declarado, a proporção padrão é 4:3.
  final semMedida = molduraDoItem(item());
  exigir(semMedida.tipo == MolduraPalco.quadrada,
      '4:3 sem medida deveria cair na quadrada, veio ${semMedida.tipo}');
  ok('imagem sem medida declarada usa a proporção padrão');

  // 8. Altura nunca passa de 62% da tela nem afunda abaixo de 110 px.
  final altaAltura = video.alturaEm(3000);
  exigir(altaAltura <= 3000 * 0.62, 'altura passou do teto: $altaAltura');
  final telaBaixa = video.alturaEm(200);
  exigir(telaBaixa >= 110, 'altura mínima respeitada: $telaBaixa');
  ok('altura da moldura respeita teto e piso');

  print('palco: $checks verificações');
}
