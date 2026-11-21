import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/dispositivo.dart';
import 'package:jarvis_nova/services/aparelho_service.dart';
import 'package:jarvis_nova/services/dispositivo_page.dart';
import 'package:material_ui/material_ui.dart';

const canal = MethodChannel('com.jarvis.nova/aparelho');

class _SemPonte extends AparelhoService {
  @override
  Future<InfoDispositivo> infoDispositivo() async {
    throw const AparelhoIndisponivel(
        'Este aparelho não tem a ponte do Jarvis para os recursos do Android.');
  }
}

Future<void> abrir(WidgetTester tester, {AparelhoService? servico}) async {
  tester.view.physicalSize = const Size(430, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
      MaterialApp(home: DispositivoPage(servico: servico)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mostra os números e os apps que o Android devolveu',
      (tester) async {
    final chamadas = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(canal, (chamada) async {
      chamadas.add(chamada);
      switch (chamada.method) {
        case 'dispositivoInfo':
          return {
            'memoriaTotalMb': 12288,
            'memoriaLivreMb': 3072,
            'memoriaBaixa': false,
            'armazenamentoTotalGb': 256.0,
            'armazenamentoLivreGb': 128.0,
            'uptimeMin': 90,
            'bateria': 84,
            'carregando': false,
            'rede': 'wifi',
            'apps': [
              {'pacote': 'com.whatsapp', 'nome': 'WhatsApp'},
              {'pacote': 'com.spotify.music', 'nome': 'Spotify'},
            ],
          };
        case 'abrirApp':
          return {'ok': true, 'mensagem': 'App aberto.'};
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(canal, null));

    await abrir(tester);

    expect(find.textContaining('3072 MB livres'), findsOneWidget);
    expect(find.textContaining('128,0 GB'), findsNothing);
    expect(find.textContaining('128.0 GB'), findsOneWidget);
    expect(find.text('Wi-Fi'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Spotify'), findsOneWidget);
    expect(chamadas.first.method, 'dispositivoInfo');

    await tester.tap(find.byKey(const ValueKey('abrir-app-com.spotify.music')));
    await tester.pumpAndSettle();
    final abertura = chamadas.firstWhere((c) => c.method == 'abrirApp');
    expect((abertura.arguments as Map)['pacote'], 'com.spotify.music');
    expect(find.text('App aberto.'), findsOneWidget);
  });

  testWidgets('sem a ponte nativa, explica em vez de inventar dados',
      (tester) async {
    await abrir(tester, servico: _SemPonte());
    expect(find.textContaining('não tem a ponte'), findsOneWidget);
    expect(find.textContaining('MB livres'), findsNothing);
  });

  testWidgets('busca filtra apps por nome', (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(canal, (chamada) async {
      if (chamada.method == 'dispositivoInfo') {
        return {
          'apps': [
            {'pacote': 'com.whatsapp', 'nome': 'WhatsApp'},
            {'pacote': 'com.spotify.music', 'nome': 'Spotify'},
          ],
        };
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(canal, null));
    await abrir(tester);
    await tester.enterText(find.byKey(const ValueKey('buscar-app')), 'whats');
    await tester.pumpAndSettle();
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Spotify'), findsNothing);
  });
  testWidgets('notificações: sem acesso, explica e abre a autorização',
      (tester) async {
    final chamadas = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(canal, (chamada) async {
      chamadas.add(chamada.method);
      switch (chamada.method) {
        case 'dispositivoInfo':
          return {'bateria': 70, 'rede': 'wifi'};
        case 'notificacoesAcesso':
          return {'ativo': false};
        case 'abrirAjustesNotificacoes':
          return {'ok': true, 'mensagem': 'Abri o acesso a notificações.'};
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(canal, null));

    await abrir(tester);
    expect(find.textContaining('Sem acesso às notificações'), findsOneWidget);
    expect(find.textContaining('Nenhuma notificação'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('autorizar-notificacoes')));
    await tester.pumpAndSettle();
    expect(chamadas.contains('abrirAjustesNotificacoes'), isTrue);
  });

  testWidgets('notificações: com acesso, lista o que o Android entregou',
      (tester) async {
    final chamadas = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(canal, (chamada) async {
      chamadas.add(chamada.method);
      switch (chamada.method) {
        case 'dispositivoInfo':
          return {'bateria': 55};
        case 'notificacoesAcesso':
          return {'ativo': true};
        case 'notificacoes':
          return {
            'itens': [
              {
                'app': 'WhatsApp',
                'titulo': 'Ana',
                'texto': 'Chegando em casa',
                'hora': '2026-11-19T18:20:00.000',
              },
              {
                'app': 'Spotify',
                'titulo': 'Tocando agora',
                'texto': 'Uma faixa qualquer',
                'hora': '2026-11-19T18:19:00.000',
              },
            ],
          };
        case 'limparNotificacoes':
          return {'ok': true, 'mensagem': 'Leitura de notificações limpa.'};
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(canal, null));

    await abrir(tester);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.textContaining('Chegando em casa'), findsOneWidget);
    expect(find.text('Tocando agora'), findsOneWidget);
    expect(find.textContaining('NOTIFICAÇÕES (2)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('limpar-notificacoes')));
    await tester.pumpAndSettle();
    expect(chamadas.contains('limparNotificacoes'), isTrue);
    expect(find.text('Ana'), findsNothing);
  });

  testWidgets('localização: pede permissão e mostra o que o Android devolveu',
      (tester) async {
    final chamadas = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(canal, (chamada) async {
      chamadas.add(chamada.method);
      switch (chamada.method) {
        case 'dispositivoInfo':
          return {'bateria': 66};
        case 'notificacoesAcesso':
          return {'ativo': false};
        case 'localizacaoEstado':
          return {
            'permissao': chamadas.contains('pedirPermissao'),
            'gpsLigado': true,
            'redeLigada': true,
            'geocoder': true,
          };
        case 'pedirPermissao':
          return {'ok': true, 'mensagem': 'Permissão de localização concedida.'};
        case 'localizacao':
          return {
            'ok': true,
            'latitude': -22.90556,
            'longitude': -47.06083,
            'precisaoMetros': 18.4,
            'fonte': 'nova_leitura',
            'provedor': 'gps',
            'idadeMs': 1500,
            'endereco': 'Campinas, São Paulo',
          };
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(canal, null));

    await abrir(tester);
    expect(find.textContaining('Sem permissão'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ver-localizacao')));
    await tester.pumpAndSettle();

    expect(chamadas.contains('pedirPermissao'), isTrue);
    final pedido = chamadas.indexOf('pedirPermissao');
    expect(chamadas.indexOf('localizacao'), greaterThan(pedido));
    expect(find.byKey(const ValueKey('localizacao-resultado')), findsOneWidget);
    expect(find.textContaining('Campinas'), findsOneWidget);
    expect(find.textContaining('-22.90556, -47.06083'), findsOneWidget);
    expect(find.textContaining('±18 m'), findsOneWidget);
    expect(find.byKey(const ValueKey('ouvir-localizacao')), findsOneWidget);
  });

  testWidgets('localização: permissão negada explica e não inventa coordenada',
      (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(canal, (chamada) async {
      switch (chamada.method) {
        case 'dispositivoInfo':
          return {'bateria': 40};
        case 'notificacoesAcesso':
          return {'ativo': false};
        case 'localizacaoEstado':
          return {'permissao': false, 'gpsLigado': true, 'redeLigada': true};
        case 'pedirPermissao':
          return {
            'ok': false,
            'mensagem': 'Permissão de localização negada. Sem ela essa tarefa não roda.',
          };
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(canal, null));

    await abrir(tester);
    await tester.tap(find.byKey(const ValueKey('ver-localizacao')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('erro-localizacao')), findsOneWidget);
    expect(find.textContaining('Permissão de localização negada'), findsOneWidget);
    expect(find.byKey(const ValueKey('localizacao-resultado')), findsNothing);
    expect(find.byKey(const ValueKey('ouvir-localizacao')), findsNothing);
  });

}
