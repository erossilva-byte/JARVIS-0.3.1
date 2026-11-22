/// Agentes especializados do JARVIS — contrato puro, sem Flutter e sem rede.
///
/// É o porte do registro que já existia no núcleo web (`agentes.js`): cada
/// pedido pertence a um domínio, e é o domínio que decide qual instrução de
/// sistema acompanha o pedido. A ordem das regras importa — “abrir arquivo” é de
/// Arquivos, não do Dispositivo — e por isso ela está presa no teste.
library;

import 'texto_ptbr.dart';

/// Um domínio de trabalho com o texto que o define.
class AgenteEspecializado {
  const AgenteEspecializado({
    required this.id,
    required this.nome,
    required this.dominio,
    required this.exemplos,
  });

  final String id;
  final String nome;

  /// O que este agente resolve, em uma frase.
  final String dominio;

  /// Exemplos de pedido que caem aqui — mostrados na tela.
  final List<String> exemplos;
}

/// Os doze agentes do núcleo. A lista é a mesma do app web, para os dois não
/// divergirem.
const agentesEspecializados = <AgenteEspecializado>[
  AgenteEspecializado(
    id: 'conversa',
    nome: 'Conversa',
    dominio: 'hora, data, cálculos, explicações e respostas gerais',
    exemplos: ['que horas são', 'explique o que é impedância', 'quanto é 12% de 480'],
  ),
  AgenteEspecializado(
    id: 'pesquisa',
    nome: 'Pesquisa',
    dominio: 'web, clima, notícias e links',
    exemplos: ['como está o tempo', 'últimas notícias de tecnologia'],
  ),
  AgenteEspecializado(
    id: 'dispositivo',
    nome: 'Dispositivo',
    dominio: 'apps, mídia, volume, brilho, alarmes, notificações, chamadas e mensagens',
    exemplos: ['aumenta o volume', 'cria um alarme para 6h', 'abre o WhatsApp'],
  ),
  AgenteEspecializado(
    id: 'arquivos',
    nome: 'Arquivos',
    dominio: 'leitura, criação e conferência de arquivos e projetos',
    exemplos: ['lê o arquivo notas.txt', 'cria uma lista de compras'],
  ),
  AgenteEspecializado(
    id: 'memoria',
    nome: 'Memória',
    dominio: 'notas, cofre e contexto do usuário',
    exemplos: ['lembra que o R1 é de 1k', 'busca o que eu anotei sobre o projeto'],
  ),
  AgenteEspecializado(
    id: 'pessoas',
    nome: 'Pessoas',
    dominio: 'contatos, perfis e reconhecimento de locutor',
    exemplos: ['quem é a Ana', 'chama a Maria no WhatsApp'],
  ),
  AgenteEspecializado(
    id: 'visao',
    nome: 'Visão',
    dominio: 'câmera, imagens e descrição de cena',
    exemplos: ['o que tem nessa imagem', 'lê o que está escrito na tela'],
  ),
  AgenteEspecializado(
    id: 'pc',
    nome: 'Computador',
    dominio: 'arquivos e comandos do PC conectado',
    exemplos: ['abre o projeto no computador'],
  ),
  AgenteEspecializado(
    id: 'sistema',
    nome: 'Sistema',
    dominio: 'atualização, diagnóstico, segurança e configuração',
    exemplos: ['faz um diagnóstico', 'qual a versão instalada'],
  ),
  AgenteEspecializado(
    id: 'programacao',
    nome: 'Programação',
    dominio: 'código, sandbox, testes, correções e revisão do próprio projeto',
    exemplos: ['revisa esse código', 'escreve um teste para o parser'],
  ),
  AgenteEspecializado(
    id: 'engenharia',
    nome: 'Engenharia',
    dominio: 'elétrica, motores, CLP, ladder e texto estruturado',
    exemplos: ['partida direta de um motor', 'dimensiona o disjuntor de 20 A'],
  ),
  AgenteEspecializado(
    id: 'eletronica',
    nome: 'Eletrônica',
    dominio: 'circuitos, componentes, netlist e intercâmbio CADeSIMU',
    exemplos: ['monta um divisor de tensão', 'circuito com LED em 12 V'],
  ),
];

