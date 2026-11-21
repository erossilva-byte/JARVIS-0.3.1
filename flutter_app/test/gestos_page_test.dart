import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/gestos.dart';
import 'package:jarvis_nova/services/gestos_page.dart';
import 'package:jarvis_nova/services/sensores_service.dart';
import 'package:material_ui/material_ui.dart';

class FakeSensores extends SensoresService {
  FakeSensores(this.estadoAtual);

  EstadoGestos estadoAtual;
  bool calou = false;

  @override
  Future<EstadoGestos> estado() async => estadoAtual;

  @override
  Future<EstadoGestos> definirCalarAoVirar(bool ativo) async {
    estadoAtual = estadoAtual.copiarCom(calarAoVirar: ativo);
    return estadoAtual;
  }

  @override
  Future<EstadoGestos> definirModoNoturno(bool ativo) async {
    estadoAtual = estadoAtual.copiarCom(modoNoturno: ativo);
    return estadoAtual;
  }

  @override
  Future<EstadoGestos> definirBrilho(int brilho) async {
    estadoAtual = estadoAtual.copiarCom(brilho: brilho);
    return estadoAtual;
  }

  @override
  Future<bool> calar() async {
    calou = true;
    return true;
  }
}

class SensoresSemCanal extends SensoresService {
  const SensoresSemCanal();

  @override
  Future<EstadoGestos> estado() async =>
      throw const SensoresIndisponivel('Gestos só existem no app Android.');
}

const _comSensor = EstadoGestos(
  temAcelerometro: true,
  calarAoVirar: false,
  modoNoturno: false,
  brilho: 35,
);

void main() {
  testWidgets('mostra o estado e liga o gesto de calar', (tester) async {
    final fake = FakeSensores(_comSensor);
    await tester.pumpWidget(MaterialApp(home: GestosPage(servico: fake)));
    await tester.pumpAndSettle();

    expect(find.textContaining('virar para calar desligado'), findsOneWidget);
    expect(find.textContaining('modo noturno desligado'), findsOneWidget);

    final chave = find.byKey(const ValueKey('gestos-calar'));
    await tester.ensureVisible(chave);
    await tester.pumpAndSettle();
    await tester.tap(chave);
    await tester.pumpAndSettle();

    expect(fake.estadoAtual.calarAoVirar, isTrue);
    final interruptor =
        tester.widget<SwitchListTile>(find.byKey(const ValueKey('gestos-calar')));
    expect(interruptor.value, isTrue);
  });

  testWidgets('sem acelerômetro o gesto fica travado e explicado',
      (tester) async {
    final fake = FakeSensores(EstadoGestos.vazio);
    await tester.pumpWidget(MaterialApp(home: GestosPage(servico: fake)));
    await tester.pumpAndSettle();

    expect(find.textContaining('não informou acelerômetro'), findsOneWidget);
    expect(find.text('Sem acelerômetro neste aparelho.'), findsOneWidget);

    final chave = find.byKey(const ValueKey('gestos-calar'));
    await tester.ensureVisible(chave);
    await tester.pumpAndSettle();
    await tester.tap(chave);
    await tester.pumpAndSettle();
    expect(fake.estadoAtual.calarAoVirar, isFalse);
  });

  testWidgets('modo noturno aplica o brilho escolhido', (tester) async {
    final fake = FakeSensores(_comSensor);
    await tester.pumpWidget(MaterialApp(home: GestosPage(servico: fake)));
    await tester.pumpAndSettle();

    final noturno = find.byKey(const ValueKey('gestos-noturno'));
    await tester.ensureVisible(noturno);
    await tester.pumpAndSettle();
    await tester.tap(noturno);
    await tester.pumpAndSettle();
    expect(fake.estadoAtual.modoNoturno, isTrue);

    final slider = find.byKey(const ValueKey('gestos-brilho'));
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    await tester.drag(slider, const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(fake.estadoAtual.brilho, lessThan(35));
    expect(fake.estadoAtual.brilho, greaterThanOrEqualTo(brilhoMinimoGestos));
    final noturnoAtivo = tester
        .widget<SwitchListTile>(find.byKey(const ValueKey('gestos-noturno')));
    expect(noturnoAtivo.value, isTrue);
  });

  testWidgets('cala agora avisa quando o canal confirma', (tester) async {
    final fake = FakeSensores(_comSensor);
    await tester.pumpWidget(MaterialApp(home: GestosPage(servico: fake)));
    await tester.pumpAndSettle();

    final botao = find.byKey(const ValueKey('gestos-calaram'));
    await tester.ensureVisible(botao);
    await tester.pumpAndSettle();
    await tester.tap(botao);
    await tester.pumpAndSettle();

    expect(fake.calou, isTrue);
    expect(find.byKey(const ValueKey('gestos-erro')), findsNothing);
  });

  testWidgets('sem canal, a tela explica em vez de fingir que ligou',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: GestosPage(servico: SensoresSemCanal())));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('gestos-erro')), findsOneWidget);
    expect(find.textContaining('só existem no app Android'), findsOneWidget);
  });
}
