'use strict';
/* Escuta de voz: nível, VAD e barge-in (Fase 4).
 *
 * Sinais sintéticos, sem microfone: silêncio, ruído baixo constante e tom senoidal. Assim é
 * possível afirmar o comportamento do detector (quando começa, quando termina, quando não
 * dispara) sem depender de hardware. As últimas verificações são estáticas e cobram a
 * ligação no app.
 */
const fs = require('node:fs');
const assert = require('node:assert/strict');
const E = require('../escuta_voz.js');

let ok = 0;
function ver(nome, fn) { fn(); ok++; }

const TAXA = 48000;
const BLOCO = 960; // 20 ms a 48 kHz

function silencio(n) { return new Float32Array(n || BLOCO); }
function tom(amplitude, n, freq) { const a = new Float32Array(n || BLOCO); for (let i = 0; i < a.length; i++) a[i] = amplitude * Math.sin(2 * Math.PI * (freq || 220) * i / TAXA); return a; }
function ruido(amplitude, n, semente) { const a = new Float32Array(n || BLOCO); let s = semente || 1; for (let i = 0; i < a.length; i++) { s = (s * 16807) % 2147483647; a[i] = amplitude * ((s / 2147483647) * 2 - 1); } return a; }
function alimentar(det, bloco, vezes, taxa) { let r = null; for (let i = 0; i < vezes; i++) r = det.processar(bloco, taxa || TAXA); return r; }

/* ---------- Nível ---------- */

ver('silêncio absoluto fica em -100 dB e classe mudo', () => {
  const n = E.nivel(silencio());
  assert.equal(n.db, -100);
  assert.equal(n.pico, 0);
  assert.equal(E.classificar(n.db, n.pico), 'mudo');
});

ver('tom de 0,2 mede cerca de -17 dB (RMS = amplitude/raiz de 2) e classe bom', () => {
  const n = E.nivel(tom(0.2));
  assert.ok(n.db > -18 && n.db < -16, 'dB medido: ' + n.db);
  assert.equal(n.pico, 0.2);
  assert.equal(E.classificar(n.db, n.pico), 'bom');
});

ver('bloco vazio não estoura', () => {
  const n = E.nivel(new Float32Array(0));
  assert.equal(n.db, -100);
  assert.equal(E.classificar(undefined, undefined), 'mudo');
});

ver('pico no teto é saturado', () => {
  assert.equal(E.classificar(-3, 0.999), 'saturado');
  assert.equal(E.classificar(-2, 0.5), 'saturado');
});

ver('classificação por faixa', () => {
  assert.equal(E.classificar(-80, 0.01), 'mudo');
  assert.equal(E.classificar(-50, 0.1), 'baixo');
  assert.equal(E.classificar(-20, 0.3), 'bom');
});

/* ---------- Detecção de fala ---------- */

ver('começa em silêncio e sem fala', () => {
  const det = E.criarDetector({});
  const e = det.estado();
  assert.equal(e.estado, 'silencio');
  assert.equal(e.desdeFalaMs, 0);
});

ver('fala é detectada depois do mínimo de 120 ms', () => {
  const det = E.criarDetector({});
  let r = alimentar(det, tom(0.2), 5);
  assert.equal(r.fala, false, '5 blocos = 100 ms, ainda não');
  r = alimentar(det, tom(0.2), 1);
  assert.equal(r.fala, true, '6 blocos = 120 ms');
  assert.equal(r.inicio, true);
  assert.equal(r.estado, 'fala');
});

ver('início só é anunciado uma vez', () => {
  const det = E.criarDetector({});
  alimentar(det, tom(0.2), 7);
  const r = det.processar(tom(0.2), TAXA);
  assert.equal(r.inicio, false);
  assert.equal(r.fala, true);
  assert.ok(r.desdeFalaMs >= 120);
});

ver('pausa curta não encerra a fala (cauda de 500 ms)', () => {
  const det = E.criarDetector({});
  alimentar(det, tom(0.2), 8);
  const pausa = alimentar(det, silencio(), 20); // 400 ms
  assert.equal(pausa.fala, true, '400 ms de pausa ficam dentro da cauda');
});

ver('silêncio depois da cauda encerra com evento fim', () => {
  const det = E.criarDetector({});
  alimentar(det, tom(0.2), 8);
  let r = null, blocos = 0;
  for (let i = 0; i < 40; i++) { r = det.processar(silencio(), TAXA); blocos++; if (r.fim) break; }
  assert.equal(r.fim, true, 'o fim precisa ser anunciado uma vez');
  assert.equal(r.fala, false);
  assert.equal(r.estado, 'silencio');
  assert.ok(blocos >= 24 && blocos <= 27, 'cauda de 500 ms respeitada; blocos até o fim: ' + blocos);
});

ver('ruído baixo constante não dispara em 2 segundos', () => {
  const det = E.criarDetector({});
  const bloco = ruido(0.0006);
  const r = alimentar(det, bloco, 100); // 2 s
  assert.equal(r.fala, false, 'ruído de fundo não pode acordar o barge-in');
  assert.ok(r.ruidoDb > -75 && r.ruidoDb < -55, 'piso medido: ' + r.ruidoDb);
});