/// Regras de roteamento, na ordem em que valem.
///
/// `RegExp` não é constante em Dart, por isso a lista é `final`. A ordem é a
/// mesma de `agentes.js`: programa antes de eletrônica, arquivos antes de
/// dispositivo.
final List<({String agente, RegExp regra})> regrasAgente = [
  (agente: 'programacao', regra: RegExp(r'(sandbox|codigo|patch|dev_|teste|revis|refator|script|programa)')),
  (agente: 'eletronica', regra: RegExp(
          r'(cadesimu|componente|netlist|simul|circuito|circ_|spice|placa|resistor|led|divisor|tensao|corrente)')),
  (agente: 'engenharia', regra: RegExp(r'(eletrica|projetista|motor|ladder|clp|\bst\b|plc|dimension|potencia|contator)')),
  (agente: 'pesquisa', regra: RegExp(r'(pesquis|clima|noticia|web|link|youtube|wikipedia|google)')),
  (agente: 'arquivos', regra: RegExp(r'(arq_|arquivo|pasta|documento|pdf|docx|planilha|zip|projeto|cad_)')),
  (agente: 'memoria',
      regra: RegExp(r'(memoria|nota|obsidian|contexto|lembra|anota|guarda isso)')),
  (agente: 'pessoas', regra: RegExp(r'(pessoa|contato|locutor|identidade|voz_)')),
  (agente: 'visao', regra: RegExp(r'(visao|camera|imagem|foto|ocr)')),
  (agente: 'pc', regra: RegExp(r'(^pc_|computador|desktop|servidor)')),
  (agente: 'sistema', regra: RegExp(r'(atualiz|diagnostico|seguranca|config|pin|backup|sincron)')),
  (
    agente: 'dispositivo',
    regra: RegExp(
        r'(app|midia|volume|brilho|lanterna|alarme|lembrete|notifica|sms|ligar|chamada|whatsapp|email|agenda|tarefa|rotina|tela|wifi|bluetooth|status_dispositivo|acessibilidade)')
  ),
];

/// Agente responsável pelo texto; sem regra que case, é a conversa.
AgenteEspecializado agenteDe(String texto) {
  final alvo = semAcentoTexto(texto).toLowerCase();
  for (final item in regrasAgente) {
    if (item.regra.hasMatch(alvo)) return agentePorId(item.agente);
  }
  return agentePorId('conversa');
}

/// Agente pelo id; id desconhecido cai na conversa em vez de derrubar a tela.
AgenteEspecializado agentePorId(String? id) {
  final alvo = (id ?? '').trim().toLowerCase();
  for (final agente in agentesEspecializados) {
    if (agente.id == alvo) return agente;
  }
  return agentesEspecializados.first;
}

/// Instrução de sistema que acompanha o pedido deste agente.
///
/// Não promete ferramenta que o app não tem: manda dizer o que falta.
String instrucaoDoAgente(AgenteEspecializado agente) {
  return 'Você é o J.A.R.V.I.S. Nova, no domínio ${agente.nome}: ${agente.dominio}. '
      'Responda em português do Brasil, curto e direto. Não invente dado, '
      'número nem efeito que não possa ser verificado no aparelho. Se o pedido '
      'depender de algo que o app não tem, diga o que falta em uma frase.';
}

/// Texto da tela de agentes: quem é quem e para onde o pedido vai.
String resumoDosAgentes() {
  final nomes = agentesEspecializados.map((a) => a.nome).join(', ');
  return 'Doze domínios: $nomes. O pedido é classificado por palavra-chave, na '
      'mesma ordem do núcleo web, e o agente escolhido define a instrução que '
      'acompanha a pergunta.';
}
