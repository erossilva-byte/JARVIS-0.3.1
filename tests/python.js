#!/usr/bin/env node
'use strict';
/*
 * Executa um script Python com o interpretador realmente disponível.
 *
 * Por que existe: a suíte usava `python3` direto. No Linux do CI isso funciona,
 * mas no Windows `python3` costuma ser o atalho da Microsoft Store, que só abre
 * a loja — então `npm run test:all` não rodava na máquina de desenvolvimento,
 * mesmo com Python instalado. Este lançador escolhe, nesta ordem:
 *
 *   1. JARVIS_PYTHON, quando o desenvolvedor quer forçar um interpretador;
 *   2. `py -3` no Windows (lançador oficial do python.org);
 *   3. `python3`, depois `python`.
 *
 * Os argumentos são repassados intactos, inclusive flags como `-m py_compile`.
 * Sai com o mesmo código do script Python.
 */
const { spawnSync } = require('child_process');

const args = process.argv.slice(2);
if (!args.length) {
  console.error('uso: node tests/python.js <script.py|flags> [argumentos...]');
  process.exit(2);
}

const candidatos = [];
if (process.env.JARVIS_PYTHON) {
  const forcado = process.env.JARVIS_PYTHON.trim();
  candidatos.push({ cmd: forcado, prefixo: [] });
}
if (process.platform === 'win32') {
  candidatos.push({ cmd: 'py', prefixo: ['-3'] });
  candidatos.push({ cmd: 'python', prefixo: [] });
} else {
  candidatos.push({ cmd: 'python3', prefixo: [] });
  candidatos.push({ cmd: 'python', prefixo: [] });
}

function disponivel(c) {
  const r = spawnSync(c.cmd, c.prefixo.concat(['--version']), { stdio: 'ignore', windowsHide: true });
  return !r.error && r.status === 0;
}

let ultimoErro = null;
for (const c of candidatos) {
  if (!disponivel(c)) { ultimoErro = c.cmd + ' indisponível'; continue; }
  const r = spawnSync(c.cmd, c.prefixo.concat(args), { stdio: 'inherit', windowsHide: true });
  if (r.error) { ultimoErro = String(r.error.message || r.error); continue; }
  process.exit(r.status === null ? 1 : r.status);
}

console.error('Nenhum interpretador Python encontrado (tentei ' +
  candidatos.map((c) => c.cmd).join(', ') + '). Defina JARVIS_PYTHON.');
if (ultimoErro) console.error('Último erro: ' + ultimoErro);
process.exit(1);
