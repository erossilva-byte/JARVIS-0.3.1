import 'package:flutter/material.dart';
import 'catalog.dart';
import 'ui_common.dart';

/// Catálogo de sistemas: busca e lista dos módulos identificados no projeto.
class SystemsView extends StatelessWidget {
  const SystemsView({
    super.key,
    required this.query,
    required this.search,
    required this.onQuery,
    required this.onOpen,
    required this.onProviders,
    required this.onKws,
  });

  final String query;
  final TextEditingController search;
  final ValueChanged<String> onQuery;
  final ValueChanged<JarvisModule> onOpen;
  final VoidCallback onProviders;
  final VoidCallback onKws;

  @override
  Widget build(BuildContext context) {
    final visible = modules.where((module) =>
      '${module.name} ${module.group} ${module.description}'.toLowerCase().contains(query.toLowerCase())).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        const Text('CENTRAL DE SISTEMAS', style: TextStyle(color: cyan, fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        const Text('Capacidades do J.A.R.V.I.S.', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w300)),
        const SizedBox(height: 6),
        const Text('Acesse os módulos disponíveis no projeto.', style: TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 16),
        TextField(
          controller: search,
          onChanged: onQuery,
          decoration: InputDecoration(
            hintText: 'Buscar sistema ou função...',
            prefixIcon: const Icon(Icons.search_rounded, color: cyan),
            suffixIcon: query.isEmpty ? null : IconButton(
              onPressed: () { search.clear(); onQuery(''); },
              icon: const Icon(Icons.close),
            ),
            filled: true, fillColor: panel,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 14),
        for (final module in visible)
          Padding(padding: const EdgeInsets.only(bottom: 8),
            child: ModuleTile(module: module, onTap: () {
              if (module.name == 'Provedores de IA') {
                onProviders();
              } else if (module.name == 'Voz e KWS') {
                onKws();
              } else {
                onOpen(module);
              }
            })),
      ],
    );
  }
}
