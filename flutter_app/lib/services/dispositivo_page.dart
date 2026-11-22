import 'package:material_ui/material_ui.dart';

import '../core/aparelho.dart';
import '../core/dispositivo.dart';
import '../core/localizacao.dart';
import '../ui_common.dart';
import 'aparelho_service.dart';
import 'voz_jarvis.dart';

/// Central do aparelho — status, notificações e localização.
///
/// Mostra memória, armazenamento, bateria, rede, tempo ligado, a lista real de
/// apps, as notificações que o Android entregou ao JARVIS e a localização do
/// aparelho quando o usuário pede. Tudo vem do canal nativo; o que não foi
/// informado aparece como "não informado", nunca como número inventado.
class DispositivoPage extends StatefulWidget {
  const DispositivoPage({super.key, this.servico});

  final AparelhoService? servico;

  @override
  State<DispositivoPage> createState() => _DispositivoPageState();
}

class _DispositivoPageState extends State<DispositivoPage> {
  late final AparelhoService _servico = widget.servico ?? AparelhoService();
  InfoDispositivo? _info;
  String? _erro;
  bool _carregando = true;
  String _busca = '';

  bool _acessoNotificacoes = false;
  List<NotificacaoAparelho> _notificacoes = const [];
  bool _carregandoNotificacoes = false;

