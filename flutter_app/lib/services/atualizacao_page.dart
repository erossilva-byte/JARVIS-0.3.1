import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../ui_common.dart';
import 'atualizacao_service.dart';

/// Painel de atualização do app: versão instalada, release publicado, download
/// conferido pelo SHA-256 e abertura do instalador do Android.
class AtualizacaoPage extends StatefulWidget {
  const AtualizacaoPage({super.key, this.servico, this.ativo = true});

  final AtualizacaoService? servico;

  /// Falso em teste/plataforma sem a ponte Android.
  final bool ativo;

  @override
  State<AtualizacaoPage> createState() => _AtualizacaoPageState();
}

class _AtualizacaoPageState extends State<AtualizacaoPage> {
  late final AtualizacaoService servico =
      widget.servico ?? AtualizacaoService();

  StreamSubscription<ProgressoDownload>? progresso;
  EstadoAtualizacao estado = const EstadoAtualizacao();
  ReleasePublicado? release;
  ResultadoDownload? baixado;
  ResultadoInstalacao? instalacao;
  String? erro;
  int pct = 0;
  bool ocupado = false;
  bool baixando = false;

  @override
  void initState() {
    super.initState();
    if (!widget.ativo) return;
    progresso = servico.progresso.listen((evento) {
      if (!mounted) return;
      setState(() => pct = evento.pct);
    }, onError: (Object _) {
      // Plataforma sem canal de eventos: o download ainda informa o fim.
    });
    _carregar();
  }

