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
  final rolagem = ScrollController();

  /// Perguntas que este modo responde sem provedor — e sem tocar em dado algum.
  static const sugestoes = <String>[
    'Que horas são?',
    'Que dia é hoje?',
    'Quem é você?',
  ];

  @override
  void dispose() {
    entrada.dispose();
    rolagem.dispose();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!rolagem.hasClients) return;
      rolagem.animateTo(rolagem.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('J.A.R.V.I.S.',
                style: TextStyle(fontSize: 15, letterSpacing: 2)),
            Text('Assistente',
                style:
                    TextStyle(fontSize: 9.5, color: muted, letterSpacing: 1)),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('visita-ajustes'),
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_rounded, size: 20),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) =>
                    _AjustesVisitaPage(aoBloquear: widget.aoBloquear))),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -.85),
            radius: .95,
            colors: [cyan.withValues(alpha: .10), bg.withValues(alpha: 0)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _cabecalho(),
              Expanded(
                child: ListView.builder(
                  key: const ValueKey('visita-conversa'),
                  controller: rolagem,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  itemCount: mensagens.length,
                  itemBuilder: (_, i) => _bolha(mensagens[i], i == 0),
                ),
              ),
              if (mensagens.length <= 1) _atalhos(),
              _barraDeEntrada(),
            ],
          ),
        ),
      ),
    );
  }

  /// Cartão de abertura: deixa claro, de relance, que este não é o app real.
  Widget _cabecalho() => Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [panel, cyan.withValues(alpha: .06)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cyan.withValues(alpha: .22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cyan.withValues(alpha: .12),
                border: Border.all(color: cyan.withValues(alpha: .35)),
                boxShadow: [
                  BoxShadow(
                    color: cyan.withValues(alpha: .18),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(Icons.person_outline_rounded,
                  color: cyan, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('MODO DE VISITA',
                        style: TextStyle(
                            color: cyan,
                            fontSize: 9,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w700)),
                    SizedBox(width: 8),
                    _Selo(texto: 'SEM DADOS'),
                  ]),
                  SizedBox(height: 6),
                  Text(
                    'Este aparelho ainda não foi configurado. Nada seu fica visível aqui e nenhuma pergunta sai do telefone.',
                    style:
                        TextStyle(fontSize: 10.5, height: 1.45, color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  /// Sugestões do que o modo de visita responde sem provedor.
  Widget _atalhos() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final sugestao in sugestoes)
              ActionChip(
                key: ValueKey('visita-sugestao-$sugestao'),
                avatar: const Icon(Icons.bolt_rounded, size: 14, color: cyan),
                label: Text(sugestao, style: const TextStyle(fontSize: 10.5)),
                backgroundColor: panel,
                side: BorderSide(color: cyan.withValues(alpha: .22)),
                onPressed: () => _enviar(sugestao),
              ),
          ],
        ),
      );

  Widget _bolha(_Fala fala, bool primeira) => Padding(
        padding: EdgeInsets.only(top: primeira ? 2 : 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment:
              fala.meu ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!fala.meu) ...[
              Container(
                margin: const EdgeInsets.only(top: 2, right: 8),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cyan.withValues(alpha: .12),
                  border: Border.all(color: cyan.withValues(alpha: .25)),
                ),
                child: const Icon(Icons.blur_on_rounded, size: 13, color: cyan),
              ),
            ],
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                constraints: const BoxConstraints(maxWidth: 300),
                decoration: BoxDecoration(
                  gradient: fala.meu
                      ? LinearGradient(colors: [
                          cyan.withValues(alpha: .22),
                          cyan.withValues(alpha: .12),
                        ])
                      : null,
                  color: fala.meu ? null : panel,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(fala.meu ? 16 : 4),
                    bottomRight: Radius.circular(fala.meu ? 4 : 16),
                  ),
                  border: Border.all(
                    color: (fala.meu ? cyan : muted).withValues(alpha: .20),
                  ),
                ),
                child: Text(fala.texto,
                    style: const TextStyle(fontSize: 12, height: 1.45)),
              ),
            ),
          ],
        ),
      );

  Widget _barraDeEntrada() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: cyan.withValues(alpha: .18)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('visita-entrada'),
                  controller: entrada,
                  onSubmitted: _enviar,
                  textInputAction: TextInputAction.send,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: 'Pergunte algo…',
                    hintStyle: TextStyle(fontSize: 12, color: muted),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                key: const ValueKey('visita-enviar'),
                onPressed: _enviar,
                icon: const Icon(Icons.send_rounded, size: 18),
              ),
            ],
          ),
        ),
      );
}

/// Etiqueta curta do cabeçalho.
class _Selo extends StatelessWidget {
  const _Selo({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF64E6B1).withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: const Color(0xFF64E6B1).withValues(alpha: .35)),
        ),
        child: Text(texto,
            style: const TextStyle(
                fontSize: 7.5,
                letterSpacing: 1,
                color: Color(0xFF64E6B1),
                fontWeight: FontWeight.w700)),
      );
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
      backgroundColor: bg,
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _cartao(
            titulo: 'ESTADO DO APARELHO',
            detalhe: 'Tudo vazio, como numa instalação nova.',
            child: Column(
              children: [
                for (final item in ajustesVisita)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(children: [
                      const Icon(Icons.remove_circle_outline_rounded,
                          size: 14, color: muted),
                      const SizedBox(width: 9),
                      Expanded(
                        child:
                            Text(item.$1, style: const TextStyle(fontSize: 12)),
                      ),
                      Text(item.$2,
                          style: const TextStyle(fontSize: 11, color: muted)),
                    ]),
                  ),
              ],
            ),
          ),
          _cartao(
            titulo: 'PROMPT SUGERIDO',
            detalhe: 'Para qualquer assistente que fale neste modo.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nomePromptModoVisita,
                    key: const ValueKey('visita-prompt-nome'),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: muted.withValues(alpha: .18)),
                  ),
                  child: const Text(promptModoVisita,
                      key: ValueKey('visita-prompt'),
                      style:
                          TextStyle(fontSize: 10.5, height: 1.5, color: muted)),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const ValueKey('visita-copiar-prompt'),
                  onPressed: () => _copiarPrompt(context),
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  label: const Text('Copiar prompt',
                      style: TextStyle(fontSize: 10.5)),
                ),
              ],
            ),
          ),
          _cartao(
            titulo: 'O QUE ESTE MODO FAZ',
            detalhe: 'E o que ele não promete.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final limite in limitesModoVisita)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1, right: 8),
                            child: Icon(Icons.shield_outlined,
                                size: 13, color: cyan),
                          ),
                          Expanded(
                            child: Text(limite,
                                style: const TextStyle(
                                    fontSize: 10.5,
                                    color: muted,
                                    height: 1.45)),
                          ),
                        ]),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC66D).withValues(alpha: .07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFFFC66D).withValues(alpha: .25)),
            ),
            child: Row(children: [
              const Icon(Icons.lock_rounded,
                  size: 16, color: Color(0xFFFFC66D)),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Ajustar qualquer coisa aqui não muda o app real: esses ajustes são só desta visita.',
                  style: TextStyle(fontSize: 10.5, height: 1.45),
                ),
              ),
              TextButton(
                key: const ValueKey('visita-sair'),
                onPressed: aoBloquear,
                child: const Text('Sair', style: TextStyle(fontSize: 10.5)),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _cartao({
    required String titulo,
    required String detalhe,
    required Widget child,
  }) =>
      Container(
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
            const SizedBox(height: 3),
            Text(detalhe, style: const TextStyle(fontSize: 10, color: muted)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );
}
