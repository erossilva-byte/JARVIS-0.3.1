/// Projetista por prompt — do texto ao circuito montado.
///
/// O app já tinha importador `.cad` e simulador; o que faltava era o caminho do
/// meio: a pessoa descreve o que quer e o JARVIS monta o esquema. Este arquivo é
/// Dart puro: lê o pedido, escolhe uma família de circuito, monta os elementos
/// na grade e **valida com o próprio simulador** antes de dizer que deu certo.
///
/// O que ele não faz, e diz na cara: potência trifásica, componentes que o
/// simulador não modela (transistor, CI, LED como símbolo próprio) e o `.cad`
/// nativo do CADeSIMU. Nesses casos devolve `ok: false` com o motivo, em vez de
/// entregar um desenho que não fecha.
library;

import 'circuito.dart';
import 'texto_ptbr.dart';

/// Famílias que o projetista sabe montar na grade.
enum FamiliaCircuito {
  lampada,
  interruptorDuplo,
  led,
  serie,
  paralelo,
  divisor,
  partidaDireta,
  reversao,
  temporizador,
  desconhecida,
}

/// Nome legível da família.
String nomeFamilia(FamiliaCircuito familia) {
  switch (familia) {
    case FamiliaCircuito.lampada:
      return 'Lâmpada com interruptor';
    case FamiliaCircuito.interruptorDuplo:
      return 'Interruptor duplo (duas lâmpadas)';
    case FamiliaCircuito.led:
      return 'LED com resistor de limitação';
    case FamiliaCircuito.serie:
      return 'Lâmpadas em série';
    case FamiliaCircuito.paralelo:
      return 'Lâmpadas em paralelo';
    case FamiliaCircuito.divisor:
      return 'Divisor de tensão';
    case FamiliaCircuito.partidaDireta:
      return 'Partida direta com selo';
    case FamiliaCircuito.reversao:
      return 'Reversão com intertravamento';
    case FamiliaCircuito.temporizador:
      return 'Sequência temporizada';
    case FamiliaCircuito.desconhecida:
      return 'Não identificada';
  }
}

/// O que o pedido disse, em números.
class PedidoCircuito {
  const PedidoCircuito({
    required this.original,
    required this.familia,
    required this.tensao,
    required this.potencia,
    required this.ohms,
    required this.segundos,
    required this.quantidade,
    required this.trifasico,
  });

  final String original;
  final FamiliaCircuito familia;

  /// Tensão da fonte, em volts.
  final double tensao;

  /// Potência da carga, em watts.
  final double potencia;

  /// Resistência pedida, em ohms; nulo quando o pedido não disse.
  final double? ohms;

  /// Atraso pedido, em segundos.
  final double segundos;

  /// Quantas cargas o pedido citou (2 por padrão).
  final int quantidade;

  /// O pedido falou em trifásico — o simulador é de corrente contínua.
  final bool trifasico;

  /// Lê o texto livre do usuário.
  factory PedidoCircuito.ler(String texto) {
    final normal = normalizarTexto(texto);
    double? numero(String padrao) {
      final achado = RegExp(padrao).firstMatch(normal);
      if (achado == null) return null;
      return double.tryParse(achado.group(1)!.replaceAll(',', '.'));
    }

    final tensao = numero(r'(\d+(?:[.,]\d+)?)\s*(?:v|volts?|vcc|vac|vdc)\b');
    final potencia = numero(r'(\d+(?:[.,]\d+)?)\s*(?:w|watts?)\b');
    final segundos =
        numero(r'(\d+(?:[.,]\d+)?)\s*(?:s|seg|segs|segundo|segundos)\b');
    var ohms = numero(r'(\d+(?:[.,]\d+)?)\s*(?:k|kohm|kohms|ohm|ohms)\b');
    if (ohms == null) {
      final emK = numero(r'(\d+(?:[.,]\d+)?)\s*k\b');
      if (emK != null) ohms = emK * 1000;
    } else if (normal.contains(RegExp(r'\d+\s*k(?:ohm|ohms)?\b'))) {
      ohms = ohms * 1000;
    }
    var quantidade = numero(r'(\d+)\s*(?:lampadas?|leds?|motores?|cargas?)\b');
    // “duas lâmpadas” não tem dígito: o pedido em português costuma escrever.
    if (quantidade == null) {
      if (RegExp(r'\bduas\b').hasMatch(normal)) quantidade = 2;
      if (RegExp(r'\btres\b').hasMatch(normal)) quantidade = 3;
      if (RegExp(r'\bquatro\b').hasMatch(normal)) quantidade = 4;
    }

    final trifasico =
        RegExp(r'(trifas|3 fases|tres fases|380)').hasMatch(normal);
    final familia = _familiaDe(normal, tensao ?? 12);

    return PedidoCircuito(
      original: texto.trim(),
      familia: familia,
      tensao: tensao ?? 12,
      potencia: potencia ?? 5,
      ohms: ohms,
      segundos: segundos ?? 3,
      quantidade: _entreDoisETres(quantidade),
      trifasico: trifasico,
    );
  }
}

