'use strict';
/* Fone desconectado e microfone usado por outro app (Fase 4B).
 *
 * Sem aparelho, a parte de comportamento é testada no módulo de explicação (com o mesmo
 * objeto que o plugin devolve); o resto cobra o que precisa existir no serviço Android.
 */
const fs = require('node:fs');
const assert = require('node:assert/strict');
const S = require('../segundo_plano.js');

let ok = 0;
function ver(nome, fn) { fn(); ok++; }

const AGORA = 1900000000000;
const BASE = { mic: true, desejada: true, notificacoes: true, bateriaLivre: true, servico: true };

ver('outro app no microfone entra como causa', () => {
  const r = S.explicar(Object.assign({}, BASE, { bloqueioMicrofone: 'outro app está usando o microfone (com.exemplo.gravador).' }), AGORA);
  assert.equal(r.causas[0].codigo, 'microfone-ocupado');
  assert.match(r.titulo, /outro app está usando o microfone/);
});

ver('fone desconectado tem causa própria', () => {
  const r = S.explicar(Object.assign({}, BASE, { pausaFoneSegundos: 4 }), AGORA);
  assert.equal(r.causas[0].codigo, 'fone');
  assert.match(r.titulo, /fone foi desconectado/);
});

ver('as duas causas podem coexistir, na ordem', () => {
  const r = S.explicar(Object.assign({}, BASE, {
    bloqueioMicrofone: 'outro app está usando o microfone.',
    pausaFoneSegundos: 2
  }), AGORA);
  assert.deepEqual(r.causas.map((c) => c.codigo), ['microfone-ocupado', 'fone']);
});

ver('sem esses campos nada muda', () => {
  const r = S.explicar(Object.assign({}, BASE, { pausaFoneSegundos: 0 }), AGORA);
  assert.equal(r.causa, undefined);
  assert.equal(r.codigo, 'sem-causa');
});

ver('a linha viva mostra o outro app e a pausa', () => {
  const m = S.microfone({ bloqueioMicrofone: 'outro app está usando o microfone (com.exemplo.gravador).' });
  assert.equal(m.ocupado, true);
  assert.equal(m.nivel, 'erro');
  assert.match(m.texto, /Microfone em uso/);
  assert.match(m.texto, /com\.exemplo\.gravador/);
  assert.match(m.texto, /até o outro app liberar/);
});

ver('a linha viva distingue fone, escuta ativa e serviço parado', () => {
  assert.match(S.microfone({ pausaFoneSegundos: 3 }).texto, /Fone desconectado.*3 s/);
  assert.equal(S.microfone({ escutando: true }).nivel, 'ok');
  assert.match(S.microfone({ escutando: true }).texto, /escuta está ativa/);
  assert.match(S.microfone({ escutando: false, servico: false }).texto, /serviço de escuta não está rodando/);
  assert.match(S.microfone({ escutando: false, servico: true }).texto, /não está ativa neste momento/);
  assert.equal(S.microfone({ bloqueioMicrofone: 'x' }).nivel !== 'erro', false);
});

ver('a tela consulta em tempo real só com a aba aberta', () => {
  const app = fs.readFileSync('app.js', 'utf8');
  assert.match(app, /async function atualizarMicrofoneAgora\(\)/);
  assert.match(app, /function iniciarVigiaMicrofone\(\)/);
  assert.match(app, /function pararVigiaMicrofone\(\)/);
  assert.match(app, /clearInterval\(vigiaMicrofone\)/);
  assert.match(app, /\}, 2500\)/);
  assert.match(app, /document\.hidden \|\| !painel \|\| painel\.hidden/);
  assert.match(app, /pararVigiaMicrofone\(\); mudarCategoriaConfig/);
  assert.match(app, /iniciarVigiaMicrofone\(\)/);
  assert.match(app, /SegundoPlano\.microfone\(/);
  const html = fs.readFileSync('index.html', 'utf8');
  assert.match(html, /id="c-bg-microfone"/);
  const plugin = fs.readFileSync('JarvisBackgroundPlugin.java', 'utf8');
  assert.match(plugin, /public void estadoMicrofone\(PluginCall call\)/);
});

ver('o serviço detecta microfone ocupado sem gravar áudio de ninguém', () => {
  const s = fs.readFileSync('JarvisService.java', 'utf8');
  assert.match(s, /static String bloqueioMicrofone\(Context c\)/);
  assert.match(s, /getActiveRecordingConfigurations\(\)/);
  assert.match(s, /getClientPackageName\(\)/);
  assert.match(s, /getClientAudioSessionId\(\)/, 'precisa reconhecer a própria sessão de áudio');
  assert.match(s, /if \(pkg\.equals\(c\.getPackageName\(\)\)\) continue;/, 'precisa ignorar o próprio app');
  const kws = fs.readFileSync('JarvisKwsEngine.java', 'utf8');
  assert.match(kws, /int sessaoAudio\(\)/, 'o motor precisa informar a sessão do AudioRecord');
  const corpo = s.slice(s.indexOf('private void iniciarMotor()'), s.indexOf('private void pausarMotor()'));
  assert.match(corpo, /bloqueioMicrofone\(this\)/, 'iniciarMotor precisa consultar o microfone');
});

ver('a pausa do fone dura 5 s e volta sozinha', () => {
  const s = fs.readFileSync('JarvisService.java', 'utf8');
  assert.match(s, /long pausaFoneAte = 0/);
  assert.match(s, /System\.currentTimeMillis\(\) < pausaFoneAte/);
  assert.match(s, /pausaFoneAte = System\.currentTimeMillis\(\) \+ 5000/);
  assert.match(s, /ACTION_AUDIO_BECOMING_NOISY/);
  assert.match(s, /pausarPorFone\(\)/);
});

ver('o receptor do fone é registrado e desregistrado', () => {
  const s = fs.readFileSync('JarvisService.java', 'utf8');
  assert.match(s, /ContextCompat\.registerReceiver\(this, foneReceiver/);
  assert.match(s, /unregisterReceiver\(foneReceiver\)/);
  assert.match(s, /foneRegistrado = true/);
  assert.match(s, /foneRegistrado = false/);
});

ver('enquanto ouve, o serviço reage ao microfone tomado', () => {
  const s = fs.readFileSync('JarvisService.java', 'utf8');
  const monitor = s.slice(s.indexOf('private final Runnable monitorMidia'), s.indexOf('static boolean escutando()'));
  assert.match(monitor, /bloqueioMicrofone\(JarvisService\.this\)/);
  assert.match(monitor, /Escuta pausada: /);
});

ver('o diagnóstico expõe os dois motivos', () => {
  const p = fs.readFileSync('JarvisBackgroundPlugin.java', 'utf8');
  assert.match(p, /o\.put\("bloqueioMicrofone"/);
  assert.match(p, /o\.put\("pausaFoneSegundos"/);
  const servico = fs.readFileSync('JarvisService.java', 'utf8');
  assert.match(servico, /static long pausaFoneRestanteMs\(\)/);
});

console.log('Fone e microfone disputado: ' + ok + ' verificações aprovadas.');
