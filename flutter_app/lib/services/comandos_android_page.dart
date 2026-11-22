import 'package:material_ui/material_ui.dart';

import '../core/comandos_android.dart';
import '../ui_common.dart';
import 'comandos_android_service.dart';
import 'historico_voz_page.dart';

class ComandosAndroidPage extends StatefulWidget {
  const ComandosAndroidPage({
    super.key,
    this.executor,
    this.ativo = true,
  });

  final ExecutorComandosAndroid? executor;
  final bool ativo;

  @override
  State<ComandosAndroidPage> createState() => _ComandosAndroidPageState();
}

class _ComandosAndroidPageState extends State<ComandosAndroidPage> {
  final campo = TextEditingController();
  ResultadoComando? resultado;
  bool executando = false;

  @override
  void dispose() {
    campo.dispose();
    super.dispose();
  }

  Future<void> _executar([String? texto]) async {
    final pedido = (texto ?? campo.text).trim();
    if (pedido.isEmpty || executando) return;
    setState(() {
      executando = true;
      resultado = null;
    });
    final resposta =
        await (widget.executor ?? ExecutorComandosAndroid(ativo: widget.ativo))
            .executar(pedido);
    if (!mounted) return;
    setState(() {
      executando = false;
      resultado = resposta ??
          const ResultadoComando(
              ok: false,
              mensagem:
                  'Esse texto não é um comando de dispositivo reconhecido. Ele continua indo para a conversa normal.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Comandos do Android',
              style: TextStyle(fontSize: 15)),
          actions: [
            IconButton(
              key: const ValueKey('abrir-historico-voz'),
              tooltip: 'Histórico do que foi executado',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const HistoricoVozPage()),
              ),
              icon: const Icon(Icons.history_rounded),
            ),
          ]),
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
                Text('AÇÕES LOCAIS VERIFICADAS',
                    style: TextStyle(
                        color: cyan,
                        fontSize: 9,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text(
                  'Estes comandos são interpretados no aparelho, sem enviar o pedido a um provedor de IA. Depois de agir, o Jarvis lê o estado real e só então confirma.',
                  style: TextStyle(color: muted, fontSize: 11, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('comando-android-campo'),
            controller: campo,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _executar(),
            decoration: InputDecoration(
              hintText: 'Ex.: ligar a lanterna, volume 50, abrir WhatsApp',
              filled: true,
              fillColor: panel,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 9),
          FilledButton.icon(
            key: const ValueKey('executar-comando-android'),
            onPressed: executando ? null : _executar,
            icon: executando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow_rounded),
            label: Text(executando ? 'Executando…' : 'Executar comando'),
          ),
          if (resultado != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: resultado!.ok
                    ? const Color(0xFF0D2118)
                    : const Color(0xFF211A10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: (resultado!.ok
                            ? const Color(0xFF65D49A)
                            : const Color(0xFFFFC66D))
                        .withValues(alpha: .3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                      resultado!.ok
                          ? Icons.check_circle_outline_rounded
                          : Icons.info_outline_rounded,
                      color: resultado!.ok
                          ? const Color(0xFF65D49A)
                          : const Color(0xFFFFC66D),
                      size: 19),
                  const SizedBox(width: 9),
                  Expanded(
                      child: Text(resultado!.mensagem,
                          style:
                              const TextStyle(fontSize: 11.5, height: 1.45))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text('EXEMPLOS RÁPIDOS',
              style: TextStyle(
                  color: cyan,
                  fontSize: 9,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 7, runSpacing: 7, children: [
            for (final acao in acoesAndroid)
              ActionChip(
                label: Text(acao.exemplo, style: const TextStyle(fontSize: 10)),
                backgroundColor: panel,
                side: const BorderSide(color: Colors.white12),
                onPressed: () {
                  campo.text = acao.exemplo;
                  _executar(acao.exemplo);
                },
              ),
          ]),
          const SizedBox(height: 18),
          const Text('REGISTRO DE AÇÕES',
              style: TextStyle(
                  color: cyan,
                  fontSize: 9,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final acao in acoesAndroid)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(acao.nome,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  Text(acao.descricao,
                      style: const TextStyle(
                          color: muted, fontSize: 10.5, height: 1.4)),
                  Text('risco: ${acao.risco.name} · ${acao.permissao}',
                      style: const TextStyle(
                          color: Color(0xFF63798B), fontSize: 9, height: 1.4)),
                ],
              ),
            ),
          const SizedBox(height: 14),
          const Text(
            'Limites reais: fechar outros apps, alternar Wi-Fi/dados, bloquear a tela e enviar SMS/ligações não estão nesta etapa. Nada de root, ADB, Shizuku ou permissão de todos os arquivos.',
            style: TextStyle(color: muted, fontSize: 10, height: 1.5),
          ),
        ],
      ),
    );
  }
}
