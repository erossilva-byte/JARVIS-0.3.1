/* J.A.R.V.I.S. Nova — Política do PIN e espera progressiva (PC).
 *
 * Porte das regras que só existiam no Flutter (`core/seguranca.dart`) e que no
 * PC estavam espalhadas dentro do `app.js`:
 *
 *  - o PIN é recusado quando é adivinhado em segundos (curto, longo, com letra,
 *    repetido, sequência ou da lista dos mais usados);
 *  - o PIN nunca é guardado: fica só o derivado PBKDF2-HMAC-SHA256 com sal
 *    aleatório, 120.000 iterações e 32 bytes (mesmos parâmetros do celular);
 *  - erro conta, acerto zera, e a espera **cresce** a cada bloco de cinco
 *    falhas: 30 s, 1 min, 2 min… até 15 min.
 *
 * Sem DOM e sem Electron. A derivação usa `node:crypto` quando existe (testes
 * e processo principal); no renderer o app deriva pelo WebCrypto com os mesmos
 * parâmetros, e o teste do vetor fixo garante que os dois chegam ao mesmo byte.
 */
(function (raiz, fabrica) {
  var api = fabrica();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.BloqueioRegras = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  var TAMANHO_MIN = 4;
  var TAMANHO_MAX = 8;
  var TENTATIVAS_ANTES_DE_ESPERA = 5;
  var ESPERA_BASE_SEG = 30;
  var ESPERA_MAX_SEG = 900;
  var ITERACOES = 120000;
  var PREFIXO_PIN = 'pin|';
  var BYTES_SAL = 16;
  var BYTES_HASH = 32;

  var MENSAGENS = {
    ok: 'PIN aceito.',
    curto: 'O PIN precisa ter pelo menos ' + TAMANHO_MIN + ' dígitos.',
    longo: 'O PIN pode ter no máximo ' + TAMANHO_MAX + ' dígitos.',
    naoNumerico: 'O PIN aceita somente números.',
    repetido: 'Não use o mesmo dígito repetido; isso é adivinhado em segundos.',
    sequencia: 'Não use sequência de dígitos (1234, 9876); isso é adivinhado em segundos.',
    comum: 'Esse PIN é um dos mais usados do mundo. Escolha outro.'
  };

  var PINS_COMUNS = {
    1234: 1, 4321: 1, 1212: 1, 2121: 1, 1122: 1, 2211: 1,
    '0000': 1, 1111: 1, 2222: 1, 3333: 1, 4444: 1, 5555: 1, 6666: 1,
    7777: 1, 8888: 1, 9999: 1, 1010: 1, '0101': 1, 1230: 1, '0852': 1,
    1379: 1, 2468: 1, 1357: 1, 2580: 1, 1590: 1, 2000: 1, 2020: 1,
    6969: 1, 101112: 1, 123123: 1, 112233: 1, 654321: 1, 111222: 1, 147258: 1
  };

  function mensagemPolitica(codigo) {
    return MENSAGENS[codigo] || MENSAGENS.curto;
  }

  /** Regras mínimas de um PIN novo. Devolve o código e a mensagem pronta. */
  function avaliarPin(pin) {
    var limpo = String(pin == null ? '' : pin).trim();
    var codigo = 'ok';
    if (!limpo) codigo = 'curto';
    else if (!/^\d+$/.test(limpo)) codigo = 'naoNumerico';
    else if (limpo.length < TAMANHO_MIN) codigo = 'curto';
    else if (limpo.length > TAMANHO_MAX) codigo = 'longo';
    else {
      var digitos = {};
      for (var i = 0; i < limpo.length; i++) digitos[limpo.charAt(i)] = 1;
      if (Object.keys(digitos).length === 1) codigo = 'repetido';
    }
    if (codigo === 'ok') {
      var crescente = true;
      var decrescente = true;
      for (var j = 1; j < limpo.length; j++) {
        var anterior = Number(limpo.charAt(j - 1));
        var atual = Number(limpo.charAt(j));
        if (atual !== anterior + 1) crescente = false;
        if (atual !== anterior - 1) decrescente = false;
      }
      if (crescente || decrescente) codigo = 'sequencia';
      else if (PINS_COMUNS[limpo]) codigo = 'comum';
    }
    return { ok: codigo === 'ok', codigo: codigo, mensagem: mensagemPolitica(codigo) };
  }

  /** Espera depois de [bloqueios] blocos de cinco falhas: 30 s, 60 s, 120 s… */
  function esperaDeBloqueios(bloqueios) {
    var n = Math.max(0, Math.min(10, Math.round(Number(bloqueios) || 0)));
    return Math.min(ESPERA_MAX_SEG, ESPERA_BASE_SEG * Math.pow(2, n));
  }

  function formatarEspera(segundos) {
    var s = Math.max(0, Math.round(Number(segundos) || 0));
    if (s === 0) return 'imediatamente';
    if (s < 60) return s + ' s';
    var minutos = Math.round(s / 60);
    return minutos === 1 ? '1 minuto' : minutos + ' minutos';
  }

  function configPadrao() {
    return { ativo: false, tentativas: 0, bloqueios: 0, bloqueadoAte: 0, esperaSeg: 0 };
  }

  /** Lê a configuração salva sem inventar nada quando o campo falta. */
  function normalizarConfig(bruto) {
    var o = bruto && typeof bruto === 'object' && !Array.isArray(bruto) ? bruto : {};
    var inteiro = function (v, min, max, reserva) {
      var n = Number(v);
      if (!isFinite(n)) return reserva;
      return Math.max(min, Math.min(max, Math.round(n)));
    };
    var ate = Number(o.bloqueadoAte) || 0;
    return {
      ativo: o.ativo === true,
      tentativas: inteiro(o.tentativas, 0, TENTATIVAS_ANTES_DE_ESPERA, 0),
      bloqueios: inteiro(o.bloqueios, 0, 10, 0),
      // A data fica como foi gravada; quem decide se ainda bloqueia é
      // `restanteDeEspera`, com o relógio de quem pergunta (teste e app).
      bloqueadoAte: ate > 0 ? Math.round(ate) : 0,
      esperaSeg: 0
    };
  }

  function restanteDeEspera(config, agora) {
    var c = config || {};
    var quando = Number(agora == null ? Date.now() : agora);
    var ate = Number(c.bloqueadoAte) || 0;
    if (!ate) return 0;
    var resta = ate - quando;
    return resta > 0 ? Math.ceil(resta / 1000) : 0;
  }

  function bloqueadoEm(config, agora) {
    return restanteDeEspera(config, agora) > 0;
  }

  /**
   * Aplica uma tentativa. Acerto zera falhas e a escala de espera; erro conta e,
   * no quinto erro, aplica a espera do bloco (que cresce a cada bloco).
   */
  function avaliarTentativa(opcoes) {
    var o = opcoes || {};
    var config = normalizarConfig(o.config);
    var agora = Number(o.agora == null ? Date.now() : o.agora);
    var resta = restanteDeEspera(config, agora);
    if (resta > 0) {
      return {
        ok: false,
        bloquado: true,
        mensagem: 'Muitas tentativas. Aguarde ' + formatarEspera(resta) + ' antes de tentar de novo.',
        config: config,
        esperaSeg: resta
      };
    }
    var base = { ativo: config.ativo, bloqueios: config.bloqueios };
    if (o.pinCorreto === true) {
      return {
        ok: true,
        bloqueado: false,
        mensagem: 'Desbloqueado.',
        config: Object.assign({}, config, base, { tentativas: 0, bloqueios: 0, bloqueadoAte: 0 }),
        esperaSeg: 0
      };
    }
    var falhas = config.tentativas + 1;
    if (falhas >= TENTATIVAS_ANTES_DE_ESPERA) {
      var espera = esperaDeBloqueios(config.bloqueios);
      return {
        ok: false,
        bloqueado: true,
        mensagem: 'PIN incorreto. Aguarde ' + formatarEspera(espera) + ' antes de tentar de novo.',
        config: Object.assign({}, config, {
          ativo: config.ativo,
          tentativas: 0,
          bloqueios: Math.min(10, config.bloqueios + 1),
          bloqueadoAte: agora + espera * 1000
        }),
        esperaSeg: espera
      };
    }
    var restantes = TENTATIVAS_ANTES_DE_ESPERA - falhas;
    return {
      ok: false,
      bloqueado: false,
      mensagem: 'PIN incorreto. ' + (restantes === 1 ? 'Resta 1 tentativa' : 'Restam ' + restantes + ' tentativas') + '.',
      config: Object.assign({}, config, base, { tentativas: falhas, bloqueadoAte: 0 }),
      esperaSeg: 0
    };
  }

  function hexDe(bytes) {
    var lista = bytes || [];
    var saida = '';
    for (var i = 0; i < lista.length; i++) {
      saida += ('0' + (Number(lista[i]) & 0xff).toString(16)).slice(-2);
    }
    return saida;
  }

  function bytesDeHex(hex) {
    var limpo = String(hex == null ? '' : hex).trim().toLowerCase();
    if (!limpo || limpo.length % 2 !== 0 || !/^[0-9a-f]+$/.test(limpo)) return null;
    var saida = [];
    for (var i = 0; i < limpo.length; i += 2) {
      saida.push(parseInt(limpo.slice(i, i + 2), 16));
    }
    return saida;
  }

  /** PBKDF2-HMAC-SHA256 (um bloco, 32 bytes) — os mesmos parâmetros do app. */
  function derivarPin(pin, sal, opcoes) {
    var o = opcoes || {};
    var iteracoes = o.iteracoes === undefined ? ITERACOES : Math.round(Number(o.iteracoes));
    if (!isFinite(iteracoes) || iteracoes < 1) throw new Error('iterações precisam ser positivas');
    var cripto = null;
    try { cripto = require('node:crypto'); } catch (e) { cripto = null; }
    if (!cripto || typeof cripto.pbkdf2Sync !== 'function') {
      throw new Error('A derivação do PIN roda no processo principal do PC; no navegador use o WebCrypto.');
    }
    var salBytes = sal instanceof Uint8Array ? Buffer.from(sal) : Buffer.from(sal || []);
    var saida = cripto.pbkdf2Sync(
      Buffer.from(String(pin == null ? '' : pin), 'utf8'),
      salBytes, iteracoes, BYTES_HASH, 'sha256'
    );
    return new Uint8Array(saida);
  }

  /** Comparação em tempo constante: nunca diz em qual byte a diferença apareceu. */
  function compararDigest(a, b) {
    if (!a || !b || a.length === 0 || a.length !== b.length) return false;
    var diferenca = 0;
    for (var i = 0; i < a.length; i++) diferenca |= (a[i] ^ b[i]);
    return diferenca === 0;
  }

  /** Formato guardado: `pbkdf2$sal$digest`, o mesmo do app antes desta versão. */
  function empacotarDigest(salHex, digestHex) {
    return 'pbkdf2$' + salHex + '$' + digestHex;
  }

  function separarDigest(valor) {
    var partes = String(valor == null ? '' : valor).split('$');
    if (partes.length !== 3 || partes[0] !== 'pbkdf2') return null;
    var sal = bytesDeHex(partes[1]);
    var digest = bytesDeHex(partes[2]);
    if (!sal || sal.length !== BYTES_SAL || !digest || digest.length !== BYTES_HASH) return null;
    return { sal: sal, digest: digest, salHex: partes[1], digestHex: partes[2] };
  }

  function novoSal(aleatorio) {
    var r = aleatorio || (typeof crypto !== 'undefined' && crypto.getRandomValues ? crypto : null);
    var bytes = new Uint8Array(BYTES_SAL);
    if (r && typeof r.getRandomValues === 'function') r.getRandomValues(bytes);
    else {
      var nodeCripto = null;
      try { nodeCripto = require('node:crypto'); } catch (e) { nodeCripto = null; }
      if (!nodeCripto) throw new Error('Sem fonte de aleatoriedade para o sal do PIN.');
      nodeCripto.randomFillSync(bytes);
    }
    return bytes;
  }

  return {
    TAMANHO_MIN: TAMANHO_MIN,
    TAMANHO_MAX: TAMANHO_MAX,
    TENTATIVAS_ANTES_DE_ESPERA: TENTATIVAS_ANTES_DE_ESPERA,
    ESPERA_BASE_SEG: ESPERA_BASE_SEG,
    ESPERA_MAX_SEG: ESPERA_MAX_SEG,
    ITERACOES: ITERACOES,
    PREFIXO_PIN: PREFIXO_PIN,
    BYTES_SAL: BYTES_SAL,
    BYTES_HASH: BYTES_HASH,
    MENSAGENS: MENSAGENS,
    mensagemPolitica: mensagemPolitica,
    avaliarPin: avaliarPin,
    esperaDeBloqueios: esperaDeBloqueios,
    formatarEspera: formatarEspera,
    configPadrao: configPadrao,
    normalizarConfig: normalizarConfig,
    restanteDeEspera: restanteDeEspera,
    bloqueadoEm: bloqueadoEm,
    avaliarTentativa: avaliarTentativa,
    hexDe: hexDe,
    bytesDeHex: bytesDeHex,
    derivarPin: derivarPin,
    compararDigest: compararDigest,
    empacotarDigest: empacotarDigest,
    separarDigest: separarDigest,
    novoSal: novoSal
  };
});
