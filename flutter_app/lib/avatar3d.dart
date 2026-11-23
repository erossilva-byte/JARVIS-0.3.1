import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'core/avatar3d_geo.dart';
import 'ui_common.dart';

/// Estados que o avatar sabe mostrar. São os mesmos da conversa: espera,
/// ouvindo, pensando, falando e erro.
enum AvatarEstado { espera, ouvindo, pensando, falando, erro }

extension AvatarEstadoTexto on AvatarEstado {
  String get rotulo => switch (this) {
        AvatarEstado.espera => 'Em espera',
        AvatarEstado.ouvindo => 'Ouvindo',
        AvatarEstado.pensando => 'Pensando',
        AvatarEstado.falando => 'Falando',
        AvatarEstado.erro => 'Erro',
      };

  String get frase => switch (this) {
        AvatarEstado.espera => 'Respira devagar e olha para a frente.',
        AvatarEstado.ouvindo => 'Anéis de escuta abertos e olhos atentos.',
        AvatarEstado.pensando => 'Gira mais rápido e aperta os olhos.',
        AvatarEstado.falando => 'A boca abre no ritmo da fala.',
        AvatarEstado.erro => 'A luz fica vermelha; nada mais se mexe.',
      };
}

/// Desenha o busto em 3D com o algoritmo do pintor.
///
/// Cada quadro: gira os vértices ([girarPonto]), projeta em perspectiva
/// ([projetarPonto]), ordena as faces da mais distante para a mais próxima e
/// pinta com luz vinda da frente-esquerda. Olhos, boca, reator, órbitas e
/// partículas são pontos 3D projetados do mesmo jeito — por isso giram junto.
class Avatar3DPainter extends CustomPainter {
  Avatar3DPainter({
    required this.t,
    required this.estado,
    this.giro = 0,
    this.inclinacao = 0,
    this.autoGiro = true,
  });

  /// Fase da animação, de 0 a 1, repetida pelo controlador da tela.
  final double t;
  final AvatarEstado estado;

  /// Giro aplicado pelo gesto, somado ao balanço automático.
  final double giro;
  final double inclinacao;
  final bool autoGiro;

  static final Malha _malha = malhaDoBusto();
  static final V3 _luz = const V3(-0.42, 0.55, 0.72).normalizado;

