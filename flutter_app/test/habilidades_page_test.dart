import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/habilidades.dart';
import 'package:jarvis_nova/services/habilidades_page.dart';
import 'package:jarvis_nova/services/habilidades_service.dart';
import 'package:material_ui/material_ui.dart';

class FakeHabilidades extends HabilidadesService {
  FakeHabilidades(this.resultado, {this.respostaExemplo = ''});

  final ResultadoHabilidades resultado;
  final String respostaExemplo;
  int leituras = 0;
  int exemplos = 0;

  @override
  Future<ResultadoHabilidades> carregar() async {
    leituras++;
    return resultado;
  }

  @override
  Future<({bool ok, String mensagem})> criarExemplo() async {
    exemplos++;
    return (ok: respostaExemplo.isEmpty, mensagem: respostaExemplo);
  }
}

void main() {
  testWidgets('lista as habilidades com nome, gatilho e origem', (tester) async {
    final fake = FakeHabilidades(const ResultadoHabilidades(
      pastaNome: 'Obsidian',
      lidas: 4,
      habilidades: [
        Habilidade(
          nome: 'Revisar texto',
          descricao: 'Corrige sem mudar o sentido.',
          gatilhos: ['revisar texto'],
          instrucoes: '1. Leia tudo.',
          origem: 'Skills/revisar-texto.md',
        ),
      ],
    ));
    await tester.pumpWidget(
        MaterialApp(home: HabilidadesPage(servico: fake)));
    await tester.pumpAndSettle();

    expect(fake.leituras, 1);
    expect(find.textContaining('pasta Obsidian'), findsOneWidget);
    expect(find.byKey(const ValueKey('habilidade-0')), findsOneWidget);
    expect(find.text('Revisar texto'), findsOneWidget);
    expect(find.textContaining('Ativa com: revisar texto'), findsOneWidget);
    expect(find.text('Skills/revisar-texto.md'), findsOneWidget);
    expect(find.byKey(const ValueKey('habilidades-vazio')), findsNothing);
  });

  testWidgets('sem habilidades, explica onde criar e mostra o formato',
      (tester) async {
    final fake = FakeHabilidades(const ResultadoHabilidades(
      aviso: 'A pasta Obsidian foi lida, mas nenhum arquivo .md está em Skills/.',
    ));
    await tester.pumpWidget(
        MaterialApp(home: HabilidadesPage(servico: fake)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('habilidades-aviso')), findsOneWidget);
    expect(find.byKey(const ValueKey('habilidades-vazio')), findsOneWidget);
    expect(find.byKey(const ValueKey('habilidades-exemplo-formato')),
        findsOneWidget);
    expect(find.textContaining('Skills/'), findsWidgets);
  });

  testWidgets('“Criar exemplo” relata o resultado real', (tester) async {
    final fake = FakeHabilidades(
      const ResultadoHabilidades(pastaNome: 'Obsidian'),
      respostaExemplo: 'A pasta está conectada somente para leitura.',
    );
    await tester.pumpWidget(
        MaterialApp(home: HabilidadesPage(servico: fake)));
    await tester.pumpAndSettle();

    final botao = find.byKey(const ValueKey('habilidades-criar-exemplo'));
    await tester.ensureVisible(botao);
    await tester.pumpAndSettle();
    await tester.tap(botao);
    await tester.pumpAndSettle();

    expect(fake.exemplos, 1);
    expect(find.byKey(const ValueKey('habilidades-aviso-exemplo')),
        findsOneWidget);
    expect(find.textContaining('somente para leitura'), findsOneWidget);
  });
}
