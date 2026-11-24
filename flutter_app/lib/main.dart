import 'package:material_ui/material_ui.dart';
import 'home_screen.dart';
import 'services/abrir_tela.dart';
import 'services/bloqueio_gate.dart';
import 'services/ponte_ia_fundo.dart';
import 'services/voz_externa_service.dart';
import 'ui_common.dart';

export 'catalog.dart';
export 'ui_common.dart' show jarvisKwsController, cyan, bg, panel, muted;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Perguntas ouvidas com o app fora da tela são respondidas pelo provedor
  // configurado, sem abrir a conversa.
  PonteIaFundo.ligar();
  // Decide uma vez se as respostas usam o Fish Audio; a conversa não consulta
  // o cofre a cada frase.
  await VozExternaConfig.carregar();
  runApp(const JarvisApp());
}

/// Entrada do **motor sem tela** do serviço de palavra de ativação.
///
/// Com o app encerrado, o Android derruba o motor do Flutter e não há quem
/// responda as perguntas livres. `JarvisPonteIa.kt` sobe então um motor só do
/// serviço com esta entrada: ela liga a mesma ponte de IA (mesmos provedores,
/// mesmas chaves, mesma personalidade) sem abrir tela nenhuma, e carrega a voz
/// externa para o Fish Audio também falar no segundo plano. O motor é desligado
/// depois de três minutos ocioso.
@pragma('vm:entry-point')
Future<void> mainFundo() async {
  WidgetsFlutterBinding.ensureInitialized();
  // A mesma decisão da tela: só tenta a rede com a voz ligada e a chave no cofre.
  await VozExternaConfig.carregar();
  PonteIaFundo.ligar();
}

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
      debugShowCheckedModeBanner: false,
      // Navegador único: uma tela pedida por voz abre por cima de qualquer
      // outra, inclusive quando o pedido chega do serviço de segundo plano.
      navigatorKey: AbrirTela.navegador,
      title: 'J.A.R.V.I.S. Nova',
      theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: bg,
          colorScheme: ColorScheme.fromSeed(
              seedColor: cyan, brightness: Brightness.dark),
          useMaterial3: true),
      home: const BloqueioGate(child: LegacyHomeScreen()));
}
