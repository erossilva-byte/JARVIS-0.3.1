/// Normalização de texto em português — sem Flutter, sem dependência.
///
/// Dart não traz normalização Unicode na biblioteca padrão, então a tabela é
/// explícita. Ela serve para casar “elétrica” com “eletrica” e “reversão” com
/// “reversao” nas regras de agente e no projetista.
library;

const _comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇñÑ';
const _semAcento = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUCnN';

/// Texto sem acento, preservando maiúsculas e pontuação.
String semAcentoTexto(String texto) {
  final saida = StringBuffer();
  for (final rune in texto.runes) {
    final caractere = String.fromCharCode(rune);
    final posicao = _comAcento.indexOf(caractere);
    saida.write(posicao >= 0 ? _semAcento[posicao] : caractere);
  }
  return saida.toString();
}

/// Texto pronto para casar regra: sem acento, minúsculo, pontuação simples
/// removida e espaços colapsados. Números e vírgula decimal continuam.
String normalizarTexto(String texto) {
  return semAcentoTexto(texto)
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 :,.]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Primeiro número do texto (aceita vírgula decimal); nulo quando não há.
double? primeiroNumero(String texto) {
  final achado = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(texto);
  if (achado == null) return null;
  return double.tryParse(achado.group(1)!.replaceAll(',', '.'));
}
