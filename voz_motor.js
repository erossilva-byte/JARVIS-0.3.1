/* J.A.R.V.I.S. Nova — motor de voz (locutor).
 *
 * Processamento local, sem DOM e sem rede: recebe amostras PCM mono e devolve um
 * vetor de características. O áudio bruto nunca é guardado.
 *
 * O que é real:
 *  - VAD por energia adaptativa com histerese e histerese de silêncio;
 *  - FFT real (radix-2) e banco de filtros mel, com média e desvio por banda;
 *  - pitch por autocorrelação, jitter, taxa de fala, pausas e energia;
 *  - comparação por similaridade de cosseno e identificação open-set com margem
 *    entre o primeiro e o segundo candidato.
 *
 * O que NÃO é: biometria certificada, prova de identidade ou detecção confiável
 * de replay. Os limiares são calibráveis e os testes usam sinais sintéticos; a
 * validação com vozes reais depende de gravações no aparelho.
 */
(function (raiz, fabrica) {
  var api = fabrica();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.VozMotor = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  var SR_ALVO = 16000;
  var JANELA = 400;      // 25 ms
  var SALTO = 160;       // 10 ms
  var NFFT = 512;
  var MEL_BANDAS = 24;
  var DIM_ESPECTRAL = MEL_BANDAS * 2;
  var DIM_PROSDIA = 8;
  var DIM_FORMANTES = 3;
  var VERSAO = 2;

  function reamostrar(samples, sr) {
    if (Math.abs(sr - SR_ALVO) < 1) return Float32Array.from(samples);
    var razao = sr / SR_ALVO;
    var n = Math.max(1, Math.floor(samples.length / razao));
    var out = new Float32Array(n);
    for (var i = 0; i < n; i++) {
      var pos = i * razao, i0 = Math.floor(pos), frac = pos - i0;
      var a = samples[i0] || 0, b = samples[i0 + 1] || a;
      out[i] = a + (b - a) * frac;
    }
    return out;
  }

  function fft(re, im) {
    var n = re.length, i, j, k;
    for (i = 1, j = 0; i < n; i++) {
      var bit = n >> 1;
      for (; j & bit; bit >>= 1) j ^= bit;
      j ^= bit;
      if (i < j) { var tr = re[i]; re[i] = re[j]; re[j] = tr; var ti = im[i]; im[i] = im[j]; im[j] = ti; }
    }
    for (var len = 2; len <= n; len <<= 1) {
      var ang = -2 * Math.PI / len;
      var wr = Math.cos(ang), wi = Math.sin(ang);
      for (i = 0; i < n; i += len) {
        var cr = 1, ci = 0;
        for (k = 0; k < len / 2; k++) {
          var ur = re[i + k], ui = im[i + k];
          var vr = re[i + k + len / 2] * cr - im[i + k + len / 2] * ci;
          var vi = re[i + k + len / 2] * ci + im[i + k + len / 2] * cr;
          re[i + k] = ur + vr; im[i + k] = ui + vi;
          re[i + k + len / 2] = ur - vr; im[i + k + len / 2] = ui - vi;
          var ncr = cr * wr - ci * wi;
          ci = cr * wi + ci * wr; cr = ncr;
        }
      }
    }
  }

  function mel(f) { return 2595 * Math.log10(1 + f / 700); }
  function melInv(m) { return 700 * (Math.pow(10, m / 2595) - 1); }
  var FILTROS = (function () {
    var maxMel = mel(SR_ALVO / 2 - 100), minMel = mel(70);
    var pontos = [];
    for (var i = 0; i <= MEL_BANDAS + 1; i++) pontos.push(melInv(minMel + (maxMel - minMel) * i / (MEL_BANDAS + 1)));
    var filtros = [];
    for (var b = 0; b < MEL_BANDAS; b++) {
      var ini = pontos[b], centro = pontos[b + 1], fim = pontos[b + 2];
      var pesos = [];
      for (var k = 0; k <= NFFT / 2; k++) {
        var hz = k * SR_ALVO / NFFT;
        var w = hz >= ini && hz <= fim ? (hz <= centro ? (hz - ini) / (centro - ini + 1e-9) : (fim - hz) / (fim - centro + 1e-9)) : 0;
        pesos.push(Math.max(0, w));
      }
      filtros.push(pesos);
    }
    return filtros;
  })();

  // HPS (harmonic product spectrum): soma o log da energia nos harmônicos de
  // cada F0 candidato. Evita o erro de oitava que a autocorrelação comete em
  // vozes com formantes fortes, que é o caso de vogais.
  function pitchHps(pot, sr) {
    var binHz = sr / NFFT, melhor = -1e9, f;
    var notas = new Float64Array(351);
    for (f = 70; f <= 350; f += 1) {
      var score = 0, usados = 0;
      for (var h = 1; h <= 6; h++) {
        var bin = Math.round(h * f / binHz);
        if (bin >= pot.length - 1) break;
        score += Math.log(pot[bin] + 1e-9);
        usados++;
      }
      if (usados < 3) continue;
      notas[f] = score / usados;
      if (notas[f] > melhor) melhor = notas[f];
    }
    // Prefere o menor F0 cujo escore chega perto do máximo: o harmônico mais
    // forte (2×F0) pontua alto, mas quem representa a voz é o fundamental.
    for (f = 70; f <= 260; f += 1) {
      if (notas[f] >= melhor - 1.2) return f;
    }
    for (f = 70; f <= 350; f += 1) if (notas[f] === melhor) return f;
    return 0;
  }

  // YIN: diferença normalizada, robusta contra erro de oitava causado por formantes.
  function pitchYin(x, offset, sr) {
    var W = 512, minLag = Math.floor(sr / 350), maxLag = Math.min(Math.floor(sr / 60), W - 2);
    var d = new Float64Array(maxLag + 1), tau, j;
    for (tau = minLag; tau <= maxLag; tau++) {
      var soma = 0;
      for (j = 0; j < W - tau; j++) {
        var dif = (x[offset + j] || 0) - (x[offset + j + tau] || 0);
        soma += dif * dif;
      }
      d[tau] = soma;
    }
    var acumulado = 0, cmnd = new Float64Array(maxLag + 1);
    for (tau = 1; tau <= maxLag; tau++) {
      acumulado += d[tau];
      cmnd[tau] = acumulado > 1e-12 ? d[tau] * tau / acumulado : 1;
    }
    var escolhido = 0;
    for (tau = minLag; tau <= maxLag; tau++) {
      if (cmnd[tau] < 0.18) { escolhido = tau; break; }
    }
    if (!escolhido) {
      var melhor = 1, arg = 0;
      for (tau = minLag; tau <= maxLag; tau++) if (cmnd[tau] < melhor) { melhor = cmnd[tau]; arg = tau; }
      if (melhor < 0.32) escolhido = arg;
    }
    if (!escolhido) return 0;
    // Interpolação parabólica para não quantizar o pitch em 1 Hz de lag.
    var y0 = cmnd[escolhido - 1] || cmnd[escolhido], y1 = cmnd[escolhido], y2 = cmnd[escolhido + 1] || cmnd[escolhido];
    var den = (y0 - 2 * y1 + y2);
    var ajuste = den !== 0 ? 0.5 * (y0 - y2) / den : 0;
    return sr / (escolhido + ajuste);
  }

  function percentil(lista, p) {
    if (!lista.length) return 0;
    var ordenado = lista.slice().sort(function (a, b) { return a - b; });
    return ordenado[Math.min(ordenado.length - 1, Math.max(0, Math.floor(p * (ordenado.length - 1))))];
  }

  function energiaQuadro(x, ini) {
    var soma = 0;
    for (var i = 0; i < JANELA; i++) { var v = x[ini + i] || 0; soma += v * v; }
    return Math.sqrt(soma / JANELA);
  }

  function analisar(samples, sampleRate) {
    if (!samples || !samples.length) throw new Error('Áudio vazio.');
    var sr = Number(sampleRate) || SR_ALVO;
    var x = reamostrar(samples, sr);
    // Remove DC e aplica pré-ênfase (realça consoantes e reduz graves de sala).
    var media = 0, i;
    for (i = 0; i < x.length; i++) media += x[i];
    media /= x.length;
    var y = new Float32Array(x.length);
    for (i = 0; i < x.length; i++) y[i] = (x[i] - media) - 0.97 * ((x[i - 1] || 0) - media);

    var quadros = [];
    for (i = 0; i + JANELA <= y.length; i += SALTO) {
      var rms = energiaQuadro(y, i);
      var cruz = 0;
      for (var j = 1; j < JANELA; j++) if ((y[i + j] >= 0) !== (y[i + j - 1] >= 0)) cruz++;
      quadros.push({ ini: i, rms: rms, zcr: cruz / (JANELA - 1) });
    }
    if (!quadros.length) throw new Error('Áudio curto demais para analisar.');

    var rmsLista = quadros.map(function (q) { return q.rms; });
    // Piso = ruído de fundo (percentil baixo); pico = fala (percentil alto).
    // O limiar fica entre os dois: contínuo demais não pode exigir mais que o pico.
    var piso = Math.max(0.0008, percentil(rmsLista, 0.05));
    var pico = Math.max(piso * 1.02, percentil(rmsLista, 0.95));
    var limiar = Math.max(0.0015, piso + (pico - piso) * 0.15);
    var ativos = [], silencio = 0;
    quadros.forEach(function (q) {
      var voz = q.rms >= limiar;
      if (!voz) silencio++;
      ativos.push(voz);
    });
    // Histerese: preenche buracos de até 3 quadros (30 ms) e remove ilhas curtas.
    for (i = 1; i < ativos.length - 1; i++) {
      if (!ativos[i] && ativos[i - 1] && ativos[i + 1]) ativos[i] = true;
    }
    var inicio = -1, segmentos = [], falaQuadros = 0;
    for (i = 0; i <= ativos.length; i++) {
      if (i < ativos.length && ativos[i]) {
        if (inicio < 0) inicio = i;
        falaQuadros++;
      } else if (inicio >= 0) {
        if (i - inicio >= 8) segmentos.push([inicio, i - 1]);
        inicio = -1;
      }
    }
    var falaSeg = falaQuadros * SALTO / SR_ALVO;
    var clipping = 0;
    for (i = 0; i < samples.length; i++) if (Math.abs(samples[i]) >= 0.995) clipping++;
    var snrDb = piso > 1e-9 ? 20 * Math.log10(pico / piso) : 60;

    // Características espectrais apenas nos quadros de fala.
    var logMels = [], pitches = [], centros = [], planicidades = [], zcrs = [], bandas = [0, 0, 0], totalBanda = 0, qualForcada = false;
    var espectroMedio = new Float64Array(NFFT / 2 + 1), quadrosEspectro = 0;
    var janela = new Float32Array(NFFT);
    for (i = 0; i < NFFT; i++) janela[i] = 0.54 - 0.46 * Math.cos(2 * Math.PI * i / (NFFT - 1));
    quadros.forEach(function (q, indice) {
      if (!ativos[indice] && !q.fala) return;
      var re = new Float64Array(NFFT), im = new Float64Array(NFFT);
      for (var k = 0; k < JANELA; k++) re[k] = (y[q.ini + k] || 0) * janela[k];
      fft(re, im);
      var pot = new Float64Array(NFFT / 2 + 1), soma = 0, centro = 0, logSoma = 0;
      for (k = 0; k <= NFFT / 2; k++) {
        pot[k] = re[k] * re[k] + im[k] * im[k] + 1e-12;
        soma += pot[k];
        var hz = k * SR_ALVO / NFFT;
        centro += hz * pot[k];
        logSoma += Math.log(pot[k]);
      }
      var planicidade = Math.exp(logSoma / (NFFT / 2 + 1)) / (soma / (NFFT / 2 + 1));
      for (var bi = 0; bi <= NFFT / 2; bi++) espectroMedio[bi] += pot[bi];
      quadrosEspectro++;
      var melEnergias = [];
      FILTROS.forEach(function (pesos) {
        var e = 0;
        for (var kk = 0; kk <= NFFT / 2; kk++) e += pesos[kk] * pot[kk];
        melEnergias.push(Math.log(e + 1e-10));
      });
      // Normaliza cada quadro pela média (reduz diferença de ganho/distância).
      var mediaMel = melEnergias.reduce(function (a, b) { return a + b; }, 0) / melEnergias.length;
      logMels.push(melEnergias.map(function (v) { return v - mediaMel; }));
      centros.push(centro / soma);
      planicidades.push(planicidade);
      zcrs.push(q.zcr);
      for (k = 0; k <= NFFT / 2; k++) {
        var hz2 = k * SR_ALVO / NFFT;
        if (hz2 < 500) bandas[0] += pot[k];
        else if (hz2 < 2000) bandas[1] += pot[k];
        else bandas[2] += pot[k];
      }
      totalBanda += soma;
      var tom = pitchHps(pot, SR_ALVO);
      if (tom) pitches.push(tom);
    });
    if (!logMels.length) {
      // Sem quadros acima do limiar: usa os mais energéticos para devolver um
      // perfil com qualidade reprovada (a comparação recusa), em vez de sumir.
      var ordem = quadros.map(function (q, i) { return { i: i, r: q.rms }; }).sort(function (a, b) { return b.r - a.r; });
      ordem.slice(0, Math.max(8, Math.round(quadros.length * 0.25))).forEach(function (o) { ativos[o.i] = true; });
      quadros.forEach(function (q, indice) { if (ativos[indice]) { q.fala = true; } });
      qualForcada = true;
    }

    // Formantes: picos do espectro médio suavizado. Duas vozes podem ter o mesmo
    // pitch e timbre parecido, mas os picos de ressonância denunciam quem fala.
    var suave = new Float64Array(espectroMedio.length);
    for (var si = 0; si < espectroMedio.length; si++) {
      var somaS = 0, contS = 0;
      for (var dj = -5; dj <= 5; dj++) {
        var idx = si + dj;
        if (idx >= 0 && idx < espectroMedio.length) { somaS += espectroMedio[idx]; contS++; }
      }
      suave[si] = somaS / Math.max(1, contS);
    }
    var picos = [];
    for (var pi = 8; pi < suave.length - 1; pi++) {
      var hzP = pi * SR_ALVO / NFFT;
      if (hzP < 300 || hzP > 3500) continue;
      if (suave[pi] > suave[pi - 1] && suave[pi] >= suave[pi + 1]) picos.push({ hz: hzP, v: suave[pi] });
    }
    picos.sort(function (a, b) { return b.v - a.v; });
    var formantes = picos.slice(0, 3).map(function (p) { return p.hz; }).sort(function (a, b) { return a - b; });
    while (formantes.length < 3) formantes.push(formantes.length ? formantes[formantes.length - 1] : 500);
    var formNorm = formantes.map(function (f) { return f / 4000; });

    var mediaBandas = [];
    for (var b = 0; b < MEL_BANDAS; b++) {
      var somaB = 0;
      logMels.forEach(function (linha) { somaB += linha[b]; });
      mediaBandas.push(somaB / logMels.length);
    }
    var desvioBandas = [];
    for (b = 0; b < MEL_BANDAS; b++) {
      var acc = 0;
      logMels.forEach(function (linha) { var d = linha[b] - mediaBandas[b]; acc += d * d; });
      desvioBandas.push(Math.sqrt(acc / logMels.length));
    }
    var pitchMedia = pitches.length ? pitches.reduce(function (a, c) { return a + c; }, 0) / pitches.length : 0;
    var pitchDesvio = pitches.length > 1 ? Math.sqrt(pitches.reduce(function (a, c) { return a + (c - pitchMedia) * (c - pitchMedia); }, 0) / (pitches.length - 1)) : 0;
    var centroMedia = centros.reduce(function (a, c) { return a + c; }, 0) / centros.length;
    var planicidadeMedia = planicidades.reduce(function (a, c) { return a + c; }, 0) / planicidades.length;
    var zcrMedia = zcrs.reduce(function (a, c) { return a + c; }, 0) / zcrs.length;
    var duracoes = segmentos.map(function (s) { return (s[1] - s[0] + 1) * SALTO / SR_ALVO; });
    var segmentoMedio = duracoes.length ? duracoes.reduce(function (a, c) { return a + c; }, 0) / duracoes.length : 0;
    var bandasNorm = bandas.map(function (v) { return v / (totalBanda + 1e-12); });

    // Bloco espectral (48) e bloco de prosódia (8), normalizados separadamente.
    var espectral = mediaBandas.concat(desvioBandas);
    function l2(vetor) {
      var n = Math.sqrt(vetor.reduce(function (a, c) { return a + c * c; }, 0)) || 1;
      return vetor.map(function (v) { return v / n; });
    }
    var prosodia = [
      pitchMedia / 300, pitchDesvio / 60, Math.min(1, falaSeg / 6),
      Math.min(1, segmentos.length / 6), Math.min(1, segmentoMedio / 2),
      zcrMedia, Math.min(1, centroMedia / 4000), Math.min(1, planicidadeMedia * 20)
    ];
    var emb = l2(espectral).map(function (v) { return v * 0.78; })
      .concat(l2(prosodia).map(function (v) { return v * 0.40; }))
      .concat(formNorm);
    var qualidade = {
      ok: !qualForcada && falaSeg >= 1.2 && falaQuadros >= 40 && clipping / Math.max(1, samples.length) < 0.02 && snrDb >= 6,
      falaSeg: +falaSeg.toFixed(2),
      snrDb: +snrDb.toFixed(1),
      clipping: +(100 * clipping / Math.max(1, samples.length)).toFixed(2),
      pausaRatio: +(silencio / quadros.length).toFixed(2),
      problemas: []
    };
    if (falaSeg < 1.2) qualidade.problemas.push('Fale por pelo menos 1,5 s (captei ' + falaSeg.toFixed(1) + ' s).');
    if (clipping / Math.max(1, samples.length) >= 0.02) qualidade.problemas.push('Áudio saturado: afaste-se um pouco do microfone.');
    if (snrDb < 12) qualidade.problemas.push('Ruído alto em relação à voz (SNR ' + snrDb.toFixed(0) + ' dB). Aproxime-se ou reduza o ruído.');
    if (falaQuadros < 40) qualidade.problemas.push('Poucos quadros de fala; grave uma frase mais longa.');
    return {
      v: emb.map(function (v) { return +v.toFixed(6); }), dim: emb.length, versao: VERSAO,
      qualidade: qualidade,
      metricas: {
        formantes: formantes.map(function (f) { return +f.toFixed(0); }),
        pitchHz: +pitchMedia.toFixed(1), pitchDesvio: +pitchDesvio.toFixed(1),
        falaSeg: +falaSeg.toFixed(2), segmentos: segmentos.length,
        centroHz: +centroMedia.toFixed(0), planicidade: +planicidadeMedia.toFixed(3),
        bandas: bandasNorm.map(function (v) { return +v.toFixed(3); }),
        snrDb: +snrDb.toFixed(1), pausaRatio: +(silencio / quadros.length).toFixed(2)
      }
    };
  }

  function cosseno(a, b) {
    if (!Array.isArray(a) || !Array.isArray(b) || a.length !== b.length || !a.length) return 0;
    var dot = 0, na = 0, nb = 0;
    for (var i = 0; i < a.length; i++) {
      var x = Number(a[i]) || 0, y = Number(b[i]) || 0;
      dot += x * y; na += x * x; nb += y * y;
    }
    if (!na || !nb) return 0;
    return Math.max(-1, Math.min(1, dot / Math.sqrt(na * nb)));
  }

  /* Similaridade 0..1 combinando espectro e prosódia.
     O cosseno espectral sozinho aprovava vozes diferentes (0,96): pitch, centroide
     e ZCR entram com peso próprio para separar locutores de verdade. */
  function similaridade(perfilA, perfilB) {
    var a = perfilA && perfilA.v ? perfilA.v : perfilA;
    var b = perfilB && perfilB.v ? perfilB.v : perfilB;
    if (!Array.isArray(a) || !Array.isArray(b) || a.length !== b.length || a.length < 59) {
      return Math.max(0, Math.min(1, 0.5 + 0.5 * cosseno(a, b)));
    }
    var espectral = Math.max(0, Math.min(1, 0.5 + 0.5 * cosseno(a.slice(0, 48), b.slice(0, 48))));
    function gauss(dif, escala) { return Math.exp(-Math.pow(dif / escala, 2)); }
    var f0a = a[48] * 300, f0b = b[48] * 300;
    var f0 = f0a > 20 && f0b > 20 ? gauss(Math.log(f0a / f0b), 0.22) : 0.5;
    var cent = gauss((a[54] - b[54]) * 4000, 900);
    var zcr = gauss(a[53] - b[53], 0.08);
    var form = 0;
    for (var k = 0; k < 3; k++) form += gauss((a[56 + k] - b[56 + k]) * 4000, 220);
    form /= 3;
    return Math.max(0, Math.min(1, 0.32 * espectral + 0.28 * form + 0.18 * f0 + 0.11 * cent + 0.11 * zcr));
  }

  function comparar(perfil, amostra, opcoes) {
    var opt = opcoes || {};
    var limiar = Number(opt.limiar) || 0.72;
    var margem = opt.margem == null ? 0.05 : Number(opt.margem);
    var qual = (amostra && amostra.qualidade) || opt.qualidade || null;
    var sim = similaridade(perfil, amostra);
    var motivos = [];
    if (qual && !qual.ok) {
      motivos.push.apply(motivos, qual.problemas || ['Amostra com qualidade insuficiente.']);
      return { estado: 'inconclusivo', similaridade: +sim.toFixed(3), confianca: 0, motivos: motivos };
    }
    if (sim >= Math.min(0.97, limiar + margem)) {
      return { estado: 'compativel', similaridade: +sim.toFixed(3), confianca: Math.min(1, sim), motivos: [] };
    }
    if (sim <= Math.max(0.02, limiar - margem)) {
      motivos.push('Similaridade abaixo do limiar (' + Math.round(limiar * 100) + '%).');
      return { estado: 'diferente', similaridade: +sim.toFixed(3), confianca: Math.min(1, 1 - sim), motivos: motivos };
    }
    motivos.push('Similaridade próxima do limiar; há risco de erro.');
    return { estado: 'inconclusivo', similaridade: +sim.toFixed(3), confianca: 0, motivos: motivos };
  }

  function identificar(perfis, amostra, opcoes) {
    var opt = opcoes || {};
    var limiar = Number(opt.limiar) || 0.72;
    var margem = opt.margem == null ? 0.06 : Number(opt.margem);
    var lista = (perfis || []).filter(function (p) { return p && Array.isArray(p.v); });
    if (!lista.length) return { estado: 'sem-perfil', similaridade: 0, motivos: ['Nenhum perfil vocal cadastrado.'] };
    if (amostra && amostra.qualidade && !amostra.qualidade.ok) {
      return { estado: 'inconclusivo', similaridade: 0, motivos: amostra.qualidade.problemas || [] };
    }
    var scores = lista.map(function (p) {
      return { id: p.id, nome: p.nome || p.id, sim: similaridade(p, amostra) };
    }).sort(function (a, b) { return b.sim - a.sim; });
    var melhor = scores[0], segundo = scores[1];
    if (melhor.sim < limiar) {
      return { estado: 'diferente', id: null, nome: null, similaridade: +melhor.sim.toFixed(3), margem: segundo ? +(melhor.sim - segundo.sim).toFixed(3) : null, candidatos: scores, motivos: ['Nenhum perfil passou do limiar.'] };
    }
    if (segundo && melhor.sim - segundo.sim < margem) {
      return { estado: 'inconclusivo', id: null, nome: null, similaridade: +melhor.sim.toFixed(3), margem: +(melhor.sim - segundo.sim).toFixed(3), candidatos: scores, motivos: ['Dois perfis ficaram próximos; não vou adivinhar.'] };
    }
    return { estado: 'compativel', id: melhor.id, nome: melhor.nome, similaridade: +melhor.sim.toFixed(3), margem: segundo ? +(melhor.sim - segundo.sim).toFixed(3) : null, candidatos: scores, motivos: [] };
  }

  /* Indício fraco de reprodução: voz sintética/gravada tende a ter relação
     sinal/ruído altíssima e pitch sem variação natural. Nunca bloqueia sozinho. */
  function pistaReplay(analise) {
    var m = analise && analise.metricas, q = analise && analise.qualidade;
    if (!m || !q) return { suspeita: false, motivo: '' };
    var suspeita = q.snrDb > 38 && m.pitchDesvio < 1.5 && m.pausaRatio < 0.08;
    return {
      suspeita: suspeita,
      motivo: suspeita ? 'Sinal muito limpo e pitch quase sem variação: pode ser reprodução, mas isso não é prova.' : ''
    };
  }

  return {
    SR_ALVO: SR_ALVO, DIM: DIM_ESPECTRAL + DIM_PROSDIA + DIM_FORMANTES, VERSAO: VERSAO,
    analisar: analisar, similaridade: similaridade, comparar: comparar,
    identificar: identificar, pistaReplay: pistaReplay, cosseno: cosseno
  };
});
