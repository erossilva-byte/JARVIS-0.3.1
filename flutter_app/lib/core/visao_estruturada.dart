/// Análise estruturada da visão e geometria dos balões.
///
/// Este arquivo é puro Dart: não usa Flutter, rede ou armazenamento. Isso permite
/// testar o parser e o posicionamento sem abrir a câmera ou chamar um provedor.
library;

import 'dart:convert';
import 'dart:math' as math;

class CaixaVisao {
  const CaixaVisao(
      {required this.x, required this.y, required this.w, required this.h});

  /// Coordenadas normalizadas (0..1) em relação à imagem.
  final double x;
  final double y;
  final double w;
  final double h;

  bool get valida => w > 0 && h > 0;
}

class ObjetoVisao {
  const ObjetoVisao({
    required this.rotulo,
    this.confianca,
    this.caixa,
    this.detalhe,
  });

  final String rotulo;
  final double? confianca;
  final CaixaVisao? caixa;
  final String? detalhe;
}

class AnaliseVisao {
  const AnaliseVisao({
    required this.resumo,
    required this.objetos,
    this.textoLegivel = const [],
    this.estruturada = true,
    this.textoOriginal = '',
  });

  final String resumo;
  final List<ObjetoVisao> objetos;
  final List<String> textoLegivel;
  final bool estruturada;
  final String textoOriginal;

  bool get temObjetosComCaixa => objetos.any((o) => o.caixa?.valida == true);
  bool get vazia =>
      resumo.trim().isEmpty && objetos.isEmpty && textoLegivel.isEmpty;

  /// Texto legível para a tela. Nunca mostra o JSON cru.
  String get textoExibicao {
    final partes = <String>[];
    if (resumo.trim().isNotEmpty) partes.add(resumo.trim());
    for (final objeto in objetos) {
      final nome = objeto.rotulo.trim();
      if (nome.isEmpty) continue;
      final confianca = objeto.confianca == null
          ? ''
          : ' (${(objeto.confianca! * 100).clamp(0, 100).round()}%)';
      final detalhe = (objeto.detalhe ?? '').trim();
      partes.add('$nome$confianca${detalhe.isEmpty ? '' : ': $detalhe'}');
    }
    if (textoLegivel.isNotEmpty) {
      partes.add('Texto legível: ${textoLegivel.join(' · ')}');
    }
    return partes.join('\n\n');
  }
}

double? _numero(Object? valor) {
  if (valor is num) {
    final n = valor.toDouble();
    return n.isFinite ? n : null;
  }
  if (valor is String) {
    final n = double.tryParse(valor.replaceAll(',', '.').trim());
    return n != null && n.isFinite ? n : null;
  }
  return null;
}

double _limitar(double valor, double minimo, double maximo) =>
    math.min(maximo, math.max(minimo, valor));

String _texto(Object? valor) {
  if (valor == null) return '';
  if (valor is String) return valor.trim();
  if (valor is num || valor is bool) return valor.toString();
  return '';
}

String _semCercas(String texto) {
  var limpo = texto.trim();
  if (limpo.startsWith('```')) {
    limpo = limpo.replaceFirst(RegExp(r'^```[a-zA-Z0-9_-]*\s*'), '');
    limpo = limpo.replaceFirst(RegExp(r'\s*```$'), '');
  }
  return limpo.trim();
}

/// Converte rótulos de pessoas em "Pessoa". Não cria nome, idade, emoção ou
/// qualquer outro atributo: a análise nunca deve identificar quem está na foto.
String rotuloSeguro(String bruto) {
  final limpo = bruto.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (limpo.isEmpty) return '';
  final minusculo = limpo.toLowerCase();
  const pessoas = {
    'pessoa',
    'pessoas',
    'person',
    'people',
    'homem',
    'mulher',
    'menino',
    'menina',
    'crianca',
    'criança',
    'adulto',
    'adulta',
    'idoso',
    'idosa',
    'rosto',
    'face',
    'human',
    'humano',
    'man',
    'woman',
    'boy',
    'girl',
    'child',
    'male',
    'female',
  };
  final palavras = minusculo.split(RegExp(r'[^a-zà-ú]+'));
  if (palavras.any(pessoas.contains)) return 'Pessoa';
  return limpo.length <= 48 ? limpo : '${limpo.substring(0, 47)}…';
}