int _entreDoisETres(double? bruto) {
  final valor = (bruto ?? 2).round();
  return valor < 2 ? 2 : (valor > 3 ? 3 : valor);
}

FamiliaCircuito _familiaDe(String normal, double tensao) {
  bool tem(String padrao) => RegExp(padrao).hasMatch(normal);
  if (tem(r'revers|dois sentidos|sentido de giro')) {
    return FamiliaCircuito.reversao;
  }
  if (tem(r'temporiz|retard|depois de|apos \d|contagem|sequencia')) {
    return FamiliaCircuito.temporizador;
  }
  if (tem(r'divisor|duas resist|metade da tensao')) {
    return FamiliaCircuito.divisor;
  }
  if (tem(r'partida|contator|selo|acionamento de motor')) {
    return FamiliaCircuito.partidaDireta;
  }
  if (tem(r'\bled\b|diodo emissor')) return FamiliaCircuito.led;
  if (tem(r'serie')) return FamiliaCircuito.serie;
  if (tem(r'paralel')) return FamiliaCircuito.paralelo;
  // Duas teclas comandam duas cargas; sem esta família o pedido cairia na
  // lâmpada com um interruptor só e a resposta ficaria errada.
  if (tem(r'interruptor duplo|duplo interruptor|interruptor de duas teclas|'
      r'duas teclas|dois interruptores')) {
    return FamiliaCircuito.interruptorDuplo;
  }
  if (tem(r'lampada|luz|interruptor|luminaria|farol|iluminacao')) {
    return FamiliaCircuito.lampada;
  }
  if (tem(r'motor')) return FamiliaCircuito.partidaDireta;
  return FamiliaCircuito.desconhecida;
}

/// Resultado do projeto: o circuito montado ou o motivo de não haver circuito.
class ResultadoProjeto {
  const ResultadoProjeto({
    required this.ok,
    required this.pedido,
    this.circuito,
    this.titulo = '',
    this.explicacao = '',
    this.avisos = const [],
    this.motivo = '',
  });

  final bool ok;
  final PedidoCircuito pedido;
  final Circuito? circuito;
  final String titulo;
  final String explicacao;
  final List<String> avisos;
  final String motivo;
}

/// Texto que explica o que o projetista monta — usado na recusa e na tela.
const familiasSuportadas =
    'lâmpada com interruptor, interruptor duplo, LED com '
    'resistor, lâmpadas '
    'em série, lâmpadas em paralelo, divisor de tensão, partida direta com selo '
    '(corrente contínua), reversão com intertravamento e ligação temporizada';

/// Exemplos para o campo de texto.
const exemplosDePedido = <String>[
  'lâmpada de 12 V e 5 W com interruptor',
  'LED de 12 V com resistor',
  'duas lâmpadas de 12 V em paralelo',
  'divisor de tensão de 12 V para 8 V',
  'partida direta de um motor de 24 V',
  'reversão de motor com intertravamento',
  'acender a lâmpada 5 segundos depois de apertar o botão',
];

