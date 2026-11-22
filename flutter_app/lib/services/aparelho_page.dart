import 'package:material_ui/material_ui.dart';

import '../core/aparelho.dart';
import '../core/pessoas.dart';
import '../core/resumo_tatico.dart';
import '../ui_common.dart';
import 'aparelho_service.dart';
import 'pessoas_store.dart';
import 'resumo_ia_service.dart';
import 'voz_jarvis.dart';

/// Painel único das capacidades do aparelho: status, notificações, mensagens,
/// Spotify, contatos, ligações e fichas de pessoas.
class AparelhoPage extends StatefulWidget {
  const AparelhoPage({
    super.key,
    this.servico,
    this.storePessoas,
    this.resumoIa,
    this.ativo = true,
  });

  final AparelhoService? servico;
  final PessoasStore? storePessoas;

  /// Resumo tático por IA; nulo usa o provedor configurado no aparelho.
  final ResumoIaService? resumoIa;

  /// Falso em teste/plataforma sem a ponte Android.
  final bool ativo;

  @override
  State<AparelhoPage> createState() => _AparelhoPageState();
}

class _AparelhoPageState extends State<AparelhoPage> {
  late final AparelhoService servico = widget.servico ?? AparelhoService();

  EstadoAparelho estado = const EstadoAparelho();
  bool acessoNotificacoes = false;
  List<NotificacaoAparelho> notificacoes = const [];
  List<AppMensagem> apps = const [];
  AppMensagem? appEscolhido;
  List<ContatoAparelho> contatos = const [];
  List<Pessoa> pessoas = const [];
  ResultadoAparelho? resultado;
  Pessoa? fichaEmEdicao;
  bool ocupado = false;
  bool pessoasCarregadas = false;
  ResumoTatico? resumo;
  String? erroResumo;
  String provedorResumo = '';
  bool resumindo = false;

  final campoDestino = TextEditingController();
  final campoTexto = TextEditingController();
  final campoFaixa = TextEditingController();
  final campoContato = TextEditingController();
  final campoNomeFicha = TextEditingController();
  final campoRelacao = TextEditingController();
  final campoPreferencias = TextEditingController();
  final campoObservacoes = TextEditingController();
  bool consentimento = false;

  @override
  void initState() {
    super.initState();
    if (widget.ativo) _atualizarTudo();
  }

  @override
  void dispose() {
    campoDestino.dispose();
    campoTexto.dispose();
    campoFaixa.dispose();
    campoContato.dispose();
    campoNomeFicha.dispose();
    campoRelacao.dispose();
    campoPreferencias.dispose();
    campoObservacoes.dispose();
    super.dispose();
  }

  Future<void> _executar(Future<ResultadoAparelho> Function() acao) async {
    if (ocupado) return;
    setState(() {
      ocupado = true;
      resultado = null;
    });
    ResultadoAparelho resposta;
    try {
      resposta = await acao();
    } on AparelhoIndisponivel catch (erro) {
      resposta = ResultadoAparelho.erro(erro.mensagem);
    } catch (_) {
      resposta =
          const ResultadoAparelho.erro('Não foi possível concluir no Android.');
    }
    if (!mounted) return;
    setState(() {
      ocupado = false;
      resultado = resposta;
    });
  }

  Future<void> _atualizarTudo() async {
    if (!widget.ativo) return;
    try {
      final novoEstado = await servico.status();
      final acesso = await servico.temAcessoNotificacoes();
      final instalados = await servico.appsDisponiveis();
      final lista = acesso ? await servico.notificacoes() : const <NotificacaoAparelho>[];
      final fichas = widget.storePessoas == null
          ? pessoas
          : await widget.storePessoas!.listar();
      if (!mounted) return;
      setState(() {
        estado = novoEstado;
        acessoNotificacoes = acesso;
        apps = instalados;
        appEscolhido ??= instalados.isEmpty ? null : instalados.first;
        notificacoes = lista;
        pessoas = fichas;
        pessoasCarregadas = true;
      });
    } on AparelhoIndisponivel catch (erro) {
      if (!mounted) return;
      setState(() {
        resultado = ResultadoAparelho.erro(erro.mensagem);
        pessoasCarregadas = true;
      });
    }
  }

  void _enviarMensagem() {
    final app = appEscolhido;
    if (app == null) {
      setState(() => resultado = const ResultadoAparelho.erro(
          'Nenhum app de mensagem instalado foi encontrado.'));
      return;
    }
    final pedido = PedidoMensagem(
      app: app,
      destino: campoDestino.text,
      texto: campoTexto.text,
    );
    _executar(() => servico.enviarMensagem(pedido));
  }

