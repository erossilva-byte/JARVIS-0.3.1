import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/modo_visita.dart';
import '../core/seguranca.dart';
import '../ui_common.dart';
import 'biometria_service.dart';
import 'bloqueio_gate.dart';
import 'bloqueio_page.dart';
import 'bloqueio_store.dart';

/// Configurações da tela de bloqueio do JARVIS.
///
/// Nada é ligado sem PIN: definir, trocar e desligar sempre passam pela
/// verificação. A biometria é uma conveniência — quando o Android não oferece, a
/// opção aparece desabilitada com o motivo, e o PIN continua sendo o caminho.
class SegurancaPage extends StatefulWidget {
  const SegurancaPage({super.key, this.porta, this.biometria});

  final PortaBloqueio? porta;
  final BiometriaGateway? biometria;

  @override
  State<SegurancaPage> createState() => _SegurancaPageState();
}

class _SegurancaPageState extends State<SegurancaPage> {
  late final PortaBloqueio porta = widget.porta ?? BloqueioStore();
  late final BiometriaGateway biometria = widget.biometria ?? BiometriaService();

  ConfigBloqueio config = ConfigBloqueio.desligado;
  BiometriaStatus bio = BiometriaStatus.indisponivel;
  bool carregando = true;
  bool salvando = false;
  String? aviso;

  /// Só existe quando a porta sabe guardar o PIN de coação.
  PortaCoacao? get coacao => porta is PortaCoacao ? porta as PortaCoacao : null;
  bool temCoacao = false;
  DateTime? usoCoacao;

  @override
  void initState() {
    super.initState();
    unawaited(_atualizar());
  }

  Future<void> _atualizar() async {
    final lido = await porta.ler();
    final status = await biometria.status();
    final portaCoacao = coacao;
    var definido = false;
    DateTime? uso;
    if (portaCoacao != null) {
      try {
        definido = await portaCoacao.temCoacao();
        uso = await portaCoacao.coacaoUsadaEm();
      } catch (_) {
        definido = false;
      }
    }
    if (!mounted) return;
    setState(() {
      config = lido;
      bio = status;
      carregando = false;
      temCoacao = definido;
      usoCoacao = uso;
    });
  }