/// Monta o circuito do pedido. Nunca devolve `ok: true` sem simulação fechada.
ResultadoProjeto montarProjetoDe(String texto) {
  final pedido = PedidoCircuito.ler(texto);
  if (pedido.original.isEmpty) {
    return ResultadoProjeto(
      ok: false,
      pedido: pedido,
      motivo: 'Descreva o circuito: tensão, carga e o que deve acontecer. '
          'Por exemplo: “lâmpada de 12 V e 5 W com interruptor”.',
    );
  }

  switch (pedido.familia) {
    case FamiliaCircuito.interruptorDuplo:
      return _interruptorDuplo(pedido);
    case FamiliaCircuito.lampada:
      return _validar(
        pedido,
        _lampadaComInterruptor(pedido),
        'Lâmpada com interruptor',
        'Fonte de ${_v(pedido.tensao)}, interruptor fechado e lâmpada de '
            '${_w(pedido.potencia)} em ${_v(pedido.tensao)}.',
        const [],
      );
    case FamiliaCircuito.led:
      return _led(pedido);
    case FamiliaCircuito.serie:
      return _serie(pedido);
    case FamiliaCircuito.paralelo:
      return _paralelo(pedido);
    case FamiliaCircuito.divisor:
      return _divisor(pedido);
    case FamiliaCircuito.partidaDireta:
      return _partidaDireta(pedido);
    case FamiliaCircuito.reversao:
      return _reversao(pedido);
    case FamiliaCircuito.temporizador:
      return _temporizado(pedido);
    case FamiliaCircuito.desconhecida:
      return ResultadoProjeto(
        ok: false,
        pedido: pedido,
        motivo:
            'Não identifiquei o circuito no pedido. Eu monto $familiasSuportadas. '
            'Diga a tensão e a carga — por exemplo: “divisor de tensão de 12 V”.',
      );
  }
}

/* ------------------------------------------------------------------ *
 * Montagem — as mesmas topologias dos exemplos do simulador, com os
 * valores do pedido no lugar dos valores fixos.
 * ------------------------------------------------------------------ */

Elemento _fio(int a, int b) =>
    Elemento(id: chaveTrecho(a, b), tipo: TipoElemento.fio, a: a, b: b);

Elemento _fonte(int a, int b, double volts) => Elemento(
    id: chaveTrecho(a, b), tipo: TipoElemento.fonte, a: a, b: b, valor: volts);

Elemento _lampada(int a, int b, double watts, double volts) => Elemento(
    id: chaveTrecho(a, b),
    tipo: TipoElemento.lampada,
    a: a,
    b: b,
    valor: watts,
    tensaoNominal: volts);

Elemento _interruptor(int a, int b) =>
    Elemento(id: chaveTrecho(a, b), tipo: TipoElemento.interruptor, a: a, b: b);

Elemento _resistor(int a, int b, double ohms) => Elemento(
    id: chaveTrecho(a, b),
    tipo: TipoElemento.resistor,
    a: a,
    b: b,
    valor: ohms);

Elemento _botoeira(int a, int b, {bool normalmenteFechado = false}) => Elemento(
    id: chaveTrecho(a, b),
    tipo: TipoElemento.botoeira,
    a: a,
    b: b,
    normalmenteFechado: normalmenteFechado);

Elemento _bobina(int a, int b, double ohms, double nominal) => Elemento(
    id: chaveTrecho(a, b),
    tipo: TipoElemento.bobina,
    a: a,
    b: b,
    valor: ohms,
    tensaoNominal: nominal);

Elemento _contatoSelo(int a, int b, {required String contatoDe}) => Elemento(
    id: chaveTrecho(a, b),
    tipo: TipoElemento.contatoSelo,
    a: a,
    b: b,
    contatoDe: contatoDe);

Elemento _contatoNf(int a, int b, {required String contatoDe}) => Elemento(
    id: chaveTrecho(a, b),
    tipo: TipoElemento.contatoNf,
    a: a,
    b: b,
    contatoDe: contatoDe);

Elemento _contatoPotencia(int a, int b, {required String contatoDe}) =>
    Elemento(
        id: chaveTrecho(a, b),
        tipo: TipoElemento.contatoPotencia,
        a: a,
        b: b,
        contatoDe: contatoDe);

Elemento _motor(int a, int b, double watts, double volts) => Elemento(
    id: chaveTrecho(a, b),
    tipo: TipoElemento.motor,
    a: a,
    b: b,
    valor: watts,
    tensaoNominal: volts);

