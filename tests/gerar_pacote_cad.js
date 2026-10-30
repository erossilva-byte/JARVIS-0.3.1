'use strict';
// Gera um pacote CAD real para o teste em Python conferir com zipfile.
const fs = require('fs');
const path = require('path');
const CAD = require('../cad.js');
const P = require('../cad_projeto.js');
const destino = process.argv[2];
if (!destino) { console.error('uso: node tests/gerar_pacote_cad.js <pasta>'); process.exit(2); }
fs.mkdirSync(destino, { recursive: true });
const doc = CAD.criar({ nome: 'suporte de parede', unidades: 'mm', objetos: [
  { tipo: 'caixa', nome: 'base', posicao: [0, 0, 0], dimensoes: [120, 80, 15] },
  { tipo: 'cilindro', nome: 'furo', posicao: [0, 0, 15], raio: 10, altura: 40 }
] });
const p = P.pacote(doc, { formatos: ['cad', 'dxf', 'stl', 'step'] });
const arquivo = path.join(destino, p.nome);
fs.writeFileSync(arquivo, Buffer.from(p.bytes));
console.log(JSON.stringify({ zip: arquivo, entradas: p.entradas, tamanho: p.tamanho,
  validacao: p.validacao, relatorio: p.relatorio, volumes: P.validar(doc).geometria }));
