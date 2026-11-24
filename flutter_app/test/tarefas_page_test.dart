import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/aparelho.dart';
import 'package:jarvis_nova/core/tarefas.dart';
import 'package:jarvis_nova/core/dispositivo.dart';
import 'package:jarvis_nova/services/agenda_service.dart';
import 'package:jarvis_nova/services/aparelho_service.dart';
import 'package:jarvis_nova/services/tarefas_page.dart';
import 'package:jarvis_nova/services/tarefas_store.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AgendaFalsa implements AgendaService {
  AgendaFalsa({this.ok = true});

  bool ok;
  final List<Map<String, Object?>> agendados = [];
  final List<int> cancelados = [];

  @override
  Future<bool> agendar({
    required int id,
    required String titulo,
    required String texto,
    required DateTime quando,
    bool repetirDiario = false,
    Recorrencia repeticao = Recorrencia.umaVez,
  }) async {
    if (!ok) return false;
    agendados.add({
      'id': id,
      'titulo': titulo,
      'texto': texto,
      'quando': quando,
      'repetir': repetirDiario,
    });
    return true;
  }

  @override
  Future<bool> cancelar(int id) async {
    cancelados.add(id);
    return true;
  }
}

class AparelhoFalso extends AparelhoService {
  final List<PedidoMensagem> mensagens = [];
  bool mensagemOk = true;

  @override
  Future<InfoDispositivo> infoDispositivo() async =>
      const InfoDispositivo(bateria: 18);

  @override
  Future<ResultadoAparelho> enviarMensagem(PedidoMensagem pedido) async {
    mensagens.add(pedido);
    return ResultadoAparelho(
      ok: mensagemOk,
      mensagem:
          mensagemOk ? 'Conversa aberta; toque em enviar.' : 'App não instalado.',
    );
  }
}

Future<void> abrir(
  WidgetTester tester, {
  required TarefasStore store,
  AgendaService? agenda,
  AparelhoService? aparelho,
}) async {
  tester.view.physicalSize = const Size(520, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home: TarefasPage(
      store: store,
      agenda: agenda ?? AgendaFalsa(),
      aparelho: aparelho ?? AparelhoFalso(),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<TarefasStore> novoStore() async {
  SharedPreferences.setMockInitialValues({});
  return TarefasStore(await SharedPreferences.getInstance(),
      agora: () => DateTime(2026, 11, 19, 10));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cria tarefa com prazo, agenda lembrete e permite concluir',
      (tester) async {
    final store = await novoStore();
    final agenda = AgendaFalsa();
    await abrir(tester, store: store, agenda: agenda);

    await tester.tap(find.byKey(const ValueKey('tarefa-nova')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('tarefa-titulo')), 'Pagar a conta');
    await tester.enterText(find.byKey(const ValueKey('tarefa-prazo')),
        '31/12/2027 09:00');
    await tester.tap(find.byKey(const ValueKey('tarefa-salvar')));
    await tester.pumpAndSettle();

    expect(find.text('Pagar a conta'), findsOneWidget);
    expect(agenda.agendados, hasLength(1));
    expect(agenda.agendados.single['texto'], 'Pagar a conta');
    expect(agenda.agendados.single['quando'], DateTime(2027, 12, 31, 9));

    final salva = store.tarefas().single;
    await tester.tap(find.byKey(ValueKey('tarefa-feita-${salva.id}')));
    await tester.pumpAndSettle();
    expect(store.tarefas().single.feita, isTrue);
    expect(agenda.cancelados, contains(salva.lembreteId));

    await tester.tap(find.byKey(ValueKey('tarefa-apagar-${salva.id}')));
    await tester.pumpAndSettle();
    expect(store.tarefas(), isEmpty);
  });

  testWidgets('mensagem pede confirmação antes de abrir a conversa',
      (tester) async {
    final store = await novoStore();
    final aparelho = AparelhoFalso();
    await abrir(tester, store: store, aparelho: aparelho);

    await tester.tap(find.text('Automações'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('automacao-nova')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('automacao-nome')), 'Avisar chegada');
    await tester.tap(find.byKey(const ValueKey('automacao-acao-avisar')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.text('Preparar uma mensagem (pede confirmação)').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('automacao-destino')), 'Ana');
    await tester.enterText(
        find.byKey(const ValueKey('automacao-texto')), 'Chego às 9');
    await tester.tap(find.byKey(const ValueKey('automacao-salvar')));
    await tester.pumpAndSettle();

    expect(find.text('Avisar chegada'), findsOneWidget);
    expect(aparelho.mensagens, isEmpty);

    await tester.tap(find.text('Executar agora'));
    await tester.pumpAndSettle();

    expect(find.textContaining('AGUARDANDO CONFIRMAÇÃO'), findsOneWidget);
    expect(find.textContaining('Mensagem no WhatsApp para Ana'),
        findsOneWidget);
    expect(aparelho.mensagens, isEmpty,
        reason: 'nada pode sair antes do toque em Confirmar');

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(aparelho.mensagens, hasLength(1));
    expect(aparelho.mensagens.single.destino, 'Ana');
    expect(aparelho.mensagens.single.texto, 'Chego às 9');
    expect(store.fila().single.estado, EstadoFila.feito);
  });

  testWidgets('sem alarme confirmado, avisa que a tarefa foi salva apenas',
      (tester) async {
    final store = await novoStore();
    final agenda = AgendaFalsa(ok: false);
    await abrir(tester, store: store, agenda: agenda);

    await tester.tap(find.byKey(const ValueKey('tarefa-nova')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('tarefa-titulo')), 'Consulta');
    await tester.enterText(
        find.byKey(const ValueKey('tarefa-prazo')), '31/12/2027 09:00');
    await tester.tap(find.byKey(const ValueKey('tarefa-salvar')));
    await tester.pumpAndSettle();

    expect(store.tarefas().single.titulo, 'Consulta');
    expect(find.textContaining('o Android não confirmou o lembrete'),
        findsOneWidget);
  });
}
