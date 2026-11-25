import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/pareamento.dart';
import '../ui_common.dart';
import 'aparelho_service.dart';
import 'pareamento_service.dart';

/// Tela do pareamento com o PC.
///
/// O celular é quem mostra o código — o PC digita. A tela só declara “pareado”
/// quando o serviço recebeu a prova certa e guardou o token; antes disso ela
/// diz que está esperando.
class PareamentoPage extends StatefulWidget {
  const PareamentoPage({super.key, this.servico, this.enderecos});

  /// Injetáveis para teste; nulos usam o serviço e as interfaces reais.
  final PareamentoService? servico;
  final Future<List<String>> Function()? enderecos;

  @override
  State<PareamentoPage> createState() => _PareamentoPageState();
}

class _PareamentoPageState extends State<PareamentoPage> {
  late final PareamentoService servico =
      widget.servico ?? PareamentoService(status: _statusDoAparelho);
  late final Future<List<String>> Function() enderecos =
      widget.enderecos ?? PareamentoService.enderecosLocais;

  OfertaPareamento? oferta;
  List<String> ips = const [];
  String? erro;
  bool ocupado = false;
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    servico.aoMudar = () {
      if (mounted) setState(() {});
    };
    _carregarIps();
    _relogio = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (oferta != null && oferta!.expirou()) {
        setState(() => oferta = null);
      } else if (oferta != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _relogio?.cancel();
    servico.aoMudar = null;
    if (widget.servico == null) {
      // Só o serviço criado por esta tela é encerrado com ela.
      unawaited(servico.fechar());
    }
    super.dispose();
  }

  /// Status enviado ao PC pareado: só leitura do aparelho, sem inventar campo
  /// que o canal do Android não devolveu.
  Future<Map<String, Object?>> _statusDoAparelho() async {
    final dados = <String, Object?>{};
    try {
      final aparelho = AparelhoService();
      final info = await aparelho.infoDispositivo();
      if (info.bateria != null) dados['bateria'] = info.bateria;
      dados['carregando'] = info.carregando;
      if (info.memoriaTotalMb != null) {
        dados['ramTotal'] = info.memoriaTotalMb! * 1024 * 1024;
      }
      if (info.memoriaLivreMb != null) {
        dados['ramLivre'] = info.memoriaLivreMb! * 1024 * 1024;
      }
      if (info.armazenamentoTotalGb != null) {
        dados['discoTotal'] = (info.armazenamentoTotalGb! * 1073741824).round();
      }
      if (info.armazenamentoLivreGb != null) {
        dados['discoLivre'] = (info.armazenamentoLivreGb! * 1073741824).round();
      }
      if (info.uptimeMin != null) dados['uptimeMin'] = info.uptimeMin;
      if ((info.rede ?? '').isNotEmpty) dados['conexao'] = info.redeRotulo;
    } catch (_) {
      // Canal do aparelho ausente (teste, outra plataforma): o PC fica sem
      // esses campos em vez de receber número inventado.
    }
    try {
      final estado = await AparelhoService().status();
      final sistema = [
        estado.modelo,
        if (estado.android.isNotEmpty) 'Android ${estado.android}',
      ].where((parte) => parte.isNotEmpty).join(' · ');
      if (sistema.isNotEmpty) dados['sistema'] = sistema;
    } catch (_) {
      // idem: sem modelo, o campo não vai.
    }
    return dados;
  }

  Future<void> _carregarIps() async {
    try {
      final lista = await enderecos();
      if (!mounted) return;
      setState(() => ips = lista);
    } catch (_) {
      if (!mounted) return;
      setState(() => ips = const []);
    }
  }

  Future<void> _abrir() async {
    setState(() {
      ocupado = true;
      erro = null;
    });
    try {
      final nova = await servico.abrirOferta();
      if (!mounted) return;
      setState(() {
        oferta = nova;
        ocupado = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        ocupado = false;
        erro = 'Não consegui abrir o canal nesta rede. Confira se o Wi-Fi está ligado. '
            '(${e.runtimeType})';
      });
    }
  }

  Future<void> _encerrar() async {
    await servico.fechar();
    if (!mounted) return;
    setState(() => oferta = null);
  }

