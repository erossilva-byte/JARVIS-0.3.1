// Testes do supervisor de planos (plano.js), com executor e confirmações injetados.
const assert = require('assert');
const P = require('../plano.js');

const ACOES = {
  hora: { risco: 0, disp: ['android', 'desktop'] },
  clima: { risco: 0, disp: ['android', 'desktop'] },
  abrir_app: { risco: 1, disp: ['android'] },
  desligar_pc: { risco: 3, disp: ['desktop'] }
};
const disp = ['hora', 'clima', 'abrir_app'];

(async () => {
// 1. Normalização, IDs, risco e recusa de ação inventada/recursiva/grande.
let n = P.normalizar({ objetivo: 'Preparar o dia', passos: [{ acao: 'hora' }, { acao: 'clima', args: { dia: 1 }, porque: 'vai chover?' }] }, { acoes: ACOES, disponiveis: disp });
assert.equal(n.ok, true);
assert.deepEqual(n.plano.passos.map((p) => p.id), ['p1', 'p2']);
assert.equal(n.plano.riscoMax, 0);
assert.equal(P.normalizar({ objetivo: 'x', passos: [{ acao: 'hora' }] }, { acoes: ACOES, disponiveis: ['clima'] }).ok, false);
assert.equal(P.normalizar({ objetivo: 'x', passos: [{ acao: 'executar_plano' }] }, { acoes: ACOES, disponiveis: disp }).ok, false);
assert.equal(P.normalizar({ objetivo: 'x', passos: Array.from({ length: 7 }, () => ({ acao: 'hora' })) }, { acoes: ACOES, disponiveis: disp }).ok, false);
assert.equal(P.normalizar({ objetivo: 'x', passos: [{ acao: 'inventada' }] }, { acoes: ACOES, disponiveis: disp }).ok, false);
assert.equal(P.normalizar({ objetivo: '', passos: [{ acao: 'hora' }] }, { acoes: ACOES }).ok, false);

// 2. JSON dentro de cerca markdown é aceito; objetivo do contexto completa.
n = P.normalizar('```json\n{"passos":[{"acao":"hora"}]}\n```', { acoes: ACOES, disponiveis: disp, objetivo: 'Saber a hora' });
assert.equal(n.ok, true);
assert.equal(n.plano.objetivo, 'Saber a hora');

// 3. Plano todo confirmado: executa na ordem e conclui.
const vistos = [];
let r = await P.executar(n.plano, {
  executar: async (p) => { vistos.push(p.acao); return { recibo: { estado: 'ok', motivo: 'confirmado' }, info: 'feito' }; }
});
assert.equal(r.status, 'concluido'); assert.equal(r.ok, 1); assert.equal(r.executados, 1); assert.deepEqual(vistos, ['hora']);

// 4. Etapa incerta pausa; com autorização explícita, segue para a próxima.
const p2 = P.normalizar({ objetivo: 'Duas etapas', passos: [{ acao: 'hora' }, { acao: 'clima' }] }, { acoes: ACOES, disponiveis: disp }).plano;
let pedidos = 0, depois = [];
r = await P.executar(p2, {
  executar: async (p) => { depois.push(p.acao); return { recibo: { estado: p.acao === 'hora' ? 'incerto' : 'ok', motivo: 'sem confirmação' } }; },
  confirmarIncerteza: async () => { pedidos++; return true; }
});
assert.equal(r.status, 'concluido'); assert.equal(r.incerto, 1); assert.equal(r.ok, 1); assert.equal(pedidos, 1); assert.deepEqual(depois, ['hora', 'clima']);

// 5. Sem autorização, para e NÃO executa a etapa seguinte.
depois = [];
r = await P.executar(p2, {
  executar: async (p) => { depois.push(p.acao); return { recibo: { estado: 'incerto', motivo: 'sem confirmação' } }; },
  confirmarIncerteza: async () => false
});
assert.equal(r.status, 'pausado'); assert.equal(r.executados, 1); assert.deepEqual(depois, ['hora']);

// 6. Falha/bloqueio param o plano; etapa seguinte nunca roda.
depois = [];
r = await P.executar(p2, {
  executar: async (p) => { depois.push(p.acao); return { recibo: { estado: 'falhou', motivo: 'sem permissão' } }; }
});
assert.equal(r.status, 'falhou'); assert.equal(r.executados, 1); assert.deepEqual(depois, ['hora']);
assert.equal(r.passos[0].estado, 'falhou');

// 7. Cancelamento antes da próxima etapa.
depois = [];
r = await P.executar(p2, {
  executar: async (p) => { depois.push(p.acao); return { recibo: { estado: 'ok' } }; },
  cancelado: (() => { let i = 0; return () => i++ > 0; })()
});
assert.equal(r.status, 'cancelado'); assert.deepEqual(depois, ['hora']);

// 8. Executor que lança exceção nunca vira sucesso.
r = await P.executar(p2, { executar: async () => { throw new Error('falha simulada'); } });
assert.equal(r.status, 'falhou'); assert.equal(r.ok, 0);

// 9. Resumo não inclui valores de argumentos sensíveis.
n = P.normalizar({ objetivo: 'Mensagem', passos: [{ acao: 'abrir_app', args: { texto: 'segredo' }, porque: 'abrir' }] }, { acoes: ACOES, disponiveis: disp });
assert.ok(P.resumo(n.plano).indexOf('segredo') < 0);
assert.ok(P.resumo(n.plano).indexOf('abrir app') >= 0);
assert.ok(P.resumo(n.plano, { args: true }).indexOf('texto=segredo') >= 0);

console.log('test_plano: 25 verificações aprovadas');

})().catch((e) => { console.error(e); process.exit(1); });
