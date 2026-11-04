/* J.A.R.V.I.S. Nova — planos multi-etapas supervisionados.
 *
 * O modelo propõe etapas; este módulo NÃO confia nelas. Normaliza, limita a seis
 * passos, recusa ação desconhecida/indisponível e impede recursão de plano. A
 * execução usa o recibo de cada ferramenta (agentes.js): só avança em "ok".
 * Etapa "incerta" pausa e pede decisão humana; falha/bloqueio/cancelamento param
 * o plano e nenhuma etapa seguinte roda.
 *
 * Desde a 1.44.0 o plano aceita dependências explícitas (DAG):
 *  - `deps` (ou `depende_de`) referencia IDs de etapas ou índices 1-based;
 *  - IDs desconhecidos, auto-dependência e ciclos são recusados;
 *  - uma etapa só roda quando todas as dependências foram concluídas;
 *  - se uma dependência falhar, os dependentes ficam "bloqueado" e não rodam;
 *  - sem nenhuma dependência declarada, o plano continua linear (retrocompatível).
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
  const ID_VALIDO = /^[a-zA-Z][a-zA-Z0-9_-]{0,39}$/;

  function extrairJson(texto) {
    let s = String(texto == null ? '' : texto).trim();
    s = s.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/,'').trim();
    const i = s.indexOf('{'), j = s.lastIndexOf('}');
    if (i < 0 || j <= i) return null;
    try { return JSON.parse(s.slice(i, j + 1)); } catch (e) { return null; }
  }

  /** Lê a lista de dependências declarada pelo modelo, sem confiar no formato. */
  function lerDeps(bruto) {
    if (bruto == null) return { ok: true, deps: [] };
    if (!Array.isArray(bruto)) return { ok: false, erro: 'dependências precisam ser uma lista' };
    return { ok: true, deps: bruto };
  }

  /** Ordem topológica estável (desempate pelo índice original). Detecta ciclo. */
  function ordenar(passos) {
    const indice = {};
    const grau = {};
    const filhos = {};
    passos.forEach((p, i) => {
      indice[p.id] = i;
      grau[p.id] = 0;
      filhos[p.id] = filhos[p.id] || [];
    });
    passos.forEach((p) => {
      p.deps.forEach((d) => {
        grau[p.id]++;
        (filhos[d] = filhos[d] || []).push(p.id);
      });
    });
    const prontos = passos.filter((p) => grau[p.id] === 0).map((p) => p.id);
    const ordem = [];
    while (prontos.length) {
      prontos.sort((a, b) => indice[a] - indice[b]);
      const id = prontos.shift();
      ordem.push(id);
      (filhos[id] || []).forEach((f) => {
        grau[f]--;
        if (grau[f] === 0) prontos.push(f);
      });
    }
    if (ordem.length !== passos.length) {
      const ciclo = passos.filter((p) => ordem.indexOf(p.id) < 0).map((p) => p.id);
      return { ok: false, erro: 'O plano tem dependência circular entre: ' + ciclo.join(', ') + '.' };
    }
    return { ok: true, ordem };
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
    const usados = Object.create(null);
    let declarouDeps = false;
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
      const id = typeof p.id === 'string' && ID_VALIDO.test(p.id.trim()) ? p.id.trim() : 'p' + (i + 1);
      if (usados[id]) return { ok: false, erro: 'Etapa ' + (i + 1) + ' repete o ID ' + id + '.' };
      usados[id] = true;
      const brutoDeps = p.deps != null ? p.deps : (p.depende_de != null ? p.depende_de : p.dependencias);
      const leitura = lerDeps(brutoDeps);
      if (!leitura.ok) return { ok: false, erro: 'Etapa ' + (i + 1) + ': ' + leitura.erro + '.' };
      if (leitura.deps.length) declarouDeps = true;
      saida.push({
        id,
        acao,
        args,
        porque: String(p.porque || p.motivo || '').trim().slice(0, 140),
        risco: Number(acoes[acao] && acoes[acao].risco) || 0,
        deps: leitura.deps,
        depsBruto: brutoDeps
      });
    }
    // Resolve dependências por ID ou por índice 1-based. A validação é feita
    // depois de todos os IDs existirem, então uma etapa pode depender de outra
    // declarada mais adiante — a ordem de execução vem do grafo, não do texto.
    const porId = Object.create(null);
    saida.forEach((p) => { porId[p.id] = p; });
    for (let i = 0; i < saida.length; i++) {
      const p = saida[i];
      const resolvidas = [];
      for (const d of p.deps) {
        let ref = '';
        if (typeof d === 'number' && Number.isInteger(d)) {
          if (d < 1 || d > saida.length) return { ok: false, erro: 'Etapa ' + (i + 1) + ' depende de um índice inexistente: ' + d + '.' };
          ref = saida[d - 1].id;
        } else if (typeof d === 'string') {
          const s = d.trim();
          if (porId[s]) ref = s;
          else if (/^\d+$/.test(s)) {
            const n = parseInt(s, 10);
            if (n < 1 || n > saida.length) return { ok: false, erro: 'Etapa ' + (i + 1) + ' depende de um índice inexistente: ' + s + '.' };
            ref = saida[n - 1].id;
          } else return { ok: false, erro: 'Etapa ' + (i + 1) + ' depende de uma etapa desconhecida: ' + s + '.' };
        } else return { ok: false, erro: 'Etapa ' + (i + 1) + ' tem dependência inválida.' };
        if (ref === p.id) return { ok: false, erro: 'Etapa ' + (i + 1) + ' depende de si mesma.' };
        if (resolvidas.indexOf(ref) < 0) resolvidas.push(ref);
      }
      p.deps = resolvidas;
      delete p.depsBruto;
    }
    // Sem dependências declaradas, o comportamento antigo é preservado: cada
    // etapa depende da anterior. Com dependências, quem não declarar nada é raiz.
    const modo = declarouDeps ? 'dag' : 'linear';
    if (modo === 'linear') {
      saida.forEach((p, i) => { p.deps = i === 0 ? [] : [saida[i - 1].id]; });
    }
    const ordenacao = ordenar(saida);
    if (!ordenacao.ok) return { ok: false, erro: ordenacao.erro };
    return {
      ok: true,
      plano: {
        objetivo,
        passos: saida,
        riscoMax: saida.reduce((m, p) => Math.max(m, p.risco), 0),
        modo,
        ordem: ordenacao.ordem
      }
    };
  }

  function descrever(passo) {
    return String(passo && passo.acao || '').replace(/_/g, ' ') + (passo && passo.porque ? ' — ' + passo.porque : '');
  }

  function resumoArgs(args) {
    const a = args && typeof args === 'object' ? args : {};
    return Object.keys(a).slice(0, 6).map((k) => {
      let v = a[k];
      if (v == null) return k;
      if (typeof v === 'object') { try { v = JSON.stringify(v); } catch (e) { v = '[objeto]'; } }
      return k + '=' + String(v).replace(/\s+/g, ' ').slice(0, 80);
    }).join(', ');
  }

  /** Resumo para exibição. Com { args: true }, mostra o que será enviado antes da confirmação. */
  function resumo(plano, opcoes) {
    const ps = (plano && plano.passos) || [];
    const comArgs = !!(opcoes && opcoes.args);
    const mostrarDeps = !!(plano && plano.modo === 'dag');
    return ps.map((p, i) => {
      const extra = comArgs ? resumoArgs(p.args) : '';
      const deps = mostrarDeps && Array.isArray(p.deps) && p.deps.length ? ' (após ' + p.deps.join(', ') + ')' : '';
      return (i + 1) + '. ' + descrever(p) + deps + (extra ? ' [' + extra + ']' : '');
    }).join(' · ');
  }

  function vazio() {
    return { passos: [], ok: 0, incerto: 0, falhou: 0, bloqueado: 0, executados: 0 };
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
    const porId = Object.create(null);
    passos.forEach((p) => { porId[p.id] = p; });
    const modo = (plano && plano.modo) || 'linear';
    const ordemIds = (plano && Array.isArray(plano.ordem) && plano.ordem.length)
      ? plano.ordem.slice()
      : passos.map((p) => p.id);
    const estados = [];
    const estadoPorId = Object.create(null);
    let ok = 0, incerto = 0, falhou = 0, bloqueado = 0;
    function fechar(status) {
      return {
        status, objetivo: plano && plano.objetivo, passos: estados,
        total: passos.length, executados: estados.length, ok, incerto, falhou, bloqueado,
        ordem: ordemIds.filter((id) => !!estadoPorId[id]),
        ultimo: estados.length ? estados[estados.length - 1] : null
      };
    }
    if (!passos.length) return fechar('falhou');
    const depsDe = (p) => Array.isArray(p && p.deps) ? p.deps : [];
    const liberado = (id) => {
      const e = estadoPorId[id];
      return !!e && (e.estado === 'ok' || e.liberado === true);
    };
    // Marca como bloqueadas todas as etapas que dependem, direta ou
    // indiretamente, de uma etapa que não concluiu.
    function bloquearDependentes(idOrigem) {
      const fila = [idOrigem];
      const vistos = Object.create(null);
      while (fila.length) {
        const atual = fila.shift();
        passos.forEach((p) => {
          if (vistos[p.id] || estadoPorId[p.id]) return;
          if (depsDe(p).indexOf(atual) < 0) return;
          vistos[p.id] = true;
          const item = {
            id: p.id, acao: p.acao, estado: 'bloqueado',
            motivo: 'dependência não concluída: ' + atual, info: ''
          };
          estados.push(item);
          estadoPorId[p.id] = item;
          bloqueado++;
          fila.push(p.id);
        });
      }
    }
    for (const id of ordemIds) {
      const p = porId[id];
      if (!p || estadoPorId[p.id]) continue;
      const indice = passos.indexOf(p);
      if (typeof o.cancelado === 'function' && o.cancelado()) return fechar('cancelado');
      const pendentes = depsDe(p).filter((d) => !liberado(d));
      if (pendentes.length) {
        const item = {
          id: p.id, acao: p.acao, estado: 'bloqueado',
          motivo: 'dependência não concluída: ' + pendentes.join(', '), info: ''
        };
        estados.push(item);
        estadoPorId[p.id] = item;
        bloqueado++;
        if (modo === 'linear') return fechar('bloqueado');
        continue;
      }
      if (typeof o.aoIniciar === 'function') await o.aoIniciar(p, indice);
      let res = null;
      try { res = await o.executar(p, indice); }
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
      estadoPorId[p.id] = item;
      if (estado === 'ok') {
        ok++;
        item.liberado = true;
        if (typeof o.aoConcluir === 'function') await o.aoConcluir(p, indice, res, item);
        continue;
      }
      if (estado === 'incerto') {
        incerto++;
        if (typeof o.aoIncertar === 'function') await o.aoIncertar(p, res, item, indice);
        const seguir = typeof o.confirmarIncerteza === 'function' ? !!(await o.confirmarIncerteza(p, res, item, indice)) : false;
        if (seguir) {
          item.liberado = true;
          if (typeof o.aoConcluir === 'function') await o.aoConcluir(p, indice, res, item);
          continue;
        }
        return fechar('pausado');
      }
      falhou++;
      if (typeof o.aoFalhar === 'function') await o.aoFalhar(p, res, item, indice);
      if (modo === 'linear') {
        return fechar(estado === 'cancelado' ? 'cancelado' : estado === 'bloqueado' ? 'bloqueado' : 'falhou');
      }
      // Em DAG, uma falha não impede ramos independentes; só os dependentes.
      bloquearDependentes(p.id);
    }
    if (falhou) return fechar('falhou');
    if (bloqueado) return fechar('bloqueado');
    return fechar('concluido');
  }

  return { MAX_PASSOS, extrairJson, normalizar, executar, resumo, descrever, vazio };
});
