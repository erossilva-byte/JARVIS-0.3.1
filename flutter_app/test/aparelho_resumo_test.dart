import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/aparelho.dart';
import 'package:jarvis_nova/core/resumo_tatico.dart';
import 'package:jarvis_nova/services/aparelho_page.dart';
import 'package:jarvis_nova/services/aparelho_service.dart';
import 'package:jarvis_nova/services/resumo_ia_service.dart';
import 'package:material_ui/material_ui.dart';

class FakeAparelho extends AparelhoService {
  FakeAparelho(this.lista);

  final List<NotificacaoAparelho> lista;
  String? textoEnviado;

  @override
  Future<EstadoAparelho> status() async => const EstadoAparelho();

  @override
  Future<bool> temAcessoNotificacoes() async => true;

  @override
  Future<List<AppMensagem>> appsDisponiveis() async => const [];

  @override
  Future<List<NotificacaoAparelho>> notificacoes({int limite = 30}) async =>
      lista;

  @override
  Future<ResultadoAparelho> responderNotificacao({
    required String texto,
    String chave = '',
    String? pacote,
  }) async {
    textoEnviado = texto;
    return const ResultadoAparelho(ok: true, mensagem: 'Resposta enviada.');
  }
}

class FakeResumo extends ResumoIaService {
  FakeResumo(this.resultado);

  final ResultadoResumo resultado;
  int pedidos = 0;

  @override
  Future<ResultadoResumo> resumir(List<NotificacaoAparelho> lista,
      {DateTime? agora}) async {
    pedidos++;
    return resultado;
  }
}

NotificacaoAparelho _msg(String app, String titulo, String texto,
        {bool responde = true}) =>
    NotificacaoAparelho.deMapa({
      'app': app,
      'pacote': 'pacote.${app.toLowerCase()}',
      'chave': 'chave-$app',
      'titulo': titulo,
      'texto': texto,
      'respondivel': responde,
    })!;

void main() {
  testWidgets('resumo tático mostra urgente, ruído e sugestão com “Usar”',
      (tester) async {
    final fake = FakeAparelho([
      _msg('WhatsApp', 'Mãe', 'Ligue agora, é urgente'),
      _msg('WhatsApp', 'Grupo do prédio', '3 mensagens novas'),
    ]);
    final resumo = FakeResumo(const ResultadoResumo(
      provedor: 'Groq',
      resumo: ResumoTatico(
        resumo: 'Duas mensagens: uma urgente e um grupo.',
        urgentes: ['WhatsApp: Ligue agora, é urgente'],
        ruido: ['WhatsApp: Grupo do prédio'],
        respostas: [
          SugestaoResposta(app: 'WhatsApp', texto: 'Já te ligo.'),
        ],
      ),
    ));
    await tester.pumpWidget(MaterialApp(
        home: AparelhoPage(servico: fake, resumoIa: resumo, ativo: true)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('resumo-texto')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('aparelho-notificacoes-resumo')));
    await tester.pumpAndSettle();

    expect(resumo.pedidos, 1);
    expect(find.text('Duas mensagens: uma urgente e um grupo.'), findsOneWidget);
    expect(find.text('URGENTE'), findsOneWidget);
    expect(find.text('Ruído de grupo filtrado (1)'), findsOneWidget);
    expect(find.text('RESPOSTAS SUGERIDAS'), findsOneWidget);
    expect(find.textContaining('Resumo via Groq'), findsOneWidget);

    final usar = find.byKey(const ValueKey('resumo-sugestao-0'));
    await tester.ensureVisible(usar);
    await tester.pumpAndSettle();
    await tester.tap(usar);
    await tester.pumpAndSettle();
    expect(find.text('Já te ligo.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('resposta-enviar')));
    await tester.pumpAndSettle();
    expect(fake.textoEnviado, 'Já te ligo.');
  });

  testWidgets('sem provedor, a triagem local aparece com o motivo honesto',
      (tester) async {
    final fake =
        FakeAparelho([_msg('WhatsApp', 'Mãe', 'Pague o boleto hoje')]);
    final resumo = FakeResumo(const ResultadoResumo(
      erro: 'Nenhum provedor de IA configurado.',
      resumo: ResumoTatico(
        resumo: '1 notificação(ões) com sinal de urgência.',
        urgentes: ['WhatsApp: Mãe'],
        daIa: false,
      ),
    ));
    await tester.pumpWidget(MaterialApp(
        home: AparelhoPage(servico: fake, resumoIa: resumo, ativo: true)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('aparelho-notificacoes-resumo')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('resumo-erro')), findsOneWidget);
    expect(find.text('Nenhum provedor de IA configurado.'), findsOneWidget);
    expect(find.textContaining('Sem IA: triagem local'), findsOneWidget);
  });
}
