import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/seguranca.dart';

/// Cofre onde ficam sal e digest do PIN. Nunca guarda o PIN digitado.
abstract interface class CofreBloqueio {
  Future<String?> read(String chave);
  Future<void> write(String chave, String valor);
  Future<void> delete(String chave);
}

/// Cofre do aparelho (`flutter_secure_storage`), com prefixo próprio.
class CofreSeguro implements CofreBloqueio {
  CofreSeguro({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const prefixo = 'jarvis.seguranca.';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String chave) => _storage.read(key: '$prefixo$chave');

  @override
  Future<void> write(String chave, String valor) =>
      _storage.write(key: '$prefixo$chave', value: valor);

  @override
  Future<void> delete(String chave) => _storage.delete(key: '$prefixo$chave');
}

/// Configuração e verificação do PIN do JARVIS.
///
/// A configuração (ligado, biometria, espera, tentativas) fica em
/// `SharedPreferences`; o sal e o digest ficam no cofre seguro. Nenhum dos dois
/// guarda o PIN. A verificação é sempre por derivação e comparação em tempo
/// constante.
class BloqueioStore implements PortaBloqueio, PortaCoacao {
  BloqueioStore({
    CofreBloqueio? cofre,
    Future<SharedPreferences> Function()? abrirPreferencias,
    DateTime Function()? agora,
    Random? random,
  })  : _cofre = cofre ?? CofreSeguro(),
        _abrirPreferencias =
            abrirPreferencias ?? SharedPreferences.getInstance,
        _agora = agora ?? DateTime.now,
        _random = random ?? Random.secure();

  static const chaveConfig = 'jarvis.bloqueio.v1';
  static const _chaveSal = 'sal';
  static const _chaveDigest = 'digest';
  static const _chaveIteracoes = 'iteracoes';

  // PIN de coação (modo de visita): sal e digest próprios, nunca o PIN em texto.
  static const _chaveCoacaoSal = 'coacao.sal';
  static const _chaveCoacaoDigest = 'coacao.digest';
  static const _chaveCoacaoIteracoes = 'coacao.iteracoes';
  static const _chaveUsoCoacao = 'jarvis.coacao.v1';

  final CofreBloqueio _cofre;
  final Future<SharedPreferences> Function() _abrirPreferencias;
  final DateTime Function() _agora;
  final Random _random;

  @override
  Future<ConfigBloqueio> ler() async {
    final prefs = await _abrirPreferencias();
    final bruto = prefs.getString(chaveConfig);
    if (bruto == null || bruto.trim().isEmpty) {
      // Um digest órfão sem configuração não pode "ligar" o bloqueio sozinho.
      return ConfigBloqueio.desligado;
    }
    try {
      final dados = jsonDecode(bruto);
      if (dados is! Map) return ConfigBloqueio.desligado;
      final config = ConfigBloqueio.fromMap(dados);
      return config.ativo && !await temPin()
          ? config.copiarCom(ativo: false, biometria: false)
          : config;
    } catch (_) {
      return ConfigBloqueio.desligado;
    }
  }

  Future<void> _gravar(ConfigBloqueio config) async {
    final prefs = await _abrirPreferencias();
    await prefs.setString(chaveConfig, jsonEncode(config.toMap()));
  }

  @override
  Future<bool> temPin() async {
    final digest = await _cofre.read(_chaveDigest);
    final sal = await _cofre.read(_chaveSal);
    return digest != null &&
        digest.isNotEmpty &&
        sal != null &&
        sal.isNotEmpty;
  }

  Future<int> _iteracoes() async {
    final bruto = await _cofre.read(_chaveIteracoes);
    final lidas = int.tryParse(bruto ?? '');
    return lidas == null || lidas < 1000 ? iteracoesPadrao : lidas;
  }

  /// Grava um PIN novo. Recusa fora da política e nunca sobrescreve em silêncio.
  @override
  Future<ResultadoTentativa> definirPin(
    String pin, {
    ConfigBloqueio? config,
  }) async {
    final politica = avaliarPin(pin);
    final atual = config ?? await ler();
    if (politica != PoliticaPin.ok) {
      return ResultadoTentativa(
        ok: false,
        mensagem: mensagemPolitica(politica),
        config: atual,
      );
    }
    final sal = novoSalt(_random);
    final digest = derivarPin(pin.trim(), sal);
    try {
      await _cofre.write(_chaveSal, hexDe(sal));
      await _cofre.write(_chaveDigest, hexDe(digest));
      await _cofre.write(_chaveIteracoes, '$iteracoesPadrao');
    } catch (_) {
      return ResultadoTentativa(
        ok: false,
        mensagem:
            'O cofre seguro do aparelho não aceitou gravar o PIN. Nada foi ativado.',
        config: atual,
      );
    }
    final nova = atual.copiarCom(
      ativo: true,
      tentativas: 0,
      limparBloqueio: true,
    );
    await _gravar(nova);
    return ResultadoTentativa(
      ok: true,
      mensagem: 'PIN definido e bloqueio ativado.',
      config: nova,
    );
  }

