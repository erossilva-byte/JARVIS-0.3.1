import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/services/acessibilidade_page.dart';
import 'package:jarvis_nova/services/acessibilidade_service.dart';
import 'package:jarvis_nova/services/acessibilidade_store.dart';
import 'package:material_ui/material_ui.dart';

class ConsentimentoFalso implements ConsentimentoAcessibilidade {
  ConsentimentoFalso(this.valor);
  bool valor;

  @override
  Future<bool> ativo() async => valor;

  @override
  Future<void> definir(bool novo) async {
    valor = novo;
  }
}

class CanalFalso {
  final chamadas = <String>[];
  final argumentos = <Map<String, Object?>>[];

  Future<Map<Object?, Object?>?> chamar(
      String metodo, Map<String, Object?> args) async {
    chamadas.add(metodo);
    argumentos.add(args);
    if (metodo == 'status') {
      return {'ligado': true, 'pacote': 'com.whatsapp'};
    }
    if (metodo == 'tocar') {
      return {'ok': true, 'mensagem': 'Toquei em "Enviar".'};
    }
    return {'ok': true, 'nos': <Object?>[]};
  }
}

Future<CanalFalso> abrir(WidgetTester tester, ConsentimentoFalso consentimento) async {
  tester.view.physicalSize = const Size(430, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final canal = CanalFalso();
  await tester.pumpWidget(MaterialApp(
      home: AcessibilidadePage(
          servico: AcessibilidadeService(
              chamada: canal.chamar, consentimento: consentimento))));
  await tester.pumpAndSettle();
  return canal;
}

void main() {
  testWidgets('abre desligada e explica o escopo estreito', (tester) async {
    await abrir(tester, ConsentimentoFalso(false));

    final chave = find.byKey(const ValueKey('acessibilidade-ativar'));
    expect(chave, findsOneWidget);
    expect(tester.widget<Switch>(chave).value, isFalse);
    expect(find.textContaining('não digita'), findsOneWidget);
    expect(find.text('Serviço do Android: autorizado'), findsOneWidget);
    expect(find.textContaining('Desligado'), findsWidgets);
  });

  testWidgets('ligar grava o consentimento e avisa que agiu', (tester) async {
    final consentimento = ConsentimentoFalso(false);
    await abrir(tester, consentimento);

    final chave = find.byKey(const ValueKey('acessibilidade-ativar'));
    await tester.ensureVisible(chave);
    await tester.tap(chave);
    await tester.pumpAndSettle();

    expect(consentimento.valor, isTrue);
    expect(tester.widget<Switch>(chave).value, isTrue);
    expect(find.byKey(const ValueKey('acessibilidade-resultado')), findsOneWidget);
    expect(find.textContaining('Automação de tela ligada'), findsOneWidget);
  });

  testWidgets('tocar pelo texto chega ao serviço com o alvo dito',
      (tester) async {
    final canal = await abrir(tester, ConsentimentoFalso(true));

    await tester.enterText(
        find.byKey(const ValueKey('acessibilidade-campo')), 'tocar em Enviar');
    final botao = find.byKey(const ValueKey('executar-acessibilidade'));
    await tester.ensureVisible(botao);
    await tester.tap(botao);
    await tester.pumpAndSettle();

    expect(canal.chamadas, contains('tocar'));
    expect(canal.argumentos.last['texto'], 'Enviar');
    expect(find.textContaining('Toquei em'), findsOneWidget);
  });

  testWidgets('texto que não é comando de tela não vai para o Android',
      (tester) async {
    final canal = await abrir(tester, ConsentimentoFalso(true));

    await tester.enterText(find.byKey(const ValueKey('acessibilidade-campo')),
        'como tocar violão');
    final botao = find.byKey(const ValueKey('executar-acessibilidade'));
    await tester.ensureVisible(botao);
    await tester.tap(botao);
    await tester.pumpAndSettle();

    expect(canal.chamadas.where((c) => c == 'tocar'), isEmpty);
    expect(find.textContaining('não é um comando de tela'), findsOneWidget);
  });
}