  Future<void> _definirCoacao() async {
    final portaCoacao = coacao;
    if (portaCoacao == null) return;
    final dados = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _DialogoCoacao(),
    );
    if (dados == null || !mounted) return;
    setState(() => salvando = true);
    final resultado = await portaCoacao.definirCoacao(dados.$1, dados.$2);
    if (!mounted) return;
    setState(() {
      salvando = false;
      aviso = resultado.mensagem;
    });
    unawaited(_atualizar());
  }

  Future<void> _removerCoacao() async {
    final portaCoacao = coacao;
    if (portaCoacao == null) return;
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoPedirPin(
        titulo: 'Remover o PIN de coação',
        explicacao: 'Digite o PIN principal. O modo de visita deixa de existir.',
        confirmar: 'Remover',
      ),
    );
    if (pin == null || !mounted) return;
    setState(() => salvando = true);
    final resultado = await portaCoacao.removerCoacao(pin);
    if (!mounted) return;
    setState(() {
      salvando = false;
      aviso = resultado.mensagem;
    });
    unawaited(_atualizar());
  }

  Future<void> _copiarPrompt() async {
    await Clipboard.setData(const ClipboardData(text: promptModoVisita));
    if (!mounted) return;
    setState(() => aviso = 'Prompt "$nomePromptModoVisita" copiado.');
  }

  Future<void> _definirPin() async {
    final novo = await showDialog<String>(
      context: context,
      builder: (_) => const DialogoNovoPin(
        titulo: 'Definir o PIN do JARVIS',
        confirmar: 'Definir',
      ),
    );
    if (novo == null || !mounted) return;
    setState(() => salvando = true);
    final resultado = await porta.definirPin(novo);
    if (!mounted) return;
    setState(() {
      salvando = false;
      config = resultado.config;
      aviso = resultado.mensagem;
    });
  }

  Future<void> _alterarPin() async {
    final pedido = await showDialog<({String atual, String novo})>(
      context: context,
      builder: (_) => const _DialogoAlterarPin(),
    );
    if (pedido == null || !mounted) return;
    setState(() => salvando = true);
    final resultado = await porta.alterarPin(pedido.atual, pedido.novo);
    if (!mounted) return;
    setState(() {
      salvando = false;
      config = resultado.config;
      aviso = resultado.mensagem;
    });
  }

  Future<void> _desligar() async {
    final atual = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoPedirPin(
        titulo: 'Desligar o bloqueio',
        explicacao:
            'Confirme o PIN atual. O bloqueio e o PIN serão apagados deste aparelho.',
        confirmar: 'Desligar',
      ),
    );
    if (atual == null || !mounted) return;
    setState(() => salvando = true);
    final resultado = await porta.desligar(atual);
    if (!mounted) return;
    setState(() {
      salvando = false;
      config = resultado.config;
      aviso = resultado.mensagem;
    });
  }

  Future<void> _alternarBiometria(bool ativo) async {
    if (ativo && !bio.podeUsar) {
      setState(() => aviso = bio.descricao);
      return;
    }
    setState(() => salvando = true);
    final novo = await porta.definirBiometria(ativo);
    if (!mounted) return;
    setState(() {
      config = novo;
      salvando = false;
      aviso = ativo
          ? 'Biometria ligada. O PIN continua valendo como alternativa.'
          : 'Biometria desligada. Só o PIN desbloqueia.';
    });
  }

  Future<void> _mudarEspera(Duration espera) async {
    setState(() => salvando = true);
    final novo = await porta.definirEspera(espera);
    if (!mounted) return;
    setState(() {
      config = novo;
      salvando = false;
      aviso = 'O JARVIS vai pedir o PIN ${rotuloEspera(espera).toLowerCase()} '
          'depois de você sair do app.';
    });
  }

  void _bloquearAgora() {
    controladorBloqueio.bloquear();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Segurança e privacidade')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('TELA DE BLOQUEIO',
              style: TextStyle(color: cyan, fontSize: 10, letterSpacing: 2)),
          const SizedBox(height: 8),
          const Text(
            'Protege o acesso ao JARVIS com um PIN próprio, que não é o PIN do aparelho. '
            'O código não é guardado: fica só um resultado irreversível com sal aleatório.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.45),
          ),
          const SizedBox(height: 14),
          Container(
            key: const ValueKey('seguranca-estado'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: (config.ativo ? const Color(0xFF54D6A0) : muted)
                      .withValues(alpha: .35)),
            ),
            child: Row(
              children: [
                Icon(config.ativo ? Icons.lock_rounded : Icons.lock_open_rounded,
                    color: config.ativo ? const Color(0xFF54D6A0) : muted,
                    size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(config.ativo ? 'BLOQUEIO ATIVO' : 'BLOQUEIO DESLIGADO',
                          style: TextStyle(
                              color: config.ativo
                                  ? const Color(0xFF54D6A0)
                                  : muted,
                              fontSize: 10.5,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        config.ativo
                            ? 'Pede o PIN ao abrir e ${rotuloEspera(config.espera).toLowerCase()} '
                                'depois de sair do app.'
                            : 'Sem PIN, qualquer pessoa que pegue o celular desbloqueado entra no JARVIS.',
                        style: const TextStyle(fontSize: 11.5, height: 1.4),
                      ),
                    ],
                  ),
                ),
                if (carregando || salvando)
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!config.ativo) ...[
            FilledButton.icon(
              key: const ValueKey('seguranca-definir-pin'),
              onPressed: carregando || salvando ? null : _definirPin,
              icon: const Icon(Icons.pin_rounded, size: 18),
              label: const Text('Definir PIN e ativar bloqueio'),
            ),
          ] else ...[
            OutlinedButton.icon(
              key: const ValueKey('seguranca-alterar-pin'),
              onPressed: salvando ? null : _alterarPin,
              icon: const Icon(Icons.password_rounded, size: 18),
              label: const Text('Alterar PIN'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('seguranca-bloquear-agora'),
              onPressed: salvando ? null : _bloquearAgora,
              icon: const Icon(Icons.lock_clock_rounded, size: 18),
              label: const Text('Bloquear agora'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              key: const ValueKey('seguranca-desligar'),
              onPressed: salvando ? null : _desligar,
              icon: Icon(Icons.lock_open_rounded, size: 18, color: colors.error),
              label: Text('Desligar o bloqueio',
                  style: TextStyle(color: colors.error)),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(13, 10, 10, 10),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cyan.withValues(alpha: .18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.fingerprint_rounded, color: cyan, size: 21),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Desbloquear com biometria',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                    Switch(
                      key: const ValueKey('seguranca-biometria'),
                      value: config.biometria && bio.podeUsar,
                      onChanged: !config.ativo || !bio.podeUsar || salvando
                          ? null
                          : _alternarBiometria,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  bio.descricao,
                  style: const TextStyle(color: muted, fontSize: 10.5, height: 1.35),
                ),
                const SizedBox(height: 4),
                const Text(
                  'O Android só devolve “confirmado” ou “não confirmado”. O app não recebe, '
                  'não guarda e não envia a sua digital ou o seu rosto.',
                  style: TextStyle(color: muted, fontSize: 10, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('PEDIR O PIN AO VOLTAR',
              style: TextStyle(
                  color: muted.withValues(alpha: .9),
                  fontSize: 9.5,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          DropdownButtonFormField<Duration>(
            key: const ValueKey('seguranca-espera'),
            initialValue: config.espera,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              for (final espera in esperasBloqueio)
                DropdownMenuItem(
                    value: espera, child: Text(rotuloEspera(espera))),
            ],
            onChanged: !config.ativo || salvando
                ? null
                : (valor) {
                    if (valor != null) unawaited(_mudarEspera(valor));
                  },
          ),
          const SizedBox(height: 6),
          const Text(
            '“Imediatamente” pede o PIN a cada volta ao app. Um tempo maior evita pedir '
            'quando você só abriu a câmera ou atendeu uma ligação.',
            style: TextStyle(color: muted, fontSize: 10.5, height: 1.4),
          ),
          if (aviso != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC66D).withValues(alpha: .10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                aviso!,
                key: const ValueKey('seguranca-aviso'),
                style: const TextStyle(
                    color: Color(0xFFFFC66D), fontSize: 11.5, height: 1.4),
              ),
            ),
          ],
          if (coacao != null) ...[
            const SizedBox(height: 18),
            Container(
              key: const ValueKey('seguranca-coacao'),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cyan.withValues(alpha: .18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.visibility_off_rounded,
                          color: cyan, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Modo de visita (Duress PIN)',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600)),
                      ),
                      if (salvando)
                        const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    temCoacao
                        ? 'Definido. Digitando esse PIN na tela de bloqueio, o JARVIS '
                            'abre sem os seus dados; o app real só volta com o PIN principal.'
                        : 'Não definido. Com um PIN de coação, quem exigir o desbloqueio '
                            'encontra um app recém-instalado, sem nada seu.',
                    key: const ValueKey('seguranca-coacao-estado'),
                    style: const TextStyle(fontSize: 11, height: 1.4),
                  ),
                  if (usoCoacao != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Último uso: ${_dataHora(usoCoacao!)}',
                      key: const ValueKey('seguranca-coacao-uso'),
                      style: const TextStyle(fontSize: 10, color: muted),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('seguranca-definir-coacao'),
                        onPressed: !config.ativo || salvando
                            ? null
                            : _definirCoacao,
                        icon: const Icon(Icons.key_rounded, size: 16),
                        label: Text(
                            temCoacao
                                ? 'Trocar PIN de coação'
                                : 'Definir PIN de coação',
                            style: const TextStyle(fontSize: 10.5)),
                      ),
                      if (temCoacao)
                        TextButton.icon(
                          key: const ValueKey('seguranca-remover-coacao'),
                          onPressed: salvando ? null : _removerCoacao,
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 16),
                          label: const Text('Remover',
                              style: TextStyle(fontSize: 10.5)),
                        ),
                    ],
                  ),
                  const Divider(height: 20),
                  const Text('PROMPT SUGERIDO',
                      style: TextStyle(
                          color: cyan, fontSize: 9, letterSpacing: 1.2)),
                  const SizedBox(height: 4),
                  const Text(nomePromptModoVisita,
                      key: ValueKey('seguranca-coacao-prompt-nome'),
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text(promptModoVisita,
                      key: ValueKey('seguranca-coacao-prompt'),
                      style: TextStyle(
                          fontSize: 10, height: 1.4, color: muted)),
                  const SizedBox(height: 2),
                  TextButton.icon(
                    key: const ValueKey('seguranca-coacao-copiar'),
                    onPressed: _copiarPrompt,
                    icon: const Icon(Icons.copy_rounded, size: 15),
                    label: const Text('Copiar prompt',
                        style: TextStyle(fontSize: 10)),
                  ),
                  for (final limite in limitesModoVisita)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('· $limite',
                          style: const TextStyle(
                              fontSize: 10, color: muted, height: 1.35)),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text('O QUE FICA GUARDADO',
              style: TextStyle(
                  color: cyan,
                  fontSize: 9.5,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            '• O PIN em forma de código derivado (PBKDF2-HMAC-SHA256 com sal), no cofre '
            'seguro do aparelho.\n'
            '• A configuração: bloqueio ligado, biometria, tempo de espera e tentativas.\n'
            '• Nada de PIN em texto, nada em nuvem, nada compartilhado com outro app.',
            style: TextStyle(color: muted, fontSize: 11, height: 1.5),
          ),
          const SizedBox(height: 14),
          Text(
            'Depois de $tentativasAntesDeEspera erros seguidos, o desbloqueio fica '
            '${esperaPorTentativas.inSeconds} segundos em espera. A espera não revela o PIN '
            'e não apaga nada.',
            style: const TextStyle(color: muted, fontSize: 10.5, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            key: const ValueKey('seguranca-atualizar'),
            onPressed: carregando ? null : _atualizar,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Atualizar estado'),
          ),
        ],
      ),
    );
  }
}

