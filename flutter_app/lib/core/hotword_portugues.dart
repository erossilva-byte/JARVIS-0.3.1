/// Palavras que acordam o JARVIS em português do Brasil.
///
/// O detector acústico (sherpa-onnx KWS) é treinado em inglês e trabalha com
/// tokens BPE, não com letras: cada palavra precisa chegar ao motor já
/// tokenizada, exatamente como `preparar_kws.py` gerou o `keywords.txt` dos
/// assets. Esta tabela é a fonte única das frases em português; o contrato
/// `tests/test_hotword_portugues.py` e o teste
/// `test/hotword_portugues_test.dart` conferem os tokens contra o
/// `tokens.txt` que vai no APK.
///
/// Nada aqui promete acerto: o modelo continua sendo inglês. As frases de duas
/// palavras (“Ei Jarvis”) dão mais evidência acústica para quem chama em
/// português, mas só o seu aparelho e a sua voz dizem se funcionam.
class VarianteHotword {
  const VarianteHotword({
    required this.id,
    required this.frase,
    required this.tokens,
    required this.dica,
    required this.grupo,
    this.padrao = false,
  });

  /// Identificador estável, gravado nas preferências.
  final String id;

  /// Como a frase é escrita para a pessoa ler.
  final String frase;

  /// Linha tokenizada entregue ao detector.
  final String tokens;

  /// Como falar, em letras comuns.
  final String dica;

  /// Grupo da tela: nome, tratamento ou apelido.
  final String grupo;

  /// Ligada de fábrica. Só as que já existiam continuam ligadas: mudar o
  /// conjunto padrão mexeria na escuta de quem já usa o app.
  final bool padrao;
}

class HotwordPortugues {
  const HotwordPortugues._();

  static const grupoNome = 'nome';
  static const grupoTratamento = 'tratamento';
  static const grupoApelido = 'apelido';

  static const Map<String, String> grupos = {
    grupoNome: 'O nome',
    grupoTratamento: 'Chamando com tratamento',
    grupoApelido: 'Apelidos que o modelo já aceitava',
  };

  /// Frases aceitas, na ordem em que aparecem na tela.
  ///
  /// Os tokens precisam existir no `tokens.txt` do modelo GigaSpeech; “▁” marca
  /// o começo de uma palavra.
  static const List<VarianteHotword> variantes = <VarianteHotword>[
    VarianteHotword(
      id: 'jarvis',
      frase: 'Jarvis',
      tokens: '▁JA R VI S',
      dica: '“DJÁR-vis”, com o J puxado para o “dj”',
      grupo: grupoNome,
      padrao: true,
    ),
    VarianteHotword(
      id: 'javis',
      frase: 'Javis',
      tokens: '▁JA VI S',
      dica: '“DJÁ-vis”, sem o R',
      grupo: grupoNome,
      padrao: true,
    ),
    VarianteHotword(
      id: 'jarvi',
      frase: 'Jarvi',
      tokens: '▁JA R VI',
      dica: '“DJÁR-vi”, sem o S final',
      grupo: grupoNome,
      padrao: true,
    ),
    VarianteHotword(
      id: 'jarve',
      frase: 'Jarve',
      tokens: '▁JA R VE',
      dica: '“DJÁR-ve”, com E no fim',
      grupo: grupoNome,
      padrao: true,
    ),
    VarianteHotword(
      id: 'jarviz',
      frase: 'Jarviz',
      tokens: '▁JA R VI Z',
      dica: '“DJÁR-vis” com Z',
      grupo: grupoNome,
      padrao: true,
    ),
    VarianteHotword(
      id: 'jarves',
      frase: 'Jarves',
      tokens: '▁JA R VE S',
      dica: '“DJÁR-ves”',
      grupo: grupoNome,
      padrao: true,
    ),
    VarianteHotword(
      id: 'javi',
      frase: 'Javi',
      tokens: '▁JA VI',
      dica: '“DJÁ-vi”',
      grupo: grupoNome,
      padrao: true,
    ),
    VarianteHotword(
      id: 'javali',
      frase: 'Javali',
      tokens: '▁JA V AL I',
      dica: '“ja-va-LI”',
      grupo: grupoNome,
      padrao: true,
    ),
    VarianteHotword(
      id: 'charles',
      frase: 'Charles',
      tokens: '▁CHA R LES',
      dica: '“TCHÁR-les”',
      grupo: grupoApelido,
      padrao: true,
    ),
    VarianteHotword(
      id: 'chales',
      frase: 'Chales',
      tokens: '▁CHA LES',
      dica: '“TCHÁ-les”',
      grupo: grupoApelido,
      padrao: true,
    ),
    VarianteHotword(
      id: 'chale',
      frase: 'Chale',
      tokens: '▁CHA LE',
      dica: '“TCHÁ-le”',
      grupo: grupoApelido,
      padrao: true,
    ),
    VarianteHotword(
      id: 'ei-jarvis',
      frase: 'Ei Jarvis',
      tokens: '▁E I ▁JA R VI S',
      dica: '“ei djár-vis”, as duas palavras seguidas',
      grupo: grupoTratamento,
    ),
    VarianteHotword(
      id: 'oi-jarvis',
      frase: 'Oi Jarvis',
      tokens: '▁O I ▁JA R VI S',
      dica: '“oi djár-vis”',
      grupo: grupoTratamento,
    ),
    VarianteHotword(
      id: 'alo-jarvis',
      frase: 'Alô Jarvis',
      tokens: '▁A LO ▁JA R VI S',
      dica: '“a-lô djár-vis”',
      grupo: grupoTratamento,
    ),
    VarianteHotword(
      id: 'ola-jarvis',
      frase: 'Olá Jarvis',
      tokens: '▁O LA ▁JA R VI S',
      dica: '“o-lá djár-vis”',
      grupo: grupoTratamento,
    ),
  ];

