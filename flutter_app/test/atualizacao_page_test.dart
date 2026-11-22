import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/services/atualizacao_page.dart';
import 'package:material_ui/material_ui.dart';

const canal = MethodChannel('com.jarvis.nova/atualizacao');

Future<void> abrir(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const MaterialApp(home: AtualizacaoPage()));
  await tester.pumpAndSettle();
}

List<MethodCall> instalarCanal({bool comAtualizacao = true}) {
  final chamadas = <MethodCall>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(canal, (chamada) async {
    chamadas.add(chamada);
    switch (chamada.method) {
      case 'status':
        return {
          'versao': '1.77.0',
          'versionCode': 17700,
          'pacote': 'com.jarvis.nova',
          'repositorio': 'erossilva-byte/JARVIS-0.3.1',
          'urlReleases': 'https://github.com/erossilva-byte/JARVIS-0.3.1/releases',
          'instaladorAutorizado': false,
          'baixado': false,
          'baixadoBytes': 0,
        };
      case 'verificar':
        if (!comAtualizacao) {
          return {
            'disponivel': false,
            'motivo': 'nenhum-release',
            'versaoInstalada': '1.77.0',
          };
        }
        return {
          'disponivel': true,
          'motivo': 'disponivel',
          'versao': '1.78.0',
          'tag': 'android-v1.78.0',
          'versaoInstalada': '1.77.0',
          'urlApk': 'https://github.com/x/y/releases/download/a/b.apk',
          'nomeArquivo': 'jarvis-nova-1.78.0-arm64.apk',
          'tamanho': 52428800,
          'urlSha256': 'https://github.com/x/y/releases/download/a/b.apk.sha256',
          'digesto': '',
          'notas': 'Atualização OTA',
          'urlRelease': 'https://github.com/x/y/releases/tag/a',
        };
      case 'baixar':
        return {
          'sha256': 'b' * 64,
          'bytes': 52428800,
          'versao': '1.78.0',
          'nomeArquivo': 'jarvis-nova-1.78.0-arm64.apk',
        };
      case 'instalar':
        return {'ok': true, 'mensagem': 'Instalador aberto.'};
      default:
        return true;
    }
  });
  addTearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(canal, null));
  return chamadas;
}

void main() {
  testWidgets('mostra a versão instalada antes de consultar', (tester) async {
    instalarCanal();
    await abrir(tester);

    expect(find.byKey(const ValueKey('atualizacao-status')), findsOneWidget);
    expect(find.text('1.77.0 (build 17700)'), findsOneWidget);
    expect(find.textContaining('ainda não autorizou'), findsOneWidget);
  });

  testWidgets('procura o release e oferece o download',
      (tester) async {
    final chamadas = instalarCanal();
    await abrir(tester);

    await tester.tap(find.byKey(const ValueKey('atualizacao-procurar')));
    await tester.pumpAndSettle();

    expect(chamadas.map((c) => c.method), contains('verificar'));
    expect(find.textContaining('Versão 1.78.0 disponível'), findsOneWidget);
    expect(find.textContaining('publicou o SHA-256'), findsOneWidget);
    expect(find.byKey(const ValueKey('atualizacao-baixar')), findsOneWidget);
  });

  testWidgets('baixa, mostra o SHA-256 conferido e abre o instalador',
      (tester) async {
    final chamadas = instalarCanal();
    await abrir(tester);

    await tester.tap(find.byKey(const ValueKey('atualizacao-procurar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('atualizacao-baixar')));
    await tester.pumpAndSettle();

    expect(chamadas.map((c) => c.method), contains('baixar'));
    expect(find.byKey(const ValueKey('atualizacao-sha256')), findsOneWidget);
    expect(find.textContaining('Confere com o publicado'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('atualizacao-instalar')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('atualizacao-resultado')), findsOneWidget);
    expect(find.text('Instalador aberto.'), findsOneWidget);
  });

  testWidgets('sem release, explica em vez de dizer atualizado',
      (tester) async {
    instalarCanal(comAtualizacao: false);
    await abrir(tester);

    await tester.tap(find.byKey(const ValueKey('atualizacao-procurar')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Não há release publicado'), findsOneWidget);
    expect(find.byKey(const ValueKey('atualizacao-baixar')), findsNothing);
  });

  testWidgets('falha do canal aparece explicada', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (chamada) async {
      if (chamada.method == 'status') {
        throw PlatformException(
            code: 'consulta', message: 'o GitHub respondeu HTTP 403');
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null));

    await abrir(tester);
    expect(find.byKey(const ValueKey('atualizacao-erro')), findsOneWidget);
    expect(find.textContaining('HTTP 403'), findsOneWidget);
  });
}
