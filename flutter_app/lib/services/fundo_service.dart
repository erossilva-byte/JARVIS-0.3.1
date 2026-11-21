import 'package:flutter/services.dart';

import '../core/fundo.dart';

/// Ponte com o serviço de segundo plano do Android.
///
/// Fora do Android o canal não existe: as respostas viram [EstadoFundo.vazio] com
/// `ponteDisponivel: false`, e a tela explica em vez de fingir que está ligado.
abstract interface class FundoGateway {
  Future<EstadoFundo> estado();
  Future<EstadoFundo> definirModoSemTela(bool ativo);
  Future<bool> abrirAjusteSobreposicao();
  Future<EstadoFundo> limparHistorico();
  Future<ResultadoFundo> executarTexto(String texto);
}

class FundoService implements FundoGateway {
  FundoService({MethodChannel? canal})
      : _canal = canal ?? const MethodChannel('com.jarvis.nova/fundo');

  final MethodChannel _canal;

  Future<Map<Object?, Object?>?> _chamar(String metodo,
      [Map<String, Object?>? argumentos]) async {
    try {
      return await _canal.invokeMapMethod<Object?, Object?>(metodo, argumentos);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<EstadoFundo> estado() async {
    final resposta = await _chamar('estado');
    return resposta == null ? EstadoFundo.vazio : EstadoFundo.fromMap(resposta);
  }

  @override
  Future<EstadoFundo> definirModoSemTela(bool ativo) async {
    final resposta = await _chamar('definirModoSemTela', {'ativo': ativo});
    return resposta == null ? EstadoFundo.vazio : EstadoFundo.fromMap(resposta);
  }

  @override
  Future<bool> abrirAjusteSobreposicao() async {
    try {
      return await _canal.invokeMethod<bool>('abrirAjusteSobreposicao') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<EstadoFundo> limparHistorico() async {
    final resposta = await _chamar('limparHistorico');
    return resposta == null ? EstadoFundo.vazio : EstadoFundo.fromMap(resposta);
  }

  @override
  Future<ResultadoFundo> executarTexto(String texto) async {
    final limpo = texto.trim();
    if (limpo.isEmpty) {
      return const ResultadoFundo(ok: false, mensagem: 'Escreva o comando.');
    }
    try {
      final resposta =
          await _canal.invokeMapMethod<Object?, Object?>('executarTexto', {
        'texto': limpo,
      });
      if (resposta == null) {
        return const ResultadoFundo(
          ok: false,
          mensagem: 'O Android não devolveu o resultado do comando.',
        );
      }
      return ResultadoFundo(
        ok: resposta['ok'] == true,
        mensagem: resposta['mensagem']?.toString() ?? '',
        acao: resposta['acao']?.toString() ?? '',
      );
    } on MissingPluginException {
      return const ResultadoFundo(
        ok: false,
        mensagem: 'Comandos em segundo plano só existem no app Android instalado.',
      );
    } on PlatformException catch (erro) {
      return ResultadoFundo(
        ok: false,
        mensagem: erro.message?.trim().isNotEmpty == true
            ? erro.message!
            : 'O Android recusou o comando.',
      );
    }
  }
}
