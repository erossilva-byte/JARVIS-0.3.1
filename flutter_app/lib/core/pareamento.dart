/// Pareamento entre celular e PC na rede local — regras puras, sem Flutter.
///
/// O celular abre uma oferta: código de 6 dígitos, um desafio aleatório e prazo
/// de 2 minutos. O PC lê o desafio em `GET /jarvis/info`, prova que sabe o
/// código com `HMAC-SHA256(codigo, desafio)` e recebe um token de leitura. O
/// código nunca autentica duas vezes e não vai para o disco de nenhum dos dois.
///
/// O que este arquivo **não** faz: TLS, descoberta automática (mDNS) e envio de
/// comandos. A escolha desta etapa é lista manual de IP e canal só de leitura —
/// a descoberta automática e o controle remoto ficam para a Etapa 6.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Porta fixa do canal do celular. O PC aceita `ip` ou `ip:porta`.
const portaPareamento = 47600;

/// Validade da oferta. Curta de propósito: o código existe para ser digitado
/// agora, não para ficar aberto a tarde inteira.
const validadeOfertaSegundos = 120;

/// Tentativas erradas antes de a oferta ser queimada.
const tentativasPareamento = 5;

/// Seis dígitos, com zero à esquerda quando precise.
String gerarCodigoPareamento(Random aleatorio) {
  final numero = aleatorio.nextInt(1000000);
  return numero.toString().padLeft(6, '0');
}

/// Só os dígitos: “123 456”, “123-456” e “123456” valem o mesmo.
String normalizarCodigoPareamento(String bruto) =>
    bruto.replaceAll(RegExp(r'\D'), '');

/// Código completo, ou string vazia quando não tem exatamente 6 dígitos.
String codigoUtilizavel(String bruto) {
  final limpo = normalizarCodigoPareamento(bruto);
  return limpo.length == 6 ? limpo : '';
}

/// “123456” → “123 456”, para ler em voz alta e conferir na tela.
String formatarCodigoPareamento(String codigo) {
  final limpo = normalizarCodigoPareamento(codigo);
  return limpo.length == 6 ? '${limpo.substring(0, 3)} ${limpo.substring(3)}' : limpo;
}

/// Prova de conhecimento do código, sem mandá-lo pela rede.
String provaDePareamento(String codigo, String desafio) {
  final chave = utf8.encode(normalizarCodigoPareamento(codigo));
  final mensagem = utf8.encode(desafio);
  return Hmac(sha256, chave).convert(mensagem).toString();
}

