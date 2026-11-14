'use strict';
/* Teste do consumo de tokens (Fase 3).
 *
 * Duas partes: a conta em si (comportamento real do módulo, com dados que os provedores
 * realmente devolvem) e a ligação dele no app (sem a ligação, a conta não aparece na tela).
 */
const fs = require('node:fs');
const assert = require('node:assert/strict');
const C = require('../consumo_ia.js');

const app = fs.readFileSync('app.js', 'utf8');
const html = fs.readFileSync('index.html', 'utf8');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));

let ok = 0;
function ver(nome, fn) { fn(); ok++; }

/* ---------- Leitura do bloco usage ---------- */

ver('formato OpenAI completo', () => {
  const u = C.lerUso({ prompt_tokens: 120, completion_tokens: 45, total_tokens: 165 });
  assert.deepEqual(u, { prompt: 120, completion: 45, total: 165 });
});

ver('formato entrada/saída (Gemini/Anthropic)', () => {
  const u = C.lerUso({ input_tokens: 30, output_tokens: 12 });
  assert.deepEqual(u, { prompt: 30, completion: 12, total: 42 });
});

ver('total calculado quando só vêm as partes', () => {
  assert.equal(C.lerUso({ prompt_tokens: 7, completion_tokens: 3 }).total, 10);
});

ver('total informado é respeitado mesmo sem as partes', () => {
  const u = C.lerUso({ total_tokens: 900 });
  assert.equal(u.total, 900);
  assert.equal(u.prompt, null);
});

ver('sem usage devolve null (não inventa zero)', () => {
  assert.equal(C.lerUso(null), null);
  assert.equal(C.lerUso(undefined), null);
  assert.equal(C.lerUso({}), null);
  assert.equal(C.lerUso({ total_tokens: 'muitos' }), null);
  assert.equal(C.lerUso({ total_tokens: -5 }), null);
});

ver('número em texto é aceito e arredondado', () => {
  const u = C.lerUso({ total_tokens: '42', prompt_tokens: '40.6' });
  assert.equal(u.total, 42);
  assert.equal(u.prompt, 41);
});

/* ---------- Soma por provedor ---------- */

ver('soma acumula chamadas e tokens', () => {
  let e = {};
  e = C.somar(e, 'groq', { prompt_tokens: 100, completion_tokens: 50, total_tokens: 150 });
  e = C.somar(e, 'groq', { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 });
  assert.equal(e.groq.chamadas, 2);
  assert.equal(e.groq.informados, 2);
  assert.equal(e.groq.prompt, 110);
  assert.equal(e.groq.completion, 55);
  assert.equal(e.groq.total, 165);
});

ver('chamada sem consumo conta como chamada e fica registrada', () => {
  let e = C.somar({}, 'mistral', { prompt_tokens: 5, completion_tokens: 5, total_tokens: 10 });
  e = C.somar(e, 'mistral', null);
  assert.equal(e.mistral.chamadas, 2);
  assert.equal(e.mistral.informados, 1);
  assert.equal(e.mistral.total, 10);
});

ver('somar não altera o estado recebido', () => {
  const antes = {};
  const depois = C.somar(antes, 'groq', { total_tokens: 3 });
  assert.deepEqual(antes, {}, 'o estado antigo precisa continuar intacto');
  assert.equal(depois.groq.total, 3);
});

ver('provedores diferentes não se misturam', () => {
  let e = C.somar({}, 'groq', { total_tokens: 100 });
  e = C.somar(e, 'cerebras', { total_tokens: 7 });
  assert.equal(e.groq.total, 100);
  assert.equal(e.cerebras.total, 7);
});

/* ---------- Frase mostrada ao usuário ---------- */

ver('frase de provedor sem consumo é honesta', () => {
  const e = C.somar({}, 'gemini', null);
  const t = C.resumo(e, 'gemini', 'Gemini');
  assert.match(t, /não informou o consumo/);
  assert.doesNotMatch(t, /tokens informados/);
});

ver('frase com consumo traz números e separador de milhar', () => {
  let e = C.somar({}, 'groq', { prompt_tokens: 1200, completion_tokens: 300, total_tokens: 1500 });
  const t = C.resumo(e, 'groq', 'Groq');
  assert.match(t, /1\.500 tokens informados/);
  assert.match(t, /1\.200 de entrada/);
  assert.match(t, /300 de saída/);
});

