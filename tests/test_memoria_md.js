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
assert.match(arqs[0].texto, /jarvis_id: [a-z0-9_-]+/, 'ID estável para sincronização');
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

const snapshot = MEM.arquivosMarkdown().find((arquivo) => arquivo.nome.startsWith('gostos/')).texto;
const snapshotEditado = snapshot
  .replace(/atualizado: .+/, 'atualizado: 2099-01-01T00:00:00.000Z')
  .replace('prefiro café sem açúcar', 'prefiro café coado');
const sync = MEM.sincronizarMarkdown(snapshotEditado);
assert.equal(sync.ok, true, 'sincronizar edição do Obsidian');
assert.equal(sync.atualizadas, 1, 'atualiza a nota pelo ID estável');
assert.equal(MEM.listar('gostos')[0].texto, 'prefiro café coado', 'conteúdo editado volta ao Jarvis');
assert.equal(MEM.sincronizarMarkdown(snapshotEditado).repetidas, 1, 'reimportar edição sincronizada não duplica');

const exportAntesConflito = MEM.arquivosMarkdown().find((arquivo) => arquivo.nome.startsWith('gostos/')).texto.replace(/atualizado: .+/, 'atualizado: 2000-01-01T00:00:00.000Z');
MEM.atualizar(a.nota.id, { texto: 'prefiro café expresso' });
const conflito = MEM.sincronizarMarkdown(exportAntesConflito.replace('prefiro café coado', 'prefiro café passado'));
assert.equal(conflito.ok, true, 'conflito é reportado');
assert.equal(conflito.conflitos.length, 1, 'divergência é identificada');
assert.equal(MEM.listar('gostos')[0].texto, 'prefiro café expresso', 'versão local mais recente é preservada');

const agrupado = MEM.arquivosPorTopico().find((arquivo) => arquivo.nome === MEM.ARQUIVOS.gostos);
assert.ok(agrupado && /<!-- jarvis_id:/.test(agrupado.texto), 'arquivo por tópico carrega ID de cada nota');

/* ---------- Cofre em disco de verdade: grava os .md, relê do disco e importa ----------
 * É o caminho que a ponte do Obsidian usa no PC: um arquivo Markdown por tópico dentro de
 * `Memoria/`. Aqui ele é exercitado com arquivos reais, para provar escrita e leitura em
 * disco — não só a string em memória. */
const fs = require('node:fs');
const os = require('node:os');
const pasta = fs.mkdtempSync(path.join(os.tmpdir(), 'jarvis-cofre-'));
try {
  MEM.apagarTudo();
  MEM.criar({ tema: 'gostos', titulo: 'Café', texto: 'prefiro café sem açúcar' });
  MEM.criar({ tema: 'projetos', titulo: 'Força de atuação', texto: 'atuador de 12 V no portão' });

  const arquivos = MEM.arquivosPorTopico();
  assert.equal(arquivos.length, 2, 'um arquivo por tópico com nota');
  arquivos.forEach((arquivo) => {
    const destino = path.join(pasta, arquivo.nome);
    fs.mkdirSync(path.dirname(destino), { recursive: true });
    fs.writeFileSync(destino, arquivo.texto, 'utf8');
  });
  assert.ok(fs.existsSync(path.join(pasta, 'Memoria', 'Gostos.md')), 'Gostos.md existe no disco');
  assert.ok(fs.existsSync(path.join(pasta, 'Memoria', 'Projetos.md')), 'Projetos.md existe no disco');

  const lidos = fs.readdirSync(path.join(pasta, 'Memoria')).filter((n) => n.endsWith('.md')).sort();
  assert.equal(lidos.length, 2, 'dois arquivos .md gravados');
  const doDisco = lidos.map((nome) => fs.readFileSync(path.join(pasta, 'Memoria', nome), 'utf8')).join('\n');
  assert.match(doDisco, /prefiro café sem açúcar/, 'acento sobrevive à ida e volta pelo disco');
  assert.match(doDisco, /atuador de 12 V no portão/, 'segundo tópico também volta legível');

  MEM.apagarTudo();
  const volta = MEM.importarMarkdown(doDisco);
  assert.equal(volta.ok, true, 'importa o que veio do disco');
  assert.equal(volta.criadas, 2, 'as duas notas voltam do disco');
  assert.equal(MEM.listar().length, 2, 'cofre reconstruído a partir do disco');
  assert.equal(MEM.listar('gostos')[0].texto.trim(), 'prefiro café sem açúcar', 'texto volta idêntico');
  assert.equal(MEM.importarMarkdown(doDisco).repetidas, 2, 'reimportar o mesmo disco não duplica');
  console.log('memoria.md: cofre em disco ok — ' + arquivos.length + ' arquivo(s) gravado(s) e relido(s)');
} finally {
  fs.rmSync(pasta, { recursive: true, force: true });
}
console.log('memoria.md: round-trip ok — ' + MEM.listar().length + ' notas, ' + MEM.arquivosMarkdown().length + ' arquivo(s) .md');
