import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'catalog.dart';
import 'drawer.dart';
import 'command_center.dart';
import 'hologram.dart';
import 'pages.dart';
import 'provider_settings_page.dart';
import 'systems_view.dart';
import 'ui_common.dart';
import 'services/kws_bridge.dart';
import 'services/kws_controller.dart';
import 'services/aparelho_service.dart';
import 'services/arquivos_page.dart';
import 'services/conversa_store.dart';
import 'services/gestos_page.dart';
import 'services/habilidades_page.dart';
import 'services/historico_page.dart';
import 'services/kws_settings_page.dart';
import 'services/memoria_page.dart';
import 'services/memoria_store.dart';
import 'services/pessoas_page.dart';
import 'services/personalidade_page.dart';
import 'services/personalidade_store.dart';
import 'services/pessoas_store.dart';
import 'services/sistema_android.dart';
import 'services/timbre_page.dart';
import 'services/voice_conversation_page.dart';
import 'services/visao_page.dart';
import 'services/voz_tela_cheia_page.dart';

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
    vsync: this,
    duration: const Duration(seconds: 20),
  )..repeat();
  late final TextEditingController composer = TextEditingController();
  late final TextEditingController search = TextEditingController();
  StreamSubscription<KwsCommandEvent>? voiceSubscription;
  StreamSubscription<IntencaoSistema>? sistemaSubscription;
  String query = '';
  int tab = 0;

  /// Jarvis acordado pela palavra de ativação: a tela mostra que ele está
  /// ativo e o microfone já está aberto pelo serviço em primeiro plano.
  bool ativo = false;
  Timer? ativoTimer;
  String clock = '';
  Timer? clockTimer;

  @override
  void initState() {
    super.initState();
    _updateClock();
    clockTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
    unawaited(_ativarKwsAoAbrir());
    jarvisKwsController.addListener(_refreshKws);
    unawaited(_ligarSistema());
    voiceSubscription = KwsController.commandBus.listen((event) {
      if (!mounted) {
        return;
      }
      if (event.type == 'wake') {
        _marcarAtivo(event.text);
      } else if (event.type == 'command_result' && event.text.trim().isNotEmpty) {
        _desmarcarAtivo();
        _openConversation(event.text.trim(), fromVoice: true);
      } else if (event.type == 'command_error' && event.message.isNotEmpty) {
        _mostrarAvisoVoz(_mensagemVozAmigavel(event.message));
      } else if (event.type == 'calou') {
        // Celular virado para baixo: o Android já parou a fala; a tela confirma.
        _desmarcarAtivo();
        if (event.message.isNotEmpty) _mostrarAvisoVoz(event.message);
      }
    });
  }

  /// Mantém o detector ativo sempre que o app abre. Se o usuário já autorizou
  /// o microfone, o serviço em primeiro plano continua ouvindo em segundo plano;
  /// na primeira vez o Android mostra o pedido de permissão.
  Future<void> _ativarKwsAoAbrir() async {
    final status = await jarvisKwsController.initialize();
    if (!mounted || !status.available || status.listening || !status.ok) return;
    // A tela abriu porque o JARVIS foi chamado: o microfone é do comando agora.
    // Ligar o detector aqui tomava a captura e o comando voltava como
    // "não consegui entender" mesmo com a fala clara.
    if (status.comandoAtivo) return;
    await jarvisKwsController.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Modo de animação reduzida (Seção 3D): com a preferência do sistema ligada, o núcleo
    // para de girar em vez de continuar consumindo quadros.
    final reduzir = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduzir) {
      motion.stop();
      motion.value = 0;
    } else if (!motion.isAnimating) {
      motion.repeat();
    }
  }

  void _updateClock() {
    if (!mounted) {
      return;
    }
    final now = DateTime.now();
    setState(() => clock =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}');
  }

  /// Mostra o aviso "JARVIS ATIVO" e confirma com o Android que a tela veio
  /// para a frente e o microfone está ativo.
  void _marcarAtivo(String palavra) {
    if (!mounted) return;
    setState(() => ativo = true);
    unawaited(() async {
      try {
        await AparelhoService().ativarEmSegundoPlano();
      } catch (_) {
        // Fora do Android não há o que ativar; a tela já mostrou o aviso.
      }
    }());
    ativoTimer?.cancel();
    ativoTimer = Timer(const Duration(seconds: 25), _desmarcarAtivo);
  }

  void _desmarcarAtivo() {
    ativoTimer?.cancel();
    if (!mounted || !ativo) return;
    setState(() => ativo = false);
  }

  @override
  @override
  void dispose() {
    clockTimer?.cancel();
    ativoTimer?.cancel();
    jarvisKwsController.removeListener(_refreshKws);
    voiceSubscription?.cancel();
    sistemaSubscription?.cancel();
    motion.dispose();
    composer.dispose();
    search.dispose();
    super.dispose();
  }

  /// Atalhos do ícone, widget e compartilhamento entram pela mesma porta.
  Future<void> _ligarSistema() async {
    await SistemaAndroid.iniciar();
    if (!mounted) return;
    sistemaSubscription = SistemaAndroid.intencoes.listen(_abrirIntencao);
    unawaited(SistemaAndroid.atualizarWidget(_kwsLabel));
  }

  void _abrirIntencao(IntencaoSistema intencao) {
    if (!mounted) return;
    if (intencao.abrirAtivo) {
      _marcarAtivo(intencao.texto);
    } else if (intencao.abrirVoz) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => VozTelaCheiaPage(controller: jarvisKwsController),
      ));
    } else if (intencao.abrirHistorico) {
      unawaited(_abrirHistorico());
    } else if (intencao.textoCompartilhado) {
      _openConversation(intencao.texto);
    } else if (intencao.abrirConversa) {
      _openConversation('');
    }
  }

  Future<void> _abrirMemoria() async {
    try {
      final store = await MemoriaStore.abrir();
      if (!mounted) return;
      await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => MemoriaPage(store: store)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('O cofre local não está disponível neste aparelho.')),
      );
    }
  }

  Future<void> _abrirPessoas() async {
    try {
      final store = await PessoasStore.abrir();
      if (!mounted) return;
      await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => PessoasPage(store: store)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'O armazenamento seguro das fichas não está disponível neste aparelho.')),
      );
    }
  }

  Future<void> _abrirPersonalidade() async {
    try {
      final store = await PersonalidadeStore.abrir();
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => PersonalidadePage(store: store),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'As preferências de personalidade não estão disponíveis neste aparelho.')),
      );
    }
  }

  Future<void> _abrirHistorico() async {
    try {
      final store = await ConversaStore.abrir();
      if (!mounted) return;
      await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => HistoricoPage(store: store)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('O histórico não está disponível neste aparelho.')),
      );
    }
  }

  String _mensagemVozAmigavel(String mensagem) {
    final tecnica = mensagem.contains('maxActivePaths') ||
        mensagem.contains('Exception') ||
        mensagem.contains('JNI') ||
        mensagem.contains('field ID');
    if (tecnica) {
      return 'O detector de voz local falhou. O microfone por toque continua disponível.';
    }
    return mensagem;
  }

  void _mostrarAvisoVoz(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensagem),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 78),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(label: 'Diagnóstico', onPressed: _openKwsSettings),
    ));
  }

  void _openConversation(String command, {bool fromVoice = false}) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) =>
          VoiceConversationPage(initialCommand: command, fromVoice: fromVoice),
    ));
  }

  void _refreshKws() {
    if (!mounted) {
      return;
    }
    setState(() {});
    unawaited(SistemaAndroid.atualizarWidget(_kwsLabel));
  }

  /// Estado real do detector local. Substitui o antigo "ONLINE" fixo da gaveta,
  /// que não media nada e afirmava saúde do sistema sem verificação.
  String get _kwsLabel {
    switch (jarvisKwsController.phase) {
      case KwsPhase.listening:
        return 'KWS ESCUTANDO';
      case KwsPhase.unavailable:
        return 'KWS INDISPONÍVEL';
      case KwsPhase.error:
        return 'KWS COM FALHA';
      case KwsPhase.idle:
        return 'KWS PRONTO';
      case KwsPhase.starting:
        return 'KWS INICIANDO';
      case KwsPhase.stopping:
        return 'KWS ENCERRANDO';
      case KwsPhase.unknown:
        return 'KWS NÃO VERIFICADO';
    }
  }

  HologramEstado get _holoEstado => switch (jarvisKwsController.phase) {
        KwsPhase.listening => HologramEstado.ouvindo,
        KwsPhase.starting || KwsPhase.stopping => HologramEstado.processando,
        KwsPhase.error || KwsPhase.unavailable => HologramEstado.erro,
        _ => HologramEstado.espera,
      };

  Color get _kwsColor {
    switch (jarvisKwsController.phase) {
      case KwsPhase.listening:
      case KwsPhase.idle:
        return const Color(0xFF64E6B1);
      case KwsPhase.unavailable:
        return const Color(0xFFFFC66D);
      case KwsPhase.error:
        return const Color(0xFFFF8A80);
      case KwsPhase.starting:
      case KwsPhase.stopping:
      case KwsPhase.unknown:
        return muted;
    }
  }

  void _openModule(String name) {
    if (name == 'Memória semântica') {
      unawaited(_abrirMemoria());
      return;
    }
    if (name == 'Pessoas e contexto') {
      unawaited(_abrirPessoas());
      return;
    }
    if (name == 'Personalização') {
      unawaited(_abrirPersonalidade());
      return;
    }
    if (name == 'Visão e OCR') {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const VisaoPage()));
      return;
    }
    if (name == 'Arquivos') {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const ArquivosPage()));
      return;
    }
    if (name == 'Habilidades em Markdown') {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const HabilidadesPage()));
      return;
    }
    if (name == 'Gestos e modo noturno') {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const GestosPage()));
      return;
    }
    if (name == 'Perfis de timbre') {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const TimbrePage()));
      return;
    }
    final matches = modules.where((item) => item.name == name);
    if (matches.isEmpty) {
      return;
    }
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
        backgroundColor: bg,
        titleSpacing: 12,
        title: const Row(children: [
          BrandMark(),
          SizedBox(width: 9),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('J.A.R.V.I.S. NOVA',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.45,
                        fontWeight: FontWeight.w700)),
                Text('PERSONAL AI SYSTEM',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 7.5, letterSpacing: 1.5, color: muted)),
              ])),
        ]),
        actions: [
          IconButton(
              tooltip: 'Voz e palavra de ativação',
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) =>
                          KwsSettingsPage(controller: jarvisKwsController))),
              icon: const Icon(Icons.graphic_eq_rounded, color: cyan)),
          IconButton(
              tooltip: 'Modo voz em tela cheia',
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) =>
                          VozTelaCheiaPage(controller: jarvisKwsController))),
              icon: const Icon(Icons.fullscreen_rounded, color: cyan)),
          IconButton(
              key: const ValueKey('settings-button'),
              tooltip: 'Configurações',
              onPressed: _openSettings,
              icon: const Icon(Icons.tune_rounded, color: cyan)),
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
      body: SafeArea(
          child: Column(children: [
        if (ativo)
          Container(
            key: const ValueKey('jarvis-ativo'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: cyan.withValues(alpha: .14),
            child: const Row(children: [
              Icon(Icons.mic_rounded, color: cyan, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'JARVIS ATIVO · microfone aberto, pode falar',
                  style: TextStyle(fontSize: 10.5, color: cyan),
                ),
              ),
            ]),
          ),
        Expanded(
            child: tab == 0
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
                  holograma: _holoEstado,
                )
              : SystemsView(
                  query: query,
                  search: search,
                  onQuery: (value) => setState(() => query = value),
                  onOpen: (module) => _openModule(module.name),
                  onProviders: _openProviderSettings,
                  onKws: _openKwsSettings,
                )),
      ])),
      bottomNavigationBar: NavigationBar(
        height: 66,
        backgroundColor: const Color(0xFF08121E),
        indicatorColor: cyan.withValues(alpha: .13),
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.blur_circular_rounded),
              selectedIcon: Icon(Icons.blur_on_rounded, color: cyan),
              label: 'Comando'),
          NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              selectedIcon: Icon(Icons.grid_view_rounded, color: cyan),
              label: 'Sistemas'),
        ],
      ),
    );
  }

  Future<void> _startVoice() async {
    try {
      final status = await jarvisKwsController.start();
      if (!mounted) {
        return;
      }
      if (status.listening) {
        _mostrarAvisoVoz('Escuta KWS iniciada.');
      } else {
        _mostrarAvisoVoz(_mensagemVozAmigavel(
            status.error.isNotEmpty ? status.error : status.detail));
      }
    } catch (error) {
      if (mounted) {
        _mostrarAvisoVoz(
            'Não foi possível iniciar a escuta. Abra o diagnóstico para ver o detalhe.');
      }
    }
  }

  void _openProviderSettings() => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProviderSettingsPage()));
  void _openKwsSettings() => Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => KwsSettingsPage(controller: jarvisKwsController)));
}
