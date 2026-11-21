import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/seguranca.dart';
import 'package:jarvis_nova/services/biometria_service.dart';
import 'package:jarvis_nova/services/bloqueio_gate.dart';
import 'package:jarvis_nova/services/bloqueio_page.dart';
import 'package:material_ui/material_ui.dart';

class PortaFalsa implements PortaBloqueio {
  PortaFalsa({this.pin = '2583', ConfigBloqueio? config})
      : estado = config ??
            const ConfigBloqueio(
              ativo: true,
              biometria: false,
              espera: Duration.zero,
              tentativas: 0,
            );

  String pin;
  ConfigBloqueio estado;
  int conferidas = 0;
  int registros = 0;
  bool falharCredencial = false;

  @override
  Future<ConfigBloqueio> ler() async => estado;

  @override
  Future<bool> temPin() async => pin.isNotEmpty;

  @override
  Future<ResultadoTentativa> definirPin(String novo, {ConfigBloqueio? config}) async {
    pin = novo;
    estado = estado.copiarCom(ativo: true, tentativas: 0, limparBloqueio: true);
    return ResultadoTentativa(
        ok: true, mensagem: 'PIN definido.', config: estado);
  }

  @override
  Future<ResultadoTentativa> conferir(String digitado, {ConfigBloqueio? config}) async {
    conferidas++;
    final resultado = avaliarTentativa(
      config: estado,
      pinCorreto: digitado == pin,
      agora: DateTime.now(),
    );
    estado = resultado.config;
    return resultado;
  }

  @override
  Future<ResultadoTentativa> alterarPin(String atual, String novo) async {
    if (atual != pin) {
      return ResultadoTentativa(
          ok: false, mensagem: 'PIN atual incorreto.', config: estado);
    }
    pin = novo;
    return ResultadoTentativa(ok: true, mensagem: 'PIN alterado.', config: estado);
  }

  @override
  Future<ResultadoTentativa> desligar(String atual) async {
    if (atual != pin) {
      return ResultadoTentativa(
          ok: false, mensagem: 'PIN atual incorreto.', config: estado);
    }
    pin = '';
    estado = ConfigBloqueio.desligado;
    return ResultadoTentativa(
        ok: true, mensagem: 'Bloqueio desligado.', config: estado);
  }

  @override
  Future<ResultadoTentativa> redefinirComCredencialDoAparelho(String novo) async {
    if (falharCredencial) {
      return ResultadoTentativa(
          ok: false, mensagem: 'Credencial recusada.', config: estado);
    }
    pin = novo;
    return ResultadoTentativa(
        ok: true, mensagem: 'PIN redefinido.', config: estado);
  }

  @override
  Future<ConfigBloqueio> definirBiometria(bool ativo) async {
    estado = estado.copiarCom(biometria: ativo);
    return estado;
  }

  @override
  Future<ConfigBloqueio> definirEspera(Duration espera) async {
    estado = estado.copiarCom(espera: espera);
    return estado;
  }

  @override
  Future<ConfigBloqueio> registrarDesbloqueio() async {
    registros++;
    estado = estado.copiarCom(tentativas: 0, limparBloqueio: true);
    return estado;
  }
}

class BiometriaFalsa implements BiometriaGateway {
  BiometriaFalsa({this.pronta = true, this.confirma = true});

  bool pronta;
  bool confirma;
  int pedidos = 0;
  int credenciais = 0;

  @override
  Future<BiometriaStatus> status() async =>
      BiometriaStatus(estado: pronta ? EstadoBiometria.pronto : EstadoBiometria.indisponivel);

  @override
  Future<ResultadoBiometria> autenticar({String motivo = ''}) async {
    pedidos++;
    return ResultadoBiometria(
        ok: confirma, mensagem: confirma ? 'Biometria confirmada.' : 'Não confirmada.');
  }

  @override
  Future<ResultadoBiometria> confirmarCredencialDoAparelho({String motivo = ''}) async {
    credenciais++;
    return ResultadoBiometria(
        ok: confirma, mensagem: confirma ? 'Confirmada.' : 'Cancelada.');
  }
}