  /// Verifica o PIN aplicando as regras de tentativas e espera.
  @override
  Future<ResultadoTentativa> conferir(
    String pin, {
    ConfigBloqueio? config,
  }) async {
    final atual = config ?? await ler();
    if (atual.bloqueadoEm(_agora())) {
      return avaliarTentativa(config: atual, pinCorreto: false, agora: _agora());
    }
    final sal = bytesDeHex(await _cofre.read(_chaveSal) ?? '');
    final esperado = bytesDeHex(await _cofre.read(_chaveDigest) ?? '');
    if (sal == null || esperado == null) {
      return ResultadoTentativa(
        ok: false,
        mensagem: 'Nenhum PIN está definido neste aparelho.',
        config: atual,
      );
    }
    final calculado = derivarPin(pin.trim(), sal, iteracoes: await _iteracoes());
    final principal = compararDigest(calculado, esperado);
    // O PIN de coação é conferido sempre, mesmo quando o principal já casou:
    // assim o tempo de resposta não denuncia qual dos dois foi digitado.
    final coacaoSal = bytesDeHex(await _cofre.read(_chaveCoacaoSal) ?? '');
    final coacaoDigest = bytesDeHex(await _cofre.read(_chaveCoacaoDigest) ?? '');
    var coacao = false;
    if (coacaoSal != null && coacaoDigest != null) {
      final coacaoCalculado = derivarPin(pin.trim(), coacaoSal,
          iteracoes: await _iteracoesCoacao());
      coacao = compararDigest(coacaoCalculado, coacaoDigest);
    }
    final resultado = avaliarTentativa(
      config: atual,
      pinCorreto: principal || coacao,
      agora: _agora(),
    );
    await _gravar(resultado.config);
    if (resultado.ok && !principal && coacao) {
      await _registrarUsoCoacao();
      return ResultadoTentativa(
        ok: true,
        mensagem: 'Aberto no modo de visita.',
        config: resultado.config,
        coacao: true,
      );
    }
    return resultado;
  }

  /// Troca o PIN depois de conferir o atual.
  @override
  Future<ResultadoTentativa> alterarPin(String pinAtual, String pinNovo) async {
    final conferido = await conferir(pinAtual);
    if (!conferido.ok) return conferido;
    return definirPin(pinNovo, config: conferido.config);
  }

  /// Desliga o bloqueio; exige o PIN atual para não ser um botão de escape.
  @override
  Future<ResultadoTentativa> desligar(String pinAtual) async {
    final conferido = await conferir(pinAtual);
    if (!conferido.ok) return conferido;
    await _cofre.delete(_chaveSal);
    await _cofre.delete(_chaveDigest);
    await _cofre.delete(_chaveIteracoes);
    // Sem bloqueio não faz sentido guardar um PIN de coação solto.
    await _cofre.delete(_chaveCoacaoSal);
    await _cofre.delete(_chaveCoacaoDigest);
    await _cofre.delete(_chaveCoacaoIteracoes);
    final nova = conferido.config.copiarCom(
      ativo: false,
      biometria: false,
      tentativas: 0,
      limparBloqueio: true,
    );
    await _gravar(nova);
    return ResultadoTentativa(
      ok: true,
      mensagem: 'Bloqueio desligado. O PIN foi apagado do aparelho.',
      config: nova,
    );
  }

  /// Redefine o PIN depois de o Android confirmar a credencial do aparelho.
  ///
  /// Só deve ser chamado quando a credencial do sistema foi aceita: é a
  /// recuperação para quem esqueceu o PIN do JARVIS.
  @override
  Future<ResultadoTentativa> redefinirComCredencialDoAparelho(
      String pinNovo) async {
    final atual = (await ler()).copiarCom(tentativas: 0, limparBloqueio: true);
    return definirPin(pinNovo, config: atual);
  }

  @override
  Future<ConfigBloqueio> definirBiometria(bool ativo) async {
    final atual = await ler();
    if (ativo && !atual.ativo) return atual;
    final nova = atual.copiarCom(biometria: ativo);
    await _gravar(nova);
    return nova;
  }

  @override
  Future<ConfigBloqueio> definirEspera(Duration espera) async {
    final atual = await ler();
    final segura = esperasBloqueio.contains(espera) ? espera : Duration.zero;
    final nova = atual.copiarCom(espera: segura);
    await _gravar(nova);
    return nova;
  }

