'use strict';
/* Gera arquivos com o motor real (arquivos_dev.js) para a auditoria externa em Python. */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const A = require('../arquivos_dev.js');

const destino = process.argv[2];
if (!destino) { console.error('informe a pasta de saída'); process.exit(2); }
fs.mkdirSync(destino, { recursive: true });

const saida = { arquivos: [] };
function gravar(nome, bytes) {
  const p = path.join(destino, nome);
  fs.writeFileSync(p, Buffer.from(bytes));
  saida.arquivos.push({
    nome: nome,
    bytes: bytes.length,
    sha256: crypto.createHash('sha256').update(Buffer.from(bytes)).digest('hex'),
    rel: nome
  });
}

const pdf = A.criar('pdf', 'relatorio', 'Relatório do J.A.R.V.I.S. Nova\nLinha dois com acentuação: ção, ê, ã.\n' + 'x'.repeat(200));
gravar(pdf.nome, pdf.bytes);

const docx = A.criar('docx', 'documento', 'Primeiro parágrafo.\nSegundo parágrafo com <tags> & símbolos.');
gravar(docx.nome, docx.bytes);

const xlsx = A.criar('xlsx', 'planilha', 'Nome;Idade\nAna;30\nBia;25', { aba: 'Pessoas' });
gravar(xlsx.nome, xlsx.bytes);

const csv = A.criar('csv', 'dados.csv', JSON.stringify([{ nome: 'Ana', nota: 9 }, { nome: 'Bia', nota: 8 }]));
gravar(csv.nome, csv.bytes);

const json = A.criar('json', 'config', '{"ativo":true,"itens":[1,2,3]}');
gravar(json.nome, json.bytes);

const zip = A.criar('zip', 'projeto', '', { entradas: [
  { nome: 'README.md', texto: '# Projeto\n' },
  { nome: 'src/main.py', texto: 'print("olá")\n' },
  { nome: 'src/util.py', texto: 'def soma(a, b):\n    return a + b\n' }
] });
gravar(zip.nome, zip.bytes);

console.log(JSON.stringify(saida));
