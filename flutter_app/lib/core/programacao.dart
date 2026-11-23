/// Modo programação — o contrato puro, sem Flutter e sem rede.
///
/// O modo cobre o que dá para provar sem terminal: criar, analisar, modificar e
/// explicar código, montar um prompt de pedido e guardar o resultado como texto.
/// O que ele **não** faz é executar, compilar ou testar: este APK não tem
/// sandbox nem permissão para rodar programas, e o código que aparece vem do
/// provedor de IA configurado, não de uma verificação local.
library;

/// O que a pessoa quer fazer com o código.
enum TarefaCodigo {
  criar('Criar código', 'Descreva o que o programa deve fazer.'),
  analisar('Analisar código', 'Cole o código: aponto riscos e o que falta.'),
  modificar('Modificar código', 'Diga o que mudar; o código atual vai junto.'),
  explicarErro('Explicar erro', 'Cole o código e a mensagem de erro.'),
  prompt('Prompt de código', 'Monte um pedido pronto para outra IA.');

  const TarefaCodigo(this.rotulo, this.descricao);

  final String rotulo;
  final String descricao;

  /// A tarefa precisa do código na área de código.
  bool get usaCodigo =>
      this == TarefaCodigo.analisar ||
      this == TarefaCodigo.modificar ||
      this == TarefaCodigo.explicarErro;

  /// A tarefa precisa da mensagem de erro do compilador/interpretador.
  bool get usaErro => this == TarefaCodigo.explicarErro;

  /// A tarefa monta um prompt local, sem chamar o provedor.
  bool get geraPrompt => this == TarefaCodigo.prompt;

  /// A tarefa exige dizer o que se quer, além do código.
  bool get exigePedido =>
      this == TarefaCodigo.criar || this == TarefaCodigo.modificar;
}

/// Uma linguagem da lista: o nome mostrado, a extensão do arquivo e a etiqueta
/// da cerca de código no pedido ao provedor.
class LinguagemCodigo {
  const LinguagemCodigo(this.id, this.nome, this.extensao, this.cerca);

  final String id;
  final String nome;
  final String extensao;
  final String cerca;
}

const linguagensCodigo = <LinguagemCodigo>[
  LinguagemCodigo('dart', 'Dart / Flutter', 'dart', 'dart'),
  LinguagemCodigo('python', 'Python', 'py', 'python'),
  LinguagemCodigo('javascript', 'JavaScript', 'js', 'javascript'),
  LinguagemCodigo('typescript', 'TypeScript', 'ts', 'typescript'),
  LinguagemCodigo('kotlin', 'Kotlin', 'kt', 'kotlin'),
  LinguagemCodigo('java', 'Java', 'java', 'java'),
  LinguagemCodigo('c', 'C', 'c', 'c'),
  LinguagemCodigo('cpp', 'C++', 'cpp', 'cpp'),
  LinguagemCodigo('csharp', 'C#', 'cs', 'csharp'),
  LinguagemCodigo('go', 'Go', 'go', 'go'),
  LinguagemCodigo('rust', 'Rust', 'rs', 'rust'),
  LinguagemCodigo('php', 'PHP', 'php', 'php'),
  LinguagemCodigo('html', 'HTML', 'html', 'html'),
  LinguagemCodigo('css', 'CSS', 'css', 'css'),
  LinguagemCodigo('sql', 'SQL', 'sql', 'sql'),
  LinguagemCodigo('bash', 'Bash', 'sh', 'bash'),
  LinguagemCodigo('outro', 'Outra / não sei', 'txt', ''),
];

/// Linguagem pelo id; id desconhecido devolve a última entrada ("outra").
LinguagemCodigo linguagemDe(String id) {
  for (final linguagem in linguagensCodigo) {
    if (linguagem.id == id) return linguagem;
  }
  return linguagensCodigo.last;
}

/// Limite de código enviado no pedido, em caracteres.
///
/// É um teto de contexto e de custo: acima disso o provedor trunca ou recusa, e
/// a tela prefere dizer o limite a mandar um pedaço pela metade.
const limiteCodigoCaracteres = 20000;

/// Um pedido do modo programação, como a pessoa preencheu.
class PedidoCodigo {
  const PedidoCodigo({
    required this.tarefa,
    required this.linguagem,
    this.pedido = '',
    this.codigo = '',
    this.erro = '',
  });

  final TarefaCodigo tarefa;
  final LinguagemCodigo linguagem;

  /// O que se quer, em texto livre.
  final String pedido;

  /// Código colado na área de código.
  final String codigo;

  /// Mensagem de erro, quando a tarefa é explicar erro.
  final String erro;

  int get linhasDeCodigo {
    final limpo = codigo.trim();
    return limpo.isEmpty ? 0 : limpo.split('\n').length;
  }

  int get caracteresDeCodigo => codigo.length;
}

