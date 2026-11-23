import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/fundo.dart';
import '../ui_common.dart';
import 'fundo_service.dart';
import 'historico_voz_page.dart';

/// Tela do modo de segundo plano.
///
/// Ela não liga nada sozinha: mostra o estado real do serviço, a autorização que
/// o Android exige para abrir apps e um campo para testar um comando sem falar.
/// O switch grava a decisão no aparelho; a escuta em si fica a cargo do serviço.
class SegundoPlanoPage extends StatefulWidget {
  const SegundoPlanoPage({super.key, this.gateway});

  final FundoGateway? gateway;

  @override
  State<SegundoPlanoPage> createState() => _SegundoPlanoPageState();
}

class _SegundoPlanoPageState extends State<SegundoPlanoPage> {
  late final FundoGateway _gateway = widget.gateway ?? FundoService();
  final comando = TextEditingController();

  EstadoFundo estado = EstadoFundo.vazio;
  ResultadoFundo? resultado;
  String? aviso;
  bool carregando = true;
  bool salvando = false;
  bool executando = false;

  @override
  void initState() {
    super.initState();
    unawaited(_atualizar());
  }

  @override
  void dispose() {
    comando.dispose();
    super.dispose();
  }

  Future<void> _atualizar() async {
    if (mounted) setState(() => carregando = true);
    final lido = await _gateway.estado();
    if (!mounted) return;
    setState(() {
      estado = lido;
      carregando = false;
    });
  }

  Future<void> _definirModo(bool ativo) async {
    setState(() => salvando = true);
    final novo = await _gateway.definirModoSemTela(ativo);
    if (!mounted) return;
    setState(() {
      estado = novo.ponteDisponivel ? novo : estado;
      salvando = false;
      aviso = ativo
          ? 'Modo sem tela ligado. Na próxima palavra de ativação o JARVIS executa o comando '
              'sem abrir o app.'
          : 'Modo sem tela desligado. A palavra de ativação volta a abrir a tela do app.';
    });
  }

  Future<void> _autorizarSobreposicao() async {
    await _gateway.abrirAjusteSobreposicao();
    if (!mounted) return;
    setState(() => aviso =
        'Autorize “Exibir sobre outros apps” na tela do Android. Ao voltar, toque em '
            'Atualizar para conferir.');
  }

  Future<void> _executar() async {
    final texto = comando.text.trim();
    if (texto.isEmpty || executando) return;
    setState(() {
      executando = true;
      resultado = null;
    });
    final executado = await _gateway.executarTexto(texto);
    if (!mounted) return;
    setState(() {
      resultado = executado;
      executando = false;
    });
    await _atualizar();
  }

  Color _corEstado(ColorScheme colors) {
    if (!estado.ponteDisponivel) return const Color(0xFFFFC66D);
    if (estado.ouvindo) return const Color(0xFF54D6A0);
    if (estado.servicoAtivo) return colors.primary;
    return const Color(0xFFFFC66D);
  }

