/* J.A.R.V.I.S. Nova — Visão 2.0: balões sem sobreposição, quadros de vídeo e texto.
 *
 * Este arquivo é o núcleo puro da visão: não toca no DOM, não fala, não chama rede.
 * Tudo aqui roda também em Node (tests/test_visao_nova.js), o que permite provar o
 * posicionamento dos balões sem abrir o aplicativo.
 *
 * Regras do posicionamento:
 *  - cada balão tem um identificador estável (o índice do objeto na análise);
 *  - o balão nunca sai da imagem e nunca cobre outro balão;
 *  - quando o objeto está fora do quadro, o balão é preso na borda e a linha-guia
 *    continua apontando para o centro real;
 *  - se não houver espaço livre (imagem minúscula com muitos objetos), o balão
 *    escolhe a posição de menor sobreposição e vem marcado com `colisao: true`,
 *    para a interface agrupar em vez de esconder informação.
 */
(function (raiz, fabrica) {
  var api = fabrica();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.VisaoNova = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  var LARGURA_PADRAO = 320;
  var ALTURA_PADRAO = 420;
  var BALAO_L = 96;
  var BALAO_A = 27;
  var MARGEM = 4;
  var PASSO = 18;

  function numero(v, padrao) {
    var n = Number(v);
    return Number.isFinite(n) ? n : padrao;
  }

  function limitar(v, min, max) {
    return Math.min(max, Math.max(min, v));
  }

  /** Caixa normalizada (0..1) do modelo -> retângulo em pixels, preso à imagem. */
  function retanguloDaIma(caixa, largura, altura) {
    var c = caixa || {};
    var x = limitar(numero(c.x, 0.5), 0, 1);
    var y = limitar(numero(c.y, 0.5), 0, 1);
    var w = limitar(numero(c.w, 0), 0, 1);
    var h = limitar(numero(c.h, 0), 0, 1);
    var cx = limitar(x + w / 2, 0, 1) * largura;
    var cy = limitar(y + h / 2, 0, 1) * altura;
    return { cx: cx, cy: cy, x: x * largura, y: y * altura, w: w * largura, h: h * altura };
  }

  function sobreposicao(a, b, folga) {
    var f = numero(folga, 3);
    var ix = Math.min(a.x + a.w + f, b.x + b.w + f) - Math.max(a.x - f, b.x - f);
    var iy = Math.min(a.y + a.h + f, b.y + b.h + f) - Math.max(a.y - f, b.y - f);
    if (ix <= 0 || iy <= 0) return 0;
    return ix * iy;
  }

  function cabe(rect, largura, altura) {
    return rect.x >= MARGEM && rect.y >= MARGEM &&
      rect.x + rect.w <= largura - MARGEM && rect.y + rect.h <= altura - MARGEM;
  }

  function centrar(cx, cy, w, h) {
    return { x: cx - w / 2, y: cy - h / 2, w: w, h: h };
  }

  /** Ordem dos candidatos: em cima, embaixo, à direita, à esquerda, depois diagonais. */
  var DIRECOES = [
    [0, -1], [0, 1], [1, 0], [-1, 0],
    [0.7, -0.7], [-0.7, -0.7], [0.7, 0.7], [-0.7, 0.7]
  ];

  /**
   * Calcula a posição de cada balão.
   * @param {Array} objetos lista com {nome, caixa:{x,y,w,h}} (caixa opcional)
   * @param {Object} opcoes {largura, altura, balaoL, balaoA, maxPorGrupo}
   * @returns {Array} {indice, x, y, largura, altura, linha:{x1,y1,x2,y2}, colisao, semCaixa}
   */
  function layoutBaloes(objetos, opcoes) {
    var o = opcoes || {};
    var largura = Math.max(120, numero(o.largura, LARGURA_PADRAO));
    var altura = Math.max(160, numero(o.altura, ALTURA_PADRAO));
    var bw = Math.max(56, numero(o.balaoL, BALAO_L));
    var bh = Math.max(20, numero(o.balaoA, BALAO_A));
    var lista = Array.isArray(objetos) ? objetos : [];
    var colocados = [];
    var saida = [];

    lista.forEach(function (obj, indice) {
      var caixa = obj && obj.caixa;
      if (!caixa || !(numero(caixa.w, 0) > 0 || numero(caixa.h, 0) > 0)) {
        saida.push({
          indice: indice, x: 0, y: 0, largura: 0, altura: 0,
          linha: null, colisao: false, semCaixa: true
        });
        return;
      }
      var alvo = retanguloDaIma(caixa, largura, altura);
      var melhor = null;
      var melhorPeso = Infinity;
      var passos = Math.ceil(Math.hypot(largura, altura) / PASSO);
      for (var passo = 0; passo <= passos; passo++) {
        var raio = passo * PASSO;
        for (var d = 0; d < DIRECOES.length; d++) {
          var dir = DIRECOES[d];
          var cx = alvo.cx + dir[0] * (raio + bw / 2);
          var cy = alvo.cy + dir[1] * (raio + bh / 2);
          var rect = centrar(cx, cy, bw, bh);
          // Prende dentro da imagem: balão cortado esconde texto.
          rect.x = limitar(rect.x, MARGEM, Math.max(MARGEM, largura - MARGEM - bw));
          rect.y = limitar(rect.y, MARGEM, Math.max(MARGEM, altura - MARGEM - bh));
          var peso = raio;
          if (!cabe(rect, largura, altura)) peso += 10000;
          for (var i = 0; i < colocados.length; i++) {
            peso += sobreposicao(rect, colocados[i], 4) * 8;
          }
          if (peso < melhorPeso) {
            melhorPeso = peso;
            melhor = rect;
            if (peso === raio && raio === 0 && colocados.length === 0) break;
          }
        }
        if (melhor && melhorPeso <= raio) break; // achou posição livre nesta volta
      }
      if (!melhor) melhor = centrar(alvo.cx, alvo.cy, bw, bh);
      var colidiu = false;
      for (var k = 0; k < colocados.length; k++) {
        if (sobreposicao(melhor, colocados[k], 3) > 0) { colidiu = true; break; }
      }
      colocados.push(melhor);
      var bordaX = limitar(alvo.cx, melhor.x, melhor.x + melhor.w);
      var bordaY = limitar(alvo.cy, melhor.y, melhor.y + melhor.h);
      saida.push({
        indice: indice,
        x: (melhor.x + melhor.w / 2) / largura * 100,
        y: (melhor.y + melhor.h / 2) / altura * 100,
        largura: melhor.w, altura: melhor.h,
        linha: {
          x1: bordaX / largura * 100, y1: bordaY / altura * 100,
          x2: alvo.cx / largura * 100, y2: alvo.cy / altura * 100
        },
        colisao: colidiu,
        semCaixa: false
      });
    });
    return saida;
  }

  /** Vídeos: timestamps distribuídos, sem carregar o arquivo inteiro na memória. */
  function planoQuadros(duracaoSegundos, maxQuadros) {
    var dur = numero(duracaoSegundos, 0);
    var max = Math.round(limitar(numero(maxQuadros, 6), 1, 12));
    // Abaixo de 1 s não há quadro representativo: o arredondamento de 0,1 s
    // repetiria o mesmo instante várias vezes (teste test_visao_nova cobre isso).
    if (!(dur > 1)) return [];
    var passo = dur / (max + 1);
    var lista = [];
    var vistos = {};
    for (var i = 1; i <= max; i++) {
      var t = Math.round(passo * i * 100) / 100;
      if (t <= 0 || t >= dur - 0.05 || vistos[t]) continue;
      vistos[t] = true;
      lista.push(t);
    }
    return lista;
  }

  function timestamp(t) {
    var s = Math.max(0, Math.floor(numero(t, 0)));
    var m = Math.floor(s / 60);
    var r = s % 60;
    return m + ':' + (r < 10 ? '0' : '') + r;
  }

  /** Junta as observações de cada quadro em um texto único, sem inventar ligação. */
  function relatoVideo(quadros) {
    var lista = Array.isArray(quadros) ? quadros : [];
    if (!lista.length) return 'Nenhum quadro foi analisado.';
    var linhas = lista.map(function (q) {
      var base = '[' + timestamp(q.t) + '] ' + (q.resumo || '').trim();
      var objs = Array.isArray(q.objetos) ? q.objetos.map(function (x) { return x && x.nome; }).filter(Boolean) : [];
      if (objs.length) base += (base ? ' ' : '') + 'Objetos: ' + objs.join(', ') + '.';
      return base.trim();
    });
    return linhas.join('\n');
  }

  function textoAnalise(resumo, objeto) {
    var partes = [];
    var r = String(resumo == null ? '' : resumo).trim();
    if (r) partes.push(r);
    if (objeto) {
      var nome = String(objeto.nome || '').trim();
      var info = String(objeto.info || '').trim();
      if (nome) partes.push(nome + (info ? ': ' + info : ''));
    }
    return partes.join('\n\n');
  }

  return {
    layoutBaloes: layoutBaloes,
    planoQuadros: planoQuadros,
    timestamp: timestamp,
    relatoVideo: relatoVideo,
    textoAnalise: textoAnalise,
    retanguloDaIma: retanguloDaIma
  };
});
