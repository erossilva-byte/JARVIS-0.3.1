import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/seguranca.dart';
import '../ui_common.dart';
import 'biometria_service.dart';

/// Tela de bloqueio do JARVIS.
///
/// O PIN nunca aparece: só os pontos do que foi digitado. A verificação é feita
/// pelo [PortaBloqueio] (derivação + tentativas). Biometria só aparece quando o
/// aparelho oferece e o usuário ligou a opção. Quem esqueceu o PIN pode redefinir
/// depois de confirmar a credencial do próprio aparelho — não existe atalho sem
/// prova de identidade.
class TelaBloqueio extends StatefulWidget {
  const TelaBloqueio({
    super.key,
    required this.porta,
    this.biometria,
    this.aoDesbloquear,
    this.aoConfigurar,
    this.aoEntrar,
  });

  final PortaBloqueio porta;
  final BiometriaGateway? biometria;
  final VoidCallback? aoDesbloquear;
  final VoidCallback? aoConfigurar;

  /// Chamado com `true` quando o PIN digitado é o de coação (modo de visita).
  /// Sem este retorno a tela nunca abre o modo de visita — melhor um app que
  /// não esconde do que um app que finge ter desbloqueado.
  final void Function(bool coacao)? aoEntrar;

  @override
  State<TelaBloqueio> createState() => _TelaBloqueioState();
}

class _TelaBloqueioState extends State<TelaBloqueio> {
  late final BiometriaGateway biometria = widget.biometria ?? BiometriaService();
  final digitado = StringBuffer();

  ConfigBloqueio config = ConfigBloqueio.desligado;
  BiometriaStatus bio = BiometriaStatus.indisponivel;
  String? erro;
  String? aviso;
  bool verificando = false;
  bool carregando = true;
  Duration restante = Duration.zero;
  Timer? contador;

  @override
  void initState() {
    super.initState();
    unawaited(_carregar());
  }

  @override
  void dispose() {
    contador?.cancel();
    super.dispose();
  }

  Future<void> _carregar() async {
    final lido = await widget.porta.ler();
    final status = await biometria.status();
    if (!mounted) return;
    setState(() {
      config = lido;
      bio = status;
      carregando = false;
      restante = lido.restanteDeEspera(DateTime.now());
    });
    _iniciarContador();
    if (status.podeUsar && lido.biometria) {
      unawaited(_usarBiometria(silencioso: true));
    }
  }

