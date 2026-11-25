/// Entender o nome do contato do jeito que ele é falado.
///
/// “Biaa🩵🩵” salvo no celular, “Bia” falado, “Beatriz” no documento;
/// “Murilo” salvo, “Murilin” falado. Esta regra normaliza o nome, expande
/// apelidos comuns do português e compara por semelhança, devolvendo um contato
/// só quando ele é o melhor — empate vira lista de candidatos, nunca palpite.
///
/// O Kotlin (`android/JarvisContatos.kt`) tem a mesma tabela e as mesmas notas,
/// porque é ele que resolve no segundo plano. O contrato do bloco cobra a
/// paridade, e os testes puros conferem o comportamento aqui.
library;

import 'aparelho.dart' show ContatoAparelho;

/// Nota mínima para um contato ser considerado parecido.
const notaMinimaContato = 0.55;

/// Dois contatos com notas a esta distância empatam e viram pergunta.
const empateContato = 0.02;

/// Apelidos comuns no Brasil: apelido → nomes que ele costuma abreviar.
const apelidosContato = <String, List<String>>{
  'bia': ['beatriz', 'bianca'],
  'bea': ['beatriz', 'beatrice'],
  'bibi': ['beatriz', 'bianca'],
  'ze': ['jose'],
  'zeca': ['jose'],
  'juca': ['jose', 'joaquim'],
  'ana': ['ana', 'anna', 'anne'],
  'ju': ['julia', 'juliana', 'juliane', 'julio'],
  'duda': ['eduarda', 'eduardo'],
  'du': ['eduarda', 'eduardo'],
  'manu': ['manuela', 'emanuelly', 'emanuelle'],
  'isa': ['isabela', 'isabel', 'isadora'],
  'bel': ['isabela', 'isabel'],
  'nanda': ['fernanda'],
  'fer': ['fernanda'],
  'fe': ['fernanda'],
  'vivi': ['viviane', 'vitoria'],
  'tati': ['tatiane', 'tatiana'],
  'tata': ['tatiane', 'tatiana'],
  'rafa': ['rafaela', 'rafael'],
  'fafa': ['fabiana', 'fabio'],
  'paty': ['patricia'],
  'pati': ['patricia'],
  'dri': ['adriana', 'adriane'],
  'cassi': ['cassia', 'cassiana'],
  'deby': ['debora'],
  'deborah': ['debora'],
  'lili': ['liliane', 'liliana'],
  'leo': ['leonardo', 'leonarda'],
  'digo': ['rodrigo'],
  'thi': ['thiago', 'tiago'],
  'tiago': ['thiago', 'tiago'],
  'mari': ['mariana', 'maria'],
  'mary': ['maria', 'mariana'],
  'kaka': ['carlos', 'carla'],
  'caca': ['carlos', 'carla'],
  'gabi': ['gabriela', 'gabriel'],
  'gab': ['gabriela', 'gabriel'],
  'gui': ['guilherme', 'guilhermina'],
  'vitor': ['vitor', 'victor'],
  'victor': ['vitor', 'victor'],
  'yuri': ['yuri'],
};

/// Palavras que decoram o nome salvo e não identificam ninguém.
const enfeitesContato = <String>{
  'tia', 'tio', 'dona', 'seu', 'sr', 'sra', 'dr', 'dra', 'amor',
  'amiga', 'amigo', 'mae', 'pai', 'filha', 'filho', 'irma', 'irmao',
  'trabalho', 'celular', 'whats', 'whatsapp', 'zap', 'pessoal',
  'fixo', 'casa', 'novo', 'nova',
};

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

/// Minúsculas, sem acento, sem emoji e sem letra repetida.
///
/// “Biaa🩵🩵” → “bia”; “Murilo” → “murilo”; “João!!! 🎉” → “joao”.
String normalizarNomeContato(String texto) {
  final limpo = _semAcento(texto)
      .replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final compacto = StringBuffer();
  String? anterior;
  for (final rune in limpo.runes) {
    final c = String.fromCharCode(rune);
    if (c == ' ' || c != anterior) compacto.write(c);
    anterior = c;
  }
  return compacto.toString().trim();
}

/// Nome completo, cada palavra, apelidos e a raiz sem a vogal final.
Set<String> variantesNome(String nome) {
  final base = normalizarNomeContato(nome);
  if (base.isEmpty) return const {};
  final saida = <String>{base};
  final palavras = base
      .split(' ')
      .where((p) => p.isNotEmpty && !enfeitesContato.contains(p))
      .toList();
  if (palavras.isEmpty) return saida;
  saida.add(palavras.join(' '));
  saida.add(palavras.first);
  for (final palavra in palavras) {
    saida.add(palavra);
    final raiz = _raiz(palavra);
    if (raiz != null) saida.add(raiz);
    final nomes = apelidosContato[palavra];
    if (nomes != null) saida.addAll(nomes);
    for (final entrada in apelidosContato.entries) {
      if (entrada.value.contains(palavra)) saida.add(entrada.key);
    }
  }
  return saida;
}

