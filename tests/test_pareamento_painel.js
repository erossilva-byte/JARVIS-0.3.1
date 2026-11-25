/* Formulário de pareamento no painel do PC (jsdom + regra compartilhada).
 *
 * Prova o que dá para provar sem Electron: os campos existem, a regra do
 * renderer valida IP e código, o estado vazio continua dizendo “Sem conexão”,
 * e o app.js liga os três pedidos nativos (parear, status, esquecer) sem
 * inventar dado quando não há celular pareado.
 */
'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

const root = path.resolve(__dirname, '..');
const bruto = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const html = bruto.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '');
const app = fs.readFileSync(path.join(root, 'app.js'), 'utf8');
const dom = new JSDOM(html, { url: 'http://localhost/', runScripts: 'outside-only' });
const { window } = dom;
const { document } = window;
window.eval(fs.readFileSync(path.join(root, 'pareamento.js'), 'utf8'));
window.eval(fs.readFileSync(path.join(root, 'status_plataforma.js'), 'utf8'));

let verificacoes = 0;
function ok(nome, condicao) {
  verificacoes++;
  assert.ok(condicao, nome);
  console.log('OK: ' + nome);
}

// 1. O formulário está no painel, na seção do celular.
for (const id of ['sc-ip', 'sc-codigo', 'sc-parear', 'sc-esquecer', 'sc-pareado', 'sc-pareamento-erro', 'sc-linhas']) {
  ok('o painel tem o elemento ' + id, !!document.getElementById(id));
}
ok('o código pede no máximo 7 caracteres (com o espaço)',
  document.getElementById('sc-codigo').getAttribute('maxlength') === '7');
ok('o painel explica onde pegar o código',
  /Pareamento Windows/.test(document.getElementById('sc-pareamento-caixa').textContent));
ok('o estado vazio continua dizendo sem conexão',
  /sem conexão/i.test(document.getElementById('sc-pareamento').textContent));

// 2. Ordem dos scripts: a regra precisa vir antes do app.
const posPareamento = bruto.indexOf('src="pareamento.js"');
const posApp = bruto.indexOf('src="app.js"');
ok('pareamento.js é carregado antes do app.js',
  posPareamento > 0 && posApp > posPareamento);
ok('a regra do pareamento está no window', !!window.Pareamento);

// 3. A regra valida o que foi digitado.
const P = window.Pareamento;
ok('código com espaço é aceito', (() => {
  const r = P.validarDigitacao('192.168.0.20', '123 456');
  return r.ok && r.codigo === '123456' && r.ip === '192.168.0.20:47600';
})());
ok('código curto é recusado', !P.validarDigitacao('192.168.0.20', '123').ok);
ok('IP público é recusado', !P.validarDigitacao('8.8.8.8', '123456').ok);
ok('IP com porta é preservado',
  P.validarDigitacao('10.0.0.5:5000', '123456').ip === '10.0.0.5:5000');
ok('a recusa do IP explica o formato',
  /rede local/.test(P.validarDigitacao('8.8.8.8', '123456').erro));
ok('formatação do código', P.formatarCodigo('004521') === '004 521');

// 4. Estado pareado: resumo honesto, sem inventar conexão.
ok('sem estado, o resumo diz sem conexão',
  /Sem conexão/.test(P.resumoPareado(null)));
ok('estado sem dispositivo não conta como pareado',
  P.estadoPareado({ pareado: true }) === false);
const estado = { pareado: true, dispositivo: 'PC da oficina', ip: '192.168.0.10', porta: 47600, endereco: '192.168.0.10:47600' };
ok('estado completo é pareado', P.estadoPareado(estado) === true);
ok('resumo cita o PC e o endereço',
  P.resumoPareado(estado) === 'Pareado com PC da oficina · 192.168.0.10:47600.');

// 5. O app.js liga os três pedidos nativos e não promete dado sem pareamento.
ok('app.js tem iniciarPareamentoPainel', /function iniciarPareamentoPainel\(/.test(app));
ok('app.js valida com a regra compartilhada', /P\.validarDigitacao\(/.test(app));
ok('app.js pareia pelo processo principal', /nativo\('parear_celular'/.test(app));
ok('app.js lê o status pelo processo principal', /nativo\('status_celular'/.test(app));
ok('app.js esquece pelo processo principal', /nativo\('esquecer_celular'/.test(app));
ok('app.js desenha o status pareado na regra compartilhada',
  /renderStatusPlataforma\('sc-linhas'/.test(app));
ok('sem pareamento, a seção diz sem conexão com todas as letras',
  /set\('sc-pareamento', 'Sem conexão: nenhum celular pareado ainda\.'\)/.test(app));
ok('sem pareamento, o alerta manda parear em vez de inventar número',
  /pareie acima com o código de 6 dígitos/.test(app));
ok('o esquecimento limpa a lista desenhada',
  /const linhas = document\.getElementById\('sc-linhas'\);\s*\n\s*if \(linhas\) linhas\.innerHTML = '';/.test(app));

// 6. O processo principal registra as quatro ações.
const main = fs.readFileSync(path.join(root, 'platforms', 'desktop', 'main.js'), 'utf8');
for (const acao of ['pareamento_celular', 'parear_celular', 'status_celular', 'esquecer_celular']) {
  ok('main.js registra ' + acao, new RegExp(acao + ':').test(main));
}
ok('main.js guarda o registro no userData',
  /pareamento-celular\.json/.test(main));

console.log('OK: ' + verificacoes + ' verificações do pareamento no painel');
