/// Comandos de tela da automação por acessibilidade.
///
/// Este arquivo não depende de Flutter: o que o usuário pediu é interpretado e
/// o que foi lido é resumido aqui, com teste sem emulador. A execução nativa
/// fica em `services/acessibilidade_service.dart`.
///
/// Escopo estreito de propósito: ler, tocar e rolar. Nada de digitar.
library;

/// Um texto ou ação que a tela mostrou.
class ElementoDeTela {
  const ElementoDeTela({
    required this.texto,
    this.pacote = '',
    this.clicavel = false,
    this.rolavel = false,
    this.campo = false,
  });

  final String texto;
  final String pacote;
  final bool clicavel;
  final bool rolavel;

  /// Campo de texto: o conteúdo não vem do Android, só o rótulo fixo.
  final bool campo;

  static ElementoDeTela? deMapa(Map<Object?, Object?> mapa) {
    final texto = (mapa['texto'] as String?)?.trim() ?? '';
    if (texto.isEmpty) return null;
    return ElementoDeTela(
      texto: texto,
      pacote: (mapa['pacote'] as String?) ?? '',
      clicavel: mapa['clicavel'] == true,
      rolavel: mapa['rolavel'] == true,
      campo: mapa['campo'] == true,
    );
  }
}

sealed class ComandoDeTela {
  const ComandoDeTela();

  /// Texto curto do que foi pedido; vai para o histórico da tela.
  String get resumo;
}

class LerTela extends ComandoDeTela {
  const LerTela();
  @override
  String get resumo => 'ler a tela';
}

class TocarNaTela extends ComandoDeTela {
  const TocarNaTela(this.alvo);
  final String alvo;
  @override
  String get resumo => 'tocar em "$alvo"';
}

class RolarTela extends ComandoDeTela {
  const RolarTela({required this.paraCima});
  final bool paraCima;
  @override
  String get resumo => 'rolar a tela para ${paraCima ? 'cima' : 'baixo'}';
}

class PararAutomacao extends ComandoDeTela {
  const PararAutomacao();
  @override
  String get resumo => 'parar a automação de tela';
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

String _limpar(String texto) =>
    _semAcento(texto).replaceAll(RegExp(r'\s+'), ' ').trim();

class InterpretadorTela {
  const InterpretadorTela._();

  // Só com preposição: "toque de recolher" é conversa, não toque na tela.
  static final _toque = RegExp(
      r'\b(?:tocar|toca|toque|clicar|clica|clique)\s+'
      r'(?:em|no|na|nos|nas)\s+(.+)$',
      caseSensitive: false);
  static final _apertar = RegExp(
      r'\b(?:apertar|aperta|aperte)\s+(?:o|a|os|as|em|no|na)?\s*(.+)$',
      caseSensitive: false);
  static final _parar = RegExp(
      r'\b(?:parar|pare|interromper|interrompa|interrompe|cancelar|cancela|cancele)\b');
  static final _automacao = RegExp(r'\b(auto?macao|tela|toques?|acoes?)\b');
  static final _rolar =
      RegExp(r'\b(rolar|rola|role|descer|desce|desca|subir|sobe|suba|passar)\b');
  static final _cima =
      RegExp(r'\b(cima|acima|topo|inicio|subir|sobe|suba)\b');
  static final _baixo =
      RegExp(r'\b(baixo|abaixo|fim|descer|desce|desca)\b');
  static final _tela = RegExp(r'\btela\b');

