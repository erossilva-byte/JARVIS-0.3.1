'use strict';
/* Manutenção periódica com WorkManager (Fase 4B).
 *
 * O texto é puro (testado com relógio fixo); o resto cobra o que precisa existir no
 * Android, no gradle, na tela e no pacote. Sem aparelho, nada além disso é verificável.
 */
const fs = require('node:fs');
const assert = require('node:assert/strict');
const M = require('../manutencao.js');

let ok = 0;
function ver(nome, fn) { fn(); ok++; }

const AGORA = 1900000000000;

ver('nunca rodou é dito sem rodeio', () => {
  const f = M.descrever({ ultimaManutencao: 0, manutencaoAgendada: true }, AGORA);
  assert.match(f, /ainda não rodou/);
  assert.match(f, /a cada 6 horas/);
});

ver('tempo relativo em minutos, horas e dias', () => {
  assert.match(M.descrever({ ultimaManutencao: AGORA - 30000, manutencaoAgendada: true }, AGORA), /agora há pouco/);
  assert.match(M.descrever({ ultimaManutencao: AGORA - 60000, manutencaoAgendada: true }, AGORA), /há 1 minuto\./);
  assert.match(M.descrever({ ultimaManutencao: AGORA - 5 * 60000, manutencaoAgendada: true }, AGORA), /há 5 minutos/);
  assert.match(M.descrever({ ultimaManutencao: AGORA - 3 * 3600000, manutencaoAgendada: true }, AGORA), /há 3 horas/);
  assert.match(M.descrever({ ultimaManutencao: AGORA - 50 * 3600000, manutencaoAgendada: true }, AGORA), /há 2 dias/);
});

ver('não agendada é um aviso, não um "tudo certo"', () => {
  const f = M.descrever({ ultimaManutencao: AGORA - 1000, manutencaoAgendada: false }, AGORA);
  assert.match(f, /não está agendada/);
  assert.doesNotMatch(f, /próxima é agendada/);
});

ver('estado vazio não lança e não inventa', () => {
  const f = M.descrever({}, AGORA);
  assert.match(f, /ainda não rodou/);
  assert.match(f, /não está agendada/);
  assert.match(M.descrever(null, AGORA), /ainda não rodou/);
});

ver('o Worker existe, com restrição de bateria e ciclo de 6 h', () => {
  const w = fs.readFileSync('JarvisManutencaoWorker.java', 'utf8');
  assert.match(w, /public class JarvisManutencaoWorker extends Worker/);
  assert.match(w, /static final String NOME = "jarvis-manutencao"/);
  assert.match(w, /INTERVALO_HORAS = 6/);
  assert.match(w, /setRequiresBatteryNotLow\(true\)/);
  assert.match(w, /enqueueUniquePeriodicWork\(NOME, ExistingPeriodicWorkPolicy\.KEEP/);
  assert.match(w, /JarvisAlarmScheduler\.restaurar\(c\)/);
  assert.match(w, /ultimaManutencao\(c, System\.currentTimeMillis\(\)\)/);
  assert.match(w, /JarvisWatchdog\.agendarRapido\(c, 5000L\)/);
  assert.match(w, /Result\.retry\(\)/);
});

ver('o worker é agendado ao ligar a escuta e depois do reinício', () => {
  const s = fs.readFileSync('JarvisService.java', 'utf8');
  const corpo = s.slice(s.indexOf('static void iniciarEscuta'), s.indexOf('static void pausarEscuta'));
  assert.match(corpo, /JarvisManutencaoWorker\.agendar\(ctx\)/);
  const boot = fs.readFileSync('JarvisBootReceiver.java', 'utf8');
  assert.match(boot, /JarvisManutencaoWorker\.agendar\(ctx\)/);
});

ver('o WorkManager entra no gradle pelo script do projeto', () => {
  const g = fs.readFileSync('patch_gradle.py', 'utf8');
  assert.match(g, /androidx\.work:work-runtime:2\.9\.1/);
  assert.match(g, /injetar_dependencia\(app_text, manutencao_dep\)/);
  for (const w of fs.readdirSync('.github/workflows').filter((f) => f.endsWith('.yml'))) {
    const txt = fs.readFileSync('.github/workflows/' + w, 'utf8');
    if (txt.includes('JarvisService.java')) assert.match(txt, /JarvisManutencaoWorker\.java/, w + ' precisa copiar o Worker');
  }
});

ver('diagnóstico e tela mostram a manutenção', () => {
  const p = fs.readFileSync('JarvisBackgroundPlugin.java', 'utf8');
  assert.match(p, /o\.put\("ultimaManutencao"/);
  assert.match(p, /o\.put\("manutencaoAgendada"/);
  assert.match(p, /public void rodarManutencaoAgora\(PluginCall call\)/);
  const html = fs.readFileSync('index.html', 'utf8');
  assert.match(html, /id="bg-manutencao"/);
  assert.match(html, /id="bg-manutencao-agora"/);
  assert.match(html, /<script src="manutencao\.js"><\/script>/);
  const app = fs.readFileSync('app.js', 'utf8');
  assert.match(app, /Manutencao\.descrever\(/);
  assert.match(app, /rodarManutencaoAgora/);
});

ver('o módulo entra no pacote e na suíte', () => {
  const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
  assert.ok(pkg.build.files.includes('manutencao.js'));
  assert.match(pkg.scripts['test:all'], /node --check manutencao\.js/);
  assert.match(pkg.scripts['test:all'], /node tests\/test_manutencao\.js/);
});

console.log('Manutenção com WorkManager: ' + ok + ' verificações aprovadas.');