ver('frase avisa quando parte das chamadas não teve consumo', () => {
  let e = C.somar({}, 'groq', { total_tokens: 10 });
  e = C.somar(e, 'groq', null);
  assert.match(C.resumo(e, 'groq', 'Groq'), /1 chamada\(s\) sem consumo informado/);
});

ver('sem chamada nenhuma, a frase diz isso', () => {
  assert.match(C.resumo({}, 'groq', 'Groq'), /nenhuma chamada/);
});

ver('lista da tela só mostra quem foi chamado', () => {
  const e = C.somar({}, 'groq', { total_tokens: 4 });
  const lista = C.linhas(e, [{ id: 'groq', nome: 'Groq' }, { id: 'mistral', nome: 'Mistral' }]);
  assert.equal(lista.length, 1);
  assert.match(lista[0], /Groq/);
});

ver('lista vazia explica em vez de ficar em branco', () => {
  const lista = C.linhas({}, [{ id: 'groq', nome: 'Groq' }]);
  assert.equal(lista.length, 1);
  assert.match(lista[0], /Nenhuma chamada/);
});

ver('total geral soma todos os provedores', () => {
  let e = C.somar({}, 'groq', { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 });
  e = C.somar(e, 'mistral', { prompt_tokens: 1, completion_tokens: 1, total_tokens: 2 });
  const t = C.total(e);
  assert.equal(t.chamadas, 2);
  assert.equal(t.total, 17);
  assert.equal(t.prompt, 11);
});

/* ---------- Ligação no app ---------- */

ver('o app guarda o consumo das duas formas de resposta', () => {
  assert.match(app, /anotarConsumo\(p\.id, j && j\.usage\)/, 'caminho sem streaming deve registrar o usage');
  assert.match(app, /anotarConsumo\(p\.id, s\.uso\)/, 'caminho de streaming deve registrar o usage');
});

ver('o streaming pede o consumo e sabe recuar quando o provedor recusa', () => {
  assert.match(app, /stream_options = \{ include_usage: true \}/, 'deve pedir include_usage no streaming');
  assert.match(app, /stream_options\|include_usage/i, 'deve reconhecer a recusa do campo');
  assert.match(app, /p\.usoStream = false/, 'deve desligar o pedido para o provedor que recusou');
});

ver('o streaming lê o bloco usage dos pacotes', () => {
  assert.match(app, /if \(j\.usage\) uso = j\.usage;/, 'cada pacote pode trazer usage (último, normalmente)');
  assert.match(app, /return raw \? \{ ok: true, raw, uso \}/, 'o uso precisa voltar para quem chamou');
});

ver('o consumo é mostrado em Ajustes e no diagnóstico', () => {
  assert.match(app, /function mostrarConsumoIA\(\)/, 'deve existir a função que pinta a tela');
  assert.match(app, /function mostrarChaves\(\) \{\n  mostrarConsumoIA\(\);/, 'Ajustes ▸ IA deve pintar o consumo ao abrir');
  assert.match(app, /'Consumo de IA \(tokens\)'/, 'o diagnóstico deve ter a linha de consumo');
  assert.match(html, /id="c-consumo-ia"/, 'a interface precisa do lugar onde escrever');
});

ver('o consumo sobrevive ao fechamento do app', () => {
  assert.match(app, /const CONSUMO_CHAVE_STORE = 'consumo_ia'/, 'precisa de chave própria no armazenamento');
  assert.match(app, /store\.set\(CONSUMO_CHAVE_STORE, JSON\.stringify\(consumoEstado\)\)/, 'precisa gravar depois de somar');
});

ver('o módulo é carregado pela interface e empacotado', () => {
  assert.match(html, /<script src="consumo_ia\.js"><\/script>/, 'index.html deve carregar o módulo');
  assert.ok(pkg.build.files.includes('consumo_ia.js'), 'o pacote precisa incluir consumo_ia.js');
  assert.match(pkg.scripts['test:all'], /node --check consumo_ia\.js/, 'a suíte deve checar a sintaxe');
  assert.match(pkg.scripts['test:all'], /node tests\/test_consumo_ia\.js/, 'a suíte deve rodar este teste');
});

console.log('Consumo de IA: ' + ok + ' verificações aprovadas.');
