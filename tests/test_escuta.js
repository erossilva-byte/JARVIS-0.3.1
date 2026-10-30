// Testes do VAD de captura (escuta.js): pré-roll, confirmação, fim por silêncio,
// limite máximo, ausência de fala e ruído de fundo. Sinais sintéticos, sem microfone.
const assert = require('assert');
const E = require('../escuta.js');

function sinal(opts) {
  const o = Object.assign({ sr: 16000, ruido: 0.002, inicio: 0.5, dur: 1.0, total: 4, amp: 0.08, blip: 0 }, opts);
  const n = Math.round(o.sr * o.total);
  const x = new Float32Array(n);
  for (let i = 0; i < n; i++) x[i] = (Math.random() * 2 - 1) * o.ruido;
  const ini = Math.round(o.sr * o.inicio), dur = Math.round(o.sr * (o.blip || o.dur));
  for (let i = ini; i < Math.min(n, ini + dur); i++) {
    const t = (i - ini) / o.sr;
    x[i] += Math.sin(2 * Math.PI * 180 * t) * o.amp;
  }
  return { x, sr: o.sr };
}
function alimentar(escuta, x, sr, bloco) {
  let r = null;
  for (let i = 0; i < x.length; i += bloco) {
    r = escuta.processar(x.subarray(i, Math.min(x.length, i + bloco)), sr);
    if (r.estado === 'fim') break;
  }
  return r;
}
function nivelNoTrecho(amostras, sr, de, ate) {
  const a = Math.max(0, Math.round(de * sr)), b = Math.min(amostras.length, Math.round(ate * sr));
  let soma = 0;
  for (let i = a; i < b; i++) soma += amostras[i] * amostras[i];
  return Math.sqrt(soma / Math.max(1, b - a));
}

let e = E.criar({ maxMs: 6000, semFalaMs: 6000 });
let s = sinal({ total: 5 });
let r = alimentar(e, s.x, s.sr, 320);
assert.strictEqual(r.estado, 'fim', 'captura termina');
assert.strictEqual(r.motivo, 'silencio', 'termina por silêncio: ' + r.motivo);
assert.ok(r.falaMs >= 1200, 'fala contabilizada: ' + r.falaMs);
assert.ok(r.amostras.length > 0);
assert.ok(r.totalMs <= 5000, 'não grava além do necessário');
const antes = nivelNoTrecho(r.amostras, s.sr, 0.05, 0.35);
const durante = nivelNoTrecho(r.amostras, s.sr, 0.7, 1.2);
assert.ok(antes < durante / 3, 'pré-roll começa no silêncio, não corta a primeira sílaba');
console.log('OK: pré-roll + fim por silêncio (motivo ' + r.motivo + ', fala ' + r.falaMs + ' ms, total ' + r.totalMs + ' ms)');

e = E.criar({ maxMs: 6000, semFalaMs: 3000 });
s = sinal({ inicio: 0, dur: 0, total: 4 });
r = alimentar(e, s.x, s.sr, 320);
assert.strictEqual(r.estado, 'fim');
assert.strictEqual(r.motivo, 'sem-fala');
assert.strictEqual(r.amostras.length, 0, 'sem fala não devolve áudio');
console.log('OK: silêncio não vira gravação');

e = E.criar({ maxMs: 2000, semFalaMs: 2000 });
s = sinal({ inicio: 0.1, dur: 5, total: 5, amp: 0.1 });
r = alimentar(e, s.x, s.sr, 320);
assert.strictEqual(r.estado, 'fim');
assert.strictEqual(r.motivo, 'maximo');
assert.ok(r.totalMs <= 2100 && r.totalMs >= 1900, 'teto rígido: ' + r.totalMs);
console.log('OK: teto de duração respeitado');

e = E.criar({ maxMs: 4000, semFalaMs: 2500 });
s = sinal({ inicio: 0.4, blip: 0.1, dur: 0.1, total: 3 });
r = alimentar(e, s.x, s.sr, 320);
assert.strictEqual(r.motivo, 'sem-fala', 'blip curto não confirma fala');
console.log('OK: blip curto não vira comando');

e = E.criar({ maxMs: 6000, semFalaMs: 6000 });
s = sinal({ inicio: 0.5, dur: 1.2, total: 3 });
alimentar(e, s.x, s.sr, 320);
e.reiniciar();
s = sinal({ inicio: 0.2, dur: 1.0, total: 3 });
r = alimentar(e, s.x, s.sr, 320);
assert.strictEqual(r.estado, 'fim');
assert.ok(r.falaMs >= 1200, 'reiniciar limpa o estado');
console.log('OK: reinício limpa o estado');

const ruido = Float32Array.from({ length: 1600 }, () => 0.005);
assert.ok(Math.abs(E.rms(ruido) - 0.005) < 0.001, 'RMS confere');
console.log('\ntest_escuta: todos os grupos passaram');