void main() {
  Future<void> abrirTela(
    WidgetTester tester, {
    required PortaFalsa porta,
    required BiometriaFalsa biometria,
    VoidCallback? aoDesbloquear,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: TelaBloqueio(
        porta: porta,
        biometria: biometria,
        aoDesbloquear: aoDesbloquear,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> digitar(WidgetTester tester, String pin) async {
    for (final digito in pin.split('')) {
      final tecla = find.byKey(ValueKey('bloqueio-tecla-$digito'));
      await tester.ensureVisible(tecla);
      await tester.tap(tecla);
      await tester.pump();
    }
  }

  Future<void> desbloquear(WidgetTester tester) async {
    final botao = find.byKey(const ValueKey('bloqueio-desbloquear'));
    await tester.ensureVisible(botao);
    await tester.tap(botao);
    await tester.pumpAndSettle();
  }

  testWidgets('PIN correto desbloqueia e zera as tentativas', (tester) async {
    final porta = PortaFalsa();
    var desbloqueado = false;
    await abrirTela(
      tester,
      porta: porta,
      biometria: BiometriaFalsa(),
      aoDesbloquear: () => desbloqueado = true,
    );

    expect(find.textContaining('J.A.R.V.I.S. BLOQUEADO'), findsOneWidget);
    await digitar(tester, '2583');
    await desbloquear(tester);

    expect(desbloqueado, isTrue);
    expect(porta.registros, 1);
  });

  testWidgets('PIN errado mostra o erro e conta a tentativa', (tester) async {
    final porta = PortaFalsa();
    var desbloqueado = false;
    await abrirTela(
      tester,
      porta: porta,
      biometria: BiometriaFalsa(),
      aoDesbloquear: () => desbloqueado = true,
    );

    await digitar(tester, '1112');
    await desbloquear(tester);

    expect(desbloqueado, isFalse);
    expect(find.textContaining('PIN incorreto'), findsOneWidget);
    expect(porta.estado.tentativas, 1);
  });

  testWidgets('depois do limite, a espera aparece e o botão fica travado',
      (tester) async {
    final porta = PortaFalsa(
      config: const ConfigBloqueio(
        ativo: true,
        biometria: false,
        espera: Duration.zero,
        tentativas: tentativasAntesDeEspera - 1,
      ),
    );
    await abrirTela(tester, porta: porta, biometria: BiometriaFalsa());

    await digitar(tester, '1112');
    await desbloquear(tester);

    expect(find.byKey(const ValueKey('bloqueio-espera')), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('bloqueio-desbloquear')))
            .onPressed,
        isNull);
  });

  testWidgets('com biometria ligada e disponível, o botão desbloqueia',
      (tester) async {
    final porta = PortaFalsa(
      config: const ConfigBloqueio(
        ativo: true,
        biometria: true,
        espera: Duration.zero,
        tentativas: 0,
      ),
    );
    final biometria = BiometriaFalsa();
    var desbloqueado = false;
    await abrirTela(
      tester,
      porta: porta,
      biometria: biometria,
      aoDesbloquear: () => desbloqueado = true,
    );

    final botao = find.byKey(const ValueKey('bloqueio-biometria'));
    await tester.ensureVisible(botao);
    await tester.tap(botao);
    await tester.pumpAndSettle();

    expect(desbloqueado, isTrue);
    expect(biometria.pedidos, greaterThanOrEqualTo(1));
  });

  testWidgets('sem biometria no aparelho o botão não aparece', (tester) async {
    final porta = PortaFalsa(
      config: const ConfigBloqueio(
        ativo: true,
        biometria: true,
        espera: Duration.zero,
        tentativas: 0,
      ),
    );
    await abrirTela(
      tester,
      porta: porta,
      biometria: BiometriaFalsa(pronta: false),
    );

    expect(find.byKey(const ValueKey('bloqueio-biometria')), findsNothing);
  });

  testWidgets('recuperação usa a credencial do aparelho antes de redefinir',
      (tester) async {
    final porta = PortaFalsa();
    final biometria = BiometriaFalsa(confirma: false);
    await abrirTela(tester, porta: porta, biometria: biometria);

    final esqueci = find.byKey(const ValueKey('bloqueio-esqueci'));
    await tester.ensureVisible(esqueci);
    await tester.tap(esqueci);
    await tester.pumpAndSettle();

    expect(biometria.credenciais, 1);
    expect(find.textContaining('Cancelada'), findsOneWidget);
  });

  testWidgets('gate mostra o app quando o bloqueio está desligado',
      (tester) async {
    final porta = PortaFalsa(config: ConfigBloqueio.desligado);
    await tester.pumpWidget(MaterialApp(
      home: BloqueioGate(
        porta: porta,
        biometria: BiometriaFalsa(),
        child: const Scaffold(body: Text('conteúdo do app')),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('conteúdo do app'), findsOneWidget);
    expect(find.textContaining('J.A.R.V.I.S. BLOQUEADO'), findsNothing);
  });

  testWidgets('gate cobre o app quando o bloqueio está ativo', (tester) async {
    final porta = PortaFalsa();
    await tester.pumpWidget(MaterialApp(
      home: BloqueioGate(
        porta: porta,
        biometria: BiometriaFalsa(),
        child: const Scaffold(body: Text('conteúdo do app')),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('J.A.R.V.I.S. BLOQUEADO'), findsOneWidget);
    expect(find.text('conteúdo do app'), findsOneWidget,
        reason: 'o app continua montado, mas coberto pela tela de bloqueio');
  });
}
