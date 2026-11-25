/// Pedido de abrir uma tela do próprio JARVIS — regra pura, sem Flutter.
///
/// "Abre o modo visão", "exibe o modo palco", "abre a memória", "mostra as
/// pessoas": antes esses pedidos caíam no comando de abrir app e o Android
/// procurava um aplicativo chamado "visão". Aqui eles viram uma tela conhecida,
/// com uma chave fixa que o serviço de segundo plano também entende.
///
/// Só vale com verbo de abrir (abre, abrir, mostra, exibe, entra, vai para) ou
/// com "modo X" sozinho. Pergunta ("como abro a memória?") nunca vira ação, e
/// pedido de mensagem/ligação não é confundido com abrir ficha de pessoa.
library;

/// Telas do JARVIS que podem ser abertas por voz.
enum TelaJarvis {
  visao('visao', 'o modo visão'),
  palco('palco', 'o modo palco'),
  memoria('memoria', 'a memória'),
  pessoas('pessoas', 'as pessoas'),
  tarefas('tarefas', 'as tarefas e rotinas'),
  programacao('programacao', 'o modo programação'),
  arquivos('arquivos', 'os arquivos'),
  cadesimu('cadesimu', 'o CADeSIMU'),
  circuito('circuito', 'o simulador de circuitos'),
  projetista('projetista', 'o projetista'),
  seguranca('seguranca', 'a segurança'),
  personalizacao('personalizacao', 'a personalização'),
  configuracoes('configuracoes', 'as configurações'),
  habilidades('habilidades', 'as habilidades'),
  gestos('gestos', 'os gestos e o modo noturno'),
  timbre('timbre', 'os perfis de timbre'),
  vozExterna('voz_externa', 'a voz externa'),
  provedores('provedores', 'os provedores de IA'),
  historico('historico', 'o histórico de conversas'),
  historicoVoz('historico_voz', 'o histórico de voz'),
  backups('backups', 'os backups da memória'),
  regrasPalco('regras_palco', 'as regras do palco'),
  ativacao('ativacao', 'a palavra de ativação'),
  mapaVoz('mapa_voz', 'o mapa da voz'),
  aparelho('aparelho', 'o aparelho conectado'),
  comandos('comandos', 'os comandos do Android'),
  acessibilidade('acessibilidade', 'a acessibilidade de tela'),
  dispositivo('dispositivo', 'a central do aparelho'),
  segundoPlano('segundo_plano', 'o segundo plano'),
  atualizacoes('atualizacoes', 'as atualizações'),
  avatar('avatar', 'o avatar 3D'),
  hermes('hermes', 'o Hermes'),
  agentes('agentes', 'os agentes'),
  modelosLocais('modelos_locais', 'os modelos locais'),
  conversa('conversa', 'a conversa'),
  voz('voz', 'o modo voz');

  const TelaJarvis(this.chave, this.rotulo);

  /// Chave estável usada no `Intent` do Android e no histórico.
  final String chave;

  /// Como a tela é chamada na fala ("Abrindo a memória.").
  final String rotulo;

  /// Tela pela chave do `Intent`; `null` quando a chave não existe nesta versão.
  static TelaJarvis? porChave(String chave) {
    final alvo = chave.trim().toLowerCase();
    if (alvo.isEmpty) return null;
    for (final tela in values) {
      if (tela.chave == alvo) return tela;
    }
    return null;
  }
}

