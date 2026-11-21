import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/services/circuito_page.dart';
import 'package:material_ui/material_ui.dart';

Future<void> abrir(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const MaterialApp(home: CircuitoPage()));
  await tester.pumpAndSettle();
}

Offset pontoDoTrecho(WidgetTester tester, int a, int b,
    {int colunas = 6, int linhas = 4}) {
  final retangulo =
      tester.getRect(find.byKey(const ValueKey('circuito-tabuleiro')));
  final geometria = GeometriaCircuito(retangulo.size, colunas, linhas);
  return retangulo.topLeft + geometria.meio(a, b);
}

void main() {
  testWidgets('abre com o exemplo calculado e declara o limite', (tester) async {
    await abrir(tester);

    expect(find.byKey(const ValueKey('circuito-tabuleiro')), findsOneWidget);
    expect(find.textContaining('não é o CADeSIMU'), findsOneWidget);
    expect(find.textContaining('12 V · 0,417 A · 5 W'), findsWidgets);
    expect(find.textContaining('100% do brilho'), findsOneWidget);
    expect(find.textContaining('RESULTADO DA SIMULAÇÃO'), findsOneWidget);
  });

  testWidgets('interruptor aberto mostra circuito aberto', (tester) async {
    await abrir(tester);
    // O interruptor do exemplo fica entre os nós (2,0) e (3,0).
    await tester.tapAt(pontoDoTrecho(tester, 2, 3));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('editor-elemento')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('alternar-interruptor')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Circuito aberto'), findsOneWidget);
    expect(find.textContaining('aberto: nada passa'), findsOneWidget);
  });

  testWidgets('trocar o resistor recalcula o divisor', (tester) async {
    await abrir(tester);
    await tester.tap(find.byKey(const ValueKey('exemplo-Divisor de tensão')));
    await tester.pumpAndSettle();

    // R1 fica entre os nós (1,1) e (2,1): índices 7 e 8 na grade 6x4.
    await tester.tapAt(pontoDoTrecho(tester, 7, 8));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('campo-valor-elemento')), '2000');
    await tester.tap(find.byKey(const ValueKey('aplicar-valor-elemento')));
    await tester.pumpAndSettle();

    expect(find.textContaining('6 V · 0,003 A'), findsWidgets);
  });

  testWidgets('exemplo de curto queima o fusível e desliga tudo',
      (tester) async {
    await abrir(tester);
    await tester.tap(
        find.byKey(const ValueKey('exemplo-Curto protegido por fusível')));
    await tester.pumpAndSettle();

    expect(find.textContaining('FU1 queimou'), findsOneWidget);
    expect(find.textContaining('Circuito aberto'), findsOneWidget);
  });

  testWidgets('partida direta com selo segura o contator depois de soltar',
      (tester) async {
    await abrir(tester);
    await tester.tap(
        find.byKey(const ValueKey('exemplo-Partida direta com selo')));
    await tester.pumpAndSettle();

    // Com a partida solta a bobina está desligada.
    expect(find.textContaining('240 Ω · desligada'), findsOneWidget);

    // Botoeira de partida fica entre os nós 3 e 9.
    await tester.tapAt(pontoDoTrecho(tester, 3, 9));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apertar-botoeira')));
    await tester.pumpAndSettle();
    expect(find.textContaining('240 Ω · ligada'), findsOneWidget);
    expect(find.textContaining('24 V · 0,1 A'), findsWidgets);

    // Soltando a partida, o contato de selo mantém a bobina ligada.
    await tester.tap(find.byKey(const ValueKey('apertar-botoeira')));
    await tester.pumpAndSettle();
    expect(find.textContaining('240 Ω · ligada'), findsOneWidget);

    // Botoeira de parada fica entre os nós 2 e 3: abre e derruba o contator.
    await tester.tapAt(pontoDoTrecho(tester, 2, 3));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apertar-botoeira')));
    await tester.pumpAndSettle();
    expect(find.textContaining('240 Ω · desligada'), findsOneWidget);
    expect(find.textContaining('Circuito aberto'), findsOneWidget);
  });

  testWidgets('reversão trava o segundo contator com o primeiro ligado',
      (tester) async {
    await abrir(tester);
    await tester.tap(
        find.byKey(const ValueKey('exemplo-Reversão com intertravamento')));
    await tester.pumpAndSettle();

    // Grade 8x5: partida 1 entre os nós 9 e 10.
    await tester.tapAt(pontoDoTrecho(tester, 9, 10, colunas: 8, linhas: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apertar-botoeira')));
    await tester.pumpAndSettle();
    expect(find.textContaining('240 Ω · ligada'), findsOneWidget);

    // Partida 2 entre os nós 12 e 13: não pode ligar o segundo contator.
    await tester.tapAt(pontoDoTrecho(tester, 12, 13, colunas: 8, linhas: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apertar-botoeira')));
    await tester.pumpAndSettle();
    expect(find.textContaining('240 Ω · ligada'), findsOneWidget);
    expect(find.textContaining('intertravamento agindo'), findsOneWidget);
  });

  testWidgets('partida liga o motor pelo contato de potência',
      (tester) async {
    await abrir(tester);
    await tester.tap(
        find.byKey(const ValueKey('exemplo-Partida direta de motor DC')));
    await tester.pumpAndSettle();

    // Grade 6x5: partida entre os nós 7 e 8.
    expect(find.textContaining('motor 24 V / 24 W'), findsOneWidget);
    expect(find.textContaining('24 V · 1 A · 24 W'), findsNothing);

    await tester.tapAt(pontoDoTrecho(tester, 7, 8, colunas: 6, linhas: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apertar-botoeira')));
    await tester.pumpAndSettle();
    expect(find.textContaining('24 V · 1 A · 24 W'), findsOneWidget);
    expect(find.textContaining('240 Ω · ligada'), findsOneWidget);
  });

  testWidgets('relé térmico desarma o motor e pode ser rearmado',
      (tester) async {
    await abrir(tester);
    await tester.tap(
        find.byKey(const ValueKey('exemplo-Partida com relé de sobrecarga')));
    await tester.pumpAndSettle();

    // Relé entre os nós 4 e 5 da grade 6x5: baixa o ajuste para 0,5 A.
    await tester.tapAt(pontoDoTrecho(tester, 4, 5, colunas: 6, linhas: 5));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('campo-valor-elemento')), '0,5');
    await tester.tap(find.byKey(const ValueKey('aplicar-valor-elemento')));
    await tester.pumpAndSettle();

    // Partida entre os nós 7 e 8: 1 A num ajuste de 0,5 A desarma o relé.
    await tester.tapAt(pontoDoTrecho(tester, 7, 8, colunas: 6, linhas: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apertar-botoeira')));
    await tester.pumpAndSettle();
    expect(find.textContaining('desarmou'), findsWidgets);

    // Solta a partida antes de rearmar: com ela apertada o relé desarma de
    // novo na hora, porque a corrente continua acima do ajuste.
    await tester.tapAt(pontoDoTrecho(tester, 7, 8, colunas: 6, linhas: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apertar-botoeira')));
    await tester.pumpAndSettle();

    // Selecionando o relé de novo aparece o rearme.
    await tester.tapAt(pontoDoTrecho(tester, 4, 5, colunas: 6, linhas: 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rearmar-rele')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rearmar-rele')));
    await tester.pumpAndSettle();
    expect(find.textContaining('desarmou'), findsNothing);
  });

  testWidgets('temporizador conta os segundos e fecha o contato',
      (tester) async {
    await abrir(tester);
    await tester.tap(
        find.byKey(const ValueKey('exemplo-Sequência com temporizador')));
    await tester.pumpAndSettle();

    // Partida entre os nós 7 e 8 da grade 6x5.
    await tester.tapAt(pontoDoTrecho(tester, 7, 8, colunas: 6, linhas: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apertar-botoeira')));
    await tester.pumpAndSettle();

    // KT1 entre os nós 10 e 16: mostra o relógio e o botão de avançar.
    await tester.tapAt(pontoDoTrecho(tester, 10, 16, colunas: 6, linhas: 5));
    await tester.pumpAndSettle();
    expect(find.textContaining('Relógio: 0 s de 3 s'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('avancar-tempo')));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('Relógio: 3 s de 3 s'), findsOneWidget);
    expect(find.textContaining('o atraso base já completou'), findsOneWidget);
  });

  testWidgets('desligamento em sequência para o motor no fim do atraso',
      (tester) async {
    await abrir(tester);
    await tester.tap(
        find.byKey(const ValueKey('exemplo-Desligamento em sequência')));
    await tester.pumpAndSettle();

    // Partida entre os nós 7 e 8 da grade 6x5.
    await tester.tapAt(pontoDoTrecho(tester, 7, 8, colunas: 6, linhas: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apertar-botoeira')));
    await tester.pumpAndSettle();
    expect(find.textContaining('24 V · 1 A · 24 W'), findsOneWidget);

    // Solta a partida: o selo mantém K1 e o motor continua rodando.
    await tester.tapAt(pontoDoTrecho(tester, 7, 8, colunas: 6, linhas: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apertar-botoeira')));
    await tester.pumpAndSettle();
    expect(find.textContaining('24 V · 1 A · 24 W'), findsOneWidget);

    // KT1 entre os nós 10 e 16: avança até o atraso de 3 s.
    await tester.tapAt(pontoDoTrecho(tester, 10, 16, colunas: 6, linhas: 5));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('avancar-tempo')));
      await tester.pumpAndSettle();
    }

    // O NF abriu, K1 caiu e o motor parou: o relógio voltou a zero.
    expect(find.textContaining('Relógio: 0 s de 3 s'), findsOneWidget);
    expect(find.textContaining('24 V · 1 A · 24 W'), findsNothing);
  });

  testWidgets('desligamento temporizado segura o motor no retardo da queda',
      (tester) async {
    await abrir(tester);
    await tester.tap(
        find.byKey(const ValueKey('exemplo-Desligamento temporizado')));
    await tester.pumpAndSettle();

    // A leitura do motor fica na própria linha dele (id 3_4 na grade 7x5).
    Finder motor(String texto) => find.descendant(
          of: find.byKey(const ValueKey('medida-3_4')),
          matching: find.textContaining(texto),
        );

    // Grade 7x5: partida entre os nós 15 e 16.
    await tester.tapAt(pontoDoTrecho(tester, 15, 16, colunas: 7, linhas: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apertar-botoeira')));
    await tester.pumpAndSettle();
    expect(motor('24 V · 1 A · 24 W'), findsOneWidget);

    // Solta a partida: o selo mantém o motor.
    await tester.tapAt(pontoDoTrecho(tester, 15, 16, colunas: 7, linhas: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apertar-botoeira')));
    await tester.pumpAndSettle();
    expect(motor('24 V · 1 A · 24 W'), findsOneWidget);

    // KT1 entre os nós 24 e 25: conta 3 s de subida.
    await tester.tapAt(pontoDoTrecho(tester, 24, 25, colunas: 7, linhas: 5));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('avancar-tempo')));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('Relógio: 3 s de 3 s'), findsOneWidget);
    expect(find.byKey(const ValueKey('relogio-queda')), findsOneWidget);

    // Aperta a parada: K1 cai, mas o motor continua pelo 67/68.
    await tester.tapAt(pontoDoTrecho(tester, 16, 17, colunas: 7, linhas: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apertar-botoeira')));
    await tester.pumpAndSettle();
    expect(find.textContaining('segurando na queda'), findsOneWidget);
    expect(motor('24 V · 1 A · 24 W'), findsOneWidget);

    // Volta ao KT1 e avança a queda: só no terceiro toque o motor para.
    await tester.tapAt(pontoDoTrecho(tester, 24, 25, colunas: 7, linhas: 5));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const ValueKey('avancar-tempo')));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('Queda: 2 s de 3 s'), findsOneWidget);
    expect(motor('24 V · 1 A · 24 W'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('avancar-tempo')));
    await tester.pumpAndSettle();
    expect(motor('24 V · 1 A · 24 W'), findsNothing);
    expect(find.textContaining('Queda: 3 s de 3 s'), findsOneWidget);
  });

  testWidgets('dois contatos do temporizador trocam as lâmpadas aos 3 s',
      (tester) async {
    await abrir(tester);
    await tester.tap(
        find.byKey(const ValueKey('exemplo-Dois contatos do temporizador')));
    await tester.pumpAndSettle();

    Finder leitura(String id, String texto) => find.descendant(
          of: find.byKey(ValueKey('medida-$id')),
          matching: find.textContaining(texto),
        );

    // Grade 8x5: parada em 9-10, partida em 10-11, KT1 em 13-21, L1 em 22-30
    // (ramo do 67/68 NA) e L2 em 23-31 (ramo do 67/68 NF).
    await tester.tapAt(pontoDoTrecho(tester, 10, 11, colunas: 8, linhas: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apertar-botoeira')));
    await tester.pumpAndSettle();
    expect(leitura('23_31', '· 5 W'), findsOneWidget);
    expect(leitura('22_30', '· 0 W'), findsOneWidget);

    // Aos 3 s o mesmo temporizador troca as lâmpadas: L1 acende, L2 apaga.
    await tester.tapAt(pontoDoTrecho(tester, 13, 21, colunas: 8, linhas: 5));
    await tester.pumpAndSettle();
    expect(find.textContaining('Relógio: 0 s de 3 s'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('avancar-tempo')));
      await tester.pumpAndSettle();
    }
    expect(leitura('22_30', '· 5 W'), findsOneWidget);
    expect(leitura('23_31', '· 0 W'), findsOneWidget);

    // Cada contato escolhe o tipo dele: virando o NA em NF, só ele muda.
    await tester.tapAt(pontoDoTrecho(tester, 14, 22, colunas: 8, linhas: 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('contato-tipo-na')), findsOneWidget);
    expect(find.textContaining('contato 67/68 do temporizador'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('contato-tipo-nf')));
    await tester.pumpAndSettle();
    expect(find.textContaining('contato 67/68 NF do temporizador'), findsWidgets);
    expect(find.byKey(const ValueKey('contato-tipo-nf')), findsOneWidget);
  });

  testWidgets('cada contato usa o próprio atraso no mesmo temporizador',
      (tester) async {
    await abrir(tester);
    await tester.tap(find.byKey(
        const ValueKey('exemplo-Contatos com tempos diferentes')));
    await tester.pumpAndSettle();

    Finder leitura(String id, String texto) => find.descendant(
          of: find.byKey(ValueKey('medida-$id')),
          matching: find.textContaining(texto),
        );

    // Grade 8x5: partida em 10-11, KT1 em 13-21, L1 (NA de 1 s) em 22-30 e
    // L2 (NF de 5 s) em 23-31.
    await tester.tapAt(pontoDoTrecho(tester, 10, 11, colunas: 8, linhas: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apertar-botoeira')));
    await tester.pumpAndSettle();
    expect(leitura('23_31', '· 5 W'), findsOneWidget);
    expect(leitura('22_30', '· 0 W'), findsOneWidget);

    await tester.tapAt(pontoDoTrecho(tester, 13, 21, colunas: 8, linhas: 5));
    await tester.pumpAndSettle();
    expect(find.textContaining('(ajuste base)'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('avancar-tempo')));
    await tester.pumpAndSettle();

    // No primeiro segundo o NA de 1 s fecha e o NF de 5 s continua fechado.
    expect(leitura('22_30', '· 5 W'), findsOneWidget);
    expect(leitura('23_31', '· 5 W'), findsOneWidget);

    // Até 4 s nada muda; aos 5 s o NF de 5 s abre e L2 apaga.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('avancar-tempo')));
      await tester.pumpAndSettle();
    }
    expect(leitura('22_30', '· 5 W'), findsOneWidget);
    expect(leitura('23_31', '· 5 W'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('avancar-tempo')));
    await tester.pumpAndSettle();
    expect(leitura('22_30', '· 5 W'), findsOneWidget);
    expect(leitura('23_31', '· 0 W'), findsOneWidget);

    // O campo do atraso próprio aparece ao escolher o contato NA.
    await tester.tapAt(pontoDoTrecho(tester, 14, 22, colunas: 8, linhas: 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('campo-atraso-contato')), findsOneWidget);
    expect(find.textContaining('Atraso deste contato: 1 s'), findsOneWidget);
  });

  testWidgets('cada contato segura pela própria queda depois da parada',
      (tester) async {
    await abrir(tester);
    await tester.tap(find.byKey(
        const ValueKey('exemplo-Quedas diferentes no temporizador')));
    await tester.pumpAndSettle();

    Finder leitura(String id, String texto) => find.descendant(
          of: find.byKey(ValueKey('medida-$id')),
          matching: find.textContaining(texto),
        );

    // Parada em 9-10, partida em 10-11, KT1 em 13-21, L1 em 22-30 (NA) e
    // L2 em 23-31 (NF).
    await tester.tapAt(pontoDoTrecho(tester, 10, 11, colunas: 8, linhas: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apertar-botoeira')));
    await tester.pumpAndSettle();

    await tester.tapAt(pontoDoTrecho(tester, 13, 21, colunas: 8, linhas: 5));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const ValueKey('avancar-tempo')));
      await tester.pumpAndSettle();
    }
    expect(leitura('22_30', '· 5 W'), findsOneWidget);
    expect(leitura('23_31', '· 0 W'), findsOneWidget);

    // Parada: os dois contatos perdem energia, mas continuam acionados.
    await tester.tapAt(pontoDoTrecho(tester, 9, 10, colunas: 8, linhas: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apertar-botoeira')));
    await tester.pumpAndSettle();
    expect(leitura('22_30', '· 5 W'), findsOneWidget);
    expect(leitura('23_31', '· 0 W'), findsOneWidget);

    // Volta ao KT1 e avança a queda: 1 s derruba L1; o NF segura até 4 s.
    await tester.tapAt(pontoDoTrecho(tester, 13, 21, colunas: 8, linhas: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('avancar-tempo')));
    await tester.pumpAndSettle();
    expect(leitura('22_30', '· 0 W'), findsOneWidget);
    expect(leitura('23_31', '· 0 W'), findsOneWidget);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const ValueKey('avancar-tempo')));
      await tester.pumpAndSettle();
    }
    expect(leitura('23_31', '· 0 W'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('avancar-tempo')));
    await tester.pumpAndSettle();
    expect(leitura('23_31', '· 5 W'), findsOneWidget);
    expect(leitura('22_30', '· 0 W'), findsOneWidget);

    // O campo da queda própria aparece ao escolher o contato NA.
    await tester.tapAt(pontoDoTrecho(tester, 14, 22, colunas: 8, linhas: 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('campo-queda-contato')), findsOneWidget);
    expect(find.textContaining('Retardo na queda deste contato: 1 s (próprio)'),
        findsOneWidget);
  });

  testWidgets('cada contato conta o próprio relógio, sem esperar o temporizador',
      (tester) async {
    await abrir(tester);
    await tester.tap(find.byKey(
        const ValueKey('exemplo-Relógios independentes no temporizador')));
    await tester.pumpAndSettle();

    Finder leitura(String id, String texto) => find.descendant(
          of: find.byKey(ValueKey('medida-$id')),
          matching: find.textContaining(texto),
        );

    // Parada 9-10, partida 10-11, KT1 13-21, L1 22-30 (NA, 2 s) e L2 23-31
    // (NF, 7 s). O ajuste base do KT1 é 12 s e não é usado por nenhum contato.
    await tester.tapAt(pontoDoTrecho(tester, 10, 11, colunas: 8, linhas: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apertar-botoeira')));
    await tester.pumpAndSettle();

    // O botão de avançar fica no editor do temporizador: selecione o KT1.
    await tester.tapAt(pontoDoTrecho(tester, 13, 21, colunas: 8, linhas: 5));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const ValueKey('avancar-tempo')));
      await tester.pumpAndSettle();
    }
    expect(leitura('22_30', '· 5 W'), findsOneWidget);
    expect(leitura('23_31', '· 5 W'), findsOneWidget);

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const ValueKey('avancar-tempo')));
      await tester.pumpAndSettle();
    }
    expect(leitura('22_30', '· 5 W'), findsOneWidget);
    expect(leitura('23_31', '· 0 W'), findsOneWidget);
  });

  testWidgets('ferramenta apagar remove o componente do trecho',
      (tester) async {
    await abrir(tester);
    await tester.tap(find.byKey(const ValueKey('exemplo-Divisor de tensão')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ferramenta-apagar')));
    await tester.pumpAndSettle();
    await tester.tapAt(pontoDoTrecho(tester, 7, 8));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('editor-elemento')), findsNothing);
    expect(find.textContaining('Circuito aberto'), findsOneWidget);
  });
}
