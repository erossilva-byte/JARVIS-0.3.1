import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../core/pareamento.dart';

/// Canal de pareamento do celular: um servidor HTTP só na rede local.
///
/// Rotas (todas recusam endereço fora da LAN):
/// - `GET  /jarvis/info`     — nome, versão e o desafio da oferta aberta;
/// - `POST /jarvis/parear`   — `{dispositivo, prova}`; devolve o token uma vez;
/// - `GET  /jarvis/status`   — exige `Authorization: Bearer <token>`; só leitura;
/// - `POST /jarvis/esquecer` — exige o token; revoga o acesso do PC.
///
/// Não há rota de comando nesta etapa, e nenhuma conexão sai do aparelho: o
/// servidor só responde a quem chega da própria rede local.
class PareamentoService {
  PareamentoService({
    this.porta = portaPareamento,
    this.nome = 'JARVIS no celular',
    this.versao = '',
    this.status,
    this.relogio,
    this.aleatorio,
  });

  /// Porta pedida; 0 deixa o sistema escolher (usado nos testes).
  final int porta;
  final String nome;
  final String versao;

  /// Leitura do status do aparelho, injetada pela tela.
  final Future<Map<String, Object?>> Function()? status;

  /// Injetáveis para teste: relógio e fonte de aleatoriedade.
  final DateTime Function()? relogio;
  final Random? aleatorio;

  HttpServer? _servidor;
  OfertaPareamento? oferta;
  RegistroPareamento? registro;

  /// Chamado quando o PC pareia ou é esquecido.
  void Function()? aoMudar;

  bool get aberto => _servidor != null;
  bool get pareado => registro != null;
  int get portaAtual => _servidor?.port ?? 0;

  DateTime _agora() => (relogio ?? DateTime.now)();
  Random _sorteio() => aleatorio ?? Random.secure();

  /// Sobe o servidor, se ainda não estiver de pé, e devolve o endereço real.
  Future<int> iniciar() async {
    final atual = _servidor;
    if (atual != null) return atual.port;
    final servidor =
        await HttpServer.bind(InternetAddress.anyIPv4, porta, shared: false);
    _servidor = servidor;
    servidor.listen(_atender, onError: (_) {});
    return servidor.port;
  }

  /// Abre uma oferta nova: código de 6 dígitos, desafio e prazo.
  Future<OfertaPareamento> abrirOferta() async {
    await iniciar();
    final sorteio = _sorteio();
    final desafio =
        List<int>.generate(16, (_) => sorteio.nextInt(256))
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
    final nova = OfertaPareamento(
      codigo: gerarCodigoPareamento(sorteio),
      desafio: desafio,
      criadoEm: _agora(),
    );
    oferta = nova;
    aoMudar?.call();
    return nova;
  }

  /// Esquece o PC: token deixa de valer na hora.
  void esquecer() {
    registro = null;
    aoMudar?.call();
  }

  Future<void> fechar() async {
    final servidor = _servidor;
    _servidor = null;
    oferta = null;
    await servidor?.close(force: true);
  }

