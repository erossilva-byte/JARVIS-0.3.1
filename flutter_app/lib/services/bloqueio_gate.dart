import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/seguranca.dart';
import '../ui_common.dart';
import 'biometria_service.dart';
import 'bloqueio_page.dart';
import 'bloqueio_store.dart';
import 'modo_visita_page.dart';
import 'seguranca_page.dart';

/// Controla o bloqueio global do app.
///
/// Existe para a tela de configurações poder bloquear na hora sem conhecer o
/// widget que envolve o app.
class ControladorBloqueio extends ChangeNotifier {
  bool _bloqueado = false;

  bool get bloqueado => _bloqueado;

  void bloquear() {
    if (_bloqueado) return;
    _bloqueado = true;
    notifyListeners();
  }

  void desbloquear() {
    if (!_bloqueado) return;
    _bloqueado = false;
    notifyListeners();
  }
}

/// Controlador único do app; a tela de segurança usa o mesmo.
final controladorBloqueio = ControladorBloqueio();

/// Envolve o app e cobre tudo com a tela de bloqueio quando o PIN está ativo.
///
/// Regras: bloqueia ao abrir e ao voltar do segundo plano depois do tempo
/// escolhido. Não bloqueia durante uma saída curta (abrir a câmera, escolher uma
/// foto, atender uma ligação) se o tempo ainda não passou.
class BloqueioGate extends StatefulWidget {
  const BloqueioGate({
    super.key,
    required this.child,
    this.porta,
    this.biometria,
  });

  final Widget child;
  final PortaBloqueio? porta;
  final BiometriaGateway? biometria;

  @override
  State<BloqueioGate> createState() => _BloqueioGateState();
}

class _BloqueioGateState extends State<BloqueioGate> with WidgetsBindingObserver {
  late final PortaBloqueio porta = widget.porta ?? BloqueioStore();
  late final BiometriaGateway biometria = widget.biometria ?? BiometriaService();

  ConfigBloqueio config = ConfigBloqueio.desligado;
  DateTime? saiuEm;
  bool carregando = true;

  /// `true` enquanto o app está aberto pelo PIN de coação.
  ///
  /// Nesse estado o app real nem é montado: no lugar dele aparece o
  /// [ModoVisitaPage]. A escuta da palavra de ativação é desligada para o
  /// JARVIS não falar dados reais em voz alta.
  bool visita = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controladorBloqueio.addListener(_aoControlador);
    unawaited(_carregar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controladorBloqueio.removeListener(_aoControlador);
    super.dispose();
  }

  void _aoControlador() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _carregar() async {
    final lido = await porta.ler();
    if (!mounted) return;
    setState(() {
      config = lido;
      carregando = false;
      if (lido.ativo) controladorBloqueio.bloquear();
    });
  }

  Future<void> _relerConfig() async {
    final lido = await porta.ler();
    if (!mounted) return;
    setState(() => config = lido);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      saiuEm = DateTime.now();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      if (visita) {
        // Quem saiu do modo de visita volta para a tela do PIN: o app real só
        // abre com o PIN principal.
        setState(() => visita = false);
        saiuEm = null;
        controladorBloqueio.bloquear();
        unawaited(_relerConfig());
        return;
      }
      if (deveBloquearAoVoltar(
          config: config, saiuEm: saiuEm, agora: DateTime.now())) {
        controladorBloqueio.bloquear();
      }
      saiuEm = null;
      unawaited(_relerConfig());
    }
  }

  bool get mostrarBloqueio => config.ativo && controladorBloqueio.bloqueado;

  /// Entrada da senha: principal abre o app; o PIN de coação abre o modo de
  /// visita. Biometria nunca cai aqui, porque ela não conhece PIN.
  void _entrar(bool coacao) {
    if (!coacao) {
      controladorBloqueio.desbloquear();
      return;
    }
    unawaited(_pararEscuta());
    setState(() => visita = true);
    controladorBloqueio.desbloquear();
  }

  Future<void> _pararEscuta() async {
    try {
      await jarvisKwsController.stop();
    } catch (_) {
      // Sem detector ligado não há o que parar; o modo de visita continua.
    }
  }

  /// “Bloquear e sair” do modo de visita: volta para a tela do PIN.
  void _sairVisita() {
    setState(() => visita = false);
    controladorBloqueio.bloquear();
  }

  @override
  Widget build(BuildContext context) {
    if (carregando) return widget.child;
    if (visita) {
      return ModoVisitaPage(aoBloquear: _sairVisita);
    }
    return Stack(
      children: [
        widget.child,
        if (mostrarBloqueio)
          Positioned.fill(
            child: TelaBloqueio(
              porta: porta,
              biometria: biometria,
              aoEntrar: _entrar,
              aoDesbloquear: controladorBloqueio.desbloquear,
              aoConfigurar: () {
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => SegurancaPage(porta: porta, biometria: biometria),
                ));
              },
            ),
          ),
      ],
    );
  }
}
