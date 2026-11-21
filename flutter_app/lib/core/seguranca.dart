/// Segurança da tela de bloqueio — contrato puro, sem Flutter e sem rede.
///
/// O PIN nunca é guardado: fica só o resultado de PBKDF2-HMAC-SHA256 com sal
/// aleatório. Este arquivo concentra a política do PIN, a derivação, a comparação
/// em tempo constante e o controle de tentativas, para tudo ser testável sem
/// emulador. A gravação e o prompt de biometria ficam nos serviços.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

const tamanhoMinPin = 4;
const tamanhoMaxPin = 8;

/// Falhas seguidas antes de uma espera obrigatória.
const tentativasAntesDeEspera = 5;

/// Espera aplicada quando o limite de tentativas é atingido.
const esperaPorTentativas = Duration(seconds: 30);

/// Custo da derivação. Alto o bastante para encarecer a tentativa por força bruta
/// e baixo o bastante para não travar um celular de entrada.
const iteracoesPadrao = 24000;
const bytesSal = 16;
const bytesHash = 32;

/// Tempo em segundo plano antes de pedir o PIN de novo.
const esperasBloqueio = <Duration>[
  Duration.zero,
  Duration(seconds: 30),
  Duration(minutes: 1),
  Duration(minutes: 5),
];

String rotuloEspera(Duration espera) {
  if (espera <= Duration.zero) return 'Imediatamente';
  if (espera.inSeconds < 60) return '${espera.inSeconds} segundos';
  final minutos = espera.inMinutes;
  return minutos == 1 ? '1 minuto' : '$minutos minutos';
}

/// Motivo de recusa de um PIN novo. [ok] é o único que aceita.
enum PoliticaPin { ok, curto, longo, naoNumerico, repetido, sequencia, comum }

String mensagemPolitica(PoliticaPin politica) => switch (politica) {
      PoliticaPin.ok => 'PIN aceito.',
      PoliticaPin.curto =>
        'O PIN precisa ter pelo menos $tamanhoMinPin dígitos.',
      PoliticaPin.longo => 'O PIN pode ter no máximo $tamanhoMaxPin dígitos.',
      PoliticaPin.naoNumerico => 'O PIN aceita somente números.',
      PoliticaPin.repetido =>
        'Não use o mesmo dígito repetido; isso é adivinhado em segundos.',
      PoliticaPin.sequencia =>
        'Não use sequência de dígitos (1234, 9876); isso é adivinhado em segundos.',
      PoliticaPin.comum =>
        'Esse PIN é um dos mais usados do mundo. Escolha outro.',
    };

/// PINs que qualquer lista de senhas tenta primeiro.
const _pinsComuns = <String>{
  '1234', '4321', '1212', '2121', '1122', '2211', '0000', '1111', '2222',
  '3333', '4444', '5555', '6666', '7777', '8888', '9999', '1010', '0101',
  '1230', '0852', '1379', '2468', '1357', '2580', '1590', '2000', '2020',
  '6969', '101112', '123123', '112233', '654321', '111222', '147258',
};

/// Regras mínimas de um PIN novo. Recusar aqui evita o "PIN de fábrica".
PoliticaPin avaliarPin(String pin) {
  final limpo = pin.trim();
  if (limpo.isEmpty) return PoliticaPin.curto;
  if (!RegExp(r'^\d+$').hasMatch(limpo)) return PoliticaPin.naoNumerico;
  if (limpo.length < tamanhoMinPin) return PoliticaPin.curto;
  if (limpo.length > tamanhoMaxPin) return PoliticaPin.longo;
  if (limpo.split('').toSet().length == 1) return PoliticaPin.repetido;

  var crescente = true;
  var decrescente = true;
  for (var i = 1; i < limpo.length; i++) {
    final anterior = int.parse(limpo[i - 1]);
    final atual = int.parse(limpo[i]);
    if (atual != anterior + 1) crescente = false;
    if (atual != anterior - 1) decrescente = false;
  }
  if (crescente || decrescente) return PoliticaPin.sequencia;
  if (_pinsComuns.contains(limpo)) return PoliticaPin.comum;
  return PoliticaPin.ok;
}

/// Deriva o PIN para [bytesHash] bytes com PBKDF2-HMAC-SHA256 (bloco único).
///
/// Nunca compare o PIN em texto: o que fica no aparelho é só este digest.
List<int> derivarPin(String pin, List<int> sal, {int iteracoes = iteracoesPadrao}) {
  if (iteracoes < 1) throw ArgumentError('iterações precisam ser positivas');
  final bloco = <int>[...sal, 0, 0, 0, 1];
  var u = Hmac(sha256, utf8.encode(pin)).convert(bloco).bytes;
  final saida = List<int>.from(u);
  for (var i = 1; i < iteracoes; i++) {
    u = Hmac(sha256, utf8.encode(pin)).convert(u).bytes;
    for (var j = 0; j < saida.length; j++) {
      saida[j] ^= u[j];
    }
  }
  return saida.sublist(0, min(bytesHash, saida.length));
}

