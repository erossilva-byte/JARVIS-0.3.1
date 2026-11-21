import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/conversa.dart';
import '../core/habilidades.dart';
import '../core/historico_voz.dart';
import '../core/memoria_busca.dart';
import '../core/personalidade.dart';
import '../core/pessoas.dart';
import '../core/stream_buffer.dart';
import '../ui_common.dart';
import 'comandos_android_service.dart';
import 'conversa_store.dart';
import 'habilidades_service.dart';
import 'historico_page.dart';
import 'kws_bridge.dart';
import 'kws_controller.dart';
import 'historico_voz_service.dart';
import 'memoria_store.dart';
import 'personalidade_store.dart';
import 'pessoas_store.dart';
import 'provider_service.dart';
import 'sistema_android.dart';
import 'voz_jarvis.dart';
import 'voz_tela_cheia_page.dart';

class VoiceConversationPage extends StatefulWidget {
  const VoiceConversationPage(
      {super.key,
      required this.initialCommand,
      this.fromVoice = false,
      this.conversa,
      this.voz = const VozJarvis(),
      this.historico,
      this.habilidadesServico});

  final String initialCommand;

  /// Origem do comando: só a captura pelo KWS nativo pode dizer "capturado por voz".
  final bool fromVoice;

  /// Conversa existente (histórico); nulo cria uma nova.
  final Conversa? conversa;

  /// Voz de resposta; testes podem injetar uma implementação falsa.
  final VozJarvis voz;

  /// Histórico de execuções; nulo usa o armazenamento do aparelho.
  final HistoricoVozGateway? historico;

  /// Habilidades em Markdown do aparelho; nulo lê a pasta padrão.
  final HabilidadesService? habilidadesServico;

  @override
  State<VoiceConversationPage> createState() => _VoiceConversationPageState();
}

class _VoiceConversationPageState extends State<VoiceConversationPage> {
  late final ProviderService service =
      ProviderService(secrets: PlatformSecretStore());
  final ExecutorComandosAndroid _comandos = ExecutorComandosAndroid();
  late final HistoricoVozGateway _historico =
      widget.historico ?? HistoricoVozService();
  int _sequenciaComandos = 0;
  late final TextEditingController composer =
      TextEditingController(text: widget.initialCommand);
  late Conversa conversa;

  ConversaStore? store;
  MemoriaStore? memoria;
  PessoasStore? pessoas;
  Personalidade _personalidade = const Personalidade();
  final List<String> _angulosRecentes = [];
  bool enviando = false;
  String? erro;
  String? aviso;
  String? provedorNome;
  AiProvider? provedorAtivo;
  bool enviouInicial = false;
  bool vozAtiva = true;

  VozJarvis get voz => widget.voz;

  /// Texto parcial da resposta em streaming, já agrupado pelo buffer.
  String parcial = '';
  StreamBuffer? _buffer;

  /// Bloco de pessoas da requisição em andamento, para anexar à resposta (inclusive se parar).
  ContextoPessoasConversa _contextoPessoaAtual =
      const ContextoPessoasConversa.nenhum();
  StreamSubscription<String>? _assinatura;

  /// Gesto do aparelho (celular virado para baixo) interrompe a resposta.
  StreamSubscription<KwsCommandEvent>? _calarSub;

