'use strict';
/* Perfis de energia da escuta (Fase 4B) — lado da tela.
 *
 * O Java decide e aplica; aqui testamos a montagem do pedido (recusando horário inválido
 * antes de chamar o Android) e a descrição do estado devolvido. As verificações finais
 * cobram o que precisa existir no serviço nativo, no plugin, na notificação e na tela.
 */
const fs = require('node:fs');
const assert = require('node:assert/strict');
const P = require('../perfil_energia.js');

let ok = 0;
function ver(nome, fn) { fn(); ok++; }

ver('os quatro perfis existem, com rótulo e dica', () => {
  assert.deepEqual(P.PERFIS.map((p) => p.id), ['sempre', 'carregando', 'horario', 'desligado']);
  for (const p of P.PERFIS) {
    assert.ok(p.rotulo.length > 3, p.id + ' precisa de rótulo');
    assert.ok(p.dica.length > 10, p.id + ' precisa explicar');
  }
});

ver('perfil desconhecido cai em "sempre"', () => {
  assert.equal(P.normalizarPerfil('qualquer'), 'sempre');
  assert.equal(P.normalizarPerfil(null), 'sempre');
  assert.equal(P.normalizarPerfil(' HORARIO '), 'horario');
  assert.equal(P.rotulo('carregando'), 'Somente carregando');
});

ver('horas válidas viram minutos', () => {
  assert.equal(P.minutosDeHora('07:30'), 450);
  assert.equal(P.minutosDeHora('7:05'), 425);
  assert.equal(P.minutosDeHora('00:00'), 0);
  assert.equal(P.minutosDeHora('23:59'), 1439);
});

ver('horas inválidas são recusadas', () => {
  for (const t of ['24:00', '12:60', '12', 'abc', '', null, '12:5']) {
    assert.equal(P.minutosDeHora(t), null, 'aceitou ' + t);
  }
});

ver('minutos voltam para HH:MM, presos entre 00:00 e 23:59', () => {
  assert.equal(P.horaDeMinutos(450), '07:30');
  assert.equal(P.horaDeMinutos(0), '00:00');
  assert.equal(P.horaDeMinutos(-10), '00:00');
  assert.equal(P.horaDeMinutos(2000), '23:59');
  assert.equal(P.horaDeMinutos(5), '00:05');
});

ver('perfis sem horário não enviam horas', () => {
  const r = P.montarPedido({ perfil: 'carregando', inicio: 'lixo', fim: 'lixo' });
  assert.equal(r.ok, true);
  assert.deepEqual(r.args, { perfil: 'carregando' });
});

ver('perfil de horário exige janela válida', () => {
  const bom = P.montarPedido({ perfil: 'horario', inicio: '07:00', fim: '23:00' });
  assert.equal(bom.ok, true);
  assert.deepEqual(bom.args, { perfil: 'horario', inicio: 420, fim: 1380 });
  const ruim = P.montarPedido({ perfil: 'horario', inicio: '25:00', fim: '23:00' });
  assert.equal(ruim.ok, false);
  assert.match(ruim.erro, /HH:MM/);
  const igual = P.montarPedido({ perfil: 'horario', inicio: '08:00', fim: '08:00' });
  assert.equal(igual.ok, false);
  assert.match(igual.erro, /meia-noite/);
});

ver('janela que atravessa a meia-noite é aceita', () => {
  const r = P.montarPedido({ perfil: 'horario', inicio: '22:00', fim: '06:00' });
  assert.equal(r.ok, true);
  assert.equal(r.args.inicio, 1320);
  assert.equal(r.args.fim, 360);
});

ver('limite de bateria escolhível: 10, 15 ou 20, padrão 15', () => {
  assert.deepEqual(P.LIMITES_BATERIA, [10, 15, 20]);
  assert.equal(P.normalizarLimite('10'), 10);
  assert.equal(P.normalizarLimite(20), 20);
  assert.equal(P.normalizarLimite(12), 15);
  assert.equal(P.normalizarLimite(null), 15);
  assert.equal(P.normalizarLimite('abc'), 15);
});

ver('o pedido leva o limite escolhido ao serviço', () => {
  const r = P.montarPedido({ perfil: 'sempre', limite: '20' });
  assert.equal(r.ok, true);
  assert.equal(r.args.limiteBateria, 20);
  const sem = P.montarPedido({ perfil: 'sempre', limite: '' });
  assert.equal('limiteBateria' in sem.args, false, 'sem escolha, o serviço mantém o que tem');
  const horario = P.montarPedido({ perfil: 'horario', inicio: '07:00', fim: '23:00', limite: 10 });
  assert.equal(horario.args.limiteBateria, 10);
  assert.equal(horario.args.inicio, 420);
});

ver('resumo mostra o limite de redução', () => {
  const f = P.resumo({ perfil: 'sempre', limiteBateria: 10 });
  assert.match(f, /Limite de redução: 10% de bateria/);
});

ver('resumo avisa quando a bateria reduziu a escuta', () => {
  const f = P.resumo({ perfil: 'sempre', bloqueioBateria: 'bateria em 9% (limite 15%).' });
  assert.match(f, /Redução para poupar bateria.*9%.*volta sozinha/);
  assert.doesNotMatch(f, /pode rodar agora/);
});

ver('resumo descreve cada situação', () => {
  assert.match(P.resumo({ perfil: 'sempre' }), /Sempre ouvindo.*pode rodar agora/);
  assert.match(P.resumo({ perfil: 'horario', horarioInicio: 420, horarioFim: 1380 }), /07:00–23:00/);
  assert.match(P.resumo({ perfil: 'carregando', bloqueio: 'o aparelho está na bateria' }), /Somente carregando.*bateria/);
  assert.match(P.resumo({ perfil: 'sempre', pausadoManual: true }), /pausada por você.*Retomar/);
  assert.match(P.resumo({}), /não informou o perfil/);
});