  /// Devolve `null` quando o texto não é um pedido de tela e deve seguir para a
  /// conversa. Perguntas (“como…”, “por que…”) nunca viram ação.
  static ComandoDeTela? interpretar(String texto) {
    final original = texto.trim();
    final limpo = _limpar(original);
    if (limpo.isEmpty) return null;
    if (RegExp(r'^(como|por que|porque|quando|quem|onde)\b').hasMatch(limpo)) {
      return null;
    }

    if (_parar.hasMatch(limpo) && _automacao.hasMatch(limpo)) {
      return const PararAutomacao();
    }

    if (_tela.hasMatch(limpo) &&
        RegExp(r'^(ler|leia|le|descrever|descreva|mostrar|mostre|o que|quais)\b')
            .hasMatch(limpo)) {
      return const LerTela();
    }

    if (_rolar.hasMatch(limpo) && (_cima.hasMatch(limpo) != _baixo.hasMatch(limpo))) {
      return RolarTela(paraCima: _cima.hasMatch(limpo));
    }

    final toque = _toque.firstMatch(original) ?? _apertar.firstMatch(original);
    if (toque != null) {
      final alvo = toque
          .group(1)!
          .trim()
          .replaceAll(RegExp(r'^["“”\x27]+|["“”\x27.,!?;:]+$'), '')
          .trim();
      if (alvo.isEmpty || alvo.length > 80) return null;
      final alvoLimpo = _limpar(alvo);
      if (RegExp(r'^(botao|o botao|a tela|tela|ele|isso)$').hasMatch(alvoLimpo)) {
        return null;
      }
      return TocarNaTela(alvo);
    }
    return null;
  }
}

/// Decisão da conversa para um pedido de tela.
sealed class DecisaoDeTela {
  const DecisaoDeTela();
}

class SemTela extends DecisaoDeTela {
  const SemTela();
}

class ExecutarNaTela extends DecisaoDeTela {
  const ExecutarNaTela(this.comando);
  final ComandoDeTela comando;
}

/// Toque novo: nada acontece antes do “sim”.
class PedirConfirmacao extends DecisaoDeTela {
  const PedirConfirmacao(this.comando);
  final TocarNaTela comando;
}

class CancelarNaTela extends DecisaoDeTela {
  const CancelarNaTela();
}

/// Liga o interpretador de tela à conversa: decide quando perguntar, quando
/// executar e quando a resposta é só conversa.
class ConversaDeTela {
  const ConversaDeTela._();

  static final _sim = RegExp(
      r'^(sim|s|confirmo|confirma|confirmar|pode|pode tocar|claro|isso|manda|executa|ok|beleza)\b');
  static final _nao = RegExp(
      r'^(nao|n|cancela|cancelar|deixa|deixa pra la|nao quero|pare|para)\b');

  static DecisaoDeTela decidir(String texto, {TocarNaTela? pendente}) {
    final limpo = _limpar(texto);
    if (limpo.isEmpty) return const SemTela();
    if (pendente != null) {
      if (_sim.hasMatch(limpo)) return ExecutarNaTela(pendente);
      if (_nao.hasMatch(limpo)) return const CancelarNaTela();
    }
    final comando = InterpretadorTela.interpretar(texto);
    if (comando == null) return const SemTela();
    if (comando is TocarNaTela) return PedirConfirmacao(comando);
    return ExecutarNaTela(comando);
  }

  static String perguntaDeConfirmacao(TocarNaTela comando) =>
      'Posso tocar em "${comando.alvo}" na tela atual? Diga "sim" ou cancelar.';
}

/// Frase do que a leitura encontrou. Repetidos somem e o tamanho é limitado:
/// a tela fala em voz alta, não despeja a árvore inteira.
String resumoDaTela({
  required String pacote,
  required List<ElementoDeTela> elementos,
  bool limitado = false,
  int limiteDeNos = 120,
  int amostra = 6,
}) {
  if (elementos.isEmpty) {
    return 'Não encontrei texto legível nesta tela. '
        'Se o app estiver protegido contra captura, o Android não entrega o conteúdo.';
  }
  final vistos = <String>{};
  final textos = <String>[];
  for (final elemento in elementos) {
    final texto = elemento.texto.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (texto.isEmpty || !vistos.add(texto.toLowerCase())) continue;
    textos.add(texto.length > 40 ? '${texto.substring(0, 40)}…' : texto);
    if (textos.length >= amostra) break;
  }
  final onde = pacote.trim().isEmpty ? 'na tela atual' : 'em $pacote';
  final plural = elementos.length == 1 ? 'elemento' : 'elementos';
  final base = 'Li ${elementos.length} $plural $onde: ${textos.join(' · ')}.';
  if (!limitado) return base;
  return '$base A leitura parou no limite de $limiteDeNos elementos.';
}
