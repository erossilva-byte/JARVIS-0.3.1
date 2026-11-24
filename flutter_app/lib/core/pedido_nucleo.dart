/// Pedido de núcleo flutuante — regra pura, sem Flutter e sem Android.
///
/// "Ativa o núcleo" e "desativa o núcleo" mudam a bolha que fica por cima dos
/// outros apps (`JarvisNucleo`). Sem esta regra o texto cairia no comando de
/// abrir app e o JARVIS procuraria um aplicativo chamado "núcleo".
///
/// Devolve `true` para ativar, `false` para desativar e `null` quando o texto
/// não fala do núcleo — a conversa normal continua.
library;

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

final _desligar = RegExp(
    r'\b(desativar|desativa|desative|fechar|fecha|feche|desligar|desliga|desligue|'
    r'esconder|esconde|esconda|tirar|tira|retirar|retira|parar|para|pare)\b');

final _ligar = RegExp(
    r'\b(ativar|ativa|ative|ligar|liga|ligue|abrir|abre|abra|mostrar|mostra|'
    r'mostre|chamar|chama|chame|aparecer|aparece|flutuar|flutuante)\b');

/// Interpreta o pedido de núcleo; `null` quando não é sobre ele.
bool? pedidoNucleo(String texto) {
  final limpo = _limpar(texto);
  if (limpo.isEmpty) return null;
  if (!RegExp(r'\bnucleo\b').hasMatch(limpo)) return null;
  // Perguntas nunca viram ação ("como ativo o núcleo?").
  if (RegExp(r'^(como|por que|porque|quando|quem|onde)\b').hasMatch(limpo)) {
    return null;
  }
  if (_desligar.hasMatch(limpo)) return false;
  if (_ligar.hasMatch(limpo)) return true;
  // Só "o núcleo": alterna, como a lanterna.
  if (RegExp(r'^(o |meu )?nucleo( flutuante)?$').hasMatch(limpo)) return true;
  return null;
}
