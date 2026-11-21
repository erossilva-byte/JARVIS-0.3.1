import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../core/ativacao_sensibilidade.dart';
import 'kws_controller.dart';
import 'kws_bridge.dart';
import 'voz_jarvis.dart';

class KwsSettingsPage extends StatefulWidget {
  const KwsSettingsPage({super.key, this.controller});
  final KwsController? controller;

  @override
  State<KwsSettingsPage> createState() => _KwsSettingsPageState();
}

class _KwsSettingsPageState extends State<KwsSettingsPage> {
  late final KwsController controller;
  late final bool ownsController;
  double? _sensibilidadeLocal;

  int get _sensibilidade =>
      _sensibilidadeLocal?.round() ??
      AtivacaoSensibilidade.comPasso(controller.sensibilidade);

  @override
  void initState() {
    super.initState();
    ownsController = widget.controller == null;
    controller = widget.controller ?? KwsController();
    controller.addListener(_refresh);
    if (ownsController) unawaited(controller.initialize());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_refresh);
    if (ownsController) controller.dispose();
    super.dispose();
  }

  Future<void> _run(Future<KwsStatus> Function() action) async {
    await action();
    if (mounted) setState(() {});
  }

  Color _stateColor(ColorScheme colors) {
    switch (controller.phase) {
      case KwsPhase.listening:
        return const Color(0xFF54D6A0);
      case KwsPhase.error:
        return colors.error;
      case KwsPhase.unavailable:
        return const Color(0xFFFFC66D);
      default:
        return colors.primary;
    }
  }

  String _stateLabel() {
    switch (controller.phase) {
      case KwsPhase.unknown:
        return 'DIAGNÓSTICO PENDENTE';
      case KwsPhase.unavailable:
        return 'PLUGIN INDISPONÍVEL';
      case KwsPhase.idle:
        return 'PRONTO · EM ESPERA';
      case KwsPhase.starting:
        return 'INICIANDO DETECTOR';
      case KwsPhase.listening:
        return 'ESCUTANDO LOCALMENTE';
      case KwsPhase.stopping:
        return 'ENCERRANDO';
      case KwsPhase.error:
        return 'FALHA NO DETECTOR';
    }
  }

  Future<void> _gravarSensibilidade(double valor) async {
    final alvo = AtivacaoSensibilidade.comPasso(valor.round());
    await controller.definirSensibilidade(alvo);
    if (!mounted) return;
    setState(() => _sensibilidadeLocal = null);
    final status = controller.status;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(status.ok
          ? 'Sensibilidade ${status.sensibilidade}% gravada no detector.'
          : 'Não foi possível gravar a sensibilidade: ${status.detail}'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final stateColor = _stateColor(colors);
    final status = controller.status;

    return Scaffold(
      appBar: AppBar(title: const Text('Voz e palavra de ativação')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: colors.surfaceContainerHighest.withValues(alpha: .45),
              border: Border.all(color: stateColor.withValues(alpha: .45)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.graphic_eq_rounded, color: stateColor, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _stateLabel(),
                        style: TextStyle(
                          color: stateColor,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (controller.busy)
                      const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  status.engine.isEmpty ? 'sherpa-onnx KWS' : status.engine,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  status.detail,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(height: 1.45),
                ),
                if (controller.lastWake != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Última ativação recebida: ${controller.lastWake}',
                    style:
                        const TextStyle(color: Color(0xFF54D6A0), fontSize: 12),
                  ),
                ],
                if (controller.error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    controller.error!,
                    style: TextStyle(color: colors.error, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: controller.busy ? null : () => _run(controller.start),
            icon: const Icon(Icons.mic_rounded),
            label: const Text('Ativar palavra de ativação'),
          ),
          const SizedBox(height: 9),
          OutlinedButton.icon(
            onPressed: controller.busy ? null : () => _run(controller.stop),
            icon: const Icon(Icons.mic_off_rounded),
            label: const Text('Parar escuta'),
          ),
          const SizedBox(height: 9),
          OutlinedButton.icon(
            onPressed: controller.busy
                ? null
                : () => _run(() => controller.startTest(seconds: 20)),
            icon: const Icon(Icons.timer_outlined),
            label: const Text('Teste de ativação · 20 segundos'),
          ),
          const SizedBox(height: 9),
          OutlinedButton.icon(
            key: const ValueKey('testar-voz-jarvis'),
            onPressed: () async {
              final falou = await const VozJarvis().falar(
                  'Olá. Eu sou o JARVIS. Estou pronto para ajudar, senhor.');
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(falou
                      ? 'Voz de resposta iniciada.'
                      : 'A síntese de voz do Android não está disponível neste aparelho.')));
            },
            icon: const Icon(Icons.volume_up_rounded),
            label: const Text('Testar voz do JARVIS'),
          ),
          const SizedBox(height: 9),
          TextButton.icon(
            onPressed: controller.busy ? null : () => _run(controller.refresh),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Atualizar diagnóstico'),
          ),
          const SizedBox(height: 18),
          _SensibilidadeCard(
            valor: _sensibilidade,
            busy: controller.busy,
            onChanged: (valor) =>
                setState(() => _sensibilidadeLocal = valor.roundToDouble()),
            onChangeEnd: _gravarSensibilidade,
          ),
          const SizedBox(height: 20),
          const _InfoCard(
            icon: Icons.lock_outline_rounded,
            title: 'Processamento local',
            description:
                'O microfone é processado no aparelho pelo sherpa-onnx. O detector não envia áudio para a nuvem.',
          ),
          const SizedBox(height: 10),
          const _InfoCard(
            icon: Icons.all_inclusive_rounded,
            title: 'Sempre ativa',
            description:
                'Ao abrir o app, o serviço em primeiro plano volta a ouvir. Depois de cada comando ele é rearmado automaticamente, inclusive com o app em segundo plano.',
          ),
          const SizedBox(height: 10),
          const _InfoCard(
            icon: Icons.record_voice_over_rounded,
            title: 'Voz de resposta',
            description:
                'As respostas são faladas em português do Brasil com timbre grave e ritmo pausado, uma aproximação do JARVIS dublado. O áudio é sintetizado no aparelho; use o ícone de alto-falante no topo da conversa para silenciar ou repetir.',
          ),
          const SizedBox(height: 10),
          const _InfoCard(
            icon: Icons.translate_rounded,
            title: 'Limitação do modelo atual',
            description:
                'O modelo KWS foi treinado em inglês. Além de Jarvis, aceita Javis, Jarve, Jarvi, Jarviz, Jarves, Javi, Javali, Charles, Chales e Chale. A precisão de cada pronúncia ainda precisa ser medida no seu aparelho.',
          ),
          const SizedBox(height: 10),
          const _InfoCard(
            icon: Icons.record_voice_over_rounded,
            title: 'Comando após a ativação',
            description:
                'Depois de detectar Jarvis, o Android tenta iniciar reconhecimento de fala offline pt-BR. O texto reconhecido abre uma conversa automaticamente. Se o pacote offline não estiver disponível, o sistema informa o erro e não envia áudio para a nuvem.',
          ),
          const SizedBox(height: 10),
          const _InfoCard(
            icon: Icons.do_not_disturb_on_outlined,
            title: 'Sem Picovoice',
            description:
                'Esta integração utiliza sherpa-onnx. Não há dependência do Picovoice nem fallback de reconhecimento por nuvem.',
          ),
          const SizedBox(height: 12),
          Text(
            'A escuta contínua usa um serviço Android em primeiro plano e exibe uma notificação enquanto estiver ativa.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SensibilidadeCard extends StatelessWidget {
  const _SensibilidadeCard({
    required this.valor,
    required this.busy,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final int valor;
  final bool busy;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colors.surfaceContainerHighest.withValues(alpha: .32),
        border: Border.all(color: colors.primary.withValues(alpha: .28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 20, color: colors.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Sensibilidade da palavra de ativação',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            AtivacaoSensibilidade.descricao(valor),
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
          ),
          Slider(
            key: const ValueKey('sensibilidade-ativacao'),
            value: valor.toDouble(),
            min: AtivacaoSensibilidade.minima.toDouble(),
            max: AtivacaoSensibilidade.maxima.toDouble(),
            divisions:
                (AtivacaoSensibilidade.maxima - AtivacaoSensibilidade.minima) ~/
                    AtivacaoSensibilidade.passo,
            label: '$valor%',
            onChanged: busy ? null : onChanged,
            onChangeEnd: busy ? null : onChangeEnd,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mínima',
                  style: Theme.of(context).textTheme.bodySmall),
              Text(
                '$valor% · ${AtivacaoSensibilidade.rotulo(valor)}',
                key: const ValueKey('sensibilidade-ativacao-valor'),
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              Text('Máxima', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Limiar do modelo: ${AtivacaoSensibilidade.limiar(valor).toStringAsFixed(2)}. '
            'Mais sensível acorda com pronúncia mais distante — inclusive falando '
            'baixo —, ao custo de mais disparos por engano.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.onSurfaceVariant, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .28),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(description,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
