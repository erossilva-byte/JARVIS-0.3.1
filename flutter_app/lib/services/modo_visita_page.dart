import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/modo_visita.dart';
import '../ui_common.dart';

/// App que aparece quando o PIN de coação é digitado.
///
/// É uma instalação nova, sem conversas, memória, fichas de pessoas, arquivos
/// ou chaves de provedor. Nada do dono do aparelho é lido, nada é enviado à
/// internet e nenhuma pergunta vai para um provedor de IA.
class ModoVisitaPage extends StatefulWidget {
  const ModoVisitaPage({super.key, required this.aoBloquear});

  /// Volta para a tela de bloqueio (o app real só abre com o PIN principal).
  final VoidCallback aoBloquear;

  @override
  State<ModoVisitaPage> createState() => _ModoVisitaPageState();
}

class _ModoVisitaPageState extends State<ModoVisitaPage> {
  final mensagens = <_Fala>[const _Fala(boasVindasVisita, meu: false)];
  final entrada = TextEditingController();

  @override
  void dispose() {
    entrada.dispose();
    super.dispose();
  }

  void _enviar([String? texto]) {
    final pergunta = (texto ?? entrada.text).trim();
    if (pergunta.isEmpty) return;
    setState(() {
      mensagens.add(_Fala(pergunta, meu: true));
      mensagens.add(_Fala(respostaVisita(pergunta), meu: false));
      entrada.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('J.A.R.V.I.S.', style: TextStyle(fontSize: 15, letterSpacing: 2)),
            Text('Assistente',
                style: TextStyle(fontSize: 9.5, color: muted, letterSpacing: 1)),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('visita-ajustes'),
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_rounded, size: 20),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => _AjustesVisitaPage(aoBloquear: widget.aoBloquear))),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              key: const ValueKey('visita-conversa'),
              padding: const EdgeInsets.all(16),
              itemCount: mensagens.length,
              itemBuilder: (_, i) {
                final fala = mensagens[i];
                return Align(
                  alignment: fala.meu
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(
                      color: fala.meu ? cyan.withValues(alpha: .16) : panel,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: (fala.meu ? cyan : muted)
                              .withValues(alpha: .22)),
                    ),
                    child: Text(fala.texto,
                        style: const TextStyle(fontSize: 12, height: 1.4)),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('visita-entrada'),
                      controller: entrada,
                      onSubmitted: _enviar,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: 'Pergunte algo…',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const ValueKey('visita-enviar'),
                    onPressed: _enviar,
                    icon: const Icon(Icons.send_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fala {
  const _Fala(this.texto, {required this.meu});
  final String texto;
  final bool meu;
}

/// Ajustes do app "recém-instalado": tudo vazio, sem nada do dono do aparelho.
class _AjustesVisitaPage extends StatelessWidget {
  const _AjustesVisitaPage({required this.aoBloquear});

  final VoidCallback aoBloquear;

  Future<void> _copiarPrompt(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: promptModoVisita));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prompt "Modo de visita" copiado.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes', style: TextStyle(fontSize: 15)),
        actions: [
          IconButton(
            key: const ValueKey('visita-bloquear'),
            tooltip: 'Bloquear e sair',
            icon: const Icon(Icons.lock_rounded, size: 20),
            onPressed: aoBloquear,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('AJUSTES DO APARELHO',
              style: TextStyle(
                  color: cyan, fontSize: 9.5, letterSpacing: 1.3)),
          const SizedBox(height: 6),
          for (final item in ajustesVisita)
            Material(
              color: Colors.transparent,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(item.$1, style: const TextStyle(fontSize: 12)),
                trailing: Text(item.$2,
                    style: const TextStyle(fontSize: 11, color: muted)),
              ),
            ),
          const SizedBox(height: 18),
          const Text('PROMPT SUGERIDO',
              style: TextStyle(
                  color: cyan, fontSize: 9.5, letterSpacing: 1.3)),
          const SizedBox(height: 6),
          Text(nomePromptModoVisita,
              key: const ValueKey('visita-prompt-nome'),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: muted.withValues(alpha: .2)),
            ),
            child: const Text(promptModoVisita,
                key: ValueKey('visita-prompt'),
                style: TextStyle(fontSize: 10.5, height: 1.45, color: muted)),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('visita-copiar-prompt'),
            onPressed: () => _copiarPrompt(context),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copiar prompt', style: TextStyle(fontSize: 10.5)),
          ),
          const SizedBox(height: 18),
          const Text('O QUE ESTE MODO FAZ',
              style: TextStyle(
                  color: cyan, fontSize: 9.5, letterSpacing: 1.3)),
          const SizedBox(height: 6),
          for (final limite in limitesModoVisita)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('· $limite',
                  style: const TextStyle(
                      fontSize: 10.5, color: muted, height: 1.4)),
            ),
        ],
      ),
    );
  }
}
