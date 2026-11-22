import 'dart:io';

import 'package:jarvis_nova/core/comandos_android.dart';
import 'package:jarvis_nova/core/localizacao.dart';

void main() {
  // 1. Estado sem permissão não promete leitura.
  const semPermissao = EstadoLocalizacao(
    permissao: false,
    gpsLigado: true,
    redeLigada: true,
    geocoder: true,
  );
  assert(!semPermissao.podeLer, 'sem permissão a leitura foi dada como pronta');
  assert(semPermissao.descricao.contains('Sem permissão'),
      'estado sem permissão não explicou o motivo');

  // 2. Permissão sem GPS nem rede também não pode ler.
  const semProvedor = EstadoLocalizacao(
    permissao: true,
    gpsLigado: false,
    redeLigada: false,
    geocoder: false,
  );
  assert(!semProvedor.podeLer, 'sem provedor a leitura foi dada como pronta');
  assert(semProvedor.descricao.contains('desligada'),
      'estado sem provedor não falou da localização desligada');

  // 3. Estado completo lê e nomeia as fontes.
  const completo = EstadoLocalizacao(
    permissao: true,
    gpsLigado: true,
    redeLigada: true,
    geocoder: true,
  );
  assert(completo.podeLer, 'estado completo não pôde ler');
  assert(completo.descricao.contains('GPS') && completo.descricao.contains('rede'),
      'descrição não citou os provedores');

  // 4. Mapa do Android vira estado; campo ausente não vira true.
  final doAndroid = EstadoLocalizacao.deMapa({
    'permissao': true,
    'gpsLigado': true,
    'redeLigada': false,
    'geocoder': false,
  });
  assert(doAndroid.permissao && doAndroid.gpsLigado, 'estado do Android perdido');
  assert(!doAndroid.redeLigada && !doAndroid.geocoder, 'campo falso virou true');
  assert(EstadoLocalizacao.deMapa(null) == EstadoLocalizacao.desconhecido,
      'mapa nulo não virou estado desconhecido');

  // 5. Leitura boa: coordenadas, precisão, idade, endereço e frase honesta.
  final boa = LocalizacaoAparelho.deMapa({
    'ok': true,
    'latitude': -22.90556,
    'longitude': -47.06083,
    'precisaoMetros': 18.4,
    'fonte': 'nova_leitura',
    'provedor': 'gps',
    'idadeMs': 4200,
    'endereco': 'Campinas, São Paulo',
  });
  assert(boa.valida, 'leitura válida foi recusada');
  assert(boa.coordenadas == '-22.90556, -47.06083', 'coordenadas formatadas errado');
  assert(boa.precisaoRotulo == '±18 m', 'precisão arredondada errado');
  assert(boa.idadeRotulo == 'há 4 s', 'idade em segundos errada');
  assert(boa.fonteRotulo.contains('leitura nova'), 'fonte não traduzida');
  assert(boa.descricao.contains('Campinas'), 'endereço não entrou na descrição');
  final frase = fraseLocalizacao(boa);
  assert(frase.contains('Campinas') && frase.contains('-22.90556'),
      'frase falada sem endereço ou coordenadas');
  assert(frase.contains('±18 m'), 'frase falada sem precisão');

  // 6. Sem endereço, a frase diz que não tem endereço — não inventa lugar.
  final semEndereco = LocalizacaoAparelho.deMapa({
    'ok': true,
    'latitude': 10.0,
    'longitude': 20.0,
    'precisaoMetros': 0,
    'fonte': 'ultima_conhecida',
    'idadeMs': 300000,
    'endereco': '',
  });
  assert(semEndereco.valida, 'leitura sem endereço foi recusada');
  assert(semEndereco.idadeRotulo == 'há 5 min', 'idade em minutos errada');
  assert(semEndereco.fonteRotulo.contains('último ponto'), 'fonte antiga não marcada');
  assert(fraseLocalizacao(semEndereco).contains('Não tenho o endereço'),
      'frase inventou endereço ausente');

  // 7. Coordenadas fora do planeta e resposta sem números são recusadas.
  final fora = LocalizacaoAparelho.deMapa({
    'ok': true,
    'latitude': 120.0,
    'longitude': -47.0,
  });
  assert(!fora.valida, 'latitude impossível foi aceita');
  final semNumeros = LocalizacaoAparelho.deMapa({'ok': true});
  assert(!semNumeros.valida, 'ok sem coordenadas foi aceito');
  assert(semNumeros.mensagem.contains('sem as coordenadas'),
      'falta de coordenadas não foi explicada');

  // 8. Falha de permissão carrega o motivo e o pedido de autorização.
  final negada = LocalizacaoAparelho.deMapa({
    'ok': false,
    'precisaPermissao': true,
    'mensagem': 'Sem a permissão de localização eu não vejo onde o aparelho está.',
  });
  assert(!negada.valida && negada.precisaPermissao, 'permissão negada mal modelada');
  assert(negada.descricao.contains('permissão'), 'erro de permissão sem texto');
  assert(fraseLocalizacao(negada).contains('permissão'),
      'frase falada escondeu a falta de permissão');

  // 9. Mapa nulo não vira leitura válida.
  assert(!LocalizacaoAparelho.deMapa(null).valida, 'mapa nulo virou leitura');
  assert(LocalizacaoAparelho.deMapa(null).coordenadas == 'não informado',
      'coordenadas ausentes não foram marcadas');

  // 10. Comando "onde estou" existe no registro e é interpretado.
  final acao = acoesAndroid.firstWhere((a) => a.nome == 'localizacao');
  assert(acao.exemplo == 'onde estou', 'exemplo do comando errado');
  assert(acao.risco == RiscoComando.medio, 'risco do comando errado');
  for (final pedido in [
    'onde estou',
    'Onde eu estou agora?',
    'me diga onde estou',
    'qual é a minha localização',
    'minha localização atual',
    'localização',
  ]) {
    final comando = InterpretadorComandos.interpretar(pedido);
    assert(comando is ComandoLocalizacao, 'não interpretou "$pedido"');
  }

  // 11. Perguntas que só falam de lugar continuam indo para a conversa.
  for (final pergunta in [
    'onde fica Paris?',
    'como chegar no centro?',
    'por que a localização está desligada?',
    'como funciona o GPS?',
    'qual a previsão do tempo?',
  ]) {
    assert(InterpretadorComandos.interpretar(pergunta) == null,
        'hijack da conversa em "$pergunta"');
  }

  // 12. O registro continua com as ações anteriores.
  final nomes = acoesAndroid.map((a) => a.nome).toSet();
  for (final nome in ['lanterna', 'volume', 'abrir_app', 'alarme', 'localizacao']) {
    assert(nomes.contains(nome), 'ação "$nome" desapareceu do registro');
  }

  stdout.writeln(
      'OK: localização do aparelho — estado, leitura, honestidade e comando.');
}