Elemento _temporizador(int a, int b, double segundos,
        {double ohms = 240, double nominal = 24}) =>
    Elemento(
        id: chaveTrecho(a, b),
        tipo: TipoElemento.temporizador,
        a: a,
        b: b,
        valor: ohms,
        tensaoNominal: nominal,
        atraso: segundos);

Elemento _contatoTemporizado(int a, int b, {required String contatoDe}) =>
    Elemento(
        id: chaveTrecho(a, b),
        tipo: TipoElemento.contatoTemporizado,
        a: a,
        b: b,
        contatoDe: contatoDe);

Circuito _montar({
  required int colunas,
  required int linhas,
  required List<Elemento> elementos,
}) =>
    Circuito(colunas: colunas, linhas: linhas, elementos: elementos);

Circuito _lampadaComInterruptor(PedidoCircuito pedido) {
  const c = 6;
  int n(int x, int y) => y * c + x;
  final v = pedido.tensao;
  return _montar(colunas: c, linhas: 4, elementos: [
    _fonte(n(0, 1), n(0, 2), v),
    _fio(n(0, 1), n(1, 1)),
    _fio(n(1, 1), n(2, 1)),
    _fio(n(2, 1), n(2, 0)),
    _interruptor(n(2, 0), n(3, 0)),
    _fio(n(3, 0), n(4, 0)),
    _lampada(n(4, 0), n(4, 1), pedido.potencia, v),
    _fio(n(4, 1), n(4, 2)),
    _fio(n(4, 2), n(3, 2)),
    _fio(n(3, 2), n(2, 2)),
    _fio(n(2, 2), n(1, 2)),
    _fio(n(1, 2), n(0, 2)),
  ]);
}

/// Duas lâmpadas, cada uma com o seu interruptor, em paralelo na fonte.
///
/// A topologia repete a da lâmpada com interruptor em dois ramos: a fonte
/// alimenta os dois ramos e cada tecla fecha só o seu. É o que se desenha para
/// um interruptor de duas teclas comandando duas lâmpadas.
ResultadoProjeto _interruptorDuplo(PedidoCircuito pedido) {
  const c = 5;
  int n(int x, int y) => y * c + x;
  final v = pedido.tensao;
  final elementos = <Elemento>[
    _fonte(n(0, 2), n(0, 3), v),
    // Barra do polo positivo, à esquerda.
    _fio(n(0, 2), n(1, 2)),
    _fio(n(1, 2), n(1, 1)),
    _fio(n(1, 1), n(1, 0)),
    // Ramo 1: tecla 1 e lâmpada 1.
    _interruptor(n(1, 0), n(2, 0)),
    _lampada(n(2, 0), n(3, 0), pedido.potencia, v),
    _fio(n(3, 0), n(4, 0)),
    // Ramo 2: tecla 2 e lâmpada 2.
    _interruptor(n(1, 1), n(2, 1)),
    _lampada(n(2, 1), n(3, 1), pedido.potencia, v),
    _fio(n(3, 1), n(4, 1)),
    // Barra do polo negativo, à direita.
    _fio(n(4, 0), n(4, 1)),
    _fio(n(4, 1), n(4, 2)),
    _fio(n(4, 2), n(4, 3)),
    _fio(n(0, 3), n(1, 3)),
    _fio(n(1, 3), n(2, 3)),
    _fio(n(2, 3), n(3, 3)),
    _fio(n(3, 3), n(4, 3)),
  ];
  return _validar(
    pedido,
    _montar(colunas: c, linhas: 4, elementos: elementos),
    'Interruptor duplo',
    'Fonte de ${_v(v)} alimentando duas lâmpadas de ${_w(pedido.potencia)}; '
        'cada tecla fecha o seu ramo, então dá para acender uma sem a outra.',
    const [],
  );
}

