'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const Sandbox = require(path.join(__dirname, '..', 'sandbox.js'));
const source = fs.readFileSync(path.join(__dirname, '..', 'sandbox.js'), 'utf8');
const html = fs.readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8');
const app = fs.readFileSync(path.join(__dirname, '..', 'app.js'), 'utf8');
const pkg = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'package.json'), 'utf8'));

function test(nome, fn) {
  fn();
  console.log('OK: ' + nome);
}

test('aceita código e entrada JSON válidos', () => {
  const r = Sandbox.validar('return input.valor * 2;', '{"valor":21}', 3000);
  assert.equal(r.ok, true);
  assert.equal(r.entrada.valor, 21);
  assert.equal(r.timeoutMs, 3000);
});

test('limita código, entrada e tempo de execução', () => {
  assert.equal(Sandbox.validar('', {}, 3000).ok, false);
  assert.equal(Sandbox.validar('x'.repeat(20001), {}, 3000).ok, false);
  assert.equal(Sandbox.validar('return 1', 'x'.repeat(10001), 3000).ok, false);
  assert.equal(Sandbox.validar('return 1', {}, 999999).timeoutMs, 10000);
  assert.equal(Sandbox.validar('return 1', {}, 1).timeoutMs, 500);
});

test('não depende de Node nem expõe APIs quando executado fora do app', async () => {
  const r = await Sandbox.executar('return 1', {}, 1000);
  assert.equal(r.ok, false);
  assert.match(r.erro, /dentro do aplicativo/);
});

test('iframe sem same-origin e worker encerrável por timeout', () => {
  assert.ok(source.includes("setAttribute('sandbox', 'allow-scripts')"));
  assert.ok(!source.includes('allow-same-origin'));
  assert.ok(source.includes('worker-src blob:'));
  assert.ok(source.includes("connect-src \\'none\\'"));
  assert.ok(source.includes('worker.terminate()'));
  assert.ok(source.includes('MAX_CODIGO = 20000'));
  assert.ok(source.includes('MAX_ENTRADA = 10000'));
});

test('painel e integração do núcleo estão empacotados', () => {
  for (const id of ['sandbox-codigo', 'sandbox-entrada', 'sandbox-executar', 'sandbox-saida']) {
    assert.ok(html.includes('id="' + id + '"'), id);
  }
  assert.ok(html.includes('<script src="sandbox.js"></script>'));
  assert.ok(app.includes("id: 'sandbox_js'"));
  assert.ok(pkg.build.files.includes('sandbox.js'));
});

console.log('test_sandbox: isolamento e contratos aprovados');
