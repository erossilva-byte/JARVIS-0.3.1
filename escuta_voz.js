/* J.A.R.V.I.S. Nova — escuta_voz: nível, atividade de voz e barge-in (Fase 4).
 *
 * (escuta.js, que já existia, cuida da captura com pré-roll e do detector de fluxo; este
 * módulo é outro: mede nível em dBFS e decide barge-in.)
 *
 * A Fase 4 pede "interromper a fala do Jarvis quando o usuário começar a falar (barge-in),
 * com cancelamento de eco" e "detecção de atividade de voz". O app cancelava a fala só por
 * botão: nada olhava o microfone enquanto ele falava.
 *
 * Este módulo é puro (sem DOM, sem rede, sem áudio do sistema): recebe blocos de amostras
 * float e devolve nível em dBFS, piso de ruído adaptativo e os eventos de início e fim de
 * fala. Assim o detector pode ser medido com sinais sintéticos, sem microfone.
 *
 * Decisões:
 *  - limiar = piso de ruído + margem; a margem cai conforme a sensibilidade sobe (15 → 6 dB);
 *  - o piso acompanha o ambiente devagar (3% por bloco) e só enquanto não há fala;
 *  - cauda (hangover) evita cortar a fala nas pausas naturais entre palavras;
 *  - barge-in exige fala contínua por um mínimo (padrão 300 ms), para tosse ou estalo não
 *    derrubarem a resposta.
 */
