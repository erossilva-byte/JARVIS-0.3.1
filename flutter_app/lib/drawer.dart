import 'package:flutter/material.dart';
import 'ui_common.dart';

/// Painel lateral: navegação e o estado real do detector local.
class JarvisDrawer extends StatelessWidget {
  const JarvisDrawer({
    super.key,
    required this.onSelectTab,
    required this.onProviders,
    required this.onKws,
    required this.onModule,
    required this.onSettings,
    required this.kwsLabel,
    required this.kwsColor,
  });

  final ValueChanged<int> onSelectTab;
  final VoidCallback onProviders;
  final VoidCallback onKws;
  final VoidCallback onSettings;
  final ValueChanged<String> onModule;
  final String kwsLabel;
  final Color kwsColor;

  @override
  Widget build(BuildContext context) => Drawer(
    backgroundColor: const Color(0xFF080F1B),
    child: SafeArea(child: Column(children: [
      const Padding(padding: EdgeInsets.fromLTRB(18, 24, 18, 18),
        child: Row(children: [
          BrandMark(), SizedBox(width: 12),
          // Expanded + ellipsis: sem isso o cabeçalho estoura 68 px na largura da gaveta.
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('COMMAND CENTER', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: cyan, fontSize: 10, letterSpacing: 2)),
            Text('J.A.R.V.I.S. Nova', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ])),
        ])),
      const Divider(color: Colors.white12),
      Expanded(child: ListView(children: [
        _item(Icons.blur_circular_rounded, 'Comando', () { Navigator.pop(context); onSelectTab(0); }),
        _item(Icons.psychology_rounded, 'IA Core', () { Navigator.pop(context); onProviders(); }),
        _item(Icons.graphic_eq_rounded, 'Voz', () { Navigator.pop(context); onKws(); }),
        _item(Icons.visibility_rounded, 'Visão', () { Navigator.pop(context); onModule('Visão e OCR'); }),
        _item(Icons.checklist_rounded, 'Tarefas', () { Navigator.pop(context); onModule('Tarefas e rotinas'); }),
        _item(Icons.people_alt_rounded, 'Pessoas', () { Navigator.pop(context); onModule('Pessoas e contexto'); }),
        _item(Icons.terminal_rounded, 'Dev. Arquivos', () { Navigator.pop(context); onModule('Programação e sandbox'); }),
        _item(Icons.bolt_rounded, 'Rotinas', () { Navigator.pop(context); onModule('Tarefas e rotinas'); }),
        _item(Icons.phone_android_rounded, 'Celular', () { Navigator.pop(context); onModule('Android e dispositivos'); }),
        _item(Icons.account_tree_rounded, 'Memória', () { Navigator.pop(context); onModule('Memória semântica'); }),
        _item(Icons.folder_copy_rounded, 'Arquivos', () { Navigator.pop(context); onModule('Arquivos'); }),
        _item(Icons.electrical_services_rounded, 'CADeSIMU', () { Navigator.pop(context); onModule('CADeSIMU e elétrica'); }),
        _item(Icons.desktop_windows_rounded, 'Computador', () { Navigator.pop(context); onModule('Controle do Windows'); }),
        _item(Icons.tune_rounded, 'Configurações', () { Navigator.pop(context); onSettings(); }),
      ])),
      const Divider(color: Colors.white12),
      Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Icon(Icons.circle, size: 8, color: kwsColor), const SizedBox(width: 9),
        const Expanded(child: Text('VOZ LOCAL', style: TextStyle(fontSize: 9, color: muted, letterSpacing: 1.5))),
        const SizedBox(width: 8),
        Flexible(child: Text(kwsLabel, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: TextStyle(fontSize: 9, color: kwsColor))),
      ])),
    ])),
  );

  Widget _item(IconData icon, String title, VoidCallback onTap) => ListTile(
    dense: true, leading: Icon(icon, color: cyan, size: 20),
    title: Text(title, style: const TextStyle(fontSize: 13)),
    trailing: const Icon(Icons.chevron_right_rounded, color: muted, size: 18),
    onTap: onTap,
  );
}
