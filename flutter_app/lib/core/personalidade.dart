/// Personalidade e humor do J.A.R.V.I.S. na interface Flutter.
///
/// Núcleo puro, sem Flutter: o nível escolhido vira regras de prompt e, quando cabe, um ângulo de
/// humor. O humor é sempre com a situação — nunca com a pessoa — e desaparece em assunto sensível.
/// Não há fala pronta obrigatória nem imitação de filmes: o modelo recebe o estilo, não um roteiro.
library;

enum NivelHumor { discreto, equilibrado, avancado }

extension NivelHumorDados on NivelHumor {
  String get rotulo => switch (this) {
        NivelHumor.discreto => 'Discreto',
        NivelHumor.equilibrado => 'Equilibrado',
        NivelHumor.avancado => 'Avançado',
      };

  int get intensidade => switch (this) {
        NivelHumor.discreto => 35,
        NivelHumor.equilibrado => 65,
        NivelHumor.avancado => 90,
      };

  String get descricao => switch (this) {
        NivelHumor.discreto => 'Cordial, elegante e direto. Sem piadas, ironia ou sarcasmo.',
        NivelHumor.equilibrado => 'Ironia fina de vez em quando, sempre depois da informação.',
        NivelHumor.avancado => 'Sarcasmo seco e deboche leve com frequência — nunca em assunto sensível.',
      };
}

NivelHumor nivelHumorDe(String? nome) {
  for (final nivel in NivelHumor.values) {
    if (nivel.name == nome) return nivel;
  }
  return NivelHumor.equilibrado;
}

class Personalidade {
  const Personalidade({this.nivel = NivelHumor.equilibrado});

  final NivelHumor nivel;

  bool get humorLigado => nivel.intensidade >= 50;

  Personalidade comNivel(NivelHumor novo) => Personalidade(nivel: novo);

  Map<String, Object?> paraJson() => {'nivel': nivel.name};

  static Personalidade deJson(Object? bruto) {
    if (bruto is! Map) return const Personalidade();
    final nome = bruto['nivel'];
    return Personalidade(nivel: nivelHumorDe(nome is String ? nome : null));
  }
}

enum TomDoTurno { comum, comPressa, sensivel }

const _mapaAcentos = <String, String>{
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c',
};

String _semAcento(String texto) {
  var saida = texto.toLowerCase();
  _mapaAcentos.forEach((letra, sem) => saida = saida.replaceAll(letra, sem));
  return saida;
}

bool _contem(String texto, String termo) => RegExp(
      r'(^|[^a-z0-9])' + RegExp.escape(termo) + r'($|[^a-z0-9])',
    ).hasMatch(texto);

/// Assunto em que o humor é suspenso por completo, mesmo no nível Avançado.
const termosSensiveis = <String>[
  'emergencia', 'socorro', 'acidente', 'infarto', 'avc', 'dor no peito', 'sangramento',
  'sangrando', 'suicidio', 'morreu', 'morte', 'luto', 'faleceu', 'estupro', 'assedio',
  'violencia', 'ameaca', 'golpe', 'fraude', 'perdi o dinheiro', 'perdi meu dinheiro',
  'perdi o emprego', 'demitido', 'cancer', 'diagnostico', 'hospital', 'medicamento',
  'ansiedade', 'depressao', 'deprimido', 'cirurgia', 'utc',
];

const _termosPressa = <String>[
  'pressa', 'urgente', 'urgencia', 'rapido', 'depressa', 'correndo', 'prazo',
  'agora mesmo', 'o mais rapido', 'em cinco minutos',
];

TomDoTurno tomDoTurno(String texto) {
  final alvo = ' ${_semAcento(texto)} ';
  for (final termo in termosSensiveis) {
    if (_contem(alvo, termo)) return TomDoTurno.sensivel;
  }
  for (final termo in _termosPressa) {
    if (_contem(alvo, termo)) return TomDoTurno.comPressa;
  }
  return TomDoTurno.comum;
}

const _banco = <String, List<String>>{
  'saudacao': [
    'Sistemas operacionais e disposição em níveis suspeitos. Vamos ver quanto tempo isso dura.',
    'Saudações. Já conferi o básico: tudo vivo, algumas coisas apenas fingindo melhor que as outras.',
  ],
  'bug': [
    'O computador decidiu contemplar a vida entre um clique e outro. Vou interromper a meditação.',
    'Encontrei o culpado: estava escondido atrás de uma suposição muito confiante.',
  ],
  'codigo': [
    'Vou ler cada linha com o respeito que ela conquistou — ou não.',
    'Se houver um comentário “não mexa aqui”, já sei por onde começar.',
  ],
  'arquivo': [
    'Recebido. Vou ler com atenção, diferente de quem só abre a primeira página.',
    'Vamos ver o que há aqui dentro. Prometo não julgar a estrutura antes do terceiro arquivo.',
  ],
  'agradecimento': [
    'Sempre à disposição. Impedir algumas decisões questionáveis faz parte do serviço.',
    'De nada. Considero isso um investimento na minha própria tranquilidade.',
  ],
  'geral': [
    'Certo. Vamos transformar esse caos em algo minimamente apresentável.',
    'Considere o assunto sob nova administração.',
  ],
};

