import 'package:flutter/services.dart';

import '../core/comandos_android.dart';
import '../core/localizacao.dart';

class ResultadoComando {
  const ResultadoComando(
      {required this.ok,
      required this.mensagem,
      this.ambiguo = false,
      this.acao = ''});
  final bool ok;
  final String mensagem;
  final bool ambiguo;

  /// O que foi executado, em texto curto; entra no histórico do aparelho.
  final String acao;
}

typedef ChamadaComando = Future<Map<Object?, Object?>?> Function(
    String metodo, Map<String, Object?> argumentos);

class ExecutorComandosAndroid {
  ExecutorComandosAndroid({ChamadaComando? chamada, this.ativo = true})
      : _chamada = chamada ?? _canalPadrao;

  static const canal = MethodChannel('com.jarvis.nova/comandos');

  /// Falso quando a interface roda em teste ou em plataforma sem a ponte Android.
  final bool ativo;
  final ChamadaComando _chamada;

  static Future<Map<Object?, Object?>?> _canalPadrao(
      String metodo, Map<String, Object?> argumentos) {
    return canal.invokeMapMethod<Object?, Object?>(metodo, argumentos);
  }

  /// Devolve `null` quando o texto não é um comando Android e deve seguir para a conversa.
  Future<ResultadoComando?> executar(String texto) async {
    final comando = InterpretadorComandos.interpretar(texto);
    if (comando == null) return null;
    if (!ativo) {
      return const ResultadoComando(
          ok: false,
          mensagem:
              'Comandos do Android só funcionam no app Android instalado.');
    }
    try {
      final resposta = switch (comando) {
        ComandoLanterna(:final ligar) =>
          await _chamada('lanterna', {'ligar': ligar}),
        ComandoVolume(:final percentual, :final delta) => await _chamada(
            'volume',
            {'canal': 'musica', 'percentual': percentual, 'delta': delta}),
        ComandoAbrirApp(:final nome) =>
          await _chamada('abrirApp', {'nome': nome}),
        ComandoAlarme(:final hora, :final minuto) =>
          await _chamada('alarme', {'hora': hora, 'minuto': minuto}),
        ComandoLocalizacao() => await _chamada('localizacao', const {}),
      };
      if (comando is ComandoLocalizacao) {
        final local = LocalizacaoAparelho.deMapa(resposta);
        return ResultadoComando(
            ok: local.valida,
            mensagem: fraseLocalizacao(local),
            acao: comando.resumo);
      }
      if (resposta == null) {
        return const ResultadoComando(
            ok: false,
            mensagem: 'O Android não devolveu o resultado do comando.');
      }
      final ambiguo = resposta['ambiguo'] == true;
      return ResultadoComando(
        ok: !ambiguo,
        ambiguo: ambiguo,
        acao: comando.resumo,
        mensagem: resposta['mensagem']?.toString() ??
            (ambiguo
                ? 'Preciso que você diga qual app.'
                : 'Comando executado.'),
      );
    } on MissingPluginException {
      return ResultadoComando(
          ok: false,
          acao: comando.resumo,
          mensagem:
              'Este aparelho não tem a ponte nativa de comandos do Jarvis.');
    } on PlatformException catch (erro) {
      return ResultadoComando(
          ok: false,
          acao: comando.resumo,
          mensagem: erro.message?.trim().isNotEmpty == true
              ? erro.message!
              : 'O Android recusou o comando.');
    } catch (_) {
      return ResultadoComando(
          ok: false,
          acao: comando.resumo,
          mensagem: 'Não foi possível executar o comando no Android.');
    }
  }
}
