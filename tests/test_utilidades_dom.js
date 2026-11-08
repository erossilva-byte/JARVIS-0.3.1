/* Teste de interação real da Central de Utilidades (jsdom).
 * Clica nos botões como o usuário faria: cálculo, conversão, saúde, finanças, jogo, cultura,
 * briefing e comandos do chat. Não substitui o aparelho, mas pega painel sem listener,
 * campo não ligado e comando que não chega ao cérebro local.
 */
'use strict';
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

const root = path.resolve(__dirname, '..');
let html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
html = html.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '');
const dom = new JSDOM(html, { url: 'http://localhost/', runScripts: 'outside-only', pretendToBeVisual: true });
const { window } = dom;
const { document } = window;

const erros = [];
window.addEventListener('error', (e) => erros.push(e.message || 'erro de script'));
for (const f of ['utilidades.js', 'cultura.js', 'briefing.js', 'jogos.js', 'utilidades_ui.js']) {
  window.eval(fs.readFileSync(path.join(root, f), 'utf8'));
}
document.dispatchEvent(new window.Event('DOMContentLoaded'));

const $ = (id) => document.getElementById(id);
const set = (id, v) => { $(id).value = v; };
const click = (id) => $(id).dispatchEvent(new window.Event('click', { bubbles: true }));
let n = 0;
function ok(nome, cond) { n++; assert.ok(cond, nome); console.log('OK: ' + nome); }

ok('a central existe e começa fechada', !!$('painel-utilidades') && $('painel-utilidades').hidden === true);
ok('a interface pública foi exposta', !!window.UtilidadesUI && typeof window.UtilidadesUI.responder === 'function');

window.UtilidadesUI.abrir('calc');
ok('abrir mostra o painel', $('painel-utilidades').hidden === false);
ok('a aba de cálculo fica visível', document.querySelector('[data-util-secao="calc"]').hidden === false);
ok('as outras abas ficam ocultas', document.querySelector('[data-util-secao="jogos"]').hidden === true);

set('util-calc-expr', '2+3*4');
click('util-calc-ver');
ok('calculadora responde no DOM', $('util-calc-saida').textContent.indexOf('14') !== -1);

set('util-calc-livre', '20% de 250');
click('util-calc-livre-ver');
ok('pedido em português é interpretado', /50/.test($('util-calc-saida').textContent));

window.UtilidadesUI.selecionar('conversao');
ok('unidades foram preenchidas', $('util-conv-de').options.length > 8);
set('util-conv-valor', '10');
$('util-conv-de').value = 'km';
$('util-conv-para').value = 'milha';
click('util-conv-ver');
ok('conversão km → milha no DOM', /6,2137|6\.2137/.test($('util-conv-saida').textContent));
$('util-conv-para').value = 'kg';
click('util-conv-ver');
ok('unidades incompatíveis são recusadas', /não são compatíveis/.test($('util-conv-saida').textContent));

window.UtilidadesUI.selecionar('saude');
set('util-saude-peso', '80'); set('util-saude-altura', '1,80'); set('util-saude-idade', '30');
click('util-saude-ver');
ok('IMC e metabolismo aparecem', /IMC 24,7/.test($('util-saude-saida').textContent) && /Metabolismo basal/.test($('util-saude-saida').textContent));

window.UtilidadesUI.selecionar('financas');
set('util-fin-capital', '1000'); set('util-fin-taxa', '1'); set('util-fin-periodos', '12');
click('util-fin-ver');
ok('juros compostos no DOM', /1\.126,83|1126,83/.test($('util-fin-saida').textContent));

window.UtilidadesUI.selecionar('jogos');
$('util-jogo-tipo').value = 'velha';
click('util-jogo-novo');
ok('novo jogo renderiza tabuleiro', $('util-jogo-estado').textContent.indexOf('|') !== -1);
set('util-jogo-jogada', '5');
click('util-jogo-enviar');
ok('jogada altera o tabuleiro', $('util-jogo-estado').textContent.indexOf('X') !== -1);
$('util-jogo-tipo').value = 'forca';
click('util-jogo-novo');
set('util-jogo-jogada', 'a');
click('util-jogo-enviar');
ok('forca aceita letra', /Erros:/.test($('util-jogo-estado').textContent));

window.UtilidadesUI.selecionar('cultura');
ok('receitas viraram botões', $('util-cultura-lista').querySelectorAll('button').length === 8);
$('util-cultura-lista').querySelector('button').dispatchEvent(new window.Event('click', { bubbles: true }));
ok('receita mostra ingredientes e modo', /Ingredientes:/.test($('util-cultura-saida').textContent) && /Modo:/.test($('util-cultura-saida').textContent));
click('util-cultura-piada');
ok('piada aparece', $('util-cultura-saida').textContent.length > 20);
click('util-cultura-filme');
ok('sugestões de filme aparecem', /Interestelar/.test($('util-cultura-saida').textContent));

window.UtilidadesUI.selecionar('briefing');
set('util-brief-nome', 'Ana'); set('util-brief-clima', '24 °C e claro');
set('util-brief-tarefas', 'enviar relatório');
click('util-brief-ver');
ok('briefing usa os dados fornecidos', /Ana/.test($('util-brief-saida').textContent) && /24 °C/.test($('util-brief-saida').textContent));
ok('briefing declara a fonte ausente', /Sem dados de: manchetes/.test($('util-brief-saida').textContent));

ok('chat responde conta', window.UtilidadesUI.responder('quanto é 2+2') === 'Deu 4.');
ok('chat responde receita', /ovos/.test(window.UtilidadesUI.responder('receita de omelete')));
ok('chat inicia jogo', /Jogo iniciado: velha/.test(window.UtilidadesUI.responder('jogar velha')));
ok('comando desconhecido devolve null', window.UtilidadesUI.responder('configure o roteador') === null);
ok('fechar esconde o painel', (window.UtilidadesUI.fechar(), $('painel-utilidades').hidden === true));
ok('nenhum erro de script durante os cliques', erros.length === 0, erros.join(' | '));

console.log('\nUtilidades DOM: ' + n + ' verificações aprovadas.');