  /// Quantas frases o detector aceita ao mesmo tempo.
  ///
  /// Cada palavra extra custa CPU e abre espaço para disparo por engano; o
  /// limite é o mesmo do laço que monta a lista no motor.
  static const int limite = 16;

  static VarianteHotword? porId(String id) {
    for (final variante in variantes) {
      if (variante.id == id) return variante;
    }
    return null;
  }

  /// Seleção de fábrica: só as frases que já existiam.
  static Set<String> get idsPadrao =>
      {for (final variante in variantes) if (variante.padrao) variante.id};

  /// Descarta identificadores desconhecidos e respeita [limite].
  static Set<String> seguras(Iterable<String> ids) {
    final validos = <String>{};
    for (final id in ids) {
      if (porId(id) != null) validos.add(id);
      if (validos.length >= limite) break;
    }
    return validos;
  }

  static List<VarianteHotword> ativas(Set<String> ids) =>
      [for (final variante in variantes) if (ids.contains(variante.id)) variante];

  /// Linhas tokenizadas na ordem da tabela, sem repetição.
  static List<String> linhas(Set<String> ids) {
    final vistas = <String>{};
    final saida = <String>[];
    for (final variante in ativas(ids)) {
      if (vistas.add(variante.tokens)) saida.add(variante.tokens);
    }
    return saida;
  }

  /// Letras da frase, sem o marcador de palavra do BPE.
  static String letras(String tokens) =>
      tokens.replaceAll('▁', '').replaceAll(RegExp(r'\s+'), '').toUpperCase();

  /// Converte o que o detector devolveu (tokens ou palavra) no nome legível.
  ///
  /// O sherpa entrega a linha tokenizada; testes e versões antigas entregam a
  /// palavra. Quando nada casa, devolve o texto original sem inventar.
  static String nomeAmigavel(String ouvido) {
    final bruto = ouvido.trim();
    if (bruto.isEmpty) return '';
    final chave = letras(bruto.replaceAll(RegExp(r'[^A-Za-z▁\s]'), ''));
    for (final variante in variantes) {
      if (letras(variante.tokens) == chave) return variante.frase;
    }
    return bruto.replaceAll('▁', '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Resumo curto da seleção, para a tela e o diagnóstico.
  static String resumo(Set<String> ids) {
    final lista = ativas(ids).map((v) => v.frase).toList();
    if (lista.isEmpty) return 'nenhuma frase ligada';
    return lista.join(', ');
  }
}
