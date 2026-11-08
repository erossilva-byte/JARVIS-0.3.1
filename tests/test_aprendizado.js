'use strict';
const assert = require('assert');
const A = require('../aprendizado.js');

const mem = new Map();
A.configurar({ store: { getItem: (k) => (mem.has(k) ? mem.get(k) : ''), setItem: (k, v) => mem.set(k, v) } });
A.limparTudo();

const p = A.observar('prefiro respostas curtas e diretas.');
assert.strictEqual(p.ok, true);
assert.strictEqual(p.item.tipo, 'preferencia');
assert.ok(A.contexto().includes('respostas curtas'));

const c = A.observar('evite usar listas quando eu estiver com pressa.');
assert.strictEqual(c.ok, true);
assert.strictEqual(c.item.tipo, 'correcao');

const h = A.observar('lembre que o projeto Atlas usa Python.');
assert.strictEqual(h.item.tipo, 'fato');

const rep = A.observar('prefiro respostas curtas e diretas.');
assert.strictEqual(rep.repetido, true);
assert.strictEqual(A.listar().length, 3);

const sens = A.observar('lembre que minha senha é 1234.');
assert.strictEqual(sens.ok, false);
assert.strictEqual(sens.bloqueado, true);
assert.ok(!A.contexto().includes('1234'));

assert.strictEqual(A.remover(c.item.id).ok, true);
assert.strictEqual(A.listar().length, 2);
const undo = A.desfazer();
assert.strictEqual(undo.ok, true);
assert.ok(undo.removido.id === h.item.id);

const antes = A.listar().length;
const backup = A.exportar();
assert.ok(backup.includes('jarvis-aprendizado-1'));
assert.strictEqual(A.limparTudo().ok, true);
assert.strictEqual(A.importar(backup).ok, true);
assert.strictEqual(A.listar().length, antes);

A.feedback('a resposta anterior foi longa demais', 'negativo', 'turno-1');
assert.ok(A.listar().some((x) => x.tipo === 'correcao' && x.fonte === 'feedback'));
assert.ok(A.resumo().total >= 2);
console.log('Aprendizado: padrões explícitos, deduplicação, sensível, remoção, desfazer, backup e contexto OK.');