  Future<void> _esquecer() async {
    servico.esquecer();
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Pareamento com o PC',
              style: TextStyle(fontSize: 15))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _cartao(
            titulo: 'ESTADO',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  servico.pareado
                      ? 'Pareado com ${servico.registro!.dispositivo}.'
                      : oferta == null
                          ? 'Nenhum PC pareado. Abra o pareamento para mostrar o código.'
                          : 'Esperando o PC digitar o código.',
                  key: const ValueKey('pareamento-estado'),
                  style: const TextStyle(fontSize: 11.5, height: 1.45),
                ),
                if (erro != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(erro!,
                        key: const ValueKey('pareamento-erro'),
                        style: const TextStyle(
                            fontSize: 10.5,
                            height: 1.4,
                            color: Color(0xFFFFC66D))),
                  ),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton.icon(
                    key: const ValueKey('pareamento-abrir'),
                    onPressed: ocupado ? null : _abrir,
                    icon: const Icon(Icons.wifi_tethering_rounded, size: 18),
                    label: Text(oferta == null ? 'Abrir pareamento' : 'Gerar novo código',
                        style: const TextStyle(fontSize: 10)),
                  ),
                  if (oferta != null)
                    OutlinedButton(
                      key: const ValueKey('pareamento-encerrar'),
                      onPressed: _encerrar,
                      child: const Text('Fechar canal',
                          style: TextStyle(fontSize: 10)),
                    ),
                  if (servico.pareado)
                    OutlinedButton(
                      key: const ValueKey('pareamento-esquecer'),
                      onPressed: _esquecer,
                      child: const Text('Esquecer este PC',
                          style: TextStyle(fontSize: 10)),
                    ),
                ]),
              ],
            ),
          ),
          if (oferta != null)
            _cartao(
              titulo: 'CÓDIGO PARA DIGITAR NO PC',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatarCodigoPareamento(oferta!.codigo),
                    key: const ValueKey('pareamento-codigo'),
                    style: const TextStyle(
                        fontSize: 34,
                        letterSpacing: 6,
                        fontWeight: FontWeight.w500,
                        color: cyan),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Vale por ${oferta!.segundosRestantes()} s · '
                    '${oferta!.tentativasRestantes} tentativa(s).',
                    key: const ValueKey('pareamento-validade'),
                    style: const TextStyle(fontSize: 10.5, color: muted),
                  ),
                ],
              ),
            ),
          _cartao(
            titulo: 'ENDEREÇO DESTE CELULAR',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ips.isEmpty)
                  const Text(
                    'Nenhum endereço IPv4 de rede local encontrado. Confira se o Wi-Fi está ligado.',
                    key: ValueKey('pareamento-enderecos'),
                    style: TextStyle(fontSize: 10.5, height: 1.4),
                  )
                else
                  for (final ip in ips)
                    Text('$ip:${servico.portaAtual}',
                        key: ValueKey('pareamento-endereco-$ip'),
                        style: const TextStyle(
                            fontSize: 12, height: 1.5, color: cyan)),
                const SizedBox(height: 8),
                const Text(
                  'Digite este endereço e o código na seção “Status do celular” do JARVIS no PC. '
                  'Nada disso sai da rede local.',
                  style: TextStyle(fontSize: 10.5, color: muted, height: 1.4),
                ),
              ],
            ),
          ),
          _cartao(
            titulo: 'O QUE ESTE CANAL FAZ',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('· O PC lê o status do celular (bateria, memória, disco, rede).',
                    style: TextStyle(fontSize: 10.5, height: 1.4)),
                Text('· Nenhum comando é aceito nesta etapa: só leitura.',
                    style: TextStyle(fontSize: 10.5, height: 1.4)),
                Text('· O código de 6 dígitos vale uma vez e expira em 2 minutos.',
                    style: TextStyle(fontSize: 10.5, height: 1.4)),
                Text('· Cinco erros fecham a oferta; o token pode ser revogado a qualquer hora.',
                    style: TextStyle(fontSize: 10.5, height: 1.4)),
                Text('· Sem TLS: use em rede local de confiança. O código viaja só como prova HMAC.',
                    key: ValueKey('pareamento-limites'),
                    style: TextStyle(fontSize: 10.5, height: 1.4, color: muted)),
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
