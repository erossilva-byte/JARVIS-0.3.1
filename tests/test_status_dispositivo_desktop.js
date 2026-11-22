'use strict';
const assert = require('assert');
const fs = require('fs');
const app = fs.readFileSync(require.resolve('../app.js'), 'utf8');
const desktop = fs.readFileSync(require.resolve('../platforms/desktop/main.js'), 'utf8');
const inicio = app.indexOf('status_dispositivo: {');
assert.ok(inicio >= 0, 'ação status_dispositivo deve existir');
const fim = app.indexOf('\n  agenda:', inicio);
assert.ok(fim > inicio, 'ação status_dispositivo deve terminar antes de agenda');
const acao = app.slice(inicio, fim);
assert.match(acao, /disp:\s*T\b/, 'status do dispositivo deve estar disponível no Android e desktop');
assert.match(acao, /plataforma\s*===\s*['"]desktop['"]/, 'deve selecionar o adaptador desktop');
assert.match(acao, /nativo\(['"]status_pc['"]/, 'desktop deve consultar o status nativo do PC');
for (const campo of ['cpu', 'ramTotal', 'ramLivre', 'discoTotal', 'discoLivre', 'aparelho', 'uptime']) {
  assert.ok(acao.includes('r.' + campo), 'status desktop deve usar o campo ' + campo);
}
assert.match(acao, /nativo\(['"]statusDispositivo['"]/, 'Android deve preservar a consulta nativa do aparelho');
assert.match(desktop, /status_pc:\s*async\s*\(\)/, 'desktop deve implementar status_pc');
console.log('OK: status_dispositivo adaptado para Android e Windows com campos reais do host');
