import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/fundo.dart';
import 'package:jarvis_nova/services/fundo_service.dart';
import 'package:jarvis_nova/services/segundo_plano_page.dart';
import 'package:material_ui/material_ui.dart';

class FundoFalso implements FundoGateway {
  FundoFalso({EstadoFundo? inicial})
      : estadoAtual = inicial ??
            const EstadoFundo(
              modoSemTela: false,
              podeAbrirApps: false,
              servicoAtivo: true,
              ouvindo: false,
              ultimaAcao: '',
              ultimoResultado: '',
              ultimoOk: false,
              ponteDisponivel: true,
            );

  EstadoFundo estadoAtual;
  int autorizacoes = 0;
  int limpezas = 0;
  String? ultimoTexto;
  ResultadoFundo proximo = const ResultadoFundo(
      ok: true, mensagem: 'WhatsApp aberto.', acao: 'abrir app whatsapp');

  @override
  Future<EstadoFundo> estado() async => estadoAtual;

  @override
  Future<EstadoFundo> definirModoSemTela(bool ativo) async {
    estadoAtual = estadoAtual.copiarCom(modoSemTela: ativo);
    return estadoAtual;
  }

  @override
  Future<bool> abrirAjusteSobreposicao() async {
    autorizacoes++;
    return true;
  }

  @override
  Future<EstadoFundo> limparHistorico() async {
    limpezas++;
    estadoAtual = EstadoFundo(
      modoSemTela: estadoAtual.modoSemTela,
      podeAbrirApps: estadoAtual.podeAbrirApps,
      servicoAtivo: estadoAtual.servicoAtivo,
      ouvindo: estadoAtual.ouvindo,
      ultimaAcao: '',
      ultimoResultado: '',
      ultimoOk: false,
      ponteDisponivel: true,
      ultimoEm: null,
    );
    return estadoAtual;
  }

  @override
  Future<ResultadoFundo> executarTexto(String texto) async {
    ultimoTexto = texto;
    return proximo;
  }
}

void main() {
  Future<void> abrir(WidgetTester tester, FundoFalso gateway) async {
    await tester.pumpWidget(MaterialApp(home: SegundoPlanoPage(gateway: gateway)));
    await tester.pumpAndSettle();
  }

  /// A tela é uma lista longa: o widget só existe depois de aparecer na janela.
  Future<void> revelar(WidgetTester tester, Finder alvo) async {
    if (alvo.evaluate().isEmpty) {
      await tester.dragUntilVisible(
          alvo, find.byType(ListView), const Offset(0, -240));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('mostra o que falta antes de prometer segundo plano', (tester) async {
    final gateway = FundoFalso();
    await abrir(tester, gateway);

    expect(find.textContaining('FALTA PARA FUNCIONAR'), findsOneWidget);
    expect(find.textContaining('Exibir sobre outros apps'), findsWidgets);

    final atualizar = find.textContaining('Atualizar estado');
    await revelar(tester, atualizar);
    expect(atualizar, findsOneWidget);

    final limites = find.text('LIMITES REAIS');
    await revelar(tester, limites);
    expect(limites, findsOneWidget);
    expect(find.textContaining('reiniciar'), findsOneWidget);
  });

  testWidgets('o switch grava a decisão no aparelho', (tester) async {
    final gateway = FundoFalso();
    await abrir(tester, gateway);

    final chave = find.byKey(const ValueKey('fundo-modo-sem-tela'));
    await revelar(tester, chave);
    await tester.tap(chave);
    await tester.pumpAndSettle();

    expect(gateway.estadoAtual.modoSemTela, isTrue);
    final aviso = find.textContaining('Modo sem tela ligado');
    await revelar(tester, aviso);
    expect(aviso, findsOneWidget);
  });

  testWidgets('autorização de sobreposição abre o ajuste do Android',
      (tester) async {
    final gateway = FundoFalso();
    await abrir(tester, gateway);

    final botao = find.byKey(const ValueKey('fundo-autorizar-sobreposicao'));
    await revelar(tester, botao);
    await tester.tap(botao);
    await tester.pumpAndSettle();

    expect(gateway.autorizacoes, 1);
    final aviso = find.textContaining('Ao voltar, toque em Atualizar');
    await revelar(tester, aviso);
    expect(aviso, findsOneWidget);
  });

  testWidgets('testar comando mostra o resultado real e registra a ação',
      (tester) async {
    final gateway = FundoFalso();
    await abrir(tester, gateway);

    final campo = find.byKey(const ValueKey('fundo-comando'));
    await revelar(tester, campo);
    await tester.enterText(campo, 'abrir whatsapp');

    final executar = find.byKey(const ValueKey('fundo-executar'));
    await revelar(tester, executar);
    await tester.tap(executar);
    await tester.pumpAndSettle();

    expect(gateway.ultimoTexto, 'abrir whatsapp');
    expect(find.text('WhatsApp aberto.'), findsOneWidget);
  });

  testWidgets('sem ponte nativa a tela avisa em vez de fingir', (tester) async {
    final gateway = FundoFalso(inicial: EstadoFundo.vazio);
    await abrir(tester, gateway);

    expect(find.textContaining('app Android'), findsOneWidget);
    expect(find.text('SÓ NO ANDROID'), findsOneWidget);

    final chave = find.byKey(const ValueKey('fundo-modo-sem-tela'));
    await revelar(tester, chave);
    expect(tester.widget<Switch>(chave).onChanged, isNull);

    final executar = find.byKey(const ValueKey('fundo-executar'));
    await revelar(tester, executar);
    expect(tester.widget<FilledButton>(executar).onPressed, isNull);
  });
}