  void _spotify(PedidoSpotify pedido) => _executar(() => servico.spotify(pedido));

  Future<void> _buscarContatos() async {
    if (ocupado) return;
    setState(() => ocupado = true);
    try {
      final achados = await servico.buscarContatos(campoContato.text.trim());
      if (!mounted) return;
      setState(() {
        ocupado = false;
        contatos = achados;
        if (achados.isEmpty) {
          resultado = const ResultadoAparelho.erro(
              'Nenhum contato do aparelho corresponde a esse nome.');
        } else {
          resultado = ResultadoAparelho(
              ok: true,
              mensagem: '${achados.length} contato(s) encontrado(s) no aparelho.');
        }
      });
    } on AparelhoIndisponivel catch (erro) {
      if (!mounted) return;
      setState(() {
        ocupado = false;
        resultado = ResultadoAparelho.erro(erro.mensagem);
      });
    }
  }

  void _prepararFicha(ContatoAparelho contato) {
    final ficha = fichaDeContato(contato);
    setState(() {
      fichaEmEdicao = ficha;
      campoNomeFicha.text = ficha.nome;
      campoRelacao.clear();
      campoPreferencias.clear();
      campoObservacoes.clear();
      consentimento = false;
    });
  }

  Future<void> _salvarFicha() async {
    final base = fichaEmEdicao;
    if (base == null) return;
    final ficha = base.copiarCom(
      nome: campoNomeFicha.text,
      relacao: campoRelacao.text,
      preferencias: campoPreferencias.text,
      observacoes: campoObservacoes.text,
      consentimento: consentimento,
    );
    final store = widget.storePessoas;
    if (store == null) {
      setState(() => resultado = const ResultadoAparelho.erro(
          'O armazenamento de fichas não está disponível aqui.'));
      return;
    }
    final salvo = await store.salvar(ficha);
    if (!mounted) return;
    if (!salvo.ok) {
      setState(() => resultado = ResultadoAparelho.erro(salvo.erro!));
      return;
    }
    setState(() {
      fichaEmEdicao = null;
      resultado = const ResultadoAparelho(
          ok: true, mensagem: 'Ficha criada no aparelho.');
    });
    _atualizarTudo();
  }

