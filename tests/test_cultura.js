// Testes do acervo local: receitas, bebidas, nutrição, treinos, piadas e sugestões.
const assert = require('assert');
const C = require('../cultura.js');
let ok = 0;
function t(nome, fn) { fn(); ok++; console.log('OK: ' + nome); }

t('receitas completas e pesquisáveis', () => {
  assert.strictEqual(C.receitas().length, 8);
  const r = C.receita('omelete');
  assert.ok(r && r.ingredientes.length >= 3 && r.modo.length >= 3);
  assert.strictEqual(C.receita('inexistente'), null);
  assert.ok(C.receita('').length === 8, 'sem termo devolve o acervo');
});

t('bebidas têm ingredientes e preparo', () => {
  const b = C.bebidas();
  assert.ok(b.length >= 4);
  b.forEach((x) => assert.ok(x.nome && x.ingredientes.length && x.modo));
  assert.ok(b.some((x) => /álcool/.test(x.nome) || /sem álcool/.test(x.nome)));
});

t('nutrição de frutas', () => {
  assert.strictEqual(C.fruta('banana').kcal, 89);
  assert.ok(C.fruta('abacate').destaque);
  assert.strictEqual(C.fruta('jabuticaba'), null);
});

t('treinos por nível', () => {
  assert.ok(C.treino('iniciante').length >= 2);
  assert.ok(C.treino('avançado').every((x) => x.nivel === 'avançado'));
  assert.ok(C.treino('').length >= 5, 'sem nível devolve todos');
});

t('piadas e curiosidades variam', () => {
  assert.notStrictEqual(C.piada(0), C.piada(1));
  assert.ok(C.piada(99).length > 10);
  assert.ok(C.curiosidade(0).length > 20);
});

t('sugestões por tipo', () => {
  assert.strictEqual(C.sugestao('filme').length, 8);
  assert.ok(C.sugestao('série').every((x) => x.titulo));
  assert.ok(C.sugestao('música').every((x) => x.genero));
  assert.ok(C.sugestao('tédio').length >= 5);
  const tudo = C.sugestao('');
  assert.ok(tudo.filmes && tudo.series && tudo.musicas && tudo.atividades);
});

t('busca ignora acentos e cruza categorias', () => {
  assert.ok(C.buscar('frango').some((x) => x.tipo === 'receita'));
  assert.ok(C.buscar('limão').length >= 1);
  assert.ok(C.buscar('banana').some((x) => x.tipo === 'fruta'));
  assert.deepStrictEqual(C.buscar(''), []);
});

console.log('\nCultura: ' + ok + ' grupos de verificação aprovados.');
