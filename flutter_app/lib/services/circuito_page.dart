import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/circuito.dart';
import '../core/clp.dart';
import '../core/engenharia.dart';
import '../ui_common.dart';
import 'sistema_android.dart';

/// Ferramenta ativa do editor. Uma delas apaga; as outras inserem elementos.
enum Ferramenta {
  fonte,
  resistor,
  lampada,
  interruptor,
  botoeira,
  sensor,
  bobina,
  contatoSelo,
  contatoNf,
  contatoPotencia,
  motor,
  releTermico,
  contatoRele,
  temporizador,
  contatoTemporizado,
  contatoTemporizadoNf,
  fusivel,
  fio,
  apagar,
}

const _nomeFerramenta = <Ferramenta, String>{
  Ferramenta.fonte: 'Fonte 12 V',
  Ferramenta.resistor: 'Resistor',
  Ferramenta.lampada: 'Lâmpada',
  Ferramenta.interruptor: 'Interruptor',
  Ferramenta.botoeira: 'Botoeira',
  Ferramenta.sensor: 'Sensor',
  Ferramenta.bobina: 'Bobina de contator',
  Ferramenta.contatoSelo: 'Contato de selo',
  Ferramenta.contatoNf: 'Contato NF (travamento)',
  Ferramenta.contatoPotencia: 'Contato de potência',
  Ferramenta.motor: 'Motor DC',
  Ferramenta.releTermico: 'Relé térmico',
  Ferramenta.contatoRele: 'Contato 95/96',
  Ferramenta.temporizador: 'Temporizador',
  Ferramenta.contatoTemporizado: 'Contato 67/68',
  Ferramenta.contatoTemporizadoNf: 'Contato 67/68 NF',
  Ferramenta.fusivel: 'Fusível',
  Ferramenta.fio: 'Fio',
  Ferramenta.apagar: 'Apagar',
};

/// Converte entre os nós da grade e os pixels do tabuleiro.
///
/// É pública para que o teste de tela consiga tocar no mesmo ponto que o
/// desenho usa.
class GeometriaCircuito {
  GeometriaCircuito(this.tamanho, this.colunas, this.linhas);

  final Size tamanho;
  final int colunas;
  final int linhas;

  double get margem => 22;
  double get passoX => (tamanho.width - 2 * margem) / (colunas - 1);
  double get passoY => (tamanho.height - 2 * margem) / (linhas - 1);
  double get passo => math.min(passoX, passoY);

  Offset no(int indice) => Offset(
        margem + (indice % colunas) * passoX,
        margem + (indice ~/ colunas) * passoY,
      );

  Offset meio(int a, int b) => (no(a) + no(b)) / 2;

  Offset direcao(int a, int b) {
    final vetor = no(b) - no(a);
    final comprimento = vetor.distance;
    return comprimento == 0 ? const Offset(1, 0) : vetor / comprimento;
  }

  /// Trecho da grade mais próximo do toque, ou nulo se o toque foi longe.
  (int, int)? trechoEm(Offset ponto) {
    (int, int)? melhor;
    var distancia = double.infinity;
    for (var y = 0; y < linhas; y++) {
      for (var x = 0; x < colunas; x++) {
        final n = y * colunas + x;
        if (x + 1 < colunas) {
          final d = (meio(n, n + 1) - ponto).distance;
          if (d < distancia) {
            distancia = d;
            melhor = (n, n + 1);
          }
        }
        if (y + 1 < linhas) {
          final d = (meio(n, n + colunas) - ponto).distance;
          if (d < distancia) {
            distancia = d;
            melhor = (n, n + colunas);
          }
        }
      }
    }
    return distancia <= passo * 0.55 ? melhor : null;
  }
}

class TabuleiroCircuito extends StatelessWidget {
  const TabuleiroCircuito({
    super.key,
    required this.circuito,
    required this.resultado,
    required this.selecionado,
    required this.rotulos,
    required this.onTrecho,
    this.tempos = const {},
    this.temposQueda = const {},
    this.temposContato = const {},
    this.temposQuedaContato = const {},
  });

  final Circuito circuito;
  final ResultadoSimulacao resultado;
  final String? selecionado;
  final Map<String, String> rotulos;
  final Map<String, double> tempos;
  final Map<String, double> temposQueda;

  /// Relógio próprio de cada contato 67/68, independente do temporizador.
  final Map<String, double> temposContato;
  final Map<String, double> temposQuedaContato;
  final void Function(int a, int b) onTrecho;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: (circuito.colunas - 1) / (circuito.linhas - 1),
      child: LayoutBuilder(
        builder: (context, restricoes) {
          final tamanho =
              Size(restricoes.maxWidth, restricoes.maxHeight);
          final geometria =
              GeometriaCircuito(tamanho, circuito.colunas, circuito.linhas);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (detalhe) {
              final trecho = geometria.trechoEm(detalhe.localPosition);
              if (trecho != null) onTrecho(trecho.$1, trecho.$2);
            },
            child: CustomPaint(
              painter: _PintorCircuito(
                circuito: circuito,
                resultado: resultado,
                selecionado: selecionado,
                rotulos: rotulos,
                tempos: tempos,
                temposQueda: temposQueda,
                temposContato: temposContato,
                temposQuedaContato: temposQuedaContato,
              ),
              size: tamanho,
            ),
          );
        },
      ),
    );
  }
}

/// Estado do contato 67/68 (NA ou NF) conforme o temporizador que o comanda e o
/// atraso do próprio contato (0 s = ajuste base do temporizador).
bool _contatoTemporizadoFechado(Elemento e, Circuito circuito,
    ResultadoSimulacao resultado, Map<String, double> tempos,
    Map<String, double> temposQueda,
    [Map<String, double> temposContato = const {},
    Map<String, double> temposQuedaContato = const {}]) {
  final dono = e.contatoDe == null ? null : circuito.porId(e.contatoDe!);
  if (dono == null || dono.tipo != TipoElemento.temporizador) {
    return e.tipo == TipoElemento.contatoTemporizadoNf;
  }
  final subiu = circuito.relogioDoContato(e, temposContato, tempos) + 1e-9 >=
      circuito.atrasoDoContato(e);
  final acionado = resultado.temporizadoresAtivos.contains(dono.id)
      ? subiu
      : subiu &&
          circuito.relogioQuedaDoContato(
                  e, temposQuedaContato, temposQueda) +
                  1e-9 <
              circuito.atrasoQuedaDoContato(e);
  return e.tipo == TipoElemento.contatoTemporizado ? acionado : !acionado;
}

Offset _girar(Offset vetor, double angulo) => Offset(
      vetor.dx * math.cos(angulo) - vetor.dy * math.sin(angulo),
      vetor.dx * math.sin(angulo) + vetor.dy * math.cos(angulo),
    );

class _PintorCircuito extends CustomPainter {
  _PintorCircuito({
    required this.circuito,
    required this.resultado,
    required this.selecionado,
    required this.rotulos,
    required this.tempos,
    required this.temposQueda,
    this.temposContato = const {},
    this.temposQuedaContato = const {},
  });

  final Circuito circuito;
  final ResultadoSimulacao resultado;
  final String? selecionado;
  final Map<String, String> rotulos;
  final Map<String, double> tempos;
  final Map<String, double> temposQueda;
  final Map<String, double> temposContato;
  final Map<String, double> temposQuedaContato;

  static const _traco = Color(0xFF7FE7FF);
  static const _aceso = Color(0xFFFFD27F);