CaixaVisao? _caixa(Object? bruto) {
  double? x;
  double? y;
  double? w;
  double? h;
  if (bruto is List && bruto.length >= 4) {
    x = _numero(bruto[0]);
    y = _numero(bruto[1]);
    w = _numero(bruto[2]);
    h = _numero(bruto[3]);
  } else if (bruto is Map) {
    x = _numero(bruto['x'] ?? bruto['left'] ?? bruto['esquerda']);
    y = _numero(bruto['y'] ?? bruto['top'] ?? bruto['topo']);
    w = _numero(bruto['w'] ?? bruto['width'] ?? bruto['largura']);
    h = _numero(bruto['h'] ?? bruto['height'] ?? bruto['altura']);
  }
  if (x == null || y == null || w == null || h == null) return null;
  if (x > 1 || y > 1 || w > 1 || h > 1) {
    // Alguns modelos devolvem pixels. Sem as dimensões da imagem, é mais seguro
    // recusar do que desenhar um balão no lugar errado.
    return null;
  }
  final cx = _limitar(x, 0, 1);
  final cy = _limitar(y, 0, 1);
  final cw = _limitar(w, 0, 1 - cx);
  final ch = _limitar(h, 0, 1 - cy);
  if (cw <= 0.001 || ch <= 0.001) return null;
  return CaixaVisao(x: cx, y: cy, w: cw, h: ch);
}

List<String> _listaTexto(Object? bruto) {
  if (bruto is String) {
    final limpo = bruto.trim();
    return limpo.isEmpty ? const [] : [limpo];
  }
  if (bruto is List) {
    return bruto
        .map(_texto)
        .where((item) => item.isNotEmpty)
        .take(12)
        .toList(growable: false);
  }
  return const [];
}

/// Lê a resposta do modelo. Aceita JSON cercado por ```json, aceita um objeto
/// único e, se não houver JSON válido, devolve o texto inteiro sem balões.
AnaliseVisao interpretarAnaliseVisao(String corpo) {
  final original = corpo.trim();
  if (original.isEmpty) {
    return const AnaliseVisao(
      resumo: '',
      objetos: [],
      estruturada: false,
    );
  }

  var limpo = _semCercas(original);
  final inicio = limpo.indexOf('{');
  final fim = limpo.lastIndexOf('}');
  if (inicio >= 0 && fim > inicio) limpo = limpo.substring(inicio, fim + 1);

  Map<String, dynamic>? dados;
  try {
    final decodificado = jsonDecode(limpo);
    if (decodificado is Map) dados = decodificado.cast<String, dynamic>();
  } catch (_) {
    dados = null;
  }

  if (dados == null) {
    return AnaliseVisao(
      resumo: _semCercas(original),
      objetos: const [],
      estruturada: false,
      textoOriginal: original,
    );
  }

  final resumo = _texto(
    dados['summary'] ??
        dados['resumo'] ??
        dados['description'] ??
        dados['descricao'],
  );
  final objetosBrutos =
      dados['objects'] ?? dados['objetos'] ?? dados['detections'];
  final objetos = <ObjetoVisao>[];
  if (objetosBrutos is List) {
    for (final item in objetosBrutos) {
      if (item is! Map) continue;
      final mapa = item.cast<String, dynamic>();
      final rotulo = rotuloSeguro(_texto(
        mapa['label'] ??
            mapa['nome'] ??
            mapa['rotulo'] ??
            mapa['name'] ??
            mapa['class'],
      ));
      if (rotulo.isEmpty) continue;
      final confianca =
          _numero(mapa['confidence'] ?? mapa['confianca'] ?? mapa['score']);
      final detalhe = rotulo == 'Pessoa'
          ? 'Pessoa detectada. O app não analisa rosto, idade, gênero ou identidade.'
          : _texto(mapa['info'] ??
              mapa['detalhe'] ??
              mapa['detail'] ??
              mapa['description']);
      objetos.add(ObjetoVisao(
        rotulo: rotulo,
        confianca: confianca == null ? null : _limitar(confianca, 0, 1),
        caixa: _caixa(mapa['bbox'] ?? mapa['box'] ?? mapa['caixa']),
        detalhe: detalhe,
      ));
    }
  }

  final textoLegivel = _listaTexto(
    dados['textoLegivel'] ??
        dados['text'] ??
        dados['texts'] ??
        dados['ocr'] ??
        dados['leitura'],
  );

  if (resumo.isEmpty && objetos.isEmpty && textoLegivel.isEmpty) {
    // JSON válido, mas sem os campos esperados: não mostre o JSON cru na tela.
    return AnaliseVisao(
      resumo: '',
      objetos: const [],
      estruturada: false,
      textoOriginal: original,
    );
  }

  return AnaliseVisao(
    resumo: resumo,
    objetos: List.unmodifiable(objetos),
    textoLegivel: List.unmodifiable(textoLegivel),
    estruturada: true,
    textoOriginal: original,
  );
}

class LinhaGuia {
  const LinhaGuia(
      {required this.x1, required this.y1, required this.x2, required this.y2});

  /// Pontos em porcentagem da imagem.
  final double x1;
  final double y1;
  final double x2;
  final double y2;
}