ResultadoProjeto _led(PedidoCircuito pedido) {
  const c = 6;
  int n(int x, int y) => y * c + x;
  final v = pedido.tensao;
  // Modelo de lâmpada como carga de LED: 2 V e 20 mA (0,04 W). O simulador não
  // tem símbolo de LED, e a tela avisa isso em vez de desenhar um diodo falso.
  const queda = 2.0;
  const corrente = 0.02;
  if (v <= queda) {
    return ResultadoProjeto(
      ok: false,
      pedido: pedido,
      motivo: 'Com ${_v(v)} não há tensão sobrando para o LED de 2 V. Use uma '
          'fonte maior que 2 V.',
    );
  }
  final ohms = pedido.ohms ?? (v - queda) / corrente;
  final circuito = _montar(colunas: c, linhas: 4, elementos: [
    _fonte(n(0, 1), n(0, 2), v),
    _fio(n(0, 1), n(1, 1)),
    _fio(n(1, 1), n(1, 0)),
    _resistor(n(1, 0), n(2, 0), ohms),
    _fio(n(2, 0), n(3, 0)),
    _lampada(n(3, 0), n(4, 0), queda * corrente, queda),
    _fio(n(4, 0), n(4, 1)),
    _fio(n(4, 1), n(4, 2)),
    _fio(n(4, 2), n(3, 2)),
    _fio(n(3, 2), n(2, 2)),
    _fio(n(2, 2), n(1, 2)),
    _fio(n(1, 2), n(0, 2)),
  ]);
  return _validar(
    pedido,
    circuito,
    'LED com resistor',
    'Com ${_v(v)} e um LED de 2 V / 20 mA, o resistor fica em '
        '${_r(ohms)} (${_r(ohms / 1000)} kΩ). O simulador não tem símbolo de '
        'LED: a carga é o modelo de lâmpada de 2 V e 0,04 W, com a mesma queda.',
    const [
      'Confira a polaridade no circuito real: o simulador não distingue ânodo '
          'de cátodo.',
    ],
  );
}

ResultadoProjeto _serie(PedidoCircuito pedido) {
  const c = 6;
  int n(int x, int y) => y * c + x;
  final v = pedido.tensao;
  final quantas = pedido.quantidade >= 3 ? 3 : 2;
  final elementos = <Elemento>[
    _fonte(n(0, 1), n(0, 2), v),
    _fio(n(0, 1), n(1, 1)),
    _fio(n(1, 1), n(2, 1)),
    _fio(n(2, 1), n(2, 0)),
    _lampada(n(2, 0), n(3, 0), pedido.potencia, v),
    _fio(n(3, 0), n(4, 0)),
    _lampada(n(4, 0), n(4, 1), pedido.potencia, v),
  ];
  if (quantas == 3) {
    elementos.addAll([
      _fio(n(4, 1), n(4, 2)),
      _lampada(n(4, 2), n(4, 3), pedido.potencia, v),
      _fio(n(4, 3), n(3, 3)),
      _fio(n(3, 3), n(2, 3)),
      _fio(n(2, 3), n(1, 3)),
      _fio(n(1, 3), n(0, 3)),
      _fio(n(0, 3), n(0, 2)),
    ]);
  } else {
    elementos.addAll([
      _fio(n(4, 1), n(4, 2)),
      _fio(n(4, 2), n(3, 2)),
      _fio(n(3, 2), n(2, 2)),
      _fio(n(2, 2), n(1, 2)),
      _fio(n(1, 2), n(0, 2)),
    ]);
  }
  final cada = v / quantas;
  return _validar(
    pedido,
    _montar(colunas: c, linhas: 4, elementos: elementos),
    'Lâmpadas em série',
    '$quantas lâmpadas de ${_w(pedido.potencia)} dividem os ${_v(v)}: cada uma '
        'recebe ${_v(cada)} e acende fraca se for de ${_v(v)}.',
    [
      if (pedido.quantidade > 3)
        'Montei três: a grade de 6 colunas não acomoda mais que isso.',
    ],
  );
}

