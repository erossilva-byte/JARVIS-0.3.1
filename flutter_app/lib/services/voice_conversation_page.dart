import 'dart:async';
import 'package:flutter/material.dart';
import '../core/stream_buffer.dart';
import 'provider_service.dart';

class VoiceConversationPage extends StatefulWidget {
  const VoiceConversationPage({super.key, required this.initialCommand, this.fromVoice = false});
  final String initialCommand;
  /// Origem do comando: só a captura pelo KWS nativo pode dizer "capturado por voz".
  final bool fromVoice;

  @override
  State<VoiceConversationPage> createState() => _VoiceConversationPageState();
}

class _VoiceConversationPageState extends State<VoiceConversationPage> {
  late final ProviderService service = ProviderService(secrets: PlatformSecretStore());
  late final TextEditingController composer = TextEditingController(text: widget.initialCommand);

  /// Cada mensagem é `{role, content}` e, nas respostas, `fontes` com as notas usadas.
  final List<Map<String, String>> mensagens = [];
  bool enviando = false;
  String? erro;
  String? aviso;
  String? provedorNome;
  AiProvider? provedorAtivo;
  bool enviouInicial = false;

  /// Texto parcial da resposta em streaming, já agrupado pelo buffer.
  String parcial = '';
  StreamBuffer? _buffer;
  StreamSubscription<String>? _assinatura;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _enviarInicialSeConfigurado());
  }

  Future<void> _enviarInicialSeConfigurado() async {
    if (enviouInicial || !mounted) return;
    enviouInicial = true;
    AiProvider? selecionado;
    try {
      selecionado = await service.firstConfiguredProvider();
    } catch (_) {
      if (!mounted) return;
      setState(() => erro = 'Não foi possível acessar o cofre seguro de credenciais. A transcrição foi preservada.');
      return;
    }
    if (!mounted) return;
    if (selecionado == null) {
      setState(() => erro = 'Nenhum provedor de IA está configurado. A transcrição foi preservada; configure o Groq ou outro provedor para receber uma resposta.');
      return;
    }
    await _enviar(provedor: selecionado);
  }

  Future<void> _enviar({AiProvider? provedor}) async {
    final texto = composer.text.trim();
    if (texto.isEmpty || enviando) return;
    AiProvider? selecionado = provedor ?? provedorAtivo;
    if (selecionado == null) {
      try {
        selecionado = await service.firstConfiguredProvider();
      } catch (_) {
        if (mounted) setState(() => erro = 'Não foi possível acessar o cofre seguro de credenciais.');
        return;
      }
    }
    if (!mounted) return;
    if (selecionado == null) {
      setState(() => erro = 'Nenhum provedor configurado. Configure o Groq ou outro provedor antes de enviar.');
      return;
    }
    final escolhido = selecionado;
    provedorAtivo = escolhido;
    final ultima = mensagens.isEmpty ? null : mensagens.last;
    if (ultima == null || ultima['role'] != 'user' || ultima['content'] != texto) {
      mensagens.add({'role': 'user', 'content': texto});
    }
    setState(() {
      enviando = true;
      erro = null;
      aviso = null;
      provedorNome = escolhido.name;
      parcial = '';
    });

    final buffer = StreamBuffer(
      aoAtualizar: (atual) {
        if (mounted) setState(() => parcial = atual);
      },
    );
    _buffer = buffer;
    _assinatura = service
        .streamComplete(escolhido.id, List<Map<String, String>>.from(mensagens))
        .listen(
      buffer.adicionar,
      cancelOnError: true,
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          enviando = false;
          parcial = '';
          erro = e.toString().replaceFirst('Bad state: ', '');
        });
      },
      onDone: () {
        if (!mounted) return;
        buffer.concluir();
        final recebido = buffer.texto;
        setState(() {
          enviando = false;
          parcial = '';
          _assinatura = null;
          if (recebido.trim().isEmpty) {
            erro = 'O provedor encerrou a resposta sem texto. Tente novamente.';
          } else {
            mensagens.add({'role': 'assistant', 'content': recebido, 'fontes': ''});
          }
        });
      },
    );
  }

  /// Interrompe a geração mantendo o que já apareceu: cancelar a assinatura fecha a conexão.
  void _parar() {
    final assinatura = _assinatura;
    if (assinatura == null) return;
    _assinatura = null;
    unawaited(assinatura.cancel());
    _buffer?.concluir();
    if (!mounted) return;
    final recebido = parcial;
    setState(() {
      enviando = false;
      if (recebido.trim().isNotEmpty) {
        mensagens.add({'role': 'assistant', 'content': recebido, 'fontes': ''});
      }
      parcial = '';
      aviso = recebido.trim().isEmpty ? 'Geração interrompida.' : 'Geração interrompida; o texto recebido foi mantido.';
    });
  }

  @override
  void dispose() {
    unawaited(_assinatura?.cancel() ?? Future<void>.value());
    composer.dispose();
    service.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Conversa com J.A.R.V.I.S.')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _origem(colors),
                const SizedBox(height: 16),
                if (provedorNome != null)
                  Text('Resposta via $provedorNome', style: const TextStyle(color: Color(0xFF55DFFF), fontSize: 10)),
                if (mensagens.isEmpty && !enviando && erro == null && parcial.isEmpty) _vazio(colors),
                for (final mensagem in mensagens) _bolha(mensagem, colors),
                if (enviando && parcial.isNotEmpty) _bolha({'role': 'assistant', 'content': parcial}, colors, emCurso: true),
                if (enviando)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('J.A.R.V.I.S. está processando…', style: TextStyle(fontSize: 11)),
                    ]),
                  ),
                if (aviso != null) ...[
                  const SizedBox(height: 10),
                  Text(aviso!, style: const TextStyle(color: Color(0xFFFFC66D), fontSize: 11, height: 1.4)),
                ],
                if (erro != null) ...[
                  const SizedBox(height: 12),
                  Text(erro!, style: TextStyle(color: colors.error, fontSize: 12, height: 1.4)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: enviando ? null : () => _enviar(),
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: const Text('Tentar de novo'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: composer,
                      minLines: 1,
                      maxLines: 4,
                      enabled: !enviando,
                      decoration: InputDecoration(
                        hintText: 'Digite uma mensagem…',
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (_) => _enviar(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (enviando)
                    IconButton.filledTonal(
                      tooltip: 'Parar geração',
                      onPressed: _parar,
                      icon: const Icon(Icons.stop_rounded),
                    )
                  else
                    IconButton.filled(
                      tooltip: 'Enviar mensagem',
                      onPressed: () => _enviar(),
                      icon: const Icon(Icons.send_rounded),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _origem(ColorScheme colors) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: .35),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.graphic_eq_rounded, color: Color(0xFF55DFFF)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.fromVoice ? 'Comando capturado por voz' : 'Comando digitado', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 5),
                  Text(widget.initialCommand, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 5),
                  Text(widget.fromVoice ? 'Reconhecimento de fala no dispositivo · pt-BR' : 'Enviado pelo campo de conversa', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _vazio(ColorScheme colors) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          children: [
            Icon(Icons.forum_outlined, color: Color(0xFF55DFFF), size: 28),
            SizedBox(height: 9),
            Text('A conversa começa com o comando acima.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            SizedBox(height: 5),
            Text('A resposta aparece aos poucos; você pode interromper a geração a qualquer momento.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 11, height: 1.4)),
          ],
        ),
      );

  Widget _bolha(Map<String, String> mensagem, ColorScheme colors, {bool emCurso = false}) {
    final doUsuario = mensagem['role'] == 'user';
    final fontes = (mensagem['fontes'] ?? '').trim();
    return Align(
      alignment: doUsuario ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.only(top: 9),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: doUsuario
              ? const Color(0xFF123047)
              : colors.surfaceContainerHighest.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mensagem['content'] ?? '', style: const TextStyle(fontSize: 13, height: 1.45)),
            if (fontes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('O que lembrei: $fontes', style: const TextStyle(color: Color(0xFF55DFFF), fontSize: 10)),
            ],
            if (emCurso) ...[
              const SizedBox(height: 6),
              const Text('recebendo…', style: TextStyle(color: Colors.grey, fontSize: 9)),
            ],
          ],
        ),
      ),
    );
  }
}