/// Pede o PIN atual antes de uma ação que muda a proteção.
class _DialogoPedirPin extends StatefulWidget {
  const _DialogoPedirPin({
    required this.titulo,
    required this.explicacao,
    required this.confirmar,
  });

  final String titulo;
  final String explicacao;
  final String confirmar;

  @override
  State<_DialogoPedirPin> createState() => _DialogoPedirPinState();
}

class _DialogoPedirPinState extends State<_DialogoPedirPin> {
  final pin = TextEditingController();

  @override
  void dispose() {
    pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.titulo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.explicacao, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('seguranca-pin-atual'),
              controller: pin,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: tamanhoMaxPin,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'PIN atual', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar')),
          FilledButton(
            key: const ValueKey('seguranca-confirmar-pin'),
            onPressed: () => Navigator.of(context).pop(pin.text.trim()),
            child: Text(widget.confirmar),
          ),
        ],
      );
}

/// Troca de PIN: atual, novo e repetição, com a mesma política do PIN inicial.
class _DialogoAlterarPin extends StatefulWidget {
  const _DialogoAlterarPin();

  @override
  State<_DialogoAlterarPin> createState() => _DialogoAlterarPinState();
}

class _DialogoAlterarPinState extends State<_DialogoAlterarPin> {
  final atual = TextEditingController();
  final novo = TextEditingController();
  final repetido = TextEditingController();
  String? erro;

