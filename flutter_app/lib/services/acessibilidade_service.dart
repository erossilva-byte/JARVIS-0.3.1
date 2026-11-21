import 'package:flutter/services.dart';

import '../core/acessibilidade.dart';
import 'acessibilidade_store.dart';

/// Estado da automação: o que o Android autorizou e o que o app consentiu.
class EstadoAcessibilidade {
  const EstadoAcessibilidade({
    required this.servicoLigado,
    required this.consentimento,
    this.pacote = '',
  });

  final bool servicoLigado;
  final bool consentimento;
  final String pacote;

  /// Só age com as duas autorizações: serviço do Android e interruptor do app.
  bool get pronto => servicoLigado && consentimento;

  static EstadoAcessibilidade deMapa(
    Map<Object?, Object?>? mapa, {
    required bool consentimento,
  }) {
    return EstadoAcessibilidade(
      servicoLigado: mapa?['ligado'] == true,
      consentimento: consentimento,
      pacote: (mapa?['pacote'] as String?) ?? '',
    );
  }
}

class ResultadoTela {
  const ResultadoTela({
    required this.ok,
    required this.mensagem,
    this.acao = '',
    this.pacote = '',
    this.elementos = const [],
  });

  final bool ok;
  final String mensagem;
  final String acao;
  final String pacote;
  final List<ElementoDeTela> elementos;
}

typedef ChamadaAcessibilidade = Future<Map<Object?, Object?>?> Function(
    String metodo, Map<String, Object?> argumentos);

class AcessibilidadeService {
  AcessibilidadeService({
    ChamadaAcessibilidade? chamada,
    ConsentimentoAcessibilidade? consentimento,
    this.ativo = true,
  })  : _chamada = chamada ?? _canalPadrao,
        _consentimento = consentimento ?? PreferencesAcessibilidade();

  static const canal = MethodChannel('com.jarvis.nova/acessibilidade');

  /// Falso em teste de widget ou em plataforma sem a ponte Android.
  final bool ativo;
  final ChamadaAcessibilidade _chamada;
  final ConsentimentoAcessibilidade _consentimento;

  static Future<Map<Object?, Object?>?> _canalPadrao(
      String metodo, Map<String, Object?> argumentos) {
    return canal.invokeMapMethod<Object?, Object?>(metodo, argumentos);
  }

  static const desligadoPeloApp =
      'A automação de tela está desligada neste app. Ligue “Ler a tela e tocar '
      'por mim” e autorize o serviço em Configurações ▸ Acessibilidade.';

  Future<bool> consentido() => _consentimento.ativo();

  Future<void> definirConsentimento(bool valor) => _consentimento.definir(valor);

  Future<EstadoAcessibilidade> status() async {
    final consentimento = await _consentimento.ativo();
    if (!ativo) {
      return EstadoAcessibilidade(
          servicoLigado: false, consentimento: consentimento);
    }
    try {
      final resposta = await _chamada('status', const {});
      return EstadoAcessibilidade.deMapa(resposta,
          consentimento: consentimento);
    } on MissingPluginException {
      return EstadoAcessibilidade(
          servicoLigado: false, consentimento: consentimento);
    } on PlatformException {
      return EstadoAcessibilidade(
          servicoLigado: false, consentimento: consentimento);
    } catch (_) {
      return EstadoAcessibilidade(
          servicoLigado: false, consentimento: consentimento);
    }
  }

  /// Abre as configurações de acessibilidade do Android. Não liga nada sozinho.
  Future<void> abrirConfiguracoes() async {
    if (!ativo) return;
    try {
      await _chamada('abrirConfiguracoes', const {});
    } catch (_) {
      // Sem a ponte Android não há o que abrir; a tela explica o caminho.
    }
  }

  Future<ResultadoTela> executar(ComandoDeTela comando) async {
    if (!await _consentimento.ativo()) {
      return ResultadoTela(
          ok: false, mensagem: desligadoPeloApp, acao: comando.resumo);
    }
    if (!ativo) {
      return ResultadoTela(
          ok: false,
          mensagem: 'A automação de tela só funciona no app Android instalado.',
          acao: comando.resumo);
    }
    try {
      final resposta = switch (comando) {
        LerTela() => await _chamada('ler', const {}),
        TocarNaTela(:final alvo) =>
          await _chamada('tocar', {'texto': alvo, 'ocorrencia': 0}),
        RolarTela(:final paraCima) =>
          await _chamada('rolar', {'paraCima': paraCima}),
        PararAutomacao() => await _chamada('parar', const {}),
      };
      return _resultado(comando, resposta);
    } on MissingPluginException {
      return ResultadoTela(
          ok: false,
          acao: comando.resumo,
          mensagem: 'Este aparelho não tem a ponte nativa de automação de tela.');
    } on PlatformException catch (erro) {
      return ResultadoTela(
          ok: false,
          acao: comando.resumo,
          mensagem: erro.message?.trim().isNotEmpty == true
              ? erro.message!
              : 'O Android recusou a ação de tela.');
    } catch (_) {
      return ResultadoTela(
          ok: false,
          acao: comando.resumo,
          mensagem: 'Não foi possível concluir a ação de tela.');
    }
  }

  ResultadoTela _resultado(
      ComandoDeTela comando, Map<Object?, Object?>? resposta) {
    if (resposta == null) {
      return ResultadoTela(
          ok: false,
          acao: comando.resumo,
          mensagem: 'O Android não devolveu o resultado da ação de tela.');
    }
    final pacote = (resposta['pacote'] as String?) ?? '';
    final ok = resposta['ok'] == true;
    if (comando is LerTela) {
      final lista = <ElementoDeTela>[];
      final nos = resposta['nos'];
      if (nos is List) {
        for (final item in nos) {
          if (item is Map) {
            final elemento = ElementoDeTela.deMapa(item);
            if (elemento != null) lista.add(elemento);
          }
        }
      }
      final limitado = resposta['limitado'] == true;
      return ResultadoTela(
        ok: ok,
        acao: comando.resumo,
        pacote: pacote,
        elementos: lista,
        mensagem: ok
            ? resumoDaTela(
                pacote: pacote, elementos: lista, limitado: limitado)
            : _erro(resposta, 'Não consegui ler a tela.'),
      );
    }
    return ResultadoTela(
      ok: ok,
      acao: comando.resumo,
      pacote: pacote,
      mensagem: ok
          ? (resposta['mensagem'] as String?)?.trim().isNotEmpty == true
              ? resposta['mensagem'] as String
              : 'Ação de tela concluída.'
          : _erro(resposta, 'O Android recusou a ação de tela.'),
    );
  }

  String _erro(Map<Object?, Object?> resposta, String padrao) {
    final erro = (resposta['erro'] as String?)?.trim() ?? '';
    return erro.isEmpty ? padrao : erro;
  }
}
