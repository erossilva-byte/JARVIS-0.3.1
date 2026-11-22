import 'package:material_ui/material_ui.dart';

import '../core/memoria.dart';
import '../core/memoria_conflito.dart';
import '../core/memoria_sync.dart';
import '../ui_common.dart';
import 'memoria_store.dart';
import 'resolvedor_conflito.dart';
import 'sincronizador.dart';

/// Resolve conflitos mostrando as duas versões e deixando o usuário escolher qual vale.
///
/// A versão perdedora não é apagada: vira uma nota de backup sem caminho, que a próxima
/// sincronização envia à pasta como arquivo novo em vez de sobrescrever o caminho em disputa.
class ConflitosPage extends StatefulWidget {
  const ConflitosPage({
    super.key,
    required this.conflitos,
    required this.store,
    required this.cofre,
  });

  final List<ConflitoSync> conflitos;
  final MemoriaStore store;
  final CofreRemoto cofre;

  @override
  State<ConflitosPage> createState() => _ConflitosPageState();
}

class _ConflitosPageState extends State<ConflitosPage> {
  late List<ConflitoSync> pendentes = List<ConflitoSync>.from(widget.conflitos);
  String? resolvendo;

  Future<void> _escolher(ConflitoSync conflito, DecisaoConflito decisao) async {
    if (resolvendo != null) return;
    final lado =
        decisao == DecisaoConflito.aparelho ? 'deste aparelho' : 'da pasta';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Manter esta versão?'),
        content: Text(
          'A versão $lado passa a valer em “${conflito.titulo}”. A outra versão vira uma nota de '
          'backup no cofre e não é apagada; a próxima sincronização a envia como arquivo novo.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogo, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogo, true),
              child: const Text('Manter')),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => resolvendo = conflito.titulo);
    final resultado =
        await ResolvedorConflito(store: widget.store, cofre: widget.cofre)
            .resolver(conflito, decisao);
    if (!mounted) return;
    setState(() {
      resolvendo = null;
      if (resultado.ok) {
        pendentes =
            pendentes.where((c) => c.titulo != conflito.titulo).toList();
      }
    });
    if (!resultado.ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(resultado.erro!)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(resultado.enviado
          ? 'Versão do aparelho mantida e enviada. A da pasta virou nota de backup.'
          : 'Versão da pasta mantida. A do aparelho virou nota de backup.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Conflitos do cofre')),
      body: pendentes.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Nenhum conflito pendente.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Voltar ao cofre')),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                  child: Text(
                    'As duas versões mudaram desde a última sincronização. Escolha qual vale: a outra '
                    'vira nota de backup e nada é apagado.',
                    style: TextStyle(fontSize: 12, height: 1.45, color: muted),
                  ),
                ),
                for (final conflito in pendentes) _cartao(conflito, colors),
              ],
            ),
    );
  }

  Widget _cartao(ConflitoSync conflito, ColorScheme colors) {
    final remotoTitulo = lerMarkdown(conflito.remoto.conteudo,
            tituloReserva: nomeSemExtensao(conflito.remoto.caminho))
        .titulo;
    final ocupado = resolvendo == conflito.titulo;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(conflito.titulo,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 2),
            Text(conflito.motivo, style: TextStyle(fontSize: 11, color: muted)),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (_, restricoes) {
                final ladoALado = restricoes.maxWidth >= 620;
                final aparelho = _versao(
                  titulo: conflito.local!.titulo,
                  rotulo: 'Neste aparelho',
                  texto: conflito.local!.texto,
                  cor: colors.primary,
                );
                final pasta = _versao(
                  titulo: remotoTitulo,
                  rotulo: 'Na pasta do Obsidian',
                  texto: conflito.remoto.corpo,
                  cor: colors.secondary,
                );
                if (!ladoALado) {
                  return Column(
                      children: [aparelho, const SizedBox(height: 8), pasta]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: aparelho),
                    const SizedBox(width: 8),
                    Expanded(child: pasta),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: ocupado
                      ? null
                      : () => _escolher(conflito, DecisaoConflito.aparelho),
                  icon: const Icon(Icons.phone_android_rounded, size: 18),
                  label: const Text('Manter a do aparelho'),
                ),
                OutlinedButton.icon(
                  onPressed: ocupado
                      ? null
                      : () => _escolher(conflito, DecisaoConflito.pasta),
                  icon: const Icon(Icons.folder_outlined, size: 18),
                  label: const Text('Manter a da pasta'),
                ),
              ],
            ),
            if (ocupado)
              const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: LinearProgressIndicator(minHeight: 2)),
          ],
        ),
      ),
    );
  }

  Widget _versao(
          {required String titulo,
          required String rotulo,
          required String texto,
          required Color cor}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cor.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rotulo,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: cor)),
            const SizedBox(height: 2),
            Text(titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: SelectableText(
                  texto.trim().isEmpty ? '(vazia)' : texto.trim(),
                  style: const TextStyle(fontSize: 11, height: 1.4),
                ),
              ),
            ),
          ],
        ),
      );
}
