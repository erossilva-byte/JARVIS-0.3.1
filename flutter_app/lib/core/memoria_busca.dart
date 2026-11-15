import 'dart:math' as math;

import 'memoria.dart';

/// Busca lexical determinística no cofre local.
///
/// Não é embedding neural: cada termo (e seus trigramas) é projetado num vetor de 128 dimensões
/// por hash FNV-1a. O resultado é reprodutível e não depende de rede, mas entende pouco de
/// paráfrase — por isso o motivo do resultado é sempre mostrado, em vez de fingir compreensão.

const _semAcento = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
};

const _vazias = {
  'a', 'o', 'as', 'os', 'um', 'uma', 'de', 'da', 'do', 'das', 'dos', 'em', 'no', 'na', 'nos',
  'nas', 'por', 'para', 'com', 'que', 'e', 'ou', 'se', 'ao', 'aos', 'ja', 'foi', 'ser', 'sua',
  'seu', 'mais', 'como', 'mas', 'nao', 'meu', 'minha', 'ele', 'ela', 'isso', 'este', 'esta',
};

/// Sinônimos fechados, em português. Não é um tesauro: só evita que a mesma ideia escrita com
/// outra palavra comum escape da busca.
const _grupos = <String, String>{
  'programa': 'software', 'codigo': 'software', 'aplicativo': 'software', 'app': 'software',
  'casa': 'moradia', 'residencia': 'moradia', 'apartamento': 'moradia',
  'carro': 'veiculo', 'automovel': 'veiculo', 'moto': 'veiculo',
  'trabalho': 'servico', 'emprego': 'servico',
  'remedio': 'medicamento', 'medicamentos': 'medicamento',
  'treino': 'exercicio', 'academia': 'exercicio',
  'filho': 'familia', 'filha': 'familia', 'esposa': 'familia', 'marido': 'familia',
};

String normalizar(String texto) {
  final buffer = StringBuffer();
  for (final rune in texto.toLowerCase().runes) {
    final caractere = String.fromCharCode(rune);
    final trocado = _semAcento[caractere] ?? caractere;
    final ehLetraOuNumero = RegExp(r'[a-z0-9]').hasMatch(trocado);
    buffer.write(ehLetraOuNumero ? trocado : ' ');
  }
  return buffer.toString().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).join(' ');
}

List<String> termosDe(String texto) {
  final base = normalizar(texto).split(' ').where((t) => t.length > 2 && !_vazias.contains(t)).toList();
  final expandidos = <String>{};
  for (final termo in base) {
    final grupo = _grupos[termo];
    expandidos.add(grupo ?? termo);
  }
  return expandidos.toList()..sort();
}