  @override
  void dispose() {
    atual.dispose();
    novo.dispose();
    repetido.dispose();
    super.dispose();
  }

  void _salvar() {
    if (novo.text.trim() != repetido.text.trim()) {
      setState(() => erro = 'Os dois PINs novos não são iguais.');
      return;
    }
    final politica = avaliarPin(novo.text.trim());
    if (politica != PoliticaPin.ok) {
      setState(() => erro = mensagemPolitica(politica));
      return;
    }
    Navigator.of(context)
        .pop((atual: atual.text.trim(), novo: novo.text.trim()));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Alterar PIN'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('seguranca-pin-atual'),
                controller: atual,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: tamanhoMaxPin,
                decoration: const InputDecoration(
                    labelText: 'PIN atual', border: OutlineInputBorder()),
              ),
              TextField(
                key: const ValueKey('seguranca-pin-novo'),
                controller: novo,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: tamanhoMaxPin,
                decoration: const InputDecoration(
                    labelText: 'Novo PIN', border: OutlineInputBorder()),
              ),
              TextField(
                key: const ValueKey('seguranca-pin-repetir'),
                controller: repetido,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: tamanhoMaxPin,
                decoration: const InputDecoration(
                    labelText: 'Repita o novo PIN',
                    border: OutlineInputBorder()),
              ),
              if (erro != null)
                Text(erro!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 11.5)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar')),
          FilledButton(
              key: const ValueKey('seguranca-salvar-pin'),
              onPressed: _salvar,
              child: const Text('Salvar')),
        ],
      );
}