ver('piso de ruído acompanha o ambiente', () => {
  const det = E.criarDetector({ ruidoInicialDb: -60 });
  alimentar(det, ruido(0.0006), 50);
  const e = det.estado();
  assert.ok(e.ruidoDb < -60, 'o piso precisa descer com o ambiente silencioso: ' + e.ruidoDb);
});

ver('sensibilidade alta passa, baixa não, para o mesmo sinal', () => {
  const amostra = tom(0.004); // cerca de -48 dB
  const alta = E.criarDetector({ sensibilidade: 0.9, ruidoInicialDb: -60 });
  const baixa = E.criarDetector({ sensibilidade: 0.1, ruidoInicialDb: -60 });
  assert.equal(alimentar(alta, amostra, 8).fala, true);
  assert.equal(alimentar(baixa, amostra, 8).fala, false);
});

ver('sensibilidade fora da faixa é limitada', () => {
  assert.equal(E.criarDetector({ sensibilidade: 5 }).estado().sensibilidade, 1);
  assert.equal(E.criarDetector({ sensibilidade: -2 }).estado().sensibilidade, 0);
});

ver('fala mínima e cauda respeitam os limites pedidos', () => {
  const e = E.criarDetector({ falaMinMs: 5, hangoverMs: 10 }).estado();
  assert.equal(e.falaMinMs, 40);
  assert.equal(e.hangoverMs, 120);
});

ver('taxa inválida cai em 48 kHz', () => {
  const det = E.criarDetector({});
  const r = det.processar(tom(0.2), 0);
  assert.ok(r.fala === false || r.fala === true); // não pode lançar
  alimentar(det, tom(0.2), 8, 0);
  assert.equal(det.estado().estado, 'fala');
});

/* ---------- Barge-in ---------- */

ver('barge-in exige fala sustentada', () => {
  assert.equal(E.deveInterromper('fala', 150), false);
  assert.equal(E.deveInterromper('fala', 299), false);
  assert.equal(E.deveInterromper('fala', 300), true);
  assert.equal(E.deveInterromper('silencio', 5000), false);
});

ver('barge-in aceita mínimo próprio', () => {
  assert.equal(E.deveInterromper('fala', 200, 150), true);
  assert.equal(E.deveInterromper('fala', 200, 0), false, 'mínimo inválido cai em 300');
});

/* ---------- Resumo de medição ---------- */

ver('resumo separa fala, silêncio, ruído e pico', () => {
  const r = E.resumir([
    { ms: 20, db: -70, pico: 0.01, fala: false, classe: 'baixo' },
    { ms: 20, db: -20, pico: 0.4, fala: true, classe: 'bom' },
    { ms: 20, db: -22, pico: 0.3, fala: true, classe: 'bom' },
    { ms: 20, db: -68, pico: 0.01, fala: false, classe: 'baixo' }
  ]);
  assert.equal(r.duracaoMs, 80);
  assert.equal(r.falaMs, 40);
  assert.equal(r.silencioMs, 40);
  assert.equal(r.ruidoDb, -70);
  assert.equal(r.pico, 0.4);
  assert.equal(r.classificacao, 'baixo');
  assert.equal(r.saturado, false);
});

ver('resumo de lista vazia não inventa dados', () => {
  const r = E.resumir([]);
  assert.equal(r.duracaoMs, 0);
  assert.equal(r.ruidoDb, -100);
  assert.equal(r.classificacao, 'mudo');
});

/* ---------- Ligação no app ---------- */

ver('o app carrega o módulo e arma o barge-in durante a fala', () => {
  const html = fs.readFileSync('index.html', 'utf8');
  assert.match(html, /<script src="escuta_voz\.js"><\/script>/);
  assert.match(html, /id="c-voz-interromper"/);
  assert.match(html, /id="c-voz-medir-mic"/);
  const app = fs.readFileSync('app.js', 'utf8');
  assert.match(app, /async function armarBargeIn\(/);
  assert.match(app, /EscutaVoz\.deveInterromper\(r\.estado, r\.desdeFalaMs, 300\)/);
  assert.match(app, /await armarBargeIn\(\);/);
  assert.match(app, /desarmarBargeIn\(\);/);
  assert.match(app, /function medirMicrofone\(/);
  assert.match(app, /store\.get\('voz_interromper', '1'\)/);
  assert.ok(app.indexOf('EscutaVozJarvis') < 0, 'a troca de nome não pode atingir o gravador EscutaJarvis');
  assert.match(app, /window\.EscutaJarvis/);
});

ver('o módulo entra no pacote, na suíte e no workflow', () => {
  const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
  assert.ok(pkg.build.files.includes('escuta_voz.js'));
  assert.match(pkg.scripts['test:all'], /node --check escuta_voz\.js/);
  assert.match(pkg.scripts['test:all'], /node tests\/test_escuta_voz\.js/);
});

console.log('Escuta de voz (VAD e barge-in): ' + ok + ' verificações aprovadas.');
