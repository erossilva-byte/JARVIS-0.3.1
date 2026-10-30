/* J.A.R.V.I.S. Nova — agentes especializados e recibos de execução.
 *
 * Duas responsabilidades, sem DOM e sem rede:
 *  1. dizer a qual agente pertence cada ferramenta (dispositivo, arquivos, memória…);
 *  2. registrar o que foi pedido, o que o sistema devolveu e se o efeito foi
 *     realmente observado. Uma ação que apenas abriu um app ou preparou uma
 *     mensagem NÃO é tratada como concluída: fica como "incerto".
 *
 * O recibo guarda só o nome da ação e as CHAVES dos argumentos. Nada de texto de
 * mensagem, telefone, caminho ou conteúdo de memória é persistido aqui.
 */
(function (raiz, fabrica) {
  const api = fabrica();
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (raiz) raiz.AgentesJarvis = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  const VERSAO = 1;
  const LIMITE = 80;
  const CHAVE = 'recibos';
  let loja = null;
  let abertos = Object.create(null);
  let sequencia = 0;

  const AGENTES = {
    conversa: { id: 'conversa', nome: 'Conversa', dominio: 'hora, data, cálculos, explicações e respostas gerais' },
    pesquisa: { id: 'pesquisa', nome: 'Pesquisa', dominio: 'web, clima, notícias e links' },
    dispositivo: { id: 'dispositivo', nome: 'Dispositivo', dominio: 'apps, mídia, volume, brilho, alarmes, notificações, chamadas e mensagens' },
    arquivos: { id: 'arquivos', nome: 'Arquivos', dominio: 'leitura, criação e conferência de arquivos e projetos' },
    memoria: { id: 'memoria', nome: 'Memória', dominio: 'notas, cofre e contexto do usuário' },
    pessoas: { id: 'pessoas', nome: 'Pessoas', dominio: 'contatos, perfis e reconhecimento de locutor' },
    visao: { id: 'visao', nome: 'Visão', dominio: 'câmera, imagens e descrição de cena' },
    pc: { id: 'pc', nome: 'Computador', dominio: 'arquivos e comandos do PC conectado' },
    sistema: { id: 'sistema', nome: 'Sistema', dominio: 'atualização, diagnóstico, segurança e configuração' }
  };

  // A ordem importa: "abrir arquivo" é de Arquivos, não do Dispositivo.
  const REGRAS = [
    ['pesquisa', /(pesquis|clima|not[ií]cia|noticia|web|link|youtube|wikipedia|google)/],
    ['arquivos', /(arq_|arquivo|pasta|documento|pdf|docx|planilha|zip|projeto|cad_)/],
    ['memoria', /(mem[oó]ria|memoria|nota|obsidian|contexto)/],
    ['pessoas', /(pessoa|contato|locutor|identidade|voz_)/],
    ['visao', /(vis[aã]o|visao|c[aâ]mera|camera|imagem|foto|ocr)/],
    ['pc', /(^pc_|computador|desktop|servidor)/],
    ['sistema', /(atualiz|diagn[oó]stico|diagnostico|seguran[cç]a|seguranca|config|pin|backup|sincron)/],
    ['dispositivo', /(app|m[ií]dia|midia|volume|brilho|lanterna|alarme|lembrete|notifica|sms|ligar|chamada|whatsapp|email|agenda|tarefa|rotina|tela|wifi|bluetooth)/]
  ];

  function agora() { return Date.now(); }

  function agenteDe(nome) {
    const n = String(nome || '').toLowerCase();
    for (let i = 0; i < REGRAS.length; i++) {
      if (REGRAS[i][1].test(n)) return AGENTES[REGRAS[i][0]];
    }
    return AGENTES.conversa;
  }

  function configurar(opcoes) {
    const o = opcoes || {};
    if (o.store && typeof o.store.get === 'function' && typeof o.store.set === 'function') loja = o.store;
    return api;
  }

  function lerHistorico() {
    if (!loja) return [];
    try {
      const bruto = loja.get(CHAVE, '[]');
      const lista = JSON.parse(bruto);
      return Array.isArray(lista) ? lista : [];
    } catch (e) { return []; }
  }

  function gravar(lista) {
    if (!loja) return false;
    try { loja.set(CHAVE, JSON.stringify(lista.slice(0, LIMITE))); return true; }
    catch (e) { return false; }
  }

  /** Abre um recibo ANTES da ferramenta rodar. Guarda apenas as chaves dos argumentos. */
  function abrir(acao, args) {
    const agente = agenteDe(acao);
    const rec = {
      id: 'rc-' + agora().toString(36) + '-' + (++sequencia),
      acao: String(acao || 'desconhecida').slice(0, 60),
      agente: agente.id,
      inicio: agora(),
      estado: 'aberto',
      argumentos: Object.keys(args && typeof args === 'object' && !Array.isArray(args) ? args : {}).slice(0, 8)
    };
    abertos[rec.id] = rec;
    return rec;
  }

  /**
   * Classifica o retorno real da ferramenta. Só é "ok" quando o adaptador afirma
   * verificação (verificado/ok) ou quando o resultado é explicitamente confirmado.
   * Textos como "Solicitei a abertura" ou "preparei a mensagem" ficam "incerto".
   */
  function classificar(resultado) {
    if (resultado === null) return { estado: 'cancelado', motivo: 'cancelado antes de executar' };
    if (!resultado || typeof resultado !== 'object') {
      return { estado: 'incerto', motivo: 'a ferramenta não devolveu um recibo verificável' };
    }
    if (resultado.bloqueado === true) return { estado: 'bloqueado', motivo: 'bloqueado por segurança, modo offline ou permissão' };
    if (resultado.falhou === true || resultado.erro || resultado.ok === false) {
      return { estado: 'falhou', motivo: String(resultado.erro || resultado.info || resultado.fala || 'a ferramenta informou falha').slice(0, 180) };
    }
    // Texto de falha vence até uma marca otimista: "Não encontrei" ou "sem permissão"
    // não pode virar "ok" só porque o adaptador preencheu verificado: true.
    const texto = String(resultado.info || resultado.fala || resultado.mensagem || '');
    if (/n[ãa]o (?:foi poss[íi]vel|consegui|encontrei|reconheci|est[áa] dispon[íi]vel)|falh|erro|negad|indispon[íi]vel|sem permiss[ãa]o|precisa de internet/i.test(texto)) {
      return { estado: 'falhou', motivo: texto.slice(0, 180) };
    }
    if (resultado.verificado === true || resultado.ok === true || resultado.sucesso === true) {
      return { estado: 'ok', motivo: 'efeito confirmado pela ferramenta' };
    }
    if (resultado.incerto === true) {
      return { estado: 'incerto', motivo: 'a ferramenta sinalizou que o efeito não foi observado' };
    }
    // Ação disparada, efeito não observado: abrir app, preparar SMS, pedir confirmação.
    return {
      estado: 'incerto',
      motivo: texto ? 'ação disparada; efeito não confirmado: ' + texto.slice(0, 140) : 'ação disparada sem confirmação de efeito'
    };
  }

  /** Fecha o recibo. Devolve uma cópia; o objeto vivo não vaza para o chamador. */
  function fechar(recOuId, resultado, motivo) {
    const rec = (recOuId && typeof recOuId === 'object') ? recOuId : abertos[String(recOuId || '')];
    if (!rec || !rec.id) return null;
    delete abertos[rec.id];
    const c = classificar(resultado);
    rec.fim = agora();
    rec.duracaoMs = Math.max(0, rec.fim - rec.inicio);
    rec.estado = c.estado;
    rec.motivo = String(motivo || c.motivo || '').slice(0, 220);
    const texto = resultado && typeof resultado === 'object' ? (resultado.info || resultado.fala || '') : '';
    rec.resultado = String(texto || '').slice(0, 220);
    const hist = lerHistorico();
    hist.unshift(rec);
    rec.persistido = gravar(hist);
    return Object.assign({}, rec);
  }

  function cancelar(recOuId, motivo) {
    return fechar(recOuId, null, motivo || 'cancelado pelo usuário');
  }

  function resumo() {
    const lista = lerHistorico();
    const conta = { total: lista.length, ok: 0, incerto: 0, falhou: 0, bloqueado: 0, cancelado: 0 };
    lista.forEach((r) => { if (conta[r.estado] != null) conta[r.estado]++; });
    const executados = conta.total - conta.cancelado;
    return Object.assign(conta, {
      abertos: Object.keys(abertos).length,
      taxaVerificacao: executados > 0 ? Math.round((conta.ok / executados) * 100) : 0,
      ultimo: lista[0] ? { acao: lista[0].acao, agente: lista[0].agente, estado: lista[0].estado, fim: lista[0].fim } : null
    });
  }

  function historico(limite) {
    const n = Math.max(1, Math.min(LIMITE, Number(limite) || 10));
    return lerHistorico().slice(0, n).map((r) => Object.assign({}, r));
  }

  function limpar() {
    abertos = Object.create(null);
    gravar([]);
    return true;
  }

  const api = {
    VERSAO, LIMITE, CHAVE, agentes: AGENTES, configurar, agenteDe,
    abrir, classificar, fechar, cancelar, resumo, historico, limpar
  };
  return api;
});
