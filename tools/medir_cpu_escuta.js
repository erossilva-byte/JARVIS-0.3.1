// Mede o custo de CPU do laço que roda com a escuta de ativação ligada no PC.
//
// O que é medido: o mesmo trabalho que o app faz a cada quadro — nível em dBFS,
// decisão de fala e, a cada 2,5 s, a conferência da palavra de ativação pelo
// Hermes. O que NÃO é medido: a captura do microfone (driver) e a transcrição
// (rede), que não acontecem nesta máquina.
//
// Uso: node tools/medir_cpu_escuta.js [segundos]
'use strict';
const path = require('node:path');
const V = require(path.join(__dirname, '..', 'voz_pc.js'));
const EscutaVoz = require(path.join(__dirname, '..', 'escuta_voz.js'));
const Hermes = require(path.join(__dirname, '..', 'hermes.js'));

const segundos = Math.max(5, Number(process.argv[2]) || 60);
const QUADRO_MS = 50;                 // o app alimenta o detector a cada 50 ms
const AMOSTRAS = 800;                 // 16 kHz × 50 ms
const quadros = Math.round(segundos * 1000 / QUADRO_MS);
const trechos = Math.max(1, Math.round(segundos / 2.5));
const cfg = Hermes.ativacao.config(55, '');

// Bloco sintético com fala em metade dos quadros e ruído no resto: o detector
// tem que tomar as duas decisões, e não só o caminho barato.
const blocos = [];
// Um segundo falando, um segundo em silêncio: o detector precisa confirmar a
// fala (120 ms) e depois vê-la terminar (500 ms de cauda).
for (let q = 0; q < 40; q++) {
  const bloco = new Float32Array(AMOSTRAS);
  const falando = Math.floor(q / 20) % 2 === 0;
  for (let i = 0; i < AMOSTRAS; i++) {
    const t = (q * AMOSTRAS + i) / 16000;
    bloco[i] = falando ? 0.08 * Math.sin(2 * Math.PI * 180 * t) : 0.002 * Math.sin(2 * Math.PI * 60 * t);
  }
  blocos.push(bloco);
}

const detector = EscutaVoz.criarDetector({ sensibilidade: 0.55, ruidoInicialDb: -55 });
let falas = 0;
let i = 0, iTrecho = 0;
let proximoTrecho = 0;

const medida = V.medirCpu(() => {
  const bloco = blocos[i % blocos.length];
  i++;
  const r = detector.processar(bloco, 16000);
  if (r.inicio) falas++;
  if (i >= proximoTrecho) {
    proximoTrecho = i + Math.round(2500 / QUADRO_MS);
    // Uma transcrição a cada 2,5 s, como no laço real.
    Hermes.ativacao.presente('jarvis ' + (iTrecho % 2 ? 'abrir o navegador' : 'que horas são'), cfg);
    iTrecho++;
  }
}, { quadros });

const porMinutoMs = medida.cpuMs / segundos * 60;
const porHoraMs = porMinutoMs * 60;
const percentualDoAudio = medida.cpuMs / (segundos * 1000) * 100;
console.log('laço de escuta simulado:');
console.log('  quadros: ' + medida.quadros + ' (' + segundos + ' s de áudio a ' + QUADRO_MS + ' ms)');
console.log('  conferências da palavra: ' + trechos);
console.log('  CPU do processo: ' + medida.cpuMs + ' ms');
console.log('  por quadro: ' + medida.porQuadroMs + ' ms');
console.log('  por minuto de áudio: ' + Math.round(porMinutoMs * 100) / 100 + ' ms de CPU');
console.log('  por hora de áudio: ' + Math.round(porHoraMs) + ' ms (' + (porHoraMs / 1000).toFixed(2) + ' s)');
console.log('  fração de um núcleo para processar o áudio: ' + Math.round(percentualDoAudio * 1000) / 1000 + '%');
console.log('  tempo de parede do laço (roda mais rápido que o tempo real): ' + medida.paredeMs + ' ms');
console.log('  inícios de fala detectados: ' + falas);
console.log('  metodologia: ' + medida.metodologia);
