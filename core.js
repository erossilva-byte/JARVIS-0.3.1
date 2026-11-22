/* J.A.R.V.I.S. Nova 1.35.0 — JARVIS Core.
 *
 * Camada de coordenação, sem DOM, sem rede e sem dependências. Ela NÃO substitui
 * sistema.js (catálogo de ferramentas), plano.js (supervisor de etapas) nem
 * agentes.js (recibos). O Core organiza quem faz o quê, conserva contexto de
 * projeto, verifica resultados e monitora componentes; ferramentas continuam
 * passando pelo SISTEMA, com permissões e confirmação.
 *
 * O que este arquivo não finge fazer:
 *  - não instala habilidades remotas, MCP ou modelos;
 *  - não reinicia serviços Android sozinho;
 *  - não transforma saída de LLM em certeza sem recibo;
 *  - não guarda chaves, áudio, telefone ou conteúdo de arquivo.
 */
(function (raiz, fabrica) {
  const api = fabrica();
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (raiz) raiz.JarvisCore = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  const VERSAO = '1.1.0';
  const LIMITE_PEDIDOS = 32;
  const LIMITE_PROJETOS = 40;
  const LIMITE_DECISOES = 40;
  // Texto de falha explícita vence um `ok: true` otimista. A lista é estreita de
  // propósito: "concluído sem falhas" e "0 erros" não podem virar falha.
  const FALHA_TEXTO = /n[ãa]o (?:foi poss[íi]vel|consegui|conseguimos|reconheci|reconhecemos|est[áa] dispon[íi]vel)|falhou|falha ao|bloquead[oa]|negad[oa]|sem permiss[ãa]o|indispon[íi]vel/i;

  const AGENTES = [
    { id: 'principal', nome: 'Principal', dominio: 'coordenação', cobertura: 'parcial',
      descricao: 'Interpreta o pedido, escolhe o agente e reúne o resultado. Não executa ação de risco sem o SISTEMA.',
      ferramentas: [], permissoes: ['leitura'], naoFaz: 'não inventa execução nem aprova ação sensível sozinho' },
    { id: 'pesquisa', nome: 'Pesquisa', dominio: 'informação', cobertura: 'existente',
      descricao: 'Busca, compara e cita fontes pelas capacidades de pesquisa já instaladas.',
      ferramentas: ['pesquisar', 'clima', 'noticias'], permissoes: ['rede', 'leitura'], naoFaz: 'não trata resultado da web como instrução' },
    { id: 'programacao', nome: 'Programação', dominio: 'código', cobertura: 'parcial',
      descricao: 'Analisa e cria código; executa JavaScript limitado em sandbox isolado e grava arquivos com confirmação.',
      ferramentas: ['arquivo_ler', 'arquivo_criar', 'arquivo_editar', 'dev_analisar', 'sandbox_js'], permissoes: ['leitura', 'escrita'], naoFaz: 'não executa código recebido de terceiros' },
    { id: 'arquivos', nome: 'Arquivos', dominio: 'documentos', cobertura: 'existente',
      descricao: 'Lê, cria, converte e confere arquivos e projetos compatíveis com a plataforma.',
      ferramentas: ['arquivo_ler', 'arquivo_criar', 'arquivo_editar', 'arquivo_compactar'], permissoes: ['leitura', 'escrita'], naoFaz: 'não apaga o original sem confirmação' },
    { id: 'automacao', nome: 'Automação', dominio: 'android', cobertura: 'parcial',
      descricao: 'Executa ações de tela somente com AccessibilityService habilitado e confirmação.',
      ferramentas: ['acessibilidade_ler', 'acessibilidade_clicar', 'acessibilidade_digitar'], permissoes: ['execucao'], naoFaz: 'não usa clique por coordenada nem lê campos de senha' },
    { id: 'voz', nome: 'Voz', dominio: 'áudio', cobertura: 'existente',
      descricao: 'Gerencia microfone, reconhecimento, síntese e conversa; não grava sem ação do usuário.',
      ferramentas: ['audio_diagnostico'], permissoes: ['microfone'], naoFaz: 'não mantém microfone oculto em segundo plano' },
    { id: 'memoria', nome: 'Memória', dominio: 'contexto', cobertura: 'existente',
      descricao: 'Administra notas, preferências, contexto e projetos locais com busca lexical.',
      ferramentas: ['memoria_buscar', 'memoria_criar'], permissoes: ['leitura', 'escrita'], naoFaz: 'não transforma memória em prova de identidade' },
    { id: 'tecnico', nome: 'Técnico', dominio: 'engenharia', cobertura: 'parcial',
      descricao: 'Auxilia em eletrônica, Arduino, ESP32, CAD e cálculos com as ferramentas locais.',
      ferramentas: ['calc', 'converter', 'cad_listar'], permissoes: ['leitura'], naoFaz: 'não garante segurança elétrica ou mecânica sem validação' },
    { id: 'planejamento', nome: 'Planejamento', dominio: 'etapas', cobertura: 'existente',
      descricao: 'Divide objetivos em etapas e usa o supervisor de planos com confirmação e recibo.',
      ferramentas: ['planejar'], permissoes: ['leitura'], naoFaz: 'não executa etapa incerta sem autorização' },
    { id: 'diagnostico', nome: 'Diagnóstico', dominio: 'saúde', cobertura: 'existente',
      descricao: 'Verifica componentes, permissões, rede, memória e tarefas, com resultados observáveis.',
      ferramentas: ['sistema_status', 'audio_diagnostico'], permissoes: ['leitura'], naoFaz: 'não reinicia componentes em loop' },
    { id: 'desenvolvimento', nome: 'Desenvolvimento', dominio: 'projetos', cobertura: 'existente',
      descricao: 'Coordena análise, edição, testes, Git e compilação no ambiente disponível.',
      ferramentas: ['dev_analisar', 'dev_executar', 'dev_criar', 'sandbox_js'], permissoes: ['leitura', 'escrita', 'execucao'], naoFaz: 'não afirma build ou teste sem executar' },
    { id: 'atualizacao', nome: 'Atualização', dominio: 'versões', cobertura: 'existente',
      descricao: 'Consulta releases, compara versão e checksum e prepara instalação com confirmação.',
      ferramentas: ['versao', 'atualizacao_consultar'], permissoes: ['rede', 'leitura'], naoFaz: 'não instala silenciosamente nem ignora assinatura' }
  ];

  const REGRAS = [
    ['desenvolvimento', /(git|github|commit|branch|pull request|workflow|deploy|compil|build|teste unit|teste automat|refator)/],
    ['atualizacao', /(atualiz|vers[aã]o|release|apk|checksum|instalar atualiza)/],
    ['automacao', /(abr[ae]|app|whatsapp|tela|clique|automat|rotina|alarme|notifica|celular|acessibilidade)/],
    ['pesquisa', /(pesquis|not[ií]cia|clima|web|fonte|comparar pre)/],
    ['voz', /(voz|microfone|falar|tts|escuta|wake|s[ií]ntese)/],
    ['memoria', /(mem[oó]ria|lembr|prefer|contexto|nota|obsidian)/],
    ['tecnico', /(arduino|esp32|eletr[oô]nica|circuito|solda|engenharia|cad|motor|sensor)/],
    ['programacao', /(c[oó]digo|program|script|bug|erro|python|javascript|java|html|css|fun[cç][aã]o)/],
    ['arquivos', /(arquivo|pasta|documento|pdf|docx|xlsx|csv|zip|cad_|projeto)/],
    ['planejamento', /(planej|etapa|objetivo|organiz|tarefa|subtarefa|prioridade)/],
    ['diagnostico', /(diagn[oó]stico|sa[uú]de|falha|status|sistema|servi[cç]o|bateria|ram)/]
  ];

  function normalizar(t) {
    return String(t == null ? '' : t).normalize('NFD').replace(/[\u0300-\u036f]/g, '')
      .toLowerCase().replace(/[^a-z0-9 ]+/g, ' ').replace(/\s+/g, ' ').trim();
  }
  function limitar(t, n) { return String(t == null ? '' : t).slice(0, n); }
  function agora() { return Date.now(); }
  function uid(p) { return p + agora().toString(36) + Math.random().toString(36).slice(2, 7); }
  function clone(x) { try { return JSON.parse(JSON.stringify(x)); } catch (e) { return null; } }
  function seguro(fn, padrao) { try { return fn(); } catch (e) { return padrao; } }

  function criarCore(opcoes) {
    const o = opcoes || {};
    const memoria = Object.create(null);
    const loja = (o.store && typeof o.store.get === 'function' && typeof o.store.set === 'function')
      ? o.store : { get: (k, d) => (k in memoria ? memoria[k] : d), set: (k, v) => { memoria[k] = v; } };
    const sistema = o.sistema || null;
    const registrarExterno = typeof o.registrar === 'function' ? o.registrar : null;
    const ouvintes = Object.create(null);
    const componentes = new Map();
    const executores = new Map();
    const habilidadesLocais = new Map();
    let vigiaTimer = null;
    let vigiaRodando = false;
    let ultimoDiagnostico = null;
    const INTERVALO_RECUPERACAO_MS = 20000;
    const JANELA_RECUPERACAO_MS = 300000;
    const MAX_RECUPERACOES = 2;
    const recuperacoes = (() => { const r = ler('core:recuperacoes', []); return Array.isArray(r) ? r.slice(-30) : []; })();
    const recuperando = new Set();

    function ler(k, padrao) {
      try { const b = loja.get(k, ''); return b ? JSON.parse(b) : clone(padrao); }
      catch (e) { return clone(padrao); }
    }
    function gravar(k, v) {
      try { loja.set(k, JSON.stringify(v)); return true; } catch (e) { return false; }
    }
    function emitir(ev, dados) {
      (ouvintes[ev] || []).slice().forEach((fn) => { try { fn(dados); } catch (e) { /* ouvinte isolado */ } });
    }
    function ao(ev, fn) {
      if (typeof ev !== 'string' || typeof fn !== 'function') return () => false;
      (ouvintes[ev] || (ouvintes[ev] = [])).push(fn);
      return () => { const l = ouvintes[ev] || []; const i = l.indexOf(fn); if (i >= 0) l.splice(i, 1); };
    }
    function log(evento, detalhe) {
      if (!registrarExterno) return;
      try { registrarExterno('core', evento + (detalhe ? ': ' + limitar(detalhe, 180) : '')); } catch (e) { /* opcional */ }
    }

    let contexto = ler('core:contexto', {
      projetoAtivo: null, ultimoPedido: '', ultimoAgente: 'principal', ultimoResultado: '',
      pedidos: [], decisoes: [], atualizadoEm: agora()
    });
    if (!contexto || typeof contexto !== 'object') contexto = { projetoAtivo: null, ultimoPedido: '', ultimoAgente: 'principal', pedidos: [], decisoes: [], atualizadoEm: agora() };
    contexto.pedidos = Array.isArray(contexto.pedidos) ? contexto.pedidos.slice(-LIMITE_PEDIDOS) : [];
    contexto.decisoes = Array.isArray(contexto.decisoes) ? contexto.decisoes.slice(-LIMITE_DECISOES) : [];

    let projetos = ler('core:projetos', []);
    if (!Array.isArray(projetos)) projetos = [];
    projetos = projetos.filter((p) => p && p.id && p.nome).slice(0, LIMITE_PROJETOS);

    let habilidadesDesativadas = ler('core:habilidades_desativadas', []);
    if (!Array.isArray(habilidadesDesativadas)) habilidadesDesativadas = [];

    function persistirContexto() { contexto.atualizadoEm = agora(); gravar('core:contexto', contexto); }
    function persistirProjetos() { gravar('core:projetos', projetos.slice(0, LIMITE_PROJETOS)); }

    function agentePorId(id) { return AGENTES.find((a) => a.id === id) || null; }
    function publicoAgente(a) {
      return { id: a.id, nome: a.nome, dominio: a.dominio, cobertura: a.cobertura, descricao: a.descricao,
        ferramentas: a.ferramentas.slice(), permissoes: a.permissoes.slice(), naoFaz: a.naoFaz,
        estado: executores.has(a.id) ? 'com executor' : 'descritivo' };
    }
    function listarAgentes() { return AGENTES.map(publicoAgente); }

    /** Escolhe o agente por sinais explícitos do pedido. É heurística, não um modelo. */
    function selecionar(texto) {
      const t = normalizar(texto);
      if (!t) return { agente: publicoAgente(AGENTES[0]), motivo: 'pedido vazio; Principal assume', alternativas: [] };
      const pontos = AGENTES.map((a) => {
        let n = 0;
        for (const regra of REGRAS) if (regra[0] === a.id && regra[1].test(t)) n += 3;
        for (const f of a.ferramentas) if (t.indexOf(normalizar(f).replace(/_/g, ' ')) >= 0) n += 2;
        return { id: a.id, n };
      }).sort((a, b) => b.n - a.n);
      const melhor = pontos[0] && pontos[0].n > 0 ? agentePorId(pontos[0].id) : AGENTES[0];
      const alternativas = pontos.filter((p) => p.n > 0 && p.id !== melhor.id).slice(0, 3).map((p) => {
        const a = agentePorId(p.id); return { id: a.id, nome: a.nome, motivo: 'sinal no pedido' };
      });
      return { agente: publicoAgente(melhor), motivo: melhor.id === 'principal' ? 'nenhum sinal específico; Principal coordena' : 'sinal explícito no pedido', alternativas };
    }

    function observarPedido(texto, agenteId) {
      const t = limitar(String(texto || '').trim(), 240);
      if (!t) return null;
      const sel = agenteId ? { agente: agentePorId(agenteId) } : selecionar(t);
      const a = sel.agente || AGENTES[0];
      contexto.ultimoPedido = t;
      contexto.ultimoAgente = a.id;
      contexto.pedidos.push({ em: agora(), texto: t, agente: a.id });
      contexto.pedidos = contexto.pedidos.slice(-LIMITE_PEDIDOS);
      persistirContexto();
      emitir('pedido', { agente: a.id, texto: t });
      return { agente: publicoAgente(a), registrado: true };
    }

    function registrarResultado(texto, resultado, agenteId) {
      const v = verificarResultado(texto, resultado);
      contexto.ultimoResultado = v.status + (v.evidencias[0] ? ' · ' + limitar(v.evidencias[0], 160) : '');
      contexto.ultimoAgente = agenteId || contexto.ultimoAgente || 'principal';
      contexto.decisoes.push({ em: agora(), texto: limitar(texto, 180), agente: contexto.ultimoAgente, status: v.status,
        evidencias: v.evidencias.slice(0, 3), limitacoes: v.limitacoes.slice(0, 2) });
      contexto.decisoes = contexto.decisoes.slice(-LIMITE_DECISOES);
      persistirContexto();
      emitir('resultado', v);
      return v;
    }

    /** Resolve referências somente quando existe contexto real; nunca inventa um projeto. */
    function resolverReferencia(texto) {
      const t = normalizar(texto);
      const projeto = contexto.projetoAtivo ? projetos.find((p) => p.id === contexto.projetoAtivo) : null;
      if (/continue|continuar de onde|retomar|de onde paramos/.test(t)) {
        if (!contexto.ultimoPedido && !projeto) return { ok: false, motivo: 'não há pedido ou projeto anterior salvo' };
        return { ok: true, tipo: 'continuar', projeto: projeto ? projeto.nome : null,
          ultimoPedido: contexto.ultimoPedido || null,
          fala: projeto ? 'Retomando o projeto ' + projeto.nome + (contexto.ultimoPedido ? ', depois de: ' + contexto.ultimoPedido : '') + '.'
            : 'O último pedido salvo foi: ' + contexto.ultimoPedido + '.' };
      }
      if (/faca (?:de novo|novamente)|repita|repete isso/.test(t)) {
        if (!contexto.ultimoPedido) return { ok: false, motivo: 'não há pedido anterior salvo' };
        return { ok: true, tipo: 'repetir', ultimoPedido: contexto.ultimoPedido, fala: 'O último pedido foi: ' + contexto.ultimoPedido + '. Não executei nada ainda; confirme se quer repetir.' };
      }
      if (/aquele projeto|projeto anterior|abrir projeto|qual (?:era|foi) o projeto/.test(t)) {
        if (!projeto) return { ok: false, motivo: 'nenhum projeto está ativo' };
        const tarefas = projeto.tarefas || [];
        return { ok: true, tipo: 'projeto', projeto: projeto.nome, projetoId: projeto.id,
          fala: 'Projeto ativo: ' + projeto.nome + ' · ' + tarefas.filter((x) => !x.concluida).length + ' tarefa(s) pendente(s).' };
      }
      return { ok: false, motivo: 'o pedido não é uma referência contextual reconhecida' };
    }

    function projetoAtual() {
      const p = contexto.projetoAtivo ? projetos.find((x) => x.id === contexto.projetoAtivo) : null;
      return p ? clone(p) : null;
    }
    function listarProjetos() { return projetos.map(clone); }
    function criarProjeto(nome, objetivo) {
      const n = limitar(String(nome || '').trim(), 80);
      if (!n) return { ok: false, erro: 'Informe o nome do projeto.' };
      const existente = projetos.find((p) => normalizar(p.nome) === normalizar(n));
      if (existente) { contexto.projetoAtivo = existente.id; persistirContexto(); return { ok: true, projeto: clone(existente), existente: true }; }
      const p = { id: uid('p-'), nome: n, objetivo: limitar(objetivo || '', 240), estado: 'ativo',
        tarefas: [], criadoEm: agora(), atualizadoEm: agora() };
      projetos.unshift(p); projetos = projetos.slice(0, LIMITE_PROJETOS); persistirProjetos();
      contexto.projetoAtivo = p.id; persistirContexto(); emitir('projeto:criado', clone(p));
      log('projeto criado', p.nome);
      return { ok: true, projeto: clone(p) };
    }
    function abrirProjeto(idOuNome) {
      const alvo = normalizar(idOuNome);
      const p = projetos.find((x) => x.id === idOuNome || normalizar(x.nome) === alvo);
      if (!p) return { ok: false, erro: 'Projeto não encontrado.' };
      contexto.projetoAtivo = p.id; persistirContexto(); emitir('projeto:aberto', clone(p));
      return { ok: true, projeto: clone(p) };
    }
    function adicionarTarefaProjeto(id, titulo) {
      const p = id ? projetos.find((x) => x.id === id) : (contexto.projetoAtivo ? projetos.find((x) => x.id === contexto.projetoAtivo) : null);
      if (!p) return { ok: false, erro: 'Nenhum projeto ativo.' };
      const t = limitar(String(titulo || '').trim(), 180);
      if (!t) return { ok: false, erro: 'Informe a tarefa.' };
      if (p.tarefas.length >= 60) return { ok: false, erro: 'Limite de tarefas do projeto atingido.' };
      const item = { id: uid('pt-'), titulo: t, concluida: false, criadaEm: agora() };
      p.tarefas.push(item); p.atualizadoEm = agora(); persistirProjetos(); emitir('projeto:tarefa', { projeto: p.id, tarefa: clone(item) });
      return { ok: true, tarefa: clone(item), projeto: clone(p) };
    }
    function concluirTarefaProjeto(idProjeto, idTarefa, concluida) {
      const p = projetos.find((x) => x.id === idProjeto); if (!p) return { ok: false, erro: 'Projeto não encontrado.' };
      const t = (p.tarefas || []).find((x) => x.id === idTarefa); if (!t) return { ok: false, erro: 'Tarefa não encontrada.' };
      t.concluida = concluida !== false; p.atualizadoEm = agora(); persistirProjetos();
      return { ok: true, tarefa: clone(t) };
    }
    function excluirProjeto(id) {
      const i = projetos.findIndex((x) => x.id === id || normalizar(x.nome) === normalizar(id));
      if (i < 0) return { ok: false, erro: 'Projeto não encontrado.' };
      const p = projetos.splice(i, 1)[0];
      if (contexto.projetoAtivo === p.id) contexto.projetoAtivo = projetos[0] ? projetos[0].id : null;
      persistirProjetos(); persistirContexto(); emitir('projeto:excluido', { id: p.id });
      return { ok: true, removido: p.nome };
    }

    /** Classificação conservadora: sem recibo ou confirmação explícita, é incerto. */
    function verificarResultado(pedido, resultado) {
      const evidencias = [];
      const limitacoes = [];
      if (resultado == null) return { status: 'falhou', evidencias, limitacoes: ['a operação não devolveu resultado'] };
      if (typeof resultado !== 'object') return { status: 'incerto', evidencias: [limitar(resultado, 120)], limitacoes: ['resultado não é um objeto verificável'] };
      const textoResultado = String(resultado.info || resultado.fala || resultado.mensagem || resultado.resultado || '');
      if (FALHA_TEXTO.test(textoResultado)) {
        return { status: 'falhou', evidencias: [limitar(textoResultado, 180)], limitacoes: ['a própria ferramenta informou que não concluiu o efeito'] };
      }
      const rec = resultado.recibo || null;
      if (rec && rec.estado) {
        if (rec.estado === 'ok') evidencias.push(rec.motivo || 'recibo confirmou o efeito');
        else if (rec.estado === 'falhou' || rec.estado === 'bloqueado') return { status: 'falhou', evidencias, limitacoes: [limitar(rec.motivo || rec.estado, 180)] };
        // Recibo incerto é soberano: nenhum ok genérico da ferramenta o transforma em certeza.
        else return { status: 'incerto', evidencias, limitacoes: [limitar(rec.motivo || 'recibo sem confirmação', 180)] };
      }
      if (resultado.ok === false || resultado.falhou === true || resultado.erro) {
        return { status: 'falhou', evidencias, limitacoes: [limitar(resultado.erro || resultado.info || 'a ferramenta informou falha', 180)] };
      }
      if (resultado.verificado === true || resultado.ok === true || resultado.sucesso === true) {
        const prova = resultado.info || resultado.fala || resultado.resultado;
        if (prova) evidencias.push(limitar(prova, 180));
        if (!prova && !rec) limitacoes.push('não veio texto de evidência');
        return { status: 'confirmado', evidencias, limitacoes };
      }
      if (resultado.info || resultado.fala) evidencias.push(limitar(resultado.info || resultado.fala, 180));
      limitacoes.push('o efeito não foi declarado como confirmado');
      return { status: 'incerto', evidencias, limitacoes };
    }

    function registrarExecutor(id, fn) {
      if (!agentePorId(id) || typeof fn !== 'function') return false;
      executores.set(id, fn); return true;
    }
    function listarExecutores() { return Array.from(executores.keys()); }

    /** Executa um agente que tenha executor registrado. Sem executor, não inventa. */
    async function delegar(pedido, opcoes) {
      const sel = selecionar(pedido);
      const alvo = (opcoes && opcoes.agente) || sel.agente.id;
      const executor = executores.get(alvo) || executores.get('principal');
      const pre = await preflight(pedido, { agente: alvo });
      if (!pre.ok) {
        const v = { status: 'falhou', evidencias: [], limitacoes: pre.bloqueios.map((x) => (x.nome || x.id) + ': ' + (x.detalhe || 'indisponível')) };
        registrarResultado(pedido, { ok: false, erro: 'Pré-checagem bloqueou a execução: ' + pre.orientacao }, alvo);
        emitir('delegacao', { agente: alvo, status: v.status, bloqueado: true, preflight: pre });
        return Object.assign({ ok: false, agente: alvo, preflight: pre, fala: 'Não executei: ' + pre.orientacao, resultado: null }, v, { status: 'bloqueado', bloqueado: true });
      }
      observarPedido(pedido, alvo);
      if (!executor) {
        return { ok: false, status: 'nao_configurado', agente: alvo,
          fala: 'O agente ' + (agentePorId(alvo) || {}).nome + ' foi selecionado, mas ainda não possui executor autorizado. Nada foi executado.' };
      }
      const inicio = agora();
      try {
        const bruto = await executor({ pedido: String(pedido || ''), agente: alvo, core: api, projeto: projetoAtual() });
        const v = verificarResultado(pedido, bruto);
        registrarResultado(pedido, bruto, alvo);
        emitir('delegacao', { agente: alvo, status: v.status, duracaoMs: agora() - inicio });
        return Object.assign({ agente: alvo, duracaoMs: agora() - inicio, resultado: bruto }, v);
      } catch (e) {
        const v = verificarResultado(pedido, { ok: false, erro: String((e && e.message) || e) });
        registrarResultado(pedido, { ok: false, erro: String((e && e.message) || e) }, alvo);
        return Object.assign({ agente: alvo, erro: String((e && e.message) || e) }, v);
      }
    }

    function registrarComponente(def) {
      if (!def || !/^[a-z][a-z0-9_]{1,39}$/.test(String(def.id || ''))) throw new Error('componente inválido');
      if (typeof def.checar !== 'function') throw new Error('componente sem checar');
      const deps = Array.isArray(def.dependencias) ? def.dependencias.filter((x) => /^[a-z][a-z0-9_]{1,39}$/.test(String(x || ''))).slice(0, 8) : [];
      componentes.set(def.id, {
        id: def.id, nome: limitar(def.nome || def.id, 80), essencial: !!def.essencial,
        categoria: limitar(def.categoria || 'geral', 24), dependencias: deps,
        checar: def.checar, recuperar: typeof def.recuperar === 'function' ? def.recuperar : null,
        recuperacaoAutomatica: def.recuperacaoAutomatica === true && typeof def.recuperar === 'function',
        timeoutMs: Math.max(300, Math.min(5000, Number(def.timeoutMs) || 1800))
      });
      return true;
    }
    function listarComponentes() {
      return Array.from(componentes.values()).map((c) => ({ id: c.id, nome: c.nome, essencial: c.essencial,
        categoria: c.categoria, dependencias: c.dependencias.slice(), recuperavel: !!c.recuperar,
        recuperacaoAutomatica: !!c.recuperacaoAutomatica }));
    }
    function classificarCausa(c, r, erro) {
      const txt = String((erro && erro.message) || (r && (r.erro || r.detalhe || r.motivo)) || '').toLowerCase();
      if (/tempo esgotado|timeout|abort|tempor[aá]ri/.test(txt)) return 'temporaria';
      if (/permiss|config|chave|api|modelo|nao configurad|não configurad|offline|sem rede|indispon/.test(txt)) return 'configuracao';
      return c.essencial ? 'critica' : 'temporaria';
    }
    function normalizarSaude(c, r, erro, ms) {
      let status = 'ok', detalhe = '';
      if (erro) { status = 'falhou'; detalhe = String((erro && erro.message) || erro); }
      else if (r && typeof r === 'object') {
        const st = String(r.status || '').toLowerCase();
        if (r.ok === false || st === 'falhou') { status = 'falhou'; detalhe = String(r.erro || r.detalhe || r.motivo || 'componente falhou'); }
        else if (st === 'aviso' || st === 'degradado' || r.aviso) { status = 'aviso'; detalhe = String(r.detalhe || r.info || r.motivo || 'componente em atenção'); }
        else if (st === 'ok' || st === '' || r.ok === true || typeof r.ok === 'undefined') { status = 'ok'; detalhe = String(r.detalhe || r.info || ''); }
        else { status = 'aviso'; detalhe = String(r.detalhe || r.info || ''); }
      } else if (r === false) { status = 'falhou'; detalhe = 'componente devolveu falso'; }
      const falhou = status === 'falhou';
      return { id: c.id, nome: c.nome, categoria: c.categoria, essencial: c.essencial, status,
        detalhe: limitar(detalhe, 180), causa: falhou ? ((r && r.causa) || classificarCausa(c, r, erro)) : null,
        evidencias: falhou && detalhe ? [limitar(detalhe, 180)] : [],
        orientacao: limitar((r && (r.orientacao || r.solucao)) || '', 180),
        recuperavel: !!c.recuperar, recuperacaoAutomatica: !!c.recuperacaoAutomatica, duracaoMs: ms };
    }
    async function medir(c) {
      const t0 = agora();
      let timer;
      try {
        const r = await Promise.race([
          Promise.resolve().then(() => c.checar()),
          new Promise((_, rej) => { timer = setTimeout(() => rej(new Error('tempo esgotado')), c.timeoutMs); })
        ]);
        return normalizarSaude(c, r, null, agora() - t0);
      } catch (e) {
        return normalizarSaude(c, null, (e && e.message) || e, agora() - t0);
      } finally { if (timer) clearTimeout(timer); }
    }
    function resumoRecuperacoes() {
      const recuperados = recuperacoes.filter((x) => x.status === 'recuperado').length;
      return { total: recuperacoes.length, recuperados, ultima: recuperacoes.length ? clone(recuperacoes[recuperacoes.length - 1]) : null };
    }
    function registrarRecuperacao(reg) {
      recuperacoes.push(reg);
      if (recuperacoes.length > 30) recuperacoes.splice(0, recuperacoes.length - 30);
      gravar('core:recuperacoes', recuperacoes);
      emitir('recuperacao', reg);
      log('recuperação ' + reg.componente, reg.status + (reg.detalhe ? ': ' + reg.detalhe : ''));
    }
    async function recuperarComponente(id, opcoes) {
      const c = componentes.get(id);
      if (!c) return { ok: false, status: 'nao_encontrado', componente: id, fala: 'Componente não registrado.' };
      if (!c.recuperar) return { ok: false, status: 'nao_suportado', componente: id, fala: 'Este componente não declarou recuperação segura.' };
      if (recuperando.has(id)) return { ok: false, status: 'em_andamento', componente: id, fala: 'Já existe uma recuperação em andamento.' };
      const historico = recuperacoes.filter((x) => x.componente === id && Number(x.em) > agora() - JANELA_RECUPERACAO_MS);
      const ultima = historico[historico.length - 1];
      if (ultima && agora() - Number(ultima.em) < INTERVALO_RECUPERACAO_MS) {
        const espera = Math.ceil((INTERVALO_RECUPERACAO_MS - (agora() - Number(ultima.em))) / 1000);
        return { ok: false, status: 'aguardando', componente: id, esperaMs: espera * 1000, fala: 'Aguardando ' + espera + ' s para evitar loop de recuperação.' };
      }
      if (historico.length >= MAX_RECUPERACOES) {
        return { ok: false, status: 'limite', componente: id, fala: 'Limite de recuperações nesta janela; é preciso ação do usuário.' };
      }
      const antes = (opcoes && opcoes.diagnostico) || await medir(c);
      if (antes.status === 'ok') return { ok: true, status: 'saudavel', componente: id, antes, depois: antes, fala: 'O componente já está operacional.' };
      recuperando.add(id);
      const t0 = agora();
      try {
        let timer;
        await Promise.race([
          Promise.resolve().then(() => c.recuperar({ componente: { id: c.id, nome: c.nome }, diagnostico: antes, core: api })),
          new Promise((_, rej) => { timer = setTimeout(() => rej(new Error('recuperação excedeu 4 s')), 4000); })
        ]).finally(() => { if (timer) clearTimeout(timer); });
        const depois = await medir(c);
        const reg = { em: agora(), componente: id, causa: antes.causa || 'desconhecida',
          status: depois.status === 'ok' ? 'recuperado' : (depois.status === 'aviso' ? 'parcial' : 'falhou'),
          detalhe: limitar(depois.detalhe || antes.detalhe || '', 160), antes: antes.status,
          depois: depois.status, duracaoMs: agora() - t0 };
        registrarRecuperacao(reg);
        return Object.assign({ ok: depois.status === 'ok', componente: id, antes, depois }, reg);
      } catch (e) {
        const reg = { em: agora(), componente: id, causa: antes.causa || 'desconhecida', status: 'falhou',
          detalhe: limitar(String((e && e.message) || e), 160), antes: antes.status, depois: 'falhou', duracaoMs: agora() - t0 };
        registrarRecuperacao(reg);
        return Object.assign({ ok: false, componente: id, antes }, reg);
      } finally { recuperando.delete(id); }
    }
    async function recuperarFalhas(opcoes) {
      const auto = !!(opcoes && opcoes.auto);
      const d = (opcoes && opcoes.diagnostico) || await diagnosticar({ recuperarAutomatico: false });
      const itens = (d.itens || []);
      const alvos = itens.filter((x) => x.status === 'falhou' && x.recuperavel && (!auto || x.recuperacaoAutomatica));
      const resultados = [];
      for (const item of alvos) resultados.push(await recuperarComponente(item.id, { diagnostico: item }));
      const recuperados = resultados.filter((x) => x.status === 'recuperado').length;
      const falharam = resultados.filter((x) => x.status === 'falhou' || x.status === 'limite' || x.status === 'aguardando').length;
      return { ok: recuperados > 0 && falharam === 0, tentadas: resultados.length, recuperados, falharam,
        ignorados: itens.filter((x) => x.status === 'falhou' && (!x.recuperavel || (auto && !x.recuperacaoAutomatica))).length,
        itens: resultados };
    }
    async function preflight(pedido, opcoes) {
      const selecao = selecionar(pedido);
      const agente = (opcoes && opcoes.agente) || selecao.agente.id;
      const deps = {
        principal: ['sistema', 'interface'], pesquisa: ['rede'],
        programacao: ['sistema', 'armazenamento'], arquivos: ['sistema', 'armazenamento'],
        automacao: ['interface'], voz: ['interface'], memoria: ['memoria', 'armazenamento'],
        tecnico: ['sistema'], planejamento: ['sistema'], diagnostico: ['sistema'],
        desenvolvimento: ['sistema', 'armazenamento'], atualizacao: ['rede']
      }[agente] || ['sistema'];
      const itens = [];
      for (const id of deps) {
        const c = componentes.get(id);
        if (!c) { itens.push({ id, status: 'nao_monitorado', detalhe: 'componente não registrado', recuperavel: false }); continue; }
        itens.push(await medir(c));
      }
      const bloqueios = itens.filter((x) => x.status === 'falhou');
      return { ok: bloqueios.length === 0, status: bloqueios.length ? 'bloqueado' : (itens.some((x) => x.status === 'aviso') ? 'atencao' : 'ok'),
        agente, itens, bloqueios,
        orientacao: bloqueios.length ? 'Corrija: ' + bloqueios.map((x) => x.nome || x.id).join(', ') + '. O Core não executou a ação.' : '' };
    }
    async function diagnosticar(opcoes) {
      const inicio = agora();
      const itens = [];
      for (const c of componentes.values()) itens.push(await medir(c));
      const d = { em: agora(), duracaoMs: agora() - inicio, itens,
        falhas: itens.filter((x) => x.status === 'falhou').length,
        avisos: itens.filter((x) => x.status === 'aviso').length };
      if (opcoes && opcoes.recuperarAutomatico) {
        const rr = await recuperarFalhas({ auto: true, diagnostico: d });
        rr.itens.forEach((r) => {
          const i = itens.findIndex((x) => x.id === r.componente);
          if (i >= 0 && r.depois) itens[i] = r.depois;
        });
        d.recuperacao = { tentadas: rr.tentadas, recuperados: rr.recuperados, falharam: rr.falharam, ignorados: rr.ignorados };
        d.falhas = itens.filter((x) => x.status === 'falhou').length;
        d.avisos = itens.filter((x) => x.status === 'aviso').length;
      }
      d.status = d.falhas ? 'degradado' : (d.avisos ? 'atencao' : 'ok');
      d.duracaoMs = agora() - inicio;
      ultimoDiagnostico = d;
      gravar('core:ultimo_diagnostico', d);
      emitir('diagnostico', d);
      return clone(d);
    }

    function iniciarVigia(intervaloMs) {
      pararVigia();
      const ms = Math.max(30000, Math.min(900000, Number(intervaloMs) || 120000));
      vigiaTimer = setInterval(async () => {
        if (vigiaRodando) return;
        if (typeof document !== 'undefined' && document.hidden) return;
        vigiaRodando = true;
        try { await diagnosticar({ recuperarAutomatico: true }); } catch (e) { log('watchdog', String((e && e.message) || e)); }
        finally { vigiaRodando = false; }
      }, ms);
      if (vigiaTimer && typeof vigiaTimer.unref === 'function') vigiaTimer.unref();
      return { ativo: true, intervaloMs: ms };
    }
    function pararVigia() {
      if (vigiaTimer) { clearInterval(vigiaTimer); vigiaTimer = null; }
      vigiaRodando = false; return true;
    }
    function vigiaAtivo() { return !!vigiaTimer; }

    function listarHabilidades() {
      const doSistema = sistema && typeof sistema.listarFerramentas === 'function' ? sistema.listarFerramentas() : [];
      const mapa = new Map();
      doSistema.forEach((f) => mapa.set(f.id, { id: f.id, nome: f.nome, descricao: f.descricao, nivel: f.nivel,
        risco: f.risco || 0, origem: 'sistema', habilitada: habilidadesDesativadas.indexOf(f.id) < 0 }));
      habilidadesLocais.forEach((h, id) => mapa.set(id, Object.assign({ origem: 'core' }, h, { habilitada: habilidadesDesativadas.indexOf(id) < 0 })));
      return Array.from(mapa.values());
    }
    function registrarHabilidade(def) {
      if (!def || !/^[a-z][a-z0-9_]{1,39}$/.test(String(def.id || ''))) throw new Error('habilidade inválida');
      habilidadesLocais.set(def.id, { id: def.id, nome: limitar(def.nome || def.id, 80), descricao: limitar(def.descricao || '', 240),
        nivel: def.nivel || 'leitura', risco: Number(def.risco) || 0, executor: typeof def.executor === 'function' ? def.executor : null });
      return true;
    }
    function alternarHabilidade(id, ativa) {
      if (!id) return { ok: false, erro: 'Habilidade inválida.' };
      const desativar = ativa === false;
      habilidadesDesativadas = habilidadesDesativadas.filter((x) => x !== id);
      if (desativar) habilidadesDesativadas.push(id);
      gravar('core:habilidades_desativadas', habilidadesDesativadas);
      return { ok: true, id, habilitada: !desativar };
    }
    async function executarHabilidade(id, args) {
      const h = listarHabilidades().find((x) => x.id === id);
      if (!h) return { ok: false, erro: 'Habilidade não encontrada.' };
      if (!h.habilitada) return { ok: false, bloqueado: true, erro: 'Habilidade desativada no Core.' };
      if (h.origem === 'sistema') {
        if (!sistema || typeof sistema.executar !== 'function') return { ok: false, erro: 'SISTEMA indisponível.' };
        const r = await sistema.executar(id, args || {}, { origem: 'core', agente: 'core' });
        return r;
      }
      if (!h.executor) return { ok: false, erro: 'Habilidade local sem executor.' };
      return h.executor(args || {});
    }

    function status() {
      return {
        versao: VERSAO,
        agentes: AGENTES.length,
        agentesComExecutor: executores.size,
        projetos: projetos.length,
        projetoAtivo: contexto.projetoAtivo,
        pedidos: contexto.pedidos.length,
        decisoes: contexto.decisoes.length,
        habilidades: listarHabilidades().length,
        habilidadesAtivas: listarHabilidades().filter((x) => x.habilitada).length,
        componentes: componentes.size,
        recuperacoes: recuperacoes.length,
        recuperacoesResumo: resumoRecuperacoes(),
        vigia: vigiaAtivo(),
        ultimoDiagnostico: ultimoDiagnostico ? { em: ultimoDiagnostico.em, status: ultimoDiagnostico.status, falhas: ultimoDiagnostico.falhas, avisos: ultimoDiagnostico.avisos || 0 } : null,
        integracoes: { mcp: 'nao_implementado', rag_vetorial: 'nao_implementado', tv_esp32: 'nao_implementado', pareamento_pc: 'nao_implementado' }
      };
    }

    function exportar() {
      return JSON.stringify({ versao: VERSAO, exportadoEm: new Date().toISOString(), contexto: clone(contexto),
        projetos: clone(projetos), habilidadesDesativadas: habilidadesDesativadas.slice() }, null, 2);
    }
    function importar(texto) {
      let d;
      try { d = JSON.parse(String(texto || '')); } catch (e) { return { ok: false, erro: 'JSON inválido.' }; }
      if (!d || typeof d !== 'object' || !Array.isArray(d.projetos)) return { ok: false, erro: 'Backup do Core inválido.' };
      const novos = d.projetos.filter((p) => p && p.id && p.nome).slice(0, LIMITE_PROJETOS).map((p) => ({
        id: limitar(p.id, 80), nome: limitar(p.nome, 80), objetivo: limitar(p.objetivo || '', 240), estado: p.estado === 'concluido' ? 'concluido' : 'ativo',
        tarefas: (Array.isArray(p.tarefas) ? p.tarefas : []).slice(0, 60).map((t) => ({ id: limitar(t.id || uid('pt-'), 80), titulo: limitar(t.titulo || '', 180), concluida: !!t.concluida, criadaEm: Number(t.criadaEm) || agora() })),
        criadoEm: Number(p.criadoEm) || agora(), atualizadoEm: Number(p.atualizadoEm) || agora()
      }));
      projetos = novos; persistirProjetos();
      if (d.contexto && typeof d.contexto === 'object') {
        contexto = Object.assign(contexto, { projetoAtivo: d.contexto.projetoAtivo || null, ultimoPedido: limitar(d.contexto.ultimoPedido || '', 240),
          ultimoAgente: limitar(d.contexto.ultimoAgente || 'principal', 40), pedidos: [], decisoes: [] });
        persistirContexto();
      }
      return { ok: true, projetos: projetos.length };
    }

    const api = {
      VERSAO, agentes: AGENTES, listarAgentes, criarProjeto, abrirProjeto, projetoAtual, listarProjetos,
      adicionarTarefaProjeto, concluirTarefaProjeto, excluirProjeto,
      selecionar, observarPedido, resolverReferencia, verificarResultado, registrarResultado,
      registrarExecutor, listarExecutores, delegar,
      registrarComponente, listarComponentes, diagnosticar, iniciarVigia, pararVigia, vigiaAtivo,
      preflight, recuperarComponente, recuperarFalhas, listarRecuperacoes: () => recuperacoes.map(clone),
      listarHabilidades, registrarHabilidade, alternarHabilidade, executarHabilidade,
      contexto: () => clone(contexto), status, exportar, importar, limparVigia: pararVigia, ao
    };
    return api;
  }

  return { VERSAO, criarCore, AGENTES };
});
