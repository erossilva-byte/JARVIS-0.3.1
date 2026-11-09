import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() => runApp(const JarvisApp());

const _cyan = Color(0xFF55DFFF);
const _bg = Color(0xFF050B14);

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'J.A.R.V.I.S. Nova',
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _bg,
      colorScheme: ColorScheme.fromSeed(seedColor: _cyan, brightness: Brightness.dark),
      useMaterial3: true,
      fontFamily: 'Roboto',
    ),
    home: const HomeScreen(),
  );
}

class JarvisModule {
  const JarvisModule(this.name, this.group, this.icon, this.description);
  final String name, group, description;
  final IconData icon;
}

const modules = <JarvisModule>[
  JarvisModule('Hermes Agent', 'Inteligência', Icons.hub, 'Orquestração e execução de agentes.'),
  JarvisModule('Provedores de IA', 'Inteligência', Icons.psychology, 'Groq, OpenRouter/DeepSeek, Gemini, Cerebras e Mistral.'),
  JarvisModule('Modelos locais', 'Inteligência', Icons.memory, 'Modelos locais e operação offline.'),
  JarvisModule('Agentes especializados', 'Inteligência', Icons.smart_toy, 'Agentes por domínio e ferramentas.'),
  JarvisModule('Memória semântica', 'Conhecimento', Icons.account_tree, 'Contexto, memória e recuperação de informações.'),
  JarvisModule('Obsidian', 'Conhecimento', Icons.auto_stories, 'Vínculo e sincronização com cofre Obsidian.'),
  JarvisModule('Voz e KWS', 'Interação', Icons.graphic_eq, 'Voz, palavra de ativação local e síntese.'),
  JarvisModule('Visão e OCR', 'Interação', Icons.visibility, 'Câmera, leitura de tela, imagens e documentos.'),
  JarvisModule('Arquivos', 'Produtividade', Icons.folder_open, 'Leitura, criação, conversão e organização.'),
  JarvisModule('Programação e sandbox', 'Produtividade', Icons.code, 'Assistência de código e execução isolada.'),
  JarvisModule('CADeSIMU e elétrica', 'Engenharia', Icons.electrical_services, 'Projetos, circuitos e validação elétrica.'),
  JarvisModule('Avatar 3D', 'Interface', Icons.view_in_ar, 'Avatar e representação visual do assistente.'),
  JarvisModule('Pessoas e contexto', 'Contexto', Icons.people_alt, 'Perfis e contexto configurável.'),
  JarvisModule('Tarefas e rotinas', 'Produtividade', Icons.checklist, 'Tarefas persistentes, lembretes e automações.'),
  JarvisModule('Segurança e privacidade', 'Sistema', Icons.shield, 'PIN, biometria e permissões suportadas.'),
  JarvisModule('Android e dispositivos', 'Sistema', Icons.phone_android, 'Estado do dispositivo e recursos Android.'),
  JarvisModule('Pareamento Windows', 'Conectividade', Icons.devices, 'Vínculo entre celular e computador.'),
  JarvisModule('Controle do Windows', 'Conectividade', Icons.desktop_windows, 'Ações autorizadas no computador.'),
  JarvisModule('ESP32 e Home Assistant', 'Conectividade', Icons.sensors, 'Integração com dispositivos e automação residencial.'),
  JarvisModule('Backup e restauração', 'Sistema', Icons.backup, 'Cópia e recuperação dos dados do assistente.'),
  JarvisModule('Atualizações', 'Sistema', Icons.system_update, 'Versões, integridade e atualização do aplicativo.'),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();
  int _tab = 0;
  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Row(children: [Icon(Icons.circle, color: _cyan, size: 10), SizedBox(width: 10), Text('J.A.R.V.I.S. NOVA', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w600))]),
      actions: [IconButton(tooltip: 'Configurações', onPressed: () => _openSettings(), icon: const Icon(Icons.tune))],
    ),
    body: SafeArea(child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 360),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _tab == 0 ? _dashboard(key: const ValueKey('home')) : _modulesView(key: const ValueKey('modules')),
    )),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (v) => setState(() => _tab = v),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.blur_circular), label: 'Núcleo'),
        NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Sistemas'),
      ],
    ),
  );

  Widget _dashboard({Key? key}) => ListView(
    key: key, padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
    children: [
      const Text('SISTEMA DE INTELIGÊNCIA', style: TextStyle(color: _cyan, letterSpacing: 2, fontSize: 11)),
      const SizedBox(height: 8),
      const Text('À sua disposição.', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300)),
      const SizedBox(height: 8),
      const Text('Interface nativa em evolução · núcleo visual', style: TextStyle(color: Colors.white54)),
      const SizedBox(height: 10),
      Center(child: GestureDetector(
        onTap: () => _showCoreAction(),
        child: AnimatedBuilder(animation: _pulse, builder: (context, _) => SizedBox(
          width: 290, height: 290,
          child: CustomPaint(painter: _CorePainter(_pulse.value), child: const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.all_inclusive, color: _cyan, size: 46),
              SizedBox(height: 8),
              Text('J.A.R.V.I.S.', style: TextStyle(letterSpacing: 3, color: Colors.white, fontSize: 16)),
              SizedBox(height: 4),
              Text('TOQUE PARA INTERAGIR', style: TextStyle(letterSpacing: 1.4, color: _cyan, fontSize: 9)),
            ]),
          )),
        )),
      )),
      const SizedBox(height: 10),
      _statusTile(Icons.circle, 'Núcleo visual', 'Renderização Flutter ativa', const Color(0xFF65DFA8)),
      _statusTile(Icons.link, 'Serviços existentes', 'Integração em migração; estado não presumido', Colors.orangeAccent),
      _statusTile(Icons.grid_view, 'Catálogo de recursos', '${modules.length} módulos identificados', _cyan),
      const SizedBox(height: 14),
      FilledButton.icon(onPressed: () => setState(() => _tab = 1), icon: const Icon(Icons.apps), label: const Text('Explorar todas as funcionalidades')),
    ],
  );

  Widget _modulesView({Key? key}) {
    final groups = modules.map((m) => m.group).toSet();
    return ListView(key: key, padding: const EdgeInsets.all(16), children: [
      const Text('CENTRAL DE SISTEMAS', style: TextStyle(color: _cyan, letterSpacing: 2, fontSize: 11)),
      const SizedBox(height: 8),
      const Text('Capacidades do J.A.R.V.I.S.', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w300)),
      const SizedBox(height: 6),
      const Text('Catálogo inicial. Cada integração será marcada como funcional somente após testes reais.', style: TextStyle(color: Colors.white60)),
      const SizedBox(height: 16),
      for (final group in groups) ...[
        Padding(padding: const EdgeInsets.only(top: 12, bottom: 8), child: Text(group.toUpperCase(), style: const TextStyle(color: _cyan, letterSpacing: 1.6, fontSize: 11))),
        for (final m in modules.where((x) => x.group == group))
          Card(color: const Color(0xFF0C1927), child: ListTile(
            leading: Icon(m.icon, color: _cyan),
            title: Text(m.name),
            subtitle: Text(m.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ModulePage(module: m))),
          )),
      ],
    ]);
  }

  Widget _statusTile(IconData icon, String title, String subtitle, Color color) => Card(
    color: const Color(0xFF0B1724),
    child: ListTile(leading: Icon(icon, color: color), title: Text(title), subtitle: Text(subtitle)),
  );

  void _showCoreAction() => showModalBottomSheet<void>(context: context, backgroundColor: const Color(0xFF0B1724), builder: (_) => const Padding(
    padding: EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.touch_app, color: _cyan, size: 32), SizedBox(height: 12),
      Text('Núcleo visual interativo', style: TextStyle(fontSize: 18)),
      SizedBox(height: 8), Text('O toque já aciona a resposta visual. A captura de voz será conectada ao serviço KWS nativo na etapa de integração.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
      SizedBox(height: 12),
    ]),
  ));

  void _openSettings() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
}

