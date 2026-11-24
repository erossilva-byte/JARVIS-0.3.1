/// Fala em fluxo — frases prontas para falar enquanto a resposta ainda chega.
///
/// A conversa recebe o texto aos poucos. Esperar o fim para falar deixava o
/// JARVIS mudo durante toda a geração; aqui cada frase fechada é entregue assim
/// que aparece, e o resto fica guardado para o fim.
///
/// É Dart puro (sem Flutter, sem voz): quem fala é a tela, e o formato pode ser
/// testado sem emulador.
library;

class FalasEmFluxo {
  FalasEmFluxo({this.minimo = 6, this.maximo = 220});

  /// Antes disso nenhuma frase é entregue: evita falar "Ok." e picar a fala.
  final int minimo;

  /// Sem pontuação, a frase é cortada aqui para a fala não travar.
  final int maximo;

  String _pendente = '';
  int _lido = 0;

  /// Ainda há texto guardado que não virou frase.
  bool get temPendente => _pendente.trim().isNotEmpty;

  /// Texto já lido do parcial (para depuração e testes).
  int get lido => _lido;

  /// Recebe o texto parcial acumulado e devolve as frases que já podem falar.
  ///
  /// [finalizar] fecha a resposta: o que sobrou é devolvido inteiro, com ou sem
  /// pontuação final.
  List<String> acrescentar(String parcial, {bool finalizar = false}) {
    // Parcial que encolheu é uma resposta nova: recomeça do zero.
    if (parcial.length < _lido) {
      _pendente = '';
      _lido = 0;
    }
    _pendente += parcial.substring(_lido);
    _lido = parcial.length;

    final prontas = <String>[];
    while (true) {
      final corte = _corteDeFrase();
      if (corte <= 0) break;
      final frase = _pendente.substring(0, corte).trim();
      _pendente = _pendente.substring(corte).trimLeft();
      if (frase.isNotEmpty) prontas.add(frase);
    }
    if (finalizar && _pendente.trim().isNotEmpty) {
      prontas.add(_pendente.trim());
      _pendente = '';
    }
    return prontas;
  }

  /// Índice onde a frase termina; `0` quando ainda não vale cortar.
  int _corteDeFrase() {
    final texto = _pendente;
    if (texto.trim().isEmpty) return 0;
    for (var i = minimo - 1; i < texto.length; i++) {
      final caractere = texto[i];
      final fim = caractere == '.' ||
          caractere == '!' ||
          caractere == '?' ||
          caractere == '…' ||
          caractere == ';' ||
          caractere == '\n';
      if (!fim) continue;
      final temProximo = i + 1 < texto.length;
      final proximo = temProximo ? texto[i + 1] : ' ';
      // Ponto no meio de palavra ("1.89", "e.mail") não fecha frase.
      if (temProximo && proximo != ' ' && proximo != '\n') continue;
      if (caractere == '.' && i > 0 && _ehDigito(texto[i - 1])) continue;
      return i + 1;
    }
    if (texto.length >= maximo) {
      final espaco = texto.lastIndexOf(' ', maximo);
      return espaco > minimo ? espaco : maximo;
    }
    return 0;
  }

  static bool _ehDigito(String caractere) {
    final codigo = caractere.codeUnitAt(0);
    return codigo >= 48 && codigo <= 57;
  }
}
