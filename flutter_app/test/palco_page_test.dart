import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/palco.dart';
import 'package:jarvis_nova/services/palco_page.dart';
import 'package:jarvis_nova/services/palco_service.dart';

const _itens = [
  ItemPalco(
    tipo: TipoPalco.imagem,
    titulo: 'Motor elétrico',
    url: 'https://commons.wikimedia.org/wiki/File:Motor.jpg',
    resumo: 'Crédito: Fulano',
    fonte: 'Wikimedia Commons',
  ),
  ItemPalco(
    tipo: TipoPalco.imagem,
    titulo: 'Painel de comando',
    url: 'https://commons.wikimedia.org/wiki/File:Painel.jpg',
    fonte: 'Wikimedia Commons',
  ),
];

void main() {
  testWidgets('pesquisa e mostra o resultado no palco', (tester) async {
    final pedidos = <PedidoPalco>[];
    await tester.pumpWidget(MaterialApp(
      home: PalcoPage(buscar: (pedido) async {
        pedidos.add(pedido);
        return _itens;
      }),
    ));

    await tester.enterText(
        find.byKey(const ValueKey('palco-campo')), 'mostra fotos de motor');
    await tester.tap(find.byKey(const ValueKey('palco-pesquisar')));
    await tester.pump();
    await tester.pump();

    expect(pedidos.single.tipo, TipoPalco.imagem);
    expect(pedidos.single.consulta, 'motor');
    expect(find.text('Motor elétrico'), findsWidgets);
    expect(find.byKey(const ValueKey('palco-resultado')), findsOneWidget);

    // A navegação entre resultados fica abaixo do palco, fora da primeira tela.
    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pump();
    expect(find.text('1 de 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('palco-proximo')));
    await tester.pump();
    expect(find.text('2 de 2'), findsOneWidget);
  });

  testWidgets('falha da fonte aparece como motivo, não como resultado',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PalcoPage(
        buscar: (_) async =>
            throw const PalcoException('O Google Notícias recusou a consulta.'),
      ),
    ));

    await tester.enterText(
        find.byKey(const ValueKey('palco-campo')), 'notícias de tecnologia');
    await tester.tap(find.byKey(const ValueKey('palco-tipo-noticia')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('palco-pesquisar')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('palco-erro')), findsOneWidget);
    expect(find.text('O Google Notícias recusou a consulta.'), findsOneWidget);
    expect(find.byKey(const ValueKey('palco-resultado')), findsNothing);
  });

  testWidgets('pedido inicial abre a tela já pesquisando', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PalcoPage(
        pedidoInicial:
            const PedidoPalco(consulta: 'motor', tipo: TipoPalco.imagem),
        buscar: (_) async => _itens,
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Motor elétrico'), findsWidgets);
    expect(find.byKey(const ValueKey('palco-resultado')), findsOneWidget);
  });

  testWidgets('sem assunto, a tela pede o que pesquisar', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PalcoPage(buscar: (_) async => _itens),
    ));
    await tester.tap(find.byKey(const ValueKey('palco-pesquisar')));
    await tester.pump();

    expect(find.byKey(const ValueKey('palco-erro')), findsOneWidget);
    expect(find.textContaining('Escreva o que quer ver'), findsOneWidget);
  });
}