  @override
  void initState() {
    super.initState();
    conversa = widget.conversa ??
        Conversa.nova(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            agora: DateTime.now());
    _preparar();
    _calarSub = KwsController.commandBus.listen((evento) {
      if (evento.type != 'calou' || !mounted) return;
      if (_assinatura != null) _parar();
      unawaited(voz.parar());
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _enviarInicialSeConfigurado());
  }

  Future<void> _preparar() async {
    try {
      store = await ConversaStore.abrir();
      if (!mounted) return;
      if (widget.conversa == null &&
          composer.text.trim().isEmpty &&
          store!.rascunho.trim().isNotEmpty) {
        composer.text = store!.rascunho;
      }
      await store!.salvar(conversa);
    } catch (_) {
      // Sem armazenamento disponível (teste ou plataforma sem plugin), a tela segue em memória.
      store = null;
    }
    try {
      memoria = await MemoriaStore.abrir();
    } catch (_) {
      memoria = null;
    }
    try {
      pessoas = await PessoasStore.abrir();
    } catch (_) {
      pessoas = null;
    }
  }

  Future<void> _persistir() async {
    final atual = store;
    if (atual == null) return;
    await atual.salvar(conversa);
  }

  Future<void> _enviarInicialSeConfigurado() async {
    if (enviouInicial || !mounted) return;
    enviouInicial = true;
    if (widget.initialCommand.trim().isEmpty) return;
    // Comandos locais não precisam de provedor; _enviar decide isso antes de pedir a chave.
    await _enviar();
  }

  Future<void> _enviar({AiProvider? provedor}) async {
    final texto = composer.text.trim();
    if (texto.isEmpty || enviando) return;
    final comando = await _comandos.executar(texto);
    if (comando != null) {
      _concluirComando(texto, comando);
      return;
    }
    _sequenciaComandos = 0;
    AiProvider? selecionado = provedor ?? provedorAtivo;
    if (selecionado == null) {
      try {
        selecionado = await service.firstConfiguredProvider();
      } catch (_) {
        if (mounted) {
          setState(() =>
              erro = 'Não foi possível acessar o cofre seguro de credenciais.');
        }
        return;
      }
    }
    if (!mounted) return;
    if (selecionado == null) {
      setState(() => erro =
          'Nenhum provedor configurado. Configure o Groq ou outro provedor antes de enviar.');
      return;
    }
    final escolhido = selecionado;
    provedorAtivo = escolhido;
    unawaited(voz.parar());
    final ultima = conversa.mensagens.isEmpty ? null : conversa.mensagens.last;
    if (ultima == null || !ultima.doUsuario || ultima.texto != texto) {
      conversa.adicionar(MensagemConversa(autor: 'user', texto: texto));
    }
    composer.clear();
    unawaited(store?.limparRascunho());
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
    final historico = conversa.mensagens
        .map((m) => {'role': m.autor, 'content': m.texto})
        .toList();
    // Só entra o que a busca considerou relevante; sem resultado, nenhuma nota é enviada.
    final contextoMemoria = memoria?.contexto(texto) ??
        const ContextoMemoria(texto: '', usados: [], caracteres: 0);
    // Só o bloco seguro de pessoas (sem contato, anotação, compromisso ou histórico). Se não há
    // ficha para o nome perguntado, o próprio bloco instrui a IA a dizer que não encontrou.
    var listaPessoas = const <Pessoa>[];
    try {
      if (pessoas != null) listaPessoas = await pessoas!.listar();
    } catch (_) {
      // Falha do armazenamento seguro não impede a conversa: segue sem fichas.
      listaPessoas = const <Pessoa>[];
    }
    final contextoPessoa = contextoPessoasParaConsulta(listaPessoas, texto);
    _contextoPessoaAtual = contextoPessoa;
    // Habilidades em Markdown: só entram as que casam com a pergunta; falha de
    // leitura não impede a conversa.
    var habilidadesUsadas = const <Habilidade>[];
    try {
      final carregadas = await (widget.habilidadesServico ??
              const HabilidadesService())
          .carregar();
      habilidadesUsadas =
          habilidadesQueCasam(carregadas.habilidades, texto);
    } catch (_) {
      habilidadesUsadas = const <Habilidade>[];
    }
    try {
      _personalidade = (await PersonalidadeStore.abrir()).carregar();
    } catch (_) {
      // Preferência indisponível não impede conversar; fica o padrão equilibrado.
      _personalidade = const Personalidade();
    }
    final estilo = estiloDoTurno(
      _personalidade,
      texto,
      recentes: _angulosRecentes,
      semente: conversa.mensagens.length,
    );
    if (estilo.angulo != null) {
      _angulosRecentes.add(estilo.angulo!);
      if (_angulosRecentes.length > 8) _angulosRecentes.removeAt(0);
    }
    _assinatura = service
        .streamComplete(
      escolhido.id,
      montarMensagens(
        historico,
        contextoMemoria,
        pessoas: contextoPessoa.bloco,
        personalidade: estilo.prompt,
        habilidades: blocoHabilidades(habilidadesUsadas),
      ),
    )
        .listen(
      buffer.adicionar,
      cancelOnError: true,
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          enviando = false;
          parcial = '';
          _contextoPessoaAtual = const ContextoPessoasConversa.nenhum();
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
            conversa.adicionar(MensagemConversa(
              autor: 'assistant',
              texto: recebido,
              fontes:
                  contextoMemoria.usados.map((nota) => nota.titulo).toList(),
              fichas: contextoPessoa.nomes,
              contextoPessoas: contextoPessoa.bloco,
              habilidades:
                  habilidadesUsadas.map((h) => h.nome).toList(),
            ));
          }
        });
        if (recebido.trim().isNotEmpty) unawaited(_falar(recebido));
        unawaited(_persistir());
        unawaited(memoria
                ?.registrarUso(contextoMemoria.usados.map((nota) => nota.id)) ??
            Future<void>.value());
      },
    );
  }

  /// Registra a resposta local de um comando sem chamar provedor de IA.
  void _concluirComando(String texto, ResultadoComando comando) {
    unawaited(voz.parar());
    final ultima = conversa.mensagens.isEmpty ? null : conversa.mensagens.last;
    if (ultima == null || !ultima.doUsuario || ultima.texto != texto) {
      conversa.adicionar(MensagemConversa(autor: 'user', texto: texto));
    }
    _sequenciaComandos++;
    final bloqueado = _sequenciaComandos > 5;
    final mensagem = bloqueado
        ? 'Limite de cinco comandos seguidos atingido. Faça uma pergunta ou peça outra coisa para continuar.'
        : comando.mensagem;
    conversa.adicionar(MensagemConversa(autor: 'assistant', texto: mensagem));
    composer.clear();
    unawaited(store?.limparRascunho());
    setState(() {
      enviando = false;
      erro = null;
      aviso = null;
      parcial = '';
    });
    unawaited(_falar(mensagem));
    unawaited(_persistir());
    // Fica no aparelho para conferir depois: o que foi pedido, a ação e o resultado.
    unawaited(_historico.registrar(
      pedido: texto,
      acao: comando.acao,
      // No limite de comandos seguidos nada foi executado: o histórico não pode dizer que sim.
      ok: comando.ok && !bloqueado,
      mensagem: mensagem,
      origem:
          widget.fromVoice ? OrigemExecucao.voz : OrigemExecucao.digitado,
    ));
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
    unawaited(voz.parar());
    setState(() {
      enviando = false;
      if (recebido.trim().isNotEmpty) {
        conversa.adicionar(MensagemConversa(
          autor: 'assistant',
          texto: recebido,
          fichas: _contextoPessoaAtual.nomes,
          contextoPessoas: _contextoPessoaAtual.bloco,
        ));
      }
      _contextoPessoaAtual = const ContextoPessoasConversa.nenhum();
      parcial = '';
      aviso = recebido.trim().isEmpty
          ? 'Geração interrompida.'
          : 'Geração interrompida; o texto recebido foi mantido.';
    });
    unawaited(_persistir());
  }

  /// Refaz a última resposta: remove a resposta anterior e reenvia a mesma pergunta.
  Future<void> _regenerar() async {
    if (enviando || conversa.mensagens.isEmpty) return;
    if (!conversa.mensagens.last.doUsuario) {
      conversa.mensagens.removeLast();
    }
    if (conversa.mensagens.isEmpty || !conversa.mensagens.last.doUsuario) {
      return;
    }
    composer.text = conversa.mensagens.last.texto;
    await _enviar();
  }

  Future<void> _falar(String texto, {bool avisar = false}) async {
    if (!vozAtiva || !mounted) return;
    final falou = await voz.falar(texto);
    if (!falou && avisar && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'A voz do aparelho não está disponível. Instale ou atualize a síntese de voz do Android.')));
    }
  }

  Future<void> _copiar(String texto) async {
    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Resposta copiada.')));
  }

  Future<void> _compartilhar() async {
    final texto = conversa.mensagens
        .map((m) => '${m.doUsuario ? 'Você' : 'J.A.R.V.I.S.'}: ${m.texto}')
        .join('\n\n');
    if (texto.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ainda não há conversa para compartilhar.')));
      return;
    }
    final enviado = await SistemaAndroid.compartilhar(texto);
    if (!mounted) return;
    if (!enviado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Compartilhar não está disponível nesta plataforma.')),
      );
    }
  }

  Future<void> _abrirHistorico() async {
    final atual = store;
    if (atual == null) return;
    await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => HistoricoPage(store: atual)));
    if (!mounted) return;
    setState(() {});
    await _persistir();
  }

  @override
  void dispose() {
    unawaited(_calarSub?.cancel() ?? Future<void>.value());
    unawaited(_assinatura?.cancel() ?? Future<void>.value());
    unawaited(voz.parar());
    composer.dispose();
    service.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title:
            Text(conversa.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: vozAtiva ? 'Silenciar respostas' : 'Falar respostas',
            onPressed: () {
              setState(() => vozAtiva = !vozAtiva);
              if (!vozAtiva) unawaited(voz.parar());
            },
            icon: Icon(
                vozAtiva ? Icons.volume_up_rounded : Icons.volume_off_rounded),
          ),
          IconButton(
            tooltip: 'Compartilhar conversa',
            onPressed: _compartilhar,
            icon: const Icon(Icons.share_rounded),
          ),
          IconButton(
            tooltip: 'Histórico de conversas',
            onPressed: store == null ? null : _abrirHistorico,
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(
            tooltip: 'Modo voz em tela cheia',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) =>
                      VozTelaCheiaPage(controller: jarvisKwsController)),
            ),
            icon: const Icon(Icons.fullscreen_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.initialCommand.trim().isNotEmpty) _origem(colors),
                if (provedorNome != null &&
                    (parcial.isNotEmpty ||
                        conversa.mensagens.any((m) => !m.doUsuario)))
                  Text('Resposta via $provedorNome',
                      style: const TextStyle(
                          color: Color(0xFF55DFFF), fontSize: 10)),
                if (conversa.mensagens.isEmpty &&
                    !enviando &&
                    erro == null &&
                    parcial.isEmpty)
                  _vazio(colors),
                for (final mensagem in conversa.mensagens)
                  _bolha(mensagem, colors),
                if (enviando && parcial.isNotEmpty)
                  _bolha(const MensagemConversa(autor: 'assistant', texto: ''),
                      colors,
                      textoEmCurso: parcial),
                if (!enviando &&
                    conversa.mensagens.isNotEmpty &&
                    !conversa.mensagens.last.doUsuario)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _regenerar,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Regenerar resposta',
                          style: TextStyle(fontSize: 11)),
                    ),
                  ),
                if (enviando)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(children: [
                      SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('J.A.R.V.I.S. está processando…',
                          style: TextStyle(fontSize: 11)),
                    ]),
                  ),
                if (aviso != null) ...[
                  const SizedBox(height: 10),
                  Text(aviso!,
                      style: const TextStyle(
                          color: Color(0xFFFFC66D), fontSize: 11, height: 1.4)),
                ],
                if (erro != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: colors.errorContainer.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                          color: colors.error.withValues(alpha: .35)),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.cloud_off_rounded,
                                color: colors.error, size: 18),
                            const SizedBox(width: 8),
                            Text('Não foi possível responder',
                                style: TextStyle(
                                    color: colors.error,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ]),
                          const SizedBox(height: 6),
                          Text(erro!,
                              style: const TextStyle(
                                  fontSize: 11.5, height: 1.45)),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: enviando ? null : () => _enviar(),
                              icon: const Icon(Icons.refresh_rounded, size: 17),
                              label: const Text('Tentar de novo'),
                            ),
                          ),
                        ]),
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
                      onChanged: (valor) =>
                          unawaited(store?.salvarRascunho(valor)),
                      decoration: InputDecoration(
                        hintText: 'Digite uma mensagem…',
                        filled: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none),
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
        margin: const EdgeInsets.only(bottom: 12),
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
                  Text(
                      widget.fromVoice
                          ? 'Comando capturado por voz'
                          : 'Comando digitado',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 5),
                  Text(widget.initialCommand,
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 5),
                  Text(
                      widget.fromVoice
                          ? 'Reconhecimento de fala no dispositivo · pt-BR'
                          : 'Enviado pelo campo de conversa',
                      style: const TextStyle(color: Colors.grey, fontSize: 10)),
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
            Text('A conversa começa com o comando acima.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            SizedBox(height: 5),
            Text(
                'A resposta aparece aos poucos; você pode interromper a geração a qualquer momento.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Colors.grey, fontSize: 11, height: 1.4)),
          ],
        ),
      );

  Widget _bolha(MensagemConversa mensagem, ColorScheme colors,
      {String? textoEmCurso}) {
    final texto = textoEmCurso ?? mensagem.texto;
    final showFontes = mensagem.fontes.isNotEmpty;
    return Align(
      alignment:
          mensagem.doUsuario ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.only(top: 9),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: mensagem.doUsuario
              ? const Color(0xFF123047)
              : colors.surfaceContainerHighest.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(texto, style: const TextStyle(fontSize: 13, height: 1.45)),
            if (mensagem.contextoPessoas.isNotEmpty) ...[
              const SizedBox(height: 6),
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: Material(
                  color: Colors.transparent,
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(top: 2),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    iconColor: const Color(0xFF55DFFF),
                    collapsedIconColor: const Color(0xFF55DFFF),
                    title: Text(
                      mensagem.fichas.isEmpty
                          ? 'Fichas: nenhuma correspondência'
                          : mensagem.fichas.length == 1
                              ? 'Ficha usada: ${mensagem.fichas.single}'
                              : 'Fichas citadas: ${mensagem.fichas.join(', ')}',
                      style: const TextStyle(
                          color: Color(0xFF55DFFF), fontSize: 10),
                    ),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          mensagem.contextoPessoas,
                          style: const TextStyle(fontSize: 10.5, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (showFontes) ...[
              const SizedBox(height: 6),
              Text('O que lembrei: ${mensagem.fontes.join(', ')}',
                  style:
                      const TextStyle(color: Color(0xFF55DFFF), fontSize: 10)),
            ],
            if (mensagem.habilidades.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Habilidades usadas: ${mensagem.habilidades.join(', ')}',
                  style:
                      const TextStyle(color: Color(0xFF55DFFF), fontSize: 10)),
            ],
            if (!mensagem.doUsuario && textoEmCurso == null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Ouvir resposta',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _falar(texto, avisar: true),
                      icon: const Icon(Icons.volume_up_rounded, size: 16),
                    ),
                    IconButton(
                      tooltip: 'Copiar resposta',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _copiar(texto),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                    ),
                  ],
                ),
              ),
            ],
            if (textoEmCurso != null) ...[
              const SizedBox(height: 6),
              const Text('recebendo…',
                  style: TextStyle(color: Colors.grey, fontSize: 9)),
            ],
          ],
        ),
      ),
    );
  }
}