/// “Murilo” → “muril”, “Beatriz” → “beatri”: aproxima o diminutivo falado.
String? _raiz(String palavra) {
  var p = palavra;
  for (final sufixo in const ['zinho', 'zinha', 'inho', 'inha']) {
    if (p.length > sufixo.length + 2 && p.endsWith(sufixo)) {
      p = p.substring(0, p.length - sufixo.length);
    }
  }
  if (p.length >= 5 &&
      (p.endsWith('a') || p.endsWith('o') || p.endsWith('e'))) {
    return p.substring(0, p.length - 1);
  }
  return null;
}

/// Distância de edição, com teto para não gastar tempo em nomes enormes.
int distanciaEdicao(String a, String b) {
  if (a == b) return 0;
  final x = a.length > 40 ? a.substring(0, 40) : a;
  final y = b.length > 40 ? b.substring(0, 40) : b;
  var anterior = List<int>.generate(y.length + 1, (i) => i);
  var atual = List<int>.filled(y.length + 1, 0);
  for (var i = 1; i <= x.length; i++) {
    atual[0] = i;
    for (var j = 1; j <= y.length; j++) {
      final custo = x[i - 1] == y[j - 1] ? 0 : 1;
      final apagar = atual[j - 1] + 1;
      final inserir = anterior[j] + 1;
      final trocar = anterior[j - 1] + custo;
      atual[j] = apagar < inserir
          ? (apagar < trocar ? apagar : trocar)
          : (inserir < trocar ? inserir : trocar);
    }
    final troca = anterior;
    anterior = atual;
    atual = troca;
  }
  return anterior[y.length];
}

double _comparar(String a, String b) {
  if (a == b) return 1.0;
  if (a.length < 3 || b.length < 3) return 0.0;
  if (b.startsWith(a)) return 0.90;
  if (a.startsWith(b)) return 0.88;
  if (RegExp(r'\b' + RegExp.escape(a) + r'\b').hasMatch(b)) return 0.85;
  final distancia = distanciaEdicao(a, b);
  final maior = a.length > b.length ? a.length : b.length;
  final limite = maior <= 4 ? 1 : (maior <= 7 ? 2 : 3);
  if (distancia > limite) return 0.0;
  final base = 0.78 - distancia * 0.06;
  return a[0] == b[0] ? base : base - 0.12;
}

/// Nota de 0 a 1 entre o nome falado e o nome salvo.
double semelhancaNome(String dito, String salvo) {
  final alvos = variantesNome(dito);
  final nomes = variantesNome(salvo);
  var melhor = 0.0;
  for (final a in alvos) {
    for (final n in nomes) {
      final nota = _comparar(a, n);
      if (nota > melhor) melhor = nota;
    }
  }
  return melhor;
}

/// Resultado do entendimento: um contato certo ou os candidatos empatados.
class EscolhaContato {
  const EscolhaContato({this.contato, this.candidatos = const []});

  final ContatoAparelho? contato;
  final List<ContatoAparelho> candidatos;

  bool get ambiguo => contato == null && candidatos.length > 1;
}

/// Escolhe o contato do nome falado; empate devolve os candidatos.
EscolhaContato escolherContato(
  String dito,
  List<ContatoAparelho> contatos,
) {
  final alvo = normalizarNomeContato(dito);
  if (alvo.isEmpty || contatos.isEmpty) return const EscolhaContato();
  final notas = contatos
      .map((c) => MapEntry(c, semelhancaNome(alvo, c.nome)))
      .where((e) => e.value >= notaMinimaContato)
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (notas.isEmpty) return const EscolhaContato();

  final melhor = notas.first.value;
  var empatados = notas.where((e) => melhor - e.value <= empateContato).toList();
  if (empatados.length > 1) {
    final primeiro = normalizarNomeContato(empatados.first.key.nome);
    final todosComPrefixo = empatados.every((e) {
      final outro = normalizarNomeContato(e.key.nome);
      return outro.startsWith(primeiro) || primeiro.startsWith(outro);
    });
    if (todosComPrefixo) {
      empatados.sort((a, b) => a.key.nome.length.compareTo(b.key.nome.length));
      empatados = [empatados.first];
    } else {
      return EscolhaContato(
          candidatos: empatados.take(5).map((e) => e.key).toList());
    }
  }
  return EscolhaContato(contato: empatados.first.key);
}

/// Lista os contatos do mais parecido com o nome falado para o menos parecido.
List<ContatoAparelho> ordenarContatosPorNome(
  String dito,
  List<ContatoAparelho> contatos,
) {
  final alvo = normalizarNomeContato(dito);
  if (alvo.isEmpty) return contatos;
  final comNota = contatos
      .map((c) => MapEntry(c, semelhancaNome(alvo, c.nome)))
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return comNota.map((e) => e.key).toList();
}