  @override
  void paint(Canvas canvas, Size size) {
    final g = GeometriaCircuito(size, circuito.colunas, circuito.linhas);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(12)),
      Paint()..color = const Color(0xFF07111B),
    );

    final grade = Paint()
      ..color = cyan.withValues(alpha: .07)
      ..strokeWidth = 1;
    for (var y = 0; y < circuito.linhas; y++) {
      final esquerda = g.no(y * circuito.colunas);
      final direita = g.no(y * circuito.colunas + circuito.colunas - 1);
      canvas.drawLine(esquerda, direita, grade);
    }
    for (var x = 0; x < circuito.colunas; x++) {
      final topo = g.no(x);
      final base = g.no(x + (circuito.linhas - 1) * circuito.colunas);
      canvas.drawLine(topo, base, grade);
    }

    final ponto = Paint()..color = _traco.withValues(alpha: .35);
    for (var i = 0; i < circuito.colunas * circuito.linhas; i++) {
      canvas.drawCircle(g.no(i), 1.7, ponto);
    }

    for (final elemento in circuito.elementos) {
      _desenhar(canvas, g, elemento);
      if (elemento.id == selecionado) {
        final retangulo = Rect.fromPoints(
                g.no(elemento.a), g.no(elemento.b))
            .inflate(10);
        canvas.drawRRect(
          RRect.fromRectAndRadius(retangulo, const Radius.circular(8)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = const Color(0xFFFFC66D).withValues(alpha: .8),
        );
      }
    }
  }

  void _desenhar(Canvas canvas, GeometriaCircuito g, Elemento e) {
    final p = g.no(e.a);
    final q = g.no(e.b);
    final m = (p + q) / 2;
    final dir = g.direcao(e.a, e.b);
    final normal = Offset(-dir.dy, dir.dx);
    final medida = resultado.medidas[e.id];
    final cor = e.tipo == TipoElemento.fusivel && e.queimado
        ? const Color(0xFFFF8A80)
        : _traco;
    final pincel = Paint()
      ..color = cor
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    void linha(Offset a, Offset b) => canvas.drawLine(a, b, pincel);

    switch (e.tipo) {
      case TipoElemento.fio:
        linha(p, q);
        break;
      case TipoElemento.resistor:
        final meioTrecho = g.passo * 0.22;
        linha(p, p + dir * meioTrecho);
        linha(q - dir * meioTrecho, q);
        final zigue = Path()
          ..moveTo(p.dx + dir.dx * meioTrecho, p.dy + dir.dy * meioTrecho);
        for (var i = 1; i <= 6; i++) {
          final avanco = meioTrecho * 2 * i / 6;
          final lado = i.isEven ? 1.0 : -1.0;
          final alvo = p + dir * (meioTrecho + avanco) + normal * (lado * 5);
          zigue.lineTo(alvo.dx, alvo.dy);
        }
        zigue.lineTo(q.dx - dir.dx * meioTrecho, q.dy - dir.dy * meioTrecho);
        canvas.drawPath(zigue, pincel);
        break;
      case TipoElemento.lampada:
        final raio = (g.passo * 0.2).clamp(7.0, 13.0);
        final potencia = (medida?.potencia ?? 0).abs();
        linha(p, m - dir * raio);
        linha(m + dir * raio, q);
        if (potencia > 0.001) {
          canvas.drawCircle(
              m,
              raio + 7,
              Paint()
                ..color = _aceso.withValues(
                    alpha: (0.10 + 0.18 * (potencia / 5)).clamp(0.0, 0.3)));
        }
        canvas.drawCircle(
          m,
          raio,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..color = potencia > 0.001 ? _aceso : cor,
        );
        final cruz = raio * 0.62;
        linha(m - Offset(cruz, cruz), m + Offset(cruz, cruz));
        linha(m - Offset(cruz, -cruz), m + Offset(cruz, -cruz));
        break;
      case TipoElemento.interruptor:
        final dobradica = p + dir * (g.passo * 0.34);
        linha(p, dobradica);
        if (e.fechado) {
          linha(dobradica, q);
        } else {
          final comprimento = (q - dobradica).distance;
          linha(dobradica, dobradica + _girar(dir, -0.7) * comprimento);
        }
        canvas.drawCircle(dobradica, 2.2, Paint()..color = cor);
        canvas.drawCircle(q, 2.2, Paint()..color = cor);
        break;
      case TipoElemento.fusivel:
        const largura = 21.0;
        const altura = 9.0;
        linha(p, m - dir * (largura / 2));
        linha(m + dir * (largura / 2), q);
        canvas.save();
        canvas.translate(m.dx, m.dy);
        canvas.rotate(math.atan2(dir.dy, dir.dx));
        final corpo = RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: largura, height: altura),
            const Radius.circular(2.5));
        canvas.drawRRect(
          corpo,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = cor,
        );
        canvas.drawLine(
            Offset(-largura / 2, 0), Offset(largura / 2, 0), pincel);
        canvas.restore();
        break;
      case TipoElemento.fonte:
        final raio = (g.passo * 0.22).clamp(9.0, 14.0);
        linha(p, m - dir * raio);
        linha(m + dir * raio, q);
        canvas.drawCircle(
          m,
          raio,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..color = cor,
        );
        _texto(canvas, '+', m - dir * (raio + 9),
            const Color(0xFFFFD27F), 11, FontWeight.w700);
        _texto(canvas, '−', m + dir * (raio + 9),
            const Color(0xFFFFD27F), 11, FontWeight.w700);
        break;
      case TipoElemento.botoeira:
        final dobradica = p + dir * (g.passo * 0.34);
        final fechada = e.normalmenteFechado ? !e.pressionada : e.pressionada;
        linha(p, dobradica);
        if (fechada) {
          linha(dobradica, q);
        } else {
          final comprimento = (q - dobradica).distance;
          linha(dobradica, dobradica + _girar(dir, -0.7) * comprimento);
        }
        // Haste do botão, para não confundir com um interruptor comum.
        final haste = dobradica + normal * (g.passo * 0.2);
        linha(dobradica + normal * 4, haste);
        linha(haste - dir * 4, haste + dir * 4);
        canvas.drawCircle(dobradica, 2.2, Paint()..color = cor);
        canvas.drawCircle(q, 2.2, Paint()..color = cor);
        break;
      case TipoElemento.bobina:
        final ligada = resultado.bobinasLigadas.contains(e.id);
        final corBobina = ligada ? _aceso : cor;
        const larguraBobina = 22.0;
        const alturaBobina = 12.0;
        final pincelBobina = Paint()
          ..color = corBobina
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(p, m - dir * (larguraBobina / 2), pincel);
        canvas.drawLine(m + dir * (larguraBobina / 2), q, pincel);
        canvas.save();
        canvas.translate(m.dx, m.dy);
        canvas.rotate(math.atan2(dir.dy, dir.dx));
        final corpoBobina = RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero,
                width: larguraBobina,
                height: alturaBobina),
            const Radius.circular(2.5));
        canvas.drawRRect(
          corpoBobina,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = corBobina,
        );
        canvas.drawLine(Offset(-larguraBobina / 2, 0),
            Offset(larguraBobina / 2, 0), pincelBobina);
        canvas.restore();
        if (ligada) {
          canvas.drawCircle(
              m,
              alturaBobina,
              Paint()
                ..color = _aceso.withValues(alpha: .12));
        }
        break;
      case TipoElemento.contatoPotencia:
        final ligado = e.contatoDe != null &&
            resultado.bobinasLigadas.contains(e.contatoDe);
        final grosso = Paint()
          ..color = ligado ? _aceso : cor
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(p, q, grosso);
        if (!ligado) {
          // Barra aberta no meio, para ver que a potência está cortada.
          final corte = Paint()
            ..color = const Color(0xFF07111B)
            ..strokeWidth = 6;
          canvas.drawLine(m - normal * 7, m + normal * 7, corte);
        }
        break;
      case TipoElemento.releTermico:
        const larguraRele = 24.0;
        const alturaRele = 12.0;
        final corRele = e.desarmado ? const Color(0xFFFF8A80) : cor;
        final pincelRele = Paint()
          ..color = corRele
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(p, m - dir * (larguraRele / 2), pincelRele);
        canvas.drawLine(m + dir * (larguraRele / 2), q, pincelRele);
        canvas.save();
        canvas.translate(m.dx, m.dy);
        canvas.rotate(math.atan2(dir.dy, dir.dx));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset.zero,
                  width: larguraRele,
                  height: alturaRele),
              const Radius.circular(2.5)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = corRele,
        );
        // Bimetal: duas lâminas cruzadas dentro do corpo.
        canvas.drawLine(const Offset(-9, -3.5), const Offset(9, 3.5),
            pincelRele);
        canvas.drawLine(const Offset(-9, 3.5), const Offset(9, -3.5),
            pincelRele);
        canvas.restore();
        break;
      case TipoElemento.temporizador:
        const larguraTimer = 24.0;
        const alturaTimer = 14.0;
        final corTimer = resultado.temporizadoresAtivos.contains(e.id)
            ? _aceso
            : cor;
        linha(p, m - dir * (larguraTimer / 2));
        linha(m + dir * (larguraTimer / 2), q);
        canvas.save();
        canvas.translate(m.dx, m.dy);
        canvas.rotate(math.atan2(dir.dy, dir.dx));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset.zero,
                  width: larguraTimer,
                  height: alturaTimer),
              const Radius.circular(2.5)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = corTimer,
        );
        // Relogiozinho dentro do corpo do temporizador.
        canvas.drawCircle(Offset.zero, 4.2,
            Paint()..color = corTimer.withValues(alpha: .25));
        canvas.drawLine(Offset.zero, const Offset(0, -2.6),
            Paint()..color = corTimer..strokeWidth = 1.2);
        canvas.drawLine(Offset.zero, const Offset(2.2, 0),
            Paint()..color = corTimer..strokeWidth = 1.2);
        canvas.restore();
        break;
      case TipoElemento.motor:
        final raioMotor = (g.passo * 0.22).clamp(9.0, 14.0);
        final potenciaMotor = (medida?.potencia ?? 0).abs();
        linha(p, m - dir * raioMotor);
        linha(m + dir * raioMotor, q);
        canvas.drawCircle(
          m,
          raioMotor,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..color = potenciaMotor > 0.001 ? _aceso : cor,
        );
        _texto(
            canvas,
            'M',
            m,
            potenciaMotor > 0.001 ? _aceso : cor,
            10,
            FontWeight.w700);
        break;
      case TipoElemento.contatoSelo:
      case TipoElemento.contatoNf:
      case TipoElemento.contatoRele:
      case TipoElemento.contatoTemporizado:
      case TipoElemento.contatoTemporizadoNf:
        final dobradica = p + dir * (g.passo * 0.34);
        final donoLigado = e.contatoDe != null &&
            resultado.bobinasLigadas.contains(e.contatoDe);
        final releDesarmado = e.contatoDe != null &&
            resultado.relesDesarmados.contains(e.contatoDe);
        // NA fecha com a bobina ligada; NF e o 95/96 fazem o contrário; o
        // contato do temporizador segue o temporizador, inclusive segurando no
        // retardo na queda.
        final fechado = switch (e.tipo) {
          TipoElemento.contatoSelo => donoLigado,
          TipoElemento.contatoNf => !donoLigado,
          TipoElemento.contatoTemporizado ||
          TipoElemento.contatoTemporizadoNf =>
            _contatoTemporizadoFechado(e, circuito, resultado, tempos,
                temposQueda, temposContato, temposQuedaContato),
          _ => !releDesarmado,
        };
        linha(p, dobradica);
        if (fechado) {
          linha(dobradica, q);
        } else {
          final comprimento = (q - dobradica).distance;
          linha(dobradica, dobradica + _girar(dir, -0.7) * comprimento);
        }
        canvas.drawCircle(dobradica, 2.2, Paint()..color = cor);
        canvas.drawCircle(q, 2.2, Paint()..color = cor);
        if (e.tipo != TipoElemento.contatoSelo) {
          // Traço do contato NF, para não confundir com o selo.
          final meioNf = fechado ? (dobradica + q) / 2 : dobradica + dir * 6;
          linha(meioNf - normal * 4.5, meioNf + normal * 4.5);
        }
        final tracejado = Paint()
          ..color = cor.withValues(alpha: .4)
          ..strokeWidth = 1;
        for (var i = 0; i < 3; i++) {
          final inicio = dobradica + normal * (5.0 + i * 4);
          canvas.drawLine(inicio, inicio + dir * 3.5, tracejado);
        }
        break;
    }

    if (e.tipo != TipoElemento.fio) {
      final valor = _valorNaTela(e);
      if (valor.isNotEmpty) {
        _texto(canvas, valor, m + normal * 14, muted, 8);
      }
      final rotulo = rotulos[e.id];
      if (rotulo != null && rotulo != 'fio') {
        _texto(canvas, rotulo, m - normal * 14,
            const Color(0xFFFFC66D).withValues(alpha: .75), 8,
            FontWeight.w700);
      }
      if (medida != null && medida.corrente.abs() > 0.0005) {
        _texto(
            canvas,
            '${formatarNumero(medida.corrente.abs(), casas: 3)} A',
            m - normal * 25,
            cyan,
            8);
      }
    }
  }

  String _valorNaTela(Elemento e) => switch (e.tipo) {
        TipoElemento.fonte => '${formatarNumero(e.valor)} V',
        TipoElemento.resistor => '${formatarNumero(e.valor)} Ω',
        TipoElemento.lampada =>
          '${formatarNumero(e.valor)} W · ${formatarNumero(e.tensaoNominal, casas: 0)} V',
        TipoElemento.interruptor => e.fechado ? 'fechado' : 'aberto',
        TipoElemento.fusivel => e.queimado
            ? 'queimado'
            : '${formatarNumero(e.valor)} A',
        TipoElemento.botoeira => e.sensor
            ? (e.normalmenteFechado
                ? (e.pressionada ? 'NF acionado' : 'NF em repouso')
                : (e.pressionada ? 'NA acionado' : 'NA em repouso'))
            : (e.normalmenteFechado
                ? (e.pressionada ? 'NF apertada' : 'NF solta')
                : (e.pressionada ? 'NA apertada' : 'NA solta')),
        TipoElemento.bobina =>
          '${formatarNumero(e.tensaoNominal, casas: 0)} V · ${formatarNumero(e.valor)} Ω',
        TipoElemento.contatoSelo => e.contatoDe != null &&
                resultado.bobinasLigadas.contains(e.contatoDe)
            ? 'fechado'
            : 'aberto',
        TipoElemento.contatoNf =>
          e.contatoDe != null && resultado.bobinasLigadas.contains(e.contatoDe)
              ? 'aberto'
              : 'fechado',
        TipoElemento.contatoPotencia => e.contatoDe != null &&
                resultado.bobinasLigadas.contains(e.contatoDe)
            ? 'fechado'
            : 'aberto',
        TipoElemento.motor =>
          '${formatarNumero(e.valor)} W · ${formatarNumero(e.tensaoNominal, casas: 0)} V',
        TipoElemento.releTermico => e.desarmado
            ? 'desarmado'
            : '${formatarNumero(e.valor)} A',
        TipoElemento.contatoRele => e.contatoDe != null &&
                resultado.relesDesarmados.contains(e.contatoDe)
            ? 'aberto'
            : 'fechado',
        TipoElemento.temporizador => '${formatarNumero(e.atraso, casas: 0)} s',
                TipoElemento.contatoTemporizado ||
        TipoElemento.contatoTemporizadoNf =>
          _contatoTemporizadoFechado(e, circuito, resultado, tempos,
                  temposQueda, temposContato, temposQuedaContato)
              ? 'fechado'
              : 'aberto',
        TipoElemento.fio => '',
      };

  void _texto(Canvas canvas, String texto, Offset centro, Color cor,
      double tamanho, [FontWeight peso = FontWeight.w500]) {
    final pintor = TextPainter(
      text: TextSpan(
          text: texto,
          style: TextStyle(
              color: cor, fontSize: tamanho, fontWeight: peso)),
      textDirection: TextDirection.ltr,
    )..layout();
    pintor.paint(
        canvas, centro - Offset(pintor.width / 2, pintor.height / 2));
  }

  @override
  bool shouldRepaint(covariant _PintorCircuito anterior) =>
      anterior.circuito != circuito ||
      anterior.resultado != resultado ||
      anterior.selecionado != selecionado;
}

