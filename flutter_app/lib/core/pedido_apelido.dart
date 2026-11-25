/// Ensinar e esquecer um apelido de contato pela fala.
///
/// “O apelido do Murilo é Murilin”, “chama o Murilo de Murilin”, “conhece o
/// Murilo como Murilin” e “esquece o apelido Murilin”. A regra só reconhece
/// frases com marcador explícito (“apelido”, “chama… de”, “conhece… como”):
/// “o céu é azul” não pode virar apelido de ninguém.
///
/// Quem grava é o Android (`JarvisContatos`), que guarda o par no aparelho; a
/// mesma frase é reconhecida no serviço de segundo plano.
library;

class PedidoApelido {
  const PedidoApelido({
    required this.apelido,
    this.nome = '',
    this.esquecer = false,
  });

  /// Como a pessoa é chamada (“Murilin”).
  final String apelido;

  /// Nome salvo na agenda (“Murilo”); vazio ao esquecer.
  final String nome;

  final bool esquecer;

  String get resumo => esquecer
      ? 'esquecer o apelido $apelido'
      : 'apelido de $nome: $apelido';

  String get fraseFalada => esquecer
      ? 'Apelido $apelido esquecido. Quando você falar $apelido, volto a '
          'procurar na agenda.'
      : 'Pronto. Quando você falar $apelido, eu entendo $nome.';
}

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

/// Versão sem acento e em minúsculas, com o mesmo comprimento do original.
String _base(String texto) => _semAcento(texto);

String _limpar(String texto) => texto
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp(r'^[\s,.;:]+|[\s,.;:]+$'), '')
    .trim();

final _pergunta = RegExp(r'^(como|por que|porque|quando|quem|onde|qual|quais|o que)\b');

/// “esquece o apelido Murilin”, “apaga o apelido de Murilin”.
final _esquecer = RegExp(
    r'\b(esquece|esquecer|esqueca|apaga|apagar|remove|remover|tira|tirar)\b'
    r'\s+(?:o\s+|a\s+)?apelido\s*(?:de|do|da)?\s*(.+)$');

/// “o apelido do Murilo é Murilin”, “apelido de Murilo: Murilin”.
final _porApelido = RegExp(
    r'^(?:o\s+|a\s+)?apelido\s+(?:de|do|da)\s+(.+?)\s*(?:e|eh|:|=)\s*(.+)$');

/// “chama o Murilo de Murilin”, “pode chamar o Murilo de Murilin”.
final _chamar = RegExp(
    r'^(?:pode\s+)?(?:chama|chamar|chame)\s+(?:o\s+|a\s+)?(.+?)\s+de\s+(.+)$');

/// “conhece o Murilo como Murilin”.
final _conhecer = RegExp(
    r'^(?:conhece|conhecer)\s+(?:o\s+|a\s+)?(.+?)\s+como\s+(.+)$');

final _cortesia = RegExp(
    r'^(?:(?:ei|oi)?\s*jarvis|por favor|pfv)[\s,]*');

/// Interpreta o pedido de apelido; `null` quando a frase é outra coisa.
///
/// O casamento acontece na versão sem acento, que tem o mesmo comprimento do
/// texto original — assim o nome e o apelido saem com acento e maiúscula como
/// foram falados.
PedidoApelido? pedidoApelido(String texto) {
  final original = texto.trim();
  if (original.isEmpty) return null;
  final base = _base(original);
  var inicio = 0;
  final cortesia = _cortesia.firstMatch(base);
  if (cortesia != null) inicio = cortesia.end;
  final resto = base.substring(inicio);
  if (resto.trim().isEmpty) return null;
  if (_pergunta.hasMatch(resto.trim())) return null;

  final esquece = _esquecer.firstMatch(resto);
  if (esquece != null) {
    // Grupo 1 é o verbo (esquece/apaga/remove); o apelido é o grupo 2.
    final apelido = _grupo(original, inicio, esquece, 2);
    if (apelido.isEmpty) return null;
    return PedidoApelido(apelido: apelido, esquecer: true);
  }

  for (final padrao in [_porApelido, _chamar, _conhecer]) {
    final achado = padrao.firstMatch(resto);
    if (achado == null) continue;
    final nome = _grupo(original, inicio, achado, 1);
    // “chama o Murilo de Murilin” pode vir com aspas.
    final apelido = _grupo(original, inicio, achado, 2)
        .replaceAll(RegExp('["“”\'`]'), '')
        .trim();
    if (nome.isEmpty || apelido.isEmpty) return null;
    return PedidoApelido(apelido: apelido, nome: nome);
  }
  return null;
}

/// Texto do grupo [indice] no original, preservando acento e maiúscula.
///
/// O casamento acontece na versão sem acento, que tem o mesmo comprimento do
/// original; por isso o deslocamento encontrado vale no texto original.
String _grupo(String original, int inicio, RegExpMatch achado, int indice) {
  final parte = achado.group(indice);
  if (parte == null || parte.isEmpty) return '';
  final completo = achado.group(0) ?? parte;
  final deslocamento = completo.indexOf(parte);
  if (deslocamento < 0) return _limpar(parte);
  final inicioTrecho = inicio + achado.start + deslocamento;
  final fim = inicioTrecho + parte.length;
  if (fim > original.length) return _limpar(parte);
  return _limpar(original.substring(inicioTrecho, fim));
}
