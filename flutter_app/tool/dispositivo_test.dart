// ignore_for_file: avoid_print

import 'package:jarvis_nova/core/dispositivo.dart';

int checks = 0;

void ok(String nome) {
  checks++;
  print('OK: $nome');
}

void exigir(bool condicao, String mensagem) {
  if (!condicao) throw StateError(mensagem);
}

void main() {
  final info = InfoDispositivo.deMapa({
    'memoriaTotalMb': 12288,
    'memoriaLivreMb': 3072,
    'memoriaBaixa': false,
    'armazenamentoTotalGb': 256.0,
    'armazenamentoLivreGb': 128.0,
    'uptimeMin': 1500,
    'bateria': 84,
    'carregando': true,
    'rede': 'wifi',
    'apps': [
      {'pacote': 'com.whatsapp', 'nome': 'WhatsApp'},
      {'pacote': 'com.spotify.music'},
      {'nome': 'sem pacote'},
      'lixo',
    ],
  });
  exigir(info.memoriaTotalMb == 12288, 'memória total');
  exigir(info.memoriaLivrePct!.round() == 25, 'percentual de memória');
  exigir(info.armazenamentoLivrePct!.round() == 50, 'percentual de disco');
  ok('percentuais de memória e armazenamento calculados');

  exigir(info.uptimeRotulo == '1d 1h', 'uptime: ${info.uptimeRotulo}');
  exigir(info.redeRotulo == 'Wi-Fi', 'rede');
  exigir(info.bateria == 84 && info.carregando, 'bateria carregando');
  ok('uptime, rede e bateria formatados');

  exigir(info.apps.length == 2, 'apps válidos: ${info.apps.length}');
  exigir(info.apps[1].nome == 'com.spotify.music',
      'app sem rótulo usa o pacote');
  ok('lista de apps ignora itens inválidos e usa o pacote como nome');

  final vazio = InfoDispositivo.deMapa(null);
  exigir(vazio.apps.isEmpty && vazio.memoriaLivrePct == null, 'vazio');
  exigir(vazio.uptimeRotulo == 'não informado', 'uptime desconhecido');
  exigir(vazio.redeRotulo == 'Não informado', 'rede desconhecida');
  ok('resposta ausente não inventa número nenhum');

  final movel = InfoDispositivo.deMapa({'rede': 'movel', 'uptimeMin': 42});
  exigir(movel.redeRotulo == 'Dados móveis', 'rede móvel');
  exigir(movel.uptimeRotulo == '42min', 'uptime curto');
  exigir(movel.bateria == null, 'bateria ausente');
  ok('rede móvel e uptime curto');

  print('\n$checks verificações da central do aparelho aprovadas.');
}