class ModulePage extends StatelessWidget {
  const ModulePage({super.key, required this.module});
  final JarvisModule module;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(module.name)),
    body: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(module.icon, color: _cyan, size: 42), const SizedBox(height: 18),
      Text(module.group.toUpperCase(), style: const TextStyle(color: _cyan, letterSpacing: 2)),
      const SizedBox(height: 8), Text(module.name, style: const TextStyle(fontSize: 26)),
      const SizedBox(height: 12), Text(module.description, style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 20),
      const Chip(avatar: Icon(Icons.pending_outlined, size: 16), label: Text('Integração em auditoria')),
      const SizedBox(height: 8),
      const Text('Este módulo aparece no catálogo, mas não é apresentado como funcional até a ponte com o serviço real e seus testes serem concluídos.', style: TextStyle(color: Colors.white54)),
    ])),
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Configurações')),
    body: const ListView(padding: EdgeInsets.all(20), children: [
      Icon(Icons.lock_outline, color: _cyan, size: 36),
      SizedBox(height: 12),
      Text('Cofre de credenciais', style: TextStyle(fontSize: 22)),
      SizedBox(height: 8),
      Text('A tela nativa de chaves de API será ligada ao cofre seguro Android/Windows. Não armazene chaves em texto puro nem em SharedPreferences.', style: TextStyle(color: Colors.white70)),
      SizedBox(height: 16),
      Chip(avatar: Icon(Icons.pending_outlined, size: 16), label: Text('Ponte nativa pendente de integração')),
    ]),
  );
}

class _CorePainter extends CustomPainter {
  _CorePainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .43;
    final glow = Paint()..color = _cyan.withOpacity(.07 + .04 * math.sin(t * math.pi * 2))..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
    canvas.drawCircle(c, radius * .72, glow);
    for (var i = 0; i < 4; i++) {
      final p = Paint()..style = PaintingStyle.stroke..strokeWidth = i == 0 ? 2.4 : 1.0..color = _cyan.withOpacity(.75 - i * .13);
      canvas.drawArc(Rect.fromCircle(center: c, radius: radius * (0.55 + i * .13)), t * math.pi * 2 * (i.isEven ? 1 : -1), math.pi * (1.35 + i * .12), false, p);
    }
    final dots = Paint()..color = _cyan;
    for (var i = 0; i < 36; i++) {
      final a = i * math.pi * 2 / 36 + t * math.pi * 2;
      final r = radius * (.78 + .035 * math.sin(i * 2.1));
      canvas.drawCircle(Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r), i % 3 == 0 ? 2 : 1, dots);
    }
    final core = Paint()..shader = RadialGradient(colors: [_cyan.withOpacity(.35), _cyan.withOpacity(.03), Colors.transparent]).createShader(Rect.fromCircle(center: c, radius: radius * .48));
    canvas.drawCircle(c, radius * .48, core);
  }
  @override
  bool shouldRepaint(covariant _CorePainter oldDelegate) => oldDelegate.t != t;
}
