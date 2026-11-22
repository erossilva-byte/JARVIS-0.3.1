import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/historico_voz.dart';
import '../ui_common.dart';
import 'historico_voz_service.dart';

/// Mostra o que o JARVIS executou, com horário e resultado real.
///
/// A lista vem do aparelho: o mesmo registro alimentado pelo comando falado com a
/// tela aberta e pelo comando executado em segundo plano. Nada é inventado aqui —
/// quando o Android não confirmou, a linha aparece como "Não executado" com a
/// resposta recebida.
class HistoricoVozPage extends StatefulWidget {
  const HistoricoVozPage({super.key, this.gateway});

  final HistoricoVozGateway? gateway;

  @override
  State<HistoricoVozPage> createState() => _HistoricoVozPageState();
}

class _HistoricoVozPageState extends State<HistoricoVozPage> {
  late final HistoricoVozGateway _gateway =
      widget.gateway ?? HistoricoVozService();

  List<RegistroExecucao> registros = const [];
  bool carregando = true;
  bool limpando = false;

  @override
  void initState() {
    super.initState();
    unawaited(_carregar());
  }

  Future<void> _carregar() async {
    if (mounted) setState(() => carregando = true);
    final lista = await _gateway.carregar();
    if (!mounted) return;
    setState(() {
      registros = lista;
      carregando = false;
    });
  }

  Future<void> _limpar() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Limpar o histórico?'),
        content: const Text(
            'Todos os registros de comandos executados neste aparelho serão apagados. '
            'A conversa não é afetada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('confirmar-limpar-historico-voz'),
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;
    setState(() => limpando = true);
    final apagou = await _gateway.limpar();
    if (!mounted) return;
    setState(() {
      limpando = false;
      if (apagou) registros = const [];
    });
    if (!apagou) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('O Android não confirmou a limpeza do histórico.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final agora = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de execuções',
            style: TextStyle(fontSize: 15)),
        actions: [
          IconButton(
            key: const ValueKey('atualizar-historico-voz'),
            tooltip: 'Atualizar histórico',
            onPressed: carregando ? null : _carregar,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cyan.withValues(alpha: .2)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('O QUE FOI EXECUTADO NO APARELHO',
                    style: TextStyle(
                        color: cyan,
                        fontSize: 9,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text(
                  'Cada comando que o JARVIS executou aparece aqui com o horário e o resultado '
                  'lido do Android. Comando falado com o app aberto e comando executado em '
                  'segundo plano entram na mesma lista.',
                  style: TextStyle(color: muted, fontSize: 11, height: 1.45),
                ),
                SizedBox(height: 6),
                Text(
                  'Fica guardado só neste aparelho, até 100 registros. O áudio não é gravado '
                  'e nada é enviado para a nuvem.',
                  style: TextStyle(color: Color(0xFF63798B), fontSize: 10, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (carregando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            ),
          if (!carregando && registros.isEmpty)
            Container(
              key: const ValueKey('historico-voz-vazio'),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: .22),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.history_toggle_off_rounded, color: muted, size: 24),
                  SizedBox(height: 8),
                  Text('Nenhum comando executado ainda',
                      style:
                          TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  SizedBox(height: 5),
                  Text(
                    'Fale “Jarvis” e peça algo como “abrir WhatsApp”, “lanterna” ou '
                    '“volume 30”. O resultado aparece aqui depois da execução.',
                    style: TextStyle(color: muted, fontSize: 11, height: 1.4),
                  ),
                ],
              ),
            ),
          if (!carregando && registros.isNotEmpty) ...[
            Text(resumoExecucoes(registros),
                key: const ValueKey('resumo-historico-voz'),
                style: const TextStyle(
                    color: cyan, fontSize: 10.5, letterSpacing: .4)),
            const SizedBox(height: 6),
            for (final item in _agrupados(agora)) ...[
              if (item.dia != null) ...[
                const SizedBox(height: 10),
                Text(item.dia!.toUpperCase(),
                    style: const TextStyle(
                        color: muted,
                        fontSize: 9,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
              ],
              _cartao(item.registro, item.indice),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('limpar-historico-voz'),
              onPressed: limpando ? null : _limpar,
              icon: limpando
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Limpar histórico deste aparelho'),
            ),
          ],
        ],
      ),
    );
  }

  /// Junta os registros do mesmo dia e marca o primeiro de cada grupo.
  List<_LinhaHistorico> _agrupados(DateTime agora) {
    final linhas = <_LinhaHistorico>[];
    String? diaAnterior;
    for (var i = 0; i < registros.length; i++) {
      final registro = registros[i];
      final dia = diaRotulo(registro.em, agora);
      linhas.add(_LinhaHistorico(
        registro: registro,
        indice: i,
        dia: dia == diaAnterior ? null : dia,
      ));
      diaAnterior = dia;
    }
    return linhas;
  }

  Widget _cartao(RegistroExecucao registro, int indice) {
    final cor = registro.ok ? const Color(0xFF65D49A) : const Color(0xFFFFC66D);
    return Container(
      key: ValueKey('historico-voz-item-$indice'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  registro.resultadoRotulo,
                  style: TextStyle(
                      color: cor, fontSize: 9.5, fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              Text(registro.hora,
                  style: const TextStyle(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 7),
          Text(registro.titulo,
              style:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          if (registro.pedido != registro.titulo) ...[
            const SizedBox(height: 3),
            Text('Pedido: “${registro.pedido}”',
                style: const TextStyle(color: muted, fontSize: 10.5)),
          ],
          if (registro.mensagem.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(registro.mensagem,
                style: const TextStyle(fontSize: 11, height: 1.4)),
          ],
          const SizedBox(height: 5),
          Text(
            '${registro.origem.rotulo} · ${diaRotulo(registro.em, DateTime.now())}',
            style: const TextStyle(color: Color(0xFF63798B), fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}

class _LinhaHistorico {
  const _LinhaHistorico({
    required this.registro,
    required this.indice,
    this.dia,
  });

  final RegistroExecucao registro;
  final int indice;
  final String? dia;
}
