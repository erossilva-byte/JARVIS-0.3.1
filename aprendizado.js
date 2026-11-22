/* J.A.R.V.I.S. Nova 1.36.0 — aprendizado explícito, reversível e local.
 *
 * Aprende somente o que o usuário declara de forma clara ("prefiro...", "evite...",
 * "corrija...", "lembre que..."). Não infere hábitos silenciosamente, não altera
 * permissões, não guarda senhas/tokens e nunca transforma uma inferência em fato.
 */
(function (raiz, fabrica) {
  var api = fabrica();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.JarvisAprendizado = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  var CHAVE = 'jv_aprendizado';
  var LIMITE = 80;
  var LIMITE_BYTES = 96 * 1024;
  var CONFIANCA_MIN = 0.65;
  var SENSIVEL = /(senha|passcode|token|chave\s*(?:api|de\s*api)|cart[aã]o|cpf|cnpj|conta\s*banc|agência|agencia|pix|criptografia|biometria)/i;
  var PADROES = [
    { tipo: 'preferencia', rx: /^(?:eu\s+)?(?:prefiro|preferiria|gosto mais|gosto que|quero que voc[eê])\s+(.{4,220})$/i, confianca: 0.9 },
    { tipo: 'correcao', rx: /^(?:n[aã]o\s+)?(?:gosto|quero|use|fa[cç]a)\s+(?:que\s+)?(?:voc[eê]\s+)?(?:n[aã]o\s+)?(.{4,220})$/i, confianca: 0.75 },
    { tipo: 'correcao', rx: /^(?:evite|pare de|n[aã]o use|n[aã]o fa[cç]a|n[aã]o repita)\s+(.{3,220})$/i, confianca: 0.85 },
    { tipo: 'habito', rx: /^(?:de agora em diante|sempre|nunca)\s+(.{4,220})$/i, confianca: 0.8 },
    { tipo: 'fato', rx: /^(?:lembre(?:-se)? que|memorize que|anote que)\s+(.{3,240})$/i, confianca: 0.9 }
  ];

  var deposito = null;
  var relogio = function () { return Date.now(); };
  var memoria = [];

  function storePadrao() {
    try { if (typeof localStorage !== 'undefined') return localStorage; } catch (e) { /* sem storage */ }
    return null;
  }
  function store() { return deposito || storePadrao(); }
  function ler() {
    var s = store();
    if (!s) return memoria.slice();
    try {
      var j = JSON.parse(s.getItem(CHAVE) || '[]');
      return Array.isArray(j) ? j.filter(function (x) { return x && typeof x.id === 'string' && x.texto; }) : [];
    } catch (e) { return []; }
  }
  function gravar(lista) {
    var limpa = lista.slice(-LIMITE);
    if (bytes(limpa) > LIMITE_BYTES) return false;
    var s = store();
    if (!s) { memoria = limpa; return true; }
    try { s.setItem(CHAVE, JSON.stringify(limpa)); return true; } catch (e) { return false; }
  }
  function limpar(txt, max) {
    return String(txt == null ? '' : txt).replace(/[<>]/g, '').replace(/\s+/g, ' ').trim().slice(0, max);
  }
  function normalizar(txt) {
    return String(txt == null ? '' : txt).normalize('NFD').replace(/[\u0300-\u036f]/g, '')
      .toLowerCase().replace(/[^a-z0-9 ]+/g, ' ').replace(/\s+/g, ' ').trim();
  }
  function bytes(lista) {
    var t = JSON.stringify(lista || []);
    try { if (typeof TextEncoder !== 'undefined') return new TextEncoder().encode(t).length; } catch (e) { /* fallback */ }
    return unescape(encodeURIComponent(t)).length;
  }
  function id() { return 'ap_' + relogio().toString(36) + '_' + Math.random().toString(36).slice(2, 6); }

  function classificar(texto) {
    var t = limpar(texto, 260);
    if (!t) return null;
    if (SENSIVEL.test(t)) return { bloqueado: true, motivo: 'Conteúdo sensível não é aprendido automaticamente.' };
    if (/^(?:esque[cç]a|apague|limpe)\s+(?:tudo|o aprendizado|as prefer[eê]ncias)$/i.test(t)) return { limpar: true };
    for (var i = 0; i < PADROES.length; i++) {
      var m = t.match(PADROES[i].rx);
      if (m && m[1]) {
        var valor = limpar(m[1].replace(/[.!?]+$/, ''), 220);
        if (valor.length >= 3) return { tipo: PADROES[i].tipo, texto: t, valor: valor, confianca: PADROES[i].confianca };
      }
    }
    return null;
  }

  function observar(texto, opcoes) {
    var c = classificar(texto);
    if (!c) return { ok: false, motivo: 'Não é uma instrução explícita de aprendizado.' };
    if (c.bloqueado) return { ok: false, bloqueado: true, motivo: c.motivo };
    if (c.limpar) return limparTudo();
    var lista = ler();
    var chave = normalizar(c.texto);
    var igual = lista.filter(function (x) { return normalizar(x.texto) === chave; })[0];
    if (igual) {
      igual.repetido = (igual.repetido || 1) + 1;
      igual.atualizado = relogio();
      igual.confianca = Math.min(0.99, Number(igual.confianca || c.confianca) + 0.02);
      if (!gravar(lista)) return { ok: false, erro: 'Não foi possível gravar o aprendizado.' };
      return { ok: true, item: igual, repetido: true };
    }
    if (lista.length >= LIMITE) return { ok: false, erro: 'Limite de ' + LIMITE + ' aprendizados. Remova algum antes de continuar.' };
    var item = {
      id: id(), tipo: c.tipo, texto: c.texto, valor: c.valor,
      confianca: c.confianca, fonte: (opcoes && opcoes.fonte) || 'explicito',
      criado: relogio(), atualizado: relogio(), ativo: true
    };
    lista.push(item);
    if (!gravar(lista)) return { ok: false, erro: 'Não foi possível gravar o aprendizado.' };
    return { ok: true, item: item };
  }

  function feedback(texto, tipo, referencia) {
    var t = limpar(texto, 220);
    if (!t) return { ok: false, erro: 'Texto vazio.' };
    var lista = ler();
    var item = {
      id: id(), tipo: tipo === 'positivo' ? 'reforco' : 'correcao', texto: t,
      valor: tipo === 'positivo' ? 'resposta aprovada' : 'correção do usuário',
      confianca: 0.9, fonte: 'feedback', referencia: limpar(referencia, 80),
      criado: relogio(), atualizado: relogio(), ativo: true
    };
    lista.push(item);
    if (lista.length > LIMITE) lista = lista.slice(-LIMITE);
    if (!gravar(lista)) return { ok: false, erro: 'Não foi possível gravar o feedback.' };
    return { ok: true, item: item };
  }

  function listar() { return ler().slice().sort(function (a, b) { return Number(b.atualizado) - Number(a.atualizado); }); }
  function remover(idAlvo) {
    var lista = ler();
    var proxima = lista.filter(function (x) { return x.id !== idAlvo; });
    if (proxima.length === lista.length) return { ok: false, erro: 'Aprendizado não encontrado.' };
    return gravar(proxima) ? { ok: true, removidos: 1 } : { ok: false, erro: 'Não foi possível gravar.' };
  }
  function desfazer() {
    var lista = ler();
    if (!lista.length) return { ok: false, erro: 'Nada para desfazer.' };
    var removido = lista.pop();
    return gravar(lista) ? { ok: true, removido: removido } : { ok: false, erro: 'Não foi possível gravar.' };
  }
  function limparTudo() {
    var lista = ler();
    return gravar([]) ? { ok: true, removidos: lista.length } : { ok: false, erro: 'Não foi possível apagar.' };
  }

  /** Contexto curto para o prompt: somente itens ativos e confiáveis. */
  function contexto() {
    var ativos = ler().filter(function (x) { return x.ativo !== false && Number(x.confianca) >= CONFIANCA_MIN; }).slice(-10);
    if (!ativos.length) return '';
    return ativos.map(function (x) { return '- [' + x.tipo + '] ' + x.texto; }).join('\n');
  }
  function resumo() {
    var l = ler();
    return { total: l.length, ativos: l.filter(function (x) { return x.ativo !== false; }).length,
      correcoes: l.filter(function (x) { return x.tipo === 'correcao'; }).length,
      limite: LIMITE, bytes: bytes(l) };
  }
  function exportar() {
    return JSON.stringify({ formato: 'jarvis-aprendizado-1', exportado: relogio(), itens: listar() }, null, 2);
  }
  function importar(texto) {
    var j = null;
    try { j = JSON.parse(String(texto || '')); } catch (e) { return { ok: false, erro: 'JSON inválido.' }; }
    var itens = Array.isArray(j) ? j : (j && Array.isArray(j.itens) ? j.itens : null);
    if (!itens) return { ok: false, erro: 'Formato sem lista de aprendizados.' };
    var atuais = ler();
    var entraram = 0;
    itens.slice(-LIMITE).forEach(function (x) {
      if (!x || !x.texto || SENSIVEL.test(x.texto)) return;
      var t = normalizar(x.texto);
      if (atuais.some(function (a) { return normalizar(a.texto) === t; })) return;
      atuais.push({ id: id(), tipo: limpar(x.tipo, 20) || 'fato', texto: limpar(x.texto, 240),
        valor: limpar(x.valor, 220), confianca: Math.max(0, Math.min(1, Number(x.confianca) || 0.7)),
        fonte: 'importado', criado: relogio(), atualizado: relogio(), ativo: true });
      entraram++;
    });
    if (!gravar(atuais)) return { ok: false, erro: 'Não foi possível importar.' };
    return { ok: true, importados: entraram };
  }
  function configurar(opcoes) {
    var o = opcoes || {};
    if (o.store) deposito = o.store;
    if (typeof o.relogio === 'function') relogio = o.relogio;
  }

  return {
    CHAVE: CHAVE, LIMITE: LIMITE, CONFIANCA_MIN: CONFIANCA_MIN,
    classificar: classificar, observar: observar, feedback: feedback,
    listar: listar, remover: remover, desfazer: desfazer, limparTudo: limparTudo,
    contexto: contexto, resumo: resumo, exportar: exportar, importar: importar,
    configurar: configurar
  };
});
