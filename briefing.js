/* J.A.R.V.I.S. Nova — Briefing e monitoramento (1.43.0)
 * Monta o resumo do dia, resume a sessão e compara monitoramentos sem inventar dados:
 * cada seção só aparece quando a fonte correspondente existe.
 */
(function (raiz) {
  'use strict';
  const B = {};

  function limpar(t) {
    return String(t == null ? '' : t).normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/\s+/g, ' ').trim();
  }

  B.saudacao = (hora) => {
    const h = Number(hora);
    if (!Number.isFinite(h)) return 'Olá';
    if (h < 5) return 'Boa madrugada';
    if (h < 12) return 'Bom dia';
    if (h < 18) return 'Boa tarde';
    return 'Boa noite';
  };

  /**
   * Briefing matinal. Só usa o que recebe; campos ausentes são omitidos em vez de inventados.
   * @param {{nome?:string,hora?:number,clima?:string,manchetes?:string[],tarefas?:string[],
   *          lembretes?:string[],memoria?:string[],eventos?:string[],foco?:string}} dados
   */
  B.montar = (dados) => {
    const d = dados || {};
    const partes = [];
    const titulo = B.saudacao(d.hora) + (d.nome ? ', ' + String(d.nome).split(' ')[0] : '') + '.';
    partes.push(titulo);
    if (d.foco) partes.push('Foco de hoje: ' + d.foco + '.');
    if (d.clima) partes.push('Tempo: ' + d.clima + '.');
    if (Array.isArray(d.eventos) && d.eventos.length) partes.push('Agenda: ' + d.eventos.slice(0, 5).join('; ') + '.');
    if (Array.isArray(d.tarefas) && d.tarefas.length) partes.push('Tarefas abertas: ' + d.tarefas.slice(0, 5).join('; ') + '.');
    if (Array.isArray(d.lembretes) && d.lembretes.length) partes.push('Lembretes: ' + d.lembretes.slice(0, 5).join('; ') + '.');
    if (Array.isArray(d.manchetes) && d.manchetes.length) partes.push('Manchetes: ' + d.manchetes.slice(0, 3).join(' | ') + '.');
    if (Array.isArray(d.memoria) && d.memoria.length) partes.push('Da memória: ' + d.memoria.slice(0, 3).join('; ') + '.');
    const secoes = [
      d.clima ? 'clima' : '', d.eventos && d.eventos.length ? 'agenda' : '',
      d.tarefas && d.tarefas.length ? 'tarefas' : '', d.manchetes && d.manchetes.length ? 'manchetes' : '',
      d.memoria && d.memoria.length ? 'memoria' : '',
    ].filter(Boolean);
    return { texto: partes.join(' '), secoes, faltando: B.fontesAusentes(d) };
  };

  B.fontesAusentes = (d) => {
    const faltando = [];
    if (!d || !d.clima) faltando.push('clima (cidade não configurada ou sem rede)');
    if (!d || !d.manchetes || !d.manchetes.length) faltando.push('manchetes (sem pesquisa nesta sessão)');
    if (!d || !d.tarefas || !d.tarefas.length) faltando.push('tarefas (nenhuma aberta)');
    return faltando;
  };

  /** Resumo de sessão a partir do histórico: pedidos do usuário, temas e pendências. */
  B.resumirSessao = (historico) => {
    const msgs = Array.isArray(historico) ? historico : [];
    const pedidos = msgs.filter((m) => m && m.role === 'user').map((m) => String(m.content || '').trim()).filter(Boolean);
    const respostas = msgs.filter((m) => m && m.role === 'assistant').length;
    const temas = [];
    const chaves = ['clima', 'tarefa', 'memoria', 'arquivo', 'cad', 'eletrica', 'codigo', 'pesquisa', 'alarme', 'lembrete', 'seguranca', 'visao'];
    pedidos.forEach((p) => {
      const n = limpar(p);
      chaves.forEach((k) => { if (n.includes(k) && !temas.includes(k)) temas.push(k); });
    });
    const pendencias = pedidos.filter((p) => /\b(?:depois|amanha|pendente|falta|nao terminei|continua)\b/.test(limpar(p)));
    return {
      pedidos: pedidos.length,
      respostas,
      temas,
      pendencias,
      texto: pedidos.length
        ? 'Nesta sessão você fez ' + pedidos.length + ' pedido(s) e eu respondi ' + respostas + ' vez(es).' +
          (temas.length ? ' Temas: ' + temas.join(', ') + '.' : '') +
          (pendencias.length ? ' Ficou pendente: ' + pendencias.slice(-2).join('; ') + '.' : '')
        : 'Ainda não há pedidos nesta sessão.',
    };
  };

  B.relatorioDia = (eventos) => {
    const lista = Array.isArray(eventos) ? eventos : [];
    const contagem = {};
    lista.forEach((e) => {
      const tipo = String((e && e.tipo) || 'outro').toLowerCase();
      contagem[tipo] = (contagem[tipo] || 0) + 1;
    });
    const tipos = Object.keys(contagem).sort((a, b) => contagem[b] - contagem[a]);
    return {
      total: lista.length,
      contagem,
      texto: lista.length
        ? 'Hoje registrei ' + lista.length + ' evento(s): ' + tipos.map((t) => t + ' (' + contagem[t] + ')').join(', ') + '.'
        : 'Nenhum evento registrado hoje.',
    };
  };

  /** Compara duas listas de itens monitorados e devolve o que é novo ou mudou. */
  B.compararMonitoramento = (anterior, atual) => {
    const norm = (v) => limpar(v).replace(/[^\w\s]/g, '').replace(/\s+/g, ' ');
    const antes = new Set((Array.isArray(anterior) ? anterior : []).map(norm).filter(Boolean));
    const agora = (Array.isArray(atual) ? atual : []).map((x) => ({ bruto: x, chave: norm(x) })).filter((x) => x.chave);
    const novos = agora.filter((x) => !antes.has(x.chave)).map((x) => x.bruto);
    const removidos = [...antes].filter((k) => !agora.some((x) => x.chave === k));
    return {
      novos,
      removidos,
      mudou: novos.length > 0 || removidos.length > 0,
      resumo: novos.length
        ? novos.length + ' novidade(s): ' + novos.slice(0, 5).join(' | ')
        : removidos.length ? removidos.length + ' item(ns) saíram da lista.' : 'Nada novo desde a última verificação.',
    };
  };

  /** Sugestão de rotina ao reconhecer a rede de casa; nunca executa nada sozinho. */
  B.sugestaoCasa = (ssid, casa) => {
    const a = limpar(ssid), b = limpar(casa);
    if (!a || !b) return null;
    if (a !== b) return null;
    return {
      rotina: 'chegada em casa',
      texto: 'Você chegou na rede de casa. Quer que eu ative o modo casa (luzes, música baixa e lembretes)?',
      confirmar: true,
    };
  };

  B.monitoramento = (nome, itens, quando) => ({
    nome: String(nome || '').trim(),
    itens: (Array.isArray(itens) ? itens : []).map(String),
    quando: quando || new Date().toISOString(),
  });

  raiz.BriefingJarvis = B;
  if (typeof module !== 'undefined' && module.exports) module.exports = B;
})(typeof window !== 'undefined' ? window : globalThis);
