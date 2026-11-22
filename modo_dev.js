/* J.A.R.V.I.S. Nova — autorização do modo de desenvolvimento (Fase 3).
 *
 * A Fase 3 exige "analisar, corrigir, testar e evoluir o próprio projeto **somente com a
 * minha autorização**". Antes disto, o painel de desenvolvimento corrigia e criava arquivos
 * sem nenhuma porta: a autorização era implícita.
 *
 * Regras deste módulo:
 *  - leitura (analisar, testar, exportar) é sempre livre — não altera nada;
 *  - escrita (corrigir, criar, editar, aplicar, projeto) exige autorização **ativa e no prazo**;
 *  - operação desconhecida é negada: nada é liberado por engano;
 *  - toda tentativa entra no histórico, permitida ou negada, com hora;
 *  - a autorização expira sozinha (padrão 30 min, mínimo 5, máximo 240).
 *
 * Sem DOM e sem rede: recebe a loja e o relógio de fora, para poder ser testado de verdade.
 */
(function (raiz) {
  'use strict';

  var CHAVE = 'modo_dev';
  var CHAVE_HIST = 'modo_dev_hist';
  var MIN_PADRAO = 30;
  var MIN_MIN = 5;
  var MIN_MAX = 240;
  var HIST_MAX = 40;

  var LEITURA = { analisar: 1, testar: 1, exportar: 1, listar: 1 };
  var ESCRITA = { corrigir: 1, criar: 1, editar: 1, aplicar: 1, projeto: 1 };

  // Arquivos do próprio aplicativo: alterá-los muda o produto, não um documento do usuário.
  var PROPRIOS = [
    'app.js', 'index.html', 'style.css', 'interface.css', 'core.css',
    'hermes.js', 'agentes.js', 'plano.js', 'sandbox.js', 'sistema.js',
    'consumo_ia.js', 'modo_dev.js', 'nucleo_v3.js', 'nucleo_v3.css',
    'arquivos_dev.js', 'package.json'
  ];

  function nomeBase(caminho) {
    var s = String(caminho || '').replace(/\\/g, '/');
    var partes = s.split('/');
    return (partes[partes.length - 1] || '').toLowerCase();
  }

  /**
   * O caminho aponta para código deste aplicativo? Conservador de propósito: um falso
   * positivo (pedir autorização para um arquivo com nome igual) é melhor que editar o
   * próprio produto sem ninguém saber.
   */
  function ehCodigoDoProjeto(caminho) {
    var bruto = String(caminho || '').replace(/\\/g, '/');
    var base = nomeBase(bruto);
    if (!base) return false;
    if (PROPRIOS.indexOf(base) >= 0) return true;
    if (/^test_.*\.js$/.test(base) && /(^|\/)tests\//i.test(bruto)) return true;
    return false;
  }

  function criar(opcoes) {
    var o = opcoes || {};
    var loja = o.store || null;
    var memoria = {};
    var relogio = (typeof o.agora === 'function') ? o.agora : function () { return Date.now(); };

    function lerBruto(chave, padrao) {
      if (loja && typeof loja.get === 'function') {
        try { return loja.get(chave, padrao); } catch (e) { return padrao; }
      }
      return Object.prototype.hasOwnProperty.call(memoria, chave) ? memoria[chave] : padrao;
    }

    function gravarBruto(chave, valor) {
      if (loja && typeof loja.set === 'function') {
        try { loja.set(chave, valor); return true; } catch (e) { return false; }
      }
      memoria[chave] = valor;
      return true;
    }

    function lerEstado() {
      try {
        var bruto = lerBruto(CHAVE, '');
        if (!bruto) return null;
        var e = JSON.parse(bruto);
        if (!e || typeof e !== 'object') return null;
        if (!(Number(e.ate) > 0)) return null;
        return { desde: Number(e.desde) || 0, ate: Number(e.ate) || 0, minutos: Number(e.minutos) || 0 };
      } catch (err) { return null; }
    }

    function historia() {
      try {
        var l = JSON.parse(lerBruto(CHAVE_HIST, '[]'));
        return Array.isArray(l) ? l : [];
      } catch (e) { return []; }
    }

    function registrar(operacao, permitido, detalhe) {
      var l = historia();
      l.unshift({
        quando: new Date(relogio()).toISOString(),
        operacao: String(operacao || '').slice(0, 40),
        permitido: !!permitido,
        detalhe: String(detalhe || '').slice(0, 160)
      });
      gravarBruto(CHAVE_HIST, JSON.stringify(l.slice(0, HIST_MAX)));
      return l[0];
    }

    function estado() {
      var e = lerEstado();
      var agora = relogio();
      var ativo = !!(e && e.ate > agora);
      return {
        ativo: ativo,
        desde: e ? e.desde : 0,
        ate: e ? e.ate : 0,
        minutos: e ? e.minutos : 0,
        restanteMs: ativo ? e.ate - agora : 0
      };
    }

    function ligar(minutos) {
      var m = Number(minutos);
      if (!isFinite(m) || m <= 0) m = MIN_PADRAO;
      m = Math.max(MIN_MIN, Math.min(MIN_MAX, Math.round(m)));
      var agora = relogio();
      gravarBruto(CHAVE, JSON.stringify({ desde: agora, ate: agora + m * 60000, minutos: m }));
      registrar('ligar', true, 'autorizado por ' + m + ' minuto(s)');
      return estado();
    }

    function desligar() {
      gravarBruto(CHAVE, '');
      registrar('desligar', true, 'encerrado pelo usuário');
      return estado();
    }

    function classeDe(operacao) {
      var op = String(operacao || '').toLowerCase();
      if (LEITURA[op]) return 'leitura';
      if (ESCRITA[op]) return 'escrita';
      return 'desconhecida';
    }

    function autorizar(operacao) {
      var classe = classeDe(operacao);
      if (classe === 'leitura') {
        return { ok: true, classe: classe, motivo: 'leitura não altera o projeto' };
      }
      if (classe === 'desconhecida') {
        return { ok: false, classe: classe, motivo: 'operação desconhecida; nada é liberado por engano' };
      }
      var e = estado();
      if (!e.ativo) {
        return { ok: false, classe: classe, motivo: 'modo de desenvolvimento desligado ou expirado' };
      }
      return { ok: true, classe: classe, motivo: 'modo de desenvolvimento ativo por mais ' + Math.ceil(e.restanteMs / 60000) + ' minuto(s)' };
    }

    /* Decide e registra: a negativa também fica no histórico. */
    function verificar(operacao, detalhe) {
      var d = autorizar(operacao);
      registrar(operacao, d.ok, d.motivo + (detalhe ? ' · ' + detalhe : ''));
      return d;
    }

    function historico(limite) {
      var n = Math.max(1, Math.min(HIST_MAX, Number(limite) || 10));
      return historia().slice(0, n);
    }

    return {
      estado: estado,
      ligar: ligar,
      desligar: desligar,
      autorizar: autorizar,
      verificar: verificar,
      registrar: registrar,
      historico: historico,
      classeDe: classeDe,
      ehCodigoDoProjeto: ehCodigoDoProjeto
    };
  }

  var api = {
    CHAVE: CHAVE,
    CHAVE_HIST: CHAVE_HIST,
    MIN_PADRAO: MIN_PADRAO,
    MIN_MIN: MIN_MIN,
    MIN_MAX: MIN_MAX,
    PROPRIOS: PROPRIOS,
    ehCodigoDoProjeto: ehCodigoDoProjeto,
    criar: criar
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (raiz) raiz.ModoDev = api;
})(typeof window !== 'undefined' ? window : null);
