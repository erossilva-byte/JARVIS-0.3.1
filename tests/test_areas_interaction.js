'use strict';
// Exercita os botões reais gerados por interface.js com um DOM mínimo, sem depender de
// navegador externo: cada cartão, cada ação e o botão de retorno precisam disparar.
const fs = require('fs');
const vm = require('vm');
const assert = require('assert');

class FakeElement {
  constructor(tag) {
    this.tagName = String(tag || 'div').toUpperCase();
    this.children = [];
    this.attributes = {};
    this.listeners = {};
    this.hidden = false;
    this.className = '';
    this.type = '';
    this._text = '';
    this.classList = {
      toggle: () => {},
      add: () => {},
      remove: () => {}
    };
  }
  set textContent(value) { this._text = String(value == null ? '' : value); this.children = []; }
  get textContent() { return this._text + this.children.map(x => x.textContent).join(''); }
  appendChild(child) { this.children.push(child); child.parentNode = this; return child; }
  addEventListener(type, fn) { (this.listeners[type] ||= []).push(fn); }
  dispatch(type) { for (const fn of (this.listeners[type] || [])) fn({ target: this, preventDefault() {} }); }
  setAttribute(name, value) { this.attributes[name] = String(value); }
  getAttribute(name) { return Object.prototype.hasOwnProperty.call(this.attributes, name) ? this.attributes[name] : null; }
  hasAttribute(name) { return Object.prototype.hasOwnProperty.call(this.attributes, name); }
  scrollIntoView() {}
}
const ids = ['areas-grid','areas-inicio','areas-detalhe','areas-status','modo-status','modo-aviso'];
const nodes = Object.fromEntries(ids.map(id => [id, new FakeElement('div')]));
const document = {
  readyState: 'complete',
  body: new FakeElement('body'),
  getElementById: id => nodes[id] || null,
  createElement: tag => new FakeElement(tag),
  querySelectorAll: () => [],
  addEventListener: () => {}
};
const chamadas = [];
const window = {
  localStorage: { getItem: () => null, setItem: () => {} },
  dispatchEvent: () => {},
  addEventListener: () => {},
  JarvisNavegacao: {
    acao: nome => { chamadas.push(nome); return true; },
    abrirAreas: () => true,
    fecharPaineis: () => true,
    silenciar: () => {}
  }
};
class CustomEvent { constructor(type, options) { this.type = type; this.detail = options && options.detail; } }
vm.runInNewContext(fs.readFileSync('interface.js', 'utf8'), { window, document, CustomEvent, console });

const areas = window.JarvisAreas.lista;
const cards = nodes['areas-grid'].children;
assert.strictEqual(cards.length, areas.length, 'todos os cartões de área devem ser renderizados');

function descendants(root, attr, out = []) {
  if (root.hasAttribute && root.hasAttribute(attr)) out.push(root);
  for (const child of root.children || []) descendants(child, attr, out);
  return out;
}

let totalAcoes = 0;
for (let i = 0; i < cards.length; i++) {
  const card = cards[i];
  card.dispatch('click');
  assert.strictEqual(nodes['areas-inicio'].hidden, true, 'o cartão deve abrir a área ' + areas[i].id);
  assert.strictEqual(nodes['areas-detalhe'].hidden, false, 'o detalhe deve ficar visível: ' + areas[i].id);
  const botoes = descendants(nodes['areas-detalhe'], 'data-area-acao');
  assert.strictEqual(botoes.length, areas[i].acoes.length, 'ações renderizadas para ' + areas[i].id);
  for (let j = 0; j < botoes.length; j++) {
    const esperado = areas[i].acoes[j].acao;
    botoes[j].dispatch('click');
    assert.strictEqual(chamadas[chamadas.length - 1], esperado, 'ação deve chegar ao roteador: ' + areas[i].id + '/' + esperado);
    totalAcoes++;
  }
  const voltar = descendants(nodes['areas-detalhe'], 'data-area-voltar')[0];
  assert.ok(voltar, 'botão voltar ausente em ' + areas[i].id);
  voltar.dispatch('click');
  assert.strictEqual(nodes['areas-inicio'].hidden, false, 'voltar deve restaurar a grade: ' + areas[i].id);
  assert.strictEqual(nodes['areas-detalhe'].hidden, true, 'voltar deve ocultar o detalhe: ' + areas[i].id);
}
assert.strictEqual(totalAcoes, areas.reduce((n, area) => n + area.acoes.length, 0));
console.log('OK: ' + cards.length + ' áreas abertas individualmente; ' + totalAcoes + ' ações encaminhadas; retorno validado.');