  Color get _cor => switch (estado) {
        AvatarEstado.espera => cyan,
        AvatarEstado.ouvindo => const Color(0xFF8FF4FF),
        AvatarEstado.pensando => const Color(0xFFB5E9FF),
        AvatarEstado.falando => const Color(0xFFD4FAFF),
        AvatarEstado.erro => const Color(0xFFFF7166),
      };

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height * 0.52);
    final escala = size.shortestSide * 0.33;
    const distancia = 4.6;
    final cor = _cor;

    final balanco = autoGiro ? math.sin(t * math.pi * 2) * 0.55 : 0.0;
    final giroTotal = giro + balanco;
    final inclinacaoTotal = inclinacao + math.sin(t * math.pi * 2 + 1.1) * 0.02;
    final respiracao = math.sin(t * math.pi * 2) * 0.012;

    PontoProjetado projetar(V3 ponto) => projetarPonto(
          ponto,
          centroX: centro.dx,
          centroY: centro.dy + respiracao * escala,
          distancia: distancia,
          escala: escala,
        );

    _fundo(canvas, size, centro, escala, cor);
    _piso(canvas, projetar, escala, cor);

    final girados = <V3>[
      for (final vertice in _malha.vertices)
        girarPonto(vertice, giro: giroTotal, inclinacao: inclinacaoTotal),
    ];
    final projetados = <PontoProjetado>[
      for (final vertice in girados) projetar(vertice),
    ];

    final ordenadas = <({FaceMalha face, double z})>[
      for (final face in _malha.faces)
        (face: face, z: centroDaFace(face, girados).z),
    ]..sort((a, b) => a.z.compareTo(b.z));

    final contorno = Paint()..style = PaintingStyle.stroke;

    for (final entrada in ordenadas) {
      final face = entrada.face;
      final normal = normalDaFace(_malha, face, girados);
      final luz = math.max(0.0, normal.ponto(_luz));
      final aresta = 1 - normal.z.abs();
      final frente = normal.z > 0.02;

      final caminho = Path();
      final primeiro = projetados[face.indices.first];
      caminho.moveTo(primeiro.x, primeiro.y);
      for (var i = 1; i < face.indices.length; i++) {
        final ponto = projetados[face.indices[i]];
        caminho.lineTo(ponto.x, ponto.y);
      }
      caminho.close();

      // Malha aberta em vez de superfície cheia: 1.800 faces translúcidas
      // empilhadas viravam uma névoa branca e escondiam o formato. O traço
      // iluminado desenha o busto com o relevo da luz.
      if (frente) {
        contorno
          ..color = Color.lerp(cor, Colors.white, luz * 0.55)!.withValues(
            alpha: 0.07 + luz * 0.34 + aresta * 0.05,
          )
          ..strokeWidth = 0.45 + luz * 0.65;
      } else {
        contorno
          ..color = cor.withValues(alpha: 0.045 + luz * 0.06)
          ..strokeWidth = 0.45;
      }
      canvas.drawPath(caminho, contorno);
    }

    _olhos(canvas, projetar, escala, giroTotal);
    _boca(canvas, projetar, giroTotal);
    _reator(canvas, projetar, escala, cor, giroTotal);
    _orbitas(canvas, projetar, cor);
    _particulas(canvas, projetar, cor);
    _varredura(canvas, projetar, cor);
    _estadoExtra(canvas, projetar, escala, cor, giroTotal);
  }

  void _fundo(Canvas canvas, Size size, Offset centro, double escala, Color cor) {
    final halo = Paint()
      ..shader = RadialGradient(
        colors: [
          cor.withValues(alpha: estado == AvatarEstado.erro ? .12 : .16),
          const Color(0xFF368BFF).withValues(alpha: .045),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: centro, radius: escala * 2.5));
    canvas.drawCircle(centro, escala * 2.5, halo);

    // Malha de fundo: dá a sensação de sala, não muda com o giro.
    final grade = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .5
      ..color = cor.withValues(alpha: .045);
    for (var i = -3; i <= 3; i++) {
      final y = centro.dy + i * escala * .34;
      canvas.drawLine(
        Offset(centro.dx - escala * 1.15, y),
        Offset(centro.dx + escala * 1.15, y),
        grade,
      );
    }
  }

  void _piso(
    Canvas canvas,
    PontoProjetado Function(V3) projetar,
    double escala,
    Color cor,
  ) {
    final centro = projetar(const V3(0, -1.02, 0));
    final retangulo = Rect.fromCenter(
      center: Offset(centro.x, centro.y),
      width: escala * 1.5,
      height: escala * 0.32,
    );
    canvas.drawOval(
      retangulo,
      Paint()
        ..shader = RadialGradient(
          colors: [
            cor.withValues(alpha: .22),
            cor.withValues(alpha: .04),
            Colors.transparent,
          ],
        ).createShader(retangulo),
    );
    canvas.drawOval(
      retangulo,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = cor.withValues(alpha: .32),
    );
  }

  void _olhos(
    Canvas canvas,
    PontoProjetado Function(V3) projetar,
    double escala,
    double giroTotal,
  ) {
    // Piscada curta a cada ciclo; olhos fecham, não desaparecem.
    final pisca = math.sin(t * math.pi * 2 * 3) > 0.985 ? 0.12 : 1.0;
    final apertados = estado == AvatarEstado.pensando ? 0.55 : 1.0;
    for (final olho in olhosDoAvatar) {
      final girado = girarPonto(olho, giro: giroTotal);
      if (girado.z < 0.10) continue;
      final ponto = projetar(olho);
      final raio = escala * 0.045 * ponto.fator;
      final altura = raio * 0.62 * pisca * apertados;
      final brilho = estado == AvatarEstado.erro
          ? const Color(0xFFFF7166)
          : Colors.white;
      canvas.drawCircle(
        Offset(ponto.x, ponto.y),
        raio * 2.1,
        Paint()
          ..shader = RadialGradient(colors: [
            _cor.withValues(alpha: .55),
            _cor.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(
            center: Offset(ponto.x, ponto.y),
            radius: raio * 2.1,
          )),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(ponto.x, ponto.y),
          width: raio * 1.35,
          height: altura * 1.35,
        ),
        Paint()..color = brilho.withValues(alpha: .92),
      );
    }
  }

  void _boca(
    Canvas canvas,
    PontoProjetado Function(V3) projetar,
    double giroTotal,
  ) {
    final centroBoca = girarPonto(const V3(0, 0.52, 0.352), giro: giroTotal);
    if (centroBoca.z < 0.10) return;
    final abertura = aberturaDaBoca(
      t * 12,
      falando: estado == AvatarEstado.falando,
    );
    final curvas = pontosDaBoca(abertura);
    final caminho = Path();
    var primeiro = true;
    for (final curva in curvas) {
      for (final ponto3 in curva) {
        final ponto = projetar(ponto3);
        if (primeiro) {
          caminho.moveTo(ponto.x, ponto.y);
          primeiro = false;
        } else {
          caminho.lineTo(ponto.x, ponto.y);
        }
      }
    }
    caminho.close();
    // Interior escuro: boca aberta é abertura, não uma barra branca.
    canvas.drawPath(
      caminho,
      Paint()..color = const Color(0xFF04121C).withValues(alpha: .82),
    );
    canvas.drawPath(
      caminho,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = Colors.white.withValues(alpha: .55),
    );
  }

  void _reator(
    Canvas canvas,
    PontoProjetado Function(V3) projetar,
    double escala,
    Color cor,
    double giroTotal,
  ) {
    final anel = anelDoReator();
    final pulso = 0.45 + 0.35 * math.sin(t * math.pi * 2 * 2);
    final caminho = Path();
    var primeiro = true;
    var profundidade = 0.0;
    for (final ponto3 in anel) {
      final girado = girarPonto(ponto3, giro: giroTotal);
      profundidade += girado.z;
      final ponto = projetar(ponto3);
      if (primeiro) {
        caminho.moveTo(ponto.x, ponto.y);
        primeiro = false;
      } else {
        caminho.lineTo(ponto.x, ponto.y);
      }
    }
    caminho.close();
    if (profundidade / anel.length < 0.15) return;
    canvas.drawPath(
      caminho,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: .35 + pulso * .35),
    );
    canvas.drawPath(
      caminho,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..color = cor.withValues(alpha: .10 + pulso * .10),
    );
    final centro = projetar(const V3(0, -0.32, 0.520));
    canvas.drawCircle(
      Offset(centro.x, centro.y),
      escala * 0.035 * centro.fator,
      Paint()..color = Colors.white.withValues(alpha: .55 + pulso * .3),
    );
  }

  void _orbitas(
    Canvas canvas,
    PontoProjetado Function(V3) projetar,
    Color cor,
  ) {
    const orbitas = [
      (raio: 1.22, inclinacao: 0.50, velocidade: 0.55, fase: 0.0),
      (raio: 1.36, inclinacao: -0.34, velocidade: -0.42, fase: 2.1),
      (raio: 1.12, inclinacao: 1.16, velocidade: 0.30, fase: 4.2),
    ];
    for (final orbita in orbitas) {
      final pontos = orbitaDoAvatar(
        t * math.pi * 2 * orbita.velocidade + orbita.fase,
        raio: orbita.raio,
        inclinacao: orbita.inclinacao,
      );
      for (var i = 0; i < pontos.length; i++) {
        final atual = pontos[i];
        final proximo = pontos[(i + 1) % pontos.length];
        final a = projetar(atual);
        final b = projetar(proximo);
        final perto = ((atual.z + proximo.z) / 2).clamp(-1.4, 1.4);
        final brilho = 0.10 + ((perto + 1.4) / 2.8) * 0.32;
        canvas.drawLine(
          Offset(a.x, a.y),
          Offset(b.x, b.y),
          Paint()
            ..strokeWidth = 0.7 + brilho
            ..color = cor.withValues(alpha: brilho),
        );
      }
    }
  }

  void _particulas(
    Canvas canvas,
    PontoProjetado Function(V3) projetar,
    Color cor,
  ) {
    final pontos = particulasDoAvatar(t * math.pi * 2);
    for (var i = 0; i < pontos.length; i++) {
      final ponto = projetar(pontos[i]);
      final brilho = 0.18 + ((pontos[i].z + 1.4) / 2.8).clamp(0.0, 1.0) * 0.5;
      canvas.drawCircle(
        Offset(ponto.x, ponto.y),
        i % 7 == 0 ? 2.0 : 1.1,
        Paint()..color = cor.withValues(alpha: brilho),
      );
    }
  }

  void _varredura(
    Canvas canvas,
    PontoProjetado Function(V3) projetar,
    Color cor,
  ) {
    final fase = (t * 2) % 1;
    final y = -1.02 + fase * 2.1;
    final esquerda = projetar(V3(-0.72, y, 0));
    final direita = projetar(V3(0.72, y, 0));
    final faixa = Rect.fromLTRB(
      esquerda.x,
      esquerda.y - 1,
      direita.x,
      esquerda.y + 1,
    );
    canvas.drawRect(
      faixa,
      Paint()
        ..shader = LinearGradient(colors: [
          cor.withValues(alpha: 0),
          cor.withValues(alpha: .30),
          cor.withValues(alpha: 0),
        ]).createShader(faixa),
    );
  }

  void _estadoExtra(
    Canvas canvas,
    PontoProjetado Function(V3) projetar,
    double escala,
    Color cor,
    double giroTotal,
  ) {
    switch (estado) {
      case AvatarEstado.ouvindo:
        final centro = projetar(const V3(0, 0.45, 0));
        for (var i = 0; i < 3; i++) {
          final fase = (t * 2 + i / 3) % 1;
          canvas.drawCircle(
            Offset(centro.x, centro.y),
            escala * (0.45 + fase * 0.55),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = cor.withValues(alpha: (1 - fase) * .20),
          );
        }
      case AvatarEstado.pensando:
        final centro = projetar(const V3(0, 1.12, 0));
        final arco = Rect.fromCircle(
          center: Offset(centro.x, centro.y),
          radius: escala * 0.16,
        );
        canvas.drawArc(
          arco,
          t * math.pi * 2 * 4,
          math.pi * 0.7,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = Colors.white.withValues(alpha: .55),
        );
      case AvatarEstado.falando:
      case AvatarEstado.espera:
      case AvatarEstado.erro:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant Avatar3DPainter old) =>
      old.t != t ||
      old.estado != estado ||
      old.giro != giro ||
      old.inclinacao != inclinacao ||
      old.autoGiro != autoGiro;
}