class CircuitoPage extends StatefulWidget {
  const CircuitoPage({super.key, this.inicial});

  final Circuito? inicial;

  @override
  State<CircuitoPage> createState() => _CircuitoPageState();
}

class _CircuitoPageState extends State<CircuitoPage> {
  late Circuito circuito;
  late ResultadoSimulacao resultado;
  Ferramenta ferramenta = Ferramenta.fio;
  String? selecionado;
  String? erroCampo;

  /// Estado das bobinas de contator: sem ele o contato de selo abriria de novo
  /// assim que a botoeira de partida fosse solta.
  Set<String> bobinas = const {};

  /// Relógio de cada temporizador, em segundos, contando energizado.
  Map<String, double> tempos = const {};

  /// Retardo na queda: segundos desde que o temporizador perdeu energia com o
  /// contato ainda acionado.
  Map<String, double> temposQueda = const {};

  /// Cada contato 67/68 conta o próprio relógio: estes mapas guardam o tempo de
  /// subida e o tempo de queda de cada contato, separados do temporizador.
  Map<String, double> temposContato = const {};
  Map<String, double> temposQuedaContato = const {};
  final campo = TextEditingController();
  final campoTensao = TextEditingController();
  final campoQueda = TextEditingController();
  final campoAtrasoContato = TextEditingController();
  final campoQuedaContato = TextEditingController();

  @override
  void initState() {
    super.initState();
    circuito = widget.inicial ?? circuitoExemplo(exemplosCircuito.first.nome);
    resultado = circuito.simular();
    bobinas = resultado.bobinasLigadas;
    tempos = {for (final id in _temporizadores) id: 0};
    temposQueda = {for (final id in _temporizadores) id: 0};
    temposContato = {for (final id in _contatos) id: 0};
    temposQuedaContato = {for (final id in _contatos) id: 0};
    if (resultado.fusiveisQueimados.isNotEmpty) {
      circuito = circuito.marcarQueimados(resultado.fusiveisQueimados);
    }
  }

  @override
  void dispose() {
    campo.dispose();
    campoTensao.dispose();
    campoQueda.dispose();
    super.dispose();
  }

  Elemento? get _escolhido =>
      selecionado == null ? null : circuito.porId(selecionado!);

  List<String> get _temporizadores => [
        for (final e in circuito.elementos)
          if (e.tipo == TipoElemento.temporizador) e.id,
      ];

  List<String> get _contatos => [
        for (final e in circuito.contatosTemporizados) e.id,
      ];

  Map<String, double> get _subida => {
        for (final id in _temporizadores) id: tempos[id] ?? 0,
      };

  Map<String, double> get _queda => {
        for (final id in _temporizadores) id: temposQueda[id] ?? 0,
      };

  Map<String, double> get _subidaContatos => {
        for (final id in _contatos) id: temposContato[id] ?? 0,
      };

  Map<String, double> get _quedaContatos => {
        for (final id in _contatos) id: temposQuedaContato[id] ?? 0,
      };

  void _aplicar(Circuito novo) {
    final anterior = resultado.temporizadoresAtivos;
    final subida = _subida;
    final queda = _queda;
    final subidaContatos = _subidaContatos;
    final quedaContatos = _quedaContatos;
    final calculo = novo.simular(
        bobinasLigadas: bobinas,
        tempos: subida,
        temposQueda: queda,
        temposContato: subidaContatos,
        temposQuedaContato: quedaContatos);
    var base = novo;
    if (calculo.fusiveisQueimados.isNotEmpty) {
      base = base.marcarQueimados(calculo.fusiveisQueimados);
    }
    if (calculo.relesDesarmados.isNotEmpty) {
      base = base.desarmar(calculo.relesDesarmados);
    }
    setState(() {
      circuito = base;
      resultado = calculo;
      bobinas = calculo.bobinasLigadas;
      _fixarRelogios(calculo, anterior, subida, queda, subidaContatos,
          quedaContatos);
      erroCampo = null;
    });
  }

  /// Guarda os relógios coerentes com o novo resultado: quem voltou a energizar
  /// começa do zero, quem perdeu energia com o contato acionado começa a contar
  /// o retardo na queda.
  void _fixarRelogios(ResultadoSimulacao calculo, Set<String> anterior,
      Map<String, double> subida, Map<String, double> queda,
      [Map<String, double> subidaContatos = const {},
      Map<String, double> quedaContatos = const {}]) {
    final ativos = calculo.temporizadoresAtivos;
    final t = <String, double>{};
    final q = <String, double>{};
    for (final e in circuito.elementos) {
      if (e.tipo != TipoElemento.temporizador) continue;
      final era = anterior.contains(e.id);
      final agora = ativos.contains(e.id);
      final valor = subida[e.id] ?? 0;
      if (agora) {
        t[e.id] = era ? valor : 0;
        q[e.id] = 0;
      } else {
        final quedaAgora = queda[e.id] ?? 0;
        // Ainda há contato atrasado? E algum deles ainda dentro da própria
        // queda? Vencidas todas as quedas, o temporizador zera.
        final atrasou = _algumContatoAtrasado(e, valor);
        final segurandoAgora =
            _algumContatoAtrasado(e, valor, quedaAgora);
        t[e.id] = segurandoAgora ? valor : 0;
        q[e.id] = atrasou ? quedaAgora : 0;
      }
    }
    tempos = t;
    temposQueda = q;
    // Cada contato tem o próprio par de relógios: zera quando o temporizador
    // volta a energizar e só continua na queda enquanto ele estiver segurando.
    final tc = <String, double>{};
    final tq = <String, double>{};
    for (final c in circuito.contatosTemporizados) {
      final dono = c.contatoDe == null ? null : circuito.porId(c.contatoDe!);
      if (dono == null || dono.tipo != TipoElemento.temporizador) continue;
      final era = anterior.contains(dono.id);
      final agora = ativos.contains(dono.id);
      final valor = subidaContatos[c.id] ?? 0;
      if (agora) {
        tc[c.id] = era ? valor : 0;
        tq[c.id] = 0;
        continue;
      }
      final quedaAgora = quedaContatos[c.id] ?? 0;
      final fechado =
          valor + 1e-9 >= circuito.atrasoDoContato(c);
      final segurando = fechado &&
          quedaAgora + 1e-9 < circuito.atrasoQuedaDoContato(c);
      tc[c.id] = segurando ? valor : 0;
      tq[c.id] = segurando ? quedaAgora : 0;
    }
    temposContato = tc;
    temposQuedaContato = tq;
  }

