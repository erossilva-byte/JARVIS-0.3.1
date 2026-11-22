'use strict';
const fs = require('fs');
const app = fs.readFileSync('app.js', 'utf8');
function section(start, end) {
  const a = app.indexOf(start);
  if (a < 0) throw new Error('Trecho não encontrado: ' + start);
  const b = app.indexOf(end, a + start.length);
  if (b < 0) throw new Error('Fim do trecho não encontrado: ' + end);
  return app.slice(a, b);
}
const open = section('async function abrirConfig()', 'async function salvarConfig()');
const save = section('async function salvarConfig()', '/* ---------- Central de comando');
if (!open.includes('await chavesProntas') || open.indexOf('await chavesProntas') > open.indexOf('mostrarChaves()')) {
  throw new Error('abrirConfig precisa hidratar o cofre antes de mostrar os campos de API.');
}
if (!save.includes('await chavesProntas') || save.indexOf('await chavesProntas') > save.indexOf('Object.entries(CAMPOS_CHAVE)')) {
  throw new Error('salvarConfig precisa aguardar a hidratação do cofre antes de ler/gravar campos.');
}
if (!save.includes('await gravarChave(n, v)')) throw new Error('Salvamento de chaves não está conectado ao cofre seguro.');
if (!app.includes("c.value = '';\n    c.placeholder = CHAVES[n] ? 'salva ····'")) {
  throw new Error('A interface deve indicar quando uma chave já está salva sem expor seu conteúdo.');
}
console.log('OK: abertura e salvamento aguardam a hidratação do cofre seguro; chaves não são exibidas em texto.');
