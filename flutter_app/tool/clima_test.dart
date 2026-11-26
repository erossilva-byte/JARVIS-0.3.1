import 'package:jarvis_nova/core/clima.dart';

void exigir(bool ok, String mensagem) {
  if (!ok) {
    // ignore: avoid_print
    print('FALHOU: $mensagem');
    throw StateError(mensagem);
  }
}

void main() {
  // Endereço sem chave, com as coordenadas e o fuso do próprio lugar.
  final url = urlDoClima(-23.5505, -46.6333);
  exigir(url.contains('api.open-meteo.com'), 'clima sem o Open-Meteo');
  exigir(url.contains('latitude=-23.5505'), 'latitude ausente');
  exigir(url.contains('longitude=-46.6333'), 'longitude ausente');
  exigir(url.contains('timezone=auto'), 'sem fuso automático');
  for (final proibido in ['api_key', 'apikey', 'token=', 'Authorization']) {
    exigir(!url.contains(proibido), 'clima pede chave: $proibido');
  }

  // Resposta real do provedor (recortada).
  const corpo = '{"current":{"temperature_2m":26.4,"apparent_temperature":28.1,'
      '"relative_humidity_2m":61,"weather_code":2,"wind_speed_10m":12.3,'
      '"precipitation":0,"is_day":1},'
      '"daily":{"temperature_2m_max":[31.2],"temperature_2m_min":[19.8]}}';
  final clima = lerClima(corpo);
  exigir(clima != null, 'não leu a resposta do clima');
  exigir(clima!.temperatura == 26.4, 'temperatura errada');
  exigir(clima.minima == 19.8 && clima.maxima == 31.2, 'mínima/máxima erradas');
  exigir(clima.descricaoCodigo == 'parcialmente nublado', 'código 2 traduzido errado');
  final frase = fraseClima(clima, lugar: 'São Paulo');
  exigir(frase.contains('26,4 °C'), 'frase sem a temperatura: $frase');
  exigir(frase.contains('São Paulo'), 'frase sem o lugar');
  exigir(frase.contains('mínima'), 'frase sem a mínima');
  exigir(frase.contains('parcialmente nublado'), 'frase sem a condição');

  // Sem temperatura não há clima — nada de número inventado.
  exigir(lerClima('{"current":{}}') == null, 'aceitou resposta sem temperatura');
  exigir(lerClima('não é json') == null, 'aceitou corpo inválido');
  exigir(descricaoClima(9999) == 'condição não informada',
      'código desconhecido virou texto inventado');

  // O que é e o que não é pedido de clima.
  for (final pedido in [
    'como está o tempo?',
    'qual a temperatura agora?',
    'vai chover hoje?',
    'previsão do tempo para amanhã',
    'quantos graus está fazendo?',
    'está frio lá fora?',
  ]) {
    exigir(pedidoDeClima(pedido), 'não reconheceu pedido de clima: $pedido');
  }
  for (final outro in [
    'quanto tempo falta para o almoço?',
    'por quanto tempo o app fica aberto?',
    'como abro a memória?',
    'abre o WhatsApp',
    'qual a minha localização?',
  ]) {
    exigir(!pedidoDeClima(outro), 'confundiu conversa com clima: $outro');
  }

  // ignore: avoid_print
  print('OK: clima (endereço sem chave, leitura, frase e pedido)');
}