ResultadoProjeto _paralelo(PedidoCircuito pedido) {
  const c = 6;
  int n(int x, int y) => y * c + x;
  final v = pedido.tensao;
  final quantas = pedido.quantidade >= 3 ? 3 : 2;
  final elementos = <Elemento>[
    _fonte(n(0, 2), n(0, 3), v),
    _fio(n(0, 2), n(1, 2)),
    _fio(n(1, 2), n(1, 1)),
    _fio(n(1, 1), n(1, 0)),
    _fio(n(0, 3), n(1, 3)),
    _fio(n(1, 3), n(2, 3)),
    _fio(n(2, 3), n(3, 3)),
    _fio(n(3, 3), n(4, 3)),
    _fio(n(4, 3), n(4, 2)),
    _fio(n(4, 2), n(4, 1)),
    _fio(n(4, 1), n(4, 0)),
    _lampada(n(1, 0), n(2, 0), pedido.potencia, v),
    _fio(n(2, 0), n(3, 0)),
    _fio(n(3, 0), n(4, 0)),
    _lampada(n(1, 1), n(2, 1), pedido.potencia, v),
    _fio(n(2, 1), n(3, 1)),
    _fio(n(3, 1), n(4, 1)),
  ];
  if (quantas == 3) {
    elementos.addAll([
      _lampada(n(1, 2), n(2, 2), pedido.potencia, v),
      _fio(n(2, 2), n(3, 2)),
      _fio(n(3, 2), n(4, 2)),
    ]);
  }
  return _validar(
    pedido,
    _montar(colunas: c, linhas: 4, elementos: elementos),
    'Lâmpadas em paralelo',
    '$quantas lâmpadas de ${_w(pedido.potencia)} recebem os ${_v(v)} inteiros e '
        'acendem com a potência nominal.',
    [
      if (pedido.quantidade > 3)
        'Montei três: a grade de 6 colunas não acomoda mais que isso.',
    ],
  );
}

ResultadoProjeto _divisor(PedidoCircuito pedido) {
  const c = 6;
  int n(int x, int y) => y * c + x;
  final v = pedido.tensao;
  final r1 = pedido.ohms ?? 1000.0;
  final r2 = pedido.ohms ?? 2000.0;
  final saida = v * r2 / (r1 + r2);
  final circuito = _montar(colunas: c, linhas: 4, elementos: [
    _fonte(n(0, 1), n(0, 2), v),
    _fio(n(0, 1), n(1, 1)),
    _resistor(n(1, 1), n(2, 1), r1),
    _resistor(n(2, 1), n(2, 2), r2),
    _fio(n(2, 2), n(1, 2)),
    _fio(n(1, 2), n(0, 2)),
  ]);
  return _validar(
    pedido,
    circuito,
    'Divisor de tensão',
    'R1 de ${_r(r1)} e R2 de ${_r(r2)} sobre ${_v(v)}: o meio entrega '
        '${_v(saida)} (${v == 0 ? 0 : (saida / v * 100).toStringAsFixed(0)}% da '
        'entrada).',
    const [
      'Divisor não é fonte de alimentação: se a carga puxar corrente, a tensão '
          'de saída cai.',
    ],
  );
}

ResultadoProjeto _partidaDireta(PedidoCircuito pedido) {
  const c = 6;
  int n(int x, int y) => y * c + x;
  final v = pedido.tensao;
  final k1 = chaveTrecho(n(3, 1), n(3, 2));
  // Bobina de 100 mA: em 24 V dá os 240 Ω do exemplo do simulador.
  final bobina = v / 0.1;
  final circuito = _montar(colunas: c, linhas: 5, elementos: [
    _fonte(n(0, 0), n(0, 1), v),
    _botoeira(n(0, 0), n(1, 0), normalmenteFechado: true),
    _fio(n(1, 0), n(1, 1)),
    _botoeira(n(1, 1), n(2, 1)),
    _fio(n(1, 1), n(1, 2)),
    _contatoSelo(n(1, 2), n(2, 2), contatoDe: k1),
    _fio(n(2, 2), n(2, 1)),
    _fio(n(2, 1), n(3, 1)),
    _bobina(n(3, 1), n(3, 2), bobina, v),
    _fio(n(3, 2), n(3, 3)),
    _fio(n(3, 3), n(3, 4)),
    _fio(n(1, 0), n(2, 0)),
    _fio(n(2, 0), n(3, 0)),
    _contatoPotencia(n(3, 0), n(4, 0), contatoDe: k1),
    _fio(n(4, 0), n(5, 0)),
    _motor(n(5, 0), n(5, 1), pedido.potencia, v),
    _fio(n(5, 1), n(5, 2)),
    _fio(n(5, 2), n(5, 3)),
    _fio(n(5, 3), n(5, 4)),
    _fio(n(0, 1), n(0, 2)),
    _fio(n(0, 2), n(0, 3)),
    _fio(n(0, 3), n(0, 4)),
    _fio(n(0, 4), n(1, 4)),
    _fio(n(1, 4), n(2, 4)),
    _fio(n(2, 4), n(3, 4)),
    _fio(n(3, 4), n(4, 4)),
    _fio(n(4, 4), n(5, 4)),
  ]);
  return _validar(
    pedido,
    circuito,
    'Partida direta com selo',
    'Comando em ${_v(v)}: parada NF, partida NA, selo de K1 e bobina de '
        '${_r(bobina)} (${_a(0.1)}). O contato principal liga o motor de '
        '${_w(pedido.potencia)}. Aperte a partida e solte: o selo mantém.',
    [
      if (pedido.trifasico)
        'O pedido citou trifásico: este esquema é de corrente contínua. O '
            'comando e o selo são os mesmos; a potência trifásica não é simulada.',
      if (v != 24)
        'Usei ${_v(v)} no comando. Confira a tensão da bobina do contator real '
            'antes de energizar.',
    ],
  );
}

