import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/circuito.dart';
import 'package:jarvis_nova/core/circuito_em_uso.dart';
import 'package:jarvis_nova/core/historico_voz.dart';
import 'package:jarvis_nova/services/historico_voz_service.dart';
import 'package:jarvis_nova/services/voice_conversation_page.dart';
import 'package:jarvis_nova/services/voz_jarvis.dart';
import 'package:jarvis_nova/services/conversa_store.dart';
import 'package:material_ui/material_ui.dart';

class VozFalsa extends VozJarvis {
  VozFalsa();
  final falas = <String>[];

  @override
  Future<bool> falar(String texto) async {
    falas.add(texto);
    return true;
  }

  @override
  Future<void> parar() async {}
}

class HistoricoFalso implements HistoricoVozGateway {
  final registros = <Map<String, Object?>>[];

  @override
  Future<List<RegistroExecucao>> carregar() async => const [];

  @override
  Future<bool> limpar() async => true;

  @override
  Future<bool> registrar({
    required String pedido,
    required String acao,
    required bool ok,
    required String mensagem,
    required OrigemExecucao origem,
  }) async {
    registros.add({'pedido': pedido, 'acao': acao, 'ok': ok});
    return true;
  }
}

Future<VozFalsa> abrir(WidgetTester tester, String comando) async {
  tester.view.physicalSize = const Size(500, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final voz = VozFalsa();
  await tester.pumpWidget(MaterialApp(
    home: VoiceConversationPage(
      initialCommand: comando,
      fromVoice: true,
      voz: voz,
      historico: HistoricoFalso(),
    ),
  ));
  await tester.pumpAndSettle();
  return voz;
}

Future<void> enviar(WidgetTester tester, String texto) async {
  await tester.enterText(find.byType(TextField), texto);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

void main() {
  setUp(ConversaStore.reiniciarSessaoParaTeste);
  setUp(CircuitoEmUso.limpar);
  tearDown(CircuitoEmUso.limpar);

  testWidgets('edita o circuito montado no chat e mostra o resultado',
      (tester) async {
    final voz = await abrir(tester, 'monta um divisor de tensão de 12 V');
    final montado = CircuitoEmUso.atual!;
    final rotulos = montado.rotulos();
    final r1 = rotulos[montado.elementos
        .firstWhere((e) => e.tipo == TipoElemento.resistor)
        .id]!;

    await enviar(tester, 'troca o $r1 por 470 ohms');

    expect(find.textContaining('Refiz a simulação'), findsOneWidget);
    expect(find.textContaining('470'), findsWidgets);
    expect(find.byKey(const ValueKey('conversa-circuito-pronto')),
        findsOneWidget);
    expect(voz.falas.last, contains('Refiz a simulação'));

    // O circuito em uso é o editado: é ele que o botão abre no simulador.
    final editado = CircuitoEmUso.atual!.elementos
        .firstWhere((e) => e.tipo == TipoElemento.resistor);
    expect(editado.valor, 470);
  });

  testWidgets('pedido de edição sem circuito aberto não inventa nada',
      (tester) async {
    await abrir(tester, 'troca o R1 por 470 ohms');

    expect(find.textContaining('Não tenho um circuito aberto'), findsOneWidget);
    expect(find.byKey(const ValueKey('conversa-circuito-pronto')),
        findsNothing);
  });

  testWidgets('depois de editar, o botão abre o simulador com o valor novo',
      (tester) async {
    await abrir(tester, 'monta um divisor de tensão de 12 V');
    final montado = CircuitoEmUso.atual!;
    final r1 = montado.rotulos()[montado.elementos
        .firstWhere((e) => e.tipo == TipoElemento.resistor)
        .id]!;
    await enviar(tester, 'muda o $r1 para 2k2');

    await tester.tap(find.byKey(const ValueKey('conversa-abrir-simulador')));
    await tester.pumpAndSettle();

    expect(find.text('Simulador de circuitos'), findsOneWidget);
    expect(find.byKey(const ValueKey('circuito-tabuleiro')), findsOneWidget);
    expect(
        CircuitoEmUso.atual!.elementos
            .firstWhere((e) => e.tipo == TipoElemento.resistor)
            .valor,
        2200);
  });

  testWidgets('recusa de edição não troca o circuito do cartão',
      (tester) async {
    await abrir(tester, 'monta um divisor de tensão de 12 V');
    final antes = CircuitoEmUso.atual!;

    await enviar(tester, 'troca o resistor por 470 ohms');

    expect(find.textContaining('Tem 2 resistores'), findsOneWidget);
    expect(identical(CircuitoEmUso.atual, antes), isTrue);
  });
}
