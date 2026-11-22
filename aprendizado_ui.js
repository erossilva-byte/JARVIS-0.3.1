/* J.A.R.V.I.S. Nova 1.36.0 — painel de aprendizado explícito.
 * Só mostra e altera o que o módulo aprendeu. Nenhum dado é inferido no DOM.
 */
(function (raiz, doc) {
  'use strict';

  var CHAVE = 'jv_aprendizado_ativo';
  function $(s) { return doc.querySelector(s); }
  function mod() { return raiz.JarvisAprendizado || null; }
  function el(tag, cls, txt) { var n = doc.createElement(tag); if (cls) n.className = cls; if (txt != null) n.textContent = txt; return n; }
  function texto(id, v) { var n = doc.getElementById(id); if (n) n.textContent = v; }
  function ativo() { try { return raiz.localStorage.getItem(CHAVE) !== '0'; } catch (e) { return true; } }

  function render() {
    var m = mod();
    var caixa = doc.getElementById('aprend-lista');
    var resumo = doc.getElementById('aprend-resumo');
    var ctx = doc.getElementById('aprend-contexto');
    if (!m) {
      if (caixa) { caixa.textContent = ''; caixa.appendChild(el('p', 'dica', 'Módulo de aprendizado não carregou neste pacote.')); }
      if (resumo) resumo.textContent = 'Indisponível.';
      return;
    }
    var lista = m.listar();
    var r = m.resumo();
    if (resumo) resumo.textContent = r.total + ' aprendizado(s) · ' + r.ativos + ' ativo(s) · ' + r.correcoes + ' correção(ões) · ' + Math.round(r.bytes / 1024) + ' kB. ' + (ativo() ? 'Aplicado ao prompt.' : 'Salvo, mas não aplicado.');
    if (ctx) ctx.textContent = m.contexto() || '(nenhum aprendizado entra no prompt agora)';
    if (!caixa) return;
    caixa.textContent = '';
    if (!lista.length) { caixa.appendChild(el('p', 'dica', 'Nada aprendido ainda. Use uma instrução explícita acima ou diga “Jarvis, prefiro respostas curtas”.')); return; }
    lista.forEach(function (x) {
      var item = el('div', 'aprend-item');
      var info = el('div');
      info.appendChild(el('b', '', x.tipo + ' · ' + Math.round(Number(x.confianca || 0) * 100) + '%'));
      info.appendChild(el('small', '', x.texto + (x.repetido ? ' · reforçado ' + x.repetido + '×' : '')));
      item.appendChild(info);
      var rem = el('button', 'secundario', 'Remover');
      rem.type = 'button';
      rem.setAttribute('data-aprend-remover', x.id);
      item.appendChild(rem);
      caixa.appendChild(item);
    });
  }

  function adicionar() {
    var m = mod(), campo = doc.getElementById('aprend-texto');
    if (!m || !campo) return;
    var r = m.observar(campo.value, { fonte: 'painel' });
    texto('aprend-status', r.ok ? 'Registrado: ' + r.item.texto : (r.motivo || r.erro || 'Não foi possível registrar.'));
    if (r.ok) { campo.value = ''; render(); }
  }

  function exportar() {
    var m = mod(); if (!m) return;
    try {
      var conteudo = m.exportar();
      var blob = new Blob([conteudo], { type: 'application/json;charset=utf-8' });
      var url = URL.createObjectURL(blob);
      var a = doc.createElement('a');
      a.href = url; a.download = 'jarvis-aprendizado.json';
      doc.body.appendChild(a); a.click(); a.remove();
      setTimeout(function () { URL.revokeObjectURL(url); }, 1500);
      texto('aprend-status', 'Backup exportado com os aprendizados locais.');
    } catch (e) { texto('aprend-status', 'Não foi possível exportar: ' + ((e && e.message) || e)); }
  }

  function limpar() {
    var m = mod(); if (!m) return;
    if (typeof raiz.confirm === 'function' && !raiz.confirm('Apagar todos os aprendizados locais? Isso não apaga memórias, perfis ou configurações.')) return;
    var r = m.limparTudo();
    texto('aprend-status', r.ok ? r.removidos + ' aprendizado(s) apagado(s).' : (r.erro || 'Não foi possível apagar.'));
    render();
  }

  function iniciar() {
    var toggle = doc.getElementById('aprend-ativo');
    if (toggle) {
      toggle.checked = ativo();
      toggle.onchange = function () {
        try { raiz.localStorage.setItem(CHAVE, toggle.checked ? '1' : '0'); } catch (e) { /* armazenamento indisponível */ }
        render();
      };
    }
    var add = doc.getElementById('aprend-adicionar'); if (add) add.onclick = adicionar;
    var exp = doc.getElementById('aprend-exportar'); if (exp) exp.onclick = exportar;
    var lim = doc.getElementById('aprend-limpar'); if (lim) lim.onclick = limpar;
    var lista = doc.getElementById('aprend-lista');
    if (lista) lista.addEventListener('click', function (e) {
      var alvo = e.target.closest ? e.target.closest('[data-aprend-remover]') : null;
      if (!alvo) return;
      var m = mod(); if (!m) return;
      var r = m.remover(alvo.getAttribute('data-aprend-remover'));
      texto('aprend-status', r.ok ? 'Aprendizado removido.' : (r.erro || 'Não encontrado.'));
      render();
    });
    var campo = doc.getElementById('aprend-texto');
    if (campo) campo.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) { e.preventDefault(); adicionar(); }
    });
    render();
  }

  raiz.JarvisAprendizadoUI = { iniciar: iniciar, render: render };
  if (doc.readyState === 'loading') doc.addEventListener('DOMContentLoaded', iniciar);
  else iniciar();
})(typeof window !== 'undefined' ? window : null, typeof document !== 'undefined' ? document : null);
