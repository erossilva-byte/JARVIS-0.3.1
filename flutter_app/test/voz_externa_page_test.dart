import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/core/voz_externa.dart';
import 'package:jarvis_nova/services/voz_externa_page.dart';
import 'package:jarvis_nova/services/voz_externa_service.dart';
import 'package:material_ui/material_ui.dart';

/// Serviço falso: nada sai para a rede e nada toca, mas o que a tela pede é
/// registrado — é o que o teste precisa para provar o comportamento.
class _ServicoFalso extends VozExternaService {
  bool comChave = false;
  bool ativaAgora = false;
  String? chaveGravada;
  String? idGravado;
  int testes = 0;

  @override
  Future<String> id() async => idVozPadrao;

  @override
  Future<bool> ativa() async => ativaAgora;

  @override
  Future<String?> lerChave() async => comChave ? 'sk-falsa' : null;

  @override
  Future<void> gravarChave(String chave) async {
    chaveGravada = chave;
    comChave = true;
  }

  @override
  Future<void> gravarId(String id) async {
    idGravado = id;
  }

  @override
  Future<void> definirAtiva(bool ativa) async {
    ativaAgora = ativa;
  }

  @override
  Future<ResultadoVozExterna> gerar(String texto) async {
    testes++;
    if (!comChave) {
      return const ResultadoVozExterna(
          erro: 'Falta a chave do serviço de voz.');
    }
    return ResultadoVozExterna(audio: Uint8List.fromList([1, 2, 3]));
  }

  @override
  Future<bool> tocar(Uint8List audio) async => false;
}


/// Tela alta: as listas destas telas são longas e o teste padrão de 800×600
/// deixa os botões de baixo fora da árvore, como aconteceria no aparelho sem
/// rolagem.
void _telaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('mostra o ID padrão e avisa que falta a chave', (tester) async {
    _telaAlta(tester);
    final servico = _ServicoFalso();
    await tester.pumpWidget(
        MaterialApp(home: VozExternaPage(servico: servico)));
    await tester.pumpAndSettle();

    expect(find.textContaining(idVozPadrao), findsWidgets);
    // O resumo e a linha de status repetem o estado: os dois são aceitos.
    expect(find.textContaining('sem chave'), findsWidgets);
    expect(find.byKey(const ValueKey('voz-externa-limite')), findsWidgets);
  });

  testWidgets('salvar a chave grava e confirma, sem mostrar o valor',
      (tester) async {
    _telaAlta(tester);
    final servico = _ServicoFalso();
    await tester.pumpWidget(
        MaterialApp(home: VozExternaPage(servico: servico)));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('voz-chave-campo')), 'sk-segredo');
    await tester.tap(find.byKey(const ValueKey('voz-chave-salvar')));
    await tester.pumpAndSettle();

    expect(servico.chaveGravada, 'sk-segredo');
    expect(find.textContaining('Chave salva'), findsOneWidget);
    // A chave não fica escrita na tela.
    expect(find.text('sk-segredo'), findsNothing);
  });

  testWidgets('testar sem chave diz o motivo em vez de fingir áudio',
      (tester) async {
    _telaAlta(tester);
    final servico = _ServicoFalso();
    await tester.pumpWidget(
        MaterialApp(home: VozExternaPage(servico: servico)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('voz-externa-testar')));
    await tester.pumpAndSettle();

    expect(servico.testes, 1);
    expect(find.textContaining('Falta a chave'), findsOneWidget);
  });

  testWidgets('o interruptor liga a voz externa no armazenamento',
      (tester) async {
    _telaAlta(tester);
    final servico = _ServicoFalso();
    await tester.pumpWidget(
        MaterialApp(home: VozExternaPage(servico: servico)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('voz-externa-ativa')));
    await tester.pumpAndSettle();

    expect(servico.ativaAgora, isTrue);
  });
}