  void _iniciarContador() {
    contador?.cancel();
    if (restante <= Duration.zero) return;
    contador = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final novo = config.restanteDeEspera(DateTime.now());
      setState(() => restante = novo);
      if (novo <= Duration.zero) timer.cancel();
    });
  }

  bool get bloqueadoPorTentativas => restante > Duration.zero;

  void _tecla(String digito) {
    if (verificando || bloqueadoPorTentativas) return;
    if (digitado.length >= tamanhoMaxPin) return;
    setState(() {
      digitado.write(digito);
      erro = null;
      aviso = null;
    });
  }

  void _apagar() {
    if (verificando || digitado.isEmpty) return;
    final atual = digitado.toString();
    digitado
      ..clear()
      ..write(atual.substring(0, atual.length - 1));
    setState(() => erro = null);
  }

  Future<void> _conferir() async {
    if (verificando || bloqueadoPorTentativas) return;
    final pin = digitado.toString();
    if (pin.length < tamanhoMinPin) {
      setState(() => erro = 'Digite pelo menos $tamanhoMinPin dígitos.');
      return;
    }
    setState(() {
      verificando = true;
      erro = null;
    });
    final resultado = await widget.porta.conferir(pin);
    if (!mounted) return;
    if (resultado.ok) {
      await widget.porta.registrarDesbloqueio();
      if (!mounted) return;
      setState(() {
        verificando = false;
        digitado.clear();
      });
      // PIN de coação: a tela não pode deixar o app real aparecer.
      if (widget.aoEntrar != null) {
        widget.aoEntrar!(resultado.coacao);
      } else if (!resultado.coacao) {
        widget.aoDesbloquear?.call();
      }
      return;
    }
    setState(() {
      verificando = false;
      erro = resultado.mensagem;
      config = resultado.config;
      restante = resultado.config.restanteDeEspera(DateTime.now());
      digitado.clear();
    });
    _iniciarContador();
  }

  Future<void> _usarBiometria({bool silencioso = false}) async {
    if (verificando) return;
    if (!bio.podeUsar) {
      setState(() => aviso = bio.descricao);
      return;
    }
    setState(() {
      verificando = true;
      erro = null;
    });
    final resultado = await biometria.autenticar(motivo: 'Desbloquear o JARVIS');
    if (!mounted) return;
    if (resultado.ok) {
      await widget.porta.registrarDesbloqueio();
      if (!mounted) return;
      setState(() => verificando = false);
      widget.aoDesbloquear?.call();
      return;
    }
    setState(() {
      verificando = false;
      // A tentativa silenciosa (ao abrir) não deve acusar erro antes do usuário agir.
      if (!silencioso) erro = resultado.mensagem;
      aviso = 'Use o PIN se preferir.';
    });
  }

  Future<void> _recuperar() async {
    final confirmado = await biometria.confirmarCredencialDoAparelho(
        motivo: 'Confirme o PIN ou padrão do aparelho para redefinir o PIN do JARVIS');
    if (!mounted) return;
    if (!confirmado.ok) {
      setState(() => aviso = confirmado.mensagem);
      return;
    }
    final novo = await showDialog<String>(
      context: context,
      builder: (_) => const DialogoNovoPin(
        titulo: 'Redefinir o PIN do JARVIS',
        confirmar: 'Redefinir',
      ),
    );
    if (novo == null || !mounted) return;
    final resultado = await widget.porta.redefinirComCredencialDoAparelho(novo);
    if (!mounted) return;
    setState(() {
      if (resultado.ok) {
        config = resultado.config;
        erro = null;
        aviso = 'PIN redefinido. Use o novo PIN para entrar.';
      } else {
        aviso = resultado.mensagem;
      }
      digitado.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final digitos = digitado.length;
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_rounded, color: cyan, size: 26),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('J.A.R.V.I.S. BLOQUEADO',
                        style: TextStyle(
                            color: cyan,
                            fontSize: 11,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w700)),
                  ),
                  if (widget.aoConfigurar != null)
                    IconButton(
                      key: const ValueKey('bloqueio-configurar'),
                      tooltip: 'Configurações da tela de bloqueio',
                      onPressed: widget.aoConfigurar,
                      icon: const Icon(Icons.tune_rounded, color: muted),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'Digite seu PIN para continuar',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w300),
              ),
              const SizedBox(height: 6),
              const Text(
                'O PIN fica só neste aparelho, guardado como código irreversível. '
                'O JARVIS não vê o que você digita.',
                style: TextStyle(color: muted, fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 20),
              Container(
                key: const ValueKey('bloqueio-pin-exibido'),
                height: 54,
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cyan.withValues(alpha: .22)),
                ),
                alignment: Alignment.center,
                child: digitos == 0
                    ? const Text('• • • •',
                        style: TextStyle(
                            color: muted, fontSize: 20, letterSpacing: 6))
                    : Text(
                        List.filled(digitos, '●').join(' '),
                        style: const TextStyle(
                            color: cyan, fontSize: 20, letterSpacing: 6),
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                '$digitos de $tamanhoMaxPin dígitos · mínimo $tamanhoMinPin',
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted, fontSize: 10),
              ),
              if (carregando) ... [
                const SizedBox(height: 10),
                const Center(
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))),
              ],
              if (bloqueadoPorTentativas) ...[
                const SizedBox(height: 12),
                Text(
                  'Aguarde ${restante.inSeconds + 1} s antes de tentar de novo.',
                  key: const ValueKey('bloqueio-espera'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFFFFC66D), fontSize: 12, height: 1.4),
                ),
              ],
              if (erro != null) ...[
                const SizedBox(height: 12),
                Text(
                  erro!,
                  key: const ValueKey('bloqueio-erro'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.error, fontSize: 12, height: 1.4),
                ),
              ],
              if (aviso != null) ...[
                const SizedBox(height: 10),
                Text(
                  aviso!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFFFFC66D), fontSize: 11, height: 1.4),
                ),
              ],
              const SizedBox(height: 18),
              _teclado(),
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const ValueKey('bloqueio-desbloquear'),
                onPressed: verificando || bloqueadoPorTentativas
                    ? null
                    : _conferir,
                icon: verificando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.lock_open_rounded, size: 19),
                label: Text(verificando ? 'Verificando…' : 'Desbloquear'),
              ),
              if (bio.podeUsar && config.biometria) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey('bloqueio-biometria'),
                  onPressed: verificando ? null : _usarBiometria,
                  icon: const Icon(Icons.fingerprint_rounded, size: 20),
                  label: const Text('Usar biometria'),
                ),
              ],
              const SizedBox(height: 4),
              TextButton(
                key: const ValueKey('bloqueio-esqueci'),
                onPressed: verificando ? null : _recuperar,
                child: const Text('Esqueci o PIN'),
              ),
              const Text(
                'A recuperação exige a credencial do próprio aparelho (PIN, padrão ou senha da tela). '
                'Sem ela, só reinstalando o app — e os dados locais são perdidos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 10, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _teclado() {
    Widget tecla(String rotulo, {Key? chave, VoidCallback? aoTocar, Widget? icone}) =>
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: AspectRatio(
              aspectRatio: 1.5,
              child: Material(
                color: panel,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  key: chave,
                  borderRadius: BorderRadius.circular(12),
                  onTap: aoTocar,
                  child: Center(
                    child: icone ??
                        Text(rotulo,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w500)),
                  ),
                ),
              ),
            ),
          ),
        );

    Widget linha(List<Widget> teclas) => Row(children: teclas);

    return Column(
      children: [
        linha([
          for (var n = 1; n <= 3; n++)
            tecla('$n',
                chave: ValueKey('bloqueio-tecla-$n'), aoTocar: () => _tecla('$n')),
        ]),
        linha([
          for (var n = 4; n <= 6; n++)
            tecla('$n',
                chave: ValueKey('bloqueio-tecla-$n'), aoTocar: () => _tecla('$n')),
        ]),
        linha([
          for (var n = 7; n <= 9; n++)
            tecla('$n',
                chave: ValueKey('bloqueio-tecla-$n'), aoTocar: () => _tecla('$n')),
        ]),
        linha([
          const Expanded(child: SizedBox()),
          tecla('0',
              chave: const ValueKey('bloqueio-tecla-0'), aoTocar: () => _tecla('0')),
          tecla('apagar',
              chave: const ValueKey('bloqueio-apagar'),
              aoTocar: _apagar,
              icone: const Icon(Icons.backspace_outlined, size: 19)),
        ]),
      ],
    );
  }
}

