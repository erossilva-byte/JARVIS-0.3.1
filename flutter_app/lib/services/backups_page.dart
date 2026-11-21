import 'package:material_ui/material_ui.dart';

import '../core/memoria.dart';
import '../ui_common.dart';
import 'memoria_page.dart';
import 'memoria_store.dart';

/// Revisão e limpeza das notas que guardam a versão perdedora de um conflito.
///
/// Restaurar cria uma nota normal com o mesmo texto e remove o backup; apagar é decisão explícita
/// e só mexe neste aparelho — a pasta do Obsidian não é tocada.
class BackupsPage extends StatefulWidget {
  const BackupsPage({super.key, required this.store});

  final MemoriaStore store;

  @override
  State<BackupsPage> createState() => _BackupsPageState();
}

class _BackupsPageState extends State<BackupsPage> {
  late List<NotaMemoria> backups =
      widget.store.listar().where(ehBackupConflito).toList();

  void _recarregar() => setState(
      () => backups = widget.store.listar().where(ehBackupConflito).toList());

  Future<void> _abrir(NotaMemoria backup) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
          builder: (_) => NotaEditorPage(store: widget.store, nota: backup)),
    );
    if (mounted) _recarregar();
  }

  Future<void> _restaurar(NotaMemoria backup) async {
    final quando = DateTime.now();
    final restaurada = NotaMemoria(
      id: 'nota-${quando.microsecondsSinceEpoch}',
      titulo: tituloSemSufixoBackup(backup.titulo),
      texto: backup.texto,
      tema: backup.tema,
      tags: backup.tags,
      importancia: backup.importancia,
      criadaEm: quando,
      atualizadaEm: quando,
    );
    await widget.store.salvar(restaurada);
    await widget.store.apagar(backup.id);
    if (!mounted) return;
    _recarregar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              '“${restaurada.titulo}” voltou como nota normal; o backup foi removido.')),
    );
  }

  Future<void> _apagar(NotaMemoria backup) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Apagar este backup?'),
        content: Text(
            '“${backup.titulo}” será removido deste aparelho. A pasta do Obsidian não é alterada.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogo, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogo, true),
              child: const Text('Apagar')),
        ],
      ),
    );
    if (confirmar != true) return;
    await widget.store.apagar(backup.id);
    if (!mounted) return;
    _recarregar();
  }

  Future<void> _limparTodos() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: Text('Apagar ${backups.length} backup(s)?'),
        content: const Text(
          'Todas as versões guardadas por conflito serão removidas deste aparelho. '
          'As notas atuais do cofre e a pasta do Obsidian não são alteradas.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogo, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogo, true),
              child: const Text('Apagar todos')),
        ],
      ),
    );
    if (confirmar != true) return;
    for (final backup in List<NotaMemoria>.from(backups)) {
      await widget.store.apagar(backup.id);
    }
    if (!mounted) return;
    _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backups de conflito'),
        actions: [
          if (backups.isNotEmpty)
            IconButton(
              tooltip: 'Apagar todos os backups',
              onPressed: _limparTodos,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: backups.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Text(
                  'Nenhum backup de conflito.\n\nQuando você resolve um conflito, a versão que perde fica guardada aqui.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, height: 1.5, color: muted),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    'Cada backup é a versão que perdeu um conflito. Restaurar devolve o texto como nota '
                    'normal; apagar remove só deste aparelho.',
                    style: TextStyle(fontSize: 12, height: 1.45, color: muted),
                  ),
                ),
                for (final backup in backups) _cartao(backup, colors),
              ],
            ),
    );
  }

  Widget _cartao(NotaMemoria backup, ColorScheme colors) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      backup.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  Text(
                    '${backup.atualizadaEm.day.toString().padLeft(2, '0')}/${backup.atualizadaEm.month.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 10, color: muted),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                backup.texto.trim().isEmpty ? '(vazia)' : backup.texto.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Abrir backup',
                    onPressed: () => _abrir(backup),
                    icon: const Icon(Icons.open_in_new_rounded, size: 19),
                  ),
                  IconButton(
                    tooltip: 'Restaurar como nota',
                    onPressed: () => _restaurar(backup),
                    icon: Icon(Icons.restore_rounded,
                        size: 20, color: colors.primary),
                  ),
                  IconButton(
                    tooltip: 'Apagar backup',
                    onPressed: () => _apagar(backup),
                    icon: const Icon(Icons.delete_outline_rounded, size: 19),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
