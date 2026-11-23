import 'dart:async';

import 'package:flutter/services.dart';

import '../core/palco.dart';

/// Pedido vindo do sistema: atalho do ícone, widget ou "compartilhar com" de outro app.
class IntencaoSistema {
  const IntencaoSistema(this.acao, [this.texto = '', this.tipo = '']);

  /// `voz`, `conversa`, `historico`, `compartilhar` ou `palco`.
  final String acao;
  final String texto;

  /// Tipo do palco (`imagem`, `video` ou `noticia`), quando a ação é `palco`.
  final String tipo;

  bool get abrirVoz => acao == 'voz';
  bool get abrirConversa => acao == 'conversa';
  bool get abrirHistorico => acao == 'historico';

  /// Palavra de ativação detectada com o app em segundo plano.
  bool get abrirAtivo => acao == 'ativo';

  /// Pedido de imagem, vídeo ou notícia reconhecido na voz de fundo.
  bool get abrirPalco => acao == 'palco' && texto.trim().isNotEmpty;

  /// Pedido pronto para a tela do palco, ou `null` quando o tipo não fecha.
  PedidoPalco? get pedidoPalco =>
      abrirPalco ? pedidoDePalcoVoz(tipo, texto) : null;
  bool get textoCompartilhado =>
      acao == 'compartilhar' && texto.trim().isNotEmpty;

  static IntencaoSistema? deMapa(Object? dados) {
    if (dados is! Map) return null;
    final acao = dados['acao'];
    if (acao is! String || acao.isEmpty) return null;
    final texto = dados['texto'];
    final tipo = dados['tipo'];
    return IntencaoSistema(
        acao, texto is String ? texto : '', tipo is String ? tipo : '');
  }
}

/// Ponte com o Android: atalhos do ícone, widget da tela inicial e folha de compartilhamento.
///
/// Fora do Android (Windows, testes) o canal não existe: as chamadas devolvem `false` e não
/// derrubam a tela. Nada aqui inventa sucesso.
class SistemaAndroid {
  SistemaAndroid._();

  static const canal = MethodChannel('com.jarvis.nova/sistema');
  static final StreamController<IntencaoSistema> _intencoes =
      StreamController<IntencaoSistema>.broadcast();

  static bool _iniciado = false;

  /// Intenções recebidas com o app aberto (atalho, widget ou compartilhamento).
  static Stream<IntencaoSistema> get intencoes => _intencoes.stream;

  /// Registra o canal e recupera a intenção que abriu o app, se houver.
  static Future<void> iniciar() async {
    if (_iniciado) return;
    _iniciado = true;
    canal.setMethodCallHandler((chamada) async {
      if (chamada.method != 'intencao') return null;
      final intencao = IntencaoSistema.deMapa(chamada.arguments);
      if (intencao != null) _intencoes.add(intencao);
      return null;
    });
    try {
      final pendente = IntencaoSistema.deMapa(
          await canal.invokeMethod<Object?>('intencaoPendente'));
      if (pendente != null) _intencoes.add(pendente);
    } on MissingPluginException {
      // Plataforma sem integração (Windows/teste): segue sem intenção.
    } on PlatformException {
      // O Android recusou a consulta; não há o que abrir.
    }
  }

  /// Abre a folha de compartilhamento do sistema com o texto. Devolve `false` quando não há
  /// integração disponível.
  static Future<bool> compartilhar(String texto) async {
    if (texto.trim().isEmpty) return false;
    try {
      final enviado =
          await canal.invokeMethod<bool>('compartilhar', {'texto': texto});
      return enviado ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Abre um link http(s) no navegador do aparelho.
  ///
  /// Devolve `false` quando não há integração (Windows/teste) ou quando o
  /// Android recusa — o palco então mostra o endereço em vez de fingir que
  /// abriu.
  static Future<bool> abrirUrl(String url) async {
    final limpo = url.trim();
    if (!limpo.startsWith('http://') && !limpo.startsWith('https://')) {
      return false;
    }
    try {
      final abriu = await canal.invokeMethod<bool>('abrirUrl', {'url': limpo});
      return abriu ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Atualiza o texto de estado do widget. Silencioso por desenho: widget é acessório.
  static Future<void> atualizarWidget(String texto) async {
    try {
      await canal.invokeMethod<void>('atualizarWidget', {'texto': texto});
    } on MissingPluginException {
      // Sem widget fora do Android.
    } on PlatformException {
      // Widget removido ou launcher indisponível.
    }
  }

  /// Só para testes: permite registrar o canal de novo entre casos.
  static void reiniciarParaTeste() {
    _iniciado = false;
    canal.setMethodCallHandler(null);
  }
}
