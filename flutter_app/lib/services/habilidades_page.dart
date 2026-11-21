import 'package:material_ui/material_ui.dart';

import '../core/habilidades.dart';
import '../ui_common.dart';
import 'habilidades_service.dart';

/// Tela das habilidades em Markdown carregadas do aparelho.
///
/// Mostra o que foi lido, de onde veio e quais gatilhos ativam cada
/// procedimento. O JARVIS só usa a habilidade quando a pergunta casa com um
/// gatilho; fora disso, nada entra no pedido ao provedor.
class HabilidadesPage extends StatefulWidget {
  const HabilidadesPage({super.key, this.servico});

  final HabilidadesService? servico;

  @override
  State<HabilidadesPage> createState() => _HabilidadesPageState();
}

class _HabilidadesPageState extends State<HabilidadesPage> {
  late final HabilidadesService servico =
      widget.servico ?? const HabilidadesService();

  ResultadoHabilidades? resultado;
  String? avisoExemplo;
  bool ocupado = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    if (ocupado) return;
    setState(() => ocupado = true);
    ResultadoHabilidades carregado;
    try {
      carregado = await servico.carregar();
    } catch (_) {
      carregado = const ResultadoHabilidades(
          aviso: 'Não foi possível ler as habilidades neste aparelho.');
    }
    if (!mounted) return;
    setState(() {
      ocupado = false;
      resultado = carregado;
    });
  }

  Future<void> _criarExemplo() async {
    if (ocupado) return;
    setState(() {
      ocupado = true;
      avisoExemplo = null;
    });
    final resposta = await servico.criarExemplo();
    if (!mounted) return;
    setState(() {
      ocupado = false;
      avisoExemplo = resposta.mensagem;
    });
    if (resposta.ok) await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final carregado = resultado;
    final habilidades = carregado?.habilidades ?? const <Habilidade>[];
    return Scaffold(
      appBar: AppBar(
          title: const Text('Habilidades em Markdown',
              style: TextStyle(fontSize: 15))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _cartao(
            titulo: 'COMO FUNCIONA',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cada habilidade é um arquivo .md dentro de uma pasta Skills/ '
                  'ou Habilidades/. O cabeçalho (frontmatter) traz o nome e os '
                  'gatilhos; o corpo é o passo a passo. O JARVIS carrega do '
                  'próprio aparelho e só usa a habilidade quando a sua pergunta '
                  'casa com um gatilho.',
                  style: TextStyle(fontSize: 11, height: 1.45, color: muted),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  exemploHabilidade.trim(),
                  key: const ValueKey('habilidades-exemplo-formato'),
                  style: const TextStyle(fontSize: 10, height: 1.4),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton.icon(
                    key: const ValueKey('habilidades-atualizar'),
                    onPressed: ocupado ? null : _carregar,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Ler de novo',
                        style: TextStyle(fontSize: 10)),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('habilidades-criar-exemplo'),
                    onPressed: ocupado ? null : _criarExemplo,
                    icon: const Icon(Icons.note_add_outlined, size: 18),
                    label: const Text('Criar exemplo no aparelho',
                        style: TextStyle(fontSize: 10)),
                  ),
                ]),
                if (avisoExemplo != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(avisoExemplo!,
                        key: const ValueKey('habilidades-aviso-exemplo'),
                        style: const TextStyle(
                            fontSize: 10.5,
                            height: 1.4,
                            color: Color(0xFFFFC66D))),
                  ),
              ],
            ),
          ),
          _cartao(
            titulo: 'CARREGADAS DO APARELHO',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  carregado == null
                      ? 'Lendo…'
                      : carregado.pastaNome.isEmpty
                          ? 'Origem: pasta local do app (nenhuma pasta do '
                              'Obsidian conectada).'
                          : 'Origem: pasta ${carregado.pastaNome} · '
                              '${carregado.lidas} arquivo(s) lido(s).',
                  key: const ValueKey('habilidades-origem'),
                  style: const TextStyle(fontSize: 11, color: muted, height: 1.4),
                ),
                if (carregado != null && carregado.aviso.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(carregado.aviso,
                        key: const ValueKey('habilidades-aviso'),
                        style: const TextStyle(
                            fontSize: 10.5,
                            height: 1.4,
                            color: Color(0xFFFFC66D))),
                  ),
                if (habilidades.isEmpty && carregado != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Nenhuma habilidade carregada ainda.',
                        key: ValueKey('habilidades-vazio'),
                        style: TextStyle(fontSize: 10.5, color: muted)),
                  ),
                for (var i = 0; i < habilidades.length; i++) ...[
                  const SizedBox(height: 10),
                  Container(
                    key: ValueKey('habilidade-$i'),
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: panel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cyan.withValues(alpha: .22)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(habilidades[i].nome,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                        if (habilidades[i].descricao.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(habilidades[i].descricao,
                                style: const TextStyle(
                                    fontSize: 10.5,
                                    color: muted,
                                    height: 1.4)),
                          ),
                        if (habilidades[i].gatilhos.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                                'Ativa com: ${habilidades[i].gatilhos.join(', ')}',
                                style: const TextStyle(
                                    fontSize: 10, color: cyan)),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(habilidades[i].origem,
                              style: const TextStyle(
                                  fontSize: 9.5, color: muted)),
                        ),
                      ],
                    ),
                  ),
                ],
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
