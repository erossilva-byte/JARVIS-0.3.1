/// Segundo plano de verdade — contrato puro, sem Flutter e sem rede.
///
/// O estado vem do serviço Android (canal do aparelho) e este arquivo só decide o
/// texto e as pendências mostradas na tela. A execução acontece no Kotlin, com o
/// mesmo registro fechado de comandos de baixo risco.
library;

/// Ações que o serviço consegue executar com o app fechado.
const acoesEmSegundoPlano = <String>[
  'Abrir um app instalado pelo nome (“abrir WhatsApp”).',
  'Ligar, desligar ou alternar a lanterna.',
  'Definir ou ajustar o volume de mídia.',
  'Abrir o alarme do relógio em um horário.',
  'Dizer as horas e a data de hoje.',
  'Responder perguntas livres com o provedor de IA já configurado.',
];

/// Limites que não devem ser escondidos do usuário.
const limitesSegundoPlano = <String>[
  'Abrir apps e o alarme a partir do segundo plano exige “Exibir sobre outros apps” '
      'autorizado no Android; sem isso o sistema bloqueia a abertura. O microfone continua '
      'funcionando: lanterna e volume são executados e a abertura avisa que falta a autorização.',
  'A fala — comando ou pergunta — é transcrita pelo reconhecimento offline pt-BR do '
      'Android. Se esse pacote não estiver instalado, o JARVIS avisa em vez de enviar áudio '
      'para a nuvem.',
  'A escuta fica aberta por até 20 segundos: a pergunta longa cabe inteira e o microfone '
      'é liberado se ninguém falar. No Android 13+ o vocabulário de elétrica, programação e '
      'mídia entra como pista do reconhecedor local.',
  'Perguntas livres usam o provedor de IA configurado, mas a ponte só existe enquanto '
      'o app está vivo na memória. Se o Android tiver encerrado o app, o JARVIS avisa em '
      'vez de inventar a resposta; abrir o app uma vez religa a ponte.',
  'Com a tela aberta, o comando é sempre respondido na conversa — inclusive sem '
      '“Exibir sobre outros apps” autorizado.',
  'O aviso “JARVIS ativo” é uma notificação de alta prioridade; no modo Não Perturbe '
      'ela pode aparecer só na gaveta, sem surgir na tela.',
  'Depois de reiniciar o aparelho, o Android não deixa iniciar sozinho um serviço de '
      'microfone: a escuta volta quando o app é aberto uma vez.',
];

/// Instante da última ação, pronto para exibição.
class EstadoFundo {
  const EstadoFundo({
    required this.modoSemTela,
    required this.podeAbrirApps,
    required this.servicoAtivo,
    required this.ouvindo,
    required this.ultimaAcao,
    required this.ultimoResultado,
    required this.ultimoOk,
    required this.ponteDisponivel,
    this.ultimoEm,
  });

  final bool modoSemTela;
  final bool podeAbrirApps;
  final bool servicoAtivo;
  final bool ouvindo;
  final String ultimaAcao;
  final String ultimoResultado;
  final bool ultimoOk;
  final bool ponteDisponivel;
  final DateTime? ultimoEm;

  /// Estado inicial: nada ligado e nenhuma ponte confirmada.
  static const vazio = EstadoFundo(
    modoSemTela: false,
    podeAbrirApps: false,
    servicoAtivo: false,
    ouvindo: false,
    ultimaAcao: '',
    ultimoResultado: '',
    ultimoOk: false,
    ponteDisponivel: false,
    ultimoEm: null,
  );

  factory EstadoFundo.fromMap(Map<Object?, Object?> mapa) {
    final quando = mapa['ultimoEm'];
    final milissegundos = quando is num ? quando.toInt() : 0;
    return EstadoFundo(
      modoSemTela: mapa['modoSemTela'] == true,
      podeAbrirApps: mapa['podeAbrirApps'] == true,
      servicoAtivo: mapa['servicoAtivo'] == true,
      ouvindo: mapa['ouvindo'] == true,
      ultimaAcao: mapa['ultimaAcao']?.toString() ?? '',
      ultimoResultado: mapa['ultimoResultado']?.toString() ?? '',
      ultimoOk: mapa['ultimoOk'] == true,
      ponteDisponivel: true,
      ultimoEm: milissegundos <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(milissegundos),
    );
  }

  EstadoFundo copiarCom({bool? modoSemTela, bool? podeAbrirApps}) =>
      EstadoFundo(
        modoSemTela: modoSemTela ?? this.modoSemTela,
        podeAbrirApps: podeAbrirApps ?? this.podeAbrirApps,
        servicoAtivo: servicoAtivo,
        ouvindo: ouvindo,
        ultimaAcao: ultimaAcao,
        ultimoResultado: ultimoResultado,
        ultimoOk: ultimoOk,
        ponteDisponivel: ponteDisponivel,
        ultimoEm: ultimoEm,
      );
}

/// Tudo pronto para o comando por voz funcionar sem abrir a tela.
bool fundoPronto(EstadoFundo estado) =>
    estado.ponteDisponivel &&
    estado.servicoAtivo &&
    estado.modoSemTela &&
    estado.podeAbrirApps;

/// Frase curta do estado do serviço, usada no cartão principal.
String resumoFundo(EstadoFundo estado) {
  if (!estado.ponteDisponivel) {
    return 'Este recurso é do app Android instalado. Fora do aparelho não há microfone '
        'em segundo plano.';
  }
  if (!estado.servicoAtivo) {
    return 'O detector não está ativo. Abra “Voz e palavra de ativação” e ligue a escuta '
        'para o JARVIS responder com o app fechado.';
  }
  if (estado.ouvindo) {
    return 'Escutando a palavra de ativação localmente. Chame “Jarvis” para perguntar ou '
        'dar um comando sem abrir o app.';
  }
  return 'Detector ativo e em espera. Assim que ele ouvir a palavra, volta a escutar.';
}

/// O que ainda falta para o comando por voz funcionar de ponta a ponta.
List<String> pendenciasFundo(EstadoFundo estado) {
  if (!estado.ponteDisponivel) return const [];
  final pendencias = <String>[];
  if (!estado.servicoAtivo) {
    pendencias.add(
        'Ligar a escuta da palavra de ativação (com o microfone autorizado).');
  }
  if (!estado.modoSemTela) {
    pendencias.add('Ligar “responder e executar sem abrir a tela”.');
  }
  if (!estado.podeAbrirApps) {
    pendencias.add(
        'Autorizar “Exibir sobre outros apps” para o JARVIS abrir apps e o alarme sozinho; '
        'sem isso ele ainda ouve o comando e executa lanterna e volume.');
  }
  return pendencias;
}

/// Idade da última ação em linguagem simples; nulo quando nunca houve ação.
String? idadeUltimaAcao(DateTime? quando, DateTime agora) {
  if (quando == null) return null;
  final diferenca = agora.difference(quando);
  if (diferenca.isNegative) return 'agora mesmo';
  if (diferenca.inSeconds < 60) return 'há ${diferenca.inSeconds} s';
  if (diferenca.inMinutes < 60) return 'há ${diferenca.inMinutes} min';
  if (diferenca.inHours < 24) return 'há ${diferenca.inHours} h';
  return 'há ${diferenca.inDays} dia(s)';
}

/// Resultado devolvido pelo executor nativo ao testar um comando por escrito.
class ResultadoFundo {
  const ResultadoFundo({
    required this.ok,
    required this.mensagem,
    this.acao = '',
  });

  final bool ok;
  final String mensagem;
  final String acao;
}
