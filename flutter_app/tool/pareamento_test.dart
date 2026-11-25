import 'dart:io';
import 'dart:math';

import 'package:jarvis_nova/core/pareamento.dart';

void main() {
  // 1. Código: sempre 6 dígitos, com zero à esquerda quando preciso.
  final sorteio = Random(7);
  final vistos = <String>{};
  for (var i = 0; i < 200; i++) {
    final codigo = gerarCodigoPareamento(sorteio);
    assert(codigo.length == 6, 'código sem 6 dígitos: $codigo');
    assert(RegExp(r'^\d{6}$').hasMatch(codigo), 'código com não dígito: $codigo');
    vistos.add(codigo);
  }
  assert(vistos.length > 150, 'gerador repetiu demais: ${vistos.length}');

  // 2. O que o usuário digita é tolerado; o que não completa 6 dígitos não vale.
  assert(normalizarCodigoPareamento('123 456') == '123456', 'espaço não ignorado');
  assert(normalizarCodigoPareamento('123-456') == '123456', 'traço não ignorado');
  assert(codigoUtilizavel('123 456') == '123456', 'código com espaço recusado');
  assert(codigoUtilizavel('12345') == '', 'cinco dígitos aceitos');
  assert(codigoUtilizavel('1234567') == '', 'sete dígitos aceitos');
  assert(codigoUtilizavel('abc') == '', 'letras aceitas');
  assert(formatarCodigoPareamento('123456') == '123 456', 'formatação errada');

  // 3. Prova: mesma entrada, mesma saída; código diferente muda a prova.
  final prova = provaDePareamento('123456', 'desafio-1');
  assert(prova == provaDePareamento('123 456', 'desafio-1'),
      'espaço no código mudou a prova');
  assert(prova.length == 64, 'prova não é SHA-256 hexadecimal');
  assert(RegExp(r'^[0-9a-f]{64}$').hasMatch(prova), 'prova com caractere estranho');
  assert(prova != provaDePareamento('123457', 'desafio-1'),
      'código diferente gerou a mesma prova');
  assert(prova != provaDePareamento('123456', 'desafio-2'),
      'desafio diferente gerou a mesma prova');

  // Vetor fixo: se a regra mudar, o PC e o celular deixam de se entender.
  assert(
      provaDePareamento('123456', 'abc') ==
          'f6ced6f4883ffc0981a6b9945819f680102b43097ad8ef7a0df9bde06fb3d2e4',
      'prova fora do vetor combinado');

  // 4. Token: 64 caracteres hexadecimais, diferente a cada chamada.
  final r = Random(3);
  final t1 = tokenDePareamento(r);
  final t2 = tokenDePareamento(r);
  assert(t1.length == 64 && t2.length == 64, 'token com tamanho errado');
  assert(t1 != t2, 'dois tokens iguais');

  // 5. Comparação em tempo constante continua comparando.
  assert(iguaisEmTempoConstante('abc', 'abc'), 'iguais recusados');
  assert(!iguaisEmTempoConstante('abc', 'abd'), 'diferentes aceitos');
  assert(!iguaisEmTempoConstante('abc', 'ab'), 'tamanhos diferentes aceitos');

  // 6. Oferta: prazo de 2 minutos e tentativas contadas.
  final criada = DateTime(2026, 11, 25, 10, 0, 0);
  final oferta = OfertaPareamento(
      codigo: '123456', desafio: 'desafio', criadoEm: criada);
  assert(oferta.valeEm(criada), 'oferta nova não vale');
  assert(oferta.segundosRestantes(criada) == validadeOfertaSegundos,
      'prazo inicial errado');
  assert(!oferta.expirou(criada.add(const Duration(seconds: 119))),
      'expirou antes do prazo');
  assert(oferta.expirou(criada.add(const Duration(seconds: 120))),
      'não expirou no prazo');
  assert(oferta.segundosRestantes(criada.add(const Duration(hours: 1))) == 0,
      'segundos restantes ficaram negativos');

  final certa = provaDePareamento('123456', 'desafio');
  assert(!oferta.conferirProva('0' * 64, agora: criada), 'prova errada aceita');
  assert(oferta.tentativasRestantes == tentativasPareamento - 1,
      'erro não gastou tentativa');
  assert(oferta.conferirProva(certa, agora: criada), 'prova certa recusada');
  assert(oferta.tentativasRestantes == 0, 'acerto não fechou a oferta');
  assert(!oferta.conferirProva(certa, agora: criada),
      'oferta consumida aceitou de novo');

  final queimada = OfertaPareamento(
      codigo: '123456', desafio: 'd', criadoEm: criada);
  for (var i = 0; i < tentativasPareamento; i++) {
    queimada.conferirProva('x', agora: criada);
  }
  assert(queimada.tentativasRestantes == 0, 'tentativas não zeraram');

  // 7. Registro do PC: ida e volta, e lixo não vira registro.
  final registro = RegistroPareamento(
    dispositivo: 'PC da oficina',
    ip: '192.168.0.10',
    porta: 47600,
    token: 'a' * 64,
    criadoEm: criada,
  );
  final voltou = RegistroPareamento.deMapa(registro.paraMapa());
  assert(voltou != null && voltou.dispositivo == 'PC da oficina',
      'registro não sobreviveu ao mapa');
  assert(voltou!.endereco == '192.168.0.10:47600', 'endereço do registro errado');
  assert(RegistroPareamento.deMapa(null) == null, 'nulo virou registro');
  assert(RegistroPareamento.deMapa({'dispositivo': 'x'}) == null,
      'registro incompleto aceito');
  assert(
      RegistroPareamento.deMapa({
        'dispositivo': 'x',
        'ip': 'y',
        'token': 'z',
        'porta': 0,
      }) ==
          null,
      'porta zero aceita');

  // 8. Só rede local.
  for (final bom in [
    '127.0.0.1',
    'localhost',
    '10.1.2.3',
    '192.168.0.10',
    '172.16.0.1',
    '172.31.255.254',
    '169.254.10.20',
    '::1',
    'fe80::1',
    'fd12::34',
  ]) {
    assert(enderecoDaRedeLocal(bom), 'endereço local recusado: $bom');
  }
  for (final ruim in [
    '8.8.8.8',
    '172.32.0.1',
    '192.169.0.1',
    '200.1.2.3',
    'exemplo.com',
    '',
  ]) {
    assert(!enderecoDaRedeLocal(ruim), 'endereço público aceito: $ruim');
  }

  // 9. Endereço digitado no PC: host, porta e recusa do que não é LAN.
  final simples = enderecoDoCelular('192.168.0.20');
  assert(simples != null && simples.host == '192.168.0.20',
      'host simples recusado');
  assert(simples!.porta == portaPareamento, 'porta padrão errada');
  final comPorta = enderecoDoCelular('192.168.0.20:5000');
  assert(comPorta != null && comPorta.porta == 5000, 'porta digitada ignorada');
  final comEsquema = enderecoDoCelular('http://10.0.0.5:47600/');
  assert(comEsquema != null && comEsquema.host == '10.0.0.5',
      'esquema e barra atrapalharam');
  final ipv6 = enderecoDoCelular('[::1]:4444');
  assert(ipv6 != null && ipv6.host == '::1' && ipv6.porta == 4444,
      'IPv6 entre colchetes não lido');
  assert(enderecoDoCelular('8.8.8.8') == null, 'IP público aceito');
  assert(enderecoDoCelular('192.168.0.10:0') == null, 'porta zero aceita');
  assert(enderecoDoCelular('') == null, 'endereço vazio aceito');

  stdout.writeln(
      'OK: pareamento — código, prova, token, oferta, registro e rede local.');
}
