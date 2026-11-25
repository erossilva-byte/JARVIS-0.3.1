/// Especialização do J.A.R.V.I.S. em CADeSIMU e em programação.
///
/// O roteador de agentes (`agentes.dart`) escolhe o domínio do pedido; aqui
/// ficam as duas áreas em que o JARVIS responde com profundidade maior. A
/// instrução é texto puro: entra no pedido do provedor de IA que o usuário já
/// configurou, e não promete ferramenta que o app não tem — em especial, nada
/// é gerado no formato proprietário `.cad` e nada de código é executado.
library;

import 'texto_ptbr.dart';

/// Uma área de especialização: o que cobre, o que recusa e como responder.
class Especialidade {
  const Especialidade({
    required this.id,
    required this.nome,
    required this.chamada,
    required this.dominio,
    required this.focos,
    required this.limites,
    required this.exemplos,
  });

  final String id;
  final String nome;

  /// Frase curta para a tela.
  final String chamada;

  /// O que esta especialidade resolve, em uma frase.
  final String dominio;

  /// Assuntos em que a resposta deve ser mais específica.
  final List<String> focos;

  /// O que a especialidade **não** faz — dito ao modelo, não escondido.
  final List<String> limites;

  /// Pedidos que caem nesta especialidade.
  final List<String> exemplos;
}

const especialidadeCadesimu = Especialidade(
  id: 'cadesimu',
  nome: 'CADeSIMU e elétrica',
  chamada: 'Do comando ao dimensionamento, sem inventar formato',
  dominio: 'projetos elétricos, comandos, ladder, texto estruturado e '
      'dimensionamento no contexto do CADeSIMU',
  focos: [
    'comando e força: partida direta, reversão, estrela-triângulo, '
        'soft-starter e inversor, com a sequência de contatos descrita',
    'ladder e texto estruturado: entradas e saídas nomeadas, bobinas, '
        'selos, temporizadores e intertravamentos',
    'dimensionamento: corrente de projeto, disjuntor, contator, relé '
        'térmico, seccionadora e bitola do condutor, com a conta mostrada',
    'leitura do `.cad`: netlist, tags de componente e ligação entre '
        'terminais, quando o arquivo já foi importado no app',
    'boas práticas: proteção, aterramento, sinalização e o risco de '
        'energia residual antes de mexer no quadro',
  ],
  limites: [
    'não gera nem edita o `.cad` nativo do CADeSIMU: é formato proprietário; '
        'o app importa em somente leitura e monta o esquema no simulador próprio',
    'não simula o CADeSIMU por dentro: os cálculos são feitos aqui e podem '
        'divergir do resultado do software original',
    'não substitui laudo, ART nem conferência de um eletricista habilitado',
  ],
  exemplos: [
    'monta uma partida direta com selo e relé térmico',
    'dimensiona o disjuntor e o contator de um motor de 5 cv em 380 V',
    'o que é o selo 13-14 do contator K1',
  ],
);

const especialidadeProgramacao = Especialidade(
  id: 'programacao',
  nome: 'Programação',
  chamada: 'Código lido, explicado e revisado — sem executar',
  dominio: 'código, revisão, testes, erros de compilação e desenho de '
      'solução em qualquer linguagem que o usuário trouxer',
  focos: [
    'criar: função, classe ou tela completa, com o mínimo de dependências',
    'analisar e revisar: apontar defeito real, risco, efeito colateral e o '
        'que o teste deveria cobrir',
    'modificar: mudança pequena e cirúrgica, preservando o que já funciona',
    'explicar erro: ler a mensagem, dizer a causa provável e o próximo passo',
    'convenções: nomes claros, limites de entrada, tratamento de erro e '
        'nenhum segredo escrito no código',
  ],
  limites: [
    'não executa, compila nem testa o código: não há terminal nem sandbox '
        'neste APK; o que for dito como “deve funcionar” é análise, não medição',
    'não acessa o repositório do usuário nem instala pacote no aparelho',
    'não inventa saída de teste: quando não dá para saber, diz o que conferir',
  ],
  exemplos: [
    'revisa essa função e aponta o que quebra com entrada vazia',
    'explica por que esse código dá null check operator used on a null value',
    'escreve um teste para esse parser',
  ],
);

const especialidadesJarvis = <Especialidade>[
  especialidadeCadesimu,
  especialidadeProgramacao,
];

