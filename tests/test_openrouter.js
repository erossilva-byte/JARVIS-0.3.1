'use strict';
const fs = require('node:fs');
const assert = require('node:assert/strict');

const app = fs.readFileSync('app.js', 'utf8');
const html = fs.readFileSync('index.html', 'utf8');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
const version = JSON.parse(fs.readFileSync('VERSAO.json', 'utf8'));
const desktop = fs.readFileSync('platforms/desktop/main.js', 'utf8');

assert.match(app, /id:\s*'openrouter',\s*nome:\s*'OpenRouter · DeepSeek',\s*url:\s*'https:\/\/openrouter\.ai\/api\/v1'/,
  'OpenRouter deve usar o endpoint OpenAI-compatible oficial.');
assert.match(app, /deepseek\/deepseek-chat/, 'DeepSeek deve ser o modelo inicial do OpenRouter.');
assert.match(app, /const CHAVES = \{[^}]*openrouter:\s*''/, 'OpenRouter deve ter chave independente.');
assert.match(app, /openrouter:\s*'#c-key-openrouter'/, 'A chave deve estar ligada ao campo de configuração.');
assert.match(app, /for \(const n of Object\.keys\(CHAVES\)\)/, 'A carga de chaves deve usar o cofre seguro genérico.');
assert.match(app, /for \(const \[n, sel\] of Object\.entries\(CAMPOS_CHAVE\)\)/, 'Salvar/apagar deve incluir todos os provedores.');
assert.match(app, /filter\(\(p\) => p\.visao !== false\)/, 'OpenRouter textual não pode ser selecionado como motor de visão.');
assert.match(html, /id="c-key-openrouter"/, 'Campo OpenRouter deve existir na interface.');
assert.match(html, /id="c-apagar-openrouter"/, 'Ação de apagar a chave OpenRouter deve existir.');
assert.match(html, /https:\/\/openrouter\.ai/, 'CSP deve permitir a conexão ao endpoint OpenRouter.');
assert.match(desktop, /\^\(groq\|openrouter\|cerebras\|mistral\|gemini\)\$/, 'Cofre Windows deve aceitar OpenRouter e continuar em allowlist.');
assert.equal(pkg.version, '1.46.0', 'package.json deve declarar 1.46.0.');
assert.equal(version.version, '1.46.0', 'VERSAO.json deve declarar 1.46.0.');
assert.equal(version.versionCode, 10460, 'versionCode deve acompanhar 1.46.0.');
console.log('OpenRouter/DeepSeek: 14 verificações estáticas aprovadas.');
