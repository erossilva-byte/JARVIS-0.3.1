'use strict';
/* "Por que parou?" — explicação a partir do diagnóstico nativo (Fase 4B).
 *
 * Sem aparelho: o objeto de diagnóstico é sintético, com os mesmos campos que
 * `JarvisBackgroundPlugin.diagnosticoEscuta()` devolve. As últimas verificações são estáticas
 * e cobram o botão na tela e a ligação no app.
 */
const fs = require('node:fs');
const assert = require('node:assert/strict');
const S = require('../segundo_plano.js');

let ok = 0;
function ver(nome, fn) { fn(); ok++; }

const AGORA = 1900000000000;

ver('escuta ativa é dita ativa, com o detector', () => {
  const r = S.explicar({ escutando: true, detector: 'Sherpa-ONNX KWS local · limiar 0.35' }, AGORA);
  assert.equal(r.ativa, true);
  assert.equal(r.codigo, 'ativa');
  assert.match(r.titulo, /ativa agora/);
  assert.match(r.detalhe, /Sherpa-ONNX/);
  assert.equal(r.causas.length, 0);
});

ver('escuta desligada pelo usuário vem como primeira causa', () => {
  const r = S.explicar({ escutando: false, desejada: false, mic: true, servico: false }, AGORA);
  assert.equal(r.ativa, false);
  assert.equal(r.codigo, 'desligada');
  assert.match(r.titulo, /desligada por escolha/);
});

ver('microfone negado é identificado', () => {
  const r = S.explicar({ escutando: false, desejada: true, mic: false, notificacoes: true, bateriaLivre: true, servico: false }, AGORA);
  assert.equal(r.codigo, 'microfone');
  assert.ok(r.causas.some((c) => c.codigo === 'microfone'));
});

ver('notificações bloqueadas entram na explicação', () => {
  const r = S.explicar({ mic: true, desejada: true, notificacoes: false, bateriaLivre: true, servico: false }, AGORA);
  assert.equal(r.codigo, 'notificacoes');
  assert.match(r.titulo, /notificações/i);
});

ver('bateria com otimização ativa é citada', () => {
  const r = S.explicar({ mic: true, desejada: true, notificacoes: true, bateriaLivre: false, servico: false }, AGORA);
  assert.equal(r.codigo, 'bateria');
});

ver('serviço parado sem outra causa é a explicação', () => {
  const r = S.explicar({ mic: true, desejada: true, notificacoes: true, bateriaLivre: true, servico: false }, AGORA);
  assert.equal(r.codigo, 'servico');
  assert.match(r.titulo, /não está rodando/);
});

ver('último erro do detector aparece, cortado e explícito', () => {
  const erro = 'x'.repeat(300);
  const r = S.explicar({ mic: true, desejada: true, notificacoes: true, bateriaLivre: true, servico: false, ultimoErro: erro }, AGORA);
  const daErro = r.causas.find((c) => c.codigo === 'erro');
  assert.ok(daErro, 'precisa listar o erro');
  assert.ok(daErro.texto.length < 200, 'texto do erro não pode crescer sem limite');
  assert.ok(daErro.texto.endsWith('…'));
});

ver('sem causa conhecida não inventa diagnóstico', () => {
  const r = S.explicar({ mic: true, desejada: true, notificacoes: true, bateriaLivre: true, servico: true, escutando: false }, AGORA);
  assert.equal(r.codigo, 'sem-causa');
  assert.match(r.titulo, /não registra o motivo/);
});

ver('pausa manual aparece como causa', () => {
  const r = S.explicar({ pausadoManual: true, mic: true, desejada: true, notificacoes: true, bateriaLivre: true, servico: true }, AGORA);
  assert.equal(r.causas[0].codigo, 'pausado');
  assert.match(r.titulo, /Pausar da notificação/);
});

ver('bloqueio de perfil de energia é citado pelo nome', () => {
  const r = S.explicar({ bloqueioPerfil: 'perfil Somente carregando: o aparelho está na bateria.', mic: true, desejada: true, notificacoes: true, bateriaLivre: true, servico: true }, AGORA);
  assert.equal(r.causas[0].codigo, 'perfil');
  assert.match(r.titulo, /Somente carregando/);
});

ver('várias causas são listadas em ordem e no detalhe', () => {
  const r = S.explicar({ desejada: false, mic: false, notificacoes: false, bateriaLivre: false, servico: false, ultimoErro: 'falha X' }, AGORA);
  assert.deepEqual(r.causas.map((c) => c.codigo), ['desligada', 'microfone', 'notificacoes', 'bateria', 'servico', 'erro']);
  assert.match(r.detalhe, /Também encontrei/);
});

ver('redução por bateria entra na explicação', () => {
  const r = S.explicar({ bloqueioBateria: 'bateria em 9% (limite 15%).', mic: true, desejada: true, notificacoes: true, bateriaLivre: true, servico: true }, AGORA);
  assert.equal(r.causas[0].codigo, 'bateria-baixa');
  assert.match(r.titulo, /poupar bateria/);
});

ver('diagnóstico vazio não lança', () => {
  const r = S.explicar({}, AGORA);
  assert.equal(r.ativa, false);
  assert.equal(r.codigo, 'sem-causa');
  const vazio = S.explicar(null, AGORA);
  assert.equal(vazio.codigo, 'sem-causa');
});

ver('tempo do último evento é calculado', () => {
  const r = S.explicar({ escutando: true, ultimoEvento: AGORA - 5 * 60000 }, AGORA);
  assert.equal(r.desdeUltimoEventoMs, 300000);
  assert.match(S.frase(r), /há 5 minuto/);
});

ver('frase junta título, detalhe e último evento', () => {
  const r = S.explicar({ desejada: false, mic: false, ultimoEvento: AGORA - 20000 }, AGORA);
  const f = S.frase(r);
  assert.match(f, /desligada por escolha/);
  assert.match(f, /Também encontrei/);
  assert.match(f, /menos de 1 minuto/);
});

ver('a tela tem o botão e o app usa o módulo', () => {
  const html = fs.readFileSync('index.html', 'utf8');
  assert.match(html, /id="c-bg-porque"/);
  assert.match(html, /id="c-bg-porque-status"/);
  assert.match(html, /<script src="segundo_plano\.js"><\/script>/);
  const app = fs.readFileSync('app.js', 'utf8');
  assert.match(app, /async function explicarParada\(/);
  assert.match(app, /SegundoPlano\.explicar\(/);
  assert.match(app, /SegundoPlano\.frase\(/);
  assert.match(app, /getElementById\('c-bg-porque'\)/);
  assert.match(app, /btnPorque\.onclick = \(\) => \{ explicarParada\(\)/);
});

ver('o módulo entra no pacote, na suíte e no workflow', () => {
  const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
  assert.ok(pkg.build.files.includes('segundo_plano.js'));
  assert.match(pkg.scripts['test:all'], /node --check segundo_plano\.js/);
  assert.match(pkg.scripts['test:all'], /node tests\/test_segundo_plano\.js/);
});

console.log('Segundo plano ("Por que parou?"): ' + ok + ' verificações aprovadas.');
