import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/visao.dart';
import 'package:jarvis_nova/services/visao_page.dart';
import 'package:jarvis_nova/services/visao_service.dart';
import 'package:material_ui/material_ui.dart';

final _png = Uint8List.fromList(base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
));

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
  Future<String> analisar({required ImagemParaAnalise imagem, String pergunta = ''}) async {
    recebida = imagem;
    perguntaRecebida = pergunta;
    if (erro != null) throw erro!;
    return resposta;
  }

  @override
  void fechar() => fechado = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> escolherGaleria(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('escolher-galeria')));
    await tester.pumpAndSettle();
  }

  Future<void> revelar(WidgetTester tester, Finder alvo) async {
    if (alvo.evaluate().isEmpty) {
      await tester.dragUntilVisible(alvo, find.byType(ListView), const Offset(0, -220));
    }
    await tester.ensureVisible(alvo);
    await tester.pumpAndSettle();
  }

  Future<void> autorizar(WidgetTester tester) async {
    final caixa = find.byType(Checkbox);
    await revelar(tester, caixa);
    await tester.tap(caixa);
    await tester.pumpAndSettle();
  }

  Future<void> analisar(WidgetTester tester) async {
    final botao = find.byKey(const ValueKey('analisar-imagem'));
    await revelar(tester, botao);
    await tester.tap(botao);
    await tester.pumpAndSettle();
  }

  testWidgets('sem imagem nem consentimento, a análise fica bloqueada', (tester) async {
    final analisador = AnalisadorFalso();
    await tester.pumpWidget(MaterialApp(
      home: VisaoPage(
        analisador: analisador,
        escolher: (_) async => ImagemParaAnalise(bytes: _png, mime: 'image/png', nome: 'caneca.png'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('não faz reconhecimento facial'), findsOneWidget);
    expect(find.textContaining('Análise por Gemini 2.5 Flash'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('analisar-imagem'))).onPressed, isNull);
  });

  testWidgets('escolher a imagem não envia sozinho e o consentimento libera a análise', (tester) async {
    final analisador = AnalisadorFalso();
    await tester.pumpWidget(MaterialApp(
      home: VisaoPage(
        analisador: analisador,
        escolher: (_) async => ImagemParaAnalise(bytes: _png, mime: 'image/png', nome: 'caneca.png'),
      ),
    ));
    await tester.pumpAndSettle();

    await escolherGaleria(tester);
    expect(find.textContaining('caneca.png'), findsOneWidget);
    expect(analisador.recebida, isNull, reason: 'imagem enviada antes do consentimento');
    final botao = find.byKey(const ValueKey('analisar-imagem'));
    await revelar(tester, botao);
    expect(tester.widget<FilledButton>(botao).onPressed, isNull);

    await autorizar(tester);
    final campo = find.byType(TextField);
    await revelar(tester, campo);
    await tester.enterText(campo, 'o que é isso?');
    await analisar(tester);

    expect(analisador.recebida, isNotNull);
    expect(analisador.recebida!.bytes.length, _png.length);
    expect(analisador.perguntaRecebida, 'o que é isso?');
    expect(find.text('Uma caneca branca sobre a mesa.'), findsOneWidget);
  });

  testWidgets('sem provedor configurado, avisa e não deixa analisar', (tester) async {
    final analisador = AnalisadorFalso(nome: null);
    await tester.pumpWidget(MaterialApp(
      home: VisaoPage(
        analisador: analisador,
        escolher: (_) async => ImagemParaAnalise(bytes: _png, mime: 'image/png', nome: 'caneca.png'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nenhum provedor com visão'), findsOneWidget);
    await escolherGaleria(tester);
    await autorizar(tester);
    final botao = find.byKey(const ValueKey('analisar-imagem'));
    await revelar(tester, botao);
    expect(tester.widget<FilledButton>(botao).onPressed, isNull);
  });

  testWidgets('falha do provedor aparece na tela sem sumir com a imagem', (tester) async {
    final analisador = AnalisadorFalso()..erro = StateError('O provedor recusou a análise.');
    await tester.pumpWidget(MaterialApp(
      home: VisaoPage(
        analisador: analisador,
        escolher: (_) async => ImagemParaAnalise(bytes: _png, mime: 'image/png', nome: 'caneca.png'),
      ),
    ));
    await tester.pumpAndSettle();

    await escolherGaleria(tester);
    await autorizar(tester);
    await analisar(tester);

    expect(find.textContaining('O provedor recusou a análise.'), findsOneWidget);
    expect(find.textContaining('caneca.png'), findsOneWidget);
  });

  testWidgets('formato não suportado é recusado antes de qualquer envio', (tester) async {
    final analisador = AnalisadorFalso();
    await tester.pumpWidget(MaterialApp(
      home: VisaoPage(
        analisador: analisador,
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
    expect(analisador.recebida, isNull);
    expect(find.textContaining('foto.heic'), findsNothing);
  });
}
