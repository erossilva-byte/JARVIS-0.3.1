import 'package:material_ui/material_ui.dart';

import '../core/acessibilidade.dart';
import '../ui_common.dart';
import 'acessibilidade_service.dart';

/// Tela da automação por acessibilidade: consentimento, estado real e um campo
/// para pedir leitura, toque ou rolagem.
class AcessibilidadePage extends StatefulWidget {
  const AcessibilidadePage({super.key, this.servico});

  final AcessibilidadeService? servico;

  @override
  State<AcessibilidadePage> createState() => _AcessibilidadePageState();
}

class _AcessibilidadePageState extends State<AcessibilidadePage> {
  final campo = TextEditingController();
  late final AcessibilidadeService servico =
      widget.servico ?? AcessibilidadeService();

  bool consentido = false;
  EstadoAcessibilidade? estado;
  ResultadoTela? resultado;
  bool carregando = true;
  bool executando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    campo.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final novoEstado = await servico.status();
    if (!mounted) return;
    setState(() {
      consentido = novoEstado.consentimento;
      estado = novoEstado;
      carregando = false;
    });
  }

  Future<void> _alternar(bool valor) async {
    await servico.definirConsentimento(valor);
    if (!mounted) return;
    setState(() {
      consentido = valor;
      resultado = ResultadoTela(
        ok: valor,
        mensagem: valor
            ? 'Automação de tela ligada neste app. '
                'O serviço do Android ainda precisa estar autorizado.'
            : 'Automação de tela desligada. Nada será lido nem tocado.',
      );
    });
    await _carregar();
  }

  Future<void> _executar() async {
    final pedido = campo.text.trim();
    if (pedido.isEmpty || executando) return;
    final comando = InterpretadorTela.interpretar(pedido);
    if (comando == null) {
      setState(() {
        resultado = const ResultadoTela(
          ok: false,
          mensagem: 'Esse texto não é um comando de tela. '
              'Use “ler a tela”, “tocar em Enviar” ou “rolar para baixo”.',
        );
      });
      return;
    }
    setState(() {
      executando = true;
      resultado = null;
    });
    final resposta = await servico.executar(comando);
    if (!mounted) return;
    setState(() {
      executando = false;
      resultado = resposta;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ligadoNoAndroid = estado?.servicoLigado == true;
    return Scaffold(
      appBar: AppBar(
          title: const Text('Acessibilidade de tela',
              style: TextStyle(fontSize: 15))),
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
                Text('ESCOPO ESTREITO',
                    style: TextStyle(
                        color: cyan,
                        fontSize: 9,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text(
                  'Com a sua autorização, o JARVIS lê os textos visíveis da tela, '
                  'toca num botão pelo texto e rola a tela. Ele não digita nada, não '
                  'lê campos de senha nem o que você escreveu, e não age com o '
                  'interruptor abaixo desligado.',
                  style: TextStyle(color: muted, fontSize: 11, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ler a tela e tocar por mim',
                    style: TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  consentido
                      ? 'Ligado neste app. O JARVIS só age quando você pede.'
                      : 'Desligado. Nenhuma ação de tela é executada.',
                  style: const TextStyle(color: muted, fontSize: 10, height: 1.4),
                ),
                Row(
                  children: [
                    Switch(
                      key: const ValueKey('acessibilidade-ativar'),
                      value: consentido,
                      onChanged: _alternar,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text('Autorizo a leitura da tela',
                          style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            key: const ValueKey('acessibilidade-status'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: (ligadoNoAndroid && consentido)
                      ? cyan.withValues(alpha: .35)
                      : Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ligadoNoAndroid
                      ? 'Serviço do Android: autorizado'
                      : 'Serviço do Android: desligado',
                  style: TextStyle(
                      fontSize: 12,
                      color: ligadoNoAndroid ? cyan : const Color(0xFFFFB86B)),
                ),
                const SizedBox(height: 5),
                Text(
                  ligadoNoAndroid
                      ? 'A leitura só acontece com o interruptor acima ligado.'
                      : 'Sem o serviço autorizado, o Android não entrega o conteúdo '
                          'da tela. Abra as configurações e procure “JARVIS Nova”.',
                  style: const TextStyle(color: muted, fontSize: 10, height: 1.4),
                ),
                if (carregando)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Conferindo o serviço…',
                        style: TextStyle(color: muted, fontSize: 9)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          OutlinedButton.icon(
            key: const ValueKey('abrir-acessibilidade-android'),
            onPressed: () => servico.abrirConfiguracoes(),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Abrir Acessibilidade do Android'),
          ),
          const SizedBox(height: 18),
          TextField(
            key: const ValueKey('acessibilidade-campo'),
            controller: campo,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _executar(),
            decoration: InputDecoration(
              hintText: 'Ex.: ler a tela, tocar em Enviar, rolar para baixo',
              filled: true,
              fillColor: panel,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 9),
          FilledButton.icon(
            key: const ValueKey('executar-acessibilidade'),
            onPressed: executando ? null : _executar,
            icon: executando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.touch_app_rounded, size: 18),
            label: Text(executando ? 'Executando…' : 'Executar'),
          ),
          if (resultado != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: resultado!.ok
                    ? cyan.withValues(alpha: .08)
                    : const Color(0xFFFFB86B).withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: resultado!.ok
                        ? cyan.withValues(alpha: .3)
                        : const Color(0xFFFFB86B).withValues(alpha: .3)),
              ),
              child: Text(
                resultado!.mensagem,
                key: const ValueKey('acessibilidade-resultado'),
                style: const TextStyle(fontSize: 11, height: 1.45),
              ),
            ),
          ],
          if (resultado != null && resultado!.elementos.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('O QUE A TELA MOSTROU',
                style: TextStyle(
                    color: cyan,
                    fontSize: 9,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final elemento in resultado!.elementos.take(20))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${elemento.campo ? '▪' : '·'} ${elemento.texto}',
                  style: const TextStyle(color: muted, fontSize: 10),
                ),
              ),
          ],
          const SizedBox(height: 18),
          const Text(
            'Limite honesto: apps de banco e alguns apps de mensagem bloqueiam a '
            'leitura da tela. Nesse caso o Android devolve pouco ou nada, e o '
            'JARVIS diz que não encontrou — em vez de fingir que agiu.',
            style: TextStyle(color: Color(0xFF63798B), fontSize: 9, height: 1.5),
          ),
        ],
      ),
    );
  }
}
