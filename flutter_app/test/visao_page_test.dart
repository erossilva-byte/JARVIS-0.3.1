import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/visao.dart';
import 'package:jarvis_nova/services/visao_camera.dart';
import 'package:jarvis_nova/services/visao_page.dart';
import 'package:jarvis_nova/services/visao_service.dart';
import 'package:jarvis_nova/services/video_quadros.dart';
import 'package:material_ui/material_ui.dart';

final _png = Uint8List.fromList(base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
));

const _jsonEstruturado = '''
```json
{
  "summary": "Uma caneca branca sobre a mesa.",
  "objects": [
    {"label": "caneca", "confidence": 0.92, "bbox": [0.1, 0.1, 0.25, 0.25]},
    {"label": "mulher", "confidence": 0.88, "bbox": [0.5, 0.2, 0.2, 0.4]}
  ],
  "text": ["CAFÉ"]
}
```
''';

class AnalisadorFalso implements AnalisadorVisao {
  AnalisadorFalso({this.nome = 'Gemini 2.5 Flash'});

  String? nome;
  String resposta = 'Uma caneca branca sobre a mesa.';
  Object? erro;
  ImagemParaAnalise? recebida;
  String? perguntaRecebida;
  bool fechado = false;

  @override
  Future<String?> provedorAtual() async => nome;

  @override
  Future<String> analisar(
      {required ImagemParaAnalise imagem, String pergunta = ''}) async {
    recebida = imagem;
    perguntaRecebida = pergunta;
    if (erro != null) throw erro!;
    return resposta;
  }

  @override
  void fechar() => fechado = true;
}

class ExtratorFalso implements ExtratorQuadros {
  int chamadas = 0;

  @override
  Future<VideoQuadros> extrair(String caminho, {int maximo = 6}) async {
    chamadas++;
    return VideoQuadros(
      duracaoMs: 6000,
      quadros: [
        QuadroVideo(bytes: _png, tempoMs: 1500, largura: 1, altura: 1),
        QuadroVideo(bytes: _png, tempoMs: 4500, largura: 1, altura: 1),
      ],
    );
  }
}

class CameraFalsa implements CameraVisao {
  CameraFalsa({Uint8List? foto}) : foto = foto ?? _png;

  Uint8List foto;
  bool _disponivel = false;
  bool _gravando = false;
  bool _flash = false;

  @override
  bool get disponivel => _disponivel;
  @override
  bool get gravando => _gravando;
  @override
  bool get temFlash => true;
  @override
  bool get flashLigado => _flash;
  @override
  bool get suportada => true;
  @override
  double get zoom => 1.5;
  @override
  double get zoomMin => 1;
  @override
  double get zoomMax => 5;
  @override
  int get totalCameras => 2;
  @override
  String? get erro => null;

  @override
  Future<void> inicializar() async => _disponivel = true;
  @override
  Future<void> liberar() async => _disponivel = false;
  @override
  Widget construirPreview() => const ColoredBox(
        key: ValueKey('preview-falso'),
        color: Colors.black,
      );
  @override
  Future<Uint8List> tirarFoto() async => foto;
  @override
  Future<void> alternarCamera() async {}
  @override
  Future<void> alternarFlash() async => _flash = !_flash;
  @override
  Future<void> definirZoom(double valor) async {}
  @override
  Future<void> iniciarVideo() async => _gravando = true;
  @override
  Future<String> pararVideo() async {
    _gravando = false;
    return '/tmp/video.mp4';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> revelar(WidgetTester tester, Finder alvo) async {
    if (alvo.evaluate().isEmpty) {
      await tester.dragUntilVisible(
          alvo, find.byType(ListView), const Offset(0, -220));
    }
    await tester.ensureVisible(alvo);
    await tester.pumpAndSettle();
  }

  Future<void> escolherGaleria(WidgetTester tester) async {
    final botao = find.byKey(const ValueKey('escolher-galeria'));
    await revelar(tester, botao);
    await tester.tap(botao);
    await tester.pumpAndSettle();
  }

  Future<void> analisar(WidgetTester tester) async {
    final botao = find.byKey(const ValueKey('analisar-imagem'));
    await revelar(tester, botao);
    await tester.tap(botao);
    await tester.pumpAndSettle();
  }

  testWidgets('sem consentimento, a análise fica bloqueada e nada é enviado',
      (tester) async {
    final analisador = AnalisadorFalso();
    await tester.pumpWidget(MaterialApp(
      home: VisaoPage(
        analisador: analisador,
        consentimentoInicial: false,
        escolher: (_) async => ImagemParaAnalise(
            bytes: _png, mime: 'image/png', nome: 'caneca.png'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(
        find.textContaining('não faz reconhecimento facial'), findsOneWidget);
    await escolherGaleria(tester);
    final botaoAnalisar = find.byKey(const ValueKey('analisar-imagem'));
    await revelar(tester, botaoAnalisar);
    expect(find.textContaining('Análise por Gemini 2.5 Flash'), findsOneWidget);
    expect(find.textContaining('caneca.png'), findsOneWidget);
    expect(analisador.recebida, isNull);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('analisar-imagem')))
            .onPressed,
        isNull);

    await tester.drag(find.byType(ListView), const Offset(0, 1200));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('switch-consentimento')));
    await tester.pumpAndSettle();
    await revelar(tester, botaoAnalisar);
    expect(tester.widget<FilledButton>(botaoAnalisar).onPressed, isNotNull);
  });

