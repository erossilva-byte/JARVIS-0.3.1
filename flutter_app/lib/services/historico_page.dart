import 'package:material_ui/material_ui.dart';

import '../core/conversa.dart';
import 'conversa_store.dart';
import 'voice_conversation_page.dart';

/// Histórico de conversas: busca, fixar, apagar e abrir.
class HistoricoPage extends StatefulWidget {
  const HistoricoPage({super.key, required this.store});

  final ConversaStore store;

  @override
  State<HistoricoPage> createState() => _HistoricoPageState();
}

class _HistoricoPageState extends State<HistoricoPage> {
  List<Conversa> conversas = const [];
  bool carregando = true;
  String busca = '';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final lista = widget.store.ordenadas();
    if (!mounted) return;
    setState(() {
      conversas = lista;
      carregando = false;
    });
  }

  List<Conversa> get _filtradas {
    final termo = busca.trim().toLowerCase();
    if (termo.isEmpty) return conversas;
    return conversas.where((c) {
      if (c.titulo.toLowerCase().contains(termo)) return true;
      return c.mensagens.any((m) => m.texto.toLowerCase().contains(termo));
    }).toList();
  }

  Future<void> _abrir(Conversa conversa) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => VoiceConversationPage(initialCommand: '', conversa: conversa),
    ));
    await _carregar();
  }

  Future<void> _nova() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const VoiceConversationPage(initialCommand: ''),
    ));
    await _carregar();
  }

  Future<void> _apagar(Conversa conversa) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Apagar conversa?'),
        content: Text('“${conversa.titulo}” será removida deste aparelho.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogo, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogo, true), child: const Text('Apagar')),
        ],
      ),
    );
    if (confirmar != true) return;
    await widget.store.apagar(conversa.id);
    await _carregar();
  }

  Future<void> _fixar(Conversa conversa) async {
    await widget.store.alternarFixada(conversa.id);
    await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de conversas'),
        actions: [
          IconButton(tooltip: 'Nova conversa', onPressed: _nova, icon: const Icon(Icons.add_comment_rounded)),
        ],
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    onChanged: (valor) => setState(() => busca = valor),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: 'Buscar por título ou mensagem…',
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                Expanded(
                  child: conversas.isEmpty
                      ? _vazio(colors)
                      : _filtradas.isEmpty
                          ? _semResultado()
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                              itemCount: _filtradas.length,
                              itemBuilder: (_, indice) {
                                final conversa = _filtradas[indice];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    onTap: () => _abrir(conversa),
                                    title: Text(conversa.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    subtitle: Text(
                                      '${conversa.mensagens.length} mensagem(ns) · ${_data(conversa.atualizadaEm)}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    leading: Icon(conversa.fixada ? Icons.push_pin_rounded : Icons.forum_outlined, color: colors.primary),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: conversa.fixada ? 'Desafixar' : 'Fixar',
                                          onPressed: () => _fixar(conversa),
                                          icon: Icon(conversa.fixada ? Icons.push_pin : Icons.push_pin_outlined, size: 19),
                                        ),
                                        IconButton(
                                          tooltip: 'Apagar',
                                          onPressed: () => _apagar(conversa),
                                          icon: const Icon(Icons.delete_outline_rounded, size: 19),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
    );
  }

  Widget _vazio(ColorScheme colors) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.forum_outlined, size: 38, color: colors.primary),
              const SizedBox(height: 12),
              const Text('Nenhuma conversa ainda', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text('As conversas ficam salvas neste aparelho. Comece uma nova pelo botão acima.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12, height: 1.4)),
            ],
          ),
        ),
      );

  Widget _semResultado() => const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text('Nenhuma conversa corresponde à busca.', textAlign: TextAlign.center),
        ),
      );

  String _data(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')} ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
}
