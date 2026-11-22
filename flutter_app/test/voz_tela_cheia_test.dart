import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/services/kws_controller.dart';
import 'package:jarvis_nova/services/voz_tela_cheia_page.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('modo voz mostra estado real e botão de encerrar',
      (tester) async {
    final controller = KwsController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
        MaterialApp(home: VozTelaCheiaPage(controller: controller)));
    await tester.pump();

    expect(find.text('Modo voz'), findsOneWidget);
    expect(find.text('Iniciar escuta'), findsOneWidget);
    expect(
        find.text('Diga “Jarvis” ou use o botão para falar.'), findsOneWidget);

    // A página não inventa "Ouvindo": sem confirmação do serviço, o rótulo é o estado neutro.
    expect(find.text('Ouvindo'), findsNothing);

    // Fecha para liberar o controlador de animação antes do fim do teste.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
