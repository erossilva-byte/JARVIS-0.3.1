import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/aparelho.dart';
import '../core/clima.dart';
import '../core/dispositivo.dart';
import '../ui_common.dart';
import 'aparelho_service.dart';
import 'clima_service.dart';
import 'dispositivo_page.dart';
import 'localizacao_service.dart';

/// Cartão resumido do celular na tela inicial.
///
/// Mostra só o que o Android respondeu: bateria, rede, armazenamento, memória e
/// a temperatura do lugar onde o aparelho está. Toque abre a Central do
/// aparelho com tudo (notificações, localização, apps). Nada é inventado: o que
/// não veio aparece como “—”, e o cartão nunca pede permissão sozinho.
class CartaoAparelho extends StatefulWidget {
  const CartaoAparelho({super.key, this.servico, this.clima});

  final AparelhoService? servico;
  final ClimaService? clima;

  @override
  State<CartaoAparelho> createState() => _CartaoAparelhoState();
}

class _CartaoAparelhoState extends State<CartaoAparelho> {
  late final AparelhoService _servico = widget.servico ?? AparelhoService();
  late final ClimaService _clima = widget.clima ?? ClimaService();

  InfoDispositivo? info;
  ClimaAgora? clima;
  String lugar = '';
  bool acessoNotificacoes = false;
  int notificacoes = 0;
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    unawaited(_carregar());
  }

  Future<void> _carregar() async {
    try {
      final dados = await _servico.infoDispositivo();
      if (mounted) setState(() => info = dados);
    } catch (_) {
      // Fora do Android o cartão fica só com o que o clima conseguiu mostrar.
    }
    try {
      final acesso = await _servico.temAcessoNotificacoes();
      var lista = const <NotificacaoAparelho>[];
      if (acesso) {
        lista = await _servico.notificacoes(limite: 30);
        if (lista.isEmpty) {
          // Acesso autorizado mas serviço sem conexão: pede a releitura.
          try {
            await _servico.reconectarNotificacoes();
            lista = await _servico.notificacoes(limite: 30);
          } catch (_) {}
        }
      }
      if (!mounted) return;
      setState(() {
        acessoNotificacoes = acesso;
        notificacoes = lista.length;
      });
    } catch (_) {}
    try {
      final local = await LocalizacaoService().ultima(exigirValidade: false);
      final achado = await _clima.atual();
      if (!mounted) return;
      setState(() {
        clima = achado.clima;
        lugar = achado.lugar.trim().isEmpty
            ? (local?.endereco ?? '')
            : achado.lugar;
      });
    } catch (_) {
      // Sem permissão de localização ou sem rede: sem temperatura.
    }
    if (mounted) setState(() => carregando = false);
  }

  Future<void> _abrir() async {
    await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const DispositivoPage()));
    if (mounted) unawaited(_carregar());
  }

  @override
  Widget build(BuildContext context) {
    final dados = info;
    final bateria = dados?.bateria;
    final livre = dados?.armazenamentoLivreGb;
    return Material(
      key: const ValueKey('cartao-aparelho'),
      color: panel,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: _abrir,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.phone_android_rounded, color: cyan, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('ESTE CELULAR',
                      style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700)),
                ),
                if (carregando)
                  const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.6))
                else
                  Text('STATUS',
                      style: TextStyle(
                          fontSize: 8,
                          letterSpacing: 1,
                          color: cyan.withValues(alpha: .8))),
              ]),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _chip(
                    Icons.battery_5_bar_rounded,
                    bateria == null
                        ? 'Bateria —'
                        : '$bateria%${dados!.carregando ? ' ⚡' : ''}',
                  ),
                  _chip(Icons.wifi_rounded, dados?.redeRotulo ?? 'Rede —'),
                  _chip(
                    Icons.sd_storage_rounded,
                    livre == null
                        ? 'Disco —'
                        : '${livre.toStringAsFixed(1)} GB livres',
                  ),
                  _chip(
                    Icons.memory_rounded,
                    dados?.temMemoria == true
                        ? '${dados!.memoriaLivreMb} MB RAM'
                        : 'RAM —',
                  ),
                  _chip(
                    acessoNotificacoes
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_off_rounded,
                    acessoNotificacoes
                        ? '$notificacoes notificação(ões)'
                        : 'Sem acesso a notificações',
                    alerta: !acessoNotificacoes,
                  ),
                  if (clima != null)
                    _chip(
                      Icons.thermostat_rounded,
                      '${clima!.temperaturaRotulo}${lugar.isEmpty ? '' : ' · $lugar'}',
                    ),
                ],
              ),
              const SizedBox(height: 9),
              const Text(
                'Toque para abrir a Central do aparelho: notificações, localização e apps.',
                style: TextStyle(color: muted, fontSize: 9.5, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icone, String texto, {bool alerta = false}) {
    final cor = alerta ? const Color(0xFFFFC66D) : cyan;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: .22)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icone, size: 13, color: cor),
        const SizedBox(width: 5),
        Text(texto, style: const TextStyle(fontSize: 10)),
      ]),
    );
  }
}
