/* J.A.R.V.I.S. Nova — captura de fala com pré-roll e fim de fala.
 *
 * Módulo puro (sem DOM, sem microfone): recebe blocos PCM mono e decide quando a
 * fala começou e quando terminou. Nasceu da comparação com os projetos Android de
 * referência (AnaaySampat/jarvis): gravar quatro segundos fixos perde o começo da
 * frase, captura silêncio e atrasa a resposta. Aqui:
 *
 *  - anel de pré-roll guarda os últimos 600 ms, então a primeira sílaba entra;
 *  - piso de ruído adaptativo (só sobe/desce fora da fala) evita disparar com ar-condicionado;
 *  - confirmação por 160 ms de energia evita blip de porta virar comando;
 *  - fim por 1,2 s de silêncio depois de pelo menos 1,2 s de fala;
 *  - teto rígido de duração, para nunca gravar indefinidamente.
 *
 * O módulo não guarda áudio em lugar nenhum: devolve as amostras para quem chamou.
 */
(function (raiz, fabrica) {
  var api = fabrica();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.EscutaJarvis = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  var PADRAO = {
    preRollMs: 600,
    minFalaMs: 1200,
    silencioMs: 1200,
    semFalaMs: 5000,
    maxMs: 15000,
    minRms: 0.004,
    ratio: 2.2,
    confirmacaoMs: 160
  };

  function criar(opcoes) {
    var o = Object.assign({}, PADRAO, opcoes || {});
    var sr = 0, preRoll = [], preRollAmostras = 0, total = 0;
    var saida = [], saidaAmostras = 0;
    var piso = 0, pisoAmostras = 0;
    var falaMs = 0, ultimaFalaMs = 0, silencioRunMs = 0, falaRunMs = 0;
    var inicioMs = 0, quadroMs = 0, pico = 0;
    var estado = 'aguardando', motivo = '';
    var iniciada = false;

    function resetar() {
      sr = 0; preRoll = []; preRollAmostras = 0; total = 0;
      saida = []; saidaAmostras = 0; piso = 0; pisoAmostras = 0;
      falaMs = 0; ultimaFalaMs = 0; silencioRunMs = 0; falaRunMs = 0;
      inicioMs = 0; quadroMs = 0; pico = 0;
      estado = 'aguardando'; motivo = ''; iniciada = false;
    }

    function rmsDe(chunk) {
      var soma = 0;
      for (var i = 0; i < chunk.length; i++) { var v = Number(chunk[i]) || 0; soma += v * v; }
      return Math.sqrt(soma / Math.max(1, chunk.length));
    }
    function guardarPreRoll(chunk) {
      preRoll.push(Float32Array.from(chunk));
      preRollAmostras += chunk.length;
      var limite = Math.round(sr * o.preRollMs / 1000);
      while (preRollAmostras > limite && preRoll.length > 1) {
        preRollAmostras -= preRoll[0].length;
        preRoll.shift();
      }
    }
    function anexar(chunk) {
      saida.push(Float32Array.from(chunk));
      saidaAmostras += chunk.length;
    }
    function juncao(lista, n) {
      var out = new Float32Array(n), off = 0;
      lista.forEach(function (a) { out.set(a, off); off += a.length; });
      return out;
    }
    function finalizar(motivoFinal) {
      estado = 'fim'; motivo = motivoFinal;
      return resultado();
    }
    function resultado() {
      return {
        estado: estado, motivo: motivo, sampleRate: sr,
        amostras: juncao(saida, saidaAmostras),
        falaMs: Math.round(falaMs), totalMs: Math.round(total * 1000 / Math.max(1, sr)),
        pico: +pico.toFixed(4), piso: +piso.toFixed(4),
        inicioMs: Math.round(inicioMs * 1000 / Math.max(1, sr))
      };
    }

    function processar(chunk, sampleRate) {
      if (estado === 'fim') return resultado();
      var x = chunk instanceof Float32Array ? chunk : Float32Array.from(chunk || []);
      if (!x.length) return resultado();
      if (!sr) {
        sr = Number(sampleRate) || 16000;
        quadroMs = 1000 * x.length / sr;
        resetar();
        sr = Number(sampleRate) || 16000;
        quadroMs = 1000 * x.length / sr;
      }
      total += x.length;
      var rms = rmsDe(x);
      pico = Math.max(pico, rms);

      // Piso inicial: menor energia dos primeiros 400 ms. A média seria
      // contaminada quando a pessoa começa a falar imediatamente — e aí o
      // limiar subiria junto com a voz, escondendo a própria fala.
      if (pisoAmostras < sr * 0.4) {
        piso = piso > 0 ? Math.min(piso, rms) : rms;
        pisoAmostras += x.length;
      }
      var limiar = Math.max(o.minRms, piso * o.ratio);

      if (estado === 'aguardando') {
        guardarPreRoll(x);
        falaRunMs = rms >= limiar ? falaRunMs + quadroMs : 0;
        // O piso só aprende enquanto não há fala confirmada; um blip não o move.
        if (!falaRunMs && pisoAmostras >= sr * 0.4) {
          piso = 0.97 * piso + 0.03 * Math.min(rms, piso * 3 + 0.002);
        }
        if (falaRunMs >= o.confirmacaoMs) {
          iniciada = true;
          estado = 'fala';
          inicioMs = Math.max(0, total - preRollAmostras);
          anexar(juncao(preRoll, preRollAmostras));
          falaMs = preRollAmostras * 1000 / sr;
          ultimaFalaMs = falaMs;
          silencioRunMs = 0;
        }
        if (!iniciada && total * 1000 / sr >= o.semFalaMs) return finalizar('sem-fala');
        return resultado();
      }

      // Em fala: anexa e mede o silêncio final.
      anexar(x);
      if (rms >= limiar) {
        falaMs += quadroMs;
        ultimaFalaMs = falaMs;
        silencioRunMs = 0;
      } else {
        silencioRunMs += quadroMs;
      }
      if (total * 1000 / sr >= o.maxMs) return finalizar('maximo');
      if (falaMs >= o.minFalaMs && silencioRunMs >= o.silencioMs) return finalizar('silencio');
      return resultado();
    }

    return {
      processar: processar,
      resultado: resultado,
      estado: function () { return estado; },
      reiniciar: resetar,
      opcoes: o
    };
  }


  /* Detector de fluxo por RMS, para o caminho em que o MediaRecorder/AudioContext
   * entrega apenas o nível (não as amostras). É puro e testável: o app chama
   * processar(rms, agora) a cada ~50 ms. O piso é aprendido fora da fala, então
   * ventilador/música não elevam o limiar junto com a voz; a confirmação evita
   * que um estalo feche a escuta, e o teto impede microfone aberto para sempre. */
  var DETECTOR_PADRAO = {
    calibracaoMs: 400,
    minRms: 0.006,
    ratio: 2.2,
    sensibilidade: 1,
    confirmacaoMs: 180,
    minFalaMs: 200,
    silencioMs: 1000,
    semFalaMs: 5000,
    maxMs: 15000
  };

  function criarDetectorRms(opcoes) {
    var o = Object.assign({}, DETECTOR_PADRAO, opcoes || {});
    var inicio = null, ultimo = null, calibrando = true, calN = 0, piso = 0;
    var falaRunMs = 0, falaMs = 0, silencioRunMs = 0;
    var ouviu = false, fim = false, motivo = '';
    var sens = Math.max(0.5, Math.min(2.5, Number(o.sensibilidade) || 1));

    function status() {
      var limiar = Math.max(o.minRms, piso * o.ratio) / sens;
      return {
        ouviu: ouviu, fim: fim, motivo: motivo,
        piso: +piso.toFixed(6), limiar: +limiar.toFixed(6),
        falaMs: Math.round(falaMs), silencioMs: Math.round(silencioRunMs),
        ruidoDb: piso > 1e-8 ? +(20 * Math.log10(piso)).toFixed(1) : null
      };
    }
    function encerrar(m) { fim = true; motivo = m; return status(); }
    function reiniciar() {
      inicio = null; ultimo = null; calibrando = true; calN = 0; piso = 0;
      falaRunMs = 0; falaMs = 0; silencioRunMs = 0; ouviu = false; fim = false; motivo = '';
    }

    function processar(rms, agora) {
      if (fim) return status();
      rms = Math.max(0, Number(rms) || 0);
      var nAgora = Number(agora);
      agora = isFinite(nAgora) ? nAgora : Date.now();
      if (inicio === null) { inicio = agora; ultimo = agora; }
      var dt = Math.max(0, Math.min(250, agora - ultimo));
      ultimo = agora;

      // Piso inicial: menor energia observada na calibração. O mínimo (não a média)
      // evita que a primeira sílaba, dita imediatamente, vire o próprio ruído.
      if (calibrando) {
        calN++;
        piso = piso > 0 ? Math.min(piso, rms) : rms;
        if (agora - inicio >= o.calibracaoMs || calN >= 12) {
          calibrando = false;
          piso = Math.max(o.minRms * 0.5, piso);
        }
        return status();
      }

      var limiar = Math.max(o.minRms, piso * o.ratio) / sens;
      // O piso só aprende fora da fala confirmada. Um blip não o desloca.
      if (!ouviu && rms < limiar) {
        piso = 0.98 * piso + 0.02 * Math.min(rms, Math.max(0.001, piso * 3));
      }

      if (!ouviu) {
        if (rms >= limiar) falaRunMs += dt; else falaRunMs = 0;
        if (falaRunMs >= o.confirmacaoMs) {
          ouviu = true;
          falaMs = Math.max(falaRunMs, o.confirmacaoMs);
          silencioRunMs = 0;
        } else if (agora - inicio >= o.semFalaMs) {
          return encerrar('sem-fala');
        }
        return status();
      }

      if (rms >= limiar) {
        falaMs += dt;
        silencioRunMs = 0;
      } else {
        silencioRunMs += dt;
      }
      if (agora - inicio >= o.maxMs) return encerrar('maximo');
      if (falaMs >= o.minFalaMs && silencioRunMs >= o.silencioMs) return encerrar('silencio');
      return status();
    }

    return { processar: processar, status: status, reiniciar: reiniciar, opcoes: o };
  }

  return { PADRAO: PADRAO, DETECTOR_PADRAO: DETECTOR_PADRAO, criar: criar, criarDetectorRms: criarDetectorRms, rms: rmsDeParaTeste };
  function rmsDeParaTeste(chunk) {
    var soma = 0;
    for (var i = 0; i < chunk.length; i++) { var v = Number(chunk[i]) || 0; soma += v * v; }
    return Math.sqrt(soma / Math.max(1, chunk.length));
  }
});