  /// Endereços IPv4 da rede local, para digitar no PC.
  static Future<List<String>> enderecosLocais() async {
    try {
      final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false);
      final lista = <String>[];
      for (final interface in interfaces) {
        for (final endereco in interface.addresses) {
          if (enderecoDaRedeLocal(endereco.address) &&
              !lista.contains(endereco.address)) {
            lista.add(endereco.address);
          }
        }
      }
      return lista;
    } on OSError {
      return const [];
    }
  }

  Future<void> _atender(HttpRequest pedido) async {
    final remoto = pedido.connectionInfo?.remoteAddress.address ?? '';
    // Fora da LAN (ou sem informação de origem), nada é respondido.
    if (!enderecoDaRedeLocal(remoto)) {
      await _responder(pedido, 403, {'erro': 'fora da rede local'});
      return;
    }
    final caminho = pedido.uri.path.replaceAll(RegExp(r'/+$'), '');
    try {
      if (pedido.method == 'GET' && caminho == '/jarvis/info') {
        await _info(pedido);
      } else if (pedido.method == 'POST' && caminho == '/jarvis/parear') {
        await _parear(pedido, remoto);
      } else if (pedido.method == 'GET' && caminho == '/jarvis/status') {
        await _status(pedido);
      } else if (pedido.method == 'POST' && caminho == '/jarvis/esquecer') {
        await _esquecer(pedido);
      } else {
        await _responder(pedido, 404, {'erro': 'rota desconhecida'});
      }
    } catch (_) {
      await _responder(pedido, 500, {'erro': 'falha ao atender o pedido'});
    }
  }

  Future<void> _info(HttpRequest pedido) async {
    final aberta = oferta;
    if (aberta == null || !aberta.valeEm(_agora())) {
      await _responder(pedido, 409, {
        'erro': 'sem oferta de pareamento aberta',
        'precisaOferta': true,
      });
      return;
    }
    await _responder(pedido, 200, {
      'nome': nome,
      'versao': versao,
      'desafio': aberta.desafio,
      'expiraEmSegundos': aberta.segundosRestantes(_agora()),
      'tentativas': aberta.tentativasRestantes,
    });
  }

  Future<void> _parear(HttpRequest pedido, String remoto) async {
    final aberta = oferta;
    if (aberta == null) {
      await _responder(pedido, 409, {
        'erro': 'sem oferta de pareamento aberta',
        'precisaOferta': true,
      });
      return;
    }
    if (aberta.expirou(_agora())) {
      oferta = null;
      await _responder(pedido, 410, {'erro': 'a oferta expirou'});
      return;
    }
    final corpo = await _corpo(pedido);
    final dispositivo = (corpo['dispositivo'] ?? '').toString().trim();
    final prova = (corpo['prova'] ?? '').toString().trim();
    if (dispositivo.isEmpty || prova.isEmpty) {
      await _responder(pedido, 400, {'erro': 'faltou dispositivo ou prova'});
      return;
    }
    if (!aberta.conferirProva(prova, agora: _agora())) {
      final restam = aberta.tentativasRestantes;
      if (restam <= 0) oferta = null;
      await _responder(pedido, 403, {
        'erro': 'código incorreto',
        'tentativasRestantes': restam < 0 ? 0 : restam,
      });
      return;
    }
    final token = tokenDePareamento(_sorteio());
    registro = RegistroPareamento(
      dispositivo: dispositivo.length > 80
          ? dispositivo.substring(0, 80)
          : dispositivo,
      ip: remoto,
      porta: pedido.connectionInfo?.remotePort ?? 0,
      token: token,
      criadoEm: _agora(),
    );
    oferta = null;
    aoMudar?.call();
    await _responder(pedido, 200, {
      'token': token,
      'dispositivo': registro!.dispositivo,
      'nome': nome,
      'versao': versao,
    });
  }

  Future<void> _status(HttpRequest pedido) async {
    if (!_autorizado(pedido)) {
      await _responder(pedido, 401, {'erro': 'token inválido ou ausente'});
      return;
    }
    final dados = status == null ? const <String, Object?>{} : await status!();
    await _responder(pedido, 200, {
      'nome': nome,
      'versao': versao,
      'atualizadoEm': _agora().toIso8601String(),
      'status': dados,
    });
  }

  Future<void> _esquecer(HttpRequest pedido) async {
    if (!_autorizado(pedido)) {
      await _responder(pedido, 401, {'erro': 'token inválido ou ausente'});
      return;
    }
    esquecer();
    await _responder(pedido, 200, {'esquecido': true});
  }

  bool _autorizado(HttpRequest pedido) {
    final atual = registro;
    if (atual == null) return false;
    final cabecalho = pedido.headers.value(HttpHeaders.authorizationHeader) ?? '';
    if (!cabecalho.toLowerCase().startsWith('bearer ')) return false;
    final token = cabecalho.substring(7).trim();
    return iguaisEmTempoConstante(atual.token, token);
  }

  Future<Map<String, Object?>> _corpo(HttpRequest pedido) async {
    final texto = await utf8.decoder.bind(pedido).join();
    if (texto.isEmpty) return const {};
    if (texto.length > 4096) return const {};
    final lido = jsonDecode(texto);
    return lido is Map ? Map<String, Object?>.from(lido) : const {};
  }

  Future<void> _responder(
      HttpRequest pedido, int codigo, Map<String, Object?> corpo) async {
    pedido.response.statusCode = codigo;
    pedido.response.headers.contentType = ContentType.json;
    pedido.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    pedido.response.write(jsonEncode(corpo));
    await pedido.response.close();
  }
}