  /// Zera a contagem de falhas depois de um desbloqueio confirmado.
  @override
  Future<ConfigBloqueio> registrarDesbloqueio() async {
    final atual = await ler();
    final nova = atual.copiarCom(tentativas: 0, limparBloqueio: true);
    await _gravar(nova);
    return nova;
  }

  Future<ConfigBloqueio> limparEspera() => registrarDesbloqueio();

  // ---- PIN de coação (modo de visita) -------------------------------------

  Future<int> _iteracoesCoacao() async {
    final bruto = await _cofre.read(_chaveCoacaoIteracoes);
    final lidas = int.tryParse(bruto ?? '');
    return lidas == null || lidas < 1000 ? iteracoesPadrao : lidas;
  }

  Future<void> _registrarUsoCoacao() async {
    try {
      final prefs = await _abrirPreferencias();
      await prefs.setInt(_chaveUsoCoacao, _agora().millisecondsSinceEpoch);
    } catch (_) {
      // Sem o registro o modo de visita continua funcionando; só não fica a data.
    }
  }

  @override
  Future<bool> temCoacao() async =>
      bytesDeHex(await _cofre.read(_chaveCoacaoSal) ?? '') != null &&
      bytesDeHex(await _cofre.read(_chaveCoacaoDigest) ?? '') != null;

  @override
  Future<DateTime?> coacaoUsadaEm() async {
    final prefs = await _abrirPreferencias();
    final bruto = prefs.getInt(_chaveUsoCoacao);
    if (bruto == null || bruto <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(bruto);
  }

  /// Define o PIN de coação depois de conferir o principal.
  ///
  /// Regras: o PIN de coação passa pela mesma política do principal, não pode
  /// ser igual a ele e exige o bloqueio ativo — sem PIN principal não existe
  /// "modo de visita", só um app aberto.
  @override
  Future<ResultadoTentativa> definirCoacao(String pinAtual, String pinNovo) async {
    final atual = await ler();
    if (!atual.ativo) {
      return ResultadoTentativa(
        ok: false,
        mensagem: 'Defina o PIN principal e ative o bloqueio antes do modo de visita.',
        config: atual,
      );
    }
    final conferido = await conferir(pinAtual, config: atual);
    if (!conferido.ok || conferido.coacao) {
      return ResultadoTentativa(
        ok: false,
        mensagem: conferido.coacao
            ? 'Digite o PIN principal, não o PIN de coação.'
            : conferido.mensagem,
        config: conferido.config,
      );
    }
    final politica = avaliarPin(pinNovo);
    if (politica != PoliticaPin.ok) {
      return ResultadoTentativa(
        ok: false,
        mensagem: mensagemPolitica(politica),
        config: conferido.config,
      );
    }
    final salPrincipal = bytesDeHex(await _cofre.read(_chaveSal) ?? '');
    final digestPrincipal = bytesDeHex(await _cofre.read(_chaveDigest) ?? '');
    if (salPrincipal != null && digestPrincipal != null) {
      final comoPrincipal = derivarPin(pinNovo.trim(), salPrincipal,
          iteracoes: await _iteracoes());
      if (compararDigest(comoPrincipal, digestPrincipal)) {
        return ResultadoTentativa(
          ok: false,
          mensagem: 'O PIN de coação precisa ser diferente do PIN principal.',
          config: conferido.config,
        );
      }
    }
    final sal = novoSalt(_random);
    final digest = derivarPin(pinNovo.trim(), sal);
    try {
      await _cofre.write(_chaveCoacaoSal, hexDe(sal));
      await _cofre.write(_chaveCoacaoDigest, hexDe(digest));
      await _cofre.write(_chaveCoacaoIteracoes, '$iteracoesPadrao');
    } catch (_) {
      return ResultadoTentativa(
        ok: false,
        mensagem:
            'O cofre seguro do aparelho não aceitou gravar o PIN de coação. Nada foi alterado.',
        config: conferido.config,
      );
    }
    return ResultadoTentativa(
      ok: true,
      mensagem:
          'Modo de visita definido. Digitando esse PIN, o JARVIS abre sem os seus dados.',
      config: conferido.config,
    );
  }

  @override
  Future<ResultadoTentativa> removerCoacao(String pinAtual) async {
    final conferido = await conferir(pinAtual);
    if (!conferido.ok || conferido.coacao) {
      return ResultadoTentativa(
        ok: false,
        mensagem: conferido.coacao
            ? 'Digite o PIN principal, não o PIN de coação.'
            : conferido.mensagem,
        config: conferido.config,
      );
    }
    await _cofre.delete(_chaveCoacaoSal);
    await _cofre.delete(_chaveCoacaoDigest);
    await _cofre.delete(_chaveCoacaoIteracoes);
    return ResultadoTentativa(
      ok: true,
      mensagem: 'PIN de coação removido. O modo de visita não abre mais.',
      config: conferido.config,
    );
  }
}