/// Token de leitura: 32 bytes aleatórios em hexadecimal.
String tokenDePareamento(Random aleatorio) {
  final bytes = List<int>.generate(32, (_) => aleatorio.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Compara duas strings sem sair no primeiro caractere diferente.
bool iguaisEmTempoConstante(String a, String b) {
  if (a.length != b.length) return false;
  var diferenca = 0;
  for (var i = 0; i < a.length; i++) {
    diferenca |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diferenca == 0;
}

/// Oferta em aberto no celular.
class OfertaPareamento {
  OfertaPareamento({
    required this.codigo,
    required this.desafio,
    required this.criadoEm,
    this.tentativasRestantes = tentativasPareamento,
  });

  final String codigo;
  final String desafio;
  final DateTime criadoEm;
  int tentativasRestantes;

  DateTime get expiraEm =>
      criadoEm.add(const Duration(seconds: validadeOfertaSegundos));

  bool expirou([DateTime? agora]) =>
      !(agora ?? DateTime.now()).isBefore(expiraEm);

  /// Vale no instante informado (o serviço passa o relógio injetado).
  bool valeEm([DateTime? agora]) =>
      tentativasRestantes > 0 && !expirou(agora);

  bool get vale => valeEm();

  /// Segundos até expirar, nunca negativos.
  int segundosRestantes([DateTime? agora]) {
    final resta = expiraEm.difference(agora ?? DateTime.now()).inSeconds;
    return resta < 0 ? 0 : resta;
  }

  /// Confere a prova do PC. Cada erro gasta uma tentativa; a oferta morre
  /// quando as tentativas acabam, para não permitir força bruta de 6 dígitos.
  bool conferirProva(String prova, {DateTime? agora}) {
    if (!valeEm(agora)) return false;
    final esperada = provaDePareamento(codigo, desafio);
    if (iguaisEmTempoConstante(esperada, prova.trim().toLowerCase())) {
      tentativasRestantes = 0;
      return true;
    }
    tentativasRestantes -= 1;
    return false;
  }
}

/// PC autorizado a ler o status deste celular.
class RegistroPareamento {
  RegistroPareamento({
    required this.dispositivo,
    required this.ip,
    required this.porta,
    required this.token,
    required this.criadoEm,
  });

  final String dispositivo;
  final String ip;
  final int porta;
  final String token;
  final DateTime criadoEm;

  String get endereco => porta == 80 ? ip : '$ip:$porta';

  Map<String, Object?> paraMapa() => {
        'dispositivo': dispositivo,
        'ip': ip,
        'porta': porta,
        'token': token,
        'criadoEm': criadoEm.toIso8601String(),
      };

  /// Leitura tolerante: campo estranho vira nulo em vez de derrubar o registro.
  static RegistroPareamento? deMapa(Object? dados) {
    if (dados is! Map) return null;
    final dispositivo = (dados['dispositivo'] ?? '').toString().trim();
    final ip = (dados['ip'] ?? '').toString().trim();
    final token = (dados['token'] ?? '').toString().trim();
    final porta = dados['porta'];
    final criadoEm = DateTime.tryParse((dados['criadoEm'] ?? '').toString());
    if (dispositivo.isEmpty || ip.isEmpty || token.isEmpty) return null;
    if (porta is! num || porta <= 0 || porta > 65535) return null;
    return RegistroPareamento(
      dispositivo: dispositivo,
      ip: ip,
      porta: porta.toInt(),
      token: token,
      criadoEm: criadoEm ?? DateTime.now(),
    );
  }
}

/// O endereço está na rede local (ou no próprio aparelho)?
///
/// Fora daqui o canal não abre: pareamento é coisa de LAN, não de internet.
bool enderecoDaRedeLocal(String host) {
  final h = host.trim().toLowerCase().replaceAll('[', '').replaceAll(']', '');
  if (h.isEmpty) return false;
  if (h == 'localhost' || h == '::1') return true;

  final ipv4 = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$').firstMatch(h);
  if (ipv4 != null) {
    final partes = [1, 2, 3, 4]
        .map((i) => int.tryParse(ipv4.group(i)!) ?? 999)
        .toList();
    if (partes.any((p) => p > 255)) return false;
    if (partes[0] == 127) return true;
    if (partes[0] == 10) return true;
    if (partes[0] == 192 && partes[1] == 168) return true;
    if (partes[0] == 172 && partes[1] >= 16 && partes[1] <= 31) return true;
    if (partes[0] == 169 && partes[1] == 254) return true;
    return false;
  }

  // IPv6: loopback, link-local (fe80::) e unique-local (fc00::/7).
  if (h.contains(':')) {
    return h.startsWith('fe8') ||
        h.startsWith('fe9') ||
        h.startsWith('fea') ||
        h.startsWith('feb') ||
        h.startsWith('fc') ||
        h.startsWith('fd');
  }
  return false;
}

/// Extrai host e porta de “192.168.0.10”, “192.168.0.10:47600” ou
/// “[fe80::1]:47600”. Porta ausente usa a padrão do canal.
({String host, int porta})? enderecoDoCelular(String bruto,
    {int portaPadrao = portaPareamento}) {
  var texto = bruto.trim();
  if (texto.isEmpty) return null;
  texto = texto.replaceFirst(RegExp(r'^https?://'), '');
  texto = texto.replaceAll(RegExp(r'/+$'), '');
  var host = texto;
  var porta = portaPadrao;
  final ipv6 = RegExp(r'^\[([^\]]+)\](?::(\d+))?$').firstMatch(texto);
  if (ipv6 != null) {
    host = ipv6.group(1)!;
    final p = int.tryParse(ipv6.group(2) ?? '');
    if (p != null) porta = p;
  } else if (RegExp(r'^[^:]+:\d+$').hasMatch(texto)) {
    final partes = texto.split(':');
    host = partes.first;
    porta = int.tryParse(partes.last) ?? porta;
  }
  if (porta <= 0 || porta > 65535) return null;
  if (!enderecoDaRedeLocal(host)) return null;
  return (host: host, porta: porta);
}
