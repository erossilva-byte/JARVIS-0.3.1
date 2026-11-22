/* J.A.R.V.I.S. Nova — camada cognitiva determinística (1.39.0).
 *
 * Não chama rede, não toca no DOM e não executa ferramentas. Ela organiza o
 * turno antes da IA e verifica a saída depois: intenção, complexidade, riscos,
 * referências, necessidade de pesquisa/cálculo/ferramenta, plano interno,
 * seleção de histórico e revisão de abertura/repetição.
 *
 * A decisão final continua no Hermes/SISTEMA. Esta camada nunca autoriza uma
 * ação sensível nem inventa um resultado de ferramenta.
 */
(function (raiz, fabrica) {
  var api = fabrica();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.JarvisCognicao = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  var VERSAO = '1.0.0';
  var SERIO = /(emerg[eê]ncia|socorro|acidente|infarto|avc|dor no peito|sangr|suic[ií]d|morreu|morte|luto|fal[eê]c|estupro|ass[eé]dio|viol[eê]ncia|amea[cç]a|golpe|fraude|perdi (o|meu) (dinheiro|emprego)|demitid|c[aâ]ncer|diagn[oó]stico|hospital|medicamento|ansiedade|depress)/i;
  var PRESSA = /(agora|rapido|r[aá]pido|urgente|correndo|sem tempo|depressa|ja|j[aá]|pra ontem|hoje mesmo)/i;
  var PESQUISA = /(pesquis|not[ií]cia|manchete|cota[cç][aã]o|pre[cç]o|lan[cç]amento|placar|resultado de hoje|quem ganhou|clima|temperatura|previs[aã]o|o que aconteceu|atual|recente|fonte|link)/i;
  var CALCULO = /(\d+\s*[+\-×x*/÷]\s*\d+|calcule|quanto (e|é|vale)|porcentagem|m[eé]dia|soma|desconto|juros)/i;
  var FERRAMENTA = /(arquivo|pdf|docx|xlsx|csv|json|xml|cad|git|github|compil|teste|analise|corrija|abra|abrir|execute|rodar|liga|ligue|mensagem|alarme|lembrete|agenda|site|pesquise|baixe|instale|crie|gere|exporte)/i;
  var REFERENCIA = /(aquele|aquela|aquilo|isso|isto|ele|ela|mesmo|anterior|ontem|de onde paramos|continue|continuar|o que fizemos|aquele projeto|aquela fun[cç][aã]o|o mesmo)/i;
  var INFORMAL = /(vc|voce|pra|pro|tipo|mano|cara|bagulho|m[oó]|pq|q |tbm|vlw|blz|n[aã]o sei|sei la|sla)/i;
  var CORRECAO = /^(nao|n[aã]o|errado|corrig|na verdade|isso esta errado|nao e isso|n[aã]o é isso)/i;
  var SAUDACAO = /^(bom dia|boa tarde|boa noite|ola|ol[aá]|oi|e ai|e a[ií]|tudo bem)/i;
  var TAREFA = /^(faz|fa[cç]a|crie|cria|gere|abra|abrir|execute|rode|analise|corrija|organize|monte|planeje|pesquise|procure|compare|explique|resuma|instale|baixe|envie|prepare|verifique)/i;
  var PARADAS = ('a o as os um uma de da do das dos e ou para por com sem em no na nos nas ao aos se ' +
    'que como qual quais quem quando onde porque por que meu minha seu sua isso isto aquilo aquele aquela ' +
    'ja ja mais muito pouco sobre entre depois antes').split(' ');

  function normalizar(t) {
    t = String(t == null ? '' : t);
    try { t = t.normalize('NFD').replace(/[\u0300-\u036f]/g, ''); } catch (e) { /* motor antigo */ }
    return t.toLowerCase().replace(/[^a-z0-9\s]/g, ' ').replace(/\s+/g, ' ').trim();
  }

  function termos(t) {
    return normalizar(t).split(' ').filter(function (p) {
      return p.length > 2 && PARADAS.indexOf(p) < 0;
    }).slice(0, 16);
  }

  function bool(v) { return v === true || v === '1' || v === 1; }

  function opcao(v, validos, padrao) {
    v = String(v == null ? '' : v).toLowerCase();
    return validos.indexOf(v) >= 0 ? v : padrao;
  }

  /** Analisa um turno. `opcoes` aceita serio, pressa, temContexto, profundidade,
   * iniciativa e conversa. O resultado é imutável para o chamador. */
  function analisar(texto, opcoes) {
    var o = opcoes || {};
    var original = String(texto == null ? '' : texto).trim();
    var n = normalizar(original);
    var palavras = n ? n.split(' ') : [];
    var t = n;
    var serio = bool(o.serio) || SERIO.test(t);
    var pressa = bool(o.pressa) || PRESSA.test(t);
    var pergunta = /\?$/.test(original) || /^(o que|quem|qual|quais|quando|onde|como|por que|porque|quanto|voce|vc)/.test(t);
    var correcao = CORRECAO.test(t);
    var saudacao = SAUDACAO.test(t);
    var tarefa = TAREFA.test(t) || /(preciso que|quero que|me ajude a|pode (fazer|analisar|corrigir|organizar|pesquisar))/.test(t);
    var intencao = correcao ? 'correcao' : saudacao ? 'saudacao' : tarefa ? 'tarefa' : pergunta ? 'pergunta' : 'conversa';
    var complexidade = 1;
    if (original.length > 90 || palavras.length > 16 || /(e depois|alem disso|tambem|passo a passo|compare|analise|explique|implemente|corrija|organize)/.test(t)) complexidade = 2;
    if (original.length > 220 || (t.match(/\b(e|depois|entao|porque|mas|porem|enquanto)\b/g) || []).length >= 3 || /(analise|compare|implemente|corrija).*(e|depois).*(teste|valide|explique)/.test(t)) complexidade = 3;
    var precisaPesquisa = PESQUISA.test(t);
    var precisaCalculo = CALCULO.test(t);
    var precisaFerramenta = FERRAMENTA.test(t) || (tarefa && /(arquivo|app|celular|computador|documento|planilha|nota|musica|volume|lanterna|alarme|lembrete)/.test(t));
    var referencia = REFERENCIA.test(t);
    var informal = INFORMAL.test(t);
    var ambiguidade = palavras.length <= 4 && (referencia || /^(faz|resolve|continua|manda|abre|explica|ajuda)$/.test(t)) && !bool(o.temContexto);
    var profundidade = opcao(o.profundidade, ['curta', 'equilibrada', 'detalhada'], complexidade >= 3 ? 'detalhada' : 'equilibrada');
    var iniciativa = opcao(o.iniciativa, ['baixa', 'normal', 'alta'], 'normal');
    var conversa = opcao(o.conversa, ['natural', 'objetiva'], 'natural');
    var passos = [
      { id: 'compreender', rotulo: 'Compreender pedido, referências e risco', estado: 'pendente' },
      { id: 'contexto', rotulo: 'Reunir apenas o contexto e as memórias relevantes', estado: 'pendente' },
      { id: 'decidir', rotulo: 'Decidir entre resposta direta, cálculo, pesquisa ou ferramenta', estado: 'pendente' },
      { id: 'responder', rotulo: 'Responder com a profundidade e o tom configurados', estado: 'pendente' },
      { id: 'verificar', rotulo: 'Verificar clareza, repetição, limites e resultado', estado: 'pendente' }
    ];
    var confianca = 0.55;
    if (palavras.length >= 5) confianca += 0.15;
    if (!ambiguidade) confianca += 0.15;
    if (!serio) confianca += 0.05;
    if (complexidade >= 2) confianca -= 0.05;
    confianca = Math.max(0, Math.min(0.95, confianca));
    return {
      versao: VERSAO, texto: original, normalizado: n, termos: termos(original),
      intencao: intencao, complexidade: complexidade, serio: serio, pressa: pressa,
      pergunta: pergunta, informal: informal, referencia: referencia, ambiguidade: ambiguidade,
      precisaPesquisa: precisaPesquisa, precisaCalculo: precisaCalculo,
      precisaFerramenta: precisaFerramenta, confianca: confianca,
      profundidade: profundidade, iniciativa: iniciativa, conversa: conversa,
      plano: passos,
      resumo: intencao + ' · complexidade ' + complexidade + (serio ? ' · sensível' : '') +
        (pressa ? ' · pressa' : '') + (precisaPesquisa ? ' · pesquisa' : '') +
        (precisaFerramenta ? ' · ferramenta' : '')
    };
  }

  /** Instruções internas derivadas do plano. O modelo não deve mostrar o plano. */
  function promptPlano(a, opcoes) {
    if (!a) return '';
    var o = opcoes || {};
    var compacto = bool(o.compacto);
    var linhas = a.plano.map(function (p, i) { return (i + 1) + '. ' + p.rotulo + '.'; });
    if (compacto) {
      return 'PLANO INTERNO (não mostre): ' + (a.serio ? 'assunto sensível, humor zero e empatia primeiro. ' : '') +
        'compreenda o pedido' + (a.referencia ? ', retome a referência da conversa' : '') +
        (a.precisaPesquisa ? ', confirme informação atual com pesquisa' : '') +
        (a.precisaCalculo ? ', calcule e confira' : '') +
        (a.precisaFerramenta ? ', use somente ferramenta disponível e não finja execução' : ', responda diretamente') +
        '; entregue o resultado e verifique antes de concluir.';
    }
    return 'PLANO COGNITIVO INTERNO — execute mentalmente, não o exiba: ' + linhas.join(' ') +
      ' Complexidade ' + a.complexidade + '/3; profundidade ' + a.profundidade + '; iniciativa ' + a.iniciativa + '. ' +
      (a.serio ? 'Assunto sensível: humor zero, empatia e clareza primeiro. ' : '') +
      (a.pressa ? 'Pressa: resposta curta, sem preâmbulo. ' : '') +
      (a.ambiguidade ? 'Há ambiguidade real: faça no máximo uma pergunta curta e específica. ' : 'Evite perguntar o que o contexto já responde. ') +
      (a.referencia ? 'Resolva pronomes e referências usando o histórico e a memória; não peça novamente o que já foi dito. ' : '') +
      (a.precisaPesquisa ? 'Informação atual: use a ferramenta de pesquisa e separe confirmado de incerto. ' : '') +
      (a.precisaCalculo ? 'Cálculo: mostre a conta ou confira o resultado antes de responder. ' : '') +
      (a.precisaFerramenta ? 'Ferramenta: escolha somente uma ação disponível; se não puder executar, diga o limite. ' : '') +
      'Ao terminar, verifique se a resposta entrega o pedido, não repete a abertura padrão e não inventa resultado.';
  }

  /** Seleciona histórico curto, priorizando sobreposição de termos e referências.
   * A ordem devolvida é sempre a cronológica: um turno antigo trazido por relevância entra
   * no lugar dele, nunca depois do turno atual — o modelo recebe a conversa na sequência em
   * que ela aconteceu e a pergunta de agora continua sendo a última mensagem. */
  function selecionarHistorico(hist, a, limite) {
    var lista = (Array.isArray(hist) ? hist : []).filter(function (x) {
      return x && (x.role === 'user' || x.role === 'assistant') && typeof x.content === 'string' && x.content;
    });
    var max = Math.max(2, Math.min(16, Number(limite) || 8));
    if (!lista.length) return [];
    var teto = max + 4;
    var inicio = Math.max(0, lista.length - (a && a.referencia ? Math.min(16, teto) : max));
    var escolhidos = {}, marcados = {};
    for (var k = inicio; k < lista.length; k++) escolhidos[k] = true;
    if (a && a.termos && a.termos.length) {
      var relevantes = [];
      for (var i = 0; i < lista.length; i++) {
        if (escolhidos[i]) continue;
        var c = normalizar(lista[i].content);
        var pontos = 0;
        a.termos.forEach(function (termo) { if (c.indexOf(termo) >= 0) pontos++; });
        if (pontos >= 2) relevantes.push({ i: i, pontos: pontos });
      }
      relevantes.sort(function (x, y) { return y.pontos - x.pontos; });
      relevantes.slice(0, 4).forEach(function (r) { escolhidos[r.i] = true; marcados[r.i] = true; });
    }
    // O excedente sai do começo da conversa; o turno atual (sempre o último) e os turnos
    // trazidos por relevância ficam, porque são eles que explicam a referência em uso.
    var indices = Object.keys(escolhidos).map(Number).sort(function (x, y) { return x - y; });
    while (indices.length > teto) {
      var cortado = false;
      for (var j = 0; j < indices.length - 1; j++) {
        if (!marcados[indices[j]]) { delete escolhidos[indices[j]]; indices.splice(j, 1); cortado = true; break; }
      }
      if (!cortado) { delete escolhidos[indices[0]]; indices.shift(); }
    }
    return Object.keys(escolhidos).map(Number).sort(function (x, y) { return x - y; })
      .map(function (i) { return lista[i]; });
  }

  /** Fala de um turno já guardado: o histórico salva o JSON inteiro do modelo.
   * Serve para comparar repetição e para ler o que foi dito, sem o envelope da ação. */
  function falaDoTurno(conteudo) {
    var bruto = String(conteudo == null ? '' : conteudo).trim();
    if (!bruto) return '';
    if (bruto.charAt(0) === '{') {
      try {
        var o = JSON.parse(bruto);
        if (o && typeof o.fala === 'string' && o.fala.trim()) return o.fala.trim();
      } catch (e) { /* texto puro */ }
    }
    return bruto;
  }

  /** Verificação conservadora da fala. Não julga fatos; aponta falhas observáveis. */
  function verificarResposta(fala, a, opcoes) {
    var o = opcoes || {};
    var f = String(fala == null ? '' : fala).trim();
    var problemas = [];
    if (!f) problemas.push('vazia');
    if (/^(claro|com certeza|entendido|sem problemas|como posso ajudar|ol[aá]|oi)[!.,;? ]*$/i.test(f)) problemas.push('abertura_generica');
    if (/^(claro|com certeza|entendido)[!.,; ]+/i.test(f) && f.length < 180) problemas.push('abertura_generica');
    if (a && a.serio && /(haha|hahaha|rsrs|piada|brincadeira|zoeira|deboche)/i.test(f)) problemas.push('humor_em_assunto_sensivel');
    if (a && a.complexidade >= 3 && f.length < 20) problemas.push('curta_demais');
    if (a && a.precisaFerramenta && !o.acao && /(ja abri|j[aá] abri|executei|acabei de|liguei|enviei|instalei|baixei|criei o arquivo)/i.test(f)) problemas.push('alegacao_sem_execucao');
    if (o.recentes && f) {
      var nf = normalizar(f);
      // O histórico guarda o turno inteiro do modelo (JSON com fala e ação); a comparação é
      // feita com a fala de cada turno, senão nenhuma repetição seria reconhecida.
      if (o.recentes.some(function (r) { return normalizar(falaDoTurno(r)) === nf; })) problemas.push('repetida');
    }
    return {
      ok: problemas.length === 0, problemas: problemas,
      correcao: problemas.length ? 'Revise a fala: entregue conteúdo direto, sem abertura neutra, sem alegar ação não executada e sem repetir a resposta anterior.' : ''
    };
  }

  /** Revisão determinística e segura: remove muletas e espaços, preserva conteúdo. */
  function revisarFala(fala, a, problemas) {
    var f = String(fala == null ? '' : fala).replace(/\s+/g, ' ').trim();
    var ps = Array.isArray(problemas) ? problemas : [];
    if (ps.indexOf('vazia') >= 0) return 'Não consegui formular uma resposta útil agora. Pode reformular o pedido?';
    if (ps.indexOf('abertura_generica') >= 0) {
      f = f.replace(/^(claro|com certeza|entendido|sem problemas|como posso ajudar)[!.,;:\s-]+/i, '');
      f = f.charAt(0).toUpperCase() + f.slice(1);
    }
    if (a && a.serio) f = f.replace(/\s*(haha|hahaha|rsrs)\s*/gi, ' ').replace(/\s+/g, ' ').trim();
    return f;
  }

  function diagnostico() {
    return { versao: VERSAO, funcoes: ['analisar', 'promptPlano', 'selecionarHistorico', 'falaDoTurno', 'verificarResposta', 'revisarFala'], rede: false, dom: false };
  }

  return {
    VERSAO: VERSAO, normalizar: normalizar, termos: termos, analisar: analisar,
    promptPlano: promptPlano, selecionarHistorico: selecionarHistorico,
    falaDoTurno: falaDoTurno,
    verificarResposta: verificarResposta, revisarFala: revisarFala, diagnostico: diagnostico
  };
});
