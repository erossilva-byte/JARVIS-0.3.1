import 'package:flutter_test/flutter_test.dart';
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
  tester.view.physicalSize = const Size(500, 2200);
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

void main() {
  setUp(ConversaStore.reiniciarSessaoParaTeste);
  testWidgets('pedido de circuito é montado na conversa, sem provedor',
      (tester) async {
    final voz = await abrir(
        tester, 'monta um circuito de lâmpada de 12 V e 5 W com interruptor');

    expect(find.textContaining('Montei o circuito'), findsOneWidget);
    expect(find.textContaining('simulação fechada'), findsWidgets);
    expect(find.byKey(const ValueKey('conversa-circuito-pronto')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('conversa-abrir-simulador')),
        findsOneWidget);
    expect(voz.falas.last, contains('Montei o circuito'));
  });

  testWidgets('o botão leva o circuito montado para o simulador',
      (tester) async {
    await abrir(tester, 'monta um divisor de tensão de 12 V');

    await tester.tap(find.byKey(const ValueKey('conversa-abrir-simulador')));
    await tester.pumpAndSettle();

    // O simulador abre com o esquema já montado: o tabuleiro existe e a tela é
    // a do simulador, não a conversa.
    expect(find.text('Simulador de circuitos'), findsOneWidget);
    expect(find.byKey(const ValueKey('circuito-tabuleiro')), findsOneWidget);
    expect(find.byKey(const ValueKey('conversa-circuito-pronto')), findsNothing);
  });

  testWidgets('recusa honesta não abre o simulador', (tester) async {
    await abrir(tester, 'monta um circuito trifásico industrial');

    expect(find.textContaining('Não montei o circuito'), findsOneWidget);
    expect(find.byKey(const ValueKey('conversa-circuito-pronto')),
        findsNothing);
    expect(find.byKey(const ValueKey('conversa-abrir-simulador')),
        findsNothing);
  });

  testWidgets('conversa comum não vira circuito', (tester) async {
    await abrir(tester, 'como tocar violão');

    expect(find.byKey(const ValueKey('conversa-circuito-pronto')),
        findsNothing);
    expect(find.textContaining('Montei o circuito'), findsNothing);
  });
}
