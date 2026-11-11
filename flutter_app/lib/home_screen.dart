import 'dart:async';
import 'package:flutter/material.dart';
import 'catalog.dart';
import 'drawer.dart';
import 'command_center.dart';
import 'pages.dart';
import 'provider_settings_page.dart';
import 'systems_view.dart';
import 'ui_common.dart';
import 'services/kws_bridge.dart';
import 'services/kws_controller.dart';
import 'services/kws_settings_page.dart';
import 'services/voice_conversation_page.dart';

// Interface clássica restaurada: HUD central, barra superior, painel lateral,
// monitor do sistema, comandos rápidos e conversa.
class LegacyHomeScreen extends StatefulWidget {
  const LegacyHomeScreen({super.key});
  @override
  State<LegacyHomeScreen> createState() => _LegacyHomeScreenState();
}
class _LegacyHomeScreenState extends State<LegacyHomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this, duration: const Duration(seconds: 20),
  )..repeat();
  late final TextEditingController composer = TextEditingController();
  late final TextEditingController search = TextEditingController();
  StreamSubscription<KwsCommandEvent>? voiceSubscription;
  String query = '';
  int tab = 0;
  String clock = '';
  Timer? clockTimer;

  @override
  void initState() {
    super.initState();
    _updateClock();
    clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
    unawaited(jarvisKwsController.initialize());
    jarvisKwsController.addListener(_refreshKws);
    voiceSubscription = KwsController.commandBus.listen((event) {
      if (!mounted) { return; }
      if (event.type == 'command_result' && event.text.trim().isNotEmpty) {
        _openConversation(event.text.trim(), fromVoice: true);
      } else if (event.type == 'command_error' && event.message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(event.message)));
      }
    });
  }

  void _updateClock() {
    if (!mounted) { return; }
    final now = DateTime.now();
    setState(() => clock = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}');
  }

  @override
  void dispose() {
    clockTimer?.cancel();
    jarvisKwsController.removeListener(_refreshKws);
    voiceSubscription?.cancel();
    motion.dispose();
    composer.dispose();
    search.dispose();
    super.dispose();
  }

  void _openConversation(String command, {bool fromVoice = false}) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => VoiceConversationPage(initialCommand: command, fromVoice: fromVoice),
    ));
  }

  void _refreshKws() {
    if (mounted) { setState(() {}); }
  }

  /// Estado real do detector local. Substitui o antigo "ONLINE" fixo da gaveta,
  /// que não media nada e afirmava saúde do sistema sem verificação.
  String get _kwsLabel {
    switch (jarvisKwsController.phase) {
      case KwsPhase.listening: return 'KWS ESCUTANDO';
      case KwsPhase.unavailable: return 'KWS INDISPONÍVEL';
      case KwsPhase.error: return 'KWS COM FALHA';
      case KwsPhase.idle: return 'KWS PRONTO';
      case KwsPhase.starting: return 'KWS INICIANDO';
      case KwsPhase.stopping: return 'KWS ENCERRANDO';
      case KwsPhase.unknown: return 'KWS NÃO VERIFICADO';
    }
  }

  Color get _kwsColor {
    switch (jarvisKwsController.phase) {
      case KwsPhase.listening:
      case KwsPhase.idle: return const Color(0xFF64E6B1);
      case KwsPhase.unavailable: return const Color(0xFFFFC66D);
      case KwsPhase.error: return const Color(0xFFFF8A80);
      case KwsPhase.starting:
      case KwsPhase.stopping:
      case KwsPhase.unknown: return muted;
    }
  }

  void _openModule(String name) {
    final matches = modules.where((item) => item.name == name);
    if (matches.isEmpty) { return; }
    final module = matches.first;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ModulePage(module: module),
    ));
  }

  void _openSettings() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SettingsPage(controller: jarvisKwsController),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: bg, titleSpacing: 16,
        title: const Row(children: [
          BrandMark(), SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('J.A.R.V.I.S. NOVA', style: TextStyle(fontSize: 13, letterSpacing: 2, fontWeight: FontWeight.w700)),
            Text('PERSONAL AI SYSTEM', style: TextStyle(fontSize: 8, letterSpacing: 2, color: muted)),
          ]),
        ]),
        actions: [
          IconButton(tooltip: 'Voz e palavra de ativação',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => KwsSettingsPage(controller: jarvisKwsController))),
            icon: const Icon(Icons.graphic_eq_rounded, color: cyan)),
          IconButton(key: const ValueKey('settings-button'), tooltip: 'Configurações',
            onPressed: _openSettings, icon: const Icon(Icons.tune_rounded, color: cyan)),
          const SizedBox(width: 6),
        ],
      ),
      drawer: JarvisDrawer(
        onSelectTab: (value) => setState(() => tab = value),
        onProviders: _openProviderSettings,
        onKws: _openKwsSettings,
        onModule: _openModule,
        onSettings: _openSettings,
        kwsLabel: _kwsLabel,
        kwsColor: _kwsColor,
      ),
      body: SafeArea(child: tab == 0
        ? CommandCenter(
            animation: motion,
            clock: clock,
            composer: composer,
            moduleCount: modules.length,
            onConversation: _openConversation,
            onVoiceStart: _startVoice,
            onProviders: _openProviderSettings,
            onKws: _openKwsSettings,
            onSystems: () => setState(() => tab = 1),
          )
        : SystemsView(
            query: query,
            search: search,
            onQuery: (value) => setState(() => query = value),
            onOpen: (module) => _openModule(module.name),
            onProviders: _openProviderSettings,
            onKws: _openKwsSettings,
          )),
      bottomNavigationBar: NavigationBar(
        height: 66, backgroundColor: const Color(0xFF08121E),
        indicatorColor: cyan.withValues(alpha: .13), selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.blur_circular_rounded), selectedIcon: Icon(Icons.blur_on_rounded, color: cyan), label: 'Comando'),
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), selectedIcon: Icon(Icons.grid_view_rounded, color: cyan), label: 'Sistemas'),
        ],
      ),
    );
  }

  Future<void> _startVoice() async {
    try {
      final status = await jarvisKwsController.start();
      if (!mounted) { return; }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status.listening ? 'Escuta KWS iniciada.' : status.detail)));
    } catch (error) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível iniciar a escuta: $error'))); }
    }
  }

  void _openProviderSettings() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProviderSettingsPage()));
  void _openKwsSettings() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => KwsSettingsPage(controller: jarvisKwsController)));

}
