import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/pareamento.dart';
import 'package:jarvis_nova/services/pareamento_page.dart';
import 'package:jarvis_nova/services/pareamento_service.dart';
import 'package:material_ui/material_ui.dart';

class ServicoFalso extends PareamentoService {
  ServicoFalso({this.codigo = '123456'})
      : super(porta: 0, nome: 'Celular de teste');

  final String codigo;

  @override
  int get portaAtual => 47600;

  @override
  Future<OfertaPareamento> abrirOferta() async {
    final nova = OfertaPareamento(
      codigo: codigo,
      desafio: 'desafio',
      criadoEm: DateTime.now(),
    );
    oferta = nova;
    aoMudar?.call();
    return nova;
  }

  @override
  Future<void> fechar() async {
    oferta = null;
  }
}

Future<List<String>> umIp() async => ['192.168.0.20'];

void main() {
  testWidgets('abre o pareamento e mostra o código e o endereço',
      (tester) async {
    final servico = ServicoFalso();
    await tester.pumpWidget(MaterialApp(
        home: PareamentoPage(servico: servico, enderecos: umIp)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nenhum PC pareado'), findsOneWidget);
    expect(find.byKey(const ValueKey('pareamento-codigo')), findsNothing);
    expect(find.text('192.168.0.20:47600'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pareamento-abrir')));
    await tester.pump();

    expect(find.text('123 456'), findsOneWidget);
    expect(find.textContaining('Esperando o PC'), findsOneWidget);
    expect(find.textContaining('tentativa(s)'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sem endereço de rede a tela explica em vez de inventar',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: PareamentoPage(
            servico: ServicoFalso(), enderecos: () async => const [])));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nenhum endereço IPv4'), findsOneWidget);
  });

  testWidgets('pareado mostra o PC e esquecer volta ao estado vazio',
      (tester) async {
    final servico = ServicoFalso()
      ..registro = RegistroPareamento(
        dispositivo: 'PC da oficina',
        ip: '192.168.0.10',
        porta: 47600,
        token: 'a' * 64,
        criadoEm: DateTime(2026, 11, 25),
      );
    await tester.pumpWidget(MaterialApp(
        home: PareamentoPage(servico: servico, enderecos: umIp)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Pareado com PC da oficina'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pareamento-esquecer')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nenhum PC pareado'), findsOneWidget);
    expect(servico.pareado, isFalse);
  });

  testWidgets('o código aparece formatado com espaço e 6 dígitos',
      (tester) async {
    final servico = ServicoFalso(codigo: '004521');
    await tester.pumpWidget(MaterialApp(
        home: PareamentoPage(servico: servico, enderecos: umIp)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pareamento-abrir')));
    await tester.pump();

    expect(find.text('004 521'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
