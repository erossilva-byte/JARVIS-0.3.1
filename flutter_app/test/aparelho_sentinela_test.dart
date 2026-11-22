import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/aparelho.dart';
import 'package:jarvis_nova/services/aparelho_page.dart';
import 'package:jarvis_nova/services/aparelho_service.dart';
import 'package:material_ui/material_ui.dart';

class FakeAparelho extends AparelhoService {
  FakeAparelho(this.lista);

  final List<NotificacaoAparelho> lista;
  String? textoEnviado;
  String? chaveEnviada;

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
    chaveEnviada = chave;
    return const ResultadoAparelho(ok: true, mensagem: 'Resposta enviada.');
  }
}

NotificacaoAparelho _msg(String app, String chave, {bool responde = true}) =>
    NotificacaoAparelho.deMapa({
      'app': app,
      'pacote': 'pacote.$app',
      'chave': chave,
      'titulo': 'Contato',
      'texto': 'Mensagem de $app',
      'respondivel': responde,
    })!;

void main() {
  testWidgets('só a mensagem com campo de resposta oferece responder',
      (tester) async {
    final fake = FakeAparelho([
      _msg('WhatsApp', 'chave-whats'),
      _msg('YouTube', 'chave-youtube', responde: false),
    ]);
    await tester.pumpWidget(
        MaterialApp(home: AparelhoPage(servico: fake, ativo: true)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('notificacao-0-responder')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('notificacao-1-responder')), findsNothing);
  });

  testWidgets('responder envia o texto pela notificação certa',
      (tester) async {
    final fake = FakeAparelho([_msg('WhatsApp', 'chave-whats')]);
    await tester.pumpWidget(
        MaterialApp(home: AparelhoPage(servico: fake, ativo: true)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('notificacao-0-responder')));
    await tester.pumpAndSettle();
    expect(find.text('Responder em WhatsApp'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('resposta-texto')), 'Chego em 10 minutos');
    await tester.tap(find.byKey(const ValueKey('resposta-enviar')));
    await tester.pumpAndSettle();

    expect(fake.textoEnviado, 'Chego em 10 minutos');
    expect(fake.chaveEnviada, 'chave-whats');
  });

  testWidgets('cancelar a resposta não envia nada', (tester) async {
    final fake = FakeAparelho([_msg('Telegram', 'chave-telegram')]);
    await tester.pumpWidget(
        MaterialApp(home: AparelhoPage(servico: fake, ativo: true)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('notificacao-0-responder')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(fake.textoEnviado, isNull);
  });
}