int _fnv1a(String texto) {
  var hash = 0x811c9dc5;
  for (final unidade in texto.codeUnits) {
    hash ^= unidade;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}

const _dimensoes = 128;

List<double> embedding(String texto) {
  final vetor = List<double>.filled(_dimensoes, 0);
  for (final termo in termosDe(texto)) {
    vetor[_fnv1a(termo) % _dimensoes] += 1;
    final marcado = '^$termo\$';
    for (var i = 0; i + 3 <= marcado.length; i++) {
      vetor[_fnv1a(marcado.substring(i, i + 3)) % _dimensoes] += 0.5;
    }
  }
  final norma = math.sqrt(vetor.fold<double>(0, (soma, valor) => soma + valor * valor));
  if (norma == 0) return vetor;
  return vetor.map((valor) => valor / norma).toList();
}

double cosseno(List<double> a, List<double> b) {
  var soma = 0.0;
  for (var i = 0; i < _dimensoes; i++) {
    soma += a[i] * b[i];
  }
  return soma.clamp(-1.0, 1.0);
}

class ResultadoMemoria {
  const ResultadoMemoria({required this.nota, required this.pontuacao, required this.cosseno, required this.motivo});

  final NotaMemoria nota;
  final double pontuacao;
  final double cosseno;
  final String motivo;
}

/// Resultado da montagem do bloco de contexto enviado à IA.
class ContextoMemoria {
  const ContextoMemoria({required this.texto, required this.usados, required this.caracteres});

  final String texto;
  final List<NotaMemoria> usados;
  final int caracteres;

  bool get vazio => texto.isEmpty;
}

double _literal(NotaMemoria nota, List<String> termos, Set<String> encontrados) {
  if (termos.isEmpty) return 0;
  final titulo = normalizar(nota.titulo);
  final tags = normalizar(nota.tags.join(' '));
  final corpo = normalizar(nota.texto);
  var pontos = 0.0;
  for (final termo in termos) {
    if (titulo.contains(termo)) {
      pontos += 1;
      encontrados.add('título');
    } else if (tags.contains(termo)) {
      pontos += 0.6;
      encontrados.add('tag');
    } else if (corpo.contains(termo)) {
      pontos += 0.25;
      encontrados.add('texto');
    }
  }
  return (pontos / termos.length).clamp(0, 1).toDouble();
}

double _recencia(DateTime atualizada, DateTime agora) {
  final dias = agora.difference(atualizada).inHours / 24;
  if (dias <= 0) return 1;
  return (1 - dias / 30).clamp(0, 1).toDouble();
}

String _motivo(Set<String> encontrados, NotaMemoria nota, DateTime agora, double recencia, bool aceitaPelaSimilaridade) {
  final partes = <String>[];
  if (encontrados.contains('título')) partes.add('título contém o termo');
  if (encontrados.contains('tag')) partes.add('tag correspondente');
  if (encontrados.contains('texto')) partes.add('texto contém o termo');
  if (aceitaPelaSimilaridade) partes.add('termos parecidos');
  if (nota.importancia >= 2) partes.add('marcada como importante');
  if (agora.difference(nota.atualizadaEm).inDays <= 3) partes.add('atualizada há pouco');
  if (nota.usos > 0) partes.add('já usada ${nota.usos}x');
  return partes.isEmpty ? 'nota recente' : partes.join(' · ');
}

/// Ordena as notas por relevância para [consulta].
///
/// Notas sem nenhuma palavra em comum só entram com similaridade alta; um corte relativo impede
/// que uma nota forte arraste notas fracas para o prompt.
List<ResultadoMemoria> buscarNotas(
  List<NotaMemoria> notas,
  String consulta, {
  int limite = 8,
  DateTime? agora,
}) {
  final quando = agora ?? DateTime.now();
  final termos = termosDe(consulta);
  if (termos.isEmpty) {
    return notas
        .map((nota) => ResultadoMemoria(
              nota: nota,
              pontuacao: 1,
              cosseno: 1,
              motivo: 'lista, sem consulta',
            ))
        .take(limite)
        .toList();
  }

  final alvo = embedding(consulta);
  final resultados = <ResultadoMemoria>[];
  for (final nota in notas) {
    final vetor = embedding('${nota.titulo} ${nota.tags.join(' ')} ${nota.texto}');
    final similaridade = cosseno(alvo, vetor);
    final encontrados = <String>{};
    final literal = _literal(nota, termos, encontrados);
    if (literal == 0 && similaridade < 0.10) continue;
    final recente = _recencia(nota.atualizadaEm, quando);
    final uso = (nota.usos / 10).clamp(0, 1).toDouble();
    final pontuacao = (0.50 * similaridade) +
        (0.28 * literal) +
        (0.07 * (nota.importancia / 3)) +
        (0.10 * recente) +
        (0.05 * uso);
    resultados.add(ResultadoMemoria(
      nota: nota,
      pontuacao: pontuacao,
      cosseno: similaridade,
      motivo: _motivo(encontrados, nota, quando, recente, literal == 0 && similaridade >= 0.10),
    ));
  }

  resultados.sort((a, b) => b.pontuacao.compareTo(a.pontuacao));
  if (resultados.isEmpty) return [];
  final melhor = resultados.first.pontuacao;
  final fortes = resultados
      .where((r) => r.pontuacao >= melhor * 0.5 || r.cosseno >= 0.35)
      .take(limite)
      .toList();
  return fortes;
}

/// Monta o bloco de contexto com orçamento de caracteres e devolve quais notas foram usadas.
///
/// Sem resultado relevante, devolve vazio: nada de mandar o cofre inteiro nem “notas recentes”
/// que não têm relação com a pergunta.
ContextoMemoria contextoRelevante(
  List<NotaMemoria> notas,
  String consulta, {
  int orcamento = 1800,
  int limite = 3,
  DateTime? agora,
}) {
  if (consulta.trim().isEmpty || notas.isEmpty) {
    return const ContextoMemoria(texto: '', usados: [], caracteres: 0);
  }
  final achados = buscarNotas(notas, consulta, limite: limite, agora: agora);
  if (achados.isEmpty) {
    return const ContextoMemoria(texto: '', usados: [], caracteres: 0);
  }
  final partes = <String>[];
  final usados = <NotaMemoria>[];
  var total = 0;
  for (final achado in achados) {
    final tema = temasMemoria[achado.nota.tema] ?? achado.nota.tema;
    final corpo = achado.nota.texto.trim().replaceAll(RegExp(r'\n{3,}'), '\n\n');
    final trecho = corpo.length > 500 ? '${corpo.substring(0, 500)}…' : corpo;
    final bloco = '### ${achado.nota.titulo} ($tema)\n$trecho';
    if (total + bloco.length > orcamento && usados.isNotEmpty) break;
    if (bloco.length > orcamento) {
      partes.add('### ${achado.nota.titulo} ($tema)\n${trecho.substring(0, math.max(0, orcamento - 60))}…');
      usados.add(achado.nota);
      total = orcamento;
      break;
    }
    partes.add(bloco);
    usados.add(achado.nota);
    total += bloco.length + 2;
  }
  final texto = partes.join('\n\n');
  return ContextoMemoria(texto: texto, usados: usados, caracteres: texto.length);
}

/// Instrução enviada junto das notas. Diz o que fazer quando as notas não bastarem, em vez de
/// induzir a IA a completar lacuna com invenção.
const instrucaoMemoria = 'Notas do cofre local relevantes para este pedido. Use quando ajudarem e '
    'diga quando não bastarem; não invente o que não está nelas.';

/// Monta a lista de mensagens do provedor: notas relevantes como mensagem de sistema, depois o
/// histórico. Sem contexto, devolve o histórico intacto.
List<Map<String, String>> montarMensagens(
  List<Map<String, String>> historico,
  ContextoMemoria contexto, {
  String? pessoas,
  String? personalidade,
}) =>
    [
      if (personalidade != null && personalidade.trim().isNotEmpty)
        {'role': 'system', 'content': personalidade},
      if (!contexto.vazio) {'role': 'system', 'content': '$instrucaoMemoria\n\n${contexto.texto}'},
      if (pessoas != null && pessoas.trim().isNotEmpty) {'role': 'system', 'content': pessoas},
      ...historico,
    ];

/// Trecho curto para mostrar na lista de resultados, com o termo em destaque visual simples.
String trecho(NotaMemoria nota, {int limite = 120}) {
  final limpo = nota.texto.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (limpo.length <= limite) return limpo;
  return '${limpo.substring(0, limite)}…';
}
