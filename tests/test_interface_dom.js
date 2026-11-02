/* Teste de interação real da interface (jsdom): cada cartão de área é clicado,
 * cada ação é acionada e o núcleo/transcrição são conferidos sem abrir o APK.
 * Não substitui teste em aparelho, mas pega o clique perdido e a delegação quebrada.
 */
'use strict';
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

const root = path.resolve(__dirname, '..');
let html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
html = html.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '');
const dom = new JSDOM(html, {
  url: 'http://localhost/',
  runScripts: 'outside-only',
  pretendToBeVisual: true
});
const { window } = dom;
const { document } = window;
const chamadas = [];
window.JarvisNavegacao = {
  acao: (nome) => chamadas.push(nome),
  abrirAreas: () => chamadas.push('abrir-areas'),
  abrirPainel: () => {},
  fecharPaineis: () => {}
};
window.eval(fs.readFileSync(path.join(root, 'interface.js'), 'utf8'));
if (!document.querySelector('.area-card')) document.dispatchEvent(new window.Event('DOMContentLoaded'));

let verificacoes = 0;
function ok(nome, condicao) {
  verificacoes++;
  assert.ok(condicao, nome);
  console.log('OK: ' + nome);
}

ok('boot nasce visível e o corpo começa travado',
  !document.getElementById('boot').hidden && document.body.classList.contains('travado'));
ok('não existe botão Conversa no menu', !document.getElementById('btn-conversa'));
ok('a transcrição é a entrada secundária', !!document.getElementById('btn-transcricao'));
ok('a resposta central existe e começa oculta',
  !!document.getElementById('resposta-atual') && document.getElementById('resposta-atual').hidden);
ok('as dez áreas foram montadas', document.querySelectorAll('.area-card').length === 10);

const cards = Array.from(document.querySelectorAll('.area-card'));
const lista = window.JarvisAreas.lista;
for (let i = 0; i < cards.length; i++) {
  const card = cards[i];
  const area = lista[i];
  card.click();
  const inicio = document.getElementById('areas-inicio');
  const detalhe = document.getElementById('areas-detalhe');
  ok('cartão abre a área: ' + area.nome,
    inicio.hidden === true && detalhe.hidden === false && detalhe.textContent.indexOf(area.nome) !== -1);
  const acoes = Array.from(detalhe.querySelectorAll('[data-area-acao]'));
  ok('a área mostra todas as ações: ' + area.nome, acoes.length === area.acoes.length);
  for (let j = 0; j < acoes.length; j++) {
    const esperado = acoes[j].getAttribute('data-area-acao');
    const antes = chamadas.length;
    acoes[j].click();
    ok('ação responde: ' + area.nome + ' › ' + acoes[j].querySelector('b').textContent,
      chamadas.length === antes + 1 && chamadas[chamadas.length - 1] === esperado);
  }
  detalhe.querySelector('[data-area-voltar]').click();
  ok('volta ao mapa depois de: ' + area.nome,
    inicio.hidden === false && detalhe.hidden === true);
}
ok('todas as áreas foram exercitadas', cards.length === 10 && chamadas.length > 0);
console.log('\nInterface: ' + verificacoes + ' verificações de DOM aprovadas.');
