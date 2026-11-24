import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/historico_voz.dart';
import 'package:jarvis_nova/services/acessibilidade_service.dart';
import 'package:jarvis_nova/services/acessibilidade_store.dart';
import 'package:jarvis_nova/services/historico_voz_service.dart';
import 'package:jarvis_nova/services/voice_conversation_page.dart';
import 'package:jarvis_nova/services/voz_jarvis.dart';
import 'package:jarvis_nova/services/conversa_store.dart';
import 'package:material_ui/material_ui.dart';

class ConsentimentoFalso implements ConsentimentoAcessibilidade {
  ConsentimentoFalso(this.valor);
  bool valor;

  @override
  Future<bool> ativo() async => valor;

  @override
  Future<void> definir(bool novo) async {
    valor = novo;
  }
}

class CanalFalso {
  final chamadas = <String>[];
  final argumentos = <Map<String, Object?>>[];

  Future<Map<Object?, Object?>?> chamar(
      String metodo, Map<String, Object?> args) async {
    chamadas.add(metodo);
    argumentos.add(args);
    if (metodo == 'status') return {'ligado': true, 'pacote': 'com.whatsapp'};
    if (metodo == 'tocar') {
      return {'ok': true, 'mensagem': 'Toquei em "Enviar".'};
    }
    if (metodo == 'ler') {
      return {
        'ok': true,
        'pacote': 'com.whatsapp',
        'nos': [
          {'texto': 'Enviar', 'clicavel': true},
        ],
      };
    }
    return {'ok': true};
  }
}

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
    registros.add({
      'pedido': pedido,
      'acao': acao,
      'ok': ok,
      'mensagem': mensagem,
    });
    return true;
  }
}

Future<(CanalFalso, VozFalsa)> abrir(
  WidgetTester tester,
  String comando, {
  bool consentido = true,
}) async {
  tester.view.physicalSize = const Size(500, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final canal = CanalFalso();
  final voz = VozFalsa();
  await tester.pumpWidget(MaterialApp(
    home: VoiceConversationPage(
      initialCommand: comando,
      fromVoice: true,
      voz: voz,
      historico: HistoricoFalso(),
      tela: AcessibilidadeService(
        chamada: canal.chamar,
        consentimento: ConsentimentoFalso(consentido),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return (canal, voz);
}

void main() {
  setUp(ConversaStore.reiniciarSessaoParaTeste);
  testWidgets('tocar pede confirmação e não chama o Android antes do sim',
      (tester) async {
    final (canal, voz) = await abrir(tester, 'tocar em Enviar');

    expect(find.byKey(const ValueKey('confirmacao-toque-tela')),
        findsOneWidget);
    expect(find.textContaining('Posso tocar em "Enviar"'), findsOneWidget);
    expect(canal.chamadas.where((c) => c == 'tocar'), isEmpty);
    expect(voz.falas.last, contains('Posso tocar'));

    await tester.tap(find.byKey(const ValueKey('confirmar-toque-tela')));
    await tester.pumpAndSettle();

    expect(canal.chamadas, contains('tocar'));
    expect(canal.argumentos.last['texto'], 'Enviar');
    expect(find.textContaining('Toquei em'), findsOneWidget);
    expect(find.byKey(const ValueKey('confirmacao-toque-tela')), findsNothing);
  });

  testWidgets('“não” cancela e nada é tocado', (tester) async {
    final (canal, _) = await abrir(tester, 'tocar em Enviar');

    await tester.enterText(find.byType(TextField), 'não');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.textContaining('Cancelado'), findsOneWidget);
    expect(canal.chamadas.where((c) => c == 'tocar'), isEmpty);
    expect(find.byKey(const ValueKey('confirmacao-toque-tela')), findsNothing);
  });

  testWidgets('ler a tela executa direto, sem confirmação', (tester) async {
    final (canal, _) = await abrir(tester, 'ler a tela');

    expect(canal.chamadas, contains('ler'));
    expect(find.byKey(const ValueKey('confirmacao-toque-tela')), findsNothing);
    expect(find.textContaining('com.whatsapp'), findsWidgets);
  });

  testWidgets('sem consentimento o toque é recusado antes de perguntar',
      (tester) async {
    final (canal, _) = await abrir(tester, 'tocar em Enviar',
        consentido: false);

    expect(find.byKey(const ValueKey('confirmacao-toque-tela')), findsNothing);
    expect(find.textContaining('desligada neste app'), findsOneWidget);
    expect(canal.chamadas.where((c) => c == 'tocar'), isEmpty);
  });

  testWidgets('conversa normal não vira ação de tela', (tester) async {
    final (canal, _) = await abrir(tester, 'como tocar violão');

    expect(canal.chamadas, isEmpty);
    expect(find.byKey(const ValueKey('confirmacao-toque-tela')), findsNothing);
  });
}