String _temaDe(String texto) {
  if (RegExp(r'^(bom dia|boa tarde|boa noite|ola|oi|e ai|tudo bem)').hasMatch(texto)) return 'saudacao';
  if (_contem(texto, 'obrigado') || _contem(texto, 'obrigada') || _contem(texto, 'valeu')) {
    return 'agradecimento';
  }
  if (RegExp(r'(arquivo|pdf|docx|xlsx|zip|planilha|documento)').hasMatch(texto)) return 'arquivo';
  if (RegExp(r'(codigo|programa|funcao|classe|java|python|javascript|compil|refator)').hasMatch(texto)) {
    return 'codigo';
  }
  if (RegExp(r'(bug|erro|falha|lento|travou|travando|nao funciona|parou|crash)').hasMatch(texto)) {
    return 'bug';
  }
  return 'geral';
}

int _hash(String texto) {
  var valor = 2166136261;
  for (final unidade in texto.codeUnits) {
    valor ^= unidade;
    valor = (valor * 16777619) & 0xFFFFFFFF;
  }
  return valor;
}

/// Ângulo de humor para o turno, ou nulo quando não cabe.
///
/// O modelo deve adaptar — nunca copiar — e [recentes] evita repetir a mesma construção na
/// conversa. Assunto sensível e nível Discreto não recebem sugestão.
String? sugerirAngulo(
  Personalidade personalidade,
  String texto, {
  List<String> recentes = const [],
  int semente = 0,
}) {
  if (!personalidade.humorLigado || texto.trim().isEmpty) return null;
  final normalizado = _semAcento(texto);
  if (tomDoTurno(texto) == TomDoTurno.sensivel) return null;
  final lista = [...(_banco[_temaDe(normalizado)] ?? const <String>[]), ..._banco['geral']!];
  final inicio = _hash('$normalizado|$semente') % lista.length;
  for (var i = 0; i < lista.length; i++) {
    final linha = lista[(inicio + i) % lista.length];
    if (!recentes.contains(linha)) return linha;
  }
  return null;
}

class EstiloDoTurno {
  const EstiloDoTurno({required this.prompt, required this.tom, this.angulo});

  final String prompt;
  final TomDoTurno tom;
  final String? angulo;
}

/// Monta o bloco de personalidade que entra no prompt, já ajustado ao tom do turno.
EstiloDoTurno estiloDoTurno(
  Personalidade personalidade,
  String texto, {
  List<String> recentes = const [],
  int semente = 0,
}) {
  final tom = tomDoTurno(texto);
  final nivel = personalidade.nivel;
  final regras = StringBuffer();

  if (nivel == NivelHumor.discreto) {
    regras.write(
      'PERSONALIDADE: elegância, competência e opinião própria, mas sem piadas, ironia ou '
      'sarcasmo neste nível. A informação vem primeiro e a resposta não abre com “Claro!”, '
      '“Entendido.” ou “Como posso ajudar?” isolados.',
    );
  } else {
    regras.write(
      'PERSONALIDADE OBRIGATÓRIA — não é um extra opcional. Toda resposta deve soar como o '
      'J.A.R.V.I.S.: inteligente, elegante, autoconfiante, leal e espirituoso. O humor vem do '
      'modo de comentar a situação, integrado à explicação, e não de uma piada colada no fim. ',
    );
    regras.write(nivel == NivelHumor.avancado
        ? 'Sarcasmo seco e deboche leve com frequência, variando o alvo: a situação, o problema, '
            'o acaso ou o próprio assistente. '
        : 'Ironia fina e ocasional, sem transformar toda resposta em número de comédia. ');
    regras.write(
      'Proibido abrir com “Claro!”, “Entendido.”, “Com certeza!” ou “Como posso ajudar?” '
      'isolados: comece já com conteúdo ou com uma observação afiada. Nunca repita a mesma piada '
      'ou construção na mesma conversa. A informação vem antes da graça. Piada é sempre com a '
      'situação — nunca com a pessoa, aparência, religião, tragédia ou erro dela. ',
    );
  }

  regras.write(
    'Nunca finja ter executado algo nem alegue acesso ao aparelho que as ferramentas não '
    'oferecem. Não copie falas, bordões ou diálogos de filmes; use apenas o arquétipo de '
    'assistente sofisticado.',
  );

  if (tom == TomDoTurno.sensivel) {
    regras.write(
      ' TOM DO TURNO: assunto sensível ou urgente (saúde, luto, violência, segurança ou dinheiro '
      'perdido). Humor zero: clareza, empatia e precisão primeiro. Não faça piada, ironia ou '
      'sarcasmo, nem para aliviar o clima.',
    );
  } else if (tom == TomDoTurno.comPressa) {
    regras.write(
      ' TOM DO TURNO: o usuário tem pressa. Vá direto ao ponto e economize palavras; no máximo '
      'uma observação curta, e só se não atrasar a resposta.',
    );
  }

  final angulo = sugerirAngulo(personalidade, texto, recentes: recentes, semente: semente);
  if (angulo != null && tom == TomDoTurno.comum) {
    regras.write(
      ' Ângulo de humor possível para este turno (adapte ao contexto; não copie literalmente e '
      'ignore se soar forçado): "$angulo"',
    );
  }

  return EstiloDoTurno(prompt: regras.toString(), tom: tom, angulo: angulo);
}