  /// Avança 1 s no relógio dos temporizadores: quem está energizado conta a
  /// subida; quem perdeu energia com o contato acionado conta o retardo na queda.
  void _avancarTempo() {
    final ativos = resultado.temporizadoresAtivos;
    final subida = _subida;
    final queda = _queda;
    final subidaContatos = _subidaContatos;
    final quedaContatos = _quedaContatos;
    var mudou = false;
    // Relógio próprio de cada contato: anda enquanto o temporizador que o
    // comanda está energizado e, depois, enquanto o contato segura na queda.
    // Nenhum contato lê o relógio do temporizador para decidir o próprio tempo.
    for (final c in circuito.contatosTemporizados) {
      final dono = c.contatoDe == null ? null : circuito.porId(c.contatoDe!);
      if (dono == null || dono.tipo != TipoElemento.temporizador) continue;
      if (ativos.contains(dono.id)) {
        final atual = subidaContatos[c.id] ?? 0;
        final limite = circuito.atrasoDoContato(c);
        if (atual + 1e-9 < limite || limite <= 0) {
          subidaContatos[c.id] = atual + 1;
        }
        quedaContatos[c.id] = 0;
        mudou = true;
      } else if ((subidaContatos[c.id] ?? 0) + 1e-9 >=
              circuito.atrasoDoContato(c) &&
          (quedaContatos[c.id] ?? 0) + 1e-9 <
              circuito.atrasoQuedaDoContato(c)) {
        quedaContatos[c.id] = (quedaContatos[c.id] ?? 0) + 1;
        mudou = true;
      }
    }
    for (final e in circuito.elementos) {
      if (e.tipo != TipoElemento.temporizador) continue;
      if (ativos.contains(e.id)) {
        subida[e.id] = (subida[e.id] ?? 0) + 1;
        queda[e.id] = 0;
        mudou = true;
      } else if (_algumContatoAtrasado(
          e, subida[e.id] ?? 0, queda[e.id] ?? 0)) {
        queda[e.id] = (queda[e.id] ?? 0) + 1;
        mudou = true;
      }
    }
    if (!mudou) return;
    final calculo = circuito.simular(
        bobinasLigadas: bobinas,
        tempos: subida,
        temposQueda: queda,
        temposContato: subidaContatos,
        temposQuedaContato: quedaContatos);
    setState(() {
      resultado = calculo;
      bobinas = calculo.bobinasLigadas;
      _fixarRelogios(calculo, ativos, subida, queda, subidaContatos,
          quedaContatos);
    });
  }

  /// Existe contato deste temporizador com o atraso próprio já completo? Com
  /// [queda] informada, também exige que ele ainda esteja dentro da própria
  /// queda.
  bool _algumContatoAtrasado(Elemento temporizador, double subida,
      [double? queda]) {
    final contatos = circuito.contatosDe(temporizador.id).toList();
    if (contatos.isEmpty) {
      // Sem contatos, vale o ajuste base do próprio temporizador.
      if (subida + 1e-9 < temporizador.atraso) return false;
      return queda == null || queda + 1e-9 < temporizador.atrasoQueda;
    }
    for (final c in contatos) {
      if (subida + 1e-9 < circuito.atrasoDoContato(c)) continue;
      if (queda != null &&
          queda + 1e-9 >= circuito.atrasoQuedaDoContato(c)) {
        continue;
      }
      return true;
    }
    return false;
  }

  /// Temporizador acionado agora, pelo ajuste base dele? Energizado, vale o
  /// relógio de subida; sem energia, o contato continua até o retardo vencer.
  bool _temporizadorAcionado(Elemento e) {
    final subiu = (tempos[e.id] ?? 0) + 1e-9 >= e.atraso;
    if (resultado.temporizadoresAtivos.contains(e.id)) return subiu;
    return subiu && (temposQueda[e.id] ?? 0) + 1e-9 < e.atrasoQueda;
  }

  /// Estado do contato 67/68 (NA ou NF) com o atraso do próprio contato.
  bool _contatoTemporizadoFechado(Elemento e) {
    final dono = e.contatoDe == null ? null : circuito.porId(e.contatoDe!);
    if (dono == null || dono.tipo != TipoElemento.temporizador) {
      return e.tipo == TipoElemento.contatoTemporizadoNf;
    }
    final subiu = (temposContato[e.id] ?? 0) + 1e-9 >=
        circuito.atrasoDoContato(e);
    final acionado = resultado.temporizadoresAtivos.contains(dono.id)
        ? subiu
        : subiu &&
            (temposQuedaContato[e.id] ?? 0) + 1e-9 <
                circuito.atrasoQuedaDoContato(e);
    return e.tipo == TipoElemento.contatoTemporizado ? acionado : !acionado;
  }

  void _escolher(String? id) {
    final elemento = id == null ? null : circuito.porId(id);
    setState(() {
      selecionado = elemento?.id;
      campo.text = elemento == null ? '' : formatarNumero(elemento.valor);
      campoTensao.text =
          elemento == null ? '' : formatarNumero(elemento.tensaoNominal);
      campoQueda.text =
          elemento == null ? '' : formatarNumero(elemento.atrasoQueda, casas: 0);
      campoAtrasoContato.text =
          elemento == null ? '' : formatarNumero(elemento.atraso, casas: 0);
      campoQuedaContato.text = elemento == null
          ? ''
          : formatarNumero(elemento.atrasoQueda, casas: 0);
    });
  }

  void _tocarTrecho(int a, int b) {
    final existente = circuito.em(a, b);
    if (ferramenta == Ferramenta.apagar) {
      if (existente == null) return;
      _aplicar(circuito.removerEm(a, b));
      _escolher(null);
      return;
    }
    if (existente != null) {
      _escolher(existente.id);
      return;
    }
    final elemento = _criar(_tipoDe(ferramenta), a, b,
        sensor: ferramenta == Ferramenta.sensor);
    if (elemento == null) return;
    _aplicar(circuito.adicionar(elemento));
    _escolher(elemento.id);
  }

  TipoElemento? _tipoDe(Ferramenta f) => switch (f) {
        Ferramenta.fonte => TipoElemento.fonte,
        Ferramenta.resistor => TipoElemento.resistor,
        Ferramenta.lampada => TipoElemento.lampada,
        Ferramenta.interruptor => TipoElemento.interruptor,
        Ferramenta.botoeira || Ferramenta.sensor => TipoElemento.botoeira,
        Ferramenta.bobina => TipoElemento.bobina,
        Ferramenta.contatoSelo => TipoElemento.contatoSelo,
        Ferramenta.contatoNf => TipoElemento.contatoNf,
        Ferramenta.contatoPotencia => TipoElemento.contatoPotencia,
        Ferramenta.motor => TipoElemento.motor,
        Ferramenta.releTermico => TipoElemento.releTermico,
        Ferramenta.contatoRele => TipoElemento.contatoRele,
        Ferramenta.temporizador => TipoElemento.temporizador,
        Ferramenta.contatoTemporizado => TipoElemento.contatoTemporizado,
        Ferramenta.contatoTemporizadoNf => TipoElemento.contatoTemporizadoNf,
        Ferramenta.fusivel => TipoElemento.fusivel,
        Ferramenta.fio => TipoElemento.fio,
        Ferramenta.apagar => null,
      };

  Elemento? _criar(TipoElemento? tipo, int a, int b, {bool sensor = false}) {
    if (tipo == null) return null;
    final id = chaveTrecho(a, b);
    final existeBobina = circuito.elementos
        .where((e) => e.tipo == TipoElemento.bobina)
        .toList();
    final existeRele = circuito.elementos
        .where((e) => e.tipo == TipoElemento.releTermico)
        .toList();
    final existeTimer = circuito.elementos
        .where((e) => e.tipo == TipoElemento.temporizador)
        .toList();
    return switch (tipo) {
      TipoElemento.botoeira => Elemento(
          id: id,
          tipo: tipo,
          a: a,
          b: b,
          sensor: sensor,
          normalmenteFechado: sensor),
      TipoElemento.bobina =>
        Elemento(id: id, tipo: tipo, a: a, b: b, valor: 240, tensaoNominal: 24),
      TipoElemento.contatoSelo ||
      TipoElemento.contatoNf ||
      TipoElemento.contatoPotencia => Elemento(
          id: id,
          tipo: tipo,
          a: a,
          b: b,
          contatoDe: existeBobina.isEmpty ? null : existeBobina.first.id,
        ),
      TipoElemento.motor => Elemento(
          id: id, tipo: tipo, a: a, b: b, valor: 24, tensaoNominal: 24),
      TipoElemento.releTermico => Elemento(
          id: id, tipo: tipo, a: a, b: b, valor: 2),
      TipoElemento.contatoRele => Elemento(
          id: id,
          tipo: tipo,
          a: a,
          b: b,
          contatoDe: existeRele.isEmpty ? null : existeRele.first.id,
        ),
      TipoElemento.temporizador => Elemento(
          id: id,
          tipo: tipo,
          a: a,
          b: b,
          valor: 240,
          tensaoNominal: 24,
          atraso: 3,
        ),
      TipoElemento.contatoTemporizado ||
      TipoElemento.contatoTemporizadoNf =>
        Elemento(
          id: id,
          tipo: tipo,
          a: a,
          b: b,
          contatoDe: existeTimer.isEmpty ? null : existeTimer.first.id,
        ),
      TipoElemento.fonte =>
        Elemento(id: id, tipo: tipo, a: a, b: b, valor: 12),
      TipoElemento.resistor =>
        Elemento(id: id, tipo: tipo, a: a, b: b, valor: 100),
      TipoElemento.lampada => Elemento(
          id: id, tipo: tipo, a: a, b: b, valor: 5, tensaoNominal: 12),
      TipoElemento.interruptor => Elemento(id: id, tipo: tipo, a: a, b: b),
      TipoElemento.fusivel =>
        Elemento(id: id, tipo: tipo, a: a, b: b, valor: 2),
      TipoElemento.fio => Elemento(id: id, tipo: tipo, a: a, b: b),
    };
  }

  void _aplicarValor() {
    final elemento = _escolhido;
    if (elemento == null) return;
    final valor = double.tryParse(campo.text.replaceAll(',', '.'));
    if (valor == null || valor <= 0) {
      setState(() =>
          erroCampo = 'Digite um número maior que zero (use vírgula ou ponto).');
      return;
    }
    final tensao = double.tryParse(campoTensao.text.replaceAll(',', '.'));
    final precisaTensao = elemento.tipo == TipoElemento.lampada ||
        elemento.tipo == TipoElemento.bobina ||
        elemento.tipo == TipoElemento.motor;
    if (precisaTensao && (tensao == null || tensao <= 0)) {
      setState(() => erroCampo =
          'A tensão nominal precisa ser maior que zero (lâmpada ou bobina).');
      return;
    }
    _aplicar(circuito.atualizar(
        elemento.copiarCom(valor: valor, tensaoNominal: tensao)));
    _escolher(elemento.id);
  }