  @override
  void dispose() {
    progresso?.cancel();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final novo = await servico.status();
      if (!mounted) return;
      setState(() => estado = novo);
    } on AtualizacaoIndisponivel catch (falha) {
      if (!mounted) return;
      setState(() => erro = falha.mensagem);
    }
  }

  Future<void> _executar(Future<void> Function() acao) async {
    if (ocupado) return;
    setState(() {
      ocupado = true;
      erro = null;
      instalacao = null;
    });
    try {
      await acao();
    } on AtualizacaoIndisponivel catch (falha) {
      if (mounted) setState(() => erro = falha.mensagem);
    } catch (_) {
      if (mounted) {
        setState(() => erro = 'Não foi possível concluir a atualização.');
      }
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Future<void> _procurar() => _executar(() async {
        final achado = await servico.verificar();
        if (!mounted) return;
        setState(() {
          release = achado;
          baixado = null;
          pct = 0;
        });
      });

  Future<void> _baixar() => _executar(() async {
        setState(() {
          baixando = true;
          pct = 0;
          baixado = null;
        });
        try {
          final resultado = await servico.baixar();
          if (!mounted) return;
          setState(() => baixado = resultado);
          await _carregar();
        } finally {
          if (mounted) setState(() => baixando = false);
        }
      });

  Future<void> _instalar() => _executar(() async {
        final resposta = await servico.instalar();
        if (!mounted) return;
        setState(() => instalacao = resposta);
        if (!resposta.ok) unawaited(_carregar());
      });

  Future<void> _abrirReleases() => _executar(() async {
        await servico.abrirReleases();
      });

  String get _tamanho {
    final bytes = release?.tamanho ?? -1;
    if (bytes <= 0) return 'tamanho não informado';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  Widget _cartao(String titulo, List<Widget> filhos) => Container(
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
            ...filhos,
          ],
        ),
      );

  List<Widget> _cartaoRelease() {
    final r = release;
    if (r == null) {
      return const [
        Text(
            'Nada foi consultado ainda. O app só fala com o GitHub quando você toca em procurar.',
            style: TextStyle(fontSize: 11, color: muted, height: 1.45)),
      ];
    }
    if (!r.disponivel) {
      return [
        Text(
          mensagemDoMotivo(r.motivo),
          key: const ValueKey('atualizacao-release'),
          style: const TextStyle(fontSize: 11.5, height: 1.45),
        ),
        const SizedBox(height: 6),
        Text(
            'Publicado: ${r.versao.isEmpty ? '—' : r.versao} · '
            'instalado: ${r.versaoInstalada.isEmpty ? '—' : r.versaoInstalada}',
            style: const TextStyle(fontSize: 10, color: muted)),
      ];
    }
    return [
      Text(
        'Versão ${r.versao} disponível (instalada: ${r.versaoInstalada}).',
        key: const ValueKey('atualizacao-release'),
        style: const TextStyle(fontSize: 11.5, height: 1.45),
      ),
      const SizedBox(height: 6),
      Text('${r.nomeArquivo} · $_tamanho',
          style: const TextStyle(fontSize: 10, color: muted)),
      const SizedBox(height: 8),
      Text(
        r.temDigestoPublicado
            ? 'A esteira publicou o SHA-256 deste APK; o download confere sozinho.'
            : 'O release não publica o SHA-256: sem ele nada será baixado.',
        style: TextStyle(
            fontSize: 10,
            height: 1.4,
            color: r.temDigestoPublicado
                ? const Color(0xFF65D49A)
                : const Color(0xFFFFC66D)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Atualizações',
              style: TextStyle(fontSize: 15))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _cartao('VERSÃO INSTALADA', [
            Text(
              estado.versao.isEmpty
                  ? 'Lendo a versão instalada…'
                  : estado.versaoCompleta,
              key: const ValueKey('atualizacao-status'),
              style: const TextStyle(fontSize: 15, letterSpacing: .4),
            ),
            const SizedBox(height: 4),
            Text(
                estado.pacote.isEmpty
                    ? 'Pacote não informado por esta plataforma.'
                    : estado.pacote,
                style: const TextStyle(fontSize: 10, color: muted)),
            const SizedBox(height: 8),
            Text(
              estado.instaladorAutorizado
                  ? 'O Android já autoriza este app a abrir o instalador de APK.'
                  : 'O Android ainda não autorizou instalar por esta origem: a tela de permissão abre no primeiro Instalar.',
              style: const TextStyle(fontSize: 10.5, color: muted, height: 1.4),
            ),
          ]),
          _cartao('RELEASE PUBLICADO', [
            ..._cartaoRelease(),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                key: const ValueKey('atualizacao-procurar'),
                onPressed: ocupado ? null : _procurar,
                icon: const Icon(Icons.system_update_alt_rounded, size: 18),
                label: const Text('Procurar atualização',
                    style: TextStyle(fontSize: 10)),
              ),
              OutlinedButton.icon(
                key: const ValueKey('atualizacao-abrir-releases'),
                onPressed: ocupado ? null : _abrirReleases,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Abrir releases',
                    style: TextStyle(fontSize: 10)),
              ),
            ]),
          ]),
          if (release?.disponivel == true)
            _cartao('BAIXAR E CONFERIR', [
              if (baixando) ...[
                LinearProgressIndicator(
                  key: const ValueKey('atualizacao-progresso'),
                  value: pct <= 0 ? null : pct / 100,
                ),
                const SizedBox(height: 6),
                Text('$pct% recebido',
                    style: const TextStyle(fontSize: 10, color: muted)),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                key: const ValueKey('atualizacao-baixar'),
                onPressed: (ocupado || baixando) ? null : _baixar,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Baixar o APK',
                    style: TextStyle(fontSize: 10)),
              ),
              const SizedBox(height: 8),
              Text(
                'O download vai para a pasta privada do app e o SHA-256 é '
                'calculado durante a cópia. Arquivo com digesto diferente do '
                'publicado é apagado, não oferecido para instalar.',
                style: const TextStyle(
                    fontSize: 9.5, color: muted, height: 1.45),
              ),
              if (baixado != null) ...[
                const SizedBox(height: 10),
                const Text('SHA-256 DO ARQUIVO BAIXADO',
                    style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.1,
                        color: cyan,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                SelectableText(
                  baixado!.sha256,
                  key: const ValueKey('atualizacao-sha256'),
                  style: const TextStyle(fontSize: 10, height: 1.4),
                ),
                const SizedBox(height: 4),
                const Text('Confere com o publicado pela esteira.',
                    style:
                        TextStyle(fontSize: 10, color: Color(0xFF65D49A))),
              ],
            ]),
          if (baixado != null || estado.baixado)
            _cartao('INSTALAR', [
              Text(
                baixado != null
                    ? 'O APK baixado está conferido e pronto. O Android mostra '
                        'a tela de instalação e mantém seus dados porque a '
                        'assinatura é a mesma.'
                    : 'Há um APK baixado nesta sessão anterior. Baixe de novo '
                        'para conferir o SHA-256 antes de instalar.',
                style: const TextStyle(fontSize: 11, height: 1.45),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                key: const ValueKey('atualizacao-instalar'),
                onPressed: ocupado ? null : _instalar,
                icon: const Icon(Icons.install_mobile_rounded, size: 18),
                label: const Text('Instalar atualização',
                    style: TextStyle(fontSize: 10)),
              ),
            ]),
          if (instalacao != null)
            Container(
              key: const ValueKey('atualizacao-resultado'),
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: instalacao!.ok
                    ? const Color(0xFF0D2118)
                    : const Color(0xFF211A10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: (instalacao!.ok
                            ? const Color(0xFF65D49A)
                            : const Color(0xFFFFC66D))
                        .withValues(alpha: .3)),
              ),
              child: Text(instalacao!.mensagem,
                  style: const TextStyle(fontSize: 11.5, height: 1.45)),
            ),
          if (erro != null)
            Container(
              key: const ValueKey('atualizacao-erro'),
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFF211A10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFFFC66D).withValues(alpha: .3)),
              ),
              child: Text(erro!,
                  style: const TextStyle(fontSize: 11.5, height: 1.45)),
            ),
          const Text(
            'Limites reais: a atualização só instala por cima se o APK vier '
            'assinado com a mesma chave do instalado; o APK da esteira é arm64. '
            'O Android sempre pede confirmação — não há instalação silenciosa, '
            'nem root, nem permissão de todos os arquivos.',
            style: TextStyle(fontSize: 9.5, color: muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}