/// Recusa com o motivo, ou `null` quando o pedido pode seguir.
String? validarPedidoCodigo(PedidoCodigo pedido) {
  if (pedido.codigo.length > limiteCodigoCaracteres) {
    return 'O código tem ${pedido.codigo.length} caracteres; o limite do '
        'pedido é $limiteCodigoCaracteres. Envie um trecho menor.';
  }
  if (pedido.tarefa.geraPrompt) {
    if (pedido.pedido.trim().length < 4) {
      return 'Descreva o objetivo do código para montar o prompt.';
    }
    return null;
  }
  if (pedido.tarefa.usaCodigo && pedido.codigo.trim().isEmpty) {
    return 'Cole o código na área de código — ${pedido.tarefa.rotulo.toLowerCase()} '
        'precisa dele.';
  }
  if (pedido.tarefa.usaErro && pedido.erro.trim().isEmpty) {
    return 'Cole a mensagem de erro que apareceu. Sem ela, só posso adivinhar.';
  }
  if (pedido.tarefa.exigePedido && pedido.pedido.trim().length < 4) {
    return 'Descreva o que o código deve fazer (ou o que deve mudar).';
  }
  return null;
}

const _baseSistema = 'Você é o JARVIS no modo programação. Responda em português '
    'do Brasil, direto, sem elogio e sem introdução. Entregue o código em um '
    'bloco cercado por três crases, com a linguagem na primeira linha. Não '
    'diga que executou, testou, compilou ou rodou nada: você não tem terminal '
    'nem sandbox, e quem cola o código num aparelho é a pessoa. Se faltar '
    'informação, faça a pergunta antes de inventar API, biblioteca ou versão. '
    'Quando houver risco de segurança, diga o risco em uma frase.';

/// Instrução de sistema para o pedido — específica por tarefa.
String instrucaoProgramacao(TarefaCodigo tarefa, LinguagemCodigo linguagem) {
  final alvo = linguagem.id == 'outro'
      ? 'na linguagem que a pessoa indicar'
      : 'em ${linguagem.nome}';
  final especifica = switch (tarefa) {
    TarefaCodigo.criar => 'Escreva o código $alvo, completo e executável. '
        'Comece por uma frase dizendo o que o programa faz, depois o bloco de '
        'código, e por último o que a pessoa deve conferir antes de usar.',
    TarefaCodigo.analisar => 'Analise o código $alvo sem reescrevê-lo inteiro. '
        'Aponte, em ordem de gravidade: o que quebra, o que está frágil e o '
        'que falta tratar. Cite a linha ou o trecho de cada achado. Se o '
        'código estiver correto, diga isso e o que ele não cobre.',
    TarefaCodigo.modificar => 'Modifique o código $alvo conforme o pedido. '
        'Devolva o arquivo inteiro no bloco de código, não um diff por '
        'palavras, e liste logo abaixo o que mudou e o que continua igual. '
        'Se o pedido for ambíguo, pergunte antes de mudar.',
    TarefaCodigo.explicarErro => 'Explique o erro $alvo em três partes: o que a '
        'mensagem significa, por que o código a produziu e a correção mínima. '
        'Mostre a correção em bloco de código. Se a mensagem não bastar para '
        'saber a causa, diga o que falta verificar em vez de adivinhar.',
    TarefaCodigo.prompt => 'Monte um prompt de pedido de código, claro e '
        'completo, para outra IA ou para você mesmo. Entregue só o prompt, '
        'pronto para copiar, sem comentário em volta.',
  };
  return '$_baseSistema\n\n$especifica';
}

/// Mensagens prontas para o provedor de IA.
List<Map<String, String>> mensagensDeCodigo(
  PedidoCodigo pedido, {
  String personalidade = '',
}) {
  final sistema = [
    if (personalidade.trim().isNotEmpty) personalidade.trim(),
    instrucaoProgramacao(pedido.tarefa, pedido.linguagem),
  ].join('\n\n');

  final partes = <String>[
    'Tarefa: ${pedido.tarefa.rotulo}.',
    if (pedido.linguagem.id != 'outro')
      'Linguagem: ${pedido.linguagem.nome}.'
    else
      'Linguagem: não informada; pergunte se for necessário.',
    if (pedido.pedido.trim().isNotEmpty) 'Pedido: ${pedido.pedido.trim()}.',
  ];

  final codigo = pedido.codigo.trim();
  if (codigo.isNotEmpty) {
    final cerca = pedido.linguagem.cerca;
    partes.add('Código atual:\n```$cerca\n$codigo\n```');
  }
  if (pedido.erro.trim().isNotEmpty) {
    partes.add('Mensagem de erro:\n```\n${pedido.erro.trim()}\n```');
  }
  partes.add('Responda em português do Brasil e não afirme ter executado nada.');

  return [
    {'role': 'system', 'content': sistema},
    {'role': 'user', 'content': partes.join('\n\n')},
  ];
}

