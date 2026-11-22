/* Botões precisam responder honestamente, nunca morrer em silêncio:
 *  1) "Liberar memória" da voz neural (Ajustes ▸ Voz) sem o plugin JarvisVoz;
 *  2) microfone do núcleo quando o ambiente não tem backend de áudio.
 * Parte 1 usa extração/execução do handler (padrão tests/test_diag_dom.js);
 * parte 2 sobe o app inteiro no jsdom e clica no botão de verdade.
 */
'use strict';
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const app = fs.readFileSync(path.join(__dirname, '..', 'app.js'), 'utf8');
const ini = app.indexOf("const btnLiberarNeural = $('#c-neural-liberar');");
const fim = app.indexOf("if (document.getElementById('c-neural-lista'))", ini);
if (ini < 0 || fim < 0 || fim <= ini) throw new Error('não localizei o handler de liberar a memória neural');
const fonte = app.slice(ini, fim);

async function rodar(plugin) {
  const mensagens = [];
  const botao = {};
  const ctx = {
    $: (sel) => (sel === '#c-neural-liberar' ? botao : null),
    neuralPlugin: () => plugin,
    neuralMsg: (texto, erro) => mensagens.push({ texto: String(texto), erro: !!erro }),
    console
  };
  vm.createContext(ctx);
  vm.runInContext(fonte + '\n;globalThis.__botao = btnLiberarNeural;', ctx);
  await ctx.__botao.onclick();
  return mensagens;
}

(async () => {
  const semPlugin = await rodar(null);
  assert.strictEqual(semPlugin.length, 1, 'clique sem plugin deve produzir exatamente uma mensagem');
  assert.ok(/Android/i.test(semPlugin[0].texto), 'mensagem deve dizer onde a voz neural existe: ' + semPlugin[0].texto);
  assert.strictEqual(semPlugin[0].erro, true, 'mensagem de indisponibilidade deve ser de erro');

  let chamadas = 0;
  const comPlugin = await rodar({ liberar: async () => { chamadas++; } });
  assert.strictEqual(chamadas, 1, 'com plugin, liberar() deve ser chamado uma vez');
  assert.ok(comPlugin.some((m) => /liberada/i.test(m.texto)), 'deve confirmar a liberação da memória');

  const falha = await rodar({ liberar: async () => { throw new Error('memória ocupada'); } });
  assert.ok(falha.some((m) => m.erro && /memória ocupada/.test(m.texto)), 'a falha do plugin deve virar mensagem visível');

  console.log('OK: botão liberar memória neural responde em todos os cenários');
  await testarMicSemBackend();
  console.log('OK: botão do microfone explica a falha quando não há gravação disponível');
  process.exit(0); // os timers do boot seguram o event loop
})().catch((e) => { console.error('FALHA: ' + e.message); process.exit(1); });

/* Parte 2: boot completo + clique real no #btn-mic. O jsdom não tem AudioContext
 * nem MediaRecorder, então gravar() devolve null — e o clique precisa virar mensagem.
 */
async function testarMicSemBackend() {
  const { JSDOM, VirtualConsole } = require('jsdom');
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
  await dormir(2500); // boot estabiliza

  const antes = d.querySelectorAll('.msg').length;
  d.getElementById('btn-mic').click();
  for (let i = 0; i < 20; i++) {
    await dormir(150);
    const msgs = Array.from(d.querySelectorAll('.msg'));
    if (msgs.length > antes) {
      const nova = msgs.slice(antes).map((m) => m.textContent).join(' ');
      assert.ok(/microfone/i.test(nova), 'a mensagem do mic deve falar do microfone: ' + nova.slice(0, 160));
      return;
    }
  }
  assert.fail('o clique no microfone não produziu nenhuma mensagem (clique silencioso)');
}
