import 'voz_externa_service.dart';
import 'voz_jarvis.dart';

/// Fala de resposta: tenta o Fish Audio quando ele está ligado e, se faltar
/// chave, rede, cota ou o aparelho não tocar o MP3, usa a voz do Android.
///
/// A falha da voz externa nunca deixa o JARVIS mudo: por isso o caminho local é
/// sempre o último recurso, e o motivo fica em [ultimoErro] para a tela poder
/// explicar quando o usuário pediu para ouvir.
class FalaJarvis {
  FalaJarvis({
    VozJarvis? local,
    VozExternaService? externa,
    bool Function()? externaPronta,
  })  : _local = local ?? const VozJarvis(),
        _externa = externa ?? VozExternaService(),
        _externaPronta = externaPronta ?? (() => VozExternaConfig.pronta);

  final VozJarvis _local;
  final VozExternaService _externa;

  /// Configuração já carregada; testes podem trocar por um valor fixo.
  final bool Function() _externaPronta;

  /// Por que a voz externa não falou nesta última tentativa; nulo quando ela
  /// falou ou quando está desligada.
  String? ultimoErro;

  /// `true` se alguma voz falou (externa ou local).
  Future<bool> falar(String texto) async {
    ultimoErro = null;
    final limpo = VozJarvis.limparParaFala(texto);
    if (limpo.isEmpty) return false;

    if (_externaPronta()) {
      final resultado = await _externa.gerar(limpo);
      if (resultado.ok) {
        final tocou = await _externa.tocar(resultado.audio!);
        if (tocou) return true;
        ultimoErro = 'O áudio do Fish Audio foi gerado, mas o aparelho não '
            'conseguiu tocar o MP3.';
      } else {
        ultimoErro = resultado.erro;
      }
    }
    return _local.falar(texto);
  }

  /// Interrompe as duas vozes: a externa também precisa calar no gesto de
  /// virar o celular para baixo.
  Future<void> parar() async {
    try {
      await _externa.parar();
    } catch (_) {
      // Canal ausente ou já parado: a voz local ainda precisa ser interrompida.
    }
    await _local.parar();
  }
}
