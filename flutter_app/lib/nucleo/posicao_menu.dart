/// Onde o menu do núcleo cabe na tela.
///
/// Espelha a mesma conta do lado Android (`PosicaoMenu.calcular`) e existe para
/// travar as regras com teste: à direita quando há espaço, à esquerda quando
/// não há, e sempre dentro da tela, descontando as barras. Se as duas contas
/// divergirem, este teste ajuda a perceber antes do aparelho.
class PosicaoMenuNucleo {
  const PosicaoMenuNucleo({
    required this.x,
    required this.y,
    required this.aDireita,
  });

  final int x;
  final int y;

  /// `true` quando o menu ficou do lado direito do núcleo.
  final bool aDireita;

  static PosicaoMenuNucleo calcular({
    required int nucleoX,
    required int nucleoY,
    required int nucleoLado,
    required int menuLargura,
    required int menuAltura,
    required int telaLargura,
    required int telaAltura,
    required int topo,
    required int base,
    required int folga,
  }) {
    final direita = nucleoX + nucleoLado + folga;
    final cabeDireita = direita + menuLargura <= telaLargura - folga;
    final bruto = cabeDireita ? direita : nucleoX - menuLargura - folga;
    final x = bruto.clamp(
      folga,
      (telaLargura - menuLargura - folga) < folga
          ? folga
          : telaLargura - menuLargura - folga,
    );
    final desejado = nucleoY + nucleoLado ~/ 2 - menuAltura ~/ 2;
    final minimo = topo + folga;
    final maximoBruto = telaAltura - base - menuAltura - folga;
    final y = desejado.clamp(
      minimo,
      maximoBruto < minimo ? minimo : maximoBruto,
    );
    return PosicaoMenuNucleo(x: x, y: y, aDireita: cabeDireita);
  }
}
