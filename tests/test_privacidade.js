'use strict';
/* Privacidade da ativação (Fase 4B).
 *
 * Duas provas possíveis sem aparelho: (1) auditoria estática — o caminho do áudio não tem
 * cliente de rede; (2) o texto que a tela mostra a partir do contador do Android. O teste de
 * campo (modo avião e captura externa) está em docs/FASE-4B-PRIVACIDADE.md.
 */
const fs = require('node:fs');
const assert = require('node:assert/strict');
const P = require('../privacidade.js');

let ok = 0;
function ver(nome, fn) { fn(); ok++; }

function semRede(nome) {
  const s = fs.readFileSync(nome, 'utf8');
  for (const api of ['java.net', 'HttpURLConnection', 'OkHttp', 'okhttp', 'new Socket', 'WebSocket', 'URLConnection']) {
    assert.ok(!s.includes(api), nome + ' não pode usar ' + api);
  }
  return s;
}

ver('o detector local não tem nenhum cliente de rede', () => {
  const kws = semRede('JarvisKwsEngine.java');
  assert.match(kws, /AudioRecord/, 'o detector precisa ler o microfone localmente');
  assert.match(kws, /sherpa/i, 'a inferência é do sherpa-onnx no aparelho');
});

ver('o serviço de escuta não abre rede', () => {
  const s = semRede('JarvisService.java');
  assert.match(s, /AudioRecord|JarvisKwsEngine/);
});

ver('o áudio do app não tem caminho de upload', () => {
  for (const f of ['audio_pcm.js', 'escuta_voz.js']) {
    const s = fs.readFileSync(f, 'utf8');
    for (const api of ['fetch(', 'XMLHttpRequest', 'WebSocket', 'navigator.sendBeacon']) {
      assert.ok(!s.includes(api), f + ' não pode usar ' + api);
    }
  }
});

ver('detectar a palavra não dispara envio: só abre a tela e o barramento', () => {
  const s = fs.readFileSync('JarvisService.java', 'utf8');
  const ini = s.indexOf('private void disparar(String texto)');
  const fim = s.indexOf('agendarRearmeSeTelaNaoResponder', ini);
  const corpo = s.slice(ini, fim);
  assert.match(corpo, /abrirTela\(\)/);
  assert.match(corpo, /JarvisWakeBus\.acordou/);
  assert.ok(!/fetch|http|Socket|upload|enviar/i.test(corpo), 'disparar não pode enviar nada');
});

ver('o contador de tráfego é do próprio app, não estimado', () => {
  const s = fs.readFileSync('JarvisService.java', 'utf8');
  assert.match(s, /TrafficStats\.getUidTxBytes\(android\.os\.Process\.myUid\(\)\)/);
  assert.match(s, /static long redeDesdeInicioBytes\(\)/);
  const p = fs.readFileSync('JarvisBackgroundPlugin.java', 'utf8');
  assert.match(p, /o\.put\("redeBytesDesdeInicio"/);
});

ver('zero byte é dito como zero; desconhecido não vira zero', () => {
  assert.match(P.resumo({ redeBytesDesdeInicio: 0 }), /Nenhum byte de rede saiu/);
  assert.match(P.resumo({ redeBytesDesdeInicio: -1 }), /não informou o contador/);
  assert.match(P.resumo({}), /não informou o contador/);
  assert.doesNotMatch(P.resumo({}), /Nenhum byte/);
});

ver('tráfego diferente de zero é informado com unidade e ressalva', () => {
  const f = P.resumo({ redeBytesDesdeInicio: 2048 });
  assert.match(f, /2,0 KB/);
  assert.match(f, /tráfego total do app/);
  assert.match(P.resumo({ redeBytesDesdeInicio: 3 * 1024 * 1024 }), /3,0 MB/);
  assert.match(P.resumo({ redeBytesDesdeInicio: 512 }), /512 B/);
});

ver('a ressalva da ativação local aparece sempre', () => {
  assert.match(P.resumo({ redeBytesDesdeInicio: 0 }), /ativação é local \(sherpa-onnx\)/);
  assert.match(P.resumo({ redeBytesDesdeInicio: 0, escutando: true }), /escuta está ativa agora/);
});

ver('a tela mostra a auditoria e usa o módulo', () => {
  const html = fs.readFileSync('index.html', 'utf8');
  assert.match(html, /id="c-bg-privacidade"/);
  assert.match(html, /<script src="privacidade\.js"><\/script>/);
  const app = fs.readFileSync('app.js', 'utf8');
  assert.match(app, /Privacidade\.resumo\(/);
});

ver('o módulo entra no pacote e na suíte', () => {
  const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
  assert.ok(pkg.build.files.includes('privacidade.js'));
  assert.match(pkg.scripts['test:all'], /node --check privacidade\.js/);
  assert.match(pkg.scripts['test:all'], /node tests\/test_privacidade\.js/);
});

ver('o roteiro de verificação existe e cobre as quatro provas', () => {
  const d = fs.readFileSync('docs/FASE-4B-PRIVACIDADE.md', 'utf8');
  assert.match(d, /inspeção/i);
  assert.match(d, /modo avião/i);
  assert.match(d, /TrafficStats|contador/i);
  assert.match(d, /captura externa|PCAP|roteador/i);
});

console.log('Privacidade da ativação: ' + ok + ' verificações aprovadas.');
