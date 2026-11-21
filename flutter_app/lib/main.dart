import 'package:material_ui/material_ui.dart';
import 'home_screen.dart';
import 'services/bloqueio_gate.dart';
import 'services/ponte_ia_fundo.dart';
import 'ui_common.dart';

export 'catalog.dart';
export 'ui_common.dart' show jarvisKwsController, cyan, bg, panel, muted;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Perguntas ouvidas com o app fora da tela são respondidas pelo provedor
  // configurado, sem abrir a conversa.
  PonteIaFundo.ligar();
  runApp(const JarvisApp());
}

/// Entrada do **motor sem tela** do serviço de palavra de ativação.
///
/// Com o app encerrado, o Android derruba o motor do Flutter e não há quem
/// responda as perguntas livres. `JarvisPonteIa.kt` sobe então um motor só do
/// serviço com esta entrada: ela liga a mesma ponte de IA (mesmos provedores,
/// mesmas chaves, mesma personalidade) sem abrir tela nenhuma. O motor é
/// desligado depois de três minutos ocioso.
@pragma('vm:entry-point')
void mainFundo() {
  WidgetsFlutterBinding.ensureInitialized();
  PonteIaFundo.ligar();
}

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'J.A.R.V.I.S. Nova',
      theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: bg,
          colorScheme: ColorScheme.fromSeed(
              seedColor: cyan, brightness: Brightness.dark),
          useMaterial3: true),
      home: const BloqueioGate(child: LegacyHomeScreen()));
}
