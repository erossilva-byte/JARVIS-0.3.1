import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/historico_voz.dart';
import 'package:jarvis_nova/services/historico_voz_service.dart';
import 'package:jarvis_nova/services/palco_page.dart';
import 'package:jarvis_nova/services/voice_conversation_page.dart';
import 'package:jarvis_nova/services/voz_jarvis.dart';
import 'package:material_ui/material_ui.dart';

class VozFalsa extends VozJarvis {
  @override
  Future<bool> falar(String texto) async => true;

  @override
  Future<void> parar() async {}
}

class HistoricoFalso implements HistoricoVozGateway {
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
  }) async =>
      true;
}

Future<void> abrirConversa(WidgetTester tester, String comando) async {
  tester.view.physicalSize = const Size(500, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home: VoiceConversationPage(
      initialCommand: comando,
      fromVoice: true,
      voz: VozFalsa(),
      historico: HistoricoFalso(),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('“mostra fotos de…” abre o palco já pesquisando', (tester) async {
    await abrirConversa(tester, 'mostra fotos de motor trifásico');

    expect(find.byType(PalcoPage), findsOneWidget);
    final campo =
        tester.widget<TextField>(find.byKey(const ValueKey('palco-campo')));
    expect(campo.controller?.text, 'motor trifásico');
  });

  testWidgets('“traz as últimas notícias de…” abre o palco em notícia',
      (tester) async {
    await abrirConversa(tester, 'traz as últimas notícias de tecnologia');

    expect(find.byType(PalcoPage), findsOneWidget);
    final etiqueta = tester
        .widget<ChoiceChip>(find.byKey(const ValueKey('palco-tipo-noticia')));
    expect(etiqueta.selected, isTrue);
  });

  testWidgets('conversa comum não abre o palco', (tester) async {
    await abrirConversa(tester, 'qual é a capital da França?');

    expect(find.byType(PalcoPage), findsNothing);
    expect(find.text('qual é a capital da França?'), findsWidgets);
  });
}
