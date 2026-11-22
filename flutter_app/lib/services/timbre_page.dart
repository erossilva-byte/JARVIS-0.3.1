import 'package:material_ui/material_ui.dart';

import '../core/timbre_voz.dart';
import '../ui_common.dart';
import 'voz_jarvis.dart';

/// Tela dos perfis de timbre da voz: grave, natural e ágil.
///
/// O perfil é gravado no aparelho pelo canal nativo e vale para a voz da tela e
/// do segundo plano. “Ouvir exemplo” usa a mesma síntese da conversa, então o
/// que se ouve aqui é o que o JARVIS fala depois.
class TimbrePage extends StatefulWidget {
  const TimbrePage({super.key, this.voz = const VozJarvis()});

  final VozJarvis voz;

  @override
  State<TimbrePage> createState() => _TimbrePageState();
}

class _TimbrePageState extends State<TimbrePage> {
  String atual = timbrePadrao;
  String? erro;
  bool carregando = true;
  bool ocupado = false;
  bool aplicado = true;

  VozJarvis get voz => widget.voz;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final lido = await voz.timbreAtual();
      if (!mounted) return;
      setState(() {
        atual = timbreDe(lido).id;
        carregando = false;
        erro = null;
      });
    } on TimbreIndisponivel catch (falha) {
      if (!mounted) return;
      setState(() {
        carregando = false;
        erro = falha.mensagem;
      });
    }
  }

  Future<void> _escolher(PerfilTimbre perfil) async {
    if (ocupado || carregando) return;
    setState(() {
      ocupado = true;
      erro = null;
    });
    try {
      final resposta = await voz.definirTimbre(perfil.id);
      if (!mounted) return;
      setState(() {
        ocupado = false;
        atual = timbreDe(resposta.timbre).id;
        aplicado = resposta.aplicado;
      });
    } on TimbreIndisponivel catch (falha) {
      if (!mounted) return;
      setState(() {
        ocupado = false;
        erro = falha.mensagem;
      });
    }
  }

  Future<void> _ouvir() async {
    final falou = await voz.falar(fraseExemploTimbre);
    if (!mounted || falou) return;
    setState(() => erro =
        'A síntese de voz do Android não está disponível neste aparelho.');
  }

  @override
  Widget build(BuildContext context) {
    final escolhido = timbreDe(atual);
    return Scaffold(
      appBar:
          AppBar(title: const Text('Perfis de timbre', style: TextStyle(fontSize: 15))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _cartao(
            titulo: 'VOZ ATUAL',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  carregando
                      ? 'Lendo o timbre do aparelho…'
                      : resumoTimbre(escolhido),
                  key: const ValueKey('timbre-atual'),
                  style: const TextStyle(fontSize: 11.5, height: 1.45),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const ValueKey('timbre-ouvir'),
                  onPressed: carregando ? null : _ouvir,
                  icon: const Icon(Icons.volume_up_rounded, size: 18),
                  label: const Text('Ouvir exemplo',
                      style: TextStyle(fontSize: 10)),
                ),
                if (!carregando && !aplicado)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'O perfil ficou gravado, mas a síntese ainda não estava '
                      'pronta para aplicar agora; a próxima fala já usa o novo '
                      'timbre.',
                      key: ValueKey('timbre-aplicado'),
                      style: TextStyle(
                          fontSize: 10.5,
                          height: 1.4,
                          color: Color(0xFFFFC66D)),
                    ),
                  ),
                if (erro != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(erro!,
                        key: const ValueKey('timbre-erro'),
                        style: const TextStyle(
                            fontSize: 10.5,
                            height: 1.4,
                            color: Color(0xFFFFC66D))),
                  ),
              ],
            ),
          ),
          _cartao(
            titulo: 'ESCOLHA O TIMBRE',
            child: Column(
              children: [
                for (final perfil in perfisTimbre)
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      key: ValueKey('timbre-opcao-${perfil.id}'),
                      contentPadding: EdgeInsets.zero,
                      onTap: (carregando || ocupado)
                          ? null
                          : () => _escolher(perfil),
                      leading: Icon(
                        perfil.id == atual
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: perfil.id == atual ? cyan : muted,
                        size: 20,
                      ),
                      title: Text(perfil.nome,
                          style: const TextStyle(fontSize: 12.5)),
                      subtitle: Text(
                        'tom ${perfil.pitch.toStringAsFixed(2)} · ritmo '
                        '${perfil.velocidade.toStringAsFixed(2)} — '
                        '${perfil.descricao}',
                        style:
                            const TextStyle(fontSize: 10, color: muted),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _cartao(
            titulo: 'LIMITES',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final limite in limitesTimbre)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('· $limite',
                        style: const TextStyle(
                            fontSize: 10.5, color: muted, height: 1.4)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartao({required String titulo, required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: panel.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cyan.withValues(alpha: .18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: const TextStyle(
                    fontSize: 9.5,
                    letterSpacing: 1.3,
                    color: cyan,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
}