  /// Uma linha por notificação: texto, leitura em voz alta e, quando o
  /// Android informou um campo de resposta, o botão de responder sem abrir o app.
  List<Widget> _linhasNotificacoes() {
    final visiveis = notificacoes.take(8).toList();
    return [
      for (var i = 0; i < visiveis.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                    '${visiveis[i].app}: ${visiveis[i].titulo} ${visiveis[i].texto}'
                        .trim(),
                    style: const TextStyle(fontSize: 10.5, color: muted)),
              ),
              IconButton(
                key: ValueKey('notificacao-$i-ler'),
                tooltip: 'Ler esta mensagem em voz alta',
                visualDensity: VisualDensity.compact,
                onPressed: () => _lerNotificacoes([visiveis[i]]),
                icon: const Icon(Icons.volume_up_outlined, size: 17),
              ),
              if (visiveis[i].respondivel)
                IconButton(
                  key: ValueKey('notificacao-$i-responder'),
                  tooltip: 'Responder sem abrir o aplicativo',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _responder(visiveis[i]),
                  icon: const Icon(Icons.reply_rounded, size: 17),
                ),
            ],
          ),
        ),
    ];
  }

  /// Lê as mensagens em voz alta, uma por vez (padrão: as cinco mais recentes).
  Future<void> _lerNotificacoes([List<NotificacaoAparelho>? quais]) async {
    final frases = frasesDeLeitura(quais ?? notificacoes,
        limite: quais == null ? 5 : 1);
    if (frases.isEmpty) return;
    final voz = const VozJarvis();
    for (final frase in frases) {
      final falou = await voz.falar(frase);
      if (falou) continue;
      if (!mounted) return;
      setState(() => resultado = const ResultadoAparelho.erro(
          'A síntese de voz do Android não está disponível neste aparelho; '
          'a mensagem está escrita na tela.'));
      return;
    }
  }

  /// Pede ao provedor configurado o resumo tático: o que é urgente, o que é
  /// ruído de grupo e o que responder. Sem provedor, a triagem local aparece.
  Future<void> _resumir() async {
    if (resumindo || ocupado) return;
    if (notificacoes.isEmpty) {
      setState(() => erroResumo =
          'Nenhuma notificação lida ainda. Toque em “Ler de novo” antes.');
      return;
    }
    setState(() {
      resumindo = true;
      erroResumo = null;
    });
    ResumoIaService servicoResumo;
    try {
      servicoResumo = widget.resumoIa ?? ResumoIaService();
      final resposta = await servicoResumo.resumir(notificacoes);
      if (!mounted) return;
      setState(() {
        resumindo = false;
        resumo = resposta.resumo;
        erroResumo = resposta.erro;
        provedorResumo = resposta.provedor;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        resumindo = false;
        erroResumo = 'Não foi possível pedir o resumo agora.';
      });
    }
  }

  /// Abre a resposta da notificação que originou a sugestão, já com o texto.
  Future<void> _responderSugestao(SugestaoResposta sugestao) async {
    final alvo = notificacaoParaResponder(notificacoes, app: sugestao.app) ??
        notificacaoParaResponder(notificacoes);
    if (alvo == null) {
      setState(() => erroResumo = 'Nenhuma notificação dessas aceita resposta '
          'direta pelo Android. Abra o aplicativo para responder.');
      return;
    }
    await _responder(alvo, textoInicial: sugestao.texto);
  }

  /// Resposta direta na notificação, sem abrir WhatsApp/Telegram/SMS.
  Future<void> _responder(NotificacaoAparelho n,
      {String textoInicial = ''}) async {
    final texto = await showDialog<String>(
      context: context,
      builder: (_) =>
          _DialogoResposta(notificacao: n, textoInicial: textoInicial),
    );
    if (texto == null || texto.trim().isEmpty) return;
    await _executar(() => servico.responderNotificacao(
        texto: texto, chave: n.chave, pacote: n.pacote));
  }

  /// Cartão do resumo tático: texto curto, urgentes, ruído filtrado e
  /// respostas sugeridas com o botão de usar em cada uma.
  Widget _cartaoResumo() {
    final r = resumo;
    final erro = erroResumo;
    if (r == null && erro == null) return const SizedBox.shrink();
    return _cartao(
      titulo: 'RESUMO TÁTICO DAS MENSAGENS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (r != null) ...[
            Text(r.resumo,
                key: const ValueKey('resumo-texto'),
                style: const TextStyle(fontSize: 11.5, height: 1.45)),
            if (!r.daIa)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                    'Sem IA: triagem local por palavras de urgência e sinais de grupo.',
                    style: TextStyle(fontSize: 10, color: muted, height: 1.4)),
              ),
            if (r.urgentes.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('URGENTE',
                  style: TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 1.2,
                      color: Color(0xFFFF8A80),
                      fontWeight: FontWeight.w700)),
              for (final item in r.urgentes)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.priority_high_rounded,
                          size: 14, color: Color(0xFFFF8A80)),
                      const SizedBox(width: 4),
                      Expanded(
                          child: Text(item,
                              style: const TextStyle(
                                  fontSize: 11, height: 1.4))),
                    ],
                  ),
                ),
            ],
            if (r.ruido.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Ruído de grupo filtrado (${r.ruido.length})',
                  style: const TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 1.1,
                      color: muted,
                      fontWeight: FontWeight.w700)),
              for (final item in r.ruido.take(4))
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text('· $item',
                      style: const TextStyle(
                          fontSize: 10.5, color: muted, height: 1.35)),
                ),
            ],
            if (r.respostas.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('RESPOSTAS SUGERIDAS',
                  style: TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 1.2,
                      color: cyan,
                      fontWeight: FontWeight.w700)),
              for (var i = 0; i < r.respostas.length; i++)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                            '${r.respostas[i].app.isEmpty ? 'Mensagem' : r.respostas[i].app}: '
                            '${r.respostas[i].texto}',
                            style: const TextStyle(
                                fontSize: 11, height: 1.4)),
                      ),
                    ),
                    TextButton(
                      key: ValueKey('resumo-sugestao-$i'),
                      onPressed: ocupado
                          ? null
                          : () => _responderSugestao(r.respostas[i]),
                      child: const Text('Usar',
                          style: TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
            ],
            if (provedorResumo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Resumo via $provedorResumo',
                    style: const TextStyle(fontSize: 9.5, color: muted)),
              ),
          ],
          if (erro != null) ...[
            const SizedBox(height: 8),
            Text(erro,
                key: const ValueKey('resumo-erro'),
                style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFFFFC66D),
                    height: 1.4)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Aparelho conectado',
              style: TextStyle(fontSize: 15))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _cartao(
            titulo: 'STATUS DO APARELHO',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(estado.descrever(),
                    key: const ValueKey('aparelho-status'),
                    style: const TextStyle(fontSize: 11.5, height: 1.45)),
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const ValueKey('aparelho-atualizar'),
                  onPressed: ocupado ? null : _atualizarTudo,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Ler de novo', style: TextStyle(fontSize: 10)),
                ),
              ],
            ),
          ),
          _cartao(
            titulo: 'NOTIFICAÇÕES DO APARELHO',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  acessoNotificacoes
                      ? 'Acesso concedido: o Jarvis lê as notificações deste aparelho.'
                      : 'Sem acesso. Autorize em Configurações → Notificações → JARVIS Nova.',
                  style: const TextStyle(fontSize: 11, color: muted, height: 1.45),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton.icon(
                    key: const ValueKey('aparelho-notificacoes-permitir'),
                    onPressed: ocupado
                        ? null
                        : () => _executar(servico.abrirAjustesNotificacoes),
                    icon: const Icon(Icons.notifications_active_outlined,
                        size: 18),
                    label: const Text('Autorizar acesso',
                        style: TextStyle(fontSize: 10)),
                  ),
                  OutlinedButton(
                    key: const ValueKey('aparelho-notificacoes-limpar'),
                    onPressed:
                        ocupado ? null : () => _executar(servico.limparNotificacoes),
                    child: const Text('Limpar leitura',
                        style: TextStyle(fontSize: 10)),
                  ),
                ]),
                if (notificacoes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('aparelho-notificacoes-ler'),
                    onPressed: ocupado ? null : _lerNotificacoes,
                    icon: const Icon(Icons.volume_up_rounded, size: 17),
                    label: const Text('Ler em voz alta',
                        style: TextStyle(fontSize: 10)),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: const ValueKey('aparelho-notificacoes-resumo'),
                    onPressed: (ocupado || resumindo) ? null : _resumir,
                    icon: resumindo
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome_rounded, size: 17),
                    label: Text(
                        resumindo
                            ? 'Resumindo as mensagens…'
                            : 'Resumo tático por IA',
                        style: const TextStyle(fontSize: 10)),
                  ),
                  const SizedBox(height: 8),
                  ..._linhasNotificacoes(),
                ] else if (acessoNotificacoes)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Nenhuma notificação guardada ainda.',
                        style: TextStyle(fontSize: 10.5, color: muted)),
                  ),
              ],
            ),
          ),
          _cartaoResumo(),
          _cartao(
            titulo: 'MENSAGEM POR QUALQUER APP',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<AppMensagem>(
                  key: const ValueKey('mensagem-app'),
                  initialValue: appEscolhido,
                  decoration: const InputDecoration(
                      labelText: 'App',
                      filled: true,
                      fillColor: panel,
                      border: OutlineInputBorder()),
                  items: [
                    for (final app in apps.isEmpty ? appsMensagem : apps)
                      DropdownMenuItem(value: app, child: Text(app.nome)),
                  ],
                  onChanged: (app) => setState(() => appEscolhido = app),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('mensagem-destino'),
                  controller: campoDestino,
                  decoration: const InputDecoration(
                      labelText: 'Para quem (nome ou número)',
                      filled: true,
                      fillColor: panel,
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('mensagem-texto'),
                  controller: campoTexto,
                  maxLines: 4,
                  decoration: const InputDecoration(
                      labelText: 'Texto exato da mensagem',
                      filled: true,
                      fillColor: panel,
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const ValueKey('mensagem-enviar'),
                  onPressed: ocupado ? null : _enviarMensagem,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Enviar', style: TextStyle(fontSize: 10)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'O WhatsApp, Discord, Instagram e Gmail não aceitam envio silencioso: '
                  'o Jarvis abre a conversa com o texto exato e você toca em enviar. '
                  'O SMS sai direto pelo aparelho.',
                  style: TextStyle(fontSize: 9.5, color: muted, height: 1.4),
                ),
              ],
            ),
          ),
          _cartao(
            titulo: 'SPOTIFY',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton(
                    key: const ValueKey('spotify-pausar'),
                    onPressed: ocupado
                        ? null
                        : () => _spotify(const PedidoSpotify(AcaoSpotify.pausar)),
                    child: const Text('Pausar', style: TextStyle(fontSize: 10)),
                  ),
                  FilledButton(
                    key: const ValueKey('spotify-continuar'),
                    onPressed: ocupado
                        ? null
                        : () =>
                            _spotify(const PedidoSpotify(AcaoSpotify.continuar)),
                    child: const Text('Continuar', style: TextStyle(fontSize: 10)),
                  ),
                  FilledButton(
                    key: const ValueKey('spotify-proxima'),
                    onPressed: ocupado
                        ? null
                        : () => _spotify(const PedidoSpotify(AcaoSpotify.proxima)),
                    child: const Text('Avançar', style: TextStyle(fontSize: 10)),
                  ),
                  FilledButton(
                    key: const ValueKey('spotify-anterior'),
                    onPressed: ocupado
                        ? null
                        : () => _spotify(const PedidoSpotify(AcaoSpotify.anterior)),
                    child: const Text('Voltar', style: TextStyle(fontSize: 10)),
                  ),
                  FilledButton(
                    key: const ValueKey('spotify-reiniciar'),
                    onPressed: ocupado
                        ? null
                        : () =>
                            _spotify(const PedidoSpotify(AcaoSpotify.reiniciar)),
                    child: const Text('Reiniciar', style: TextStyle(fontSize: 10)),
                  ),
                ]),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('spotify-faixa'),
                  controller: campoFaixa,
                  decoration: const InputDecoration(
                      labelText: 'Música pedida',
                      filled: true,
                      fillColor: panel,
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const ValueKey('spotify-tocar'),
                  onPressed: ocupado
                      ? null
                      : () => _spotify(PedidoSpotify(AcaoSpotify.tocar,
                          faixa: campoFaixa.text)),
                  icon: const Icon(Icons.music_note_rounded, size: 18),
                  label: const Text('Tocar pedida', style: TextStyle(fontSize: 10)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tocar a faixa usa a busca de mídia do Android '
                  '(MEDIA_PLAY_FROM_SEARCH) e a sessão ativa: o Spotify escolhe o '
                  'melhor resultado e o Jarvis confere o título antes de dizer '
                  '"tocando". O Android não deixa enfileirar uma faixa arbitrária '
                  'por fora do app; com um link spotify:track:… o Jarvis manda a '
                  'URI exata pela sessão.',
                  style: TextStyle(fontSize: 9.5, color: muted),
                ),
              ],
            ),
          ),
          _cartao(
            titulo: 'CONTATOS E LIGAÇÕES',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const ValueKey('contato-busca'),
                  controller: campoContato,
                  decoration: const InputDecoration(
                      labelText: 'Nome do contato',
                      filled: true,
                      fillColor: panel,
                      border: OutlineInputBorder()),
                  onSubmitted: (_) => _buscarContatos(),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton.icon(
                    key: const ValueKey('contato-buscar'),
                    onPressed: ocupado ? null : _buscarContatos,
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: const Text('Buscar no aparelho',
                        style: TextStyle(fontSize: 10)),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('contato-pedir-permissao'),
                    onPressed: ocupado
                        ? null
                        : () => _executar(() => servico.pedirPermissao('contatos')),
                    icon: const Icon(Icons.contacts_outlined, size: 18),
                    label: const Text('Autorizar contatos',
                        style: TextStyle(fontSize: 10)),
                  ),
                ]),
                for (final c in contatos.take(6))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.nome, style: const TextStyle(fontSize: 12)),
                    subtitle: Text(
                        c.telefones.isEmpty ? 'sem telefone' : c.telefones.join(', '),
                        style: const TextStyle(fontSize: 10)),
                    trailing: Wrap(spacing: 4, children: [
                      IconButton(
                        tooltip: 'Ligar',
                        icon: const Icon(Icons.call_rounded, size: 18),
                        onPressed: ocupado
                            ? null
                            : () => _executar(() => servico.ligar(
                                c.primeiroTelefone.isEmpty
                                    ? c.nome
                                    : c.primeiroTelefone)),
                      ),
                      IconButton(
                        tooltip: 'Criar ficha',
                        icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                        onPressed: () => _prepararFicha(c),
                      ),
                    ]),
                  ),
              ],
            ),
          ),
          _cartao(
            titulo: 'PESSOAS E FICHAS',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pessoasCarregadas
                      ? pessoas.isEmpty
                          ? 'Nenhuma ficha guardada ainda. Busque no aparelho e crie a primeira.'
                          : '${pessoas.length} ficha(s) guardada(s): '
                              '${pessoas.take(8).map((p) => p.nome).join(', ')}'
                      : 'Lendo as fichas…',
                  key: const ValueKey('pessoas-resumo'),
                  style: const TextStyle(fontSize: 11, color: muted, height: 1.45),
                ),
                if (fichaEmEdicao != null) ...[
                  const SizedBox(height: 10),
                  Text('FICHA NVA · ${fichaEmEdicao!.nome}',
                      style: const TextStyle(
                          color: cyan,
                          fontSize: 9,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  for (final pergunta in perguntasBasicasPessoa.take(4))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $pergunta',
                          style: const TextStyle(fontSize: 10, color: muted)),
                    ),
                  const SizedBox(height: 6),
                  TextField(
                    key: const ValueKey('ficha-nome'),
                    controller: campoNomeFicha,
                    decoration: const InputDecoration(
                        labelText: 'Nome ou apelido', filled: true, fillColor: panel),
                  ),
                  TextField(
                    key: const ValueKey('ficha-relacao'),
                    controller: campoRelacao,
                    decoration: const InputDecoration(
                        labelText: 'Relação', filled: true, fillColor: panel),
                  ),
                  TextField(
                    key: const ValueKey('ficha-preferencias'),
                    controller: campoPreferencias,
                    decoration: const InputDecoration(
                        labelText: 'Preferências', filled: true, fillColor: panel),
                  ),
                  TextField(
                    key: const ValueKey('ficha-observacoes'),
                    controller: campoObservacoes,
                    decoration: const InputDecoration(
                        labelText: 'Observações', filled: true, fillColor: panel),
                  ),
                  Row(
                    key: const ValueKey('ficha-consentimento'),
                    children: [
                      Checkbox(
                        value: consentimento,
                        onChanged: (v) =>
                            setState(() => consentimento = v ?? false),
                      ),
                      const Expanded(
                        child: Text(
                            'Tenho o consentimento desta pessoa para guardar estas informações.',
                            style: TextStyle(fontSize: 10)),
                      ),
                    ],
                  ),
                  FilledButton(
                    key: const ValueKey('ficha-salvar'),
                    onPressed: _salvarFicha,
                    child: const Text('Salvar ficha', style: TextStyle(fontSize: 10)),
                  ),
                ],
              ],
            ),
          ),
          if (resultado != null)
            Container(
              key: const ValueKey('aparelho-resultado'),
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: resultado!.ok
                    ? const Color(0xFF0D2118)
                    : const Color(0xFF211A10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: (resultado!.ok
                            ? const Color(0xFF65D49A)
                            : const Color(0xFFFFC66D))
                        .withValues(alpha: .3)),
              ),
              child: Text(resultado!.mensagem,
                  style: const TextStyle(fontSize: 11.5, height: 1.45)),
            ),
          const SizedBox(height: 14),
          const Text(
            'Limites reais: nenhum app de terceiro aceita enviar mensagem sem '
            'confirmação; o Jarvis preenche o texto exato e você toca em enviar. '
            'O Spotify é controlado pela sessão de mídia ativa, com o app aberto. '
            'Nada usa root, ADB ou permissão de todos os arquivos.',
            style: TextStyle(fontSize: 9.5, color: muted, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _cartao({required String titulo, required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cyan.withValues(alpha: .2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: const TextStyle(
                    color: cyan,
                    fontSize: 9,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
}

class _DialogoResposta extends StatefulWidget {
  const _DialogoResposta({required this.notificacao, this.textoInicial = ''});
  final NotificacaoAparelho notificacao;

  /// Sugestão da IA já pronta para editar antes de enviar.
  final String textoInicial;

  @override
  State<_DialogoResposta> createState() => _DialogoRespostaState();
}

class _DialogoRespostaState extends State<_DialogoResposta> {
  late final TextEditingController campo =
      TextEditingController(text: widget.textoInicial);

  @override
  void dispose() {
    campo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notificacao;
    return AlertDialog(
      title: Text('Responder em ${n.app}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(n.fraseLeitura,
              style: const TextStyle(fontSize: 12, height: 1.4)),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('resposta-texto'),
            controller: campo,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Resposta', hintText: 'Ex.: chego em 10 minutos'),
          ),
          const SizedBox(height: 8),
          const Text(
            'A resposta vai pelo campo da própria notificação; o aplicativo '
            'não é aberto.',
            style: TextStyle(fontSize: 10.5, color: muted, height: 1.35),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        FilledButton(
          key: const ValueKey('resposta-enviar'),
          onPressed: () => Navigator.of(context).pop(campo.text),
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}
