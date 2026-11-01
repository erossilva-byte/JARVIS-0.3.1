/* J.A.R.V.I.S. Nova 1.35.0 — painel do Core.
 * Só apresenta o que o core.js devolve. Nenhum número é inventado no DOM.
 */
(function (raiz, doc) {
  'use strict';
  var ultimoDiag = null;

  function $(s) { return doc.querySelector(s); }
  function core() { return raiz.JarvisCore || null; }
  function el(tag, cls, txt) {
    var n = doc.createElement(tag);
    if (cls) n.className = cls;
    if (txt != null) n.textContent = txt;
    return n;
  }
  function texto(id, v) { var n = doc.getElementById(id); if (n) n.textContent = v; }
  function vazio(caixa, msg) { if (!caixa) return; caixa.textContent = ''; caixa.appendChild(el('p', 'dica', msg)); }

  function renderStatus() {
    var c = core(), s = c && c.status ? c.status() : null;
    if (!s) { texto('core-status', 'Core indisponível: o módulo core.js não carregou.'); return; }
    texto('core-status', 'Core v' + s.versao + ' · ' + s.agentes + ' agentes · ' + s.agentesComExecutor + ' com executor · ' +
      s.projetos + ' projeto(s) · ' + s.componentes + ' componente(s) monitorado(s) · ' + (s.recuperacoes || 0) + ' recuperação(ões) · vigia ' + (s.vigia ? 'ativo' : 'parado') + '.');
    var ctx = c.contexto();
    var p = c.projetoAtual();
    texto('core-contexto', 'Projeto ativo: ' + (p ? p.nome : 'nenhum') + ' · último agente: ' + (ctx.ultimoAgente || '—') +
      ' · último pedido: ' + (ctx.ultimoPedido || '—') + '.');
    var integ = s.integracoes || {};
    texto('core-integracoes', 'Integrações: MCP ' + integ.mcp.replace(/_/g, ' ') + ' · RAG vetorial ' +
      integ.rag_vetorial.replace(/_/g, ' ') + ' · TV/ESP32 ' + integ.tv_esp32.replace(/_/g, ' ') + ' · pareamento PC ' + integ.pareamento_pc.replace(/_/g, ' ') + '.');
  }

  function renderAgentes() {
    var caixa = doc.getElementById('core-agentes'); if (!caixa) return;
    var c = core(); if (!c) { vazio(caixa, 'Core não carregado.'); return; }
    caixa.textContent = '';
    c.listarAgentes().forEach(function (a) {
      var card = el('div', 'core-agent');
      var topo = el('div', 'core-agent-topo');
      topo.appendChild(el('b', '', a.nome));
      topo.appendChild(el('span', 'core-badge ' + (a.estado === 'com executor' ? 'ok' : ''), a.estado));
      topo.appendChild(el('span', 'core-badge', a.cobertura));
      card.appendChild(topo);
      card.appendChild(el('p', '', a.descricao));
      card.appendChild(el('small', '', 'Permissões: ' + a.permissoes.join(', ') + ' · Limite: ' + a.naoFaz));
      caixa.appendChild(card);
    });
  }

  function renderProjetos() {
    var caixa = doc.getElementById('core-projetos'); if (!caixa) return;
    var c = core(); if (!c) { vazio(caixa, 'Core não carregado.'); return; }
    var lista = c.listarProjetos();
    caixa.textContent = '';
    if (!lista.length) { vazio(caixa, 'Nenhum projeto criado. Crie um abaixo; ele fica neste aparelho e pode ser exportado.'); return; }
    var ativo = c.projetoAtual();
    lista.forEach(function (p) {
      var card = el('div', 'core-projeto');
      var topo = el('div', 'core-agent-topo');
      topo.appendChild(el('b', '', p.nome));
      if (ativo && ativo.id === p.id) topo.appendChild(el('span', 'core-badge ok', 'ativo'));
      topo.appendChild(el('span', 'core-badge', (p.tarefas || []).length + ' tarefa(s)'));
      card.appendChild(topo);
      if (p.objetivo) card.appendChild(el('small', '', p.objetivo));
      var acoes = el('div', 'core-acoes');
      var abrir = el('button', 'mini', 'Abrir');
      abrir.type = 'button'; abrir.setAttribute('data-core-projeto-abrir', p.id);
      var excluir = el('button', 'mini perigo', 'Excluir');
      excluir.type = 'button'; excluir.setAttribute('data-core-projeto-excluir', p.id);
      acoes.appendChild(abrir); acoes.appendChild(excluir);
      card.appendChild(acoes);
      caixa.appendChild(card);
    });
  }

  function renderSaude() {
    var caixa = doc.getElementById('core-saude'); if (!caixa) return;
    var c = core(); if (!c) { vazio(caixa, 'Core não carregado.'); return; }
    var d = ultimoDiag || c.status().ultimoDiagnostico;
    caixa.textContent = '';
    if (!d || !d.itens) { vazio(caixa, 'Nenhum diagnóstico executado nesta sessão. Use “Diagnosticar Core”.'); return; }
    d.itens.forEach(function (i) {
      var linha = el('div', 'core-saude-linha ' + (i.status === 'falhou' ? 'falhou' : i.status === 'aviso' ? 'aviso' : 'ok'));
      linha.appendChild(el('b', '', i.nome || i.id));
      var detalhe = i.status + (i.detalhe ? ' · ' + i.detalhe : '') + (i.duracaoMs != null ? ' · ' + i.duracaoMs + ' ms' : '');
      if (i.causa) detalhe += ' · causa: ' + i.causa;
      if (i.recuperavel) detalhe += i.recuperacaoAutomatica ? ' · recuperação automática segura' : ' · recuperação manual';
      linha.appendChild(el('span', '', detalhe));
      if (i.orientacao) linha.appendChild(el('small', 'core-orientacao', 'Como resolver: ' + i.orientacao));
      caixa.appendChild(linha);
    });
    texto('core-saude-resumo', 'Status: ' + d.status + ' · ' + d.falhas + ' falha(s) · ' + (d.avisos || 0) + ' aviso(s) · ' + d.duracaoMs + ' ms.');
  }

  function renderHabilidades() {
    var caixa = doc.getElementById('core-habilidades'); if (!caixa) return;
    var c = core(); if (!c) { vazio(caixa, 'Core não carregado.'); return; }
    var lista = c.listarHabilidades();
    caixa.textContent = '';
    if (!lista.length) { vazio(caixa, 'Nenhuma habilidade registrada no SISTEMA.'); return; }
    lista.forEach(function (h) {
      var linha = el('label', 'core-habilidade');
      var chk = doc.createElement('input'); chk.type = 'checkbox'; chk.checked = !!h.habilitada;
      chk.setAttribute('data-core-habilidade', h.id);
      linha.appendChild(chk);
      var info = el('span');
      info.appendChild(el('b', '', h.nome + ' · ' + h.id));
      info.appendChild(el('small', '', h.descricao + (h.origem === 'sistema' ? ' · ferramenta do SISTEMA' : ' · habilidade local') + (h.risco ? ' · risco ' + h.risco : '')));
      linha.appendChild(info);
      caixa.appendChild(linha);
    });
  }

  function renderRecuperacoes() {
    var caixa = doc.getElementById('core-recuperacoes'); if (!caixa) return;
    var c = core(); if (!c || !c.listarRecuperacoes) { vazio(caixa, 'Histórico de recuperação indisponível.'); return; }
    var lista = c.listarRecuperacoes().slice(-8).reverse();
    caixa.textContent = '';
    if (!lista.length) { vazio(caixa, 'Nenhuma tentativa registrada. O botão acima só tenta componentes que declararam recuperação segura.'); return; }
    lista.forEach(function (r) {
      var linha = el('div', 'core-rec ' + (r.status === 'recuperado' ? 'ok' : 'falhou'));
      linha.appendChild(el('b', '', r.componente));
      linha.appendChild(el('span', '', r.status + ' · ' + (r.causa || 'causa não classificada') + (r.detalhe ? ' · ' + r.detalhe : '') + (r.duracaoMs != null ? ' · ' + r.duracaoMs + ' ms' : '')));
      caixa.appendChild(linha);
    });
  }

  function render() { renderStatus(); renderAgentes(); renderProjetos(); renderSaude(); renderRecuperacoes(); renderHabilidades(); }

  async function recuperar() {
    var c = core(); if (!c) return;
    var b = doc.getElementById('core-recuperar');
    if (b) { b.disabled = true; b.textContent = 'Recuperando…'; }
    try {
      var d = await c.diagnosticar({ recuperarAutomatico: false });
      var r = await c.recuperarFalhas({ diagnostico: d });
      ultimoDiag = d;
      texto('core-recuperacao-status', r.tentadas
        ? r.recuperados + ' recuperado(s) de ' + r.tentadas + ' tentativa(s); ' + r.falharam + ' falhou(aram); ' + r.ignorados + ' sem recuperação declarada.'
        : (d.falhas ? 'Há ' + d.falhas + ' falha(s) sem recuperação segura declarada. Nada foi reiniciado.' : 'Nenhuma falha para recuperar.'));
      renderSaude(); renderRecuperacoes(); renderStatus();
    } catch (e) {
      texto('core-recuperacao-status', 'Recuperação falhou: ' + ((e && e.message) || e));
    } finally { if (b) { b.disabled = false; b.textContent = 'Tentar recuperar falhas'; } }
  }

  async function diagnosticar() {
    var c = core(); if (!c) return;
    var b = doc.getElementById('core-diag');
    if (b) { b.disabled = true; b.textContent = 'Diagnosticando…'; }
    try {
      ultimoDiag = await c.diagnosticar({ recuperarAutomatico: false });
      renderSaude(); renderRecuperacoes(); renderStatus();
      texto('core-saude-resumo', 'Status: ' + ultimoDiag.status + ' · ' + ultimoDiag.falhas + ' falha(s) · ' + (ultimoDiag.avisos || 0) + ' aviso(s) · ' + ultimoDiag.duracaoMs + ' ms.');
    } catch (e) {
      texto('core-saude-resumo', 'Diagnóstico falhou: ' + ((e && e.message) || e));
    } finally {
      if (b) { b.disabled = false; b.textContent = 'Diagnosticar Core'; }
    }
  }

  function criarProjeto() {
    var c = core(); if (!c) return;
    var campo = doc.getElementById('core-projeto-nome');
    var r = c.criarProjeto(campo ? campo.value : '');
    texto('core-projeto-status', r.ok ? 'Projeto ' + (r.existente ? 'já existia e foi aberto' : 'criado') + ': ' + r.projeto.nome + '.' : r.erro);
    if (r.ok && campo) campo.value = '';
    renderProjetos(); renderStatus();
  }

  function ligar() {
    var abrir = doc.getElementById('core-atualizar'); if (abrir) abrir.onclick = render;
    var diag = doc.getElementById('core-diag'); if (diag) diag.onclick = diagnosticar;
    var rec = doc.getElementById('core-recuperar'); if (rec) rec.onclick = recuperar;
    var criar = doc.getElementById('core-projeto-criar'); if (criar) criar.onclick = criarProjeto;
    var projeto = doc.getElementById('core-projeto-nome');
    if (projeto) projeto.addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); criarProjeto(); } });
    var vigia = doc.getElementById('core-vigia');
    if (vigia) vigia.onclick = function () {
      var c = core(); if (!c) return;
      if (c.vigiaAtivo()) { c.pararVigia(); texto('core-vigia-status', 'Vigia parado.'); }
      else { var r = c.iniciarVigia(120000); texto('core-vigia-status', 'Vigia ativo a cada ' + Math.round(r.intervaloMs / 1000) + ' s; ele apenas diagnostica e registra, não reinicia serviços.'); }
      renderStatus(); vigia.textContent = c.vigiaAtivo() ? 'Parar vigia' : 'Iniciar vigia';
    };
    var lista = doc.getElementById('core-projetos');
    if (lista) lista.addEventListener('click', function (e) {
      var c = core(); if (!c) return;
      var alvo = e.target.closest ? e.target.closest('[data-core-projeto-abrir],[data-core-projeto-excluir]') : null;
      if (!alvo) return;
      var id = alvo.getAttribute('data-core-projeto-abrir') || alvo.getAttribute('data-core-projeto-excluir');
      if (alvo.hasAttribute('data-core-projeto-abrir')) {
        var r = c.abrirProjeto(id); texto('core-projeto-status', r.ok ? 'Projeto ativo: ' + r.projeto.nome + '.' : r.erro);
      } else {
        var x = c.excluirProjeto(id); texto('core-projeto-status', x.ok ? 'Projeto removido: ' + x.removido + '.' : x.erro);
      }
      renderProjetos(); renderStatus();
    });
    var hab = doc.getElementById('core-habilidades');
    if (hab) hab.addEventListener('change', function (e) {
      var chk = e.target.closest ? e.target.closest('[data-core-habilidade]') : null;
      if (!chk) return;
      var c = core(); if (!c) return;
      c.alternarHabilidade(chk.getAttribute('data-core-habilidade'), chk.checked);
      texto('core-habilidade-status', 'Alteração salva. Isso controla o escopo do Core; o SISTEMA continua pedindo confirmação para risco.');
    });
    var fechar = doc.getElementById('core-fechar');
    if (fechar) fechar.onclick = function () { if (raiz.JarvisNavegacao) raiz.JarvisNavegacao.fecharPaineis(); };
    var exp = doc.getElementById('core-exportar');
    if (exp) exp.onclick = function () {
      var c = core(); if (!c) return;
      var blob = new Blob([c.exportar()], { type: 'application/json' });
      var a = doc.createElement('a'); a.href = URL.createObjectURL(blob); a.download = 'jarvis-core-contexto.json';
      doc.body.appendChild(a); a.click(); a.remove(); setTimeout(function () { URL.revokeObjectURL(a.href); }, 1000);
    };
  }

  function abrir() {
    if (raiz.JarvisNavegacao && typeof raiz.JarvisNavegacao.abrirPainel === 'function') raiz.JarvisNavegacao.abrirPainel('#painel-core');
    render();
  }

  raiz.JarvisCoreUI = { abrir: abrir, atualizar: render, diagnosticar: diagnosticar };
  if (doc.readyState === 'loading') doc.addEventListener('DOMContentLoaded', ligar, { once: true });
  else ligar();
})(window, document);
