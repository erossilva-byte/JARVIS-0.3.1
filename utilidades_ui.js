/* J.A.R.V.I.S. Nova — Interface da Central de Utilidades (1.43.0)
 * Liga os núcleos puros (utilidades, jogos, cultura, briefing) ao painel e ao chat.
 * Não guarda nada na rede: cálculo, jogos e acervo são locais.
 */
(function (raiz) {
  'use strict';
  const U = raiz.UtilidadesJarvis, C = raiz.CulturaJarvis, B = raiz.BriefingJarvis, J = raiz.JogosJarvis;
  if (!U || !C || !B || !J) return;

  const el = (id) => document.getElementById(id);
  const txt = (id, v) => { const n = el(id); if (n) n.textContent = v; };
  let jogo = null, tipoJogo = '';

  function abrir(aba) {
    const nav = raiz.JarvisNavegacao;
    if (nav && typeof nav.abrirPainel === 'function') nav.abrirPainel('#painel-utilidades');
    else { const p = el('painel-utilidades'); if (p) p.hidden = false; }
    selecionar(aba || 'calc');
  }
  function fechar() {
    const nav = raiz.JarvisNavegacao;
    if (nav && typeof nav.fecharPaineis === 'function') nav.fecharPaineis();
    else { const p = el('painel-utilidades'); if (p) p.hidden = true; }
  }
  function selecionar(aba) {
    document.querySelectorAll('[data-util-tab]').forEach((b) => b.setAttribute('aria-selected', String(b.dataset.utilTab === aba)));
    document.querySelectorAll('[data-util-secao]').forEach((s) => { s.hidden = s.dataset.utilSecao !== aba; });
    if (aba === 'cultura') renderCultura();
    if (aba === 'jogos' && !jogo) novoJogo('');
  }

  /* ---------- Calculadora ---------- */
  function calcular() {
    const expr = (el('util-calc-expr') || {}).value || '';
    const r = U.avaliar(expr);
    txt('util-calc-saida', r === null ? 'Não consegui calcular essa expressão. Use + - * / ^ ! raiz(), log(), sen(), cos() e parênteses.' : expr.trim() + ' = ' + U.formatar(r, 6));
  }
  function interpretarLivre() {
    const t = (el('util-calc-livre') || {}).value || '';
    const r = U.interpretar(t);
    txt('util-calc-saida', r ? r.texto : 'Ainda não entendi. Exemplos: “20% de 250”, “converter 10 km para milhas”, “imc 80 1,80”, “senha de 16”, “fatorial de 6”.');
  }

  /* ---------- Conversões ---------- */
  const UNIDADES = ['mm', 'cm', 'm', 'km', 'pol', 'pe', 'milha', 'g', 'kg', 't', 'libra', 'onca', 'ml', 'l', 'galao', 'm/s', 'km/h', 'mph', 'no', 's', 'min', 'h', 'dia', 'kb', 'mb', 'gb', 'tb', 'm2', 'hectare', 'c', 'f', 'k'];
  function preencherUnidades() {
    ['util-conv-de', 'util-conv-para'].forEach((id) => {
      const s = el(id); if (!s || s.options.length) return;
      UNIDADES.forEach((u) => { const o = document.createElement('option'); o.value = u; o.textContent = u; s.appendChild(o); });
    });
    const de = el('util-conv-de'), para = el('util-conv-para');
    if (de) de.value = 'km';
    if (para) para.value = 'milha';
  }
  function converter() {
    const valor = (el('util-conv-valor') || {}).value;
    const de = (el('util-conv-de') || {}).value, para = (el('util-conv-para') || {}).value;
    const r = U.converter(valor, de, para);
    txt('util-conv-saida', r ? U.formatar(valor, 4) + ' ' + de + ' = ' + U.formatar(r.valor, 4) + ' ' + para : 'Essas unidades não são compatíveis. Use comprimento, massa, volume, velocidade, tempo, dados, área ou temperatura.');
  }

  /* ---------- Saúde ---------- */
  function saude() {
    const peso = (el('util-saude-peso') || {}).value, altura = (el('util-saude-altura') || {}).value;
    const idade = (el('util-saude-idade') || {}).value, sexo = (el('util-saude-sexo') || {}).value || 'm';
    const imc = U.imc(peso, altura);
    if (!imc) return txt('util-saude-saida', 'Informe peso em kg e altura em metros (ou centímetros).');
    // A altura pode vir com vírgula ("1,80") ou em centímetros ("180"); o núcleo usa a mesma regra.
    const alturaNum = U.numero(altura);
    const alturaCm = Number.isFinite(alturaNum) ? (alturaNum <= 3 ? alturaNum * 100 : alturaNum) : altura;
    const bmr = U.taxaMetabolica(sexo, peso, alturaCm, idade);
    let texto = 'IMC ' + U.formatar(imc.valor, 1) + ' — ' + imc.classe + '. Faixa saudável: ' + U.formatar(imc.pesoIdeal.min, 1) + ' a ' + U.formatar(imc.pesoIdeal.max, 1) + ' kg.';
    if (bmr) texto += ' Metabolismo basal estimado: ' + U.formatar(bmr.bmr, 0) + ' kcal/dia. Água sugerida: ' + bmr.aguaMl + ' ml/dia.';
    texto += ' Estimativas educativas, não substituem avaliação médica.';
    txt('util-saude-saida', texto);
  }

  /* ---------- Finanças ---------- */
  function financas() {
    const capital = (el('util-fin-capital') || {}).value, taxa = (el('util-fin-taxa') || {}).value;
    const n = (el('util-fin-periodos') || {}).value;
    const simples = U.jurosSimples(capital, taxa, n), composto = U.jurosCompostos(capital, taxa, n);
    if (!simples || !composto) return txt('util-fin-saida', 'Informe capital, taxa mensal em % e número de meses.');
    const parcela = U.parcelaPrice(capital, taxa, n);
    txt('util-fin-saida', 'Juros simples: R$ ' + U.formatar(simples.montante) + ' (juros R$ ' + U.formatar(simples.juros) + '). ' +
      'Juros compostos: R$ ' + U.formatar(composto.montante) + ' (juros R$ ' + U.formatar(composto.juros) + ').' +
      (parcela ? ' Parcela na tabela Price: R$ ' + U.formatar(parcela.parcela) + '.' : ''));
  }

  /* ---------- Jogos ---------- */
  function renderJogo(s) {
    if (!s) return;
    const simbolos = { certa: '🟩', presente: '🟨', ausente: '⬛' };
    let texto = '';
    if (s.tipo === 'velha') {
      const linhas = [];
      for (let l = 0; l < 3; l++) linhas.push(s.tabuleiro.slice(l * 3, l * 3 + 3).map((v, i) => v || String(l * 3 + i + 1)).join(' | '));
      texto = linhas.join('\n');
    } else if (s.tipo === 'ligue4') {
      texto = s.grade.map((l) => l.map((v) => v || '·').join(' ')).join('\n');
    } else if (s.tipo === 'forca') {
      texto = s.exibida + '\nErros: ' + s.erros + '/' + s.maxErros;
    } else if (s.tipo === 'blackjack') {
      texto = 'Você: ' + s.jogador.join(' ') + ' (' + s.pontosJogador + ')\nBanca: ' + s.banca.join(' ') + (s.pontosBanca != null ? ' (' + s.pontosBanca + ')' : '');
    } else if (s.tipo === 'ppt') {
      texto = 'Você ' + s.pontos.voce + ' × ' + s.pontos.maquina + ' máquina';
    } else if (s.tipo === 'adivinha') {
      texto = 'Chutes: ' + (s.chutes.join(', ') || '—') + '\nRestam ' + s.restantes + ' tentativas.';
    } else if (s.tipo === 'termo') {
      texto = s.tentativas.map((t) => t.palavra.toUpperCase() + '  ' + t.marcas.map((m) => simbolos[m]).join('')).join('\n') || 'Tente uma palavra de 5 letras.';
    } else if (s.tipo === 'roleta') {
      texto = 'Saldo: ' + s.saldo + ' fichas\n' + (s.historico || []).map((h) => '#' + h.numero + ' ' + (h.ganhou ? 'ganhou' : 'perdeu')).join(' · ');
    }
    const a = el('util-jogo-estado');
    if (a) a.textContent = texto + (s.mensagem ? '\n' + s.mensagem : '');
  }
  function novoJogo(tipo) {
    tipoJogo = tipo || (el('util-jogo-tipo') || {}).value || 'velha';
    jogo = J.criar(tipoJogo);
    renderJogo(jogo && jogo.estadoAtual ? jogo.estadoAtual() : null);
  }
  function jogar() {
    if (!jogo) novoJogo('');
    const v = (el('util-jogo-jogada') || {}).value || '';
    let s;
    if (tipoJogo === 'blackjack') s = jogo.acao(v);
    else if (tipoJogo === 'roleta') {
      const partes = v.trim().split(/\s+/);
      s = jogo.jogar(partes[0] === 'numero' ? { tipo: 'numero', numero: Number(partes[1]), valor: Number(partes[2]) } : { tipo: partes[0], valor: Number(partes[1]) });
    } else s = jogo.jogar(v);
    renderJogo(s);
    const i = el('util-jogo-jogada'); if (i) i.value = '';
  }

  /* ---------- Cultura ---------- */
  function renderCultura() {
    const alvo = el('util-cultura-lista');
    if (!alvo || alvo.dataset.pronto === '1') return;
    alvo.dataset.pronto = '1';
    C.receitas().forEach((nome) => {
      const b = document.createElement('button');
      b.type = 'button'; b.className = 'util-chip'; b.textContent = nome;
      b.addEventListener('click', () => mostrarReceita(nome));
      alvo.appendChild(b);
    });
  }
  function mostrarReceita(nome) {
    const r = C.receita(nome);
    if (!r) return;
    txt('util-cultura-saida', r.nome + ' (' + r.tempo + ' min, ' + r.porcoes + ' porção(ões))\nIngredientes: ' + r.ingredientes.join('; ') + '\nModo: ' + r.modo.join(' '));
  }
  function culturaAleatoria(tipo) {
    if (tipo === 'piada') return txt('util-cultura-saida', C.piada(Math.floor(Math.random() * 12)));
    if (tipo === 'curiosidade') return txt('util-cultura-saida', C.curiosidade(Math.floor(Math.random() * 12)));
    if (tipo === 'filme') return txt('util-cultura-saida', C.sugestao('filme').map((f) => '• ' + f.titulo + ' — ' + f.dica).join('\n'));
    if (tipo === 'serie') return txt('util-cultura-saida', C.sugestao('serie').map((f) => '• ' + f.titulo + ' — ' + f.dica).join('\n'));
    if (tipo === 'musica') return txt('util-cultura-saida', C.sugestao('musica').map((f) => '• ' + f.genero + ': ' + f.dica).join('\n'));
    if (tipo === 'tedio') return txt('util-cultura-saida', C.sugestao('tedio').map((f) => '• ' + f).join('\n'));
  }

  /* ---------- Briefing ---------- */
  function montarBriefing() {
    const hora = new Date().getHours();
    const nome = (el('util-brief-nome') || {}).value || '';
    const clima = (el('util-brief-clima') || {}).value || '';
    const tarefas = ((el('util-brief-tarefas') || {}).value || '').split('\n').map((s) => s.trim()).filter(Boolean);
    const manchetes = ((el('util-brief-manchetes') || {}).value || '').split('\n').map((s) => s.trim()).filter(Boolean);
    const r = B.montar({ nome, hora, clima, tarefas, manchetes });
    txt('util-brief-saida', r.texto + (r.faltando.length ? '\n\nSem dados de: ' + r.faltando.join('; ') + '.' : ''));
  }

  /* ---------- Comandos de chat/voz ---------- */
  function responder(texto) {
    const t = String(texto || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/\s+/g, ' ').trim();
    if (!t) return null;
    if (/^(abrir|mostrar|mostre) (a )?(central de )?utilidades$/.test(t)) { abrir('calc'); return 'Central de utilidades aberta: cálculo, conversões, saúde, finanças, jogos, cultura e briefing.'; }
    if (/^(abrir|mostrar) (a )?(central de )?jogos$/.test(t)) { abrir('jogos'); return 'Jogos disponíveis: ' + J.tipos().join(', ') + '.'; }
    let m = /^(?:jogar|comecar|começar) (?:o )?(.+)$/.exec(t);
    if (m) {
      const j = J.criar(m[1]);
      if (!j) return 'Não conheço esse jogo. Tenho: ' + J.tipos().join(', ') + '.';
      abrir('jogos'); tipoJogo = j.tipo; jogo = j;
      const s = el('util-jogo-tipo'); if (s) s.value = j.tipo;
      renderJogo(j.estadoAtual());
      return 'Jogo iniciado: ' + j.tipo + '. ' + J.ajuda().find((a) => a.startsWith(j.tipo));
    }
    m = /^(?:receita|como (?:fazer|preparar)) (?:de |do |da )?(.+)$/.exec(t);
    if (m) {
      const r = C.receita(m[1]);
      return r ? r.nome + ': ' + r.ingredientes.join('; ') + '. Modo: ' + r.modo.join(' ') : 'Não achei essa receita no acervo local. Receitas: ' + C.receitas().join(', ') + '.';
    }
    if (/^(?:me )?(?:conte |conta )?(?:uma )?piada$/.test(t)) return C.piada(new Date().getDate());
    if (/^(?:me )?(?:fale |diga )?(?:uma )?curiosidade$/.test(t)) return C.curiosidade(new Date().getDate());
    m = /^(?:sugira|sugere|me sugira|recomende|o que (?:assistir|ouvir|fazer))\s*(.*)$/.exec(t);
    if (m) {
      const pedido = m[1];
      const tipo = /filme|cinema/.test(pedido) ? 'filme' : /serie/.test(pedido) ? 'serie' : /musica|ouvir|playlist/.test(pedido) ? 'musica' : 'tedio';
      const lista = C.sugestao(tipo);
      if (Array.isArray(lista)) return lista.map((x) => typeof x === 'string' ? '• ' + x : '• ' + x.titulo + ' — ' + x.dica).join('\n');
      return lista.map((x) => '• ' + x.genero + ': ' + x.dica).join('\n');
    }
    if (/^(?:briefing|resumo do dia|bom dia jarvis)$/.test(t)) {
      const r = B.montar({ hora: new Date().getHours() });
      return r.texto + ' Abra “Utilidades ▸ Briefing” para incluir clima, agenda e manchetes reais.';
    }
    if (/^quanto (?:custa|vale) (?:o )?(?:dolar|euro)/.test(t)) return 'Cotação exige consulta online; sem fonte configurada eu não invento taxa. Use “Utilidades ▸ Finanças” para simular com a taxa que você informar.';
    const r = U.interpretar(texto);
    return r ? r.texto : null;
  }

  function iniciar() {
    if (!el('painel-utilidades')) return;
    preencherUnidades();
    const liga = (id, tipo, fn) => { const n = el(id); if (n) n.addEventListener(tipo, fn); };
    liga('util-calc-ver', 'click', calcular);
    liga('util-calc-expr', 'keydown', (e) => { if (e.key === 'Enter') calcular(); });
    liga('util-calc-livre-ver', 'click', interpretarLivre);
    liga('util-calc-livre', 'keydown', (e) => { if (e.key === 'Enter') interpretarLivre(); });
    liga('util-conv-ver', 'click', converter);
    liga('util-saude-ver', 'click', saude);
    liga('util-fin-ver', 'click', financas);
    liga('util-jogo-novo', 'click', () => novoJogo(''));
    liga('util-jogo-tipo', 'change', () => novoJogo(''));
    liga('util-jogo-enviar', 'click', jogar);
    liga('util-jogo-jogada', 'keydown', (e) => { if (e.key === 'Enter') jogar(); });
    liga('util-cultura-piada', 'click', () => culturaAleatoria('piada'));
    liga('util-cultura-curiosidade', 'click', () => culturaAleatoria('curiosidade'));
    liga('util-cultura-filme', 'click', () => culturaAleatoria('filme'));
    liga('util-cultura-serie', 'click', () => culturaAleatoria('serie'));
    liga('util-cultura-musica', 'click', () => culturaAleatoria('musica'));
    liga('util-cultura-tedio', 'click', () => culturaAleatoria('tedio'));
    liga('util-brief-ver', 'click', montarBriefing);
    liga('util-fechar', 'click', fechar);
    const dash = el('dash-utilidades');
    if (dash) dash.addEventListener('click', () => abrir('calc'));
    document.querySelectorAll('[data-util-tab]').forEach((b) => b.addEventListener('click', () => selecionar(b.dataset.utilTab)));
    document.querySelectorAll('[data-util-abrir]').forEach((b) => b.addEventListener('click', () => abrir(b.dataset.utilAbrir)));
  }

  raiz.UtilidadesUI = { abrir, fechar, selecionar, responder, novoJogo, calcular, converter };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', iniciar);
  else iniciar();
})(typeof window !== 'undefined' ? window : globalThis);
