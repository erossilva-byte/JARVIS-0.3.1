import 'package:flutter/material.dart';
import 'provider_service.dart';

class VoiceConversationPage extends StatefulWidget {
  const VoiceConversationPage({super.key, required this.initialCommand});
  final String initialCommand;

  @override
  State<VoiceConversationPage> createState() => _VoiceConversationPageState();
}

class _VoiceConversationPageState extends State<VoiceConversationPage> {
  late final ProviderService service = ProviderService(secrets: PlatformSecretStore());
  late final TextEditingController composer = TextEditingController(text: widget.initialCommand);
  final List<Map<String, String>> history = [];
  bool sending = false;
  String? error;
  String? providerName;
  AiProvider? activeProvider;
  bool submittedInitial = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendInitialIfConfigured());
  }

  Future<void> _sendInitialIfConfigured() async {
    if (submittedInitial || !mounted) return;
    submittedInitial = true;
    AiProvider? selected;
    try {
      selected = await service.firstConfiguredProvider();
    } catch (_) {
      if (!mounted) return;
      setState(() => error = 'Não foi possível acessar o cofre seguro de credenciais. A transcrição foi preservada.');
      return;
    }
    if (!mounted) return;
    if (selected == null) {
      setState(() => error = 'Nenhum provedor de IA está configurado. A transcrição foi preservada; configure o Groq ou outro provedor para receber uma resposta.');
      return;
    }
    await _send(provider: selected);
  }

  Future<void> _send({AiProvider? provider}) async {
    final text = composer.text.trim();
    if (text.isEmpty || sending) return;
    AiProvider? selected = provider ?? activeProvider;
    if (selected == null) {
      try {
        selected = await service.firstConfiguredProvider();
      } catch (_) {
        if (mounted) setState(() => error = 'Não foi possível acessar o cofre seguro de credenciais.');
        return;
      }
    }
    if (!mounted) return;
    if (selected == null) {
      setState(() => error = 'Nenhum provedor configurado. Configure o Groq ou outro provedor antes de enviar.');
      return;
    }
    activeProvider = selected;
    setState(() {
      sending = true;
      error = null;
      providerName = selected.name;
      if (history.isEmpty || history.last['role'] != 'user' || history.last['content'] != text) {
        history.add({'role': 'user', 'content': text});
      }
    });
    try {
      final reply = await service.complete(selected.id, history);
      if (!mounted) return;
      setState(() => history.add({'role': 'assistant', 'content': reply}));
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  void dispose() {
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
                Container(
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
                            const Text('Comando capturado por voz', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            const SizedBox(height: 5),
                            Text(widget.initialCommand, style: const TextStyle(fontSize: 14)),
                            const SizedBox(height: 5),
                            const Text('Reconhecimento de fala no dispositivo · pt-BR', style: TextStyle(color: Colors.grey, fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (providerName != null)
                  Text('Resposta via $providerName', style: const TextStyle(color: Color(0xFF55DFFF), fontSize: 10)),
                for (final message in history)
                  Align(
                    alignment: message['role'] == 'user' ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 340),
                      margin: const EdgeInsets.only(top: 9),
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: message['role'] == 'user'
                            ? const Color(0xFF123047)
                            : colors.surfaceContainerHighest.withValues(alpha: .5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(message['content'] ?? '', style: const TextStyle(fontSize: 13, height: 1.45)),
                    ),
                  ),
                if (sending)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 10), Text('J.A.R.V.I.S. está processando…', style: TextStyle(fontSize: 11))]),
                  ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: TextStyle(color: colors.error, fontSize: 12, height: 1.4)),
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
                      decoration: InputDecoration(
                        hintText: 'Digite uma mensagem…',
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: sending ? null : () => _send(),
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
}
