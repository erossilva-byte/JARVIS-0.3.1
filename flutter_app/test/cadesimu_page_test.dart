import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/services/cadesimu_cad.dart';
import 'package:jarvis_nova/services/cadesimu_page.dart';
import 'package:material_ui/material_ui.dart';

const amostra = 'CADe_SIMU*0*3004#-X#########'
    '*0*0*0*0*0*0*0*0*69*51*0*0*-12*-9*18*3*0*0*0*1*0*0*0#'
    '*1*8##########*0*0*0*0*0*0*0*0*63*30*73*33*0*0*0*0*0*0*0*0*0*0*0#FUERZA'
    '*2*4000#*0*0*0*0*0*0*0*0*69*51*69*87*0*0*0*0*0*0*0*0*0*0*0'
    '#\$\$\$&&&';

class SeletorFalso implements SeletorCad {
  SeletorFalso(this.arquivo);
  final ArquivoCad? arquivo;
  int chamadas = 0;

  @override
  Future<ArquivoCad?> escolher() async {
    chamadas++;
    return arquivo;
  }
}

void main() {
  testWidgets('mostra aviso de somente leitura e o resumo do arquivo',
      (tester) async {
    final seletor = SeletorFalso(
        ArquivoCad('motor.cad', Uint8List.fromList(amostra.codeUnits)));
    await tester.pumpWidget(MaterialApp(home: CadesimuPage(seletor: seletor)));
    expect(find.textContaining('Somente leitura'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('abrir-cad')));
    await tester.pumpAndSettle();

    expect(seletor.chamadas, 1);
    expect(find.text('motor.cad'), findsOneWidget);
    expect(find.text('SÍMBOLOS'), findsOneWidget);
    expect(find.textContaining('não edita, não simula'), findsOneWidget);
  });

  testWidgets('erro do seletor aparece em português', (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: CadesimuPage(seletor: _SeletorComErro())));
    await tester.tap(find.byKey(const ValueKey('abrir-cad')));
    await tester.pumpAndSettle();
    expect(find.text('Arquivo inválido.'), findsOneWidget);
  });

  testWidgets('cancelar não mostra erro nem resumo', (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: CadesimuPage(seletor: SeletorFalso(null))));
    await tester.tap(find.byKey(const ValueKey('abrir-cad')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível'), findsNothing);
    expect(find.text('SÍMBOLOS'), findsNothing);
  });
}

class _SeletorComErro implements SeletorCad {
  @override
  Future<ArquivoCad?> escolher() async =>
      throw CadesimuErro('Arquivo inválido.');
}
