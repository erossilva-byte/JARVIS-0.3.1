/// Habilidades em Markdown: procedimentos que o usuário escreve e o JARVIS
/// carrega do próprio aparelho.
///
/// Cada habilidade é um arquivo `.md` dentro de uma pasta de habilidades
/// (`Skills/`, `Habilidades/` ou a pasta local do app). O cabeçalho opcional
/// (frontmatter) traz o nome, a descrição e os gatilhos; o corpo é o passo a
/// passo. Nada de código: o texto entra no pedido ao provedor de IA como
/// instrução, e só quando a pergunta casa com os gatilhos.
library;

import 'memoria.dart';

/// Pastas reconhecidas como pasta de habilidades, em qualquer nível do cofre.
const pastasHabilidades = <String>[
  'skills',
  'habilidades',
  'habilidade',
];

/// Limites para o pedido não crescer sem controle.
const limiteHabilidades = 24;
const limiteInstrucoes = 2400;
const limiteBlocoHabilidades = 4000;

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

/// O caminho está dentro de uma pasta de habilidades?
///
/// Vale para `Skills/revisar-texto.md` e para `Projetos/Skills/fechar-mes.md`;
/// um arquivo solto na raiz do cofre não é habilidade.
bool caminhoDeHabilidade(String caminho) {
  final partes = caminho
      .replaceAll('\\', '/')
      .split('/')
      .where((parte) => parte.trim().isNotEmpty)
      .toList();
  if (partes.length < 2) return false;
  return partes
      .take(partes.length - 1)
      .any((pasta) => pastasHabilidades.contains(pasta.toLowerCase().trim()));
}

/// Uma habilidade lida do aparelho.
class Habilidade {
  const Habilidade({
    required this.nome,
    required this.instrucoes,
    this.descricao = '',
    this.gatilhos = const [],
    this.origem = '',
  });

  final String nome;
  final String instrucoes;
  final String descricao;

  /// Frases ou palavras que fazem esta habilidade entrar na conversa.
  final List<String> gatilhos;

  /// Caminho relativo de onde ela veio, para a tela mostrar a origem.
  final String origem;
}

/// Lê um Markdown de habilidade. Devolve `null` quando não há passo a passo.
Habilidade? lerHabilidade(String bruto, {required String origem}) {
  if (bruto.trim().isEmpty) return null;
  final lido = lerMarkdown(bruto, tituloReserva: _tituloDoCaminho(origem));
  final extras = lido.extras;
  String extra(List<String> chaves) {
    for (final chave in chaves) {
      final valor = extras[chave];
      if (valor != null && valor.trim().isNotEmpty) return valor.trim();
    }
    return '';
  }

  final nome = extra(const ['nome', 'titulo', 'title', 'name']);
  final descricao = extra(const ['descricao', 'description', 'resumo']);
  final gatilhos = _listaDeGatilhos(
      extra(const ['gatilhos', 'triggers', 'quando', 'para']));
  final instrucoes = lido.texto.trim();
  if (instrucoes.isEmpty) return null;
  final nomeFinal = nome.isNotEmpty ? nome : lido.titulo;
  if (nomeFinal.trim().isEmpty) return null;
  return Habilidade(
    nome: nomeFinal,
    instrucoes: instrucoes.length <= limiteInstrucoes
        ? instrucoes
        : '${instrucoes.substring(0, limiteInstrucoes).trimRight()}…',
    descricao: descricao,
    gatilhos: gatilhos,
    origem: origem,
  );
}

String _tituloDoCaminho(String origem) {
  final arquivo = origem.split('/').last;
  final semExtensao = arquivo.replaceAll(RegExp(r'\.md$', caseSensitive: false), '');
  final limpo = semExtensao.replaceAll(RegExp(r'[-_]+'), ' ').trim();
  return limpo.isEmpty ? 'Habilidade' : limpo;
}

