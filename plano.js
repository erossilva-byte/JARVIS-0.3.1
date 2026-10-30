/* J.A.R.V.I.S. Nova — planos multi-etapas supervisionados.
 *
 * O modelo propõe etapas; este módulo NÃO confia nelas. Normaliza, limita a seis
 * passos, recusa ação desconhecida/indisponível e impede recursão de plano. A
 * execução usa o recibo de cada ferramenta (agentes.js): só avança em "ok".
 * Etapa "incerta" pausa e pede decisão humana; falha/bloqueio/cancelamento param
 * o plano e nenhuma etapa seguinte roda.
 *
 * Módulo puro: recebe o executor e as confirmações por injeção, então é testável
 * sem DOM, rede ou aparelho.
 */
(function (raiz, fabrica) {
  const api = fabrica();
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (raiz) raiz.PlanoJarvis = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  const MAX_PASSOS = 6;
  const MAX_ARGS = 2000;

  function extrairJson(texto) {
    let s = String(texto == null ? '' : texto).trim();
    s = s.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/,'').trim();
    const i = s.indexOf('{'), j = s.lastIndexOf('}');
    if (i < 0 || j <= i) return null;
    try { return JSON.parse(s.slice(i, j + 1)); } catch (e) { return null; }
  }

  /**
   * Valida a proposta do modelo. Devolve { ok, plano } ou { ok:false, erro }.
   * Nunca trunca em silêncio: plano com passos demais é recusado.
   */
  function normalizar(bruto, ctx) {
    const c = ctx || {};
    const obj = typeof bruto === 'string' ? extrairJson(bruto) : bruto;
    if (!obj || typeof obj !== 'object' || Array.isArray(obj)) {
      return { ok: false, erro: 'A resposta não contém um objeto de plano válido.' };
    }
    const objetivo = String(obj.objetivo || c.objetivo || '').trim().slice(0, 240);
    if (!objetivo) return { ok: false, erro: 'O plano não tem objetivo.' };
    const passos = Array.isArray(obj.passos) ? obj.passos : [];
    const max = Math.max(1, Math.min(MAX_PASSOS, Number(c.maxPassos) || MAX_PASSOS));
    if (!passos.length) return { ok: false, erro: 'O plano não tem etapas.' };
    if (passos.length > max) return { ok: false, erro: 'O plano tem ' + passos.length + ' etapas; o limite é ' + max + '.' };
    const acoes = c.acoes || {};
    const disp = Array.isArray(c.disponiveis) ? c.disponiveis : null;
    const saida = [];
    for (let i = 0; i < passos.length; i++) {
      const p = passos[i];
      if (!p || typeof p !== 'object' || Array.isArray(p)) return { ok: false, erro: 'Etapa ' + (i + 1) + ' inválida.' };
      const acao = String(p.acao || '').trim();
      if (!/^[a-z][a-z0-9_]{1,39}$/.test(acao)) return { ok: false, erro: 'Etapa ' + (i + 1) + ' tem nome de ação inválido.' };
      if (acao === 'executar_plano' || acao === 'planejar' || acao === 'plano') {
        return { ok: false, erro: 'Etapa ' + (i + 1) + ' tenta criar um plano dentro do plano.' };
      }
      if (!Object.prototype.hasOwnProperty.call(acoes, acao)) {
        return { ok: false, erro: 'Etapa ' + (i + 1) + ' usa ação inexistente: ' + acao + '.' };
      }
      if (disp && disp.indexOf(acao) < 0) {
        return { ok: false, erro: 'Etapa ' + (i + 1) + ' usa ação indisponível nesta plataforma: ' + acao + '.' };
      }
      const args = (p.args && typeof p.args === 'object' && !Array.isArray(p.args)) ? p.args : {};
      let tamanho = 0;
      try { tamanho = JSON.stringify(args).length; } catch (e) { return { ok: false, erro: 'Etapa ' + (i + 1) + ' tem argumentos inválidos.' }; }
      if (tamanho > MAX_ARGS) return { ok: false, erro: 'Etapa ' + (i + 1) + ' tem argumentos grandes demais.' };
      saida.push({
        id: 'p' + (i + 1),
        acao,
        args,
        porque: String(p.porque || p.motivo || '').trim().slice(0, 140),
        risco: Number(acoes[acao] && acoes[acao].risco) || 0
      });
    }
    return {
      ok: true,
      plano: {
        objetivo,
        passos: saida,
        riscoMax: saida.reduce((m, p) => Math.max(m, p.risco), 0)
      }
    };
  }

  function descrever(passo) {
    return String(passo && passo.acao || '').replace(/_/g, ' ') + (passo && passo.porque ? ' — ' + passo.porque : '');
  }

  function resumo(plano) {
    const ps = (plano && plano.passos) || [];
    return ps.map((p, i) => (i + 1) + '. ' + descrever(p)).join(' · ');
  }

  function vazio() {
    return { passos: [], ok: 0, incerto: 0, falhou: 0, executados: 0 };
  }

  /**
   * Executa o plano. `op`:
   *  - executar(passo) -> resultado com `recibo` (obrigatório para "ok");
   *  - cancelado() -> true para parar antes da próxima etapa;
   *  - aoIniciar(passo, indice), aoConcluir(passo, indice, resultado);
   *  - confirmarIncerteza(passo, resultado, estado) -> true para seguir;
   *  - classificar(resultado) opcional (padrão: usa recibo).
   */
  async function executar(plano, op) {
    const o = op || {};
    const passos = (plano && plano.passos) || [];
    const estados = [];
    let ok = 0, incerto = 0, falhou = 0;
    function fechar(status) {
      return {
        status, objetivo: plano && plano.objetivo, passos: estados,
        total: passos.length, executados: estados.length, ok, incerto, falhou,
        ultimo: estados.length ? estados[estados.length - 1] : null
      };
    }
    if (!passos.length) return fechar('falhou');
    for (let i = 0; i < passos.length; i++) {
      const p = passos[i];
      if (typeof o.cancelado === 'function' && o.cancelado()) return fechar('cancelado');
      if (typeof o.aoIniciar === 'function') await o.aoIniciar(p, i);
      let res = null;
      try { res = await o.executar(p, i); }
      catch (e) { res = { falhou: true, info: String((e && e.message) || e || 'erro') }; }
      let est = null;
      if (res && res.recibo) est = res.recibo;
      else if (typeof o.classificar === 'function') est = o.classificar(res);
      let estado = est && est.estado ? est.estado : '';
      if (!estado) {
        if (res === null) estado = 'cancelado';
        else if (res && (res.falhou === true || res.erro || res.bloqueado === true)) estado = res.bloqueado === true ? 'bloqueado' : 'falhou';
        else estado = 'incerto';
      }
      const motivo = (est && est.motivo) || (res === null ? 'cancelado antes de executar' : (res && (res.erro || res.info)) || 'a ferramenta não devolveu recibo');
      const item = { id: p.id, acao: p.acao, estado, motivo, info: String((res && (res.info || res.fala)) || '').slice(0, 220) };
      estados.push(item);
      if (estado === 'ok') {
        ok++;
        if (typeof o.aoConcluir === 'function') await o.aoConcluir(p, i, res, item);
        continue;
      }
      if (estado === 'incerto') {
        incerto++;
        if (typeof o.aoIncertar === 'function') await o.aoIncertar(p, res, item, i);
        const seguir = typeof o.confirmarIncerteza === 'function' ? !!(await o.confirmarIncerteza(p, res, item, i)) : false;
        if (seguir) {
          if (typeof o.aoConcluir === 'function') await o.aoConcluir(p, i, res, item);
          continue;
        }
        return fechar('pausado');
      }
      falhou++;
      if (typeof o.aoFalhar === 'function') await o.aoFalhar(p, res, item, i);
      return fechar(estado === 'cancelado' ? 'cancelado' : estado === 'bloqueado' ? 'bloqueado' : 'falhou');
    }
    return fechar('concluido');
  }

  return { MAX_PASSOS, extrairJson, normalizar, executar, resumo, descrever };
});