/// Um bloco de código encontrado na resposta do provedor.
class BlocoCodigo {
  const BlocoCodigo({required this.linguagem, required this.codigo});

  final String linguagem;
  final String codigo;

  int get linhas => codigo.split('\n').length;
}

final _blocoCompleto =
    RegExp(r'```([A-Za-z0-9+#._-]*)[ \t]*\r?\n([\s\S]*?)```');

/// Extrai os blocos cercados por três crases, na ordem em que aparecem.
///
/// Um bloco sem fechamento (resposta cortada) ainda é extraído até o fim do
/// texto: é melhor entregar o que veio do que esconder o código.
List<BlocoCodigo> extrairBlocos(String texto) {
  final blocos = <BlocoCodigo>[];
  for (final achado in _blocoCompleto.allMatches(texto)) {
    final codigo = (achado.group(2) ?? '').trimRight();
    if (codigo.trim().isEmpty) continue;
    blocos.add(BlocoCodigo(
      linguagem: (achado.group(1) ?? '').toLowerCase(),
      codigo: codigo,
    ));
  }
  if (blocos.isNotEmpty) return blocos;

  final abre = RegExp(r'```([A-Za-z0-9+#._-]*)[ \t]*\r?\n').firstMatch(texto);
  if (abre != null) {
    final codigo = texto.substring(abre.end).replaceAll('```', '').trimRight();
    if (codigo.trim().isNotEmpty) {
      blocos.add(BlocoCodigo(
        linguagem: (abre.group(1) ?? '').toLowerCase(),
        codigo: codigo,
      ));
    }
  }
  return blocos;
}

/// O texto da resposta sem os blocos de código — a explicação.
String explicacaoSemCodigo(String resposta) => resposta
    .replaceAll(_blocoCompleto, ' ')
    .replaceAll('```', ' ')
    .replaceAll(RegExp(r'[ \t]+\n'), '\n')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

/// O que vai para a área de código: o primeiro bloco, ou a resposta inteira
/// quando não há bloco (explicação, prompt).
String codigoParaArea(String resposta) {
  final blocos = extrairBlocos(resposta);
  return blocos.isEmpty ? resposta.trim() : blocos.first.codigo;
}

/// Nome livre na pasta isolada, sem extensão: a pasta acrescenta `.txt`.
///
/// `existentes` são os nomes já usados, com ou sem `.txt`; o sufixo numérico
/// evita sobrescrever um arquivo anterior.
String nomeArquivoDeCodigo(
  LinguagemCodigo linguagem, {
  Iterable<String> existentes = const [],
}) {
  final usados = existentes
      .map((nome) => nome.toLowerCase().replaceFirst(RegExp(r'\.txt$'), ''))
      .toSet();
  final base = 'codigo_${linguagem.id}';
  if (!usados.contains(base)) return base;
  for (var i = 2; i < 100; i++) {
    final candidato = '${base}_$i';
    if (!usados.contains(candidato)) return candidato;
  }
  return '${base}_${DateTime.now().millisecondsSinceEpoch}';
}

/// Prompt pronto de pedido de código — montado no aparelho, sem provedor.
String promptDeCodigo(
  LinguagemCodigo linguagem,
  String objetivo, {
  String restricoes = '',
  String contexto = '',
}) {
  final alvo = linguagem.id == 'outro' ? 'na linguagem adequada' : 'em ${linguagem.nome}';
  final linhas = <String>[
    'Escreva código $alvo.',
    '',
    'Objetivo: ${objetivo.trim()}',
    if (restricoes.trim().isNotEmpty) 'Restrições: ${restricoes.trim()}',
    if (contexto.trim().isNotEmpty) 'Contexto: ${contexto.trim()}',
    '',
    'Formato da resposta:',
    '1. Uma frase dizendo o que o código faz.',
    '2. O código completo em um bloco cercado por três crases.',
    '3. O que devo conferir antes de usar.',
    '',
    'Regras: português do Brasil; sem dependência que eu não tenha pedido; '
        'trate os casos de erro; não diga que executou ou testou o código.',
  ];
  return linhas.join('\n');
}

/// O que este modo não faz. Fica escrito na tela, não só no relatório.
const limitesProgramacao = <String>[
  'Nada é executado, compilado ou testado aqui: não há sandbox, terminal nem '
      'permissão para rodar programas neste APK.',
  'O código vem do provedor de IA configurado. Ele pode estar errado, '
      'desatualizado ou usar biblioteca que você não tem — conferir é seu passo.',
  'Sem chave de provedor, a análise não acontece; a tela diz isso em vez de '
      'inventar resposta. O prompt de código é montado no aparelho e funciona '
      'sem chave.',
  'O texto do pedido e o código colado saem do aparelho para o provedor '
      'escolhido. Não cole segredo, chave ou dado de outra pessoa.',
  'Salvar grava um arquivo de texto (.txt) na pasta isolada do app, em '
      'Arquivos. O arquivo não vira programa instalável.',
];
