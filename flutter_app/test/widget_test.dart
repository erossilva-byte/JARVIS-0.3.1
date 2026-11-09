import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_nova/main.dart';

void main() {
  testWidgets('exibe o núcleo e navega para o catálogo de funcionalidades', (tester) async {
    await tester.pumpWidget(const JarvisApp());
    expect(find.text('J.A.R.V.I.S. NOVA'), findsOneWidget);
    await tester.tap(find.text('Sistemas'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Capacidades do J.A.R.V.I.S.'), findsOneWidget);
    expect(find.text('Hermes Agent'), findsOneWidget);
    expect(find.text('CADeSIMU e elétrica'), findsOneWidget);
  });
}
