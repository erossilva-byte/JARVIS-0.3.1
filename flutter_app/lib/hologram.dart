import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'ui_common.dart';

enum HologramEstado { espera, ouvindo, processando, falando, erro }

class HologramPainter extends CustomPainter {
  HologramPainter(this.t, this.pointer,
      {this.estado = HologramEstado.espera, this.fundo = true});

  final double t;
  final Offset pointer;
  final HologramEstado estado;

  /// Malha e vinheta de fundo; desligado na máscara flutuante, que é transparente.
  final bool fundo;

  static final _Esfera _esfera = _criarEsfera();

  Color get _cor => switch (estado) {
        HologramEstado.espera => cyan,
        HologramEstado.ouvindo => const Color(0xFF8FF4FF),
        HologramEstado.processando => const Color(0xFFB5E9FF),
        HologramEstado.falando => const Color(0xFFD4FAFF),
        HologramEstado.erro => const Color(0xFFFF7166),
      };

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(
      size.width / 2 + pointer.dx * 20,
      size.height / 2 + pointer.dy * 16,
    );
    final raio = size.shortestSide * .34;
    final spin =
        t * math.pi * 2 * (estado == HologramEstado.processando ? 1.7 : 1);
    final cor = _cor;

    if (fundo) {
      _fundo(canvas, size, centro, raio, cor);
      _vinheta(canvas, size, centro, raio);
    }
    _esferaGeodesica(canvas, centro, raio, spin, cor);
    _aneis(canvas, centro, raio, spin, cor);
    _reator(canvas, centro, raio, spin, cor);
    _particulas(canvas, centro, raio, spin, cor);
    _marcas(canvas, centro, raio, spin, cor);
    _estado(canvas, centro, raio, spin, cor);
  }

  void _fundo(Canvas canvas, Size size, Offset centro, double raio, Color cor) {
    // Malha hexagonal sutil, sem competir com a esfera.
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .55
      ..color = cor.withValues(alpha: .055);
    for (var linha = -2; linha <= 2; linha++) {
      for (var coluna = -2; coluna <= 2; coluna++) {
        final cx =
            centro.dx + coluna * raio * .52 + (linha.isOdd ? raio * .26 : 0);
        final cy = centro.dy + linha * raio * .45;
        final path = Path();
        for (var i = 0; i < 6; i++) {
          final a = math.pi / 3 * i + math.pi / 6;
          final x = cx + math.cos(a) * raio * .28;
          final y = cy + math.sin(a) * raio * .28;
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, p);
      }
    }

    final halo = Paint()
      ..shader = RadialGradient(
        colors: [
          cor.withValues(alpha: estado == HologramEstado.erro ? .12 : .14),
          const Color(0xFF368BFF).withValues(alpha: .035),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: centro, radius: raio * 1.35));
    canvas.drawCircle(centro, raio * 1.35, halo);
  }

  void _vinheta(Canvas canvas, Size size, Offset centro, double raio) {
    final vinheta = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF02070D).withValues(alpha: .38),
        ],
        stops: const [.58, 1],
      ).createShader(Rect.fromCircle(center: centro, radius: raio * 1.7));
    canvas.drawCircle(centro, raio * 1.7, vinheta);
  }

  void _esferaGeodesica(
    Canvas canvas,
    Offset centro,
    double raio,
    double spin,
    Color cor,
  ) {
    final ax = .48 + pointer.dy * .55;
    final ay = spin + pointer.dx * .7;
    final cy = math.cos(ay), sy = math.sin(ay);
    final cx = math.cos(ax), sx = math.sin(ax);
    final pontos = <Offset>[];

    for (final v in _esfera.vertices) {
      final x = v[0] * raio;
      final y = v[1] * raio;
      final z = v[2] * raio;
      final x1 = x * cy + z * sy;
      final z1 = -x * sy + z * cy;
      final y1 = y * cx - z1 * sx;
      final z2 = y * sx + z1 * cx;
      final perspectiva = (raio * 3.7) / (raio * 3.7 + z2);
      pontos.add(
          Offset(centro.dx + x1 * perspectiva, centro.dy + y1 * perspectiva));
    }

    for (final aresta in _esfera.arestas) {
      final a = aresta[0];
      final b = aresta[1];
      final zMedio = (_esfera.vertices[a][2] + _esfera.vertices[b][2]) / 2;
      final frente = ((zMedio + 1) / 2).clamp(0.0, 1.0);
      final brilho = .12 + frente * .62;
      canvas.drawLine(
        pontos[a],
        pontos[b],
        Paint()
          ..color = cor.withValues(alpha: brilho * .28)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        pontos[a],
        pontos[b],
        Paint()
          ..color = Color.lerp(cor, Colors.white, frente * .45)!
              .withValues(alpha: brilho)
          ..strokeWidth = .55 + frente * .75
          ..strokeCap = StrokeCap.round,
      );
    }

    // Nós nos vértices da malha, com mais luz na frente.
    for (var i = 0; i < pontos.length; i++) {
      final z = _esfera.vertices[i][2];
      final frente = ((z + 1) / 2).clamp(0.0, 1.0);
      canvas.drawCircle(
        pontos[i],
        .8 + frente * 1.1,
        Paint()..color = Colors.white.withValues(alpha: .18 + frente * .55),
      );
    }
  }

  void _aneis(
      Canvas canvas, Offset centro, double raio, double spin, Color cor) {
    final aneis = [
      (raio * .72, .22, spin * .12),
      (raio * .85, -.17, -spin * .09),
      (raio * 1.08, .38, spin * .06),
    ];
    for (final (r, inclinacao, rotacao) in aneis) {
      canvas.save();
      canvas.translate(centro.dx, centro.dy);
      canvas.rotate(rotacao + pointer.dx * .15);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: r * 2,
        height: r * 2 * math.cos(inclinacao),
      );
      canvas.drawOval(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..color = cor.withValues(alpha: .28),
      );
      canvas.restore();
    }
  }

  void _reator(
      Canvas canvas, Offset centro, double raio, double spin, Color cor) {
    const segmentos = 44;
    final rect = Rect.fromCircle(center: centro, radius: raio * .99);
    for (var i = 0; i < segmentos; i++) {
      final pulso = .35 + .55 * (0.5 + 0.5 * math.sin(spin * 3 + i * .42));
      final inicio = i * math.pi * 2 / segmentos;
      final path = Path()..addArc(rect, inicio, math.pi * 2 / segmentos * .58);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i % 5 == 0 ? 3.2 : 1.5
          ..strokeCap = StrokeCap.round
          ..color = cor.withValues(alpha: pulso),
      );
    }

    final anelInterno = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: .30);
    canvas.drawCircle(centro, raio * .55, anelInterno);
    canvas.drawCircle(centro, raio * .43, anelInterno);

    final scan = Paint()
      ..color = cor.withValues(alpha: .14)
      ..strokeWidth = 1;
    for (var i = -4; i <= 4; i++) {
      final y = centro.dy + i * raio * .055 + math.sin(spin + i) * 1.5;
      canvas.drawLine(
        Offset(centro.dx - raio * .38, y),
        Offset(centro.dx + raio * .38, y),
        scan,
      );
    }
  }

  void _particulas(
      Canvas canvas, Offset centro, double raio, double spin, Color cor) {
    for (var i = 0; i < 58; i++) {
      final angulo = i * 2.39996 + spin * .22;
      final orbita = raio * (1.12 + .08 * math.sin(spin * 1.7 + i));
      final x = math.cos(angulo) * orbita;
      final y = math.sin(angulo) * orbita * .72;
      final brilho = .25 + .55 * (0.5 + 0.5 * math.sin(spin * 2 + i));
      canvas.drawCircle(
        Offset(centro.dx + x, centro.dy + y),
        (i % 7 == 0 ? 2.2 : 1.1) *
            (estado == HologramEstado.ouvindo ? 1.35 : 1),
        Paint()..color = cor.withValues(alpha: brilho),
      );
    }
  }

  void _marcas(
      Canvas canvas, Offset centro, double raio, double spin, Color cor) {
    for (var i = 0; i < 60; i++) {
      final a = i * math.pi * 2 / 60 + spin * .03;
      final comprimento = i % 5 == 0 ? raio * .055 : raio * .026;
      final inicio = Offset(
        centro.dx + math.cos(a) * raio * 1.16,
        centro.dy + math.sin(a) * raio * 1.16,
      );
      final fim = Offset(
        centro.dx + math.cos(a) * (raio * 1.16 + comprimento),
        centro.dy + math.sin(a) * (raio * 1.16 + comprimento),
      );
      canvas.drawLine(
        inicio,
        fim,
        Paint()
          ..color = cor.withValues(alpha: i % 5 == 0 ? .50 : .22)
          ..strokeWidth = i % 5 == 0 ? 1.3 : .7,
      );
    }
  }

  void _estado(
      Canvas canvas, Offset centro, double raio, double spin, Color cor) {
    switch (estado) {
      case HologramEstado.espera:
        _pulso(canvas, centro, raio, spin * .55, cor, .10);
      case HologramEstado.ouvindo:
        for (var i = 0; i < 3; i++) {
          final fase = (spin * .55 + i / 3) % 1;
          canvas.drawCircle(
            centro,
            raio * (.56 + fase * .42),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = cor.withValues(alpha: (1 - fase) * .22),
          );
        }
        _pulso(canvas, centro, raio, spin * 1.4, cor, .09);
      case HologramEstado.processando:
        _pulso(canvas, centro, raio, spin * 2.2, cor, .13);
        final arco = Rect.fromCircle(center: centro, radius: raio * 1.1);
        canvas.drawArc(
          arco,
          spin,
          math.pi * .52,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..color = Colors.white.withValues(alpha: .50),
        );
      case HologramEstado.falando:
        for (var i = 0; i < 7; i++) {
          final y = centro.dy + raio * .50 + i * 3.5;
          final amplitude = 2 + 6 * math.sin(spin * 5 + i * .9).abs();
          canvas.drawLine(
            Offset(centro.dx - amplitude, y),
            Offset(centro.dx + amplitude, y),
            Paint()
              ..color = cor.withValues(alpha: .30)
              ..strokeWidth = 1.1,
          );
        }
      case HologramEstado.erro:
        _trianguloErro(canvas, centro, raio, cor);
    }
  }

  void _pulso(Canvas canvas, Offset centro, double raio, double fase, Color cor,
      double alpha) {
    final onda = (fase % 1);
    canvas.drawCircle(
      centro,
      raio * (.60 + onda * .34),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = cor.withValues(alpha: alpha * (1 - onda)),
    );
  }

  void _trianguloErro(Canvas canvas, Offset centro, double raio, Color cor) {
    final topo = Offset(centro.dx, centro.dy - raio * .22);
    final esquerda = Offset(centro.dx - raio * .17, centro.dy + raio * .08);
    final direita = Offset(centro.dx + raio * .17, centro.dy + raio * .08);
    final path = Path()
      ..moveTo(topo.dx, topo.dy)
      ..lineTo(esquerda.dx, esquerda.dy)
      ..lineTo(direita.dx, direita.dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = cor.withValues(alpha: .92),
    );
    canvas.drawLine(
      Offset(centro.dx, centro.dy - raio * .10),
      Offset(centro.dx, centro.dy + raio * .015),
      Paint()
        ..color = cor
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(centro.dx, centro.dy + raio * .052),
      1.5,
      Paint()..color = cor,
    );
  }

  @override
  bool shouldRepaint(covariant HologramPainter old) =>
      old.t != t || old.pointer != pointer || old.estado != estado;
}