  /// Ajusta o retardo na queda (0 desliga o retardo).
  void _aplicarQueda() {
    final elemento = _escolhido;
    if (elemento == null || elemento.tipo != TipoElemento.temporizador) return;
    final queda = double.tryParse(campoQueda.text.replaceAll(',', '.'));
    if (queda == null || queda < 0) {
      setState(() => erroCampo =
          'Digite um retardo na queda igual ou maior que zero (use vírgula ou ponto).');
      return;
    }
    _aplicar(circuito.atualizar(elemento.copiarCom(atrasoQueda: queda)));
    _escolher(elemento.id);
  }

  /// Ajusta o atraso só deste contato temporizado. Zero volta a usar o tempo
  /// do temporizador que o comanda.
  void _aplicarAtrasoContato() {
    final elemento = _escolhido;
    if (elemento == null) return;
    if (elemento.tipo != TipoElemento.contatoTemporizado &&
        elemento.tipo != TipoElemento.contatoTemporizadoNf) {
      return;
    }
    final atraso =
        double.tryParse(campoAtrasoContato.text.replaceAll(',', '.'));
    if (atraso == null || atraso < 0) {
      setState(() => erroCampo =
          'Digite um atraso igual ou maior que zero (use vírgula ou ponto).');
      return;
    }
    _aplicar(circuito.atualizar(elemento.copiarCom(atraso: atraso)));
    _escolher(elemento.id);
  }

  /// Ajusta o retardo na queda só deste contato temporizado. Zero volta a usar
  /// o retardo do temporizador que o comanda.
  void _aplicarQuedaContato() {
    final elemento = _escolhido;
    if (elemento == null) return;
    if (elemento.tipo != TipoElemento.contatoTemporizado &&
        elemento.tipo != TipoElemento.contatoTemporizadoNf) {
      return;
    }
    final queda =
        double.tryParse(campoQuedaContato.text.replaceAll(',', '.'));
    if (queda == null || queda < 0) {
      setState(() => erroCampo =
          'Digite uma queda igual ou maior que zero (use vírgula ou ponto).');
      return;
    }
    _aplicar(circuito.atualizar(elemento.copiarCom(atrasoQueda: queda)));
    _escolher(elemento.id);
  }

  void _alternar() {
    final elemento = _escolhido;
    if (elemento == null || elemento.tipo != TipoElemento.interruptor) return;
    _aplicar(
        circuito.atualizar(elemento.copiarCom(fechado: !elemento.fechado)));
    _escolher(elemento.id);
  }

  /// Aperta ou solta a botoeira. Com o contato de selo no lugar, soltar a
  /// botoeira de partida não desliga mais o contator.
  void _apertarBotoeira() {
    final elemento = _escolhido;
    if (elemento == null || elemento.tipo != TipoElemento.botoeira) return;
    _aplicar(circuito.atualizar(
        elemento.copiarCom(pressionada: !elemento.pressionada)));
    _escolher(elemento.id);
  }

  void _trocarTipoBotoeira() {
    final elemento = _escolhido;
    if (elemento == null || elemento.tipo != TipoElemento.botoeira) return;
    _aplicar(circuito.atualizar(elemento
        .copiarCom(normalmenteFechado: !elemento.normalmenteFechado)));
    _escolher(elemento.id);
  }

  void _escolherTemporizador(String id) {
    final elemento = _escolhido;
    if (elemento == null ||
        (elemento.tipo != TipoElemento.contatoTemporizado &&
            elemento.tipo != TipoElemento.contatoTemporizadoNf)) {
      return;
    }
    _aplicar(circuito.atualizar(elemento.copiarCom(contatoDe: id)));
    _escolher(elemento.id);
  }

  /// Troca só o tipo deste contato temporizado, de NA para NF ou de volta.
  /// Cada contato escolhe o dele: um temporizador pode ter os dois ao mesmo
  /// tempo, e mudar um não mexe no outro.
  void _trocarTipoContato(TipoElemento tipo) {
    final elemento = _escolhido;
    if (elemento == null || elemento.tipo == tipo) return;
    if (elemento.tipo != TipoElemento.contatoTemporizado &&
        elemento.tipo != TipoElemento.contatoTemporizadoNf) {
      return;
    }
    _aplicar(circuito.atualizar(elemento.copiarCom(tipo: tipo)));
    _escolher(elemento.id);
  }

  void _escolherRele(String id) {
    final elemento = _escolhido;
    if (elemento == null || elemento.tipo != TipoElemento.contatoRele) return;
    _aplicar(circuito.atualizar(elemento.copiarCom(contatoDe: id)));
    _escolher(elemento.id);
  }

  void _escolherBobina(String id) {
    final elemento = _escolhido;
    if (elemento == null ||
        (elemento.tipo != TipoElemento.contatoSelo &&
            elemento.tipo != TipoElemento.contatoNf &&
            elemento.tipo != TipoElemento.contatoPotencia)) {
      return;
    }
    _aplicar(circuito.atualizar(elemento.copiarCom(contatoDe: id)));
    _escolher(elemento.id);
  }

