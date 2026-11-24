/// Perfis de timbre da voz do JARVIS — contrato puro, sem Flutter e sem
/// Android.
///
/// O timbre é aplicado pela síntese de voz do aparelho: `pitch` (tom) e
/// `velocidade` (ritmo). Os valores são os mesmos do Kotlin
/// (`JarvisTimbre.kt`), e os testes prendem a paridade para a tela nunca mostrar
/// um perfil diferente do que a voz realmente usa.
library;

/// Faixa aceita pelo TextToSpeech do Android.
const pitchMinimo = 0.5;
const pitchMaximo = 2.0;
const velocidadeMinima = 0.5;
const velocidadeMaxima = 2.0;

/// Perfil de timbre escolhido pelo usuário.
class PerfilTimbre {
  const PerfilTimbre({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.pitch,
    required this.velocidade,
  });

  final String id;
  final String nome;
  final String descricao;
  final double pitch;
  final double velocidade;
}

/// Os perfis do comparativo com o ULTRON.
///
/// O grave é o timbre original do app (0,72 de tom), agora com ritmo mais
/// rápido: a fala antiga (0,88) ficava lenta demais para o dia a dia. O perfil
/// "Rápida" leva o ritmo ao ponto mais alto que a síntese costuma aceitar sem
/// picar as palavras. Nenhum perfil cria voz nova: só ajusta tom e ritmo da
/// mesma voz do aparelho.
const perfisTimbre = <PerfilTimbre>[
  PerfilTimbre(
    id: 'grave',
    nome: 'Grave',
    descricao: 'Timbre original do JARVIS, com a fala mais rápida de agora.',
    pitch: 0.72,
    velocidade: 1.12,
  ),
  PerfilTimbre(
    id: 'natural',
    nome: 'Natural',
    descricao: 'A voz do aparelho sem alteração de tom, em ritmo ágil.',
    pitch: 1.0,
    velocidade: 1.28,
  ),
  PerfilTimbre(
    id: 'agil',
    nome: 'Ágil',
    descricao: 'Mais agudo e rápido, para respostas curtas do dia a dia.',
    pitch: 1.15,
    velocidade: 1.45,
  ),
  PerfilTimbre(
    id: 'rapida',
    nome: 'Rápida',
    descricao: 'O ritmo mais alto que a síntese costuma aceitar sem picar.',
    pitch: 1.0,
    velocidade: 1.6,
  ),
];

/// Perfil usado quando o aparelho nunca escolheu nenhum.
const timbrePadrao = 'grave';

/// Devolve o perfil pedido; id desconhecido ou vazio cai no padrão.
PerfilTimbre timbreDe(String? id) {
  final procurado = (id ?? '').trim().toLowerCase();
  for (final perfil in perfisTimbre) {
    if (perfil.id == procurado) return perfil;
  }
  return perfisTimbre.first;
}

/// Tom dentro da faixa aceita pelo Android.
double pitchSeguro(double valor) => valor < pitchMinimo
    ? pitchMinimo
    : (valor > pitchMaximo ? pitchMaximo : valor);

/// Ritmo dentro da faixa aceita pelo Android.
double velocidadeSegura(double valor) => valor < velocidadeMinima
    ? velocidadeMinima
    : (valor > velocidadeMaxima ? velocidadeMaxima : valor);

/// Frase curta do perfil, para o cartão principal da tela.
String resumoTimbre(PerfilTimbre perfil) =>
    '${perfil.nome}: tom ${perfil.pitch.toStringAsFixed(2)} e ritmo '
    '${perfil.velocidade.toStringAsFixed(2)}. ${perfil.descricao}';

/// Texto do botão “Ouvir exemplo”: curto e sem números para a voz não tropeçar.
const fraseExemploTimbre =
    'Bom dia. Eu sou o JARVIS. Esta é a minha voz neste timbre.';

/// Limites que não devem ser escondidos do usuário.
const limitesTimbre = <String>[
  'O timbre muda o tom e o ritmo da voz já instalada no aparelho; não é uma '
      'voz nova e a qualidade depende do mecanismo de síntese.',
  'Ritmo acima de cerca de 1,6 pode picar palavras em sintetizadores antigos; '
      'se acontecer, volte para o Natural ou o Grave.',
  'Se o Android não tiver voz em português, a síntese usa o idioma padrão e o '
      'timbre continua valendo.',
  'O perfil fica gravado no aparelho e vale para a tela e para o segundo plano.',
  'No modo noturno o volume continua em 45%, qualquer que seja o timbre.',
];