class _Esfera {
  const _Esfera(this.vertices, this.arestas);

  final List<List<double>> vertices;
  final List<List<int>> arestas;
}

_Esfera _criarEsfera() {
  final phi = (1 + math.sqrt(5)) / 2;
  var vertices = <List<double>>[
    [-1, phi, 0],
    [1, phi, 0],
    [-1, -phi, 0],
    [1, -phi, 0],
    [0, -1, phi],
    [0, 1, phi],
    [0, -1, -phi],
    [0, 1, -phi],
    [phi, 0, -1],
    [phi, 0, 1],
    [-phi, 0, -1],
    [-phi, 0, 1],
  ];
  vertices = vertices.map((v) {
    final norma = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    return [v[0] / norma, v[1] / norma, v[2] / norma];
  }).toList();

  var faces = <List<int>>[
    [0, 11, 5],
    [0, 5, 1],
    [0, 1, 7],
    [0, 7, 10],
    [0, 10, 11],
    [1, 5, 9],
    [5, 11, 4],
    [11, 10, 2],
    [10, 7, 6],
    [7, 1, 8],
    [3, 9, 4],
    [3, 4, 2],
    [3, 2, 6],
    [3, 6, 8],
    [3, 8, 9],
    [4, 9, 5],
    [2, 4, 11],
    [6, 2, 10],
    [8, 6, 7],
    [9, 8, 1],
  ];

  final cache = <String, int>{};
  int meio(int a, int b) {
    final chave = a < b ? '$a:$b' : '$b:$a';
    final existente = cache[chave];
    if (existente != null) return existente;
    final ponto = [
      (vertices[a][0] + vertices[b][0]) / 2,
      (vertices[a][1] + vertices[b][1]) / 2,
      (vertices[a][2] + vertices[b][2]) / 2,
    ];
    final norma = math.sqrt(
      ponto[0] * ponto[0] + ponto[1] * ponto[1] + ponto[2] * ponto[2],
    );
    vertices.add([ponto[0] / norma, ponto[1] / norma, ponto[2] / norma]);
    final indice = vertices.length - 1;
    cache[chave] = indice;
    return indice;
  }

  final subdivididas = <List<int>>[];
  for (final face in faces) {
    final a = meio(face[0], face[1]);
    final b = meio(face[1], face[2]);
    final c = meio(face[2], face[0]);
    subdivididas.addAll([
      [face[0], a, c],
      [face[1], b, a],
      [face[2], c, b],
      [a, b, c],
    ]);
  }
  faces = subdivididas;

  final arestas = <String, List<int>>{};
  for (final face in faces) {
    for (var i = 0; i < 3; i++) {
      final a = face[i];
      final b = face[(i + 1) % 3];
      final chave = a < b ? '$a:$b' : '$b:$a';
      arestas[chave] = [a, b];
    }
  }
  return _Esfera(vertices, arestas.values.toList());
}
