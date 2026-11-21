import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../hologram.dart';
import '../ui_common.dart';
import 'kws_bridge.dart';
import 'kws_controller.dart';

/// Modo voz em tela cheia: núcleo animado, estado real do detector e legendas do comando.
class VozTelaCheiaPage extends StatefulWidget {
  const VozTelaCheiaPage({super.key, required this.controller});

  final KwsController controller;

  @override
  State<VozTelaCheiaPage> createState() => _VozTelaCheiaPageState();
}

class _VozTelaCheiaPageState extends State<VozTelaCheiaPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  )..repeat();
  StreamSubscription<KwsCommandEvent>? _eventos;
  String legenda = '';
  bool ocupado = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_atualizar);
    _eventos = KwsController.commandBus.listen((evento) {
      if (!mounted) return;
      if (evento.type == 'command_result' && evento.text.trim().isNotEmpty) {
        setState(() => legenda = evento.text.trim());
      }
      if (evento.type == 'command_error' && evento.message.isNotEmpty) {
        setState(() => legenda = evento.message);
      }
    });
  }

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
    widget.controller.removeListener(_atualizar);
    _eventos?.cancel();
    motion.dispose();
    super.dispose();
  }

  void _atualizar() {
    if (mounted) setState(() {});
  }

  String get _rotulo {
    switch (widget.controller.phase) {
      case KwsPhase.listening:
        return 'Ouvindo';
      case KwsPhase.starting:
        return 'Preparando microfone';
      case KwsPhase.stopping:
        return 'Encerrando';
      case KwsPhase.unavailable:
        return 'KWS indisponível';
      case KwsPhase.error:
        return 'Falha no KWS';
      case KwsPhase.idle:
        return 'Inativo';
      case KwsPhase.unknown:
        return 'Não verificado';
    }
  }

  Color get _cor => switch (widget.controller.phase) {
        KwsPhase.listening => const Color(0xFF64E6B1),
        KwsPhase.starting || KwsPhase.stopping || KwsPhase.unknown => muted,
        _ => const Color(0xFFFF8A80),
      };

  Future<void> _alternar() async {
    if (ocupado) return;
    setState(() => ocupado = true);
    try {
      if (widget.controller.phase == KwsPhase.listening) {
        await widget.controller.stop();
      } else {
        final status = await widget.controller.start();
        if (mounted && !status.listening) {
          setState(() => legenda = status.detail);
        }
      }
    } catch (erro) {
      if (mounted) {
        setState(() => legenda = 'Não foi possível controlar a escuta: $erro');
      }
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ouvindo = widget.controller.phase == KwsPhase.listening;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: const Text('Modo voz'),
        actions: [
          IconButton(
            tooltip: 'Encerrar',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            SizedBox(
              width: 260,
              height: 260,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: motion,
                  builder: (_, __) => CustomPaint(
                    painter: HologramPainter(motion.value, Offset.zero),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                              ouvindo
                                  ? Icons.graphic_eq_rounded
                                  : Icons.mic_off_rounded,
                              color: _cor,
                              size: 44),
                          const SizedBox(height: 8),
                          Text(_rotulo,
                              style: TextStyle(
                                  color: _cor,
                                  fontSize: 13,
                                  letterSpacing: 1.2)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                legenda.isEmpty
                    ? 'Diga “Jarvis” ou use o botão para falar.'
                    : legenda,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: legenda.isEmpty ? muted : Colors.white,
                    fontSize: 16,
                    height: 1.4),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: ocupado ? null : _alternar,
                      icon: Icon(
                          ouvindo ? Icons.stop_rounded : Icons.mic_rounded),
                      label: Text(ouvindo ? 'Parar escuta' : 'Iniciar escuta'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Encerrar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