  String _rotuloEstado() {
    if (!estado.ponteDisponivel) return 'SÓ NO ANDROID';
    if (estado.ouvindo) return 'ESCUTANDO · SEGUNDO PLANO';
    if (estado.servicoAtivo) return 'ATIVO · EM ESPERA';
    return 'DETECTOR DESLIGADO';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cor = _corEstado(colors);
    final pendencias = pendenciasFundo(estado);
    final idade = idadeUltimaAcao(estado.ultimoEm, DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Segundo plano')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('SEGUNDO PLANO DE VERDADE',
              style: TextStyle(color: cyan, fontSize: 10, letterSpacing: 2)),
          const SizedBox(height: 8),
          const Text(
            'Chame “Jarvis” com o app fechado: o serviço mostra na tela que está ativo, escuta '
            'sua fala e executa o que é de baixo risco — abrir um app, lanterna, volume e alarme. '
            'Se o que você disse não for comando, é tratado como pergunta e respondido pelo '
            'provedor de IA configurado.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.45),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cor.withValues(alpha: .35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sensors_rounded, color: cor, size: 22),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _rotuloEstado(),
                        style: TextStyle(
                          color: cor,
                          fontSize: 10.5,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (carregando)
                      const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(resumoFundo(estado),
                    style: const TextStyle(fontSize: 12, height: 1.45)),
                if (estado.servicoAtivo) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _selo('microfone', estado.ouvindo),
                      _selo('abrir apps', estado.podeAbrirApps),
                      _selo('modo sem tela', estado.modoSemTela),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            key: const ValueKey('fundo-modo-cartao'),
            padding: const EdgeInsets.fromLTRB(13, 10, 8, 10),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cyan.withValues(alpha: .18)),
            ),
            child: Row(
              children: [
                const Icon(Icons.phonelink_lock_rounded, color: cyan, size: 21),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Perguntar e executar sem abrir a tela',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600)),
                      SizedBox(height: 3),
                      Text(
                        'Com isto ligado, a palavra de ativação não abre o app: o serviço '
                        'escuta, responde perguntas no provedor de IA e executa os comandos '
                        'de baixo risco aqui mesmo.',
                        style: TextStyle(
                            fontSize: 10.5, color: muted, height: 1.35),
                      ),
                    ],
                  ),
                ),
                Switch(
                  key: const ValueKey('fundo-modo-sem-tela'),
                  value: estado.modoSemTela,
                  onChanged:
                      salvando || !estado.ponteDisponivel ? null : _definirModo,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const ValueKey('fundo-autorizar-sobreposicao'),
            onPressed: estado.ponteDisponivel ? _autorizarSobreposicao : null,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(estado.podeAbrirApps
                ? 'Revisar “Exibir sobre outros apps” (já autorizado)'
                : 'Autorizar “Exibir sobre outros apps”'),
          ),
          if (pendencias.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC66D).withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('FALTA PARA FUNCIONAR SEM A TELA',
                      style: TextStyle(
                          color: Color(0xFFFFC66D),
                          fontSize: 9.5,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  for (final pendencia in pendencias)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $pendencia',
                          style: const TextStyle(fontSize: 11.5, height: 1.4)),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text('TESTAR UM COMANDO SEM FALAR',
              style: TextStyle(
                  color: cyan,
                  fontSize: 9.5,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextField(
            key: const ValueKey('fundo-comando'),
            controller: comando,
            enabled: !executando,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _executar(),
            decoration: const InputDecoration(
              hintText:
                  'Ex.: abrir YouTube · lanterna · volume 30 · alarme 7:30',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('fundo-executar'),
            onPressed: executando || !estado.ponteDisponivel ? null : _executar,
            icon: executando
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text(executando ? 'Executando…' : 'Executar comando'),
          ),
          if (resultado != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (resultado!.ok ? const Color(0xFF54D6A0) : colors.error)
                    .withValues(alpha: .10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                resultado!.mensagem,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: resultado!.ok ? const Color(0xFF54D6A0) : colors.error,
                ),
              ),
            ),
          ],
          if (aviso != null) ...[
            const SizedBox(height: 10),
            Text(aviso!,
                style: const TextStyle(
                    color: Color(0xFFFFC66D), fontSize: 11, height: 1.4)),
          ],
          const SizedBox(height: 16),
          Container(
            key: const ValueKey('fundo-ultima-acao'),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: .30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ÚLTIMA AÇÃO EM SEGUNDO PLANO',
                    style: TextStyle(
                        fontSize: 9.5,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  estado.ultimaAcao.isEmpty
                      ? 'Nenhum comando executado ainda neste aparelho.'
                      : '${estado.ultimaAcao}${idade == null ? '' : ' · $idade'}',
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
                if (estado.ultimoResultado.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(estado.ultimoResultado,
                      style: const TextStyle(color: muted, fontSize: 11)),
                ],
                if (estado.ultimaAcao.isNotEmpty)
                  TextButton(
                    key: const ValueKey('fundo-limpar-historico'),
                    onPressed: () async {
                      final limpo = await _gateway.limparHistorico();
                      if (!mounted) return;
                      setState(() => estado = limpo);
                    },
                    child: const Text('Limpar este registro'),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            key: const ValueKey('fundo-ver-historico'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HistoricoVozPage()),
            ),
            icon: const Icon(Icons.history_rounded, size: 18),
            label: const Text('Ver histórico completo'),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            key: const ValueKey('fundo-atualizar'),
            onPressed: carregando ? null : _atualizar,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Atualizar estado'),
          ),
          const SizedBox(height: 14),
          const Text('O QUE ELE FAZ SEM A TELA',
              style: TextStyle(
                  color: cyan,
                  fontSize: 9.5,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final acao in acoesEmSegundoPlano)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text('• $acao',
                  style: const TextStyle(fontSize: 11.5, height: 1.4)),
            ),
          const SizedBox(height: 14),
          const Text('LIMITES REAIS',
              style: TextStyle(
                  color: Color(0xFFFFC66D),
                  fontSize: 9.5,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final limite in limitesSegundoPlano)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text('• $limite',
                  style:
                      const TextStyle(color: muted, fontSize: 11, height: 1.4)),
            ),
          const SizedBox(height: 6),
          const Text(
            'O microfone continua sendo processado no aparelho. Nenhum áudio é enviado para a '
            'nuvem e nenhum comando é executado sem passar por este registro fechado.',
            style: TextStyle(color: muted, fontSize: 10.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _selo(String rotulo, bool ativo) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color:
              (ativo ? const Color(0xFF54D6A0) : muted).withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          ativo ? '$rotulo OK' : '$rotulo pendente',
          style: TextStyle(
            fontSize: 9.5,
            color: ativo ? const Color(0xFF54D6A0) : muted,
          ),
        ),
      );
}