/// Regras de reconhecimento, na ordem em que valem.
///
/// CADeSIMU vem antes de programação de propósito: “programa do CLP” é
/// engenharia, não código. `RegExp` não é constante em Dart, por isso a lista
/// é `final`.
final List<({String id, RegExp regra})> _regrasEspecialidade = [
  (
    id: 'cadesimu',
    regra: RegExp(
        r'(cadesimu|cad[ _-]?simu|\.cad\b|netlist|\bladder\b|\bclp\b|\bplc\b|'
        r'contator|disjuntor|seccionadora|rel[eé] t[eé]rmico|'
        r'partida direta|estrela.?tri[aâ]ngulo|soft.?starter|'
        r'texto estruturado|diagrama el[eé]trico|quadro el[eé]trico|'
        r'comando el[eé]trico|motor trif[aá]sico|dimensiona.+(motor|circuito|cabo)|'
        r'bitola.+(cabo|condutor|fio))'),
  ),
  (
    id: 'programacao',
    regra: RegExp(
        r'(\bcodigo\b|\bprograma(r|cao|dor)?\b|python|dart|kotlin|javascript|'
        r'typescript|\bjava\b|\bc#|c\+\+|flutter|react|node\.?js|'
        r'\bsql\b|\bhtml\b|\bcss\b|\bapi\b|\bjson\b|regex|'
        r'\bbug\b|exce[cç][aã]o|null (?:pointer|check operator)|stack ?trace|compila|'
        r'refator|teste unit[aá]rio|\bfun[cç][aã]o\b|\bclasse\b|revis.+(c[oó]digo|fun[cç][aã]o|arquivo))'),
  ),
];

/// Especialidade que responde ao texto, ou `null` quando o pedido é geral.
///
/// Devolver `null` é o caso normal: só um pedido que fala a língua da área
/// recebe a instrução extra, para não transformar toda conversa em aula.
Especialidade? especialidadeDe(String texto) {
  final alvo = semAcentoTexto(texto).toLowerCase();
  if (alvo.trim().isEmpty) return null;
  for (final regra in _regrasEspecialidade) {
    if (regra.regra.hasMatch(alvo)) return especialidadePorId(regra.id);
  }
  return null;
}

/// Especialidade pelo id; id desconhecido devolve `null` em vez de supor.
Especialidade? especialidadePorId(String? id) {
  final alvo = (id ?? '').trim().toLowerCase();
  for (final especialidade in especialidadesJarvis) {
    if (especialidade.id == alvo) return especialidade;
  }
  return null;
}

/// Instrução de sistema da especialidade, pronta para entrar no pedido.
///
/// O texto é curto de propósito: ele acompanha cada mensagem, e um bloco longo
/// comeria o orçamento da conversa.
String instrucaoDaEspecialidade(Especialidade especialidade) {
  final focos = especialidade.focos.map((foco) => '- $foco').join('\n');
  final limites = especialidade.limites.map((limite) => '- $limite').join('\n');
  return 'Você é o J.A.R.V.I.S. Nova, especializado em ${especialidade.nome}. '
      'Domínio: ${especialidade.dominio}. Responda em português do Brasil, '
      'direto, com o detalhe técnico que a pergunta pede.\n'
      'O que você cobre:\n$focos\n'
      'Limites que você declara quando o pedido chega perto deles:\n$limites\n'
      'Nunca invente número, norma, pino, tag ou resultado de medição. Quando '
      'faltar um dado (tensão, potência, versão, trecho de código), pergunte '
      'uma coisa de cada vez ou diga qual dado falta. Se o pedido fugir da '
      'especialidade, responda normalmente e diga em uma frase que aquilo está '
      'fora dela.';
}

/// Bloco pronto para o pedido, ou string vazia quando o texto não é da área.
String blocoDaEspecialidade(Especialidade? especialidade) =>
    especialidade == null ? '' : instrucaoDaEspecialidade(especialidade);

/// Texto da tela de especialidades.
String resumoEspecialidades() {
  final nomes = especialidadesJarvis.map((e) => e.nome).join(' e ');
  return 'Duas especializações além da conversa geral: $nomes. O pedido é '
      'reconhecido por palavra-chave e a instrução da área acompanha a '
      'pergunta; o resto continua sendo respondido no domínio comum.';
}
