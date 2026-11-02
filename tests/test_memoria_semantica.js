'use strict';
const assert = require('node:assert/strict');
const MEM = require('../memoria.js');
const db = {};
MEM.usarStore({
  getItem: (k) => (k in db ? db[k] : null),
  setItem: (k, v) => { db[k] = String(v); },
  removeItem: (k) => { delete db[k]; }
});
MEM.apagarTudo();

const atlas = MEM.criar({ tema: 'projetos', titulo: 'Projeto Atlas', texto: 'O aplicativo Atlas usa Python e fica no repositório do GitHub.', tags: ['atlas', 'python'] });
const casa = MEM.criar({ tema: 'contextos', titulo: 'Minha casa', texto: 'A residência fica na rua das Flores, apartamento 12.', tags: ['casa'] });
const respostas = MEM.criar({ tema: 'preferencias', titulo: 'Respostas curtas', texto: 'Prefiro respostas curtas e diretas, sem listas longas.', tags: ['estilo'] });
assert.ok(atlas.ok && casa.ok && respostas.ok);

// 1. Consultas parafraseadas encontram a nota certa, sem exigir as mesmas palavras.
let r = MEM.buscarSemantica('onde está o programa do Atlas?', 5);
assert.equal(r[0].nota.id, atlas.nota.id);
assert.equal(r.length, 1, 'notas sem relação não entram no RAG');
r = MEM.buscarSemantica('meu apartamento', 5);
assert.equal(r[0].nota.id, casa.nota.id);
r = MEM.buscarSemantica('como gosto das respostas?', 5);
assert.equal(r[0].nota.id, respostas.nota.id);
assert.ok(!r.some((x) => x.nota.id === casa.nota.id), 'stopwords não podem casar por acidente');

// 2. Busca literal continua funcionando; fallback semântico amplia a cobertura.
assert.equal(MEM.buscar('Projeto Atlas')[0].id, atlas.nota.id);
assert.equal(MEM.buscar('programa do projeto Atlas')[0].id, atlas.nota.id);
assert.equal(MEM.buscar('lar')[0].id, casa.nota.id);

// 3. Embedding é determinístico, normalizado e comparável.
const a = MEM.embedding('programa do Atlas');
const b = MEM.embedding('programa do Atlas');
assert.equal(a.length, MEM.embedding('x').length);
assert.ok(MEM.cosseno(a, b) > 0.9999);
assert.ok(MEM.cosseno(a, MEM.embedding('apartamento')) < 0.9);

// 4. Contexto do RAG inclui o relevante e corta o irrelevante.
const ctx = MEM.contextoRelevante('qual a linguagem do repositório Atlas?', 400);
assert.ok(ctx.includes('Projeto Atlas'));
assert.ok(!ctx.includes('Flores'));
assert.ok(ctx.length <= 400);

// 5. Atualização guarda versão anterior e permite restaurar.
const up = MEM.atualizar(atlas.nota.id, { texto: 'Atlas agora usa Rust.' });
assert.equal(up.ok, true);
assert.equal(up.alterada, true);
const h = MEM.historico(atlas.nota.id);
assert.equal(h.length, 1);
assert.ok(h[0].texto.includes('Python'));
assert.equal(MEM.carregar().find((n) => n.id === atlas.nota.id).texto, 'Atlas agora usa Rust.');
const volta = MEM.restaurar(atlas.nota.id, 0);
assert.equal(volta.ok, true);
assert.ok(volta.nota.texto.includes('Python'));
const h2 = MEM.historico(atlas.nota.id);
assert.equal(h2.length, 2, 'restauração também preserva a versão substituída');
assert.ok(h2.some((v) => v.texto.includes('Rust')));
assert.ok(h2.some((v) => v.texto.includes('Python')));

// 6. Uso frequente é registrado, sem alterar o conteúdo.
MEM.reforcar(atlas.nota.id);
assert.ok(MEM.carregar().find((n) => n.id === atlas.nota.id).usos >= 1);

// 7. Importação do Obsidian não sobrescreve nota com mesmo título e conteúdo diferente.
const md = '---\ntitle: "Projeto Atlas"\ntema: projetos\ntags: [atlas]\n---\n\n# Projeto Atlas\n\nAgora usa Rust e não é a mesma nota.\n';
const imp = MEM.importarMarkdown(md);
assert.equal(imp.ok, true);
assert.equal(imp.conflitos.length, 1);
assert.ok(imp.conflitos[0].motivo.includes('nada foi sobrescrito'));
assert.ok(MEM.carregar().find((n) => n.id === atlas.nota.id).texto.includes('Python'));

// 8. O módulo continua puro: sem DOM, rede ou execução de código.
const fonte = require('fs').readFileSync(require.resolve('../memoria.js'), 'utf8');
assert.ok(!/\beval\s*\(|\bFunction\s*\(|fetch\s*\(/.test(fonte));
console.log('Memória semântica: paráfrase, stopwords, embedding, RAG, versões, restauração e conflito Obsidian aprovados.');