/// Diálogo de PIN novo com confirmação; devolve null quando cancela.
class DialogoNovoPin extends StatefulWidget {
  const DialogoNovoPin({super.key, required this.titulo, required this.confirmar});

  final String titulo;
  final String confirmar;

  @override
  State<DialogoNovoPin> createState() => DialogoNovoPinState();
}

class DialogoNovoPinState extends State<DialogoNovoPin> {
  final primeiro = TextEditingController();
  final segundo = TextEditingController();
  String? erro;

  @override
  void dispose() {
    primeiro.dispose();
    segundo.dispose();
    super.dispose();
  }

  void _salvar() {
    final a = primeiro.text.trim();
    final b = segundo.text.trim();
    if (a != b) {
      setState(() => erro = 'Os dois PINs não são iguais.');
      return;
    }
    final politica = avaliarPin(a);
    if (politica != PoliticaPin.ok) {
      setState(() => erro = mensagemPolitica(politica));
      return;
    }
    Navigator.of(context).pop(a);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('novo-pin'),
            controller: primeiro,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: tamanhoMaxPin,
            decoration: const InputDecoration(
              labelText: 'Novo PIN',
              helperText: 'De 4 a 8 dígitos, sem sequência nem repetição.',
              border: OutlineInputBorder(),
            ),
          ),
          TextField(
            key: const ValueKey('novo-pin-confirmar'),
            controller: segundo,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: tamanhoMaxPin,
            decoration: const InputDecoration(
              labelText: 'Repita o novo PIN',
              border: OutlineInputBorder(),
            ),
          ),
          if (erro != null)
            Text(erro!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error, fontSize: 11.5)),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        FilledButton(
            key: const ValueKey('novo-pin-salvar'),
            onPressed: _salvar,
            child: Text(widget.confirmar)),
      ],
    );
  }
}
