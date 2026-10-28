// Round-trip do Markdown do cofre (1.19.0): memoria.js roda em Node com um store injetado.
'use strict';
const assert = require('node:assert/strict');
const path = require('node:path');
const MEM = require(path.join(__dirname, '..', 'memoria.js'));
const banco = {};
MEM.usarStore({ getItem: (k) => (k in banco ? banco[k] : null), setItem: (k, v) => { banco[k] = String(v); }, removeItem: (k) => { delete banco[k]; } });
MEM.apagarTudo();

const a = MEM.criar({ tema: 'gostos', titulo: 'Café', texto: 'prefiro café sem açúcar', tags: ['cafe'] });
assert.equal(a.ok, true, 'criar nota');
assert.equal(MEM.criar({ tema: 'gostos', titulo: 'Café', texto: 'prefiro café sem açúcar' }).duplicada, true, 'não duplica');

const arqs = MEM.arquivosMarkdown();
assert.equal(arqs.length, 1, 'um arquivo por nota');
assert.match(arqs[0].nome, /^gostos\/cafe-[a-z0-9]{5}\.md$/, 'nome estável por tema + id');
assert.match(arqs[0].texto, /^---\ntitle: "Café"\ntema: gostos\n/, 'frontmatter');
assert.match(arqs[0].texto, /\n# Café\n\nprefiro café sem açúcar/, 'corpo com título');

const md = '---\ntitle: "Projeto X"\ntema: projetos\ntags: [jarvis, cad]\n---\n\n# Projeto X\n\nDecidimos exportar DXF e IFC.\n';
const imp = MEM.importarMarkdown(md);
assert.equal(imp.ok, true, 'importar');
assert.equal(imp.criadas, 1, 'uma nota criada');
assert.equal(MEM.listar('projetos').length, 1, 'tema respeitado');
assert.equal(MEM.importarMarkdown(md).repetidas, 1, 'importação repetida não duplica');
assert.equal(MEM.listar().length, 2, 'cofre com duas notas');

const voltou = MEM.importarMarkdown(MEM.markdown());
assert.equal(voltou.criadas, 0, 'exportar e reimportar o próprio pacote não cria nada');
console.log('memoria.md: round-trip ok — ' + MEM.listar().length + ' notas, ' + MEM.arquivosMarkdown().length + ' arquivo(s) .md');