/// Alias de fala para cada tela. A ordem não importa: o casamento testa o
/// alias mais longo primeiro, para "voz externa" não virar "voz".
const _aliases = <String, TelaJarvis>{
  'modo visao': TelaJarvis.visao,
  'modo vision': TelaJarvis.visao,
  'vision': TelaJarvis.visao,
  'visao': TelaJarvis.visao,
  'camera': TelaJarvis.visao,
  'modo palco': TelaJarvis.palco,
  'palco': TelaJarvis.palco,
  'memoria': TelaJarvis.memoria,
  'obsidian': TelaJarvis.memoria,
  'anotacoes': TelaJarvis.memoria,
  'notas': TelaJarvis.memoria,
  'pessoas': TelaJarvis.pessoas,
  'fichas': TelaJarvis.pessoas,
  'ficha de pessoas': TelaJarvis.pessoas,
  'tarefas': TelaJarvis.tarefas,
  'rotinas': TelaJarvis.tarefas,
  'lembretes': TelaJarvis.tarefas,
  'agenda': TelaJarvis.tarefas,
  'modo programacao': TelaJarvis.programacao,
  'programacao': TelaJarvis.programacao,
  'modo dev': TelaJarvis.programacao,
  'arquivos': TelaJarvis.arquivos,
  'cadesimu': TelaJarvis.cadesimu,
  'cad': TelaJarvis.cadesimu,
  'simulador de circuitos': TelaJarvis.circuito,
  'simulador': TelaJarvis.circuito,
  'circuito': TelaJarvis.circuito,
  'projetista': TelaJarvis.projetista,
  'seguranca': TelaJarvis.seguranca,
  'bloqueio': TelaJarvis.seguranca,
  'personalizacao': TelaJarvis.personalizacao,
  'personalidade': TelaJarvis.personalizacao,
  'configuracoes': TelaJarvis.configuracoes,
  'configuracao': TelaJarvis.configuracoes,
  'ajustes': TelaJarvis.configuracoes,
  'habilidades': TelaJarvis.habilidades,
  'skills': TelaJarvis.habilidades,
  'gestos': TelaJarvis.gestos,
  'modo noturno': TelaJarvis.gestos,
  'perfis de timbre': TelaJarvis.timbre,
  'perfis de voz': TelaJarvis.timbre,
  'timbre': TelaJarvis.timbre,
  'voz externa': TelaJarvis.vozExterna,
  'fish audio': TelaJarvis.vozExterna,
  'fish': TelaJarvis.vozExterna,
  'provedores de ia': TelaJarvis.provedores,
  'provedores': TelaJarvis.provedores,
  'chaves': TelaJarvis.provedores,
  'historico': TelaJarvis.historico,
  'historico de voz': TelaJarvis.historicoVoz,
  'historico da voz': TelaJarvis.historicoVoz,
  'voz executada': TelaJarvis.historicoVoz,
  'backups': TelaJarvis.backups,
  'notas de backup': TelaJarvis.backups,
  'versoes antigas': TelaJarvis.backups,
  'regras do palco': TelaJarvis.regrasPalco,
  'regras': TelaJarvis.regrasPalco,
  'palavra de ativacao': TelaJarvis.ativacao,
  'palavra chave': TelaJarvis.ativacao,
  'ativacao': TelaJarvis.ativacao,
  'hotword': TelaJarvis.ativacao,
  'mapa da voz': TelaJarvis.mapaVoz,
  'telas por voz': TelaJarvis.mapaVoz,
  'comandos de voz': TelaJarvis.mapaVoz,
  'mapa dos comandos': TelaJarvis.mapaVoz,
  'aparelho conectado': TelaJarvis.aparelho,
  'aparelho': TelaJarvis.aparelho,
  'comandos do android': TelaJarvis.comandos,
  'comandos android': TelaJarvis.comandos,
  'comandos': TelaJarvis.comandos,
  'acessibilidade': TelaJarvis.acessibilidade,
  'central do aparelho': TelaJarvis.dispositivo,
  'dispositivo': TelaJarvis.dispositivo,
  'segundo plano': TelaJarvis.segundoPlano,
  'atualizacoes': TelaJarvis.atualizacoes,
  'atualizacao': TelaJarvis.atualizacoes,
  'avatar 3d': TelaJarvis.avatar,
  'avatar': TelaJarvis.avatar,
  'hermes': TelaJarvis.hermes,
  'agentes': TelaJarvis.agentes,
  'agente': TelaJarvis.agentes,
  'modelos locais': TelaJarvis.modelosLocais,
  'conversa': TelaJarvis.conversa,
  'chat': TelaJarvis.conversa,
  'modo voz': TelaJarvis.voz,
  'tela de voz': TelaJarvis.voz,
  'voz': TelaJarvis.voz,
};

