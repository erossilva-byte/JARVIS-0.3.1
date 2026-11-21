// ignore_for_file: avoid_print

import 'package:jarvis_nova/core/comandos_android.dart';

int checks = 0;

void ok(String nome) {
  checks++;
  print('OK: $nome');
}

void exigir(bool condicao, String mensagem) {
  if (!condicao) throw StateError(mensagem);
}

void main() {
  final ligar = InterpretadorComandos.interpretar('ligar a lanterna');
  exigir(ligar is ComandoLanterna && ligar.ligar == true, 'lanterna on');
  final desligar = InterpretadorComandos.interpretar('apague a lanterna');
  exigir(
      desligar is ComandoLanterna && desligar.ligar == false, 'lanterna off');
  final alternar = InterpretadorComandos.interpretar('lanterna');
  exigir(
      alternar is ComandoLanterna && alternar.ligar == null, 'lanterna toggle');
  ok('lanterna liga, desliga e alterna');

  final volume = InterpretadorComandos.interpretar('volume 50');
  exigir(volume is ComandoVolume && volume.percentual == 50, 'volume 50');
  final porcento = InterpretadorComandos.interpretar('30% de volume');
  exigir(porcento is ComandoVolume && porcento.percentual == 30, '30% volume');
  final mais = InterpretadorComandos.interpretar('aumentar o volume');
  exigir(mais is ComandoVolume && mais.delta == 10, 'aumentar volume');
  final menos = InterpretadorComandos.interpretar('abaixe o volume');
  exigir(menos is ComandoVolume && menos.delta == -10, 'abaixar volume');
  final mudo = InterpretadorComandos.interpretar('silenciar');
  exigir(mudo is ComandoVolume && mudo.percentual == 0, 'silenciar');
  ok('volume absoluto, relativo e mudo');

  final app = InterpretadorComandos.interpretar('abrir WhatsApp');
  exigir(app is ComandoAbrirApp && app.nome == 'whatsapp', 'abrir app');
  final appComArtigo = InterpretadorComandos.interpretar('abre o YouTube');
  exigir(appComArtigo is ComandoAbrirApp && appComArtigo.nome == 'youtube',
      'abrir app com artigo');
  ok('abrir app');

  final alarme = InterpretadorComandos.interpretar('alarme 7:30');
  exigir(alarme is ComandoAlarme && alarme.hora == 7 && alarme.minuto == 30,
      'alarme');
  final alarmeH = InterpretadorComandos.interpretar('despertador 18h05');
  exigir(alarmeH is ComandoAlarme && alarmeH.hora == 18, 'alarme com h');
  ok('alarme');

  final localizacao = InterpretadorComandos.interpretar('onde estou');
  exigir(localizacao is ComandoLocalizacao, 'localização não interpretada');
  exigir(InterpretadorComandos.interpretar('minha localização atual')
      is ComandoLocalizacao, 'localização com "atual" não interpretada');
  ok('localização do aparelho');

  for (final pergunta in [
    'onde fica Paris?',
    'como chegar no centro?',
    'por que a localização está desligada?',
    'como ligar a lanterna?',
    'por que a lanterna não funciona?',
    'como abrir o WhatsApp?',
    'abrir arquivo de texto',
    'me explique o volume de um cilindro',
    'Bom dia',
    'volume 150',
    'alarme 25:00',
  ]) {
    exigir(InterpretadorComandos.interpretar(pergunta) == null,
        'interceptou pergunta: $pergunta');
  }
  ok('perguntas e valores inválidos seguem para a conversa');

  exigir(acoesAndroid.length == 5, 'registro incompleto');
  exigir(
      acoesAndroid.every((a) =>
          a.risco == RiscoComando.baixo || a.risco == RiscoComando.medio),
      'ação de alto risco sem confirmação');
  ok('registro de ações com risco e permissão');

  print('\nComandos Android: $checks grupos de verificação aprovados.');
}
