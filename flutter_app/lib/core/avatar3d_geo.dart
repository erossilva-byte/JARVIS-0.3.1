/// Avatar 3D — geometria e projeção puras, sem Flutter e sem rede.
///
/// O APK não tem motor 3D nem modelo importado: este arquivo constrói a malha
/// do busto por revolução, gira os vértices com matriz de rotação em três eixos
/// e projeta em perspectiva. Quem pinta é `avatar3d.dart`, com o algoritmo do
/// pintor (face mais distante primeiro). É geometria 3D de verdade, feita aqui,
/// e não uma imagem 2D fingindo profundidade.
library;

import 'dart:math' as math;

/// Ponto ou vetor no espaço do avatar. `y` para cima, `z` para a frente.
class V3 {
  const V3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  static const zero = V3(0, 0, 0);

  V3 operator +(V3 outro) => V3(x + outro.x, y + outro.y, z + outro.z);
  V3 operator -(V3 outro) => V3(x - outro.x, y - outro.y, z - outro.z);
  V3 operator *(double fator) => V3(x * fator, y * fator, z * fator);

  double get comprimento => math.sqrt(x * x + y * y + z * z);

  V3 get normalizado {
    final tamanho = comprimento;
    if (tamanho == 0) return const V3(0, 1, 0);
    return V3(x / tamanho, y / tamanho, z / tamanho);
  }

  double ponto(V3 outro) => x * outro.x + y * outro.y + z * outro.z;

  V3 produtoVetorial(V3 outro) => V3(
        y * outro.z - z * outro.y,
        z * outro.x - x * outro.z,
        x * outro.y - y * outro.x,
      );

  @override
  String toString() =>
      'V3(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, '
      '${z.toStringAsFixed(3)})';
}

/// Gira o ponto: `giro` em volta do eixo vertical, `inclinacao` em volta do
/// eixo horizontal. A ordem é giro e depois inclinação — a mesma do gesto.
V3 girarPonto(V3 ponto, {double giro = 0, double inclinacao = 0}) {
  final cosGiro = math.cos(giro);
  final senGiro = math.sin(giro);
  final xGiro = ponto.x * cosGiro + ponto.z * senGiro;
  final zGiro = -ponto.x * senGiro + ponto.z * cosGiro;

  final cosInc = math.cos(inclinacao);
  final senInc = math.sin(inclinacao);
  final yInc = ponto.y * cosInc - zGiro * senInc;
  final zInc = ponto.y * senInc + zGiro * cosInc;

  return V3(xGiro, yInc, zInc);
}

/// Ponto já projetado na tela, com a profundidade e o fator de perspectiva.
class PontoProjetado {
  const PontoProjetado(this.x, this.y, this.profundidade, this.fator);

  final double x;
  final double y;

  /// `z` no espaço girado: maior é mais perto da câmera.
  final double profundidade;

  /// Fator de perspectiva (> 1 perto, < 1 longe).
  final double fator;

  double get escala => fator;
}

/// Projeta em perspectiva com a câmera em `distancia`, no eixo `z`.
///
/// [escala] é quantos pixels valem uma unidade do avatar. O centro da tela
/// recebe o centro do avatar; `y` cresce para baixo, como na tela.
PontoProjetado projetarPonto(
  V3 ponto, {
  required double centroX,
  required double centroY,
  required double distancia,
  required double escala,
}) {
  final fundo = math.max(0.35, distancia - ponto.z);
  final fator = distancia / fundo;
  return PontoProjetado(
    centroX + ponto.x * escala * fator,
    centroY - ponto.y * escala * fator,
    ponto.z,
    fator,
  );
}

/// Uma face da malha: índices dos vértices, em ordem.
class FaceMalha {
  const FaceMalha(this.indices);

  final List<int> indices;
}

/// Malha fechada de vértices e faces.
class Malha {
  const Malha(this.vertices, this.faces);

  final List<V3> vertices;
  final List<FaceMalha> faces;

  int get quads => faces.length;
}

/// Silhueta do busto, do peito ao topo da cabeça: pares (altura, raio).
///
/// Um perfil só, revolvido em volta do eixo vertical, dá o corpo inteiro —
/// peito largo, ombros, pescoço fino e cabeça. É o mesmo truque de um torno:
/// menos vértices e nenhuma emenda entre partes.
const perfilDoBusto = <List<double>>[
  [-1.02, 0.34],
  [-0.90, 0.44],
  [-0.66, 0.51],
  [-0.44, 0.56],
  [-0.22, 0.585],
  [-0.04, 0.55],
  [0.05, 0.42],
  [0.13, 0.265],
  [0.26, 0.195],
  [0.38, 0.215],
  [0.46, 0.275],
  [0.53, 0.345],
  [0.62, 0.385],
  [0.74, 0.395],
  [0.86, 0.360],
  [0.96, 0.285],
  [1.04, 0.160],
  [1.09, 0.0],
];

/// Raio do perfil na altura `y`, com interpolação suavizada entre os pontos.
double raioDoPerfil(double y) {
  if (y <= perfilDoBusto.first[0]) return perfilDoBusto.first[1];
  if (y >= perfilDoBusto.last[0]) return perfilDoBusto.last[1];
  for (var i = 0; i < perfilDoBusto.length - 1; i++) {
    final inicio = perfilDoBusto[i];
    final fim = perfilDoBusto[i + 1];
    if (y >= inicio[0] && y <= fim[0]) {
      final intervalo = fim[0] - inicio[0];
      if (intervalo <= 0) return fim[1];
      final bruto = (y - inicio[0]) / intervalo;
      // Suaviza a emenda entre trechos sem precisar de mais pontos de controle.
      final t = 0.5 - 0.5 * math.cos(bruto * math.pi);
      return inicio[1] + (fim[1] - inicio[1]) * t;
    }
  }
  return perfilDoBusto.last[1];
}