class BalaoVisao {
  const BalaoVisao({
    required this.indice,
    required this.x,
    required this.y,
    required this.largura,
    required this.altura,
    this.linha,
    this.colisao = false,
    this.semCaixa = false,
  });

  final int indice;

  /// Centro do balão em porcentagem da imagem.
  final double x;
  final double y;
  final double largura;
  final double altura;
  final LinhaGuia? linha;
  final bool colisao;
  final bool semCaixa;
}

class _Retangulo {
  _Retangulo(this.x, this.y, this.w, this.h);
  double x;
  double y;
  final double w;
  final double h;
}

double _sobreposicao(_Retangulo a, _Retangulo b, double folga) {
  final ix = math.min(a.x + a.w + folga, b.x + b.w + folga) -
      math.max(a.x - folga, b.x - folga);
  final iy = math.min(a.y + a.h + folga, b.y + b.h + folga) -
      math.max(a.y - folga, b.y - folga);
  if (ix <= 0 || iy <= 0) return 0;
  return ix * iy;
}

/// Calcula balões sem sobreposição e presos dentro da imagem.
///
/// [largura] e [altura] são as dimensões reais em que a imagem será desenhada.
List<BalaoVisao> layoutBaloesVisao(
  List<ObjetoVisao> objetos, {
  required double largura,
  required double altura,
  double larguraBalao = 96,
  double alturaBalao = 27,
}) {
  const margem = 4.0;
  const passo = 18.0;
  const direcoes = <List<double>>[
    [0, -1],
    [0, 1],
    [1, 0],
    [-1, 0],
    [0.7, -0.7],
    [-0.7, -0.7],
    [0.7, 0.7],
    [-0.7, 0.7],
  ];

  final l = math.max(120.0, largura);
  final a = math.max(160.0, altura);
  final bw = math.max(56.0, larguraBalao);
  final bh = math.max(20.0, alturaBalao);
  final colocados = <_Retangulo>[];
  final saida = <BalaoVisao>[];

  for (var indice = 0; indice < objetos.length; indice++) {
    final caixa = objetos[indice].caixa;
    if (caixa == null || !caixa.valida) {
      saida.add(BalaoVisao(
        indice: indice,
        x: 0,
        y: 0,
        largura: 0,
        altura: 0,
        semCaixa: true,
      ));
      continue;
    }

    final alvoX = _limitar(caixa.x + caixa.w / 2, 0, 1) * l;
    final alvoY = _limitar(caixa.y + caixa.h / 2, 0, 1) * a;
    _Retangulo? melhor;
    var melhorPeso = double.infinity;
    final passos = (math.sqrt(l * l + a * a) / passo).ceil();

    for (var rodada = 0; rodada <= passos; rodada++) {
      final raio = rodada * passo;
      for (final direcao in direcoes) {
        final cx = alvoX + direcao[0] * (raio + bw / 2);
        final cy = alvoY + direcao[1] * (raio + bh / 2);
        final rect = _Retangulo(cx - bw / 2, cy - bh / 2, bw, bh);
        rect.x = _limitar(rect.x, margem, math.max(margem, l - margem - bw));
        rect.y = _limitar(rect.y, margem, math.max(margem, a - margem - bh));
        var peso = raio;
        if (rect.x < margem ||
            rect.y < margem ||
            rect.x + rect.w > l - margem ||
            rect.y + rect.h > a - margem) {
          peso += 10000;
        }
        for (final colocado in colocados) {
          peso += _sobreposicao(rect, colocado, 4) * 8;
        }
        if (peso < melhorPeso) {
          melhorPeso = peso;
          melhor = rect;
          if (peso == raio && raio == 0 && colocados.isEmpty) break;
        }
      }
      if (melhor != null && melhorPeso <= raio) break;
    }

    final posicao =
        melhor ?? _Retangulo(alvoX - bw / 2, alvoY - bh / 2, bw, bh);
    var colidiu = false;
    for (final colocado in colocados) {
      if (_sobreposicao(posicao, colocado, 3) > 0) {
        colidiu = true;
        break;
      }
    }
    colocados.add(posicao);

    final bordaX = _limitar(alvoX, posicao.x, posicao.x + posicao.w);
    final bordaY = _limitar(alvoY, posicao.y, posicao.y + posicao.h);
    saida.add(BalaoVisao(
      indice: indice,
      x: (posicao.x + posicao.w / 2) / l * 100,
      y: (posicao.y + posicao.h / 2) / a * 100,
      largura: posicao.w,
      altura: posicao.h,
      linha: LinhaGuia(
        x1: bordaX / l * 100,
        y1: bordaY / a * 100,
        x2: alvoX / l * 100,
        y2: alvoY / a * 100,
      ),
      colisao: colidiu,
    ));
  }
  return saida;
}
