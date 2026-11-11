import 'package:flutter/material.dart';
import 'hologram.dart';
import 'ui_common.dart';

/// Central de comando: núcleo holográfico, monitor do sistema, atalhos e conversa.
class CommandCenter extends StatelessWidget {
  const CommandCenter({
    super.key,
    required this.animation,
    required this.clock,
    required this.composer,
    required this.moduleCount,
    required this.onConversation,
    required this.onVoiceStart,
    required this.onProviders,
    required this.onKws,
    required this.onSystems,
  });

  final Animation<double> animation;
  final String clock;
  final TextEditingController composer;
  final int moduleCount;
  final ValueChanged<String> onConversation;
  final VoidCallback onVoiceStart;
  final VoidCallback onProviders;
  final VoidCallback onKws;
  final VoidCallback onSystems;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
    children: [
      Row(children: [
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('CENTRAL DE COMANDO', style: TextStyle(color: cyan, fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.w700)),
          SizedBox(height: 5), Text('À sua disposição.', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w300)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(clock, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w300)),
          Text(DateTime.now().toString().substring(0, 10), style: const TextStyle(fontSize: 9, color: muted)),
        ]),
      ]),
      const SizedBox(height: 8),
      const Text('Inteligência em movimento. Sempre ao seu comando.', style: TextStyle(color: muted, fontSize: 11)),
      Center(child: AnimatedBuilder(animation: animation, builder: (_, __) => GestureDetector(
        onTap: () => showModalBottomSheet<void>(context: context, backgroundColor: panel, showDragHandle: true,
          builder: (_) => const Padding(padding: EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.blur_circular_rounded, color: cyan, size: 38), SizedBox(height: 12),
              Text('Núcleo holográfico', style: TextStyle(fontSize: 19)), SizedBox(height: 8),
              Text('A animação responde ao toque e ao arraste. Use o microfone para iniciar a escuta KWS local.',
                textAlign: TextAlign.center, style: TextStyle(color: muted, height: 1.5)),
            ]))),
        child: SizedBox(width: 310, height: 310,
          child: CustomPaint(painter: HologramPainter(animation.value, Offset.zero),
            child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.all_inclusive_rounded, color: cyan, size: 48), SizedBox(height: 8),
              Text('J.A.R.V.I.S.', style: TextStyle(letterSpacing: 3.5, fontSize: 16)), SizedBox(height: 5),
              Text('NÚCLEO HOLOGRÁFICO', style: TextStyle(color: cyan, fontSize: 8, letterSpacing: 2)),
            ]))),
        ),
      ))),
      const SizedBox(height: 4),
      _sectionHeader('SYSTEM MONITOR', 'ESTADO DO SISTEMA'),
      const SizedBox(height: 9),
      _statusCard(Icons.hub_rounded, 'Núcleo de IA', 'Provedores configuráveis · Groq prioritário',
        'CONFIGURAR', cyan, () => onProviders()),
      const SizedBox(height: 8),
      _statusCard(Icons.graphic_eq_rounded, 'Voz e palavra de ativação',
        'KWS local sherpa-onnx · diagnóstico nativo', 'VERIFICAR',
        const Color(0xFFFFC66D), () => onKws()),
      const SizedBox(height: 8),
      _statusCard(Icons.widgets_rounded, 'Módulos do sistema',
        '$moduleCount áreas identificadas no catálogo', 'SISTEMAS', cyan,
        () => onSystems()),
      const SizedBox(height: 16),
      _sectionHeader('QUICK COMMANDS', 'COMANDOS RÁPIDOS'),
      const SizedBox(height: 9),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final command in ['Bom dia', 'Que horas são?', 'Como está o tempo?', 'Conte uma piada'])
          ActionChip(
            avatar: const Icon(Icons.bolt_rounded, size: 15, color: cyan),
            label: Text(command, style: const TextStyle(fontSize: 11)),
            onPressed: () => onConversation(command),
            backgroundColor: panel, side: const BorderSide(color: Colors.white12),
          ),
      ]),
      const SizedBox(height: 16),
      _sectionHeader('CONVERSA', 'CHAT'),
      const SizedBox(height: 9),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white12)),
        child: Row(children: [
          Expanded(child: TextField(
            controller: composer, textInputAction: TextInputAction.send,
            onSubmitted: (value) { final text = value.trim(); if (text.isEmpty) { return; } composer.clear(); onConversation(text); },
            decoration: const InputDecoration(hintText: 'Fale com J.A.R.V.I.S....', border: InputBorder.none, isDense: true),
          )),
          IconButton(tooltip: 'Enviar mensagem', onPressed: () {
            final text = composer.text.trim(); if (text.isEmpty) { return; } composer.clear(); onConversation(text);
          }, icon: const Icon(Icons.send_rounded, color: cyan)),
          IconButton(tooltip: 'Iniciar escuta por voz', onPressed: onVoiceStart, icon: const Icon(Icons.mic_rounded, color: cyan)),
        ]),
      ),
      const SizedBox(height: 14),
      const Text('Ações de dispositivo e módulos sem integração comprovada não são exibidos como ativos.',
        style: TextStyle(color: Color(0xFF63798B), fontSize: 9, height: 1.5)),
    ],
  );

  Widget _sectionHeader(String title, String trailing) => Row(children: [
    Text(title, style: const TextStyle(fontSize: 9, letterSpacing: 1.6, fontWeight: FontWeight.w700)),
    const Spacer(), Text(trailing, style: const TextStyle(fontSize: 8, letterSpacing: 1.1, color: muted)),
  ]);

  Widget _statusCard(IconData icon, String title, String detail, String state,
    Color color, VoidCallback onTap) => Material(
    color: panel, borderRadius: BorderRadius.circular(13),
    child: InkWell(borderRadius: BorderRadius.circular(13), onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Icon(icon, color: cyan, size: 21), const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3), Text(detail, style: const TextStyle(fontSize: 10, color: muted)),
        ])),
        Text(state, style: TextStyle(fontSize: 8, letterSpacing: .8, color: color, fontWeight: FontWeight.w700)),
      ])),
    ),
  );


}
