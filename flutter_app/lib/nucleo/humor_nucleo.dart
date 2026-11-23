import 'dart:async';

import 'nucleo_controle.dart';

/// Estados que o núcleo flutuante imita: parado, ouvindo, pensando ou falando.
enum HumorNucleo { espera, ouvindo, pensando, falando }

/// Decide o humor do núcleo juntando a escuta do detector com a conversa.
///
/// A conversa tem prioridade sobre a escuta: enquanto o JARVIS responde, o
/// núcleo mostra pensamento ou fala, mesmo com o microfone aberto. A fala tem
/// prioridade sobre o pensamento para não voltar ao violeta no meio da leitura.
class HumorNucleoControle {
  HumorNucleoControle._();

  static bool _escutando = false;
  static HumorNucleo? _conversa;
  static int _falas = 0;
  static HumorNucleo? _enviado;

  /// Humor que o núcleo deve estar mostrando agora.
  static HumorNucleo get atual {
    if (_falas > 0) return HumorNucleo.falando;
    return _conversa ?? (_escutando ? HumorNucleo.ouvindo : HumorNucleo.espera);
  }

  /// O detector de palavra de ativação abriu ou fechou o microfone.
  static void definirEscuta(bool valor) {
    _escutando = valor;
    _aplicar();
  }

  /// A conversa está esperando resposta do provedor.
  static void definirPensando(bool valor) {
    if (valor) {
      _conversa = HumorNucleo.pensando;
    } else if (_conversa == HumorNucleo.pensando) {
      _conversa = null;
    }
    _aplicar();
  }

  /// A síntese de voz começou a ler; pode haver mais de uma leitura em fila.
  static void iniciarFala() {
    _falas++;
    _aplicar();
  }

  static void terminarFala() {
    if (_falas > 0) _falas--;
    _aplicar();
  }

  /// A tela de conversa fechou: volta a obedecer só à escuta.
  static void esquecerConversa() {
    _conversa = null;
    _falas = 0;
    _aplicar();
  }

  /// Só para testes: zera a memória sem falar com o Android.
  static void reiniciarParaTeste() {
    _escutando = false;
    _conversa = null;
    _falas = 0;
    _enviado = null;
  }

  static void _aplicar() {
    final alvo = atual;
    if (alvo == _enviado) return;
    _enviado = alvo;
    unawaited(NucleoControle.definirHumor(alvo).catchError((Object _) {}));
  }
}