/// Malha do busto por revolução do [perfilDoBusto].
///
/// [segmentos] é a volta completa (mais segmentos, mais redondo) e [aneis] a
/// divisão vertical. 28 × 64 dá cerca de 1.800 faces — suficiente para ler como
/// 3D e leve para desenhar a cada quadro.
Malha malhaDoBusto({int segmentos = 28, int aneis = 64}) {
  final vertices = <V3>[];
  final faces = <FaceMalha>[];

  final alturaInicial = perfilDoBusto.first[0];
  final alturaFinal = perfilDoBusto.last[0];

  for (var anel = 0; anel <= aneis; anel++) {
    final t = anel / aneis;
    final y = alturaInicial + (alturaFinal - alturaInicial) * t;
    final raio = raioDoPerfil(y);
    for (var segmento = 0; segmento < segmentos; segmento++) {
      final angulo = segmento / segmentos * math.pi * 2;
      vertices.add(V3(math.cos(angulo) * raio, y, math.sin(angulo) * raio));
    }
  }

  for (var anel = 0; anel < aneis; anel++) {
    for (var segmento = 0; segmento < segmentos; segmento++) {
      final proximo = (segmento + 1) % segmentos;
      final a = anel * segmentos + segmento;
      final b = anel * segmentos + proximo;
      final c = (anel + 1) * segmentos + proximo;
      final d = (anel + 1) * segmentos + segmento;
      // Ordem anti-horária vista de fora: a normal aponta para fora do busto.
      faces.add(FaceMalha([a, d, c, b]));
    }
  }

  return Malha(vertices, faces);
}

/// Normal da face, no espaço girado (média dos vértices já girados).
V3 normalDaFace(Malha malha, FaceMalha face, List<V3> girados) {
  if (face.indices.length < 3) return const V3(0, 0, 1);
  final a = girados[face.indices[0]];
  final b = girados[face.indices[1]];
  final c = girados[face.indices[2]];
  return (b - a).produtoVetorial(c - a).normalizado;
}

/// Centro (média dos vértices) da face, para ordenar por profundidade.
V3 centroDaFace(FaceMalha face, List<V3> girados) {
  var soma = V3.zero;
  for (final indice in face.indices) {
    soma = soma + girados[indice];
  }
  return soma * (1 / face.indices.length);
}

/// Posições dos olhos no rosto, à frente da superfície da cabeça.
const olhosDoAvatar = <V3>[
  V3(-0.132, 0.655, 0.352),
  V3(0.132, 0.655, 0.352),
];

/// Pontos da boca: duas curvas (lábio de cima e de baixo), abertas por
/// [abertura] (0 fechada, 1 bem aberta). Acompanha o giro junto com a cabeça.
List<List<V3>> pontosDaBoca(double abertura, {int divisoes = 10}) {
  final abre = abertura.clamp(0.0, 1.0);
  final cima = <V3>[];
  final baixo = <V3>[];
  for (var i = 0; i <= divisoes; i++) {
    final t = i / divisoes;
    final x = -0.115 + 0.23 * t;
    final curva = math.sin(t * math.pi);
    final yCentro = 0.520 - 0.022 * curva;
    final meiaAbertura = 0.008 + 0.055 * abre * curva;
    final z = 0.352 - 0.030 * (x.abs() / 0.115);
    cima.add(V3(x, yCentro + meiaAbertura, z));
    baixo.add(V3(x, yCentro - meiaAbertura, z));
  }
  return [cima, baixo];
}

/// Anel do reator no peito: círculo plano à frente da superfície do peito.
List<V3> anelDoReator({double raio = 0.125, int pontos = 24}) {
  final lista = <V3>[];
  for (var i = 0; i < pontos; i++) {
    final angulo = i / pontos * math.pi * 2;
    lista.add(V3(
      math.cos(angulo) * raio,
      -0.320 + math.sin(angulo) * raio,
      0.520,
    ));
  }
  return lista;
}

/// Órbitas do holograma: círculos inclinados em volta do busto.
List<V3> orbitaDoAvatar(
  double fase, {
  double raio = 1.28,
  double inclinacao = 0.55,
  int pontos = 48,
}) {
  final lista = <V3>[];
  final cosInc = math.cos(inclinacao);
  final senInc = math.sin(inclinacao);
  for (var i = 0; i < pontos; i++) {
    final angulo = i / pontos * math.pi * 2 + fase;
    final x = math.cos(angulo) * raio;
    final z = math.sin(angulo) * raio * cosInc;
    final y = math.sin(angulo) * raio * senInc;
    lista.add(V3(x, y, z));
  }
  return lista;
}

/// Partículas em volta do busto: posições determinísticas para a fase [t].
List<V3> particulasDoAvatar(double t, {int quantidade = 46}) {
  final lista = <V3>[];
  for (var i = 0; i < quantidade; i++) {
    final angulo = i * 2.39996 + t * 0.35;
    final raio = 1.12 + 0.10 * math.sin(t * 1.7 + i);
    final altura = math.sin(i * 1.7 + t * 0.9) * 0.85;
    lista.add(V3(
      math.cos(angulo) * raio,
      altura,
      math.sin(angulo) * raio * 0.85,
    ));
  }
  return lista;
}

/// Abertura da boca para o estado: muda devagar, sem depender de áudio real.
double aberturaDaBoca(double t, {required bool falando}) {
  if (!falando) return 0.08;
  // Duas senoides de períodos diferentes: a boca não fica metronômica.
  final onda = 0.55 + 0.30 * math.sin(t * 9.1) + 0.15 * math.sin(t * 15.7);
  return onda.clamp(0.0, 1.0);
}
