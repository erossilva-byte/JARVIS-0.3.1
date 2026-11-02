/* J.A.R.V.I.S. Nova — camada de transcrição (1.42.0).
 *
 * Este módulo não reconhece áudio. Ele recebe o texto que o motor de STT já produziu
 * e faz apenas o que pode ser justificado: limpeza conservadora, pontuação, grafia de
 * termos técnicos, leitura das hipóteses alternativas e uma decisão de confiança.
 *
 * Regras deliberadas:
 *  - nunca inventa palavras, nunca troca um comando por outro e nunca "corrige" o
 *    sentido de uma frase;
 *  - só altera grafia de termos de uma lista fechada;
 *  - se o motor não informar confiança, o campo fica null — não inventamos 100%;
 *  - baixa confiança em frase com verbo de ação pede repetição em vez de executar.
 *
 * Roda em Node e no WebView; não toca no DOM, na rede ou no microfone.
 */
(function (raiz, fabrica) {
  var api = fabrica();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.FalaJarvis = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  var VERSAO = '1.1.0';
  var LIMIAR_BAIXO = 0.45;
  var LIMIAR_MEDIO = 0.68;

  // Só grafia. Nenhuma entrada altera o sentido de um verbo ou de um argumento.
  var TERMOS = [
    [/\bj\s*\.?\s*a\s*\.?\s*r\s*\.?\s*v\s*\.?\s*i\s*\.?\s*s\b/gi, 'Jarvis'],
    [/\bjarvis\b/gi, 'Jarvis'],
    [/\bwi[\s-]?fi\b/gi, 'Wi-Fi'],
    [/\bbluetooth\b/gi, 'Bluetooth'],
    [/\bwhats\s*app\b/gi, 'WhatsApp'],
    [/\byou\s*tube\b/gi, 'YouTube'],
    [/\bspotify\b/gi, 'Spotify'],
    [/\bobsidian\b/gi, 'Obsidian'],
    [/\bchat\s*gpt\b/gi, 'ChatGPT'],
    [/\bgroq\b/gi, 'Groq'],
    [/\bcerebras\b/gi, 'Cerebras'],
    [/\bgemini\b/gi, 'Gemini'],
    [/\bmistral\b/gi, 'Mistral']
  ];

  var VERBOS_ACAO = /^(?:abre|abrir|abra|fecha|fechar|feche|liga|ligar|ligue|chama|chamar|chame|manda|mandar|mande|envia|enviar|envie|toca|tocar|toque|coloca|colocar|coloque|define|definir|defina|aumenta|aumentar|aumente|diminui|diminuir|diminua|para|parar|pare|desliga|desligar|desligue|agenda|agendar|agende|alarme|lembra|lembrar|lembre|cria|criar|crie|apaga|apagar|apague|pesquisa|pesquisar|pesquise|calcula|calcular|calcule|traduz|traduzir|traduza|responde|responder|responda)\b/;

  function textoLimpo(v) {
    return String(v == null ? '' : v)
      .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }
  function semAcento(v) {
    return textoLimpo(v).normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
  }
  function capitalizar(v) {
    var s = textoLimpo(v);
    return s ? s.charAt(0).toUpperCase() + s.slice(1) : s;
  }

  /** Limpeza que não muda o conteúdo: só muletas isoladas nas pontas. */
  function limpar(texto) {
    var s = textoLimpo(texto);
    if (!s) return '';
    // Não colapsamos palavras repetidas: "não não" e "muito muito" podem ser
    // ênfase legítima. Repetição de STT fica visível em vez de virar outra frase.
    // Muletas no começo/fim, somente quando são um token separado.
    s = s.replace(/^(?:ahn?|ah|eh|hum+|hã+|hmm+)\s+/i, '');
    s = s.replace(/\s+(?:ahn?|ah|eh|hum+|hã+|hmm+)$/i, '');
    return s.replace(/\s+/g, ' ').trim();
  }

  /** Pontuação conservadora: não reescreve a frase, só fecha e capitaliza. */
  function pontuar(texto) {
    var s = limpar(texto);
    if (!s) return '';
    s = capitalizar(s);
    if (/[.!?…]$/.test(s)) return s;
    var n = semAcento(s);
    var pergunta = /^(?:quem|qual|quais|quando|onde|como|por que|porque|quanto|quantos|quantas|que horas|que dia|voce|você|pode|poderia|tem|ha|há)\b/.test(n);
    if (/[,;:]$/.test(s)) s = s.slice(0, -1);
    return s + (pergunta ? '?' : '.');
  }

  /** Aplica apenas o dicionário fechado de grafia. */
  function termos(texto) {
    var s = textoLimpo(texto);
    TERMOS.forEach(function (par) { s = s.replace(par[0], par[1]); });
    return s;
  }

  function comando(texto) {
    var n = semAcento(texto).replace(/^jarvis[\s,;:.-]*/, '').trim();
    return VERBOS_ACAO.test(n);
  }

  function numero(v) {
    var n = Number(v);
    // Muitos motores (inclusive o SpeechRecognizer do Android em certos aparelhos)
    // devolvem 0 quando não têm uma pontuação real. Zero, aqui, é ausência de
    // confiança — não uma confiança baixíssima que bloquearia todo comando.
    return isFinite(n) && n > 0 ? Math.max(0, Math.min(1, n)) : null;
  }

  function normalizarAlternativas(lista) {
    if (!Array.isArray(lista)) return [];
    var vistos = Object.create(null);
    return lista.slice(0, 5).map(function (a) {
      if (typeof a === 'string') return { texto: textoLimpo(a), confianca: null };
      return { texto: textoLimpo(a && a.texto), confianca: numero(a && a.confianca) };
    }).filter(function (a) {
      var chave = semAcento(a.texto);
      if (!chave || vistos[chave]) return false;
      vistos[chave] = true;
      return true;
    });
  }

  /** Concordância entre hipóteses, sem fingir uma confiança que o motor não deu. */
  function concordancia(alternativas) {
    if (alternativas.length < 2) return null;
    var base = semAcento(alternativas[0].texto).split(' ').filter(Boolean);
    if (!base.length) return null;
    var iguais = 0;
    base.forEach(function (palavra, i) {
      var ocorrencias = alternativas.slice(1).filter(function (a) {
        var p = semAcento(a.texto).split(' ').filter(Boolean);
        return p[i] === palavra;
      }).length;
      if (ocorrencias) iguais++;
    });
    return iguais / base.length;
  }

  /**
   * Avalia uma transcrição. `resultado` aceita:
   *   { texto, confianca, alternativas: [{texto, confianca}], motor, latenciaMs }
   * Devolve o texto final e os sinais usados na decisão.
   */
  function avaliar(resultado, opcoes) {
    var r = resultado || {};
    var o = opcoes || {};
    var bruto = textoLimpo(r.texto);
    var alternativas = normalizarAlternativas(r.alternativas);
    var conf = numero(r.confianca);
    if (conf == null && alternativas.length && alternativas[0].confianca != null) conf = alternativas[0].confianca;
    var acordo = concordancia(alternativas);
    var limpo = limpar(termos(bruto));
    var final = pontuar(limpo);
    var acao = comando(limpo);
    var limiar = o.limiarBaixo == null ? LIMIAR_BAIXO : Math.max(0, Math.min(1, Number(o.limiarBaixo)));
    // Sem confiança informada, não bloqueia: o Groq não devolve esse campo.
    var baixa = conf != null && conf < limiar;
    var repetir = !!(o.exigirConfianca !== false && baixa && acao);
    var motivos = [];
    if (!bruto) motivos.push('O motor não devolveu texto.');
    if (baixa) motivos.push('Confiança baixa (' + Math.round(conf * 100) + '%).');
    if (acordo != null && acordo < 0.5 && alternativas.length > 1) motivos.push('As hipóteses do motor divergem.');
    return {
      versao: VERSAO,
      texto: final,
      bruto: bruto,
      corrigido: final !== bruto,
      confianca: conf,
      confiancaPct: conf == null ? null : Math.round(conf * 100),
      concordancia: acordo == null ? null : +acordo.toFixed(3),
      alternativas: alternativas,
      comando: acao,
      nivel: conf == null ? 'nao-informada' : conf >= LIMIAR_MEDIO ? 'alta' : conf >= limiar ? 'media' : 'baixa',
      precisaRepetir: repetir,
      motivos: motivos,
      motor: String(r.motor || ''),
      latenciaMs: Number(r.latenciaMs) >= 0 ? Math.round(Number(r.latenciaMs)) : null
    };
  }

  function tokens(v) {
    return semAcento(v).replace(/[^a-z0-9\s]/g, ' ').split(/\s+/).filter(Boolean);
  }
  function levenshtein(a, b) {
    var x = a || [], y = b || [];
    var prev = new Array(y.length + 1), cur = new Array(y.length + 1), i, j;
    for (j = 0; j <= y.length; j++) prev[j] = j;
    for (i = 1; i <= x.length; i++) {
      cur[0] = i;
      for (j = 1; j <= y.length; j++) {
        cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (x[i - 1] === y[j - 1] ? 0 : 1));
      }
      var t = prev; prev = cur; cur = t;
    }
    return prev[y.length];
  }
  /** WER por palavras; null quando não há referência. */
  function wer(esperado, reconhecido) {
    var e = tokens(esperado), r = tokens(reconhecido);
    if (!e.length) return null;
    return +(levenshtein(e, r) / e.length).toFixed(4);
  }
  function acerto(esperado, reconhecido) {
    var w = wer(esperado, reconhecido);
    return w == null ? null : +Math.max(0, 1 - w).toFixed(4);
  }

  /** Métricas de uma lista de testes: {em, esperado, reconhecido, latenciaMs}. */
  function metricas(historico) {
    var lista = Array.isArray(historico) ? historico.slice(-50) : [];
    var lat = lista.map(function (x) { return Number(x && x.latenciaMs); }).filter(function (n) { return isFinite(n) && n >= 0; });
    var acertos = lista.map(function (x) { return acerto(x && x.esperado, x && x.reconhecido); }).filter(function (n) { return n != null; });
    var audios = lista.map(function (x) { return Number(x && x.audioMs); }).filter(function (n) { return isFinite(n) && n >= 0; });
    var bytes = lista.map(function (x) { return Number(x && x.bytes); }).filter(function (n) { return isFinite(n) && n > 0; });
    var media = function (a) { return a.length ? +(a.reduce(function (s, n) { return s + n; }, 0) / a.length).toFixed(1) : null; };
    return {
      testes: lista.length,
      latenciaMediaMs: media(lat),
      audioMedioMs: media(audios),
      bytesMedios: media(bytes),
      acertoMedio: media(acertos),
      ultimoAcerto: lista.length ? acerto(lista[lista.length - 1].esperado, lista[lista.length - 1].reconhecido) : null,
      ultimoErro: lista.length ? wer(lista[lista.length - 1].esperado, lista[lista.length - 1].reconhecido) : null
    };
  }

  return {
    VERSAO: VERSAO, LIMIAR_BAIXO: LIMIAR_BAIXO, LIMIAR_MEDIO: LIMIAR_MEDIO,
    limpar: limpar, pontuar: pontuar, termos: termos, comando: comando,
    avaliar: avaliar, wer: wer, acerto: acerto, metricas: metricas,
    tokens: tokens
  };
});