  testWidgets('consentimento autorizado libera a análise e preserva a pergunta',
      (tester) async {
    final analisador = AnalisadorFalso();
    await tester.pumpWidget(MaterialApp(
      home: VisaoPage(
        analisador: analisador,
        consentimentoInicial: true,
        escolher: (_) async => ImagemParaAnalise(
            bytes: _png, mime: 'image/png', nome: 'caneca.png'),
      ),
    ));
    await tester.pumpAndSettle();

    await escolherGaleria(tester);
    final campo = find.byType(TextField);
    await revelar(tester, campo);
    await tester.enterText(campo, 'o que é isso?');
    await analisar(tester);

    expect(analisador.recebida, isNotNull);
    expect(analisador.perguntaRecebida, 'o que é isso?');
    expect(
        find.textContaining('Uma caneca branca sobre a mesa.'), findsWidgets);
  });

  testWidgets('JSON estruturado vira balões e pessoa não é identificada',
      (tester) async {
    final analisador = AnalisadorFalso()..resposta = _jsonEstruturado;
    await tester.pumpWidget(MaterialApp(
      home: VisaoPage(
        analisador: analisador,
        consentimentoInicial: true,
        escolher: (_) async => ImagemParaAnalise(
            bytes: _png, mime: 'image/png', nome: 'caneca.png'),
      ),
    ));
    await tester.pumpAndSettle();

    await escolherGaleria(tester);
    await analisar(tester);

    expect(find.byKey(const ValueKey('balao-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('balao-1')), findsOneWidget);
    expect(find.text('Pessoa'), findsWidgets);
    expect(find.text('mulher'), findsNothing);
    expect(find.byKey(const ValueKey('salvar-baloes')), findsOneWidget);
  });

  testWidgets('texto sem JSON mostra a análise e avisa que não há balões',
      (tester) async {
    final analisador = AnalisadorFalso();
    await tester.pumpWidget(MaterialApp(
      home: VisaoPage(
        analisador: analisador,
        consentimentoInicial: true,
        escolher: (_) async => ImagemParaAnalise(
            bytes: _png, mime: 'image/png', nome: 'caneca.png'),
      ),
    ));
    await tester.pumpAndSettle();

    await escolherGaleria(tester);
    await analisar(tester);

    expect(find.byKey(const ValueKey('balao-0')), findsNothing);
    expect(find.textContaining('sem balões'), findsOneWidget);
    expect(
        find.textContaining('Uma caneca branca sobre a mesa.'), findsWidgets);
  });

  testWidgets('câmera falsa abre, tira foto e analisa automaticamente',
      (tester) async {
    final analisador = AnalisadorFalso()..resposta = _jsonEstruturado;
    final camera = CameraFalsa();
    await tester.pumpWidget(MaterialApp(
      home: VisaoPage(
        analisador: analisador,
        consentimentoInicial: true,
        camera: camera,
      ),
    ));
    await tester.pumpAndSettle();

    final abrir = find.byKey(const ValueKey('abrir-camera'));
    await revelar(tester, abrir);
    await tester.tap(abrir);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('preview-falso')), findsOneWidget);

    final capturar = find.byKey(const ValueKey('capturar-foto'));
    await revelar(tester, capturar);
    await tester.tap(capturar);
    await tester.pumpAndSettle();

    expect(analisador.recebida, isNotNull);
    expect(find.byKey(const ValueKey('balao-0')), findsOneWidget);
  });

  testWidgets('vídeo grava, extrai quadros e mostra linha do tempo',
      (tester) async {
    final analisador = AnalisadorFalso()..resposta = _jsonEstruturado;
    final camera = CameraFalsa();
    final extrator = ExtratorFalso();
    await tester.pumpWidget(MaterialApp(
      home: VisaoPage(
        analisador: analisador,
        consentimentoInicial: true,
        camera: camera,
        extratorQuadros: extrator,
        salvarVideo: (_) async {},
      ),
    ));
    await tester.pumpAndSettle();

    final abrir = find.byKey(const ValueKey('abrir-camera'));
    await revelar(tester, abrir);
    await tester.tap(abrir);
    await tester.pumpAndSettle();

    final gravar = find.byKey(const ValueKey('gravar-video'));
    await revelar(tester, gravar);
    await tester.tap(gravar);
    await tester.pump();
    await tester.tap(gravar);
    await tester.pumpAndSettle();

    final analisarVideo = find.byKey(const ValueKey('analisar-video'));
    await revelar(tester, analisarVideo);
    await tester.tap(analisarVideo);
    await tester.pumpAndSettle();

    expect(extrator.chamadas, 1);
    expect(analisador.recebida, isNotNull);
    expect(find.byKey(const ValueKey('quadro-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('quadro-1')), findsOneWidget);
    expect(find.text('0:01'), findsWidgets);
  });

  testWidgets('sem provedor configurado, avisa e não deixa analisar',
      (tester) async {
    final analisador = AnalisadorFalso(nome: null);
    await tester.pumpWidget(MaterialApp(
      home: VisaoPage(
        analisador: analisador,
        consentimentoInicial: true,
        escolher: (_) async => ImagemParaAnalise(
            bytes: _png, mime: 'image/png', nome: 'caneca.png'),
      ),
    ));
    await tester.pumpAndSettle();

    await escolherGaleria(tester);
    final botao = find.byKey(const ValueKey('analisar-imagem'));
    await revelar(tester, botao);
    expect(find.textContaining('Nenhum provedor com visão'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('analisar-imagem')))
            .onPressed,
        isNull);
  });

  testWidgets('falha do provedor aparece na tela sem sumir com a imagem',
      (tester) async {
    final analisador = AnalisadorFalso()
      ..erro = StateError('O provedor recusou a análise.');
    await tester.pumpWidget(MaterialApp(
      home: VisaoPage(
        analisador: analisador,
        consentimentoInicial: true,
        escolher: (_) async => ImagemParaAnalise(
            bytes: _png, mime: 'image/png', nome: 'caneca.png'),
      ),
    ));
    await tester.pumpAndSettle();

    await escolherGaleria(tester);
    await analisar(tester);

    expect(
        find.textContaining('O provedor recusou a análise.'), findsOneWidget);
    expect(find.textContaining('caneca.png'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('formato não suportado é recusado antes de qualquer envio',
      (tester) async {
    final analisador = AnalisadorFalso();
    await tester.pumpWidget(MaterialApp(
      home: VisaoPage(
        analisador: analisador,
        consentimentoInicial: true,
        escolher: (_) async => ImagemParaAnalise(
          bytes: Uint8List.fromList([1, 2, 3]),
          mime: 'image/heic',
          nome: 'foto.heic',
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await escolherGaleria(tester);
    expect(find.textContaining('Formato não aceito'), findsOneWidget);
    expect(find.textContaining('não pôde ser lida'), findsNothing);
    expect(analisador.recebida, isNull);
    expect(find.textContaining('foto.heic'), findsNothing);
  });
}
