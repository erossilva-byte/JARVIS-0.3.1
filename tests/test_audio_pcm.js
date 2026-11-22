'use strict';
const assert = require('assert');
const A = require('../audio_pcm.js');

const sr = 16000;
const amostras = new Float32Array(sr); // 1 segundo
for (let i = 0; i < amostras.length; i++) amostras[i] = Math.sin(2 * Math.PI * 220 * i / sr) * 0.5;
amostras[0] = 2;
amostras[1] = -2;

const bytes = A.wav(amostras, sr);
const view = new DataView(bytes.buffer);
function txt(off, n) {
  let s = '';
  for (let i = 0; i < n; i++) s += String.fromCharCode(view.getUint8(off + i));
  return s;
}
assert.strictEqual(txt(0, 4), 'RIFF');
assert.strictEqual(txt(8, 4), 'WAVE');
assert.strictEqual(txt(12, 4), 'fmt ');
assert.strictEqual(txt(36, 4), 'data');
assert.strictEqual(view.getUint16(20, true), 1, 'PCM');
assert.strictEqual(view.getUint16(22, true), 1, 'mono');
assert.strictEqual(view.getUint32(24, true), sr, 'sample rate');
assert.strictEqual(view.getUint16(34, true), 16, '16 bits');
assert.strictEqual(view.getUint32(40, true), amostras.length * 2, 'data size');
assert.strictEqual(bytes.length, 44 + amostras.length * 2, 'tamanho total');
assert.strictEqual(view.getInt16(44, true), 32767, 'clipping positivo');
assert.strictEqual(view.getInt16(46, true), -32768, 'clipping negativo');
assert.strictEqual(A.duracaoMs(amostras, sr), 1000);
const vazio = A.wav([], 16000);
assert.strictEqual(vazio.length, 44);
assert.strictEqual(A.duracaoMs([], 16000), 0);
const alta = new Float32Array(48000);
for (let i = 0; i < alta.length; i++) alta[i] = Math.sin(2 * Math.PI * 220 * i / 48000) * 0.5;
const baixa = A.reamostrar(alta, 48000, 16000);
assert.strictEqual(baixa.length, 16000, 'downsample 48k -> 16k');
assert.ok(Math.abs(A.duracaoMs(baixa, 16000) - 1000) <= 1, 'duração preservada');
let rms = 0;
for (const v of baixa) rms += v * v;
rms = Math.sqrt(rms / baixa.length);
assert.ok(rms > 0.25 && rms < 0.45, 'amplitude preservada no downsample: ' + rms.toFixed(3));
assert.strictEqual(A.reamostrar(baixa, 16000, 16000).length, 16000);
assert.strictEqual(A.reamostrar([], 48000, 16000).length, 0);
const wav16 = A.wav(baixa, 16000);
assert.strictEqual(new DataView(wav16.buffer).getUint32(24, true), 16000, 'WAV em 16 kHz');
assert.strictEqual(wav16.length, 44 + 16000 * 2, 'WAV 16k tem 32 KB/s');
console.log('AudioPcm: cabeçalho, tamanho, clipping, mono/16-bit, duração e reamostragem 48k->16k aprovados.');
