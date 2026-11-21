import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/historico_voz.dart';
import 'package:jarvis_nova/services/historico_voz_page.dart';
import 'package:jarvis_nova/services/historico_voz_service.dart';
import 'package:material_ui/material_ui.dart';

class HistoricoFalso implements HistoricoVozGateway {
  HistoricoFalso({List<RegistroExecucao>? inicial})
      : registros = inicial ?? const [];

  List<RegistroExecucao> registros;
  int cargas = 0;
  int limpezas = 0;
  bool limparOk = true;

  @override
  Future<List<RegistroExecucao>> carregar() async {
    cargas++;
    return registros;
  }

  @override
  Future<bool> limpar() async {
    limpezas++;
    if (limparOk) registros = const [];
    return limparOk;
  }

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

RegistroExecucao registro({
  required int hora,
  int minuto = 0,
  String pedido = 'abrir WhatsApp',
  String acao = 'abrir o app whatsapp',
  bool ok = true,
  String mensagem = 'Abertura de WhatsApp enviada ao Android.',
  OrigemExecucao origem = OrigemExecucao.voz,
  DateTime? em,
}) {
  final agora = DateTime.now();
  return RegistroExecucao(
    em: em ?? DateTime(agora.year, agora.month, agora.day, hora, minuto),
    origem: origem,
    pedido: pedido,
    acao: acao,
    ok: ok,
    mensagem: mensagem,
  );
}

void main() {
  Future<void> abrir(WidgetTester tester, HistoricoFalso gateway) async {
    await tester.pumpWidget(MaterialApp(home: HistoricoVozPage(gateway: gateway)));
    await tester.pumpAndSettle();
  }

  testWidgets('mostra horário, ação e resultado do que foi executado',
      (tester) async {
    final gateway = HistoricoFalso(inicial: [
      registro(hora: 8, minuto: 13),
      registro(
        hora: 7,
        minuto: 5,
        pedido: 'abrir YouTube',
        acao: 'abrir app youtube',
        ok: false,
        mensagem: 'Nenhum app instalado corresponde a "YouTube".',
        origem: OrigemExecucao.segundoPlano,
      ),
    ]);
    await abrir(tester, gateway);

    expect(gateway.cargas, 1);
    expect(find.byKey(const ValueKey('historico-voz-item-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('historico-voz-item-1')), findsOneWidget);

    expect(find.text('08:13'), findsOneWidget);
    expect(find.text('07:05'), findsOneWidget);
    expect(find.text('abrir o app whatsapp'), findsOneWidget);
    expect(find.text('Executado'), findsOneWidget);
    expect(find.text('Não executado'), findsOneWidget);
    expect(find.textContaining('“abrir YouTube”'), findsOneWidget);
    expect(find.textContaining('Nenhum app instalado'), findsOneWidget);
    expect(find.textContaining('Por voz'), findsWidgets);
    expect(find.textContaining('segundo plano'), findsWidgets);
    expect(find.textContaining('2 comandos'), findsOneWidget);
  });

  testWidgets('sem registros explica como o histórico é preenchido',
      (tester) async {
    await abrir(tester, HistoricoFalso());

    expect(find.byKey(const ValueKey('historico-voz-vazio')), findsOneWidget);
    expect(find.textContaining('Nenhum comando executado ainda'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('limpar-historico-voz')), findsNothing);
  });

  testWidgets('limpar pede confirmação e só então apaga', (tester) async {
    final gateway = HistoricoFalso(inicial: [registro(hora: 9)]);
    await abrir(tester, gateway);

    await tester.tap(find.byKey(const ValueKey('limpar-historico-voz')));
    await tester.pumpAndSettle();
    expect(find.text('Limpar o histórico?'), findsOneWidget);
    expect(gateway.limpezas, 0, reason: 'apagou antes de confirmar');

    await tester.tap(find.byKey(const ValueKey('confirmar-limpar-historico-voz')));
    await tester.pumpAndSettle();

    expect(gateway.limpezas, 1);
    expect(find.byKey(const ValueKey('historico-voz-vazio')), findsOneWidget);
  });

  testWidgets('falha ao limpar avisa em vez de fingir que apagou',
      (tester) async {
    final gateway = HistoricoFalso(inicial: [registro(hora: 9)])
      ..limparOk = false;
    await abrir(tester, gateway);

    await tester.tap(find.byKey(const ValueKey('limpar-historico-voz')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmar-limpar-historico-voz')));
    await tester.pumpAndSettle();

    expect(find.textContaining('não confirmou a limpeza'), findsOneWidget);
    expect(find.byKey(const ValueKey('historico-voz-item-0')), findsOneWidget);
  });

  testWidgets('atualizar relê o histórico do aparelho', (tester) async {
    final gateway = HistoricoFalso(inicial: [registro(hora: 9)]);
    await abrir(tester, gateway);

    gateway.registros = [
      registro(hora: 9),
      registro(hora: 10, pedido: 'lanterna', acao: 'ligar a lanterna'),
    ];
    await tester.tap(find.byKey(const ValueKey('atualizar-historico-voz')));
    await tester.pumpAndSettle();

    expect(gateway.cargas, 2);
    expect(find.byKey(const ValueKey('historico-voz-item-1')), findsOneWidget);
    expect(find.text('ligar a lanterna'), findsOneWidget);
  });
}
