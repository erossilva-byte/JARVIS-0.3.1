/* J.A.R.V.I.S. Nova — Central de Comandos (interface única para celular e computador).
 *
 * Uma camada nova por cima do app que já existe, sem alterar nenhuma tela:
 *
 *   computador  painel central em três partes (áreas, capacidades, busca), atalhos de
 *               teclado, foco visível, largura de leitura confortável;
 *   celular     gaveta que sobe de baixo, com áreas em faixa horizontal e cartões
 *               grandes para o dedo, arrastar para baixo para fechar;
 *
 * Cada capacidade do catálogo (catalogo_jarvis.js) tem uma ação real:
 *   c  roda um comando local pelo próprio núcleo (Hermes.cap.comandoLocal);
 *   p  abre o painel que já existe (clica no botão de navegação do app);
 *   a  ação de interface: deck, parar, log, config;
 *   —  sem ação: mostra o que falta, em vez de fingir que fez.
 *
 * Não toca no DOM existente além de acrescentar o próprio botão e a própria gaveta.
 * Carregamento tolerante: espera o DOM e as capacidades do Hermes, com rede de segurança.
 */
(function () {
  'use strict';
  if (typeof window === 'undefined' || typeof document === 'undefined') return;
  if (window.JarvisCentral) return;

  const CAT = window.JarvisCatalogo;
  if (!CAT || !Array.isArray(CAT.AREAS)) return;

  const CHAVE_AREA = 'jarvis.central.area';
  const CHAVE_FILTRO = 'jarvis.central.filtro';
  const FILTROS = [
    { id: 'tudo', nome: 'Tudo' },
    { id: 'agora', nome: 'Funciona agora' },
    { id: 'chave', nome: 'Pede chave' },
    { id: 'pc', nome: 'Só no PC' },
    { id: 'falta', nome: 'Falta' }
  ];

  function plataformaAtual() {
    try {
      if (window.jarvisNative && window.jarvisNative.run) return 'pc';
      const cap = window.Capacitor;
      if (cap && typeof cap.getPlatform === 'function') {
        const p = cap.getPlatform();
        if (p === 'android') return 'android';
        if (p === 'ios') return 'ios';
      }
    } catch (e) { /* segue como web */ }
    return 'web';
  }

  const PLATAFORMA = plataformaAtual();
  const NOME_PLATAFORMA = { pc: 'computador', android: 'celular', ios: 'celular', web: 'navegador' }[PLATAFORMA] || 'navegador';

  const estado = {
    aberto: false,
    area: 'ia',
    filtro: 'tudo',
    busca: '',
    selecionado: 0,
    itens: [],
    focoAnterior: null
  };

  /* --------------------------------------------------------------- utilidades */
  let refs = null;

  function el(tag, classe, texto) {
    const n = document.createElement(tag);
    if (classe) n.className = classe;
    if (texto != null) n.textContent = texto;
    return n;
  }

  function guardar(chave, valor) {
    try { window.localStorage.setItem(chave, valor); } catch (e) { /* modo privado */ }
  }
  function ler(chave, padrao) {
    try {
      const v = window.localStorage.getItem(chave);
      return v == null ? padrao : v;
    } catch (e) { return padrao; }
  }
  function movel() {
    return window.matchMedia('(max-width: 899px)').matches;
  }
  function reduzido() {
    return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  }

  /* ------------------------------------------------------------------- estilos */
  const CSS = `
  .cx-fundo{position:fixed;inset:0;z-index:9980;background:rgba(2,7,13,.72);backdrop-filter:blur(7px);opacity:0;transition:opacity .18s ease}
  .cx-fundo.on{opacity:1}
  .cx-deck{position:fixed;z-index:9990;display:flex;flex-direction:column;color:#e8f6ff;font:400 15px/1.45 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;background:linear-gradient(180deg,rgba(7,19,28,.985),rgba(4,10,16,.99));border:1px solid rgba(23,200,255,.28);box-shadow:0 24px 70px rgba(0,0,0,.62),0 0 0 1px rgba(0,0,0,.35) inset;transform:translateY(14px);opacity:0;transition:transform .18s ease,opacity .18s ease}
  .cx-deck.on{transform:none;opacity:1}
  .cx-deck[hidden]{display:none}
  .cx-arrasto{display:none}
  .cx-topo{display:flex;align-items:center;gap:12px;padding:14px 16px;border-bottom:1px solid rgba(23,200,255,.16);flex:0 0 auto}
  .cx-marca{display:flex;align-items:center;gap:9px;min-width:0;flex:0 0 auto}
  .cx-marca b{font-weight:600;letter-spacing:.02em;white-space:nowrap}
  .cx-ponto{width:9px;height:9px;border-radius:50%;background:#17c8ff;box-shadow:0 0 12px #17c8ff;flex:0 0 auto}
  .cx-plat{font-size:11px;letter-spacing:.09em;text-transform:uppercase;color:#7fd7ff;background:rgba(23,200,255,.12);border:1px solid rgba(23,200,255,.28);border-radius:999px;padding:3px 9px;white-space:nowrap}
  .cx-busca{flex:1 1 auto;display:flex;align-items:center;gap:8px;background:rgba(255,255,255,.05);border:1px solid rgba(255,255,255,.12);border-radius:12px;padding:0 12px;min-width:0;height:42px}
  .cx-busca:focus-within{border-color:rgba(23,200,255,.55);box-shadow:0 0 0 3px rgba(23,200,255,.14)}
  .cx-busca input{flex:1 1 auto;min-width:0;background:none;border:0;outline:none;color:#e8f6ff;font:inherit}
  .cx-busca input::placeholder{color:#7d93a6}
  .cx-busca svg{flex:0 0 auto;opacity:.65}
  .cx-x{flex:0 0 auto;width:42px;height:42px;border-radius:12px;border:1px solid rgba(255,255,255,.14);background:rgba(255,255,255,.04);color:#cfe9f7;font-size:16px;line-height:1;cursor:pointer;touch-action:manipulation}
  .cx-x:hover{background:rgba(23,200,255,.14);border-color:rgba(23,200,255,.5)}
  .cx-x:focus-visible{outline:2px solid #17c8ff;outline-offset:2px}
  .cx-filtros{display:flex;gap:7px;padding:10px 16px;overflow-x:auto;scrollbar-width:none;flex:0 0 auto;border-bottom:1px solid rgba(255,255,255,.06)}
  .cx-filtros::-webkit-scrollbar{display:none}
  .cx-chip{flex:0 0 auto;border:1px solid rgba(255,255,255,.14);background:rgba(255,255,255,.03);color:#bcd6e6;border-radius:999px;padding:7px 13px;font-size:13px;cursor:pointer;white-space:nowrap;touch-action:manipulation}
  .cx-chip:hover{border-color:rgba(23,200,255,.46);color:#e8f6ff}
  .cx-chip.on{background:rgba(23,200,255,.18);border-color:rgba(23,200,255,.62);color:#eafaff;font-weight:600}
  .cx-chip:focus-visible{outline:2px solid #17c8ff;outline-offset:2px}
  .cx-corpo{flex:1 1 auto;min-height:0;display:flex;flex-direction:column}
  .cx-trilho{display:flex;gap:7px;padding:10px 16px;overflow-x:auto;scrollbar-width:none;flex:0 0 auto}
  .cx-trilho::-webkit-scrollbar{display:none}
  .cx-area{flex:0 0 auto;display:inline-flex;align-items:center;gap:7px;border:1px solid rgba(255,255,255,.12);background:rgba(255,255,255,.03);color:#b9d3e4;border-radius:11px;padding:9px 12px;font-size:13.5px;cursor:pointer;touch-action:manipulation}
  .cx-area:hover{border-color:rgba(23,200,255,.45);color:#eafaff}
  .cx-area.on{background:linear-gradient(180deg,rgba(23,200,255,.22),rgba(23,200,255,.09));border-color:rgba(23,200,255,.6);color:#f2fbff;font-weight:600}
  .cx-area:focus-visible{outline:2px solid #17c8ff;outline-offset:2px}
  .cx-area .n{font-size:11px;opacity:.72;font-weight:400}
  .cx-lista{flex:1 1 auto;min-height:0;overflow-y:auto;overscroll-behavior:contain;padding:4px 16px 20px}
  .cx-lista:focus{outline:none}
  .cx-card{display:block;width:100%;text-align:left;border:1px solid rgba(255,255,255,.1);background:rgba(255,255,255,.035);border-radius:14px;padding:13px 14px;margin-bottom:10px;color:inherit;font:inherit;cursor:pointer;touch-action:manipulation;transition:border-color .14s ease,background .14s ease,transform .14s ease}
  .cx-card:hover{border-color:rgba(23,200,255,.45);background:rgba(23,200,255,.07)}
  .cx-card.sel{border-color:rgba(23,200,255,.75);background:rgba(23,200,255,.11);box-shadow:0 0 0 1px rgba(23,200,255,.35) inset}
  .cx-card:focus-visible{outline:2px solid #17c8ff;outline-offset:2px}
  .cx-card.falta{opacity:.9}
  .cx-l1{display:flex;align-items:baseline;gap:10px;justify-content:space-between}
  .cx-t{font-weight:600;font-size:15px;letter-spacing:.01em}
  .cx-badge{flex:0 0 auto;font-size:10.5px;letter-spacing:.05em;text-transform:uppercase;padding:3px 8px;border-radius:999px;border:1px solid currentColor;opacity:.95;white-space:nowrap}
  .cx-d{display:block;margin-top:4px;color:#a9c4d6;font-size:13.5px}
  .cx-hint{display:block;margin-top:7px;font-size:12.5px;color:#7fd7ff;opacity:.9}
  .cx-hint.nada{color:#ffb2a8}
  .cx-vazio{padding:34px 8px;text-align:center;color:#93aec1;font-size:14px}
  .cx-rodape{flex:0 0 auto;display:flex;align-items:center;gap:12px;justify-content:space-between;padding:10px 16px;border-top:1px solid rgba(255,255,255,.07);font-size:12px;color:#8fabc0}
  .cx-dicas{display:none}
  .cx-aviso{position:absolute;left:50%;bottom:64px;transform:translate(-50%,10px);max-width:min(560px,92%);background:rgba(8,22,32,.98);border:1px solid rgba(23,200,255,.5);border-radius:12px;padding:11px 14px;font-size:13.5px;color:#e8f6ff;box-shadow:0 12px 34px rgba(0,0,0,.5);opacity:0;pointer-events:none;transition:opacity .16s ease,transform .16s ease;z-index:2}
  .cx-aviso.on{opacity:1;transform:translate(-50%,0)}
  .cx-abrir{position:fixed;z-index:9970;display:inline-flex;align-items:center;gap:9px;border:1px solid rgba(23,200,255,.5);background:linear-gradient(180deg,rgba(11,32,45,.96),rgba(5,14,22,.97));color:#dff6ff;border-radius:999px;padding:10px 15px;font:600 13px/1 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;cursor:pointer;box-shadow:0 10px 28px rgba(0,0,0,.45);touch-action:manipulation}
  .cx-abrir:hover{border-color:#17c8ff;box-shadow:0 0 22px rgba(23,200,255,.3)}
  .cx-abrir:focus-visible{outline:2px solid #17c8ff;outline-offset:3px}
  .cx-abrir .k{font-size:11px;opacity:.8;border:1px solid rgba(255,255,255,.2);border-radius:5px;padding:2px 5px}
  @media (max-width:899px){
    .cx-abrir{right:14px;bottom:calc(86px + env(safe-area-inset-bottom));padding:12px 16px;min-height:44px}
    .cx-abrir .k{display:none}
    .cx-deck{left:0;right:0;bottom:0;top:auto;height:88dvh;max-height:88dvh;border-radius:20px 20px 0 0;padding-bottom:env(safe-area-inset-bottom)}
    .cx-deck .cx-arrasto{display:block;width:44px;height:4px;border-radius:2px;background:rgba(255,255,255,.3);margin:8px auto 0;flex:0 0 auto}
    .cx-topo{flex-wrap:wrap;padding:10px 14px 12px}
    .cx-marca{flex:1 1 auto}
    .cx-busca{order:3;flex:1 1 100%;height:44px}
    .cx-filtros{padding:8px 14px}
    .cx-trilho{padding:8px 14px}
    .cx-lista{padding:2px 14px 26px}
    .cx-t{font-size:15.5px}
    .cx-card{padding:14px}
    .cx-rodape{padding:9px 14px 12px;font-size:11.5px}
  }
  @media (min-width:900px){
    .cx-abrir{left:calc(50% - 74px);top:10px;padding:8px 14px;font-size:12px}
    .cx-deck{left:0;right:0;top:3vh;bottom:3vh;max-width:1180px;margin:0 auto;border-radius:20px}
    .cx-corpo{display:grid;grid-template-columns:242px 1fr}
    .cx-trilho{flex-direction:column;gap:5px;overflow:visible;padding:12px 10px;border-right:1px solid rgba(23,200,255,.14);overflow-y:auto}
    .cx-area{width:100%;justify-content:flex-start;border-color:transparent;background:none;padding:10px 11px}
    .cx-area.on{background:rgba(23,200,255,.16);border-color:rgba(23,200,255,.4)}
    .cx-area .n{margin-left:auto}
    .cx-lista{display:grid;grid-template-columns:repeat(auto-fill,minmax(288px,1fr));gap:10px;align-content:start;padding:14px 16px 22px}
    .cx-card{margin-bottom:0;height:100%}
    .cx-dicas{display:block}
    .cx-dicas b{color:#bcd6e6;font-weight:600}
    .cx-rodape{font-size:12px}
  }
  @media (prefers-reduced-motion:reduce){
    .cx-deck,.cx-fundo,.cx-card,.cx-aviso{transition:none}
  }
  `;

  function injetarEstilo() {
    if (document.getElementById('cx-estilo')) return;
    const st = el('style');
    st.id = 'cx-estilo';
    st.textContent = CSS;
    document.head.appendChild(st);
  }

  /* ---------------------------------------------------------------- construção */
  function construir() {
    if (document.getElementById('cx-deck')) return;

    const fundo = el('div', 'cx-fundo');
    fundo.id = 'cx-fundo';
    fundo.hidden = true;

    const deck = el('div', 'cx-deck');
    deck.id = 'cx-deck';
    deck.hidden = true;
    deck.setAttribute('role', 'dialog');
    deck.setAttribute('aria-modal', 'true');
    deck.setAttribute('aria-labelledby', 'cx-titulo');
    deck.setAttribute('aria-describedby', 'cx-resumo');

    const arrasto = el('div', 'cx-arrasto');
    arrasto.setAttribute('aria-hidden', 'true');

    const topo = el('div', 'cx-topo');
    const marca = el('div', 'cx-marca');
    marca.appendChild(el('span', 'cx-ponto'));
    const titulo = el('b', null, 'Central de Comandos');
    titulo.id = 'cx-titulo';
    marca.appendChild(titulo);
    const plat = el('span', 'cx-plat', NOME_PLATAFORMA);
    plat.id = 'cx-plat';
    marca.appendChild(plat);

    const busca = el('label', 'cx-busca');
    busca.setAttribute('for', 'cx-campo');
    busca.innerHTML = '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>';
    const campo = el('input');
    campo.id = 'cx-campo';
    campo.type = 'search';
    campo.placeholder = 'Buscar: IMC, alarme, QR, arquivo…';
    campo.setAttribute('autocomplete', 'off');
    campo.setAttribute('aria-label', 'Buscar capacidade');
    busca.appendChild(campo);

    const fechar = el('button', 'cx-x', '✕');
    fechar.id = 'cx-fechar';
    fechar.type = 'button';
    fechar.setAttribute('aria-label', 'Fechar (Esc)');
    fechar.title = 'Fechar (Esc)';

    topo.appendChild(marca);
    topo.appendChild(busca);
    topo.appendChild(fechar);

    const filtros = el('div', 'cx-filtros');
    filtros.setAttribute('role', 'tablist');
    filtros.setAttribute('aria-label', 'Filtrar por estado');

    const corpo = el('div', 'cx-corpo');
    const trilho = el('nav', 'cx-trilho');
    trilho.setAttribute('aria-label', 'Áreas');
    const lista = el('div', 'cx-lista');
    lista.id = 'cx-lista';
    lista.setAttribute('role', 'list');
    lista.setAttribute('tabindex', '-1');
    corpo.appendChild(trilho);
    corpo.appendChild(lista);

    const rodape = el('div', 'cx-rodape');
    const contagem = el('span');
    contagem.id = 'cx-contagem';
    const resumo = el('span', 'cx-dicas');
    resumo.id = 'cx-resumo';
    rodape.appendChild(contagem);
    rodape.appendChild(resumo);

    const aviso = el('div', 'cx-aviso');
    aviso.id = 'cx-aviso';
    aviso.setAttribute('role', 'status');
    aviso.setAttribute('aria-live', 'polite');

    deck.appendChild(arrasto);
    deck.appendChild(topo);
    deck.appendChild(filtros);
    deck.appendChild(corpo);
    deck.appendChild(rodape);
    deck.appendChild(aviso);

    const abrir = el('button', 'cx-abrir');
    abrir.id = 'cx-abrir';
    abrir.type = 'button';
    abrir.title = 'Central de Comandos (Ctrl+K)';
    abrir.innerHTML = '<span aria-hidden="true">✦</span><span>Central</span><span class="k" aria-hidden="true">Ctrl K</span>';
    abrir.setAttribute('aria-label', 'Abrir a Central de Comandos');

    document.body.appendChild(fundo);
    document.body.appendChild(deck);
    document.body.appendChild(abrir);

    refs = { deck, fundo, campo, lista, trilho, filtros, contagem, resumo, aviso, abrir, fechar, arrasto, plat };

    // filtros
    FILTROS.forEach((f) => {
      const b = el('button', 'cx-chip', f.nome);
      b.type = 'button';
      b.dataset.filtro = f.id;
      b.setAttribute('role', 'tab');
      b.addEventListener('click', () => {
        estado.filtro = f.id;
        guardar(CHAVE_FILTRO, f.id);
        estado.selecionado = 0;
        desenharFiltros();
        desenharLista();
      });
      filtros.appendChild(b);
    });

    // áreas
    CAT.AREAS.forEach((a) => {
      const b = el('button', 'cx-area');
      b.type = 'button';
      b.dataset.area = a.id;
      b.title = a.resumo || a.nome;
      b.appendChild(el('span', null, a.icone));
      b.appendChild(el('span', null, a.nome));
      b.appendChild(el('span', 'n', String(a.itens.length)));
      b.addEventListener('click', () => {
        estado.area = a.id;
        guardar(CHAVE_AREA, a.id);
        estado.busca = '';
        refs.campo.value = '';
        estado.selecionado = 0;
        desenharAreas();
        desenharLista();
      });
      trilho.appendChild(b);
    });

    campo.addEventListener('input', () => {
      estado.busca = campo.value;
      estado.selecionado = 0;
      desenharLista();
    });
    campo.addEventListener('keydown', (e) => {
      if (e.key === 'ArrowDown') { e.preventDefault(); refs.lista.focus(); }
    });

    abrir.addEventListener('click', alternar);
    fechar.addEventListener('click', fechar);
    fundo.addEventListener('click', fechar);

    // arrastar para baixo fecha no celular
    let y0 = null;
    let dy = 0;
    arrasto.addEventListener('touchstart', (e) => { y0 = e.touches[0].clientY; dy = 0; }, { passive: true });
    arrasto.addEventListener('touchmove', (e) => {
      if (y0 == null) return;
      dy = Math.max(0, e.touches[0].clientY - y0);
      if (!reduzido()) deck.style.transform = 'translateY(' + Math.min(dy, 160) + 'px)';
    }, { passive: true });
    arrasto.addEventListener('touchend', () => {
      deck.style.transform = '';
      if (dy > 90) fechar();
      y0 = null;
    }, { passive: true });

    estado.area = ler(CHAVE_AREA, 'ia');
    estado.filtro = ler(CHAVE_FILTRO, 'tudo');
    if (!CAT.AREAS.some((a) => a.id === estado.area)) estado.area = CAT.AREAS[0].id;
    if (!FILTROS.some((f) => f.id === estado.filtro)) estado.filtro = 'tudo';

    desenharFiltros();
    desenharAreas();
    desenharLista();
  }

  /* ------------------------------------------------------------------ desenho */
  function desenharFiltros() {
    if (!refs) return;
    Array.prototype.forEach.call(refs.filtros.children, (b) => {
      const on = b.dataset.filtro === estado.filtro;
      b.classList.toggle('on', on);
      b.setAttribute('aria-selected', on ? 'true' : 'false');
    });
  }

  function desenharAreas() {
    if (!refs) return;
    Array.prototype.forEach.call(refs.trilho.children, (b) => {
      b.classList.toggle('on', b.dataset.area === estado.area);
    });
  }

  function passaFiltro(item) {
    const f = estado.filtro;
    if (f === 'tudo') return true;
    if (f === 'agora') return item.e === 'pronto' || item.e === 'offline';
    if (f === 'chave') return item.e === 'chave' || item.e === 'aparelho';
    if (f === 'pc') return item.e === 'pc';
    if (f === 'falta') return item.e === 'falta';
    return true;
  }

  // Nome que o usuário reconhece, em vez do identificador interno do painel.
  const NOME_PAINEL = {
    central: 'a conversa', ia: 'IA Core', voz: 'a voz', visao: 'a visão',
    tarefas: 'as tarefas', rotinas: 'as rotinas', pessoas: 'as pessoas',
    dev: 'o desenvolvimento', celular: 'o celular', info: 'as informações',
    memoria: 'a memória', arquivos: 'os arquivos', pc: 'o computador',
    atualizacao: 'a atualização', diagnostico: 'o diagnóstico'
  };

  function dicaDoItem(item) {
    if (item.c) return 'Diga ou toque: "' + item.c + '"';
    if (item.p) return 'Abre ' + (NOME_PAINEL[item.p] || ('o painel ' + item.p));
    if (item.a === 'parar') return 'Para fala, câmera e tarefas';
    if (item.a === 'config') return 'Abre os ajustes';
    if (item.a === 'log') return 'Abre o registro de ações';
    if (item.a === 'deck') return 'Já é esta tela';
    return item.n || 'Ainda não implementado';
  }

  function desenharLista() {
    if (!refs) return;
    const busca = estado.busca.trim();
    let itens;
    if (busca) {
      itens = CAT.buscar(busca);
    } else {
      itens = CAT.porArea(estado.area).map((it) => {
        const area = CAT.AREAS.find((a) => a.id === estado.area);
        return Object.assign({}, it, { area: area.id, areaNome: area.nome, icone: area.icone });
      });
    }
    itens = itens.filter(passaFiltro);
    estado.itens = itens;
    if (estado.selecionado >= itens.length) estado.selecionado = 0;

    refs.lista.textContent = '';
    if (!itens.length) {
      const v = el('p', 'cx-vazio', 'Nada encontrado com esse filtro. Experimente "Tudo" ou outro termo.');
      refs.lista.appendChild(v);
      atualizarRodape();
      return;
    }

    const frag = document.createDocumentFragment();
    itens.forEach((item, i) => {
      const estadoVisivel = CAT.estadoNaPlataforma(item.e, PLATAFORMA);
      const meta = CAT.ESTADOS[estadoVisivel] || CAT.ESTADOS.falta;
      const card = el('button', 'cx-card' + (estadoVisivel === 'falta' ? ' falta' : '') + (i === estado.selecionado ? ' sel' : ''));
      card.type = 'button';
      card.dataset.idx = String(i);
      card.setAttribute('role', 'listitem');

      const l1 = el('span', 'cx-l1');
      l1.appendChild(el('span', 'cx-t', item.t));
      const badge = el('span', 'cx-badge', meta.rotulo);
      badge.style.color = meta.cor;
      l1.appendChild(badge);
      card.appendChild(l1);
      card.appendChild(el('span', 'cx-d', busca ? item.areaNome + ' · ' + item.d : item.d));
      const dica = el('span', 'cx-hint' + (estadoVisivel === 'falta' ? ' nada' : ''), dicaDoItem(item));
      card.appendChild(dica);

      card.addEventListener('click', () => executar(item));
      card.addEventListener('mouseenter', () => {
        estado.selecionado = i;
        marcarSelecionado();
      });
      frag.appendChild(card);
    });
    refs.lista.appendChild(frag);
    atualizarRodape();
  }

  function marcarSelecionado() {
    if (!refs) return;
    Array.prototype.forEach.call(refs.lista.querySelectorAll('.cx-card'), (c) => {
      c.classList.toggle('sel', Number(c.dataset.idx) === estado.selecionado);
    });
  }

  function atualizarRodape() {
    if (!refs) return;
    const c = CAT.contar();
    const agora = c.pronto + c.offline;
    refs.contagem.textContent = agora + ' funcionam agora · ' + c.chave + ' pedem chave · ' + c.pc + ' só no PC · ' + c.falta + ' ainda faltam';
    if (movel()) {
      refs.resumo.textContent = '';
    } else {
      refs.resumo.innerHTML = '<b>↑↓</b> escolher · <b>Enter</b> abrir · <b>/</b> buscar · <b>Esc</b> fechar';
    }
  }

  /* ------------------------------------------------------------------ executar */
  let timerAviso = null;
  function avisar(texto) {
    if (!refs) return;
    refs.aviso.textContent = texto;
    refs.aviso.classList.add('on');
    if (timerAviso) clearTimeout(timerAviso);
    timerAviso = setTimeout(() => { refs.aviso.classList.remove('on'); }, 4200);
  }

  async function executar(item) {
    if (!item) return;
    try {
      if (item.c) {
        const cap = window.Hermes && window.Hermes.cap;
        if (cap && typeof cap.comandoLocal === 'function') {
          fechar();
          await cap.comandoLocal(item.c);
          return;
        }
        avisar('O núcleo ainda não publicou os comandos locais. Fale ou escreva: "' + item.c + '".');
        return;
      }
      if (item.p) {
        const alvo = document.querySelector('[data-lat="' + item.p + '"]');
        if (alvo) {
          fechar();
          alvo.click();
          return;
        }
        avisar('Este painel não existe nesta versão do app.');
        return;
      }
      if (item.a === 'parar') {
        const b = document.getElementById('btn-parar');
        fechar();
        if (b) b.click();
        return;
      }
      if (item.a === 'log') {
        const b = document.getElementById('btn-log');
        fechar();
        if (b) b.click();
        return;
      }
      if (item.a === 'config') {
        const b = document.getElementById('btn-config');
        fechar();
        if (b) b.click();
        return;
      }
      if (item.a === 'deck') {
        avisar('Você já está na Central de Comandos.');
        return;
      }
      avisar(item.n || 'Ainda não implementado neste aplicativo.');
    } catch (e) {
      avisar('Não consegui executar: ' + (e && e.message ? e.message : 'erro desconhecido'));
    }
  }

  /* ------------------------------------------------------------------- abrir/fechar */
  function abrir() {
    if (!refs || estado.aberto) return;
    construirSePreciso();
    estado.aberto = true;
    estado.focoAnterior = document.activeElement;
    refs.fundo.hidden = false;
    refs.deck.hidden = false;
    // próximo quadro: deixa a transição de opacidade acontecer
    requestAnimationFrame(() => {
      refs.fundo.classList.add('on');
      refs.deck.classList.add('on');
    });
    document.body.setAttribute('data-central', 'aberta');
    desenharLista();
    if (!movel()) refs.campo.focus();
  }

  function fechar() {
    if (!refs || !estado.aberto) return;
    estado.aberto = false;
    refs.fundo.classList.remove('on');
    refs.deck.classList.remove('on');
    document.body.removeAttribute('data-central');
    const esconder = () => {
      if (estado.aberto) return;
      refs.fundo.hidden = true;
      refs.deck.hidden = true;
    };
    if (reduzido()) esconder();
    else setTimeout(esconder, 180);
    const foco = estado.focoAnterior;
    if (foco && typeof foco.focus === 'function' && document.contains(foco)) {
      try { foco.focus({ preventScroll: true }); } catch (e) { /* sem foco */ }
    }
  }

  function alternar() {
    if (estado.aberto) fechar();
    else abrir();
  }

  const construirSePreciso = () => { if (!refs) construir(); };

  /* -------------------------------------------------------------------- teclado */
  function aoTeclar(e) {
    const meta = e.ctrlKey || e.metaKey;
    if (meta && !e.altKey && (e.key === 'k' || e.key === 'K')) {
      e.preventDefault();
      e.stopPropagation();
      construirSePreciso();
      alternar();
      return;
    }
    if (e.key === 'F1') {
      e.preventDefault();
      e.stopPropagation();
      construirSePreciso();
      abrir();
      return;
    }
    if (!estado.aberto) return;
    if (e.key === 'Escape') {
      e.preventDefault();
      e.stopPropagation();
      fechar();
      return;
    }
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      if (!estado.itens.length) return;
      e.preventDefault();
      e.stopPropagation();
      const passo = e.key === 'ArrowDown' ? 1 : -1;
      estado.selecionado = (estado.selecionado + passo + estado.itens.length) % estado.itens.length;
      marcarSelecionado();
      const atual = refs.lista.querySelector('.cx-card.sel');
      if (atual && atual.scrollIntoView) atual.scrollIntoView({ block: 'nearest' });
      return;
    }
    if (e.key === 'Enter' && document.activeElement !== refs.campo) {
      const item = estado.itens[estado.selecionado];
      if (item) {
        e.preventDefault();
        e.stopPropagation();
        executar(item);
      }
      return;
    }
    if (e.key === '/' && document.activeElement !== refs.campo) {
      e.preventDefault();
      e.stopPropagation();
      refs.campo.focus();
    }
  }

  /* ----------------------------------------------------------------- instalação */
  function instalar() {
    if (window.JarvisCentral) return true;
    injetarEstilo();
    construir();
    document.addEventListener('keydown', aoTeclar, true);
    window.JarvisCentral = {
      VERSAO: '1.0.0',
      plataforma: PLATAFORMA,
      abrir: abrir,
      fechar: fechar,
      alternar: alternar,
      estaAberta: () => estado.aberto,
      catalogo: CAT
    };
    return true;
  }

  // Se o corpo ainda não existe (script no <head>), espera sem perder o carregamento.
  if (document.body) {
    instalar();
  } else if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', instalar, { once: true });
  } else {
    setTimeout(instalar, 0);
  }
})();