  EstadoLocalizacao _estadoLocalizacao = EstadoLocalizacao.desconhecido;
  LocalizacaoAparelho? _localizacao;
  bool _carregandoLocalizacao = false;
  String? _erroLocalizacao;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final info = await _servico.infoDispositivo();
      if (!mounted) return;
      setState(() {
        _info = info;
        _carregando = false;
      });
    } on AparelhoIndisponivel catch (erro) {
      if (!mounted) return;
      setState(() {
        _erro = erro.mensagem;
        _carregando = false;
      });
    }
    await _carregarNotificacoes();
    await _carregarEstadoLocalizacao();
  }

  Future<void> _carregarNotificacoes() async {
    if (_carregandoNotificacoes) return;
    setState(() => _carregandoNotificacoes = true);
    try {
      final acesso = await _servico.temAcessoNotificacoes();
      final lista =
          acesso ? await _servico.notificacoes(limite: 12) : const <NotificacaoAparelho>[];
      if (!mounted) return;
      setState(() {
        _acessoNotificacoes = acesso;
        _notificacoes = lista;
        _carregandoNotificacoes = false;
      });
    } on AparelhoIndisponivel {
      if (!mounted) return;
      setState(() => _carregandoNotificacoes = false);
    }
  }

  Future<void> _carregarEstadoLocalizacao() async {
    try {
      final estado = await _servico.estadoLocalizacao();
      if (!mounted) return;
      setState(() => _estadoLocalizacao = estado);
    } on AparelhoIndisponivel {
      // Fora do Android a seção explica pela própria descrição do estado.
    }
  }

  Future<void> _autorizarNotificacoes() async {
    try {
      await _servico.abrirAjustesNotificacoes();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Autorize o JARVIS Nova em “Acesso a notificações” e volte para atualizar.'),
      ));
    } on AparelhoIndisponivel catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro.mensagem)));
    }
  }

  Future<void> _limparNotificacoes() async {
    try {
      await _servico.limparNotificacoes();
      if (!mounted) return;
      setState(() => _notificacoes = const []);
    } on AparelhoIndisponivel {
      // A lista já está vazia; nada a corrigir.
    }
  }

  Future<void> _verLocalizacao() async {
    if (_carregandoLocalizacao) return;
    setState(() {
      _carregandoLocalizacao = true;
      _erroLocalizacao = null;
    });
    try {
      if (!_estadoLocalizacao.permissao) {
        final pedido = await _servico.pedirPermissao('localizacao');
        if (!pedido.ok) {
          if (!mounted) return;
          setState(() {
            _carregandoLocalizacao = false;
            _erroLocalizacao = pedido.mensagem;
          });
          return;
        }
      }
      final local = await _servico.localizacao();
      final estado = await _servico.estadoLocalizacao();
      if (!mounted) return;
      setState(() {
        _localizacao = local;
        _estadoLocalizacao = estado;
        _carregandoLocalizacao = false;
        _erroLocalizacao = local.valida ? null : local.mensagem;
      });
    } on AparelhoIndisponivel catch (erro) {
      if (!mounted) return;
      setState(() {
        _carregandoLocalizacao = false;
        _erroLocalizacao = erro.mensagem;
      });
    }
  }

  Future<void> _ouvirLocalizacao() async {
    final local = _localizacao;
    if (local == null) return;
    final falou = await const VozJarvis().falar(fraseLocalizacao(local));
    if (!mounted) return;
    if (!falou) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('A síntese de voz do Android não está disponível neste aparelho.'),
      ));
    }
  }

  Future<void> _abrir(String pacote, String nome) async {
    try {
      final resultado = await _servico.abrirApp(pacote);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(resultado.mensagem.isEmpty
            ? (resultado.ok ? '$nome aberto.' : 'Não consegui abrir $nome.')
            : resultado.mensagem),
      ));
    } on AparelhoIndisponivel catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro.mensagem)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final busca = _busca.trim().toLowerCase();
    final apps = info == null
        ? const <AppInstalado>[]
        : (busca.isEmpty
            ? info.apps
            : info.apps
                .where((a) =>
                    a.nome.toLowerCase().contains(busca) ||
                    a.pacote.toLowerCase().contains(busca))
                .toList());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Central do aparelho',
            style: TextStyle(fontSize: 15)),
        actions: [
          IconButton(
            key: const ValueKey('atualizar-dispositivo'),
            onPressed: _carregando ? null : _carregar,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (_carregando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_erro != null)
          _aviso(_erro!, const Color(0xFFFF8A80))
        else if (info != null) ...[
          const Eyebrow('ESTADO DO APARELHO'),
          const SizedBox(height: 8),
          _linha('Memória', _memoria(info)),
          _linha('Armazenamento', _armazenamento(info)),
          _linha('Bateria', _bateria(info)),
          _linha('Rede', info.redeRotulo),
          _linha('Ligado há', info.uptimeRotulo),
          if (info.memoriaBaixa)
            _aviso('O Android está com pouca memória livre agora.',
                const Color(0xFFFFD27F)),
          const SizedBox(height: 18),
          _secaoNotificacoes(),
          const SizedBox(height: 18),
          _secaoLocalizacao(),
          const SizedBox(height: 18),
          Eyebrow('APPS INSTALADOS (${info.apps.length})'),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('buscar-app'),
            onChanged: (valor) => setState(() => _busca = valor),
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Buscar por nome ou pacote',
              hintStyle: const TextStyle(fontSize: 11, color: muted),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              filled: true,
              fillColor: panel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (apps.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Nenhum app encontrado com essa busca.',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ),
          for (final app in apps)
            ListTile(
              key: ValueKey('app-${app.pacote}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(app.nome, style: const TextStyle(fontSize: 12)),
              subtitle: Text(app.pacote,
                  style: const TextStyle(fontSize: 10, color: muted)),
              trailing: TextButton(
                key: ValueKey('abrir-app-${app.pacote}'),
                onPressed: () => _abrir(app.pacote, app.nome),
                child: const Text('Abrir', style: TextStyle(fontSize: 10)),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'Estes números vêm do Android (ActivityManager, StatFs, '
            'bateria, ConnectivityManager). As notificações só aparecem depois '
            'que você autoriza “Acesso a notificações”; elas ficam só na memória '
            'do app, limitadas a 80 e nunca vão para a rede. A localização é '
            'lida só quando você pede, pelo LocationManager do aparelho. '
            'Fechar outros apps, controlar janelas e pareamento com o Windows '
            'ainda não estão implementados.',
            style: TextStyle(color: muted, fontSize: 10, height: 1.5),
          ),
        ],
      ]),
    );
  }

  Widget _secaoNotificacoes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow('NOTIFICAÇÕES (${_notificacoes.length})'),
        const SizedBox(height: 8),
        Container(
          key: const ValueKey('status-notificacoes'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cyan.withValues(alpha: .18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _acessoNotificacoes
                    ? 'Acesso autorizado. Só o que o Android entregar ao JARVIS aparece aqui.'
                    : 'Sem acesso às notificações. O Android exige uma autorização separada, '
                        'em Configurações → Notificações → Acesso a notificações.',
                style: const TextStyle(fontSize: 11.5, height: 1.4),
              ),
              if (!_acessoNotificacoes) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey('autorizar-notificacoes'),
                  onPressed: _autorizarNotificacoes,
                  icon: const Icon(Icons.notifications_active_outlined, size: 17),
                  label: const Text('Abrir acesso a notificações'),
                ),
              ] else ...[
                if (_notificacoes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Nenhuma notificação foi entregue desde que o app abriu. '
                      'Elas não são gravadas: se o processo reiniciar, a lista recomeça.',
                      style: TextStyle(color: muted, fontSize: 10.5, height: 1.4),
                    ),
                  ),
                for (var i = 0; i < _notificacoes.length; i++)
                  ListTile(
                    key: ValueKey('notificacao-$i'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _notificacoes[i].titulo.isEmpty
                          ? _notificacoes[i].app
                          : _notificacoes[i].titulo,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${_notificacoes[i].app} · ${_notificacoes[i].texto}',
                      style: const TextStyle(fontSize: 10, color: muted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (_notificacoes.isNotEmpty)
                  TextButton.icon(
                    key: const ValueKey('limpar-notificacoes'),
                    onPressed: _limparNotificacoes,
                    icon: const Icon(Icons.delete_outline_rounded, size: 17),
                    label: const Text('Limpar leitura'),
                  ),
                TextButton.icon(
                  key: const ValueKey('atualizar-notificacoes'),
                  onPressed: _carregandoNotificacoes ? null : _carregarNotificacoes,
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: const Text('Atualizar notificações'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _secaoLocalizacao() {
    final local = _localizacao;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('LOCALIZAÇÃO'),
        const SizedBox(height: 8),
        Container(
          key: const ValueKey('status-localizacao'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cyan.withValues(alpha: .18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _estadoLocalizacao.descricao,
                style: const TextStyle(fontSize: 11.5, height: 1.4),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('ver-localizacao'),
                    onPressed: _carregandoLocalizacao ? null : _verLocalizacao,
                    icon: _carregandoLocalizacao
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location_rounded, size: 17),
                    label: Text(_carregandoLocalizacao
                        ? 'Lendo localização…'
                        : 'Ver minha localização'),
                  ),
                  if (local != null && local.valida)
                    OutlinedButton.icon(
                      key: const ValueKey('ouvir-localizacao'),
                      onPressed: _ouvirLocalizacao,
                      icon: const Icon(Icons.volume_up_rounded, size: 17),
                      label: const Text('Ouvir'),
                    ),
                ],
              ),
              if (_erroLocalizacao != null && local?.valida != true) ...[
                const SizedBox(height: 8),
                Text(_erroLocalizacao!,
                    key: const ValueKey('erro-localizacao'),
                    style: const TextStyle(
                        color: Color(0xFFFFC66D), fontSize: 11, height: 1.4)),
              ],
              if (local != null && local.valida) ...[
                const SizedBox(height: 10),
                Text(
                  local.endereco.trim().isEmpty
                      ? 'Endereço aproximado indisponível.'
                      : 'Perto de ${local.endereco}',
                  key: const ValueKey('localizacao-resultado'),
                  style: const TextStyle(fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 4),
                Text(
                  'Coordenadas ${local.coordenadas} · ${local.precisaoRotulo} · '
                  '${local.fonteRotulo} (${local.idadeRotulo})',
                  style: const TextStyle(color: muted, fontSize: 10.5, height: 1.4),
                ),
                if (local.aviso.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(local.aviso,
                        style: const TextStyle(
                            color: Color(0xFFFFC66D), fontSize: 10.5, height: 1.4)),
                  ),
              ],
              const SizedBox(height: 8),
              const Text(
                'A localização é lida no próprio aparelho e não é guardada nem enviada pelo app. '
                'O endereço aproximado, quando aparece, vem do Geocoder do Android e pode falhar '
                'sem internet.',
                style: TextStyle(color: muted, fontSize: 10, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _memoria(InfoDispositivo info) {
    if (!info.temMemoria) return 'não informado';
    final livre = info.memoriaLivreMb ?? 0;
    final pct = info.memoriaLivrePct?.toStringAsFixed(0) ?? '—';
    return '$livre MB livres de ${info.memoriaTotalMb} MB ($pct%)';
  }

  String _armazenamento(InfoDispositivo info) {
    final total = info.armazenamentoTotalGb;
    if (total == null) return 'não informado';
    final livre = info.armazenamentoLivreGb ?? 0;
    final pct = info.armazenamentoLivrePct?.toStringAsFixed(0) ?? '—';
    return '${livre.toStringAsFixed(1)} GB livres de '
        '${total.toStringAsFixed(1)} GB ($pct%)';
  }

  String _bateria(InfoDispositivo info) {
    final nivel = info.bateria;
    if (nivel == null) return 'não informado';
    return '$nivel%${info.carregando ? ' · carregando' : ''}';
  }

  Widget _linha(String rotulo, String valor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 112,
              child: Text(rotulo,
                  style: const TextStyle(fontSize: 11, color: muted)),
            ),
            Expanded(
              child: Text(valor, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );

  Widget _aviso(String texto, Color cor) => Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: cor.withValues(alpha: .25)),
        ),
        child: Text(texto, style: TextStyle(fontSize: 11, color: cor)),
      );
}
