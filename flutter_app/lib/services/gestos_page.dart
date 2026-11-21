import 'package:material_ui/material_ui.dart';

import '../core/gestos.dart';
import '../ui_common.dart';
import 'sensores_service.dart';

/// Tela dos gestos com o aparelho: virar para calar e modo noturno.
///
/// Mostra o estado real lido do Android e só diz “ligado” depois que o canal
/// confirma. O brilho é aplicado na janela do app; o sensor só fica ativo com a
/// tela na frente.
class GestosPage extends StatefulWidget {
  const GestosPage({super.key, this.servico});

  /// Injetável para teste; nulo usa o canal do aparelho.
  final SensoresService? servico;

  @override
  State<GestosPage> createState() => _GestosPageState();
}

class _GestosPageState extends State<GestosPage> {
  late final SensoresService servico = widget.servico ?? const SensoresService();

  EstadoGestos estado = EstadoGestos.vazio;
  String? erro;
  bool carregando = true;
  int brilhoLocal = brilhoPadraoGestos;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final lido = await servico.estado();
      if (!mounted) return;
      setState(() {
        estado = lido;
        brilhoLocal = lido.brilho;
        carregando = false;
        erro = null;
      });
    } on SensoresIndisponivel catch (falha) {
      if (!mounted) return;
      setState(() {
        carregando = false;
        erro = falha.mensagem;
      });
    }
  }

  Future<void> _aplicar(
      Future<EstadoGestos> Function() acao) async {
    try {
      final novo = await acao();
      if (!mounted) return;
      setState(() {
        estado = novo;
        brilhoLocal = novo.brilho;
        erro = null;
      });
    } on SensoresIndisponivel catch (falha) {
      if (!mounted) return;
      setState(() => erro = falha.mensagem);
    }
  }

  Future<void> _calarAgora() async {
    final calou = await servico.calar();
    if (!mounted) return;
    setState(() => erro = calou
        ? null
        : 'O canal do aparelho não confirmou o silenciamento.');
  }

  @override
  Widget build(BuildContext context) {
    final semSensor = !estado.temAcelerometro;
    return Scaffold(
      appBar: AppBar(
          title: const Text('Gestos e modo noturno',
              style: TextStyle(fontSize: 15))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _cartao(
            titulo: 'ESTADO NO APARELHO',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  carregando ? 'Lendo os sensores…' : resumoGestos(estado),
                  key: const ValueKey('gestos-status'),
                  style: const TextStyle(fontSize: 11.5, height: 1.45),
                ),
                if (erro != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(erro!,
                        key: const ValueKey('gestos-erro'),
                        style: const TextStyle(
                            fontSize: 10.5,
                            height: 1.4,
                            color: Color(0xFFFFC66D))),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const ValueKey('gestos-calaram'),
                  onPressed: carregando ? null : _calarAgora,
                  icon: const Icon(Icons.volume_off_rounded, size: 18),
                  label: const Text('Calar agora',
                      style: TextStyle(fontSize: 10)),
                ),
              ],
            ),
          ),
          _cartao(
            titulo: 'VIRAR PARA CALAR',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                  key: const ValueKey('gestos-calar'),
                  contentPadding: EdgeInsets.zero,
                  value: estado.calarAoVirar,
                  onChanged: (semSensor || carregando)
                      ? null
                      : (ativo) =>
                          _aplicar(() => servico.definirCalarAoVirar(ativo)),
                  title: const Text('Calar ao virar o celular para baixo',
                      style: TextStyle(fontSize: 12)),
                  subtitle: Text(
                    semSensor
                        ? 'Sem acelerômetro neste aparelho.'
                        : 'Para a fala na hora; a resposta escrita continua.',
                    style: const TextStyle(fontSize: 10, color: muted),
                  ),
                  ),
                ),
              ],
            ),
          ),
          _cartao(
            titulo: 'MODO NOTURNO',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                  key: const ValueKey('gestos-noturno'),
                  contentPadding: EdgeInsets.zero,
                  value: estado.modoNoturno,
                  onChanged: carregando
                      ? null
                      : (ativo) =>
                          _aplicar(() => servico.definirModoNoturno(ativo)),
                  title: const Text('Brilho baixo e voz mais suave',
                      style: TextStyle(fontSize: 12)),
                  subtitle: const Text(
                    'Vale só na janela do JARVIS; a voz sai em 45% do volume.',
                    style: TextStyle(fontSize: 10, color: muted),
                  ),
                  ),
                ),
                Text('Brilho: $brilhoLocal%',
                    key: const ValueKey('gestos-brilho-valor'),
                    style: const TextStyle(fontSize: 11)),
                Slider(
                  key: const ValueKey('gestos-brilho'),
                  value: brilhoLocal.toDouble().clamp(
                      brilhoMinimoGestos.toDouble(),
                      brilhoMaximoGestos.toDouble()),
                  min: brilhoMinimoGestos.toDouble(),
                  max: brilhoMaximoGestos.toDouble(),
                  divisions:
                      (brilhoMaximoGestos - brilhoMinimoGestos) ~/ 10,
                  label: '$brilhoLocal%',
                  onChanged: estado.modoNoturno
                      ? (valor) => setState(() => brilhoLocal = valor.round())
                      : null,
                  onChangeEnd: estado.modoNoturno
                      ? (valor) =>
                          _aplicar(() => servico.definirBrilho(valor.round()))
                      : null,
                ),
              ],
            ),
          ),
          _cartao(
            titulo: 'LIMITES',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final limite in limitesGestos)
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
