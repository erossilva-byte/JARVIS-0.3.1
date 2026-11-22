/* J.A.R.V.I.S. Nova — consumo de tokens por provedor (Fase 3).
 *
 * A Fase 3 do prompt exige exibir "erros, limites, consumo e informações de conexão quando a
 * API fornecer". Erro e limite já aparecem; consumo não existia: o campo `usage` de cada
 * resposta era lido e jogado fora.
 *
 * Este módulo é só a conta, sem rede e sem tela, para poder ser testado de verdade:
 *  - `lerUso(usage)` aceita o formato OpenAI (`prompt_tokens`, `completion_tokens`,
 *    `total_tokens`) e o formato de entrada/saída (`input_tokens`, `output_tokens`);
 *  - devolve `null` quando o provedor não informa nada — quem chama deve dizer isso ao
 *    usuário, nunca inventar número;
 *  - `somar` devolve um estado novo (não altera o recebido), contando a chamada mesmo quando
 *    o consumo não veio;
 *  - `resumo`/`linhas` escrevem a frase em português, incluindo quantas chamadas ficaram sem
 *    consumo informado.
 */
(function (raiz) {
  'use strict';

  function inteiro(v) {
    var n = Number(v);
    if (!isFinite(n) || n < 0) return null;
    return Math.round(n);
  }

  /* Normaliza o bloco `usage` de uma resposta. Sem número legível, devolve null. */
  function lerUso(u) {
    if (!u || typeof u !== 'object') return null;
    var prompt = inteiro(u.prompt_tokens);
    if (prompt === null) prompt = inteiro(u.input_tokens);
    var completion = inteiro(u.completion_tokens);
    if (completion === null) completion = inteiro(u.output_tokens);
    var total = inteiro(u.total_tokens);
    if (total === null && (prompt !== null || completion !== null)) total = (prompt || 0) + (completion || 0);
    if (prompt === null && completion === null && total === null) return null;
    return { prompt: prompt, completion: completion, total: total };
  }

  function novo() {
    return { chamadas: 0, informados: 0, prompt: 0, completion: 0, total: 0 };
  }

  /* Soma uma chamada ao estado e devolve o estado novo. */
  function somar(estado, id, uso) {
    var base = (estado && typeof estado === 'object') ? estado : {};
    var copia = {};
    for (var k in base) if (Object.prototype.hasOwnProperty.call(base, k)) copia[k] = base[k];
    var antes = copia[id] || novo();
    var agora = {
      chamadas: antes.chamadas + 1,
      informados: antes.informados,
      prompt: antes.prompt,
      completion: antes.completion,
      total: antes.total
    };
    var u = lerUso(uso);
    if (u) {
      agora.informados = antes.informados + 1;
      agora.prompt = antes.prompt + (u.prompt || 0);
      agora.completion = antes.completion + (u.completion || 0);
      agora.total = antes.total + (u.total || 0);
    }
    copia[id] = agora;
    return copia;
  }

  function milhar(n) {
    return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  }

  /* Frase de um provedor. Nunca promete número que a API não mandou. */
  function resumo(estado, id, nome) {
    var c = estado && estado[id];
    var rotulo = nome || id;
    if (!c || !c.chamadas) return rotulo + ': nenhuma chamada registrada.';
    if (!c.informados) {
      return rotulo + ': ' + c.chamadas + ' chamada(s); o provedor não informou o consumo.';
    }
    var txt = rotulo + ': ' + c.chamadas + ' chamada(s), ' + milhar(c.total) + ' tokens informados';
    if (c.prompt || c.completion) {
      txt += ' (' + milhar(c.prompt) + ' de entrada, ' + milhar(c.completion) + ' de saída)';
    }
    if (c.informados < c.chamadas) {
      txt += '; ' + (c.chamadas - c.informados) + ' chamada(s) sem consumo informado';
    }
    return txt + '.';
  }

  /* Linhas para a tela: só os provedores que já foram chamados. */
  function linhas(estado, provedores) {
    var lista = provedores || [];
    var out = [];
    for (var i = 0; i < lista.length; i++) {
      var c = estado && estado[lista[i].id];
      if (c && c.chamadas) out.push(resumo(estado, lista[i].id, lista[i].nome));
    }
    if (!out.length) {
      return ['Nenhuma chamada de IA registrada ainda; o consumo aparece aqui quando houver.'];
    }
    return out;
  }

  /* Totais gerais, para o diagnóstico. */
  function total(estado) {
    var t = novo();
    var base = estado || {};
    for (var k in base) {
      if (!Object.prototype.hasOwnProperty.call(base, k)) continue;
      var c = base[k] || {};
      t.chamadas += c.chamadas || 0;
      t.informados += c.informados || 0;
      t.prompt += c.prompt || 0;
      t.completion += c.completion || 0;
      t.total += c.total || 0;
    }
    return t;
  }

  var api = { lerUso: lerUso, somar: somar, resumo: resumo, linhas: linhas, total: total, novo: novo };

  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (raiz) raiz.ConsumoIA = api;
})(typeof window !== 'undefined' ? window : null);
