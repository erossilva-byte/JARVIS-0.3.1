import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/services/atualizacao_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const canal = MethodChannel('com.jarvis.nova/atualizacao');
  final chamadas = <MethodCall>[];

  void instalarCanal(Future<Object?> Function(MethodCall) responder) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (chamada) {
      chamadas.add(chamada);
      return responder(chamada);
    });
  }

  setUp(() {
    chamadas.clear();
    instalarCanal((chamada) async {
      switch (chamada.method) {
        case 'status':
          return {
            'versao': '1.77.0',
            'versionCode': 17700,
            'pacote': 'com.jarvis.nova',
            'repositorio': 'erossilva-byte/JARVIS-0.3.1',
            'urlReleases': 'https://github.com/erossilva-byte/JARVIS-0.3.1/releases',
            'instaladorAutorizado': false,
            'baixado': true,
            'baixadoBytes': 52428800,
          };
        case 'verificar':
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
            'sha256': 'a' * 64,
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
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);
  });

  test('lê a versão instalada e o estado do arquivo', () async {
    final estado = await AtualizacaoService().status();
    expect(estado.versao, '1.77.0');
    expect(estado.versionCode, 17700);
    expect(estado.versaoCompleta, '1.77.0 (build 17700)');
    expect(estado.baixado, isTrue);
    expect(estado.instaladorAutorizado, isFalse);
    expect(chamadas.single.method, 'status');
  });

  test('descreve o release publicado', () async {
    final release = await AtualizacaoService().verificar();
    expect(release.disponivel, isTrue);
    expect(release.versao, '1.78.0');
    expect(release.temDigestoPublicado, isTrue);
    expect(release.nomeArquivo, 'jarvis-nova-1.78.0-arm64.apk');
  });

  test('download devolve o SHA-256 calculado', () async {
    final resultado = await AtualizacaoService().baixar();
    expect(resultado.sha256, 'a' * 64);
    expect(resultado.bytes, 52428800);
  });

  test('instalação devolve a resposta do Android', () async {
    final resultado = await AtualizacaoService().instalar();
    expect(resultado.ok, isTrue);
    expect(resultado.mensagem, 'Instalador aberto.');
  });

  test('erro do Android chega explicado, sem inventar sucesso', () async {
    instalarCanal((chamada) async =>
        throw PlatformException(code: 'download', message: 'SHA-256 não confere.'));
    await expectLater(
      AtualizacaoService().baixar(),
      throwsA(isA<AtualizacaoIndisponivel>()
          .having((e) => e.mensagem, 'mensagem', 'SHA-256 não confere.')),
    );
  });

  test('sem ponte nativa a chamada falha explicada', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);
    await expectLater(
      AtualizacaoService().status(),
      throwsA(isA<AtualizacaoIndisponivel>()),
    );
  });

  test('lê o hash do arquivo .sha256 no formato do sha256sum', () {
    const conteudo =
        '3d1c2f0b9a8e7d6c5b4a39281706f5e4d3c2b1a0918273645f6e7d8c9b0a1f2e  jarvis-nova-1.78.0-arm64.apk\n';
    expect(hashSha256Publicado(conteudo),
        '3d1c2f0b9a8e7d6c5b4a39281706f5e4d3c2b1a0918273645f6e7d8c9b0a1f2e');
    expect(hashSha256Publicado('sem hash aqui'), isNull);
  });

  test('compara versões numéricas', () {
    expect(versaoMaiorQue('1.78.0', '1.77.0'), isTrue);
    expect(versaoMaiorQue('1.77.0', '1.77.0'), isFalse);
    expect(versaoMaiorQue('1.77.1', '1.78.0'), isFalse);
    expect(versaoMaiorQue('2.0', '1.99.9'), isTrue);
  });

  test('motivo sem release tem frase honesta', () {
    expect(mensagemDoMotivo('nenhum-release'), contains('Não há release'));
    expect(mensagemDoMotivo('atualizado'), contains('mais recente'));
  });
}