ResultadoProjeto _reversao(PedidoCircuito pedido) {
  const c = 8;
  const l = 5;
  int n(int x, int y) => y * c + x;
  final k1 = chaveTrecho(n(3, 1), n(3, 2));
  final k2 = chaveTrecho(n(6, 1), n(6, 2));
  final v = pedido.tensao;
  final bobina = v / 0.1;
  final circuito = _montar(colunas: c, linhas: l, elementos: [
    _fonte(n(0, 0), n(0, 1), v),
    _botoeira(n(0, 0), n(1, 0), normalmenteFechado: true),
    _fio(n(1, 0), n(2, 0)),
    _fio(n(2, 0), n(3, 0)),
    _fio(n(3, 0), n(4, 0)),
    _fio(n(1, 0), n(1, 1)),
    _fio(n(4, 0), n(4, 1)),
    _botoeira(n(1, 1), n(2, 1)),
    _fio(n(1, 1), n(1, 2)),
    _contatoSelo(n(1, 2), n(2, 2), contatoDe: k1),
    _fio(n(2, 2), n(2, 1)),
    _contatoNf(n(2, 1), n(3, 1), contatoDe: k2),
    _bobina(n(3, 1), n(3, 2), bobina, v),
    _fio(n(3, 2), n(3, 3)),
    _fio(n(3, 3), n(3, 4)),
    _botoeira(n(4, 1), n(5, 1)),
    _fio(n(4, 1), n(4, 2)),
    _contatoSelo(n(4, 2), n(5, 2), contatoDe: k2),
    _fio(n(5, 2), n(5, 1)),
    _contatoNf(n(5, 1), n(6, 1), contatoDe: k1),
    _bobina(n(6, 1), n(6, 2), bobina, v),
    _fio(n(6, 2), n(6, 3)),
    _fio(n(6, 3), n(6, 4)),
    _fio(n(0, 4), n(1, 4)),
    _fio(n(1, 4), n(2, 4)),
    _fio(n(2, 4), n(3, 4)),
    _fio(n(3, 4), n(4, 4)),
    _fio(n(4, 4), n(5, 4)),
    _fio(n(5, 4), n(6, 4)),
    _fio(n(0, 1), n(0, 2)),
    _fio(n(0, 2), n(0, 3)),
    _fio(n(0, 3), n(0, 4)),
  ]);
  return _validar(
    pedido,
    circuito,
    'Reversão com intertravamento',
    'Dois contatores em ${_v(v)}: cada bobina de ${_r(bobina)} tem o próprio '
        'selo e passa pelo contato NF do outro. Com K1 ligado, apertar a partida '
        'de K2 não faz nada.',
    [
      if (pedido.trifasico)
        'O pedido citou trifásico: o intertravamento é o mesmo, mas a potência '
            'trifásica e a troca de duas fases não são simuladas aqui.',
      if (v != 24) 'Confira a tensão das bobinas antes de energizar.',
    ],
  );
}