List<String> _listaDeGatilhos(String bruto) {
  if (bruto.trim().isEmpty) return const [];
  final gatilhos = bruto
      .split(RegExp(r'[,;\n]'))
      .map((item) => item.replaceAll(RegExp(r'^[-*+]\s*'), '').trim())
      .where((item) => item.isNotEmpty)
      .map((item) => item.length <= 60 ? item : item.substring(0, 60))
      .toList();
  return gatilhos.take(12).toList();
}

/// Monta as habilidades a partir dos arquivos lidos do cofre.
///
/// Arquivo fora das pastas de habilidades é ignorado; nome repetido mantém o
/// primeiro (o cofre entrega em ordem de pasta) para o mesmo procedimento não
/// entrar duas vezes no pedido.
List<Habilidade> habilidadesDosArquivos(
    List<({String caminho, String conteudo})> arquivos) {
  final habilidades = <Habilidade>[];
  final vistos = <String>{};
  for (final arquivo in arquivos) {
    if (!caminhoDeHabilidade(arquivo.caminho)) continue;
    final habilidade =
        lerHabilidade(arquivo.conteudo, origem: arquivo.caminho);
    if (habilidade == null) continue;
    final chave = _limpo(habilidade.nome);
    if (!vistos.add(chave)) continue;
    habilidades.add(habilidade);
    if (habilidades.length >= limiteHabilidades) break;
  }
  return habilidades;
}

/// Habilidades que casam com a pergunta.
///
/// Casa quando o gatilho aparece na pergunta (sem acento e sem caixa) ou quando
/// uma palavra significativa do nome aparece. Pergunta vazia não ativa nada.
List<Habilidade> habilidadesQueCasam(
  List<Habilidade> habilidades,
  String pergunta, {
  int limite = 2,
}) {
  final texto = _limpo(pergunta);
  if (texto.isEmpty || habilidades.isEmpty) return const [];
  final achadas = <Habilidade>[];
  for (final habilidade in habilidades) {
    final gatilhos = habilidade.gatilhos.isEmpty
        ? const <String>[]
        : habilidade.gatilhos;
    final porGatilho = gatilhos.any((gatilho) {
      final alvo = _limpo(gatilho);
      return alvo.length >= 3 && texto.contains(alvo);
    });
    final porNome = habilidade.nome
        .split(RegExp(r'[^0-9A-Za-zÀ-ÿ]+'))
        .map(_limpo)
        .where((palavra) => palavra.length >= 4)
        .any(texto.contains);
    if (porGatilho || porNome) achadas.add(habilidade);
    if (achadas.length >= limite) break;
  }
  return achadas;
}

/// Bloco de instruções enviado ao provedor junto da pergunta.
///
/// Devolve texto vazio quando não há habilidade casando: nada de gastar cota
/// com um bloco que não se aplica.
String blocoHabilidades(List<Habilidade> habilidades) {
  if (habilidades.isEmpty) return '';
  final partes = <String>[
    'O usuário escreveu os procedimentos abaixo e quer que você os siga.',
    'Use somente os que se aplicam ao pedido; se nenhum servir, ignore o bloco.',
    'Quando seguir um deles, comece a resposta dizendo o nome da habilidade.',
  ];
  for (final habilidade in habilidades) {
    final linhas = <String>[
      '## ${habilidade.nome}',
      if (habilidade.descricao.isNotEmpty) habilidade.descricao,
      if (habilidade.gatilhos.isNotEmpty)
        'Quando: ${habilidade.gatilhos.join('; ')}',
      'Passos:',
      habilidade.instrucoes,
    ];
    partes.add(linhas.join('\n'));
  }
  final bloco = partes.join('\n\n').trim();
  return bloco.length <= limiteBlocoHabilidades
      ? bloco
      : '${bloco.substring(0, limiteBlocoHabilidades).trimRight()}…';
}

/// Modelo de habilidade para o botão "Criar exemplo".
const exemploHabilidade = '''---
nome: Revisar texto
descricao: Corrige e encurta textos sem mudar o sentido.
gatilhos: revisar texto, corrigir texto, deixar mais claro
---

1. Leia o texto inteiro antes de mexer.
2. Corrija ortografia e concordância.
3. Corte repetições e frases longas.
4. No fim, liste as mudanças principais em uma frase.
''';
