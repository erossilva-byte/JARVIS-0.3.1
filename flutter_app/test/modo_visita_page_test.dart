import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/modo_visita.dart';
import 'package:jarvis_nova/core/seguranca.dart';
import 'package:jarvis_nova/services/biometria_service.dart';
import 'package:jarvis_nova/services/bloqueio_gate.dart';
import 'package:jarvis_nova/services/bloqueio_page.dart';
import 'package:jarvis_nova/services/modo_visita_page.dart';
import 'package:material_ui/material_ui.dart';

class _PortaCoacao implements PortaBloqueio {
  _PortaCoacao();

  final String pin = '2583';
  final String coacao = '4719';
  ConfigBloqueio estado = const ConfigBloqueio(
    ativo: true,
    biometria: false,
    espera: Duration.zero,
    tentativas: 0,
  );

  @override
  Future<ConfigBloqueio> ler() async => estado;

  @override
  Future<bool> temPin() async => true;

  @override
  Future<ResultadoTentativa> definirPin(String novo,
          {ConfigBloqueio? config}) async =>
      ResultadoTentativa(ok: true, mensagem: 'PIN definido.', config: estado);

  @override
  Future<ResultadoTentativa> conferir(String digitado,
      {ConfigBloqueio? config}) async {
    final atual = config ?? estado;
    final ehCoacao = digitado == coacao;
    final resultado = avaliarTentativa(
      config: atual,
      pinCorreto: digitado == pin || ehCoacao,
      agora: DateTime.now(),
    );
    estado = resultado.config;
    if (resultado.ok && ehCoacao && digitado != pin) {
      return ResultadoTentativa(
          ok: true,
          mensagem: 'Aberto no modo de visita.',
          config: resultado.config,
          coacao: true);
    }
    return resultado;
  }

  @override
  Future<ResultadoTentativa> alterarPin(String atual, String novo) async =>
      ResultadoTentativa(ok: true, mensagem: 'PIN alterado.', config: estado);

  @override
  Future<ResultadoTentativa> desligar(String atual) async =>
      ResultadoTentativa(ok: true, mensagem: 'Desligado.', config: estado);

  @override
  Future<ResultadoTentativa> redefinirComCredencialDoAparelho(
          String novo) async =>
      ResultadoTentativa(ok: true, mensagem: 'Redefinido.', config: estado);

  @override
  Future<ConfigBloqueio> definirBiometria(bool ativo) async => estado;

  @override
  Future<ConfigBloqueio> definirEspera(Duration espera) async => estado;

  @override
  Future<ConfigBloqueio> registrarDesbloqueio() async => estado;
}

class _Biometria implements BiometriaGateway {
  @override
  Future<BiometriaStatus> status() async => BiometriaStatus.indisponivel;

  @override
  Future<ResultadoBiometria> autenticar({String motivo = ''}) async =>
      const ResultadoBiometria(ok: false, mensagem: 'Sem biometria.');

  @override
  Future<ResultadoBiometria> confirmarCredencialDoAparelho(
          {String motivo = ''}) async =>
      const ResultadoBiometria(ok: false, mensagem: 'Sem biometria.');
}

Future<void> _digitar(WidgetTester tester, String pin) async {
  for (final digito in pin.split('')) {
    final tecla = find.byKey(ValueKey('bloqueio-tecla-$digito'));
    await tester.ensureVisible(tecla);
    await tester.pump();
    await tester.tap(tecla);
    await tester.pump();
  }
  final confirmar = find.byKey(const ValueKey('bloqueio-desbloquear'));
  await tester.ensureVisible(confirmar);
  await tester.pump();
  await tester.tap(confirmar);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('abre como um app recém-instalado e não consulta IA',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: ModoVisitaPage(aoBloquear: () {})));

    expect(find.textContaining('provedor de inteligência'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('visita-entrada')),
        'Jarvis, me fale sobre culinária no geral');
    await tester.tap(find.byKey(const ValueKey('visita-enviar')));
    await tester.pump();

    expect(find.textContaining('me fale sobre culinária'), findsOneWidget);
    expect(find.textContaining('não tenho um provedor'), findsOneWidget);
  });

  testWidgets('horário responde sem provedor e sem dado do dono',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: ModoVisitaPage(aoBloquear: () {})));

    await tester.enterText(
        find.byKey(const ValueKey('visita-entrada')), 'que horas são?');
    await tester.tap(find.byKey(const ValueKey('visita-enviar')));
    await tester.pump();

    expect(find.textContaining(RegExp(r'Agora são \d\d horas e \d\d minutos')),
        findsOneWidget);
  });

  testWidgets('ajustes mostram o prompt "Modo de visita" e nada guardado',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: ModoVisitaPage(aoBloquear: () {})));

    await tester.tap(find.byKey(const ValueKey('visita-ajustes')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('visita-prompt-nome')), findsOneWidget);
    expect(find.text(nomePromptModoVisita), findsOneWidget);
    expect(find.byKey(const ValueKey('visita-prompt')), findsOneWidget);
    for (final item in ajustesVisita) {
      expect(find.text(item.$1), findsOneWidget);
      expect(find.text(item.$2), findsOneWidget);
    }
    expect(find.textContaining('Nenhuma guardada'), findsOneWidget);
  });

  testWidgets('PIN de coação abre o modo de visita, nunca o app real',
      (tester) async {
    final porta = _PortaCoacao();
    await tester.pumpWidget(MaterialApp(
        home: BloqueioGate(
      porta: porta,
      biometria: _Biometria(),
      child: const Scaffold(body: Text('CONTEUDO REAL')),
    )));
    await tester.pumpAndSettle();

    expect(find.byType(TelaBloqueio), findsOneWidget);
    await _digitar(tester, '4719');

    expect(find.byType(ModoVisitaPage), findsOneWidget);
    expect(find.text('CONTEUDO REAL'), findsNothing);
    expect(find.textContaining('provedor de inteligência'), findsOneWidget);

    // “Bloquear e sair” volta para o PIN; o app real continua escondido.
    await tester.tap(find.byKey(const ValueKey('visita-ajustes')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('visita-bloquear')));
    await tester.pumpAndSettle();

    expect(find.byType(ModoVisitaPage), findsNothing);
    expect(find.text('CONTEUDO REAL'), findsNothing);
  });

  testWidgets('PIN principal abre o app real, sem modo de visita',
      (tester) async {
    final porta = _PortaCoacao();
    await tester.pumpWidget(MaterialApp(
        home: BloqueioGate(
      porta: porta,
      biometria: _Biometria(),
      child: const Scaffold(body: Text('CONTEUDO REAL')),
    )));
    await tester.pumpAndSettle();

    await _digitar(tester, '2583');

    expect(find.byType(ModoVisitaPage), findsNothing);
    expect(find.text('CONTEUDO REAL'), findsOneWidget);
  });
}
