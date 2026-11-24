import 'dart:async';

import 'voz_externa_service.dart';
import 'voz_jarvis.dart';

/// Fala de resposta: tenta o Fish Audio quando ele está ligado e, se faltar
/// chave, rede, cota, tempo ou o aparelho não tocar o MP3, usa a voz do Android.
///
/// A falha da voz externa nunca deixa o JARVIS mudo: por isso o caminho local é
/// sempre o último recurso, e o motivo fica em [ultimoErro] para a tela poder
/// explicar quando o usuário pediu para ouvir.
///
/// ## Por que a fala começava tarde
///
/// Cada frase era gerada na hora de falar: com a voz externa, o texto já estava
/// na tela e o áudio só começava depois de uma ida à nuvem — e a frase seguinte
/// só era pedida quando a anterior acabava, somando as esperas. Agora a geração
/// é adiantada ([preparar]) enquanto a frase anterior toca, e a primeira frase
/// tem prazo curto: se a nuvem não responder, a voz do aparelho fala na hora e
/// o resto da resposta continua nela, sem trocar de voz no meio.
class FalaJarvis {
  FalaJarvis({
    VozJarvis? local,
    VozExternaService? externa,
    bool Function()? externaPronta,
    this.prazoExterna = const Duration(seconds: 3),
  })  : _local = local ?? const VozJarvis(),
        _externa = externa ?? VozExternaService(),
        _externaPronta = externaPronta ?? (() => VozExternaConfig.pronta);

  final VozJarvis _local;
  final VozExternaService _externa;

  /// Configuração já carregada; testes podem trocar por um valor fixo.
  final bool Function() _externaPronta;

  /// Tempo máximo que a voz externa pode segurar a fala antes de o aparelho
  /// assumir. Contado a partir do começo da geração, não do pedido de fala.
  final Duration prazoExterna;

  /// Por que a voz externa não falou nesta última tentativa; nulo quando ela
  /// falou ou quando está desligada.
  String? ultimoErro;

  /// Gerações já pedidas e ainda não tocadas, por texto falável.
  ///
  /// É o que faz a fala acompanhar o texto: enquanto a frase atual toca, a
  /// próxima já está sendo gerada.
  final Map<String, Future<ResultadoVozExterna>> _preparadas = {};

  /// Máximo de frases adiantadas; o resto volta a ser gerado na hora.
  static const _maximoAdiantadas = 4;

  /// A voz externa passou do prazo nesta resposta: o resto fala no aparelho,
  /// para não trocar de voz no meio da mesma resposta.
  bool _externaDesistiu = false;

  /// Começa a gerar o áudio de [texto] antes de ser a vez dele.
  ///
  /// Não espera nada e não fala: só deixa a geração pronta para quando a frase
  /// entrar na fila. Falha da rede só aparece no momento de falar.
  void preparar(String texto) {
    if (_externaDesistiu || !_externaPronta()) return;
    final limpo = VozJarvis.limparParaFala(texto);
    if (limpo.isEmpty || _preparadas.containsKey(limpo)) return;
    _preparadas[limpo] = _externa.gerar(limpo);
    while (_preparadas.length > _maximoAdiantadas) {
      _preparadas.remove(_preparadas.keys.first);
    }
  }

  /// `true` se alguma voz falou (externa ou local).
  Future<bool> falar(String texto) async {
    ultimoErro = null;
    final limpo = VozJarvis.limparParaFala(texto);
    if (limpo.isEmpty) return false;

    if (await _falarExterna(limpo, fluxo: false)) return true;
    return _local.falar(texto);
  }

  /// Fala uma frase do fluxo, sem esperar a resposta inteira.
  ///
  /// A voz externa espera o MP3 terminar (a frase seguinte não corta esta) e a
  /// voz do aparelho entra na fila do sintetizador.
  Future<bool> falarEmFluxo(String texto, {Duration? prazo}) async {
    ultimoErro = null;
    final limpo = VozJarvis.limparParaFala(texto);
    if (limpo.isEmpty) return false;

    if (await _falarExterna(limpo, fluxo: true, prazo: prazo)) return true;
    return _local.falarEmFila(texto);
  }

  /// Tenta a voz externa com prazo; devolve `false` quando o aparelho deve falar.
  Future<bool> _falarExterna(
    String limpo, {
    required bool fluxo,
    Duration? prazo,
  }) async {
    if (_externaDesistiu || !_externaPronta()) return false;
    final futuro = _preparadas.remove(limpo) ?? _externa.gerar(limpo);
    final limite = prazo ?? prazoExterna;
    ResultadoVozExterna resultado;
    try {
      resultado = await futuro.timeout(limite);
    } on TimeoutException {
      // A geração continua em segundo plano e é descartada: nada toca depois.
      _externaDesistiu = true;
      ultimoErro = 'A voz externa passou do prazo de '
          '${limite.inMilliseconds} ms. Falei com a voz do aparelho para não '
          'atrasar a resposta.';
      return false;
    }
    if (resultado.ok) {
      final tocou = fluxo
          ? await _externa.tocarEAguardar(resultado.audio!)
          : await _externa.tocar(resultado.audio!);
      if (tocou) return true;
      ultimoErro = 'O áudio do Fish Audio foi gerado, mas o aparelho não '
          'conseguiu tocar o MP3.';
      return false;
    }
    ultimoErro = resultado.erro;
    return false;
  }

  /// Interrompe as duas vozes: a externa também precisa calar no gesto de
  /// virar o celular para baixo.
  ///
  /// Zera o adiantamento e o desistir da voz externa: a próxima resposta tenta
  /// o Fish Audio de novo, com o prazo valendo outra vez.
  Future<void> parar() async {
    _preparadas.clear();
    _externaDesistiu = false;
    try {
      await _externa.parar();
    } catch (_) {
      // Canal ausente ou já parado: a voz local ainda precisa ser interrompida.
    }
    await _local.parar();
  }
}
