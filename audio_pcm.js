/* J.A.R.V.I.S. Nova — PCM/WAV local (1.42.0).
 * Converte as amostras Float32 já capturadas para um WAV PCM 16-bit mono.
 * Não grava, não envia e não toca áudio; existe para o VAD entregar exatamente
 * o trecho de fala, com pré-roll, sem depender do contêiner do MediaRecorder.
 */
(function (raiz, fabrica) {
  var api = fabrica();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.AudioPcm = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  function limitar(v) {
    var n = Number(v);
    if (!isFinite(n)) return 0;
    return Math.max(-1, Math.min(1, n));
  }
  function pcm16(samples) {
    var a = samples || [];
    var out = new Int16Array(a.length);
    for (var i = 0; i < a.length; i++) {
      var v = limitar(a[i]);
      out[i] = v < 0 ? Math.round(v * 32768) : Math.round(v * 32767);
    }
    return out;
  }
  function escreverTexto(view, offset, txt) {
    for (var i = 0; i < txt.length; i++) view.setUint8(offset + i, txt.charCodeAt(i));
  }
  /** Cabeçalho RIFF/WAVE + PCM 16-bit mono. Retorna Uint8Array. */
  function wav(samples, sampleRate) {
    var sr = Math.max(8000, Math.min(96000, Math.round(Number(sampleRate) || 16000)));
    var pcm = pcm16(samples);
    var bytes = pcm.length * 2;
    var out = new Uint8Array(44 + bytes);
    var view = new DataView(out.buffer);
    escreverTexto(view, 0, 'RIFF');
    view.setUint32(4, 36 + bytes, true);
    escreverTexto(view, 8, 'WAVE');
    escreverTexto(view, 12, 'fmt ');
    view.setUint32(16, 16, true);          // tamanho do bloco fmt
    view.setUint16(20, 1, true);           // PCM
    view.setUint16(22, 1, true);           // mono
    view.setUint32(24, sr, true);
    view.setUint32(28, sr * 2, true);      // byte rate
    view.setUint16(32, 2, true);           // block align
    view.setUint16(34, 16, true);          // bits por amostra
    escreverTexto(view, 36, 'data');
    view.setUint32(40, bytes, true);
    for (var i = 0; i < pcm.length; i++) view.setInt16(44 + i * 2, pcm[i], true);
    return out;
  }
  /** Reamostra mono por média de janela (downsample) ou interpolação (upsample). */
  function reamostrar(samples, sampleRate, targetRate) {
    var n = samples ? samples.length : 0;
    var sr = Math.max(8000, Math.min(96000, Math.round(Number(sampleRate) || 16000)));
    var alvo = Math.max(8000, Math.min(96000, Math.round(Number(targetRate) || 16000)));
    if (!n) return new Float32Array(0);
    if (sr === alvo) return Float32Array.from(samples);
    if (alvo < sr) {
      var razao = sr / alvo;
      var m = Math.max(1, Math.floor(n / razao));
      var out = new Float32Array(m);
      for (var i = 0; i < m; i++) {
        var ini = Math.floor(i * razao), fim = Math.min(n, Math.floor((i + 1) * razao));
        if (fim <= ini) fim = Math.min(n, ini + 1);
        var soma = 0;
        for (var j = ini; j < fim; j++) soma += Number(samples[j]) || 0;
        out[i] = soma / Math.max(1, fim - ini);
      }
      return out;
    }
    var k = sr / alvo;
    var up = new Float32Array(Math.max(1, Math.floor(n / k)));
    for (var q = 0; q < up.length; q++) {
      var pos = q * k, a = Math.floor(pos), frac = pos - a;
      var v0 = Number(samples[a]) || 0, v1 = Number(samples[a + 1]) || v0;
      up[q] = v0 + (v1 - v0) * frac;
    }
    return up;
  }
  function duracaoMs(samples, sampleRate) {
    var sr = Number(sampleRate) || 16000;
    return Math.round((samples ? samples.length : 0) * 1000 / sr);
  }
  return { pcm16: pcm16, wav: wav, duracaoMs: duracaoMs, reamostrar: reamostrar };
});
