import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../core/ativacao_sensibilidade.dart';
import '../core/hotword_portugues.dart';
import 'hotword_store.dart';
import 'kws_controller.dart';
import 'kws_bridge.dart';
import 'voz_externa_page.dart';
import 'voz_jarvis.dart';

class KwsSettingsPage extends StatefulWidget {
  const KwsSettingsPage({super.key, this.controller, this.hotwordStore});
  final KwsController? controller;
  final PreferenciasHotword? hotwordStore;

  @override
  State<KwsSettingsPage> createState() => _KwsSettingsPageState();
}

class _KwsSettingsPageState extends State<KwsSettingsPage> {
  late final KwsController controller;
  late final bool ownsController;
  late final PreferenciasHotword hotwordStore;
  Set<String> _hotword = HotwordPortugues.idsPadrao;
  bool _hotwordCarregada = false;
  double? _sensibilidadeLocal;

  int get _sensibilidade =>
      _sensibilidadeLocal?.round() ??
      AtivacaoSensibilidade.comPasso(controller.sensibilidade);

  @override
  void initState() {
    super.initState();
    ownsController = widget.controller == null;
    controller = widget.controller ?? KwsController();
    hotwordStore = widget.hotwordStore ?? HotwordStore();
    controller.addListener(_refresh);
    if (ownsController) unawaited(controller.initialize());
    unawaited(_carregarHotword());
  }

  Future<void> _carregarHotword() async {
    final ids = await hotwordStore.carregar();
    if (!mounted) return;
    setState(() {
      _hotword = ids;
      _hotwordCarregada = true;
    });
  }

  /// Liga/desliga uma frase e aplica na hora no detector.
  Future<void> _alternarHotword(VarianteHotword variante, bool ligada) async {
    final nova = {..._hotword};
    if (ligada) {
      nova.add(variante.id);
    } else {
      nova.remove(variante.id);
    }
    if (nova.isEmpty) {
      // Sem nenhuma frase o motor volta ao conjunto empacotado no APK; a tela
      // não finge que a escuta ficou muda.
      _avisar('Deixe pelo menos uma frase ligada para o JARVIS continuar ouvindo.');
      return;
    }
    if (nova.length > HotwordPortugues.limite) {
      _avisar('O detector aceita até ${HotwordPortugues.limite} frases ao mesmo tempo.');
      return;
    }
    setState(() => _hotword = HotwordPortugues.seguras(nova));
    final gravadas = await hotwordStore.gravar(_hotword);
    if (!mounted) return;
    setState(() => _hotword = gravadas);
    await controller.aplicarHotword();
    if (!mounted) return;
    setState(() {});
    final status = controller.status;
    _avisar(status.hotword > 0
        ? '${HotwordPortugues.resumo(gravadas)} · detector religado com ${status.hotword} frases.'
        : 'Frases gravadas. O detector as usa na próxima escuta.');
  }

  void _avisar(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
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
          // A voz por ID morava só dentro de outro módulo; aqui é o lugar em
          // que a pessoa procura voz.
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              key: const ValueKey('abrir-voz-externa'),
              leading: const Icon(Icons.key_rounded),
              title: const Text('Voz externa (ID)'),
              subtitle: const Text(
                  'ID da voz e chave do Fish Audio, com teste de voz. '
                  'Desligada, o JARVIS fala com a voz do aparelho.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const VozExternaPage())),
            ),
          ),
          const SizedBox(height: 14),
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
                    'Última ativação recebida: '
                    '${HotwordPortugues.nomeAmigavel(controller.lastWake!)}',
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
          const SizedBox(height: 14),
          _HotwordCard(
            carregada: _hotwordCarregada,
            ativos: _hotword,
            busy: controller.busy,
            onChanged: _alternarHotword,
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
                'O modelo KWS foi treinado em inglês. As frases em português da lista acima são pronúncias aceitas pelo modelo, não um modelo brasileiro: “Ei Jarvis” e “Olá Jarvis” chegam ao detector como sons parecidos com palavras inglesas. A precisão de cada pronúncia só pode ser medida no seu aparelho, com a sua voz.',
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

class _HotwordCard extends StatelessWidget {
  const _HotwordCard({
    required this.carregada,
    required this.ativos,
    required this.busy,
    required this.onChanged,
  });

  final bool carregada;
  final Set<String> ativos;
  final bool busy;
  final void Function(VarianteHotword variante, bool ligada) onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final grupos = <String, List<VarianteHotword>>{};
    for (final variante in HotwordPortugues.variantes) {
      grupos.putIfAbsent(variante.grupo, () => []).add(variante);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
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
              Icon(Icons.record_voice_over_rounded,
                  size: 20, color: colors.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Palavras que acordam o JARVIS',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            carregada
                ? '${ativos.length} de ${HotwordPortugues.variantes.length} ligadas. '
                    'O detector aceita até ${HotwordPortugues.limite} ao mesmo tempo.'
                : 'Lendo as frases gravadas no aparelho…',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 4),
          Text(
            'O nome e as pronúncias que já existiam ficam ligados. As frases com '
            '“ei”, “oi”, “alô” e “olá” vêm desligadas: cada palavra extra custa '
            'processamento e pode acordar o JARVIS por engano. Ligue só a que você '
            'usa de verdade.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.onSurfaceVariant, height: 1.4),
          ),
          for (final entrada in grupos.entries) ...[
            const SizedBox(height: 10),
            Text(
              HotwordPortugues.grupos[entrada.key] ?? entrada.key,
              style: TextStyle(
                color: colors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: .8,
              ),
            ),
            for (final variante in entrada.value)
              InkWell(
                onTap: busy || !carregada
                    ? null
                    : () => onChanged(variante, !ativos.contains(variante.id)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Checkbox(
                        key: ValueKey('hotword-${variante.id}'),
                        value: ativos.contains(variante.id),
                        onChanged: busy || !carregada
                            ? null
                            : (valor) =>
                                onChanged(variante, valor ?? false),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(variante.frase,
                                style: const TextStyle(fontSize: 13)),
                            Text(
                              variante.dica,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
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
