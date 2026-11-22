/// Gestos com os sensores e modo noturno — contrato puro, sem Flutter e sem
/// Android.
///
/// O acelerômetro do aparelho é lido no Kotlin; aqui ficam as regras que a tela
/// mostra e que os testes prendem: quando o celular está de bruços, qual é o
/// brilho seguro e o que o modo noturno muda.
library;

/// Gravidade apontando para o lado oposto à tela: celular de bruços.
const limiarViradoParaBaixo = -8.0;

/// Folga para voltar a considerar o celular para cima.
const limiarVoltouParaCima = -4.0;

const brilhoMinimoGestos = 10;
const brilhoMaximoGestos = 100;
const brilhoPadraoGestos = 35;

/// Brilho dentro da faixa usada pelo app.
int brilhoSeguro(int valor) =>
    valor < brilhoMinimoGestos
        ? brilhoMinimoGestos
        : (valor > brilhoMaximoGestos ? brilhoMaximoGestos : valor);

/// Fator de brilho da janela (0–1) para o `WindowManager` do Android.
double fatorBrilho(int percentual) => brilhoSeguro(percentual) / 100;

/// O eixo Z do acelerômetro indica a tela virada para baixo.
bool viradoParaBaixo(double z) => z <= limiarViradoParaBaixo;

/// O celular voltou a ficar com a tela para cima (histerese do gesto).
bool voltouParaCima(double z) => z >= limiarVoltouParaCima;

/// Estado lido do aparelho.
class EstadoGestos {
  const EstadoGestos({
    required this.temAcelerometro,
    required this.calarAoVirar,
    required this.modoNoturno,
    required this.brilho,
  });

  final bool temAcelerometro;
  final bool calarAoVirar;
  final bool modoNoturno;
  final int brilho;

  static const vazio = EstadoGestos(
    temAcelerometro: false,
    calarAoVirar: false,
    modoNoturno: false,
    brilho: brilhoPadraoGestos,
  );

  factory EstadoGestos.deMapa(Object? dados) {
    if (dados is! Map) return vazio;
    int inteiro(Object? valor, int padrao) =>
        valor is num ? valor.toInt() : padrao;
    return EstadoGestos(
      temAcelerometro: dados['temAcelerometro'] == true,
      calarAoVirar: dados['calarAoVirar'] == true,
      modoNoturno: dados['modoNoturno'] == true,
      brilho: brilhoSeguro(
          inteiro(dados['brilho'], brilhoPadraoGestos)),
    );
  }

  EstadoGestos copiarCom({bool? calarAoVirar, bool? modoNoturno, int? brilho}) =>
      EstadoGestos(
        temAcelerometro: temAcelerometro,
        calarAoVirar: calarAoVirar ?? this.calarAoVirar,
        modoNoturno: modoNoturno ?? this.modoNoturno,
        brilho: brilho == null ? this.brilho : brilhoSeguro(brilho),
      );
}

/// Frase curta do estado, para o cartão principal da tela.
String resumoGestos(EstadoGestos estado) {
  if (!estado.temAcelerometro) {
    return 'Este aparelho não informou acelerômetro: virar para calar não existe aqui.';
  }
  final partes = <String>[
    estado.calarAoVirar ? 'virar para calar ligado' : 'virar para calar desligado',
    estado.modoNoturno
        ? 'modo noturno com brilho em ${estado.brilho}%'
        : 'modo noturno desligado',
  ];
  return '${partes.join(' · ')}.';
}

/// Limites que não devem ser escondidos do usuário.
const limitesGestos = <String>[
  'Virar para calar usa o acelerômetro e só vale com a tela do JARVIS aberta: '
      'o sensor é desligado quando o app sai da frente para não gastar bateria.',
  'O gesto cala a fala na hora; a resposta escrita continua na tela.',
  'O modo noturno muda o brilho apenas na janela do JARVIS. Mudar o brilho do '
      'aparelho exigiria a permissão WRITE_SETTINGS, que o app não pede.',
  'No modo noturno a voz sai em 45% do volume; se o aparelho estiver no mudo, '
      'ainda depende do volume de mídia.',
];
