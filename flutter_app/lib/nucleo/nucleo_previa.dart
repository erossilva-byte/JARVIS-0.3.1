import 'package:material_ui/material_ui.dart';

import '../hologram.dart';

/// Prévia do mesmo núcleo: esfera geodésica girando, sem fundo.
///
/// O desenho de verdade é feito no Android por cima dos outros apps; aqui ele
/// aparece grande, no app, para a pessoa ver o que vai ligar antes de ligar.
class NucleoPrevia extends StatefulWidget {
  const NucleoPrevia({super.key, this.tamanho = 160});

  final double tamanho;

  @override
  State<NucleoPrevia> createState() => _NucleoPreviaState();
}

class _NucleoPreviaState extends State<NucleoPrevia>
    with SingleTickerProviderStateMixin {
  late final AnimationController giro = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat();

  @override
  void dispose() {
    giro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: widget.tamanho,
        child: AnimatedBuilder(
          animation: giro,
          builder: (_, __) => RepaintBoundary(
            child: CustomPaint(
              painter: HologramPainter(giro.value, Offset.zero, fundo: false),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
}
