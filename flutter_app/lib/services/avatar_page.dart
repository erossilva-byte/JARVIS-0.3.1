import 'package:material_ui/material_ui.dart';

import '../avatar3d.dart';
import '../nucleo/nucleo_page.dart';
import '../ui_common.dart';

/// Avatar 3D do JARVIS: busto desenhado por projeção em perspectiva.
///
/// A tela é honesta sobre o que existe: a geometria, o giro, a luz e as
/// expressões são calculados no aparelho, sem motor 3D de terceiros e sem
/// modelo importado. As expressões são prévia — este avatar ainda não sabe se
/// você está falando de verdade; os estados são os mesmos que a conversa usa.
class AvatarPage extends StatefulWidget {
  const AvatarPage({super.key, this.estadoInicial = AvatarEstado.espera});

  final AvatarEstado estadoInicial;

  @override
  State<AvatarPage> createState() => _AvatarPageState();
}

class _AvatarPageState extends State<AvatarPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  late AvatarEstado estado = widget.estadoInicial;
  double giro = 0;
  bool girarSozinho = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduzir = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduzir) {
      motion.stop();
      motion.value = 0;
    } else if (!motion.isAnimating) {
      motion.repeat();
    }
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  void _arrastar(DragUpdateDetails detalhe) {
    setState(() => giro += detalhe.delta.dx * 0.010);
  }

  void _centralizar() => setState(() => giro = 0);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Avatar 3D', style: TextStyle(fontSize: 15)),
          actions: [
            IconButton(
              key: const ValueKey('avatar-centralizar'),
              tooltip: 'Centralizar o avatar',
              onPressed: _centralizar,
              icon: const Icon(Icons.center_focus_strong_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Eyebrow('AVATAR 3D'),
            const SizedBox(height: 8),
            const Text('Um busto, girado por você',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300)),
            const SizedBox(height: 7),
            const Text(
              'Geometria, perspectiva, luz e expressões são calculadas neste '
              'aparelho. Arraste para os lados para girar, dê dois toques para '
              'centralizar e escolha um estado para ver a reação.',
              style: TextStyle(color: muted, height: 1.5, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Container(
              key: const ValueKey('avatar-3d'),
              height: 360,
              decoration: BoxDecoration(
                color: const Color(0xFF03080F),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cyan.withValues(alpha: .18)),
              ),
              clipBehavior: Clip.antiAlias,
              // Giro no eixo horizontal: o deslize vertical continua rolando
              // a página, sem disputa entre os dois gestos.
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: _arrastar,
                onDoubleTap: _centralizar,
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: motion,
                    builder: (_, __) => CustomPaint(
                      painter: Avatar3DPainter(
                        t: motion.value,
                        estado: estado,
                        giro: giro,
                        autoGiro: girarSozinho,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              key: const ValueKey('avatar-nucleo-flutuante'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.blur_on_rounded, color: cyan),
              title: const Text('Núcleo flutuante',
                  style: TextStyle(fontSize: 14)),
              subtitle: const Text(
                'Um núcleo 3D pequeno que se move e se teletransporta por cima '
                'dos outros apps.',
                style: TextStyle(color: muted, fontSize: 11, height: 1.4),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: muted),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const NucleoPage())),
            ),
            Row(
              children: [
                Icon(Icons.circle, size: 8, color: _corDoEstado(estado)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${estado.rotulo} · ${estado.frase}',
                    key: const ValueKey('avatar-estado-atual'),
                    style: const TextStyle(fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Eyebrow('ESTADOS'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final valor in AvatarEstado.values)
                  ChoiceChip(
                    key: ValueKey('avatar-estado-${valor.name}'),
                    label: Text(valor.rotulo,
                        style: const TextStyle(fontSize: 11)),
                    selected: estado == valor,
                    onSelected: (_) => setState(() => estado = valor),
                    selectedColor: _corDoEstado(valor).withValues(alpha: .22),
                    labelStyle: TextStyle(
                      color: estado == valor ? _corDoEstado(valor) : muted,
                    ),
                    side: BorderSide(
                      color: estado == valor
                          ? _corDoEstado(valor).withValues(alpha: .55)
                          : Colors.white12,
                    ),
                    backgroundColor: panel,
                    showCheckmark: false,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const ValueKey('avatar-girar-sozinho'),
              value: girarSozinho,
              onChanged: (valor) => setState(() => girarSozinho = valor),
              contentPadding: EdgeInsets.zero,
              title:
                  const Text('Girar sozinho', style: TextStyle(fontSize: 12.5)),
              subtitle: const Text(
                'Um balanço lento em volta do busto. Desligado, o avatar só '
                'gira com o dedo.',
                style: TextStyle(color: muted, fontSize: 10.5),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cyan.withValues(alpha: .18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('O QUE ESTE AVATAR É',
                      style: TextStyle(
                          fontSize: 9.5,
                          letterSpacing: 1.3,
                          color: cyan,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  for (final linha in _limitesDoAvatar)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 13, color: muted),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              linha,
                              key: const ValueKey('avatar-limite'),
                              style: const TextStyle(
                                  color: muted, fontSize: 10.5, height: 1.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}

Color _corDoEstado(AvatarEstado estado) => switch (estado) {
      AvatarEstado.espera => cyan,
      AvatarEstado.ouvindo => const Color(0xFF8FF4FF),
      AvatarEstado.pensando => const Color(0xFFB5E9FF),
      AvatarEstado.falando => const Color(0xFFD4FAFF),
      AvatarEstado.erro => const Color(0xFFFF7166),
    };

const _limitesDoAvatar = <String>[
  'Não há modelo importado (glTF, OBJ) nem motor 3D de terceiros: a malha é '
      'gerada por revolução do perfil e pintada no próprio Flutter.',
  'As expressões são prévia: boca, olhos e anéis reagem ao estado escolhido, '
      'não à sua voz. Ligar o avatar ao áudio do microfone é o próximo passo.',
  'O avatar não fala, não ouve e não grava nada; nenhum quadro sai do aparelho.',
  'É um busto estilizado, não um rosto com semelhança de pessoa real.',
];
