// Projeto CAD no celular: reparo, validação, conversão com reabertura, script e pacote.
'use strict';
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const CAD = require('../cad.js');
const P = require('../cad_projeto.js');

let falhas = 0;
function ok(nome, fn) {
  try { fn(); console.log('OK: ' + nome); }
  catch (e) { falhas++; console.log('FALHA: ' + nome + ' -> ' + e.message); }
}
async function okAsync(nome, fn) {
  try { await fn(); console.log('OK: ' + nome); }
  catch (e) { falhas++; console.log('FALHA: ' + nome + ' -> ' + e.message); }
}

function docBom() {
  return CAD.criar({ nome: 'suporte', unidades: 'mm', objetos: [
    { tipo: 'caixa', nome: 'base', posicao: [0, 0, 0], dimensoes: [100, 60, 20] },
    { tipo: 'cilindro', nome: 'pino', posicao: [0, 0, 20], raio: 6, altura: 30 }
  ] });
}

ok('Frase vira projeto com duas primitivas e unidade', () => {
  const r = P.criarDeTexto('crie uma caixa 120x80x30 com um cilindro raio 8 altura 25 em cm chamado suporte');
  assert.strictEqual(r.ok, true, r.erro);
  assert.strictEqual(r.unidades, 'cm');
  assert.strictEqual(r.objetos, 2);
  assert.deepStrictEqual(r.doc.objetos[0].dimensoes, [120, 80, 30]);
  assert.strictEqual(r.doc.objetos[1].raio, 8);
});

ok('Projeto bom é aprovado com geometria medida', () => {
  const v = P.validar(docBom());
  assert.strictEqual(v.ok, true, v.resumo);
  assert.ok(v.geometria.triangulos > 0);
  assert.ok(v.geometria.volume > 100000, 'volume: ' + v.geometria.volume);
  assert.strictEqual(v.geometria.fechada, true);
});

ok('Problemas estruturais são detectados, não escondidos', () => {
  const ruim = { formato: 'CadSimu CAD', versao: 1, nome: 'ruim', unidades: 'mm', objetos: [
    { tipo: 'caixa', nome: 'a', posicao: [0, 0, 0], dimensoes: [0, 10, 10] },
    { tipo: 'caixa', nome: 'b', posicao: 'aqui', dimensoes: [10, 10, 10] },
    { tipo: 'caixa', nome: 'c', posicao: [0, 0, 0], dimensoes: [10, 10, 10] },
    { tipo: 'caixa', nome: 'c', posicao: [0, 0, 0], dimensoes: [10, 10, 10] },
    { tipo: 'pirâmide', nome: 'd' }
  ] };
  const p = P.problemas(ruim);
  const codigos = p.map((x) => x.codigo);
  for (const c of ['dimensoes', 'posicao', 'tipo', 'duplicado', 'nome-repetido']) {
    assert.ok(codigos.includes(c), 'faltou ' + c + ' em ' + codigos.join(','));
  }
  assert.strictEqual(P.validar(ruim).ok, false);
});

ok('Reparo corrige campos, remove duplicata e revalida', () => {
  const ruim = { formato: 'CadSimu CAD', versao: 1, nome: 'ruim', unidades: 'xx', objetos: [
    { tipo: 'caixa', nome: 'a', posicao: [0, 0, 0], dimensoes: [0, 10, 10] },
    { tipo: 'caixa', nome: 'b', posicao: 'aqui', dimensoes: [10, 10, 10] },
    { tipo: 'caixa', nome: 'c', posicao: [0, 0, 0], dimensoes: [10, 10, 10] },
    { tipo: 'caixa', nome: 'c', posicao: [0, 0, 0], dimensoes: [10, 10, 10] },
    { tipo: 'pirâmide', nome: 'd' }
  ] };
  const antes = JSON.stringify(ruim);
  const r = P.reparar(ruim);
  assert.strictEqual(r.ok, true, r.erro);
  assert.ok(r.correcoes.length >= 4, r.correcoes.join(' | '));
  // Depois de corrigir a posição, b fica idêntico a c: a deduplicação deixa 2, de propósito.
  assert.strictEqual(r.doc.objetos.length, 2);
  assert.ok(r.correcoes.some((c) => /Duplicata/.test(c)), r.correcoes.join(' | '));
  assert.strictEqual(r.doc.unidades, 'mm');
  assert.strictEqual(JSON.stringify(ruim), antes, 'o documento de entrada não pode ser alterado');
  assert.strictEqual(P.validar(r.doc).ok, true);
  assert.ok(CAD.parse(r.texto).ok);
});