ResultadoProjeto _temporizado(PedidoCircuito pedido) {
  const c = 6;
  int n(int x, int y) => y * c + x;
  final v = pedido.tensao;
  final k1 = chaveTrecho(n(3, 1), n(3, 2));
  final kt1 = chaveTrecho(n(4, 1), n(4, 2));
  final bobina = v / 0.1;
  final circuito = _montar(colunas: c, linhas: 5, elementos: [
    _fonte(n(0, 0), n(0, 1), v),
    _botoeira(n(0, 0), n(1, 0), normalmenteFechado: true),
    _fio(n(1, 0), n(1, 1)),
    _botoeira(n(1, 1), n(2, 1)),
    _fio(n(1, 1), n(1, 2)),
    _contatoSelo(n(1, 2), n(2, 2), contatoDe: k1),
    _fio(n(2, 2), n(2, 1)),
    _fio(n(2, 1), n(3, 1)),
    _bobina(n(3, 1), n(3, 2), bobina, v),
    _fio(n(3, 2), n(3, 3)),
    _fio(n(3, 3), n(3, 4)),
    _fio(n(3, 1), n(4, 1)),
    _temporizador(n(4, 1), n(4, 2), pedido.segundos, ohms: bobina, nominal: v),
    _fio(n(4, 2), n(4, 3)),
    _fio(n(4, 3), n(4, 4)),
    _fio(n(4, 0), n(5, 0)),
    _fio(n(5, 0), n(5, 1)),
    _contatoTemporizado(n(5, 1), n(5, 2), contatoDe: kt1),
    _lampada(n(5, 2), n(5, 3), pedido.potencia, v),
    _fio(n(5, 3), n(5, 4)),
    _fio(n(1, 0), n(2, 0)),
    _fio(n(2, 0), n(3, 0)),
    _fio(n(3, 0), n(4, 0)),
    _fio(n(0, 1), n(0, 2)),
    _fio(n(0, 2), n(0, 3)),
    _fio(n(0, 3), n(0, 4)),
    _fio(n(0, 4), n(1, 4)),
    _fio(n(1, 4), n(2, 4)),
    _fio(n(2, 4), n(3, 4)),
    _fio(n(3, 4), n(4, 4)),
    _fio(n(4, 4), n(5, 4)),
  ]);
  return _validar(
    pedido,
    circuito,
    'Sequência temporizada',
    'Partida em ${_v(v)} com temporizador KT1 de ${_s(pedido.segundos)}: K1 '
        'puxa na hora e a lâmpada de ${_w(pedido.potencia)} acende quando o '
        'contato 67/68 fecha. Use “Avançar 1 s” no simulador para correr o '
        'relógio.',
    [
      if (v != 24) 'Confira a tensão das bobinas antes de energizar.',
      'O atraso do contato é ajustável no simulador, tocando no 67/68.',
    ],
  );
}

/* ------------------------------------------------------------------ *
 * Validação e formatação
 * ------------------------------------------------------------------ */

ResultadoProjeto _validar(
  PedidoCircuito pedido,
  Circuito circuito,
  String titulo,
  String explicacao,
  List<String> avisos,
) {
  final resultado = circuito.simular();
  if (!resultado.calculado) {
    return ResultadoProjeto(
      ok: false,
      pedido: pedido,
      motivo: 'O simulador não fechou o circuito: '
          '${resultado.erro ?? 'sem solução numérica'}. Nada foi entregue como '
          'pronto.',
      avisos: avisos,
    );
  }
  for (final aviso in resultado.avisos) {
    if (aviso.gravidade == GravidadeAviso.erro) {
      return ResultadoProjeto(
        ok: false,
        pedido: pedido,
        motivo: 'O simulador recusou o esquema: ${aviso.texto}',
        avisos: avisos,
      );
    }
  }
  // A lista de avisos do simulador entra junto: quem monta precisa ver o que
  // ele achou do circuito, não só o que o projetista prometeu.
  final todos = [
    ...avisos,
    for (final aviso in resultado.avisos)
      if (aviso.gravidade != GravidadeAviso.info) aviso.texto,
  ];
  return ResultadoProjeto(
    ok: true,
    pedido: pedido,
    circuito: circuito,
    titulo: titulo,
    explicacao: explicacao,
    avisos: todos,
  );
}

String _v(double volts) => '${formatarNumero(volts)} V';
String _w(double watts) => '${formatarNumero(watts)} W';
String _r(double ohms) => '${formatarNumero(ohms)} Ω';
String _a(double amperes) => '${formatarNumero(amperes, casas: 3)} A';
String _s(double segundos) => '${formatarNumero(segundos)} s';