String _dataHora(DateTime quando) {
  String dois(int valor) => valor.toString().padLeft(2, '0');
  return '${dois(quando.day)}/${dois(quando.month)}/${quando.year} '
      'às ${dois(quando.hour)}:${dois(quando.minute)}';
}

/// Pede o PIN principal e o novo PIN de coação, sem mostrar nenhum dos dois.
class _DialogoCoacao extends StatefulWidget {
  const _DialogoCoacao();

  @override
  State<_DialogoCoacao> createState() => _DialogoCoacaoState();
}

class _DialogoCoacaoState extends State<_DialogoCoacao> {
  final principal = TextEditingController();
  final coacao = TextEditingController();
  String? erro;

  @override
  void dispose() {
    principal.dispose();
    coacao.dispose();
    super.dispose();
  }

  void _confirmar() {
    final atual = principal.text.trim();
    final novo = coacao.text.trim();
    if (atual.length < tamanhoMinPin) {
      setState(() => erro = 'Digite o PIN principal completo.');
      return;
    }
    if (novo.length < tamanhoMinPinCoacao) {
      setState(() => erro =
          'O PIN de coação precisa ter pelo menos $tamanhoMinPinCoacao dígitos.');
      return;
    }
    Navigator.of(context).pop((atual, novo));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('PIN de coação (modo de visita)',
            style: TextStyle(fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Esse PIN abre um app vazio, sem os seus dados. Precisa ser '
              'diferente do PIN principal e do mesmo jeito difícil de adivinhar.',
              style: TextStyle(fontSize: 11, height: 1.4),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('coacao-pin-principal'),
              controller: principal,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: tamanhoMaxPin,
              decoration: const InputDecoration(
                  labelText: 'PIN principal', isDense: true),
            ),
            TextField(
              key: const ValueKey('coacao-pin-novo'),
              controller: coacao,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: tamanhoMaxPinCoacao,
              decoration: const InputDecoration(
                  labelText: 'Novo PIN de coação', isDense: true),
            ),
            if (erro != null)
              Text(erro!,
                  key: const ValueKey('coacao-erro'),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFFFFC66D))),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          FilledButton(
              key: const ValueKey('coacao-confirmar'),
              onPressed: _confirmar,
              child: const Text('Definir')),
        ],
      );
}