  @override
  Widget build(BuildContext context) {
    final rotulos = circuito.rotulos();
    final elemento = _escolhido;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulador de circuitos',
            style: TextStyle(fontSize: 15)),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _cartao(
          key: const ValueKey('aviso-simulador'),
          cor: const Color(0xFF65D49A),
          icone: Icons.science_outlined,
          texto:
              'Simulação DC calculada no aparelho: fonte, resistor, lâmpada, '
              'interruptor, fusível, botoeira, bobina de contator, contatos '
              'auxiliares, contato de potência, relé térmico e motor DC. O '
              'resultado numérico é real, mas não é o CADeSIMU: corrente '
              'corrente alternada, motor de indução nem CLP.',
        ),
        const SizedBox(height: 12),
        TabuleiroCircuito(
          key: const ValueKey('circuito-tabuleiro'),
          circuito: circuito,
          resultado: resultado,
          selecionado: selecionado,
          rotulos: rotulos,
          tempos: tempos,
          temposQueda: temposQueda,
          temposContato: temposContato,
          temposQuedaContato: temposQuedaContato,
          onTrecho: _tocarTrecho,
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 7, runSpacing: 7, children: [
          for (final f in Ferramenta.values)
            ChoiceChip(
              key: ValueKey('ferramenta-${f.name}'),
              label: Text(_nomeFerramenta[f]!,
                  style: const TextStyle(fontSize: 10)),
              selected: ferramenta == f,
              backgroundColor: panel,
              side: const BorderSide(color: Colors.white12),
              onSelected: (_) {
                setState(() => ferramenta = f);
                if (f == Ferramenta.apagar) _escolher(null);
              },
            ),
        ]),
        const SizedBox(height: 6),
        const Text(
          'Toque num trecho vazio para inserir a ferramenta escolhida. Toque '
          'num componente para selecioná-lo, mudar o valor, abrir o '
          'interruptor ou removê-lo.',
          style: TextStyle(color: muted, fontSize: 10, height: 1.45),
        ),
        if (elemento != null) ...[
          const SizedBox(height: 12),
          _editor(elemento, rotulos[elemento.id] ?? ''),
        ],
        const SizedBox(height: 14),
        const Eyebrow('CIRCUITOS DE EXEMPLO'),
        const SizedBox(height: 6),
        Wrap(spacing: 7, runSpacing: 7, children: [
          for (final exemplo in exemplosCircuito)
            ActionChip(
              key: ValueKey('exemplo-${exemplo.nome}'),
              label:
                  Text(exemplo.nome, style: const TextStyle(fontSize: 10)),
              backgroundColor: panel,
              side: const BorderSide(color: Colors.white12),
              onPressed: () {
                _aplicar(exemplo.montar());
                _escolher(null);
              },
            ),
        ]),
        const SizedBox(height: 16),
        _resultado(rotulos),
        const SizedBox(height: 16),
        _engenharia(),
        const SizedBox(height: 16),
        const Text(
          'Limites declarados: corrente contínua, elementos lineares, fontes '
          'ideais e comando por contator (bobina puxa acima de 70% da tensão e '
          'solta abaixo de 50%, contatos de selo e NF de intertravamento, tudo '
          'resolvido por iteração até estabilizar); fios, contatos e fusíveis '
          'têm 1 µΩ. O motor é tratado como carga resistiva e o relé térmico '
          'desarma no instante em que a corrente passa do ajuste, sem curva de '
          'tempo: a corrente de partida de um motor real é várias vezes maior e '
          'isso não é simulável aqui. O temporizador também não corre sozinho: '
          'cada toque em Avançar 1 s soma um segundo no relógio dele, porque a '
          'conta é instantânea e não existe animação de tempo. Não há CA, '
          'transitórios, motor de indução, CLP nem leitura do arquivo .cad. Um '
          'circuito só é considerado funcional dentro destas condições.',
          style: TextStyle(color: muted, fontSize: 10, height: 1.5),
        ),
      ]),
    );
  }

  Widget _engenharia() {
    return Container(
      key: const ValueKey('engenharia-circuito'),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Eyebrow('ENGENHARIA'),
        const SizedBox(height: 6),
        const Text(
          'Verificação de ligações, lista de materiais, arquivo .circ e '
          'dimensionamento de condutor e disjuntor (tabela resumida NBR 5410).',
          style: TextStyle(color: muted, fontSize: 10, height: 1.45),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 7, runSpacing: 7, children: [
          ActionChip(
            key: const ValueKey('verificar-ligacoes'),
            label: const Text('Verificar ligações',
                style: TextStyle(fontSize: 10)),
            backgroundColor: bg,
            side: const BorderSide(color: Colors.white12),
            onPressed: _verificarLigacoes,
          ),
          ActionChip(
            key: const ValueKey('lista-de-materiais'),
            label: const Text('Lista de materiais',
                style: TextStyle(fontSize: 10)),
            backgroundColor: bg,
            side: const BorderSide(color: Colors.white12),
            onPressed: () async {
              final texto = listaDeMateriais(circuito);
              await Clipboard.setData(ClipboardData(text: texto));
              if (!mounted) return;
              await _mostrarTexto('Lista de materiais', texto);
            },
          ),
          ActionChip(
            key: const ValueKey('exportar-circuito'),
            label: const Text('Exportar .circ',
                style: TextStyle(fontSize: 10)),
            backgroundColor: bg,
            side: const BorderSide(color: Colors.white12),
            onPressed: _exportarCircuito,
          ),
          ActionChip(
            key: const ValueKey('importar-circuito'),
            label: const Text('Importar .circ',
                style: TextStyle(fontSize: 10)),
            backgroundColor: bg,
            side: const BorderSide(color: Colors.white12),
            onPressed: _importarCircuito,
          ),
          ActionChip(
            key: const ValueKey('dimensionar-circuito'),
            label: const Text('Dimensionar', style: TextStyle(fontSize: 10)),
            backgroundColor: bg,
            side: const BorderSide(color: Colors.white12),
            onPressed: _dimensionar,
          ),
          ActionChip(
            key: const ValueKey('clp-didatico'),
            label: const Text('CLP didático', style: TextStyle(fontSize: 10)),
            backgroundColor: bg,
            side: const BorderSide(color: Colors.white12),
            onPressed: _clpDidatico,
          ),
        ]),
      ]),
    );
  }

  Future<void> _mostrarTexto(String titulo, String texto) {
    return showDialog<void>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text(titulo, style: const TextStyle(fontSize: 15)),
        content: SingleChildScrollView(
          child: SelectableText(texto,
              style: const TextStyle(fontSize: 11, height: 1.45)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  void _verificarLigacoes() {
    final achados = diagnosticarCircuito(circuito);
    final texto = achados.map((d) => '• ${d.texto}').join('\n\n');
    _mostrarTexto('Verificação de ligações', texto);
  }

  Future<void> _exportarCircuito() async {
    final texto = circuitoParaTexto(circuito);
    await Clipboard.setData(ClipboardData(text: texto));
    final enviado = await SistemaAndroid.compartilhar(texto);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(enviado
          ? 'Circuito exportado no formato .circ e copiado.'
          : 'Circuito .circ copiado. Compartilhar não está disponível aqui.'),
    ));
  }

  Future<void> _importarCircuito() async {
    final campo = TextEditingController();
    final texto = await showDialog<String>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Importar .circ', style: TextStyle(fontSize: 15)),
        content: TextField(
          key: const ValueKey('campo-importar-circuito'),
          controller: campo,
          maxLines: 6,
          style: const TextStyle(fontSize: 11),
          decoration: const InputDecoration(
            hintText: 'Cole aqui o conteúdo do arquivo .circ',
            hintStyle: TextStyle(fontSize: 10),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('confirmar-importar-circuito'),
            onPressed: () => Navigator.of(contexto).pop(campo.text),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    if (texto == null || texto.trim().isEmpty) return;
    try {
      final novo = circuitoDeTexto(texto);
      _aplicar(novo);
      _escolher(null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Circuito importado do arquivo .circ.')));
    } on FormatException catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Não foi possível importar: ${erro.message}')));
    }
  }

  void _dimensionar() {
    Elemento? primeiraCarga;
    for (final e in circuito.elementos) {
      if (e.tipo == TipoElemento.motor || e.tipo == TipoElemento.lampada) {
        primeiraCarga = e;
        break;
      }
    }
    final carga = _escolhido != null &&
            (_escolhido!.tipo == TipoElemento.motor ||
                _escolhido!.tipo == TipoElemento.lampada)
        ? _escolhido
        : primeiraCarga;
    final potencia = TextEditingController(
        text: formatarNumero(carga?.valor ?? 1000));
    final tensao =
        TextEditingController(text: formatarNumero(carga?.tensaoNominal ?? 220));
    final comprimento = TextEditingController(text: '20');
    showDialog<void>(
      context: context,
      builder: (contexto) => StatefulBuilder(
        builder: (contexto, mudar) {
          final p = double.tryParse(potencia.text.replaceAll(',', '.'));
          final v = double.tryParse(tensao.text.replaceAll(',', '.'));
          final d = double.tryParse(comprimento.text.replaceAll(',', '.'));
          Dimensionamento? r;
          String? erro;
          if (p == null || v == null || d == null || p <= 0 || v <= 0) {
            erro = 'Informe potência, tensão e comprimento válidos.';
          } else {
            r = carga?.tipo == TipoElemento.motor
                ? dimensionarMotor(
                    potenciaW: p, tensaoV: v, comprimentoM: d)
                : dimensionarCarga(potenciaW: p, tensaoV: v, comprimentoM: d);
          }
          return AlertDialog(
            title: const Text('Dimensionamento', style: TextStyle(fontSize: 15)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: const ValueKey('dimensionar-potencia'),
                    controller: potencia,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Potência (W)',
                        labelStyle: TextStyle(fontSize: 11)),
                  ),
                  TextField(
                    key: const ValueKey('dimensionar-tensao'),
                    controller: tensao,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Tensão (V)',
                        labelStyle: TextStyle(fontSize: 11)),
                  ),
                  TextField(
                    key: const ValueKey('dimensionar-comprimento'),
                    controller: comprimento,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Distância (m)',
                        labelStyle: TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(height: 10),
                  if (erro != null)
                    Text(erro,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFFFF8A80)))
                  else if (r != null) ...[
                    Text(
                      r.aprovado
                          ? 'Dentro dos limites adotados.'
                          : 'Fora dos limites: revise seção ou distância.',
                      style: TextStyle(
                          fontSize: 11,
                          color: r.aprovado
                              ? const Color(0xFF65D49A)
                              : const Color(0xFFFFD27F)),
                    ),
                    const SizedBox(height: 4),
                    for (final linha in r.observacoes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text('• $linha',
                            style: const TextStyle(
                                fontSize: 11, height: 1.4)),
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(contexto).pop(),
                child: const Text('Fechar'),
              ),
              FilledButton(
                key: const ValueKey('calcular-dimensionamento'),
                onPressed: () => mudar(() {}),
                child: const Text('Calcular'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _clpDidatico() {
    final programa = clpPartidaComSelo();
    var acionadas = <String>{};
    var saidas = <String, bool>{};
    showDialog<void>(
      context: context,
      builder: (contexto) => StatefulBuilder(
        builder: (contexto, mudar) {
          final entradas = {for (final i in entradasDoClp(programa)) i: acionadas.contains(i)};
          final r = programa.executar(entradas, saidasIniciais: saidas);
          saidas = r.saidas;
          final ligada = r.saidas['Q1'] ?? false;
          return AlertDialog(
            title: const Text('CLP didático', style: TextStyle(fontSize: 15)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Programa de partida direta com selo:\n'
                    'I1 (partida) em paralelo com Q1 (selo), em série com I2 '''
                    '(parada NF) → Q1.\n'
                    'Isto é lógica ladder calculada por ciclos; não é um CLP '''
                    'físico nem simulação elétrica.',
                    style: TextStyle(fontSize: 10, height: 1.4),
                  ),
                  SwitchListTile(
                    key: const ValueKey('clp-i1'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('I1 — partida', style: TextStyle(fontSize: 11)),
                    value: acionadas.contains('I1'),
                    onChanged: (v) => mudar(() {
                      v ? acionadas.add('I1') : acionadas.remove('I1');
                    }),
                  ),
                  SwitchListTile(
                    key: const ValueKey('clp-i2'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('I2 — parada (NF)', style: TextStyle(fontSize: 11)),
                    value: acionadas.contains('I2'),
                    onChanged: (v) => mudar(() {
                      v ? acionadas.add('I2') : acionadas.remove('I2');
                    }),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ligada ? 'Q1 ligada' : 'Q1 desligada',
                    key: const ValueKey('clp-saida'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ligada ? const Color(0xFF65D49A) : const Color(0xFFFF8A80),
                    ),
                  ),
                  Text(
                    'Ciclos até estabilizar: ${r.ciclos}'
                    '${r.estabilizou ? '' : ' (não estabilizou)'}',
                    style: const TextStyle(fontSize: 10, color: muted),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(contexto).pop(),
                child: const Text('Fechar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _editor(Elemento elemento, String rotulo) {
    final mapaRotulos = circuito.rotulos();
    final temValor = switch (elemento.tipo) {
      TipoElemento.fonte ||
      TipoElemento.resistor ||
      TipoElemento.lampada ||
      TipoElemento.fusivel ||
      TipoElemento.bobina ||
      TipoElemento.motor ||
      TipoElemento.releTermico =>
        true,
      _ => false,
    };
    return Container(
      key: const ValueKey('editor-elemento'),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: cyan.withValues(alpha: .18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              '$rotulo · ${_descricao(elemento)}',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            key: const ValueKey('remover-elemento'),
            onPressed: () {
              _aplicar(circuito.removerEm(elemento.a, elemento.b));
              _escolher(null);
            },
            child: const Text('Remover',
                style: TextStyle(fontSize: 10, color: Color(0xFFFF8A80))),
          ),
        ]),
        if (temValor) ...[
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: TextField(
                key: const ValueKey('campo-valor-elemento'),
                controller: campo,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: _unidade(elemento),
                  labelStyle: const TextStyle(fontSize: 10, color: muted),
                  filled: true,
                  fillColor: bg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            if (elemento.tipo == TipoElemento.lampada ||
                elemento.tipo == TipoElemento.bobina ||
                elemento.tipo == TipoElemento.motor) ...[
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const ValueKey('campo-tensao-elemento'),
                  controller: campoTensao,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: switch (elemento.tipo) {
                      TipoElemento.lampada => 'tensão nominal (V)',
                      TipoElemento.motor => 'tensão do motor (V)',
                      _ => 'tensão da bobina (V)',
                    },
                    labelStyle: const TextStyle(fontSize: 10, color: muted),
                    filled: true,
                    fillColor: bg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            FilledButton(
              key: const ValueKey('aplicar-valor-elemento'),
              onPressed: _aplicarValor,
              child: const Text('Aplicar', style: TextStyle(fontSize: 10)),
            ),
          ]),
        ],
        if (elemento.tipo == TipoElemento.interruptor) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const ValueKey('alternar-interruptor'),
              onPressed: _alternar,
              icon: Icon(
                  elemento.fechado
                      ? Icons.toggle_on_rounded
                      : Icons.toggle_off_rounded,
                  size: 18),
              label: Text(
                  elemento.fechado
                      ? 'Abrir interruptor'
                      : 'Fechar interruptor',
                  style: const TextStyle(fontSize: 10)),
            ),
          ),
        ],
        if (elemento.tipo == TipoElemento.botoeira) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 7, runSpacing: 7, children: [
            FilledButton.icon(
              key: const ValueKey('apertar-botoeira'),
              onPressed: _apertarBotoeira,
              icon: Icon(
                  elemento.pressionada
                      ? Icons.pan_tool_alt_rounded
                      : Icons.touch_app_rounded,
                  size: 18),
              label: Text(
                  elemento.sensor
                      ? (elemento.pressionada
                          ? 'Soltar sensor'
                          : 'Acionar sensor')
                      : (elemento.pressionada
                          ? 'Soltar botoeira'
                          : 'Apertar botoeira'),
                  style: const TextStyle(fontSize: 10)),
            ),
            OutlinedButton(
              key: const ValueKey('alternar-tipo-botoeira'),
              onPressed: _trocarTipoBotoeira,
              child: Text(
                  elemento.normalmenteFechado
                      ? 'NF: aberta ao apertar'
                      : 'NA: fechada ao apertar',
                  style: const TextStyle(fontSize: 10)),
            ),
          ]),
        ],
        if (elemento.tipo == TipoElemento.contatoSelo ||
            elemento.tipo == TipoElemento.contatoNf ||
            elemento.tipo == TipoElemento.contatoPotencia) ...[
          const SizedBox(height: 6),
          const Text('Contato comandado pela bobina:',
              style: TextStyle(fontSize: 10, color: muted)),
          const SizedBox(height: 4),
          Wrap(spacing: 7, runSpacing: 7, children: [
            for (final bobina in circuito.elementos
                .where((e) => e.tipo == TipoElemento.bobina))
              ChoiceChip(
                key: ValueKey('bobina-do-selo-${bobina.id}'),
                label: Text(mapaRotulos[bobina.id] ?? 'bobina',
                    style: const TextStyle(fontSize: 10)),
                selected: elemento.contatoDe == bobina.id,
                backgroundColor: bg,
                side: const BorderSide(color: Colors.white12),
                onSelected: (_) => _escolherBobina(bobina.id),
              ),
          ]),
          if (!circuito.elementos.any((e) => e.tipo == TipoElemento.bobina))
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Sem bobina no circuito: o selo fica sempre aberto. Monte uma '
                'bobina de contator para comandá-lo.',
                style: TextStyle(fontSize: 10, color: Color(0xFFFFC66D)),
              ),
            ),
        ],
        if (elemento.tipo == TipoElemento.contatoRele) ...[
          const SizedBox(height: 6),
          const Text('Contato 95/96 do relé:',
              style: TextStyle(fontSize: 10, color: muted)),
          const SizedBox(height: 4),
          Wrap(spacing: 7, runSpacing: 7, children: [
            for (final rele in circuito.elementos
                .where((e) => e.tipo == TipoElemento.releTermico))
              ChoiceChip(
                key: ValueKey('rele-do-contato-${rele.id}'),
                label: Text(mapaRotulos[rele.id] ?? 'relé',
                    style: const TextStyle(fontSize: 10)),
                selected: elemento.contatoDe == rele.id,
                backgroundColor: bg,
                side: const BorderSide(color: Colors.white12),
                onSelected: (_) => _escolherRele(rele.id),
              ),
          ]),
          if (!circuito.elementos
              .any((e) => e.tipo == TipoElemento.releTermico))
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Sem relé térmico no circuito: o contato 95/96 fica fechado '
                'sem proteger nada.',
                style: TextStyle(fontSize: 10, color: Color(0xFFFFC66D)),
              ),
            ),
        ],
        if (elemento.tipo == TipoElemento.releTermico && elemento.desarmado) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const ValueKey('rearmar-rele'),
              onPressed: () => _aplicar(circuito.rearmarReles()),
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Rearmar relé', style: TextStyle(fontSize: 10)),
            ),
          ),
        ],
        if (elemento.tipo == TipoElemento.contatoTemporizado ||
            elemento.tipo == TipoElemento.contatoTemporizadoNf) ...[
          const SizedBox(height: 6),
          Text(
              elemento.tipo == TipoElemento.contatoTemporizadoNf
                  ? 'Contato 67/68 NF do temporizador:'
                  : 'Contato 67/68 do temporizador:',
              style: const TextStyle(fontSize: 10, color: muted)),
          const SizedBox(height: 4),
          Wrap(spacing: 7, runSpacing: 7, children: [
            for (final timer in circuito.elementos
                .where((e) => e.tipo == TipoElemento.temporizador))
              ChoiceChip(
                key: ValueKey('temporizador-do-contato-${timer.id}'),
                label: Text(mapaRotulos[timer.id] ?? 'temporizador',
                    style: const TextStyle(fontSize: 10)),
                selected: elemento.contatoDe == timer.id,
                backgroundColor: bg,
                side: const BorderSide(color: Colors.white12),
                onSelected: (_) => _escolherTemporizador(timer.id),
              ),
          ]),
          if (!circuito.elementos
              .any((e) => e.tipo == TipoElemento.temporizador))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                elemento.tipo == TipoElemento.contatoTemporizadoNf
                    ? 'Sem temporizador no circuito: o contato 67/68 NF fica '
                        'sempre fechado.'
                    : 'Sem temporizador no circuito: o contato 67/68 fica sempre '
                        'aberto.',
                style:
                    const TextStyle(fontSize: 10, color: Color(0xFFFFC66D)),
              ),
            ),
          const SizedBox(height: 6),
          const Text('Tipo deste contato (cada contato escolhe o dele):',
              style: TextStyle(fontSize: 10, color: muted)),
          const SizedBox(height: 4),
          Wrap(spacing: 7, runSpacing: 7, children: [
            ChoiceChip(
              key: const ValueKey('contato-tipo-na'),
              label: const Text('67/68 NA', style: TextStyle(fontSize: 10)),
              selected: elemento.tipo == TipoElemento.contatoTemporizado,
              backgroundColor: bg,
              side: const BorderSide(color: Colors.white12),
              onSelected: (_) =>
                  _trocarTipoContato(TipoElemento.contatoTemporizado),
            ),
            ChoiceChip(
              key: const ValueKey('contato-tipo-nf'),
              label: const Text('67/68 NF', style: TextStyle(fontSize: 10)),
              selected: elemento.tipo == TipoElemento.contatoTemporizadoNf,
              backgroundColor: bg,
              side: const BorderSide(color: Colors.white12),
              onSelected: (_) =>
                  _trocarTipoContato(TipoElemento.contatoTemporizadoNf),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Atraso deste contato: '
            '${formatarNumero(circuito.atrasoDoContato(elemento), casas: 0)} s '
            '${elemento.atraso > 0 ? '(próprio)' : '(o do temporizador)'}',
            key: const ValueKey('atraso-contato'),
            style: const TextStyle(fontSize: 10, color: muted),
          ),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: TextField(
                key: const ValueKey('campo-atraso-contato'),
                controller: campoAtrasoContato,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'atraso próprio (s, 0 = o do temporizador)',
                  labelStyle: const TextStyle(fontSize: 10, color: muted),
                  filled: true,
                  fillColor: bg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const ValueKey('aplicar-atraso-contato'),
              onPressed: _aplicarAtrasoContato,
              child: const Text('Aplicar', style: TextStyle(fontSize: 10)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Retardo na queda deste contato: '
            '${formatarNumero(circuito.atrasoQuedaDoContato(elemento), casas: 0)} s '
            '${elemento.atrasoQueda > 0 ? '(próprio)' : '(o do temporizador)'}',
            key: const ValueKey('queda-contato'),
            style: const TextStyle(fontSize: 10, color: muted),
          ),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: TextField(
                key: const ValueKey('campo-queda-contato'),
                controller: campoQuedaContato,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'queda própria (s, 0 = a do temporizador)',
                  labelStyle: const TextStyle(fontSize: 10, color: muted),
                  filled: true,
                  fillColor: bg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const ValueKey('aplicar-queda-contato'),
              onPressed: _aplicarQuedaContato,
              child: const Text('Aplicar', style: TextStyle(fontSize: 10)),
            ),
          ]),
        ],
        if (elemento.tipo == TipoElemento.temporizador) ...[
          const SizedBox(height: 6),
          Text(
            'Relógio: '
            '${formatarNumero(tempos[elemento.id] ?? 0, casas: 0)} s de '
            '${formatarNumero(elemento.atraso, casas: 0)} s (ajuste base)',
            key: const ValueKey('relogio-temporizador'),
            style: const TextStyle(fontSize: 10, color: muted),
          ),
          if (elemento.atrasoQueda > 0) ...[
            Text(
              'Queda: '
              '${formatarNumero(temposQueda[elemento.id] ?? 0, casas: 0)} s de '
              '${formatarNumero(elemento.atrasoQueda, casas: 0)} s',
              key: const ValueKey('relogio-queda'),
              style: const TextStyle(fontSize: 10, color: muted),
            ),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('campo-atraso-queda'),
                  controller: campoQueda,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'retardo na queda (s)',
                    labelStyle: const TextStyle(fontSize: 10, color: muted),
                    filled: true,
                    fillColor: bg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const ValueKey('aplicar-atraso-queda'),
                onPressed: _aplicarQueda,
                child: const Text('Aplicar', style: TextStyle(fontSize: 10)),
              ),
            ]),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const ValueKey('avancar-tempo'),
              onPressed: _avancarTempo,
              icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
              label:
                  const Text('Avançar 1 s', style: TextStyle(fontSize: 10)),
            ),
          ),
        ],
        if (elemento.tipo == TipoElemento.fusivel && elemento.queimado) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const ValueKey('trocar-fusivel'),
              onPressed: () => _aplicar(circuito.trocarFusiveis()),
              icon: const Icon(Icons.autorenew_rounded, size: 18),
              label:
                  const Text('Trocar fusível', style: TextStyle(fontSize: 10)),
            ),
          ),
        ],
        if (erroCampo != null) ...[
          const SizedBox(height: 6),
          Text(erroCampo!,
              style: const TextStyle(
                  color: Color(0xFFFF8A80), fontSize: 10, height: 1.4)),
        ],
      ]),
    );
  }

  Widget _resultado(Map<String, String> rotulos) {
    final calculo = resultado;
    return Container(
      key: const ValueKey('resultado-circuito'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1A16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF65D49A).withValues(alpha: .22)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Eyebrow('RESULTADO DA SIMULAÇÃO')),
          TextButton(
            key: const ValueKey('recalcular-circuito'),
            onPressed: () => _aplicar(circuito),
            child: const Text('Recalcular', style: TextStyle(fontSize: 10)),
          ),
        ]),
        if (!calculo.calculado) ...[
          Text(
            calculo.erro ?? 'Sem solução para este circuito.',
            style: const TextStyle(
                color: Color(0xFFFFC66D), fontSize: 11.5, height: 1.45),
          ),
        ] else ...[
          Text(
            'Potência nas cargas: ${formatarNumero(calculo.potenciaTotal)} W',
            style: const TextStyle(fontSize: 11, color: muted),
          ),
          const SizedBox(height: 6),
          for (final elemento in circuito.elementos)
            if (elemento.tipo != TipoElemento.fio)
              _linhaMedida(elemento, rotulos[elemento.id] ?? ''),
          if (calculo.avisos.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final aviso in calculo.avisos) _aviso(aviso),
          ],
        ],
      ]),
    );
  }

  Widget _linhaMedida(Elemento elemento, String rotulo) {
    final medida = resultado.medidas[elemento.id];
    final cor = switch (elemento.tipo) {
      TipoElemento.lampada => const Color(0xFFFFD27F),
      TipoElemento.fusivel => const Color(0xFFFF8A80),
      TipoElemento.interruptor => const Color(0xFF9AD5FF),
      TipoElemento.fonte => const Color(0xFF65D49A),
      TipoElemento.bobina => const Color(0xFFFFC66D),
      TipoElemento.botoeira => const Color(0xFF9AD5FF),
      TipoElemento.contatoSelo => const Color(0xFFFFC66D),
      TipoElemento.contatoNf => const Color(0xFFFFC66D),
      TipoElemento.contatoPotencia => const Color(0xFFFFD27F),
      TipoElemento.motor => const Color(0xFF65D49A),
      TipoElemento.releTermico => const Color(0xFFFF8A80),
      TipoElemento.contatoRele => const Color(0xFFFF8A80),
      TipoElemento.temporizador => const Color(0xFF9AD5FF),
      TipoElemento.contatoTemporizado => const Color(0xFF9AD5FF),
      TipoElemento.contatoTemporizadoNf => const Color(0xFF9AD5FF),
      _ => const Color(0xFFCFE6F2),
    };
    final estado = switch (elemento.tipo) {
      TipoElemento.interruptor => elemento.fechado ? 'fechado' : 'aberto',
      TipoElemento.fusivel => elemento.queimado ? 'queimado' : 'inteiro',
      TipoElemento.botoeira => elemento.sensor
          ? (elemento.pressionada ? 'acionado' : 'em repouso')
          : (elemento.pressionada ? 'apertada' : 'solta'),
      TipoElemento.bobina => resultado.bobinasLigadas.contains(elemento.id)
          ? 'ligada'
          : 'desligada',
      TipoElemento.contatoSelo =>
        elemento.contatoDe != null &&
                resultado.bobinasLigadas.contains(elemento.contatoDe)
            ? 'fechado'
            : 'aberto',
      TipoElemento.contatoNf =>
        elemento.contatoDe != null &&
                resultado.bobinasLigadas.contains(elemento.contatoDe)
            ? 'aberto'
            : 'fechado',
      TipoElemento.contatoPotencia =>
        elemento.contatoDe != null &&
                resultado.bobinasLigadas.contains(elemento.contatoDe)
            ? 'fechado'
            : 'aberto',
      TipoElemento.releTermico => elemento.desarmado ? 'desarmado' : 'armado',
      TipoElemento.contatoRele =>
        elemento.contatoDe != null &&
                resultado.relesDesarmados.contains(elemento.contatoDe)
            ? 'aberto'
            : 'fechado',
      TipoElemento.temporizador => resultado.temporizadoresAtivos
              .contains(elemento.id)
          ? 'contando ${formatarNumero(tempos[elemento.id] ?? 0, casas: 0)} s '
              'de ${formatarNumero(elemento.atraso, casas: 0)} s'
          : _temporizadorAcionado(elemento)
              ? 'segurando na queda '
                  '${formatarNumero(temposQueda[elemento.id] ?? 0, casas: 0)} s '
                  'de ${formatarNumero(elemento.atrasoQueda, casas: 0)} s'
              : 'sem energia',
      TipoElemento.contatoTemporizado ||
      TipoElemento.contatoTemporizadoNf =>
        _contatoTemporizadoFechado(elemento) ? 'fechado' : 'aberto',
      _ => '',
    };
    final texto = medida == null
        ? 'sem medida'
        : '${formatarNumero(medida.tensao.abs())} V · '
            '${formatarNumero(medida.corrente.abs(), casas: 3)} A · '
            '${formatarNumero(medida.potencia.abs())} W'
            '${elemento.tipo == TipoElemento.lampada && elemento.valor > 0 ? ' · ${((medida.potencia.abs() / elemento.valor) * 100).clamp(0, 100).round()}% do brilho' : ''}';
    return Padding(
      key: ValueKey('medida-${elemento.id}'),
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 34,
          child: Text(rotulo,
              style: TextStyle(
                  fontSize: 10, color: cor, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '${_descricao(elemento)}${estado.isEmpty ? '' : ' · $estado'}',
              style: const TextStyle(fontSize: 10.5),
            ),
            Text(texto,
                style: const TextStyle(color: muted, fontSize: 10)),
          ]),
        ),
      ]),
    );
  }

  Widget _aviso(AvisoCircuito aviso) {
    final cor = switch (aviso.gravidade) {
      GravidadeAviso.erro => const Color(0xFFFF8A80),
      GravidadeAviso.atencao => const Color(0xFFFFC66D),
      GravidadeAviso.info => const Color(0xFF9AD5FF),
    };
    final icone = switch (aviso.gravidade) {
      GravidadeAviso.erro => Icons.error_outline_rounded,
      GravidadeAviso.atencao => Icons.warning_amber_rounded,
      GravidadeAviso.info => Icons.info_outline_rounded,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icone, size: 14, color: cor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(aviso.texto,
              style: TextStyle(color: cor, fontSize: 10.5, height: 1.4)),
        ),
      ]),
    );
  }

  Widget _cartao({
    required Key key,
    required Color cor,
    required IconData icone,
    required String texto,
  }) =>
      Container(
        key: key,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1A16),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: cor.withValues(alpha: .22)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icone, color: cor, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(texto,
                style: const TextStyle(color: muted, fontSize: 11, height: 1.45)),
          ),
        ]),
      );

  String _descricao(Elemento e) => switch (e.tipo) {
        TipoElemento.fonte => 'fonte de ${formatarNumero(e.valor)} V',
        TipoElemento.resistor => 'resistor de ${formatarNumero(e.valor)} Ω',
        TipoElemento.lampada =>
          'lâmpada ${formatarNumero(e.tensaoNominal, casas: 0)} V / '
              '${formatarNumero(e.valor)} W',
        TipoElemento.interruptor => 'interruptor',
        TipoElemento.fusivel => 'fusível de ${formatarNumero(e.valor)} A',
        TipoElemento.botoeira => e.sensor
            ? (e.normalmenteFechado
                ? 'sensor NF (abre ao ser acionado)'
                : 'sensor NA (fecha ao ser acionado)')
            : (e.normalmenteFechado
                ? 'botoeira NF (abre ao apertar)'
                : 'botoeira NA (fecha ao apertar)'),
        TipoElemento.bobina =>
          'bobina de contator ${formatarNumero(e.tensaoNominal, casas: 0)} V / '
              '${formatarNumero(e.valor)} Ω',
        TipoElemento.contatoSelo => 'contato de selo (NA)',
        TipoElemento.contatoNf => 'contato NF auxiliar (21-22)',
        TipoElemento.contatoPotencia => 'contato principal (1-2)',
        TipoElemento.motor =>
          'motor ${formatarNumero(e.tensaoNominal, casas: 0)} V / '
              '${formatarNumero(e.valor)} W',
        TipoElemento.releTermico =>
          'relé térmico ajustado em ${formatarNumero(e.valor)} A',
        TipoElemento.contatoRele => 'contato 95/96 do relé',
        TipoElemento.temporizador =>
          'temporizador com atraso de ${formatarNumero(e.atraso, casas: 0)} s'
              '${e.atrasoQueda > 0 ? ' e ${formatarNumero(e.atrasoQueda, casas: 0)} s na queda' : ''}',
        TipoElemento.contatoTemporizado =>
          'contato 67/68 do temporizador${_ajustesDoContato(e)}',
        TipoElemento.contatoTemporizadoNf =>
          e.atraso > 0 || e.atrasoQueda > 0
              ? 'contato 67/68 NF do temporizador${_ajustesDoContato(e)}'
              : 'contato 67/68 NF do temporizador (abre no fim do atraso)',
        TipoElemento.fio => 'fio',
      };

  /// " com atraso de 1 s e queda de 2 s", conforme o que foi ajustado no
  /// próprio contato.
  String _ajustesDoContato(Elemento e) {
    final partes = <String>[];
    if (e.atraso > 0) {
      partes.add('atraso de ${formatarNumero(e.atraso, casas: 0)} s');
    }
    if (e.atrasoQueda > 0) {
      partes.add('queda de ${formatarNumero(e.atrasoQueda, casas: 0)} s');
    }
    return partes.isEmpty ? '' : ' com ${partes.join(' e ')}';
  }

  String _unidade(Elemento e) => switch (e.tipo) {
        TipoElemento.fonte => 'tensão (V)',
        TipoElemento.resistor => 'resistência (Ω)',
        TipoElemento.lampada => 'potência (W)',
        TipoElemento.fusivel => 'corrente de ruptura (A)',
        TipoElemento.bobina => 'resistência da bobina (Ω)',
        TipoElemento.motor => 'potência do motor (W)',
        TipoElemento.releTermico => 'corrente de ajuste (A)',
        TipoElemento.temporizador => 'atraso (s)',
        _ => 'valor',
      };
}
