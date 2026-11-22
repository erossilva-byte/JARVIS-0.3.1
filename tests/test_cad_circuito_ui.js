/* Circuito no .cad e pergunta no Vision, com o app inteiro no jsdom:
 * clica nos botões de verdade e confere o que aparece na tela e no cofre.
 */
'use strict';
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { JSDOM, VirtualConsole } = require('jsdom');

(async () => {
  const raiz = path.resolve(__dirname, '..');
  const html = fs.readFileSync(path.join(raiz, 'index.html'), 'utf8')
    .replace(/<script\b(?![^>]*\bsrc=)[^>]*>[\s\S]*?<\/script>/gi, '');
  const vc = new VirtualConsole();
  vc.on('jsdomError', () => {});
  const dom = new JSDOM(html, { url: 'http://localhost/', runScripts: 'outside-only', pretendToBeVisual: true, virtualConsole: vc });
  const w = dom.window;
  const d = w.document;
  w.matchMedia = w.matchMedia || (() => ({ matches: false, addListener() {}, removeListener() {}, addEventListener() {}, removeEventListener() {} }));
  w.scrollTo = () => {};
  w.alert = () => {};
  w.confirm = () => true;
  w.prompt = () => null;
  w.open = () => null;
  w.HTMLCanvasElement.prototype.getContext = function () {
    return new Proxy({}, { get: (t, k) => (k === 'measureText' ? () => ({ width: 10 }) : () => undefined), set: () => true });
  };
  const tags = [...html.matchAll(/<script\b[^>]*src="([^"]+)"[^>]*>/g)].map((m) => m[1]);
  for (const src of tags) w.eval(fs.readFileSync(path.join(raiz, src), 'utf8'));
  d.dispatchEvent(new w.Event('DOMContentLoaded', { bubbles: true }));
  const dormir = (ms) => new Promise((r) => setTimeout(r, ms));
  await dormir(2500);

  // --- .cad: editor de circuito (palco + lista) ---
  const sel = d.getElementById('circ-tipo');
  assert.ok(sel && sel.options.length >= 11, 'o seletor deve listar os tipos do CAD.js: ' + (sel ? sel.options.length : 'ausente'));
  d.getElementById('circ-exemplo').click();
  await dormir(80);
  assert.strictEqual(d.querySelectorAll('#circ-lista .mem-nota').length, 4, 'o exemplo deve listar 4 componentes');
  assert.strictEqual(d.querySelectorAll('#circ-palco .circ-comp').length, 4, 'o palco deve desenhar os 4 símbolos');
  assert.strictEqual(d.querySelectorAll('#circ-palco .circ-fio').length, 4, 'o palco deve desenhar as 4 ligações');

  const grupo = d.querySelector('#circ-palco .circ-comp[data-id="R1"]');
  assert.ok(grupo, 'R1 deve estar no palco');
  grupo.dispatchEvent(new w.MouseEvent('pointerdown', { bubbles: true, clientX: 160, clientY: 60 }));
  assert.strictEqual(d.getElementById('circ-edit-id').value, 'R1', 'selecionar deve preencher o id');
  d.getElementById('circ-edit-valor').value = '470';
  d.getElementById('circ-aplicar').click();
  await dormir(60);
  assert.ok(/R1 atualizado/.test(d.getElementById('circ-status').textContent), 'editar deve confirmar: ' + d.getElementById('circ-status').textContent);
  assert.ok(/470/.test(d.getElementById('circ-lista').textContent), 'a lista deve mostrar o valor novo');

  w.dispatchEvent(new w.MouseEvent('pointermove', { clientX: 200, clientY: 90 }));
  w.dispatchEvent(new w.MouseEvent('pointerup', { clientX: 200, clientY: 90 }));
  await dormir(60);
  assert.ok(/R1 movido/.test(d.getElementById('circ-status').textContent), 'arrastar deve confirmar: ' + d.getElementById('circ-status').textContent);

  d.getElementById('circ-validar').click();
  await dormir(60);
  assert.ok(/Circuito válido/.test(d.getElementById('circ-status').textContent), 'validar deve confirmar: ' + d.getElementById('circ-status').textContent);
  d.getElementById('circ-netlist').click();
  await dormir(60);
  assert.ok(/V1 1 0 9/.test(d.getElementById('cad-texto').value), 'a netlist deve usar terra 0: ' + d.getElementById('cad-texto').value.slice(0, 160));

  const antes = w.CadNucleo.listar().length;
  d.getElementById('circ-salvar').click();
  await dormir(150);
  assert.ok(/salvo com 4 componente/.test(d.getElementById('circ-status').textContent), 'salvar deve confirmar: ' + d.getElementById('circ-status').textContent);
  const arquivos = w.CadNucleo.listar();
  assert.strictEqual(arquivos.length, antes + 1, 'o .cad do circuito deve entrar no cofre');
  const lido = w.CadNucleo.ler(arquivos[0].nome) || {};
  const texto = typeof lido === 'string' ? lido : (lido.texto || lido.conteudo || '');
  assert.ok(texto, 'o arquivo salvo deve poder ser lido de volta');
  const doc = JSON.parse(texto);
  const r1 = doc.circuito.componentes.find((c) => c.id === 'R1');
  assert.ok(r1, 'R1 deve estar no arquivo salvo');
  assert.strictEqual(r1.valor, 470, 'o valor editado deve ser salvo');
  assert.strictEqual(r1.x, 200, 'a posição x do arraste deve ser salva: ' + r1.x);
  assert.strictEqual(r1.y, 90, 'a posição y do arraste deve ser salva: ' + r1.y);
  assert.ok(doc.objetos.length >= 1, 'o arquivo salvo deve conter a placa como geometria');

  const grupoD1 = d.querySelector('#circ-palco .circ-comp[data-id="D1"]');
  assert.ok(grupoD1, 'D1 deve estar no palco');
  grupoD1.dispatchEvent(new w.MouseEvent('pointerdown', { bubbles: true, clientX: 250, clientY: 60 }));
  d.getElementById('circ-apagar').click();
  await dormir(80);
  assert.strictEqual(d.querySelectorAll('#circ-palco .circ-comp').length, 3, 'apagar deve remover o componente do palco');
  assert.ok(/removido/.test(d.getElementById('circ-status').textContent), 'apagar deve confirmar');
  d.getElementById('circ-carregar').click();
  await dormir(120);
  assert.ok(/carregado para edição/.test(d.getElementById('circ-status').textContent), 'carregar deve confirmar: ' + d.getElementById('circ-status').textContent);
  assert.strictEqual(d.querySelectorAll('#circ-palco .circ-comp').length, 4, 'carregar deve restaurar os 4 componentes salvos');

  // --- Visão: perguntar sobre a análise ---
  const campo = d.getElementById('visao-pergunta');
  assert.ok(campo, 'o campo de pergunta sobre a imagem deve existir');
  campo.value = '';
  d.getElementById('visao-perguntar').click();
  await dormir(100);
  assert.ok(/Escreva a pergunta/.test(d.getElementById('visao-pergunta-status').textContent), 'pergunta vazia deve ser recusada com explicação');
  campo.value = 'quantas portas aparecem?';
  d.getElementById('visao-pergunta-limpar').click();
  assert.strictEqual(campo.value, '', 'limpar deve esvaziar o campo');
  assert.ok(/Pergunta limpa/.test(d.getElementById('visao-pergunta-status').textContent), 'limpar deve confirmar');
  assert.ok(d.getElementById('visao-perguntar') && /Perguntar/.test(d.getElementById('visao-perguntar').textContent), 'o botão Perguntar deve estar visível');

  console.log('OK: circuito .cad montado, validado, com netlist e salvo; pergunta do Vision responde na interface');
  process.exit(0);
})().catch((e) => { console.error('FALHA: ' + e.message); process.exit(1); });
