// Testes do núcleo da Visão 2.0 (visao.js). Roda sem DOM: só geometria e texto.
const assert = require('assert');
const V = require('../visao.js');

function retangulo(pos) {
  const largura = 320, altura = 420;
  return {
    x: (pos.x / 100) * largura - pos.largura / 2,
    y: (pos.y / 100) * altura - pos.altura / 2,
    w: pos.largura,
    h: pos.altura
  };
}
function cruza(a, b) {
  return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
}

// ---------- 1. Objetos empilhados no mesmo ponto não geram balões sobrepostos ----------
const empilhados = Array.from({ length: 10 }, (_, i) => ({
  nome: 'objeto ' + (i + 1),
  caixa: { x: 0.45, y: 0.45, w: 0.1, h: 0.1 }
}));
const layout = V.layoutBaloes(empilhados, { largura: 320, altura: 420 });
assert.strictEqual(layout.length, 10, 'um balão por objeto');
const rets = layout.map(retangulo);
for (let i = 0; i < rets.length; i++) {
  for (let j = i + 1; j < rets.length; j++) {
    assert.ok(!cruza(rets[i], rets[j]), 'balão ' + i + ' sobrepõe o balão ' + j);
  }
}
console.log('OK: 10 objetos no mesmo ponto, nenhum balão sobreposto');

// ---------- 2. Nenhum balão sai da imagem ----------
const perto = [
  { nome: 'canto superior', caixa: { x: 0, y: 0, w: 0.02, h: 0.02 } },
  { nome: 'canto inferior', caixa: { x: 0.98, y: 0.98, w: 0.02, h: 0.02 } },
  { nome: 'borda direita', caixa: { x: 1, y: 0.5, w: 0.01, h: 0.01 } }
];
V.layoutBaloes(perto, { largura: 240, altura: 320 }).forEach((pos) => {
  const r = {
    x: (pos.x / 100) * 240 - pos.largura / 2,
    y: (pos.y / 100) * 320 - pos.altura / 2,
    w: pos.largura, h: pos.altura
  };
  assert.ok(r.x >= 0 && r.y >= 0, 'balão começa fora da imagem');
  assert.ok(r.x + r.w <= 240 + 0.001 && r.y + r.h <= 320 + 0.001, 'balão termina fora da imagem');
});
console.log('OK: balões presos dentro da imagem');

// ---------- 3. Linha-guia liga o balão ao centro real do objeto ----------
const guia = V.layoutBaloes([{ nome: 'x', caixa: { x: 0.2, y: 0.3, w: 0.2, h: 0.2 } }], { largura: 300, altura: 400 })[0];
assert.ok(guia.linha, 'linha-guia presente');
assert.ok(Math.abs(guia.linha.x2 - 30) < 2 && Math.abs(guia.linha.y2 - 40) < 2, 'guia aponta para o centro do objeto');
console.log('OK: linha-guia no centro do objeto');

// ---------- 4. Objeto sem caixa vai para a lista, não para a imagem ----------
const semCaixa = V.layoutBaloes([{ nome: 'sem posição' }, { nome: 'com', caixa: { x: 0.1, y: 0.1, w: 0.1, h: 0.1 } }]);
assert.strictEqual(semCaixa[0].semCaixa, true);
assert.strictEqual(semCaixa[1].semCaixa, false);
console.log('OK: objeto sem caixa separado da imagem');

// ---------- 5. Imagem minúscula: colisão é marcada, não escondida ----------
const apertado = Array.from({ length: 12 }, () => ({ nome: 'n', caixa: { x: 0.5, y: 0.5, w: 0.1, h: 0.1 } }));
const pequeno = V.layoutBaloes(apertado, { largura: 130, altura: 170 });
assert.ok(pequeno.some((p) => p.colisao === true), 'colisão impossível deve ser marcada');
console.log('OK: colisão impossível marcada para agrupamento');

// ---------- 6. Vídeo: timestamps distribuídos, sem extremos ----------
const plano = V.planoQuadros(60, 6);
assert.strictEqual(plano.length, 6);
assert.ok(plano[0] > 0 && plano[plano.length - 1] < 60, 'quadros dentro da duração');
assert.deepStrictEqual(plano, plano.slice().sort((a, b) => a - b), 'ordem crescente');
assert.deepStrictEqual(V.planoQuadros(0, 6), []);
assert.strictEqual(V.planoQuadros(0.2, 6).length, 0);
assert.strictEqual(V.planoQuadros(60, 99).length, 12, 'limite superior de quadros');
console.log('OK: plano de quadros de vídeo');

// ---------- 7. Timestamp e relato ----------
assert.strictEqual(V.timestamp(0), '0:00');
assert.strictEqual(V.timestamp(65.9), '1:05');
const relato = V.relatoVideo([
  { t: 4, resumo: 'uma mesa', objetos: [{ nome: 'mesa' }] },
  { t: 18, resumo: 'uma janela', objetos: [] }
]);
assert.ok(relato.indexOf('[0:04] uma mesa') === 0, relato);
assert.ok(relato.indexOf('[0:18] uma janela') > 0);
assert.strictEqual(V.relatoVideo([]), 'Nenhum quadro foi analisado.');
console.log('OK: timestamps e relato do vídeo');

// ---------- 8. Texto do balão preserva o resumo geral ----------
const texto = V.textoAnalise('Resumo geral.', { nome: 'caneca', info: 'branca' });
assert.ok(texto.indexOf('Resumo geral.') === 0 && texto.indexOf('caneca: branca') > 0);
console.log('OK: texto do balão soma resumo e detalhe');

console.log('test_visao_nova: 8 grupos de verificação passaram');
