/// Modo de visita (Duress PIN) — regras puras.
///
/// O modo de visita é o app aberto com o **PIN de coação**, diferente do PIN
/// principal. Ele não abre o JARVIS de verdade: mostra uma instalação nova,
/// sem conversas, memória, fichas de pessoas, arquivos ou chaves de provedor.
/// Nada é apagado; os dados reais continuam no aparelho e voltam ao entrar com
/// o PIN principal.
///
/// Este arquivo não conhece tela nem armazenamento: só o que pode ser dito e
/// mostrado sem tocar em nada do dono do aparelho.
library;

/// Quantos dígitos o PIN de coação aceita (mesma faixa do PIN principal).
const tamanhoMinPinCoacao = 4;
const tamanhoMaxPinCoacao = 8;

/// Nome do prompt sugerido, usado na tela de segurança e na documentação.
const nomePromptModoVisita = 'Modo de visita';

/// Prompt sugerido do modo de visita.
///
/// Serve para qualquer assistente que venha a falar dentro do modo de visita,
/// inclusive um provedor local no futuro: a regra é nunca revelar que existe
/// um dono, um histórico ou qualquer dado guardado.
const promptModoVisita = '''
Você está no $nomePromptModoVisita do JARVIS, em um aparelho sem dados configurados. Responda em português do Brasil, em no máximo três frases, com tom cordial e neutro. Nunca mencione o dono do aparelho, conversas anteriores, memória, fichas de pessoas, arquivos, localização, compromissos ou chaves de provedor. Se pedirem algo pessoal, diga que este aparelho não tem dados configurados e ofereça ajuda geral. Não invente fatos, não finja ter acesso a nada e não peça senhas. Se a pergunta for sobre o próprio JARVIS, diga apenas que é um assistente e que os recursos dependem de configuração.
''';

/// Primeira fala ao abrir o modo de visita: plausível para um app recém-instalado.
const boasVindasVisita =
    'Bom dia. Eu sou o JARVIS. Este aparelho ainda não tem um provedor de '
    'inteligência configurado.';

/// Resposta local do modo de visita — sem rede, sem provedor e sem dados.
///
/// O modo de visita **não** consulta IA: qualquer texto que saísse daqui levaria
/// junto o contexto do dono do aparelho. Hora e data vêm do próprio relógio, que
/// não revela nada guardado.
String respostaVisita(String pergunta, {DateTime? agora}) {
  final texto = pergunta.trim().toLowerCase();
  if (texto.isEmpty) {
    return 'Pode perguntar. Neste aparelho eu respondo só o básico.';
  }
  final quando = agora ?? DateTime.now();
  if (texto.contains('que horas') || texto.contains('hora agora')) {
    return 'Agora são ${_hora(quando)}.';
  }
  if (texto.contains('que dia') ||
      texto.contains('data de hoje') ||
      texto.contains('hoje é')) {
    return 'Hoje é ${_data(quando)}.';
  }
  if (texto.startsWith('oi') ||
      texto.startsWith('olá') ||
      texto.startsWith('ola') ||
      texto.contains('bom dia') ||
      texto.contains('boa tarde') ||
      texto.contains('boa noite')) {
    return 'Olá. Em que posso ajudar?';
  }
  if (texto.contains('quem é você') || texto.contains('seu nome')) {
    return 'Sou o JARVIS, um assistente neste aparelho.';
  }
  if (texto.contains('culinária') ||
      texto.contains('culinaria') ||
      texto.contains('receita')) {
    return 'Sobre culinária eu não tenho um provedor de inteligência '
        'configurado aqui. Este aparelho ainda não foi ajustado para isso.';
  }
  return 'Neste aparelho eu ainda não tenho um provedor de inteligência '
      'configurado, então não consigo responder isso. Tudo o que é seu segue '
      'guardado.';
}

/// Itens que a tela de ajustes do modo de visita mostra — sempre vazios.
const ajustesVisita = <(String, String)>[
  ('Provedor de IA', 'Nenhum configurado'),
  ('Conversas', 'Nenhuma guardada'),
  ('Memória', 'Vazia'),
  ('Pessoas', 'Nenhuma ficha'),
  ('Arquivos e cofre', 'Nenhum arquivo'),
  ('Palavra de ativação', 'Desligada'),
];

/// O que o modo de visita realmente faz — e não faz.
const limitesModoVisita = <String>[
  'O modo de visita não apaga nada: as conversas, a memória e as fichas '
      'continuam no aparelho e voltam com o PIN principal.',
  'Ele esconde o conteúdo, não o criptografa de novo. Com acesso técnico ao '
      'aparelho (root ou perícia), os dados reais ainda podem ser encontrados.',
  'A biometria continua abrindo o app real: o rosto ou o dedo do dono não '
      'levam ao modo de visita.',
  'Nada é enviado à internet no modo de visita: nenhuma pergunta sai do '
      'aparelho.',
  'Quem conhece os dois PINs não é protegido por ele.',
];

String _hora(DateTime quando) {
  final h = quando.hour.toString().padLeft(2, '0');
  final m = quando.minute.toString().padLeft(2, '0');
  return '$h horas e $m minutos';
}

const _dias = [
  'segunda-feira',
  'terça-feira',
  'quarta-feira',
  'quinta-feira',
  'sexta-feira',
  'sábado',
  'domingo',
];

const _meses = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

String _data(DateTime quando) =>
    '${_dias[quando.weekday - 1]}, ${quando.day} de ${_meses[quando.month - 1]} '
    'de ${quando.year}';
