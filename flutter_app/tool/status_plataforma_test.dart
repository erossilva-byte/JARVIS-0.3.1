import 'package:jarvis_nova/core/status_plataforma.dart';

void main() {
  // 1. Mapa do PC (o que o Electron entrega em status_pc).
  final pc = StatusPlataforma.deMapa({
    'cpu': 17,
    'ramLivre': 8589934592, // 8 GB
    'ramTotal': 17179869184, // 16 GB
    'discoLivre': 107374182400, // 100 GB
    'discoTotal': 536870912000, // 500 GB
    'aparelho': 'Windows_NT 10.0.19045 · x64',
    'uptime': '2 dia(s) e 3 h',
    'carregado': 1,
  }, origem: OrigemStatus.pc)!;
  assert(pc.titulo == 'Status do PC', 'título do PC saiu errado: ${pc.titulo}');
  assert(!pc.semDados, 'PC com dados foi tratado como vazio');
  final linhasPc = pc.linhas.map((l) => '${l.rotulo}: ${l.valor}').toList();
  assert(linhasPc.contains('Processador: 17% de uso'), 'CPU: $linhasPc');
  assert(linhasPc.contains('Memória: 8 GB de 16 GB em uso (50%)'),
      'memória: $linhasPc');
  assert(linhasPc.contains('Disco: 400 GB de 500 GB em uso (80%)'),
      'disco: $linhasPc');
  assert(linhasPc.contains('Ligado há: 2 dia(s) e 3 h'), 'uptime: $linhasPc');
  assert(linhasPc.contains('Sistema: Windows_NT 10.0.19045 · x64'),
      'sistema: $linhasPc');
  assert(!linhasPc.any((l) => l.contains('Bateria')),
      'PC de mesa não deve inventar bateria');

  // 2. Mapa do celular (o que o Android entrega).
  final celular = StatusPlataforma.deMapa({
    'bateria': 78,
    'temperatura': 31.5,
    'ramTotal': 4294967296,
    'ramLivre': 2147483648,
    'discoTotal': 128849018880,
    'discoLivre': 64424509440,
    'uptimeMin': 2880,
    'conexao': 'Wi-Fi',
    'modelo': 'Pixel 8 · Android 14',
    'carregando': true,
  }, origem: OrigemStatus.celular)!;
  assert(celular.titulo == 'Status do celular',
      'título do celular saiu errado: ${celular.titulo}');
  final linhasCel = celular.linhas.map((l) => '${l.rotulo}: ${l.valor}').toList();
  assert(linhasCel.contains('Bateria: 78% (carregando)'), 'bateria: $linhasCel');
  assert(linhasCel.contains('Temperatura: 31,5 °C'), 'temperatura: $linhasCel');
  assert(linhasCel.contains('Memória: 2 GB de 4 GB em uso (50%)'),
      'memória do celular: $linhasCel');
  assert(linhasCel.contains('Ligado há: 2 dia(s)'), 'uptime do celular: $linhasCel');
  assert(linhasCel.contains('Rede: Wi-Fi'), 'rede: $linhasCel');
  assert(!linhasCel.any((l) => l.startsWith('Processador')),
      'celular não informa CPU aqui; não pode inventar');

  // 3. Não inventa: mapa vazio ou sem nada útil devolve vazio honesto.
  assert(StatusPlataforma.deMapa(null, origem: OrigemStatus.pc) == null,
      'mapa nulo deveria dar null');
  final vazio = StatusPlataforma.deMapa({'carregado': 1}, origem: OrigemStatus.pc)!;
  assert(vazio.semDados, 'mapa sem campos úteis deveria ser semDados');
  assert(vazio.linhas.isEmpty, 'mapa sem campos não pode gerar linha');

  // 4. Campo faltando some, e não vira zero.
  final soBateria = StatusPlataforma.deMapa(
      {'bateria': 50}, origem: OrigemStatus.celular)!;
  assert(soBateria.linhas.length == 1, 'linha inventada: ${soBateria.linhas}');
  assert(soBateria.linhas.single.valor == '50%', 'bateria errada');

  // 5. Memória só com o total continua legível.
  final soTotal = StatusPlataforma.deMapa(
      {'ramTotal': 8589934592}, origem: OrigemStatus.pc)!;
  assert(soTotal.linhas.single.valor == '8 GB no total',
      'total sem livre: ${soTotal.linhas.single.valor}');

  // 6. Uptime em minutos vira texto falável.
  assert(StatusPlataforma.deMapa({'uptimeMin': 45}, origem: OrigemStatus.celular)!
          .uptimeTexto ==
      '45 min', 'uptime curto');
  assert(StatusPlataforma.deMapa({'uptimeMin': 300}, origem: OrigemStatus.celular)!
          .uptimeTexto ==
      '5 h', 'uptime em horas');
  assert(StatusPlataforma.deMapa({'uptimeMin': 2880}, origem: OrigemStatus.celular)!
          .uptimeTexto ==
      '2 dia(s)', 'uptime exato em dias');
  assert(StatusPlataforma.deMapa({'uptimeMin': 3060}, origem: OrigemStatus.celular)!
          .uptimeTexto ==
      '2 dia(s) e 3 h', 'uptime com sobra');
}
