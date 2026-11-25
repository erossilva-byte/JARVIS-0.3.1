import 'package:material_ui/material_ui.dart';

import '../core/mapa_voz.dart';
import '../ui_common.dart';

/// Mapa da voz: as telas e os caminhos que respondem por fala.
///
/// Sai da mesma tabela usada para abrir as telas, então o que aparece aqui é o
/// que funciona de verdade. Cada item traz a frase de exemplo, e a frase pode
/// ser dita com o app aberto ou fechado.
class MapaVozPage extends StatelessWidget {
  const MapaVozPage({super.key});

  @override
  Widget build(BuildContext context) {
    final categorias = mapaDaVoz();
    return Scaffold(
      appBar: AppBar(
          title: const Text('Mapa da voz',
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
                Text('FALE DO JEITO QUE QUISER',
                    style: TextStyle(
                        color: cyan,
                        fontSize: 9,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text(
                  'Cada linha é uma frase de exemplo. O JARVIS reconhece o '
                  'pedido antes de gastar provedor de IA e responde o que '
                  'realmente aconteceu — quando falta uma autorização, ele diz '
                  'qual é.',
                  style: TextStyle(color: muted, fontSize: 11, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final categoria in categorias) ...[
            Text(categoria.titulo,
                style: const TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(categoria.nota,
                style: const TextStyle(
                    color: muted, fontSize: 10, height: 1.4)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  for (final item in categoria.itens)
                    ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      leading: const Icon(Icons.mic_none_rounded, size: 18),
                      title: Text('“$item”',
                          style: const TextStyle(fontSize: 11.5)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Telas: $totalDeTelasPorVoz. Contato: diga “o apelido do Murilo '
            'é Murilin” uma vez e o JARVIS passa a entender os dois nomes.',
            style: const TextStyle(color: muted, fontSize: 10, height: 1.45),
          ),
        ],
      ),
    );
  }
}