(function (raiz) {
  'use strict';

  var DB_MIN = -100;

  function limitar(v, min, max) {
    var n = Number(v);
    if (!isFinite(n)) return min;
    return Math.max(min, Math.min(max, n));
  }

  /** Nível RMS em dBFS e pico absoluto de um bloco de amostras. */
  function nivel(amostras) {
    if (!amostras || !amostras.length) return { db: DB_MIN, pico: 0 };
    var soma = 0, pico = 0;
    for (var i = 0; i < amostras.length; i++) {
      var v = amostras[i];
      soma += v * v;
      var a = Math.abs(v);
      if (a > pico) pico = a;
    }
    var rms = Math.sqrt(soma / amostras.length);
    var db = 20 * Math.log10(rms > 0 ? rms : 1e-10);
    if (db < DB_MIN) db = DB_MIN;
    if (db > 0) db = 0;
    return { db: Math.round(db * 10) / 10, pico: Math.round(pico * 1000) / 1000 };
  }

  /** Classificação honesta do que o microfone está entregando. */
  function classificar(db, pico) {
    if (Number(pico) >= 0.99) return 'saturado';
    if (!isFinite(db) || db <= -70) return 'mudo';
    if (db <= -45) return 'baixo';
    if (db <= -3) return 'bom';
    return 'saturado';
  }

  /**
   * Detector com memória: alimente com blocos de amostras; receba eventos.
   * Devolve { db, pico, limiar, ruidoDb, fala, estado, desdeFalaMs, inicio, fim, classe }.
   */
  function criarDetector(opcoes) {
    var o = opcoes || {};
    var sensibilidade = limitar(o.sensibilidade, 0, 1);
    var margemDb = 15 - 9 * sensibilidade;
    var falaMinMs = Math.max(40, Number(o.falaMinMs) || 120);
    var hangoverMs = Math.max(120, Number(o.hangoverMs) || 500);
    var pisoDb = isFinite(o.ruidoInicialDb) ? Number(o.ruidoInicialDb) : -60;

    var estadoAtual = 'silencio';
    var acimaMs = 0;
    var abaixoMs = 0;
    var desdeFalaMs = 0;

    function processar(amostras, taxa) {
      var taxaSegura = Number(taxa) > 0 ? Number(taxa) : 48000;
      var total = (amostras && amostras.length) ? amostras.length : 0;
      var duracaoMs = total ? (total / taxaSegura) * 1000 : 0;
      var n = nivel(amostras);
      var limiarDb = Math.max(pisoDb + margemDb, -72);
      var acimaDoLimiar = n.db > limiarDb;
      var anterior = estadoAtual;

      if (estadoAtual === 'silencio') {
        // O piso só aprende o ambiente quando ninguém está falando.
        if (!acimaDoLimiar) pisoDb = pisoDb * 0.97 + n.db * 0.03;
        acimaMs = acimaDoLimiar ? acimaMs + duracaoMs : 0;
        if (acimaMs >= falaMinMs) {
          estadoAtual = 'fala';
          // A fala começou quando a energia subiu, não agora: o tempo já decorrido conta.
          desdeFalaMs = acimaMs;
          abaixoMs = 0;
        }
      } else {
        if (acimaDoLimiar) {
          abaixoMs = 0;
          desdeFalaMs += duracaoMs;
        } else {
          abaixoMs += duracaoMs;
        }
        if (abaixoMs >= hangoverMs) {
          estadoAtual = 'silencio';
          acimaMs = 0;
          desdeFalaMs = 0;
        }
      }

      return {
        db: n.db,
        pico: n.pico,
        limiar: Math.round(limiarDb * 10) / 10,
        ruidoDb: Math.round(pisoDb * 10) / 10,
        fala: estadoAtual === 'fala',
        estado: estadoAtual,
        desdeFalaMs: Math.round(desdeFalaMs),
        inicio: anterior === 'silencio' && estadoAtual === 'fala',
        fim: anterior === 'fala' && estadoAtual === 'silencio',
        classe: classificar(n.db, n.pico)
      };
    }

    function estado() {
      return {
        estado: estadoAtual,
        desdeFalaMs: Math.round(desdeFalaMs),
        ruidoDb: Math.round(pisoDb * 10) / 10,
        sensibilidade: sensibilidade,
        margemDb: Math.round(margemDb * 10) / 10,
        falaMinMs: falaMinMs,
        hangoverMs: hangoverMs
      };
    }

    return { processar: processar, estado: estado };
  }

  /** Barge-in: só interrompe com fala sustentada, nunca com um estalo. */
  function deveInterromper(estado, desdeFalaMs, minimoMs) {
    var minimo = Number(minimoMs) > 0 ? Number(minimoMs) : 300;
    return estado === 'fala' && Number(desdeFalaMs) >= minimo;
  }

  /** Resumo de uma sessão de medição: quanto tempo de fala, ruído, pico e classe dominante. */
  function resumir(leituras) {
    var lista = Array.isArray(leituras) ? leituras : [];
    var duracaoMs = 0, falaMs = 0, menorDb = null, maiorPico = 0;
    var contagem = {};
    lista.forEach(function (x) {
      if (!x) return;
      var ms = Number(x.ms) || 0;
      duracaoMs += ms;
      if (x.fala) falaMs += ms;
      if (isFinite(x.db) && (menorDb === null || x.db < menorDb)) menorDb = x.db;
      if (isFinite(x.pico) && x.pico > maiorPico) maiorPico = x.pico;
      if (x.classe) contagem[x.classe] = (contagem[x.classe] || 0) + 1;
    });
    var dominante = 'mudo', melhor = -1;
    Object.keys(contagem).forEach(function (k) {
      if (contagem[k] > melhor) { melhor = contagem[k]; dominante = k; }
    });
    return {
      duracaoMs: Math.round(duracaoMs),
      falaMs: Math.round(falaMs),
      silencioMs: Math.round(duracaoMs - falaMs),
      ruidoDb: menorDb === null ? DB_MIN : Math.round(menorDb * 10) / 10,
      pico: Math.round(maiorPico * 1000) / 1000,
      classificacao: dominante,
      saturado: maiorPico >= 0.99
    };
  }

  var api = {
    DB_MIN: DB_MIN,
    nivel: nivel,
    classificar: classificar,
    criarDetector: criarDetector,
    deveInterromper: deveInterromper,
    resumir: resumir
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (raiz) raiz.EscutaVoz = api;
})(typeof window !== 'undefined' ? window : null);
