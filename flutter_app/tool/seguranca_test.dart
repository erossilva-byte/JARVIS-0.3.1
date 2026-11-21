import 'dart:math';
import 'dart:io';

import 'package:jarvis_nova/core/seguranca.dart';

void main() {
  // 1. Política do PIN recusa o que é adivinhado em segundos.
  assert(avaliarPin('2583') == PoliticaPin.ok, 'PIN comum foi recusado');
  assert(avaliarPin('123') == PoliticaPin.curto, 'PIN curto foi aceito');
  assert(avaliarPin('123456789') == PoliticaPin.longo, 'PIN longo foi aceito');
  assert(avaliarPin('12a4') == PoliticaPin.naoNumerico, 'letra foi aceita');
  assert(avaliarPin('0000') == PoliticaPin.repetido, 'dígitos repetidos aceitos');
  assert(avaliarPin('777777') == PoliticaPin.repetido, 'repetição longa aceita');
  assert(avaliarPin('1234') == PoliticaPin.sequencia, 'sequência crescente aceita');
  assert(avaliarPin('9876') == PoliticaPin.sequencia, 'sequência decrescente aceita');
  assert(avaliarPin('2580') == PoliticaPin.comum, 'PIN de lista comum aceito');
  assert(avaliarPin('1122') == PoliticaPin.comum, 'PIN comum 1122 aceito');
  assert(avaliarPin('') == PoliticaPin.curto, 'PIN vazio aceito');
  assert(avaliarPin('  ').toString().contains('curto'), 'espaços viraram PIN');
  for (final politica in PoliticaPin.values) {
    assert(mensagemPolitica(politica).isNotEmpty, '$politica sem mensagem');
  }

  // 2. Derivação é determinística por sal e muda com o sal.
  final salA = novoSalt(Random(7));
  final salB = novoSalt(Random(9));
  assert(salA.length == bytesSal, 'sal com tamanho errado');
  assert(salA.toSet().length > 1, 'sal constante não é aleatório');
  final digest = derivarPin('2583', salA, iteracoes: 500);
  assert(digest.length == bytesHash, 'digest com tamanho errado');
  assert(compararDigest(digest, derivarPin('2583', salA, iteracoes: 500)),
      'mesma entrada gerou digest diferente');
  assert(!compararDigest(digest, derivarPin('2583', salB, iteracoes: 500)),
      'sal diferente gerou o mesmo digest');
  assert(!compararDigest(digest, derivarPin('2584', salA, iteracoes: 500)),
      'PIN diferente gerou o mesmo digest');
  assert(!compararDigest(digest, derivarPin('2583', salA, iteracoes: 501)),
      'iterações diferentes geraram o mesmo digest');
  assert(!compararDigest(digest, digest.sublist(0, 8)), 'tamanhos diferentes aceitos');
  assert(!compararDigest(const [], const []), 'digests vazios aceitos');

  // 3. Hex do sal e do digest sobrevive à ida e volta.
  final hex = hexDe(salA);
  assert(hex.length == bytesSal * 2, 'hex com tamanho errado');
  assert(compararDigest(bytesDeHex(hex)!, salA), 'hex não voltou igual');
  assert(bytesDeHex('xyz') == null, 'hex inválido foi aceito');
  assert(bytesDeHex('abc') == null, 'hex ímpar foi aceito');

  // 4. Tentativas: erro conta, acerto zera, limite impõe espera.
  final agora = DateTime(2026, 11, 19, 12, 0);
  var config = ConfigBloqueio.desligado
      .copiarCom(ativo: true, espera: const Duration(seconds: 30));
  assert(config.restantes == tentativasAntesDeEspera, 'contagem inicial errada');

  final erro1 = avaliarTentativa(config: config, pinCorreto: false, agora: agora);
  assert(!erro1.ok && erro1.config.tentativas == 1, 'primeira falha não contou');
  assert(erro1.mensagem.contains('Restam'), 'mensagem de restantes ausente');
  config = erro1.config;
  for (var i = 2; i < tentativasAntesDeEspera; i++) {
    config = avaliarTentativa(config: config, pinCorreto: false, agora: agora).config;
  }
  final limite =
      avaliarTentativa(config: config, pinCorreto: false, agora: agora);
  assert(!limite.ok, 'limite de tentativas desbloqueou');
  assert(limite.config.bloqueadoEm(agora), 'espera não foi aplicada');
  assert(limite.mensagem.contains('Aguarde'), 'mensagem de espera ausente');
  assert(
      !avaliarTentativa(
              config: limite.config, pinCorreto: true, agora: agora)
          .ok,
      'PIN certo passou durante a espera');

  final depois = agora.add(const Duration(seconds: 31));
  final correto =
      avaliarTentativa(config: limite.config, pinCorreto: true, agora: depois);
  assert(correto.ok, 'PIN certo não desbloqueou depois da espera');
  assert(correto.config.tentativas == 0, 'acerto não zerou as falhas');
  assert(!correto.config.bloqueadoEm(depois), 'espera continuou depois do acerto');

  // 5. Configuração sobrevive à serialização sem inventar nada.
  final salva = config.copiarCom(
    biometria: true,
    espera: const Duration(minutes: 1),
    bloqueadoAte: agora,
  );
  final lida = ConfigBloqueio.fromMap(salva.toMap());
  assert(lida.ativo && lida.biometria, 'flags perdidas');
  assert(lida.espera == const Duration(minutes: 1), 'espera perdida');
  assert(lida.bloqueadoAte == agora, 'data de espera perdida');
  final vazia = ConfigBloqueio.fromMap({});
  assert(!vazia.ativo && !vazia.biometria, 'mapa vazio ligou o bloqueio');
  assert(vazia.espera == Duration.zero, 'mapa vazio inventou espera');
  assert(ConfigBloqueio.desligado.restanteDeEspera(agora) == Duration.zero,
      'sem espera deveria ser zero');
  assert(
      config.copiarCom(bloqueadoAte: agora.add(const Duration(seconds: 10)))
              .restanteDeEspera(agora)
              .inSeconds ==
          10,
      'restante de espera errado');

  // 6. Volta do segundo plano respeita o tempo escolhido.
  final ativo = ConfigBloqueio.desligado
      .copiarCom(ativo: true, espera: const Duration(minutes: 5));
  assert(
      !deveBloquearAoVoltar(
          config: ativo,
          saiuEm: agora.subtract(const Duration(minutes: 1)),
          agora: agora),
      'bloqueou antes do tempo');
  assert(
      deveBloquearAoVoltar(
          config: ativo,
          saiuEm: agora.subtract(const Duration(minutes: 6)),
          agora: agora),
      'não bloqueou depois do tempo');
  assert(
      !deveBloquearAoVoltar(
          config: ConfigBloqueio.desligado, saiuEm: agora, agora: agora),
      'bloqueou com o recurso desligado');
  assert(
      !deveBloquearAoVoltar(config: ativo, saiuEm: null, agora: agora),
      'bloqueou sem ter saído');
  assert(rotuloEspera(Duration.zero) == 'Imediatamente', 'rótulo imediato errado');
  assert(rotuloEspera(const Duration(seconds: 30)) == '30 segundos',
      'rótulo de segundos errado');
  assert(rotuloEspera(const Duration(minutes: 1)) == '1 minuto',
      'rótulo de minuto errado');
  assert(esperasBloqueio.length == 4, 'opções de espera inesperadas');

  // 7. Biometria: só "pronto" pode ser usada; o resto explica.
  assert(!BiometriaStatus.indisponivel.podeUsar, 'indisponível liberou biometria');
  final pronta = BiometriaStatus.fromMap({'estado': 'pronto', 'api': 34});
  assert(pronta.podeUsar && pronta.api == 34, 'estado pronto não lido');
  assert(BiometriaStatus.fromMap({'estado': 'sem_cadastro'}).podeUsar == false,
      'sem cadastro liberou biometria');
  assert(BiometriaStatus.fromMap({'estado': 'outra coisa'}).estado ==
      EstadoBiometria.indisponivel, 'estado desconhecido virou disponível');
  for (final estado in EstadoBiometria.values) {
    assert(BiometriaStatus(estado: estado).descricao.isNotEmpty,
        '$estado sem descrição');
  }

  stdout.writeln(
      'OK: segurança — política de PIN, derivação com sal, tentativas, serialização, espera e biometria');
}
