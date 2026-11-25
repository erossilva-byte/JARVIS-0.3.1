/// O mapa da voz: o que o JARVIS abre e faz quando você fala.
///
/// Sai da mesma tabela que o app usa para abrir as telas, então não há lista
/// paralela para envelhecer: acrescentar uma tela em `TelaJarvis` já a coloca
/// aqui. A pergunta “quais telas você abre?” é respondida no aparelho, sem
/// provedor de IA.
library;

import 'pedido_abrir.dart';

class CategoriaDaVoz {
  const CategoriaDaVoz(this.titulo, this.itens, {this.nota = ''});

  final String titulo;
  final List<String> itens;

  /// Frase que explica o alcance da categoria.
  final String nota;
}

/// Caminhos que não são tela do app, mas respondem por voz.
const _outrosCaminhos = <String>[
  'abre o WhatsApp na conversa da Ana',
  'abre o Gmail para escrever para a Ana',
  'abre o mapa até a Rua das Flores',
  'abre o YouTube e pesquisa gatos',
  'manda mensagem para o Murilo no WhatsApp dizendo que chego às 9',
  'liga para a Ana',
  'o apelido do Murilo é Murilin',
  'lanterna, volume, alarme e abrir app pelo nome',
  'toca Legião Urbana no Spotify',
  'mostra fotos de gatos',
  'abre a câmera e fala o que você vê',
  'ativa o núcleo flutuante',
  'lê a tela e toca em Enviar por mim',
];

/// Catálogo completo, pronto para a tela do mapa da voz.
List<CategoriaDaVoz> mapaDaVoz() {
  final telas = [
    for (final tela in TelaJarvis.values) 'abre ${tela.rotulo}',
  ];
  return [
    CategoriaDaVoz(
      'Telas do JARVIS',
      telas,
      nota: '${telas.length} telas abrem pelo nome, com o app aberto ou fechado.',
    ),
    CategoriaDaVoz(
      'Apps, mensagens e aparelho',
      _outrosCaminhos,
      nota: 'Abrir app já na ação, mensagem, ligação, música e comandos do '
          'celular. Apelido de contato também se ensina falando.',
    ),
  ];
}

/// Quantas telas o mapa cobre hoje.
int get totalDeTelasPorVoz => TelaJarvis.values.length;

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

String _limpo(String texto) =>
    _semAcento(texto).replaceAll(RegExp(r'\s+'), ' ').trim();

final _pedeLista = RegExp(
    r'\b(quais|que|lista|listar|mostra|mostrar|mostre|ver|existe|existem)\b');
final _assunto = RegExp(r'\b(tela|telas|comando|comandos|voz|fala|funcao|funcoes)\b');

/// Resposta falada para “quais telas você abre?”; `null` quando não é pergunta
/// de mapa.
String? respostaMapaDaVoz(String texto) {
  final limpo = _limpo(texto);
  if (limpo.isEmpty) return null;
  // “abre o mapa da voz” é comando de abrir tela, não pergunta.
  if (RegExp(r'^\s*(abre|abrir|exibe|exibir|mostra|mostrar)\b').hasMatch(limpo) &&
      limpo.contains('mapa da voz')) {
    return null;
  }
  if (!_pedeLista.hasMatch(limpo) || !_assunto.hasMatch(limpo)) return null;
  if (limpo.contains('como ') && !limpo.contains('quais')) return null;
  return 'Consigo abrir $totalDeTelasPorVoz telas por voz, de “abre a memória” a '
      '“abre as configurações”. Também abro apps já na conversa, mando mensagem, '
      'ligo, controlo música e o aparelho, e aprendo apelido de contato. '
      'Para ver a lista completa, diga: abre o mapa da voz.';
}