/// Alias ordenados do mais longo para o mais curto (casamento determinístico).
final List<MapEntry<String, TelaJarvis>> _ordenados = () {
  final lista = _aliases.entries.toList();
  lista.sort((a, b) => b.key.length.compareTo(a.key.length));
  return lista;
}();

String _semAcento(String texto) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const para = 'aaaaaeeeeiiiiooooouuuuc';
  final saida = StringBuffer();
  for (final rune in texto.toLowerCase().runes) {
    final caractere = String.fromCharCode(rune);
    final indice = de.indexOf(caractere);
    saida.write(indice < 0 ? caractere : para[indice]);
  }
  return saida.toString();
}

String _limpar(String texto) =>
    _semAcento(texto).replaceAll(RegExp(r'\s+'), ' ').trim();

/// Verbos que pedem para abrir. "Chamar" fica de fora: é ligação.
final _verbo = RegExp(
    r'\b(abrir|abre|abra|abri|mostrar|mostra|mostre|exibir|exibe|exiba|'
    r'entrar em|entra em|entre em|ir para|vai para|va para|leva para|'
    r'levar para|leva me para)\b');

/// Pedido de mensagem: app de mensagem citado ou verbo de enviar. Tem o seu
/// próprio caminho e não pode abrir uma tela do JARVIS.
final _bloqueio = RegExp(
    r'\b(mensagem|whatsapp|whats|zap|wpp|telegram|gmail|e-mail|email|sms|'
    r'manda|mandar|mande|envia|enviar|envie|escreve|escrever)\b');

/// Pedido de ligação: "liga para a Ana" — não é abrir tela.
final _ligacao = RegExp(r'\b(liga|ligar|ligue|disca|discar)\s+(para|pra|pro|ao|a|o)\b');

String _tirarCortesia(String texto) => texto
    .replaceFirst(RegExp(r'^(?:jarvis|ei jarvis|oi jarvis)[\s,]*'), '')
    .replaceFirst(RegExp(r'^(?:por favor|pfv)[\s,]*'), '')
    .trim();

class PedidoAbrir {
  const PedidoAbrir(this.tela, {this.assunto = ''});

  final TelaJarvis tela;

  /// Assunto solto depois da tela (hoje só o palco usa, quando houver).
  final String assunto;

  String get resumo => 'abrir ${tela.rotulo}';

  /// Frase curta para o alto-falante, dita antes de a tela aparecer.
  String get fraseFalada => 'Abrindo ${tela.rotulo}.';
}

/// Interpreta o pedido de abrir uma tela do app; `null` quando não é isso.
PedidoAbrir? pedidoAbrir(String texto) {
  final original = texto.trim();
  final limpo = _tirarCortesia(_limpar(original));
  if (limpo.isEmpty) return null;
  // Pergunta nunca vira ação.
  if (RegExp(r'^(como|por que|porque|quando|quem|onde|qual|quais|o que)\b')
      .hasMatch(limpo)) {
    return null;
  }
  // Mensagem e ligação têm o seu próprio caminho: "abre o WhatsApp e manda
  // mensagem para as pessoas" não pode abrir a tela de Pessoas.
  if (_bloqueio.hasMatch(limpo) || _ligacao.hasMatch(limpo)) return null;

  final verbo = _verbo.firstMatch(limpo);
  // "modo visão" e o nome puro valem sem verbo; o resto precisa do verbo.
  final semVerbo = limpo.startsWith('modo ') ||
      _ordenados.any((e) => e.key == limpo);
  if (verbo == null && !semVerbo) return null;

  final inicio = verbo?.end ?? 0;
  for (final alias in _ordenados) {
    final achado = RegExp('\\b${RegExp.escape(alias.key)}\\b').firstMatch(limpo);
    if (achado == null || achado.start < inicio) continue;
    return PedidoAbrir(alias.value);
  }
  return null;
}
