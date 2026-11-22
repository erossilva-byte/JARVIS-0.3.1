import 'package:flutter/services.dart';

import '../core/timbre_voz.dart';

/// Falha explicada do canal de voz quando o timbre não pôde ser lido ou salvo.
class TimbreIndisponivel implements Exception {
  const TimbreIndisponivel(this.mensagem);
  final String mensagem;
  @override
  String toString() => mensagem;
}

/// Ponte para a voz pt-BR grave sintetizada pelo Android.
///
/// O áudio é gerado no próprio aparelho; nenhum texto é enviado à rede por
/// causa da fala. Se o mecanismo de síntese não existir, [falar] devolve false
/// em vez de interromper a conversa.
class VozJarvis {
  const VozJarvis({this.channel = const MethodChannel('com.jarvis.nova/voz')});

  final MethodChannel channel;

  Future<bool> falar(String texto) async {
    final limpo = limparParaFala(texto);
    if (limpo.isEmpty) return false;
    try {
      return await channel.invokeMethod<bool>('falar', {'texto': limpo}) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> parar() async {
    try {
      await channel.invokeMethod<void>('parar');
    } on MissingPluginException {
      // Plataforma sem voz nativa: não há nada para parar.
    } on PlatformException {
      // Uma falha do mecanismo não deve quebrar a conversa.
    }
  }

  /// Perfil gravado no aparelho; lança [TimbreIndisponivel] fora do Android.
  Future<String> timbreAtual() async {
    try {
      final dados = await channel.invokeMapMethod<Object?, Object?>('timbre');
      final id = dados?['timbre'];
      // Canal ausente (ou antigo) responde vazio: é falha, não timbre padrão —
      // a tela precisa dizer que ali não há perfis.
      if (id is! String || id.trim().isEmpty) {
        throw const TimbreIndisponivel(
            'Os perfis de timbre só existem no app Android instalado.');
      }
      return timbreDe(id).id;
    } on MissingPluginException {
      throw const TimbreIndisponivel(
          'Os perfis de timbre só existem no app Android instalado.');
    } on PlatformException catch (erro) {
      throw TimbreIndisponivel(
          erro.message ?? 'Não foi possível ler o timbre atual.');
    }
  }

  /// Grava e aplica o perfil. `aplicado` confirma que a síntese aceitou agora.
  Future<({String timbre, bool aplicado})> definirTimbre(String id) async {
    try {
      final dados = await channel.invokeMapMethod<Object?, Object?>(
          'definirTimbre', {'id': timbreDe(id).id});
      if (dados == null || dados['timbre'] is! String) {
        throw const TimbreIndisponivel(
            'Os perfis de timbre só existem no app Android instalado.');
      }
      final salvo = dados['timbre'];
      return (
        timbre: salvo is String && salvo.isNotEmpty ? salvo : timbreDe(id).id,
        aplicado: dados['aplicado'] == true,
      );
    } on MissingPluginException {
      throw const TimbreIndisponivel(
          'Os perfis de timbre só existem no app Android instalado.');
    } on PlatformException catch (erro) {
      throw TimbreIndisponivel(
          erro.message ?? 'Não foi possível aplicar o timbre.');
    }
  }

  Future<Map<Object?, Object?>> status() async {
    try {
      return await channel.invokeMapMethod<Object?, Object?>('status') ??
          const {};
    } on MissingPluginException {
      return const {};
    } on PlatformException {
      return const {};
    }
  }

  /// Remove marcação que o sintetizador leria em voz alta e limita respostas
  /// longas. O corte procura uma pausa de frase para não emendar palavras.
  static String limparParaFala(String texto) {
    var limpo = texto
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
        .replaceAllMapped(RegExp(r'`([^`]*)`'), (m) => m[1] ?? '')
        .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ' ')
        .replaceAllMapped(
            RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m[1] ?? '')
        .replaceAll(RegExp(r'https?://\S+'), ' ')
        .replaceAll(RegExp(r'[*_#>]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAllMapped(RegExp(r'\s+([,.;:!?])'), (m) => m[1] ?? '')
        .trim();
    if (limpo.length <= 1800) return limpo;
    var corte = -1;
    for (final pausa in const ['. ', '! ', '? ', '; ', ', ']) {
      final achado = limpo.lastIndexOf(pausa, 1800);
      if (achado > corte) corte = achado;
    }
    if (corte < 600) corte = 1797;
    limpo = limpo.substring(0, corte).trim();
    return limpo.endsWith('.') || limpo.endsWith('!') || limpo.endsWith('?')
        ? limpo
        : '$limpo.';
  }
}
