import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/services/aparelho_page.dart';
import 'package:material_ui/material_ui.dart';

const canal = MethodChannel('com.jarvis.nova/aparelho');

Future<void> abrir(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 3400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const MaterialApp(home: AparelhoPage()));
  await tester.pumpAndSettle();
}

List<MethodCall> instalarCanal() {
  final chamadas = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(canal, (chamada) async {
    chamadas.add(chamada);
    switch (chamada.method) {
      case 'status':
        return {
          'bateria': 84,
          'carregando': false,
          'rede': 'Wi-Fi',
          'volume': 40,
          'brilho': 60,
          'modelo': 'Poco X7',
          'android': '15',
        };
      case 'notificacoesAcesso':
        return {'ativo': false};
      case 'appsMensagem':
        return {
          'ids': ['whatsapp', 'sms', 'gmail']
        };
      case 'enviarMensagem':
        return {
          'ok': true,
          'mensagem': 'Abri o WhatsApp para Ana com o texto exato. '
              'Falta tocar em enviar.',
        };
      case 'buscarContatos':
        return {
          'itens': [
            {
              'nome': 'Ana Paula',
              'telefones': ['+55 11 99999-8888'],
            }
          ]
        };
      case 'abrirAjustesNotificacoes':
        return {'ok': true, 'mensagem': 'Abri o acesso a notificações.'};
      case 'spotify':
        return {'ok': true, 'mensagem': 'Pausei o Spotify.'};
      case 'ligar':
        return {'ok': true, 'mensagem': 'Discando para Ana Paula.'};
      default:
        return {'ok': true, 'mensagem': 'ok'};
    }
  });
  addTearDown(() => messenger.setMockMethodCallHandler(canal, null));
  return chamadas;
}

void main() {
  testWidgets('abre com o status real e sem acesso a notificações',
      (tester) async {
    instalarCanal();
    await abrir(tester);

    expect(find.byKey(const ValueKey('aparelho-status')), findsOneWidget);
    expect(find.textContaining('bateria em 84%'), findsOneWidget);
    expect(find.textContaining('rede Wi-Fi'), findsOneWidget);
    expect(find.textContaining('Sem acesso'), findsOneWidget);
  });

  testWidgets('envia o texto exato para o app escolhido', (tester) async {
    final chamadas = instalarCanal();
    await abrir(tester);

    await tester.enterText(
        find.byKey(const ValueKey('mensagem-destino')), 'Ana');
    await tester.enterText(
        find.byKey(const ValueKey('mensagem-texto')), 'chego às 9');
    await tester.tap(find.byKey(const ValueKey('mensagem-enviar')));
    await tester.pumpAndSettle();

    final envio =
        chamadas.firstWhere((c) => c.method == 'enviarMensagem').arguments
            as Map;
    expect(envio['app'], 'whatsapp');
    expect(envio['destino'], 'Ana');
    expect(envio['texto'], 'chego às 9');
    expect(find.textContaining('Falta tocar em enviar'), findsOneWidget);
  });

  testWidgets('os botões do Spotify mandam o controle certo', (tester) async {
    final chamadas = instalarCanal();
    await abrir(tester);

    await tester.tap(find.byKey(const ValueKey('spotify-pausar')));
    await tester.pumpAndSettle();
    final pausa = chamadas.firstWhere((c) => c.method == 'spotify').arguments
        as Map;
    expect(pausa['acao'], 'pausar');

    await tester.tap(find.byKey(const ValueKey('spotify-reiniciar')));
    await tester.pumpAndSettle();
    final reinicio = chamadas.lastWhere((c) => c.method == 'spotify').arguments
        as Map;
    expect(reinicio['acao'], 'reiniciar');
    expect(find.textContaining('Pausei o Spotify'), findsWidgets);
    expect(find.textContaining('MEDIA_PLAY_FROM_SEARCH'), findsOneWidget);
  });

  testWidgets('busca o contato no aparelho e liga pelo telefone',
      (tester) async {
    final chamadas = instalarCanal();
    await abrir(tester);

    await tester.enterText(
        find.byKey(const ValueKey('contato-busca')), 'Ana');
    await tester.tap(find.byKey(const ValueKey('contato-buscar')));
    await tester.pumpAndSettle();

    expect(find.text('Ana Paula'), findsOneWidget);
    expect(find.textContaining('99999'), findsWidgets);

    await tester.tap(find.byIcon(Icons.call_rounded).first);
    await tester.pumpAndSettle();
    final ligacao = chamadas.firstWhere((c) => c.method == 'ligar').arguments
        as Map;
    expect(ligacao['destino'], '+55 11 99999-8888');
  });

  testWidgets('cria ficha a partir do contato e pergunta o básico',
      (tester) async {
    instalarCanal();
    await abrir(tester);

    await tester.enterText(
        find.byKey(const ValueKey('contato-busca')), 'Ana');
    await tester.tap(find.byKey(const ValueKey('contato-buscar')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_add_alt_rounded).first);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ficha-relacao')), findsOneWidget);
    expect(find.textContaining('Qual é a relação dela'), findsOneWidget);
    expect(find.byKey(const ValueKey('ficha-consentimento')), findsOneWidget);
  });
}