ok('Reparo sem objeto válido não devolve sucesso falso', () => {
  const r = P.reparar({ formato: 'CadSimu CAD', versao: 1, objetos: [{ tipo: 'pirâmide' }] });
  assert.strictEqual(r.ok, false);
  assert.ok(/não sobrou|inválido/i.test(r.erro), r.erro);
});

ok('Script OpenSCAD converte cm para mm e fecha a sintaxe', () => {
  const doc = CAD.criar({ nome: 'peca cm', unidades: 'cm', objetos: [
    { tipo: 'caixa', nome: 'b', posicao: [0, 0, 0], dimensoes: [10, 5, 2] },
    { tipo: 'cilindro', nome: 'c', posicao: [0, 0, 2], raio: 1, altura: 3 }
  ] });
  const s = P.gerarScad(doc);
  assert.strictEqual(s.ok, true, s.problemas.join('; '));
  assert.ok(/escala = 10;/.test(s.texto));
  assert.ok(/cube\(\[10, 5, 2\]/.test(s.texto), s.texto);
  assert.ok(/cylinder\(/.test(s.texto));
  assert.ok(!/NaN|undefined/.test(s.texto));
  assert.ok(/NÃO executa/i.test(s.aviso));
});

ok('Matriz de formatos declara o que não existe', () => {
  const lista = P.formatos();
  const porId = {};
  lista.forEach((f) => { porId[f.id] = f; });
  assert.strictEqual(porId.dwg.escreve, false);
  assert.strictEqual(porId.iges.escreve, false);
  assert.strictEqual(porId.scad.escreve, true);
  assert.strictEqual(porId['cad-cadesimu'].le, false);
  assert.ok(/NÃO é o \.cad do CADe SIMU/.test(porId.cad.pc));
});

ok('Pacote traz projeto, trocas, script, relatório e instruções', () => {
  const p = P.pacote(docBom(), { formatos: ['cad', 'dxf', 'stl', 'step'] });
  assert.strictEqual(p.ok, true, p.falhas.join('; '));
  for (const nome of ['suporte.cad', 'suporte.dxf', 'suporte.stl', 'suporte.step', 'suporte.scad', 'RELATORIO.md', 'LEIA-ME.txt', 'projeto.json']) {
    assert.ok(p.entradas.includes(nome), 'faltou ' + nome + ' em ' + p.entradas.join(','));
  }
  assert.strictEqual(p.falhas.length, 0, p.falhas.join('; '));
  assert.ok(p.tamanho > 2000, 'tamanho: ' + p.tamanho);
  assert.ok(p.relatorio.includes('MEDIDO aqui'));
  assert.ok(p.relatorio.includes('NÃO SUPORTADO'));
  assert.ok(p.relatorio.includes('APROVADA'));
});

(async () => {
  await okAsync('Conversão para DXF reabre e desenha', async () => {
    const r = await P.converter(docBom(), 'dxf');
    assert.strictEqual(r.ok, true, r.erro);
    assert.strictEqual(r.validacao.ok, true, r.validacao.detalhe);
    assert.ok(r.validacao.detalhe.includes('segmento'));
  });
  await okAsync('Conversão para STL reabre com malha fechada', async () => {
    const r = await P.converter(docBom(), 'stl');
    assert.strictEqual(r.validacao.ok, true, r.validacao.erro);
    assert.ok(/malha fechada/.test(r.validacao.detalhe), r.validacao.detalhe);
  });
  await okAsync('Conversão para STEP relê entidades', async () => {
    const r = await P.converter(docBom(), 'step');
    assert.strictEqual(r.validacao.ok, true, r.validacao.erro);
    assert.ok(/entidade/.test(r.validacao.detalhe), r.validacao.detalhe);
  });
  await okAsync('Conversão para IFC relê elementos', async () => {
    const r = await P.converter(docBom(), 'ifc');
    assert.strictEqual(r.validacao.ok, true, r.validacao.erro);
    assert.ok(/elemento/.test(r.validacao.detalhe), r.validacao.detalhe);
  });
  await okAsync('Conversão para 3MF relê a malha', async () => {
    const r = await P.converter(docBom(), '3mf');
    assert.strictEqual(r.validacao.ok, true, r.validacao.erro);
  });
  await okAsync('Formato não suportado é recusado com motivo', async () => {
    const r = await P.converter(docBom(), 'dwg');
    assert.strictEqual(r.ok, false);
    assert.ok(/não é gerado|DWG/i.test(r.erro), r.erro);
  });

  if (falhas) { console.log('\n' + falhas + ' verificação(ões) do projeto CAD falharam.'); process.exit(1); }
  console.log('\nProjeto CAD: reparo, validação, conversão e pacote aprovados.');
})();
