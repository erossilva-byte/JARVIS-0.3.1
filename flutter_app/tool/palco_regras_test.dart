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

void quase(double a, double b, String mensagem) {
  if ((a - b).abs() > 0.0001) {
    print('FALHOU: $mensagem (esperado $b, veio $a)');
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
  // 1. O padrão é o de sempre: as regras novas não mudam o palco que existia.
  const padrao = RegrasPalco.padrao;
  quase(padrao.capaLarga.altura, 0.38, 'altura da capa larga');
  quase(padrao.retratoAlto.altura, 0.56, 'altura do retrato');
  quase(padrao.quadrada.altura, 0.44, 'altura da quase quadrada');
  quase(padrao.capaVideo.altura, 0.34, 'altura do vídeo');
  quase(padrao.capaNoticia.altura, 0.26, 'altura da notícia');
  exigir(padrao.retratoAlto.cabeInteira && !padrao.capaLarga.cabeInteira,
      'recorte padrão errado');
  ok('regras padrão mantêm o enquadramento atual');

  // 2. Trocar uma regra não mexe nas outras.
  final personalizada =
      padrao.comRegra(MolduraPalco.capaVideo,
          const RegraMoldura(altura: 0.55, cabeInteira: true));
  quase(personalizada.capaVideo.altura, 0.55, 'vídeo alterado');
  exigir(personalizada.capaVideo.cabeInteira, 'vídeo inteiro');
  quase(personalizada.capaLarga.altura, padrao.capaLarga.altura,
      'capa larga não deveria mudar');
  ok('mudar o vídeo não mexe nas outras regras');

  // 3. A altura é limitada a 15%–62% da tela.
  final alta = const RegraMoldura(altura: 0.95, cabeInteira: false);
  quase(alta.alturaLimitada, RegraMoldura.alturaMaxima, 'teto de altura');
  final baixa = const RegraMoldura(altura: 0.01, cabeInteira: true);
  quase(baixa.alturaLimitada, RegraMoldura.alturaMinima, 'piso de altura');
  final copia = baixa.copiarCom(altura: 0.30);
  quase(copia.altura, 0.30, 'copiarCom muda a altura');
  ok('altura respeita piso e teto');

  // 4. As regras valem no palco de verdade.
  final video = molduraDoItem(item(tipo: TipoPalco.video),
      regras: personalizada);
  exigir(video.tipo == MolduraPalco.capaVideo, 'vídeo deveria ser capa');
  quase(video.alturaRelativa, 0.55, 'vídeo com altura nova');
  exigir(video.cabeInteira, 'vídeo inteiro pela regra');
  ok('a moldura do vídeo obedece à regra do usuário');

  final noticia = molduraDoItem(item(tipo: TipoPalco.noticia),
      regras: const RegrasPalco(
          capaNoticia: RegraMoldura(altura: 0.2, cabeInteira: true)));
  quase(noticia.alturaRelativa, 0.2, 'notícia com altura nova');
  exigir(noticia.cabeInteira, 'notícia inteira');
  ok('a moldura da notícia obedece à regra do usuário');

  // 5. Os limiares classificam a foto.
  final regrasLargas = padrao.copiarCom(limiarLargo: 2.0);
  exigir(molduraDoItem(item(largura: 1800, altura: 1000),
              regras: regrasLargas)
          .tipo ==
      MolduraPalco.quadrada, '1,8:1 deveria ser quase quadrada com limiar 2,0');
  exigir(molduraDoItem(item(largura: 2400, altura: 1000),
              regras: regrasLargas)
          .tipo ==
      MolduraPalco.capaLarga, '2,4:1 deveria ser capa larga');
  final regrasEstreitas = padrao.copiarCom(limiarEstreito: 0.55);
  exigir(molduraDoItem(item(largura: 900, altura: 1000),
              regras: regrasEstreitas)
          .tipo ==
      MolduraPalco.quadrada, '0,9:1 deveria ser quase quadrada com limiar 0,55');
  ok('os limiares decidem capa larga, quase quadrada e retrato');

  // 6. O limiar largo nunca fica abaixo do estreito.
  final apertadas =
      padrao.copiarCom(limiarLargo: 1.1, limiarEstreito: 0.95);
  exigir(apertadas.limiarLargo > apertadas.limiarEstreito,
      'limiares se cruzaram: ${apertadas.limiarLargo} x ${apertadas.limiarEstreito}');
  final fora = padrao.copiarCom(limiarLargo: 9, limiarEstreito: -1);
  exigir(
      fora.limiarLargo <= RegrasPalco.limiarLargoMaximo &&
          fora.limiarEstreito >= RegrasPalco.limiarEstreitoMinimo,
      'limiares fora da faixa não foram contidos');
  ok('limiares ficam na faixa e nunca se cruzam');

  // 7. Ida e volta pelo JSON.
  final guardada =
      padrao.comRegra(MolduraPalco.retratoAlto,
          const RegraMoldura(altura: 0.5, cabeInteira: false));
  final lida = RegrasPalco.deJson(guardada.paraJson());
  quase(lida.retratoAlto.altura, 0.5, 'altura do retrato no JSON');
  exigir(!lida.retratoAlto.cabeInteira, 'recorte do retrato no JSON');
  quase(lida.capaLarga.altura, guardada.capaLarga.altura, 'capa larga no JSON');
  ok('as regras voltam do JSON como foram salvas');

  // 8. Texto estragado ou ausente volta ao padrão, sem exceção.
  exigir(RegrasPalco.deJson('nada de json') == padrao ||
      RegrasPalco.deJson('nada de json').capaLarga.altura ==
          padrao.capaLarga.altura, 'json inválido deveria voltar ao padrão');
  exigir(RegrasPalco.deJson(null).capaVideo.altura == padrao.capaVideo.altura,
      'sem dados deveria voltar ao padrão');
  exigir(
      RegrasPalco.deJson({'capaLarga': {'altura': 'alta'}})
              .capaLarga
              .altura ==
          padrao.capaLarga.altura,
      'altura inválida deveria manter o padrão');
  ok('json inválido não quebra o palco');

  // 9. Regra de cada moldura é acessível e a sem imagem é fixa.
  for (final tipo in MolduraPalco.values) {
    exigir(guardada.regraDe(tipo).altura > 0, 'regra ausente para $tipo');
  }
  exigir(guardada.regraDe(MolduraPalco.semImagem).altura == 0.24,
      'a moldura sem imagem não é editável');
  ok('todas as molduras têm regra');

  print('regras do palco: $checks verificações');
}
