import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/palco.dart';
import 'package:jarvis_nova/services/palco_regras_page.dart';

/// Guarda o que o editor devolveu; o botão só preenche depois do "Salvar".
class ResultadoEditor {
  RegrasPalco? valor;
}

Future<ResultadoEditor> abrirEditor(WidgetTester tester,
    {RegrasPalco regras = RegrasPalco.padrao}) async {
  final resultado = ResultadoEditor();
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Center(
        child: ElevatedButton(
          onPressed: () async {
            resultado.valor = await Navigator.of(context).push<RegrasPalco>(
              MaterialPageRoute(
                  builder: (_) => PalcoRegrasPage(regras: regras)),
            );
          },
          child: const Text('abrir'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return resultado;
}

void main() {
  testWidgets('mostra a prévia desenhada, sem pedir imagem pela rede',
      (tester) async {
    await abrirEditor(tester);

    expect(find.byKey(const ValueKey('previa-moldura')), findsOneWidget);
    expect(find.byKey(const ValueKey('previa-legenda')), findsOneWidget);
    expect(find.textContaining('prévia desenhada'), findsOneWidget);
    // A prévia é desenho local: nenhuma imagem de rede é montada.
    expect(
        find.byWidgetPredicate(
            (w) => w is Image && w.image is NetworkImage),
        findsNothing);
  });

  testWidgets('troca o tipo de mídia e o recorte, e salva o que mudou',
      (tester) async {
    final resultado = await abrirEditor(tester);

    await tester.tap(find.byKey(const ValueKey('regra-tipo-capaVideo')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Vídeo ·'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('regra-inteira')));
    await tester.pumpAndSettle();
    expect(find.textContaining('inteira'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('regra-salvar')));
    await tester.pumpAndSettle();

    final regras = resultado.valor;
    expect(regras, isNotNull);
    expect(regras!.capaVideo.cabeInteira, isTrue);
    // As outras regras continuam como estavam.
    expect(regras.capaLarga.cabeInteira, isFalse);
  });

  testWidgets('voltar ao padrão devolve os valores originais', (tester) async {
    final resultado = await abrirEditor(
      tester,
      regras: const RegrasPalco(
        capaVideo: RegraMoldura(altura: 0.6, cabeInteira: true),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('regra-tipo-capaVideo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('regra-padrao')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('regra-salvar')));
    await tester.pumpAndSettle();

    final regras = resultado.valor;
    expect(regras, isNotNull);
    expect(regras!.capaVideo.altura, RegrasPalco.padrao.capaVideo.altura);
    expect(regras.capaVideo.cabeInteira, isFalse);
  });
}