/// Comparação em tempo constante: não vaza em qual byte a diferença apareceu.
bool compararDigest(List<int> a, List<int> b) {
  // Digests vazios nunca significam "igual": seria um desbloqueio sem prova.
  if (a.isEmpty || a.length != b.length) return false;
  var diferenca = 0;
  for (var i = 0; i < a.length; i++) {
    diferenca |= a[i] ^ b[i];
  }
  return diferenca == 0;
}

List<int> novoSalt(Random random) =>
    List<int>.generate(bytesSal, (_) => random.nextInt(256));

String hexDe(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

List<int>? bytesDeHex(String hex) {
  final limpo = hex.trim().toLowerCase();
  if (limpo.isEmpty || limpo.length.isOdd || !RegExp(r'^[0-9a-f]+$').hasMatch(limpo)) {
    return null;
  }
  final saida = <int>[];
  for (var i = 0; i < limpo.length; i += 2) {
    saida.add(int.parse(limpo.substring(i, i + 2), radix: 16));
  }
  return saida;
}

/// Configuração persistida da tela de bloqueio. Nunca carrega o PIN.
class ConfigBloqueio {
  const ConfigBloqueio({
    required this.ativo,
    required this.biometria,
    required this.espera,
    required this.tentativas,
    this.bloqueadoAte,
  });

  final bool ativo;
  final bool biometria;
  final Duration espera;
  final int tentativas;
  final DateTime? bloqueadoAte;

  static const desligado = ConfigBloqueio(
    ativo: false,
    biometria: false,
    espera: Duration.zero,
    tentativas: 0,
    bloqueadoAte: null,
  );

  factory ConfigBloqueio.fromMap(Map<Object?, Object?> mapa) {
    final esperaSegundos = mapa['esperaSegundos'];
    final bloqueado = mapa['bloqueadoAte'];
    final tentativas = mapa['tentativas'];
    return ConfigBloqueio(
      ativo: mapa['ativo'] == true,
      biometria: mapa['biometria'] == true,
      espera: Duration(
          seconds: esperaSegundos is num ? esperaSegundos.toInt().clamp(0, 3600) : 0),
      tentativas: tentativas is num ? tentativas.toInt().clamp(0, 99) : 0,
      bloqueadoAte: bloqueado is num && bloqueado > 0
          ? DateTime.fromMillisecondsSinceEpoch(bloqueado.toInt())
          : null,
    );
  }

  Map<String, Object?> toMap() => {
        'ativo': ativo,
        'biometria': biometria,
        'esperaSegundos': espera.inSeconds,
        'tentativas': tentativas,
        'bloqueadoAte': bloqueadoAte?.millisecondsSinceEpoch ?? 0,
      };

  ConfigBloqueio copiarCom({
    bool? ativo,
    bool? biometria,
    Duration? espera,
    int? tentativas,
    DateTime? bloqueadoAte,
    bool limparBloqueio = false,
  }) =>
      ConfigBloqueio(
        ativo: ativo ?? this.ativo,
        biometria: biometria ?? this.biometria,
        espera: espera ?? this.espera,
        tentativas: tentativas ?? this.tentativas,
        bloqueadoAte: limparBloqueio ? null : (bloqueadoAte ?? this.bloqueadoAte),
      );

  bool bloqueadoEm(DateTime agora) =>
      bloqueadoAte != null && agora.isBefore(bloqueadoAte!);

  Duration restanteDeEspera(DateTime agora) {
    if (bloqueadoAte == null) return Duration.zero;
    final restante = bloqueadoAte!.difference(agora);
    return restante.isNegative ? Duration.zero : restante;
  }

  int get restantes => (tentativasAntesDeEspera - tentativas).clamp(0, tentativasAntesDeEspera);
}

/// Resultado de uma tentativa de desbloqueio, com a configuração já atualizada.
class ResultadoTentativa {
  const ResultadoTentativa({
    required this.ok,
    required this.mensagem,
    required this.config,
    this.coacao = false,
  });

  final bool ok;
  final String mensagem;
  final ConfigBloqueio config;

  /// `true` quando quem casou foi o **PIN de coação**: a tela deve abrir o modo
  /// de visita, nunca o app real.
  final bool coacao;
}

/// Aplica uma tentativa: acerto zera falhas, erro conta e pode impor espera.
///
/// A espera existe para encarecer a adivinhação; ela nunca "libera" o PIN, só
/// atrasa a próxima tentativa.
ResultadoTentativa avaliarTentativa({
  required ConfigBloqueio config,
  required bool pinCorreto,
  required DateTime agora,
}) {
  if (config.bloqueadoEm(agora)) {
    final restante = config.restanteDeEspera(agora).inSeconds + 1;
    return ResultadoTentativa(
      ok: false,
      mensagem: 'Muitas tentativas. Aguarde $restante s.',
      config: config,
    );
  }
  if (pinCorreto) {
    return ResultadoTentativa(
      ok: true,
      mensagem: 'Desbloqueado.',
      config: config.copiarCom(tentativas: 0, limparBloqueio: true),
    );
  }
  final falhas = config.tentativas + 1;
  if (falhas >= tentativasAntesDeEspera) {
    return ResultadoTentativa(
      ok: false,
      mensagem:
          'PIN incorreto. Aguarde ${esperaPorTentativas.inSeconds} segundos antes de tentar de novo.',
      config: config.copiarCom(
        tentativas: 0,
        bloqueadoAte: agora.add(esperaPorTentativas),
      ),
    );
  }
  final restantes = tentativasAntesDeEspera - falhas;
  return ResultadoTentativa(
    ok: false,
    mensagem: 'PIN incorreto. ${restantes == 1 ? 'Resta 1 tentativa' : 'Restam $restantes tentativas'}.',
    config: config.copiarCom(tentativas: falhas),
  );
}

/// Quando o app volta do segundo plano, este cálculo decide se bloqueia.
bool deveBloquearAoVoltar({
  required ConfigBloqueio config,
  required DateTime? saiuEm,
  required DateTime agora,
}) {
  if (!config.ativo || saiuEm == null) return false;
  return agora.difference(saiuEm) >= config.espera;
}

/// Contrato de armazenamento usado pela tela de bloqueio e pelas configurações.
///
/// Existe para os testes usarem uma porta em memória sem tocar no cofre do
/// aparelho, e para a interface não depender de detalhes de persistência.
abstract interface class PortaBloqueio {
  Future<ConfigBloqueio> ler();
  Future<bool> temPin();
  Future<ResultadoTentativa> definirPin(String pin, {ConfigBloqueio? config});
  Future<ResultadoTentativa> conferir(String pin, {ConfigBloqueio? config});
  Future<ResultadoTentativa> alterarPin(String pinAtual, String pinNovo);
  Future<ResultadoTentativa> desligar(String pinAtual);
  Future<ResultadoTentativa> redefinirComCredencialDoAparelho(String pinNovo);
  Future<ConfigBloqueio> definirBiometria(bool ativo);
  Future<ConfigBloqueio> definirEspera(Duration espera);
  Future<ConfigBloqueio> registrarDesbloqueio();
}

/// Contrato do PIN de coação (modo de visita).
///
/// Fica separado de [PortaBloqueio] para o resto do app continuar sem conhecer
/// o recurso: quem tem a porta de coação é o `BloqueioStore`, e a tela de
/// segurança só mostra a seção quando a porta existe.
abstract interface class PortaCoacao {
  /// Se há um PIN de coação definido neste aparelho.
  Future<bool> temCoacao();

  /// Define o PIN de coação. Exige o PIN principal em [pinAtual].
  Future<ResultadoTentativa> definirCoacao(String pinAtual, String pinNovo);

  /// Remove o PIN de coação. Exige o PIN principal.
  Future<ResultadoTentativa> removerCoacao(String pinAtual);

  /// Quando o modo de visita foi aberto pela última vez (só para o dono ver).
  Future<DateTime?> coacaoUsadaEm();
}

/// Estado de disponibilidade da biometria informado pelo Android.
enum EstadoBiometria { indisponivel, semCadastro, pronto }

class BiometriaStatus {
  const BiometriaStatus({
    required this.estado,
    this.hardware = false,
    this.api = 0,
  });

  final EstadoBiometria estado;
  final bool hardware;
  final int api;

  static const indisponivel =
      BiometriaStatus(estado: EstadoBiometria.indisponivel);

  factory BiometriaStatus.fromMap(Map<Object?, Object?> mapa) {
    final texto = mapa['estado']?.toString() ?? '';
    final api = mapa['api'];
    return BiometriaStatus(
      estado: switch (texto) {
        'pronto' => EstadoBiometria.pronto,
        'sem_cadastro' => EstadoBiometria.semCadastro,
        _ => EstadoBiometria.indisponivel,
      },
      hardware: mapa['hardware'] == true,
      api: api is num ? api.toInt() : 0,
    );
  }

  bool get podeUsar => estado == EstadoBiometria.pronto;

  String get descricao => switch (estado) {
        EstadoBiometria.pronto => 'Biometria disponível neste aparelho.',
        EstadoBiometria.semCadastro =>
          'O aparelho tem leitor biométrico, mas nenhuma digital ou rosto cadastrado.',
        EstadoBiometria.indisponivel =>
          'Este aparelho não ofereceu biometria ao app. O PIN continua valendo.',
      };
}
