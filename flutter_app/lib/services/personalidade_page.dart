import 'package:material_ui/material_ui.dart';

import '../core/personalidade.dart';
import '../ui_common.dart';
import 'personalidade_store.dart';

/// Escolha do nível de humor, com prévia do tom e aviso do que o app não faz.
class PersonalidadePage extends StatefulWidget {
  const PersonalidadePage({super.key, required this.store, this.inicial});

  final PersonalidadeStore store;
  final Personalidade? inicial;

  @override
  State<PersonalidadePage> createState() => _PersonalidadePageState();
}

class _PersonalidadePageState extends State<PersonalidadePage> {
  late NivelHumor nivel;
  bool salvando = false;

  @override
  void initState() {
    super.initState();
    nivel = (widget.inicial ?? widget.store.carregar()).nivel;
  }

  Future<void> _salvar() async {
    if (salvando) return;
    setState(() => salvando = true);
    final ok = await widget.store.salvar(Personalidade(nivel: nivel));
    if (!mounted) return;
    setState(() => salvando = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Personalidade salva: ${nivel.rotulo}. Vale para as próximas respostas.'
          : 'Não foi possível salvar a preferência neste aparelho.'),
    ));
  }

  String get _exemplo => switch (nivel) {
        NivelHumor.discreto =>
          'O erro está na alimentação do circuito. Corrija o terminal e teste novamente.',
        NivelHumor.equilibrado =>
          'O erro está na alimentação do circuito. Corrija o terminal — eletrônica tem dessas '
              'exigências.',
        NivelHumor.avancado =>
          'O erro está na alimentação do circuito. Sim, até os componentes precisam de energia; '
              'revolucionário, eu sei.',
      };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalidade e humor'),
        actions: [
          IconButton(
            tooltip: 'Salvar personalidade',
            onPressed: salvando ? null : _salvar,
            icon: salvando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('COMO O J.A.R.V.I.S. FALA', style: TextStyle(color: cyan, fontSize: 10, letterSpacing: 2)),
          const SizedBox(height: 8),
          const Text(
            'O nível vale para as respostas na conversa, digitada ou aberta pela voz. A informação '
            'vem sempre antes da graça, e a piada é com a situação — nunca com você.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.45),
          ),
          const SizedBox(height: 14),
          for (final opcao in NivelHumor.values)
            _cartao(opcao, colors),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: .35),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Prévia — ${nivel.rotulo}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                Text(_exemplo, style: const TextStyle(fontSize: 13, height: 1.45)),
                const SizedBox(height: 10),
                const Text(
                  'Em emergência, saúde, luto, violência, segurança ou dinheiro perdido, o humor é suspenso por completo, qualquer que seja o nível.',
                  style: TextStyle(color: Color(0xFFFFC66D), fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'O nível não muda a voz sintetizada, não autentica ninguém e não altera o que a IA pode '
            'fazer. Ele só ajusta o estilo das respostas.',
            style: TextStyle(color: muted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _cartao(NivelHumor opcao, ColorScheme colors) {
    final selecionado = opcao == nivel;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selecionado ? const Color(0xFF123047) : colors.surfaceContainerHighest.withValues(alpha: .25),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          key: ValueKey('nivel-${opcao.name}'),
          borderRadius: BorderRadius.circular(13),
          onTap: () => setState(() => nivel = opcao),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selecionado ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: selecionado ? cyan : muted,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(opcao.rotulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(opcao.descricao, style: const TextStyle(color: muted, fontSize: 11.5, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
