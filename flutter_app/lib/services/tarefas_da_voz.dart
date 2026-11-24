import 'package:flutter/services.dart';

import '../core/aparelho.dart';
import '../core/pedido_nucleo.dart';
import '../nucleo/nucleo_controle.dart';
import 'aparelho_service.dart';

/// Resultado de uma tarefa pedida por texto ou voz.
class ResultadoTarefa {
  const ResultadoTarefa({
    required this.ok,
    required this.mensagem,
    required this.acao,
  });

  final bool ok;
  final String mensagem;

  /// O que foi executado, em texto curto; vai para o histórico do aparelho.
  final String acao;
}

/// Executa no aparelho as tarefas que a voz pede antes de gastar provedor.
///
/// Cobre o que já existia em telas mas não era alcançável falando: pausar ou
/// retomar a música que está tocando, mandar mensagem, ligar e ativar o núcleo
/// flutuante. Abrir app, lanterna, volume e alarme continuam no
/// `ExecutorComandosAndroid`, que roda antes deste.
///
/// Nada aqui afirma sucesso sem a resposta do Android: quando o canal não
/// existe ou o sistema recusa, o texto diz o motivo e a conversa continua.
class TarefasDaVoz {
  TarefasDaVoz({
    AparelhoService? aparelho,
    Future<NucleoEstado> Function()? iniciarNucleo,
    Future<NucleoEstado> Function()? pararNucleo,
  })  : _aparelho = aparelho ?? AparelhoService(),
        _iniciarNucleo = iniciarNucleo ?? NucleoControle.iniciar,
        _pararNucleo = pararNucleo ?? NucleoControle.parar;

  final AparelhoService _aparelho;
  final Future<NucleoEstado> Function() _iniciarNucleo;
  final Future<NucleoEstado> Function() _pararNucleo;

  /// Devolve `null` quando o texto não é uma tarefa desta classe.
  Future<ResultadoTarefa?> executar(String texto) async {
    final limpo = _semAcento(texto);
    if (limpo.isEmpty) return null;
    // Comandos do Android têm prioridade e são tratados antes; não os
    // reinterpretar aqui evita transformar "ligar a lanterna" em ligação.
    for (final termo in const [
      'lanterna',
      'volume',
      'alarme',
      'despertador',
      'nucleo',
    ]) {
      if (limpo.contains(termo)) return null;
    }
    // "Tocar em Enviar" é automação de tela, não música: a tela decide antes
    // e continua sendo quem pede o "sim".
    if (limpo.contains('tela') ||
        RegExp(r'\b(tocar|toca|toque|clicar|clica|clique)\s+(em|no|na|nos|nas)\b')
            .hasMatch(limpo)) {
      return null;
    }

    final musica = interpretarSpotify(texto);
    if (musica != null) {
      return _rodar(
        acao: musica.resumo,
        chamada: () => _aparelho.spotify(musica),
        recusa: 'O Android não deixou controlar a música.',
      );
    }

    final mensagem = interpretarMensagem(texto);
    if (mensagem != null && mensagem.pronto) {
      return _rodar(
        acao: 'mensagem por ${mensagem.app.nome}',
        chamada: () => _aparelho.enviarMensagem(mensagem),
        recusa: 'O Android não deixou preparar a mensagem.',
      );
    }

    final ligacao = interpretarLigacao(texto);
    if (ligacao != null && !limpo.contains('musica')) {
      return _rodar(
        acao: ligacao.resumo,
        chamada: () => _aparelho.ligar(ligacao.destino),
        recusa: 'O Android não deixou iniciar a ligação.',
      );
    }
    return null;
  }

  /// Ativa ou desativa o núcleo flutuante pelo texto, com a resposta real.
  Future<ResultadoTarefa> nucleo(bool ativar, String texto) async {
    final acao = ativar ? 'ativar o núcleo flutuante' : 'desativar o núcleo';
    try {
      final estado = ativar ? await _iniciarNucleo() : await _pararNucleo();
      if (ativar) {
        if (estado.ativo) {
          return ResultadoTarefa(
            ok: true,
            acao: acao,
            mensagem:
                'Núcleo flutuante ativo. Ele fica por cima dos outros apps '
                'até você pedir para desativar.',
          );
        }
        final motivo = estado.motivo == 'sem_permissao'
            ? 'Falta autorizar “Exibir sobre outros apps” para o núcleo aparecer '
                'por cima dos outros aplicativos.'
            : 'O Android não abriu o núcleo flutuante.';
        return ResultadoTarefa(ok: false, acao: acao, mensagem: motivo);
      }
      return ResultadoTarefa(
        ok: !estado.ativo,
        acao: acao,
        mensagem: estado.ativo
            ? 'O núcleo continua na tela; o Android não confirmou a saída.'
            : 'Núcleo flutuante desativado.',
      );
    } on MissingPluginException {
      return ResultadoTarefa(
        ok: false,
        acao: acao,
        mensagem: 'O núcleo flutuante só existe no app Android instalado.',
      );
    } catch (_) {
      return ResultadoTarefa(
        ok: false,
        acao: acao,
        mensagem: 'Não foi possível falar com o núcleo flutuante agora.',
      );
    }
  }

  /// Pedido de núcleo no texto, se houver.
  static bool? pedidoDeNucleo(String texto) => pedidoNucleo(texto);

  Future<ResultadoTarefa> _rodar({
    required String acao,
    required Future<ResultadoAparelho> Function() chamada,
    required String recusa,
  }) async {
    try {
      final resultado = await chamada();
      return ResultadoTarefa(
        ok: resultado.ok,
        acao: acao,
        mensagem: resultado.mensagem.isEmpty ? recusa : resultado.mensagem,
      );
    } catch (erro) {
      final motivo = erro is AparelhoIndisponivel ? erro.mensagem : recusa;
      return ResultadoTarefa(ok: false, acao: acao, mensagem: motivo);
    }
  }

  static String _semAcento(String texto) {
    const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const para = 'aaaaaeeeeiiiiooooouuuuc';
    final saida = StringBuffer();
    for (final rune in texto.toLowerCase().runes) {
      final caractere = String.fromCharCode(rune);
      final indice = de.indexOf(caractere);
      saida.write(indice < 0 ? caractere : para[indice]);
    }
    return saida.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