ver('o nativo tem os quatro perfis e a pausa que sobrevive', () => {
  const prefs = fs.readFileSync('JarvisPrefs.java', 'utf8');
  for (const chave of ['PERFIL_SEMPRE', 'PERFIL_CARREGANDO', 'PERFIL_HORARIO', 'PERFIL_DESLIGADO']) {
    assert.match(prefs, new RegExp(chave + ' = "'));
  }
  assert.match(prefs, /static String perfilEnergia\(Context c\)/);
  assert.match(prefs, /static void perfilEnergia\(Context c, String v\)/);
  assert.match(prefs, /horarioInicio/, 'precisa guardar o início da janela');
  assert.match(prefs, /horarioFim/);
  assert.match(prefs, /pausadoManual/, 'pausa manual precisa persistir');
  assert.match(prefs, /static int limiteBateria\(Context c\)/);
  assert.match(prefs, /LIMITES_BATERIA/, 'precisa oferecer os limites 10/15/20');
});

ver('o serviço respeita o perfil e alterna Pausar/Retomar', () => {
  const s = fs.readFileSync('JarvisService.java', 'utf8');
  assert.match(s, /ACAO_PAUSAR = "com\.jarvis\.nova\.ESCUTA_PAUSAR_MANUAL"/);
  assert.match(s, /ACAO_RETOMAR = "com\.jarvis\.nova\.ESCUTA_RETOMAR"/);
  assert.match(s, /static String bloqueioPerfil\(Context c\)/);
  assert.match(s, /static boolean carregando\(Context c\)/);
  assert.match(s, /perfil Desligado/);
  assert.match(s, /Somente carregando/);
  assert.match(s, /Horários/);
  // A checagem precisa estar dentro do caminho que inicia o microfone, não só na interface.
  const corpo = s.slice(s.indexOf('private void iniciarMotor()'), s.indexOf('private void pausarMotor()'));
  assert.match(corpo, /bloqueioPerfil\(this\)/, 'iniciarMotor precisa consultar o perfil');
  assert.match(s, /pausadoManual\(this\)/);
});

ver('a notificação tem Pausar/Retomar, Abrir e Desligar', () => {
  const s = fs.readFileSync('JarvisService.java', 'utf8');
  const nota = s.slice(s.indexOf('private Notification montarNotificacao()'), s.indexOf('private void notificar()'));
  assert.match(nota, /"Pausar"/);
  assert.match(nota, /"Retomar"/);
  assert.match(nota, /"Abrir"/);
  assert.match(nota, /"Desligar escuta"/);
  assert.match(nota, /ACAO_PAUSAR/);
  assert.match(nota, /ACAO_RETOMAR/);
});

ver('o serviço reduz a escuta por bateria antes de abrir o microfone', () => {
  const s = fs.readFileSync('JarvisService.java', 'utf8');
  assert.match(s, /int limite = JarvisPrefs\.limiteBateria\(c\)/);
  assert.match(s, /static String bloqueioBateria\(Context c\)/);
  assert.match(s, /isPowerSaveMode\(\)/);
  const corpo = s.slice(s.indexOf('private void iniciarMotor()'), s.indexOf('private void pausarMotor()'));
  assert.match(corpo, /bloqueioBateria\(this\)/, 'iniciarMotor precisa consultar a bateria');
  const regra = s.slice(s.indexOf('static String bloqueioBateria'), s.indexOf('static int nivelBateria'));
  assert.match(regra, /economiaEnergia\(c\)/);
  assert.match(regra, /nivel <= limite/);
  assert.match(regra, /!carregando\(c\)/);
});

ver('o plugin expõe leitura, definição, pausa e retomada', () => {
  const p = fs.readFileSync('JarvisBackgroundPlugin.java', 'utf8');
  for (const m of ['estadoEnergia', 'definirPerfilEnergia', 'pausarEscutaManual', 'retomarEscutaManual']) {
    assert.match(p, new RegExp('public void ' + m + '\\(PluginCall call\\)'));
  }
  assert.match(p, /o\.put\("pausadoManual"/);
  assert.match(p, /o\.put\("bloqueioPerfil"/);
  assert.match(p, /o\.put\("carregando"/);
  assert.match(p, /o\.put\("nivelBateria"/);
  assert.match(p, /o\.put\("economiaEnergia"/);
  assert.match(p, /o\.put\("bloqueioBateria"/);
});

ver('a tela tem perfil, horários e ligação com o plugin', () => {
  const html = fs.readFileSync('index.html', 'utf8');
  assert.match(html, /id="c-bg-perfil"/);
  assert.match(html, /id="c-bg-inicio"/);
  assert.match(html, /id="c-bg-fim"/);
  assert.match(html, /id="c-bg-perfil-status"/);
  assert.match(html, /<script src="perfil_energia\.js"><\/script>/);
  const app = fs.readFileSync('app.js', 'utf8');
  assert.match(app, /async function carregarPerfilEnergia\(/);
  assert.match(app, /async function salvarPerfilEnergia\(/);
  assert.match(app, /nativo\('definirPerfilEnergia'/);
  assert.match(app, /PerfilEnergia\.montarPedido\(/);
  assert.match(app, /PerfilEnergia\.resumo\(/);
});

ver('o módulo entra no pacote e na suíte', () => {
  const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
  assert.ok(pkg.build.files.includes('perfil_energia.js'));
  assert.match(pkg.scripts['test:all'], /node tests\/test_perfil_energia\.js/);
  assert.match(pkg.scripts['test:all'], /node --check perfil_energia\.js/);
});

console.log('Perfis de energia: ' + ok + ' verificações aprovadas.');
