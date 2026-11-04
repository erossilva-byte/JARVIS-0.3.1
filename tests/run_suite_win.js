#!/usr/bin/env node
'use strict';
/*
 * Roda a MESMA suíte do `npm run test:all` no Windows.
 *
 * O script oficial usa `python3`, que existe no Linux do CI. No Windows,
 * `python3` normalmente é o atalho da Microsoft Store e não executa Python,
 * então a suíte não rodava na máquina de desenvolvimento.
 *
 * Em vez de duplicar a lista de testes (que sairia do lugar na primeira
 * alteração), este lançador lê o próprio `test:all` do package.json e troca
 * apenas a invocação do interpretador por `node tests/python.js`, que escolhe
 * `py -3`/`python`/`python3` conforme a máquina. A suíte oficial permanece
 * intacta, e os testes que conferem o registro em `test:all` continuam válidos.
 */
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const raiz = path.resolve(__dirname, '..');
const pacote = JSON.parse(fs.readFileSync(path.join(raiz, 'package.json'), 'utf8'));
const suite = pacote.scripts && pacote.scripts['test:all'];

if (!suite) {
  console.error('package.json não define scripts["test:all"].');
  process.exit(2);
}

const comando = suite.replace(/\bpython3 /g, 'node tests/python.js ');

console.log('[test:all:win] interpretador Python resolvido por tests/python.js');
const r = spawnSync(comando, {
  cwd: raiz,
  stdio: 'inherit',
  shell: true,
  env: Object.assign({}, process.env, { PYTHONIOENCODING: process.env.PYTHONIOENCODING || 'utf-8' })
});

if (r.error) {
  console.error('Falha ao iniciar a suíte: ' + (r.error.message || r.error));
  process.exit(1);
}
process.exit(r.status === null ? 1 : r.status);
