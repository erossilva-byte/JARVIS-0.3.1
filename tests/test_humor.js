"use strict";
const H = require('../humor.js');
let f = 0;
function ok(n, c, d) { if (c) console.log('OK: ' + n); else { f++; console.log('FALHA: ' + n + (d ? ' -> ' + d : '')); } }
ok('módulo tem banco por contexto', H.temas.length >= 8 && H.temas.indexOf('codigo') >= 0);
ok('detecta assunto técnico', ['codigo', 'bug'].indexOf(H.tema('meu código tem um bug')) >= 0);
ok('detecta saudação', H.tema('bom dia, Jarvis') === 'saudacao');
ok('detecta assunto sério', H.eSerio('minha mãe está no hospital com dor no peito'));
ok('não sugere humor em assunto sério', H.sugerir('perdi meu dinheiro num golpe') === null);
ok('não sugere humor em intensidade baixa', H.sugerir('bom dia', { humor: 20 }) === null);
const a = H.sugerir('meu computador está lento', { humor: 90 });
ok('sugere ângulo contextual', a && a.tema === 'bug' && a.linha.length > 10, a);
ok('evita repetir ângulo recente', (() => { const b = H.sugerir('meu computador está lento', { humor: 90, recentes: [a.linha] }); return b && b.linha !== a.linha; })());
const regras = H.estiloPrompt({ humor: 90, sarcasmo: 90, ironia: 90, brincadeiras: 85, espontaneidade: 85, provocacao: 70, formalidade: 15 });
ok('prompt exige personalidade em toda resposta', regras.indexOf('PERSONALIDADE OBRIGATÓRIA') >= 0 && regras.indexOf('Toda resposta') >= 0);
ok('prompt proíbe abertura neutra', regras.indexOf('Proibido abrir') >= 0 && regras.indexOf('Como posso ajudar') >= 0);
ok('prompt zera humor em assunto sensível', regras.indexOf('humor zero') >= 0);
ok('prompt proíbe copiar filmes', regras.indexOf('Não copie falas') >= 0);
ok('humor zero tem regra própria', H.estiloPrompt({ humor: 0 }).indexOf('sem piadas') >= 0);
const iron = H.prosodia('Excelente, aparentemente funcionou.');
ok('ironia fica mais grave e lenta', iron.pitch < 0 && iron.rate < 1, iron);
ok('exclamação ganha entusiasmo', H.prosodia('Funcionou!').pitch > 0);
ok('pergunta sobe o tom', H.prosodia('Isso vai funcionar?').pitch > 0);
if (f) { console.log('\n' + f + ' falha(s) no humor.'); process.exit(1); }
console.log('\nHumor: contexto, repetição, seriedade, prompt e prosódia verificados.');
