/* Avatar 3D: API, fallback Canvas 2D e contrato de honestidade. Sem navegador real. */
'use strict';
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const A = require('../avatar.js');
let ok = 0;
const t = (nome, fn) => {
  try { fn(); ok++; console.log('OK: ' + nome); }
  catch (e) { console.error('FALHOU: ' + nome + ' — ' + e.message); process.exitCode = 1; }
};

t('API do avatar exposta', () => {
  for (const n of ['iniciar', 'parar', 'destruir', 'estado', 'nivel', 'ativo', 'tipo', 'diagnostico']) {
    assert.strictEqual(typeof A[n], 'function', n);
  }
});
t('iniciar sem canvas não finge suporte', () => {
  assert.strictEqual(A.iniciar(null), null);
  assert.strictEqual(A.tipo(), null);
  assert.match(A.diagnostico().motivo, /não iniciado/);
});
t('estado e nível são seguros antes de iniciar', () => {
  A.estado('speaking');
  A.nivel(0.8);
  assert.strictEqual(A.ativo(), false);
});
t('fonte não usa innerHTML nem rede', () => {
  const src = fs.readFileSync(path.join(__dirname, '..', 'avatar.js'), 'utf8');
  assert.ok(!src.includes('innerHTML'));
  assert.ok(!src.includes('fetch('));
  assert.ok(!src.includes('https://cdn'));
  for (const marca of ['Render3D', 'Render2D', 'suportaWebGL', 'requestAnimationFrame', 'IntersectionObserver', 'visibilitychange', 'TorusGeometry']) {
    assert.ok(src.includes(marca), 'faltou ' + marca);
  }
  assert.ok(/amplitude/i.test(src) && /visemas/i.test(src), 'deve declarar sincronização por amplitude');
});

t('fallback Canvas 2D inicia e desenha sem WebGL', () => {
  const grad = { addColorStop() {} };
  const ctx = new Proxy({}, {
    get(obj, chave) {
      if (chave === 'createRadialGradient') return () => grad;
      if (chave in obj) return obj[chave];
      return () => {};
    },
    set(obj, chave, valor) { obj[chave] = valor; return true; }
  });
  const canvas = {
    width: 0, height: 0,
    getContext(tipo) { return tipo === '2d' ? ctx : null; },
    getBoundingClientRect() { return { width: 320, height: 320 }; }
  };
  const antigos = {
    document: global.document, requestAnimationFrame: global.requestAnimationFrame,
    cancelAnimationFrame: global.cancelAnimationFrame, devicePixelRatio: global.devicePixelRatio
  };
  global.document = {
    hidden: false,
    createElement() { return { width: 0, height: 0, getContext() { return null; } }; },
    addEventListener() {}, removeEventListener() {}
  };
  global.requestAnimationFrame = () => 1;
  global.cancelAnimationFrame = () => {};
  global.devicePixelRatio = 1;
  try {
    const r = A.iniciar(canvas);
    assert.ok(r, 'deveria criar o fallback');
    assert.strictEqual(A.tipo(), 'canvas2d');
    assert.strictEqual(A.ativo(), true);
    A.estado('speaking');
    A.nivel(0.45);
    A.parar();
    assert.strictEqual(A.ativo(), false);
  } finally {
    A.destruir();
    if (antigos.document === undefined) delete global.document; else global.document = antigos.document;
    if (antigos.requestAnimationFrame === undefined) delete global.requestAnimationFrame; else global.requestAnimationFrame = antigos.requestAnimationFrame;
    if (antigos.cancelAnimationFrame === undefined) delete global.cancelAnimationFrame; else global.cancelAnimationFrame = antigos.cancelAnimationFrame;
    if (antigos.devicePixelRatio === undefined) delete global.devicePixelRatio; else global.devicePixelRatio = antigos.devicePixelRatio;
  }
});

console.log('\ntest_avatar: ' + ok + ' verificações aprovadas');
if (process.exitCode) process.exit(process.exitCode);
