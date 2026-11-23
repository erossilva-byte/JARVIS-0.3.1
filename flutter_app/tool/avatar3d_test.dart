import 'dart:io';
import 'dart:math' as math;

import 'package:jarvis_nova/core/avatar3d_geo.dart';

double _perto(double a, double b, [double tolerancia = 1e-9]) =>
    (a - b).abs() <= tolerancia ? 0 : 1;

void main() {
  // 1. O giro preserva o comprimento: é rotação, não escala.
  const ponto = V3(0.3, -0.4, 0.9);
  for (final giro in [0.0, 0.8, math.pi, -2.2]) {
    for (final inclinacao in [0.0, 0.4, -0.7]) {
      final girado = girarPonto(ponto, giro: giro, inclinacao: inclinacao);
      assert(_perto(girado.comprimento, ponto.comprimento, 1e-9) == 0,
          'giro mudou o comprimento: $girado');
    }
  }
  final meiaVolta = girarPonto(ponto, giro: math.pi);
  assert(_perto(meiaVolta.x, -ponto.x, 1e-9) == 0 &&
          _perto(meiaVolta.z, -ponto.z, 1e-9) == 0,
      'meia volta não espelhou x e z: $meiaVolta');

  // 2. Projeção: o centro vai para o centro e o que está perto cresce.
  final centro = projetarPonto(const V3(0, 0, 0),
      centroX: 100, centroY: 50, distancia: 4.6, escala: 100);
  assert(_perto(centro.x, 100) == 0 && _perto(centro.y, 50) == 0,
      'centro projetado fora do lugar');
  final perto = projetarPonto(const V3(0.5, 0, 1.5),
      centroX: 0, centroY: 0, distancia: 4.6, escala: 100);
  final longe = projetarPonto(const V3(0.5, 0, -1.5),
      centroX: 0, centroY: 0, distancia: 4.6, escala: 100);
  assert(perto.fator > longe.fator, 'perspectiva não cresce de perto');
  assert(perto.x > longe.x, 'x do ponto perto deveria ser maior');
  final acima = projetarPonto(const V3(0, 1, 0),
      centroX: 0, centroY: 0, distancia: 4.6, escala: 100);
  assert(acima.y < 0, 'y para cima deveria ir para o topo da tela');

  // 3. Malha do busto: índices válidos e fechamento por revolução.
  final malha = malhaDoBusto(segmentos: 24, aneis: 40);
  assert(malha.vertices.length == 24 * 41, 'vértices fora da conta');
  assert(malha.faces.length == 24 * 40, 'faces fora da conta');
  for (final face in malha.faces) {
    assert(face.indices.length == 4, 'face não é quadrilátero');
    for (final indice in face.indices) {
      assert(indice >= 0 && indice < malha.vertices.length,
          'índice de vértice inválido: $indice');
    }
  }
  // O topo da cabeça fecha em zero e o peito é mais largo que o pescoço.
  assert(raioDoPerfil(1.2) == 0, 'topo da cabeça não fecha');
  assert(raioDoPerfil(0.74) > raioDoPerfil(0.30),
      'cabeça deveria ser mais larga que o pescoço');
  assert(raioDoPerfil(-0.60) > raioDoPerfil(0.30),
      'peito deveria ser mais largo que o pescoço');
  assert(_perto(raioDoPerfil(-5), raioDoPerfil(perfilDoBusto.first[0])) == 0,
      'altura abaixo do perfil não foi limitada');
  assert(_perto(raioDoPerfil(5), 0) == 0,
      'altura acima do perfil não foi limitada');

  // 4. A normal da face é unitária e aponta para fora num ponto conhecido.
  final girados = [
    for (final vertice in malha.vertices) girarPonto(vertice),
  ];
  final normal = normalDaFace(malha, malha.faces.first, girados);
  assert(_perto(normal.comprimento, 1, 1e-9) == 0,
      'normal não é unitária: ${normal.comprimento}');
  final centroFace = centroDaFace(malha.faces.first, girados);
  assert(normal.ponto(centroFace) > 0,
      'normal da primeira face aponta para dentro');

  // 5. Rosto: olhos simétricos e fora da superfície; boca abre com o valor.
  assert(olhosDoAvatar.length == 2, 'esperava dois olhos');
  assert(_perto(olhosDoAvatar[0].x, -olhosDoAvatar[1].x) == 0,
      'olhos não estão simétricos em x');
  assert(olhosDoAvatar.first.z > raioDoPerfil(olhosDoAvatar.first.y) * 0.8,
      'olho afundado na cabeça');
  final fechada = pontosDaBoca(0);
  final aberta = pontosDaBoca(1);
  final alturaFechada = fechada[0][5].y - fechada[1][5].y;
  final alturaAberta = aberta[0][5].y - aberta[1][5].y;
  assert(alturaAberta > alturaFechada * 3,
      'boca aberta não abre o suficiente: $alturaAberta');
  assert(fechada[0].length == 11 && fechada[1].length == 11,
      'curvas da boca com número errado de pontos');

  // 6. A boca só fala quando o estado é falando.
  final calada = aberturaDaBoca(0.3, falando: false);
  assert(calada < 0.1, 'boca em espera não deveria abrir: $calada');
  var minimo = 1.0;
  var maximo = 0.0;
  for (var i = 0; i < 40; i++) {
    final valor = aberturaDaBoca(i * 0.07, falando: true);
    assert(valor >= 0 && valor <= 1, 'abertura fora de 0..1: $valor');
    minimo = math.min(minimo, valor);
    maximo = math.max(maximo, valor);
  }
  assert(maximo - minimo > 0.3, 'a boca falando não varia: $minimo..$maximo');

  // 7. Reator, órbitas e partículas: pontos no espaço, nada em 2D fixo.
  final reator = anelDoReator();
  assert(reator.length == 24, 'anel do reator com pontos errados');
  for (final pontoAnel in reator) {
    assert(_perto(pontoAnel.z, 0.520) == 0, 'reator saiu do plano do peito');
  }
  final orbita = orbitaDoAvatar(0.4, raio: 1.2, inclinacao: 0.5);
  assert(orbita.length > 20, 'órbita com poucos pontos');
  for (final pontoOrbita in orbita) {
    assert(_perto(pontoOrbita.comprimento, 1.2, 1e-6) == 0,
        'órbita não está no raio pedido');
  }
  final particulas = particulasDoAvatar(0.2, quantidade: 12);
  assert(particulas.length == 12, 'partículas com quantidade errada');
  assert(particulas.toSet().length == 12,
      'partículas repetidas: o desenho ficaria estático');

  stdout.writeln('OK: giro preserva comprimento, projeção em perspectiva, '
      '${malha.faces.length} faces, rosto, boca, reator e órbitas conferidos');
}
