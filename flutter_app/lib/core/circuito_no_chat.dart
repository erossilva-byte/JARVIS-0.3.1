/// Circuito por prompt no caminho natural: a conversa.
///
/// O bloco 099 criou o projetista, mas ele só era alcançável por dentro do
/// módulo de CADeSIMU. Aqui fica a decisão que faltava: **este texto é um pedido
/// para montar um circuito?** Se for, a conversa monta e simula no aparelho —
/// sem provedor, sem chave, sem rede — e responde com o resultado. Se não for
/// (uma pergunta sobre eletrônica, um comando do Android, uma conversa), devolve
/// `null` e o fluxo segue como antes.
///
/// A regra é conservadora de propósito: pedir exige **verbo de montagem** e
/// **substantivo de circuito**, e pergunta pura (“o que é um resistor”) fica de
/// fora. Errar para o lado de não interceptar só devolve a resposta ao provedor;
/// errar para o outro lado engoliria uma pergunta legítima.
library;

import 'projetista.dart';
import 'texto_ptbr.dart';

/// Verbos que pedem a construção de alguma coisa.
const _verbosDeMontagem = r'(monta|monto|montamos|montar|monte|faz|faco|faca|fazer|'
    r'cria|crio|criar|crie|gera|gero|gerar|projeta|projetar|desenha|desenhar|'
    r'constroi|construir|elabora|preciso de|quero um|quero uma|me da um|me da uma)';

/// Substantivos que só aparecem quando o assunto é circuito.
const _substantivosDeCircuito = r'(circuito|esquema|diagrama|lampada|led|'
    r'resistor|divisor|partida direta|reversao|temporiza|contator|motor|'
    r'ligacao eletrica|fonte de tensao)';

/// Abertura de pergunta: nesse caso só intercepta com verbo imperativo claro.
const _aberturaDePergunta = r'^(o que|que e|explica|explicar|como|por que|'
    r'porque|qual|quais|quando|onde|quanto|quem)';

/// Verbos que, mesmo em pergunta, pedem execução (“como monto…”).
const _imperativos = r'(monta|monto|monte|montar|cria|crie|criar|faz|faca|'
    r'gerar|gera|desenha|projeta|constroi)';

/// Este texto pede para montar um circuito?
bool pedidoDeCircuito(String texto) {
  final normal = normalizarTexto(texto);
  if (normal.isEmpty) return false;
  if (!RegExp(_substantivosDeCircuito).hasMatch(normal)) return false;
  if (!RegExp(_verbosDeMontagem).hasMatch(normal)) return false;
  final pergunta = RegExp(_aberturaDePergunta).hasMatch(normal);
  if (pergunta && !RegExp(_imperativos).hasMatch(normal)) return false;
  return true;
}

/// Resposta local de um pedido de circuito — pronta para a conversa e para a
/// voz, sem markdown.
class RespostaCircuito {
  const RespostaCircuito({
    required this.ok,
    required this.projeto,
    required this.texto,
    required this.textoFalado,
  });

  final bool ok;
  final ResultadoProjeto projeto;

  /// Texto completo, para a bolha da conversa.
  final String texto;

  /// Versão curta e falável, para o alto-falante e o segundo plano.
  final String textoFalado;
}

/// Monta e simula o circuito do texto; `null` quando o texto não é um pedido.
///
/// O resultado nunca é `ok: true` sem simulação fechada: quem garante isso é
/// [montarProjetoDe], e esta função só transporta o veredito para a conversa.
RespostaCircuito? responderPedidoDeCircuito(String texto) {
  if (!pedidoDeCircuito(texto)) return null;
  final projeto = montarProjetoDe(texto);
  if (!projeto.ok) {
    final motivo = projeto.motivo.trim().isEmpty
        ? 'não consegui montar esse circuito.'
        : projeto.motivo.trim();
    return RespostaCircuito(
      ok: false,
      projeto: projeto,
      texto: 'Não montei o circuito. $motivo',
      textoFalado: 'Não montei esse circuito. $motivo',
    );
  }
  final circuito = projeto.circuito!;
  final simulacao = circuito.simular();
  final pot = _numero(simulacao.potenciaTotal);
  final aviso = projeto.avisos.isEmpty ? '' : ' ${projeto.avisos.first}';
  return RespostaCircuito(
    ok: true,
    projeto: projeto,
    texto: 'Montei o circuito “${projeto.titulo}”: '
        '${circuito.elementos.length} trechos, simulação fechada, $pot W no '
        'total. ${projeto.explicacao}$aviso Abra no simulador para ver o '
        'esquema.',
    textoFalado: 'Montei o circuito ${projeto.titulo}. Simulação fechada, '
        '$pot watts. Abra o simulador para ver o esquema.',
  );
}

/// Número curto para fala: uma casa decimal, sem zero sobrando.
String _numero(double valor) {
  final texto = valor.toStringAsFixed(1);
  return texto.endsWith('.0') ? texto.substring(0, texto.length - 2) : texto;
}
