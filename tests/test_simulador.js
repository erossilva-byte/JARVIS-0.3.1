// Fase 10 — simulador de circuitos: documento, solver, ERC, explicação e tela.
'use strict';
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const C = require('../circuito.js');

let falhas = 0;
function ok(nome, fn) {
  try { fn(); console.log('OK: ' + nome); }
  catch (e) { falhas++; console.log('FALHA: ' + nome + ' -> ' + e.message); }
}

const EXEMPLO = path.join(__dirname, 'fixtures', 'partida_direta_com_selo.jschem');

function textoExemplo() { return fs.readFileSync(EXEMPLO, 'utf8'); }
function mapaExemplo() { return JSON.parse(textoExemplo()); }
function abrirExemplo() {
  const r = C.abrir(textoExemplo());
  assert.strictEqual(r.ok, true, r.erro);
  return new C.Doc(r.doc);
}
function semFio(mapa, id) {
  const s = mapa.sheets[0];
  s.wires = s.wires.filter((w) => w.id !== id);
  return mapa;
}
function base(comps, fios, fases) {
  const alim = { comando: { fase: 'src:L', neutro: 'src:N' } };
  if (fases) alim.potencia = { fases: fases };
  return {
    schema: 1,
    meta: { tensaoComando: { valor: 220 }, tensaoPotencia: { valor: 380 } },
    sheets: [{
      id: 's1', camadas: ['comando', 'potencia'], alimentacao: alim,
      components: comps, wires: fios
    }]
  };
}
function comp(id, type, ref, camada, params) {
  return { id, type, ref, camada: camada || 'comando', params: params || {}, pos: { x: 0, y: 0 }, rot: 0 };
}
function fio(id, de, para) { return { id, from: de, to: para }; }
function diags(doc, sim) { return C.erc(doc, sim).map((d) => d.codigo); }

ok('Exemplo abre, tem 12 componentes e 19 fios, ERC limpo', () => {
  const mapa = mapaExemplo();
  const doc = new C.Doc(mapa);
  assert.strictEqual(doc.ordem.length, 12);
  assert.strictEqual(doc.wires.length, 19);
  const lista = C.erc(doc, new C.Sim(doc));
  assert.deepStrictEqual(lista, [], JSON.stringify(lista));
});

ok('Selo: S2 liga, corrente de partida 80,5 A e nominal 11,5 A', () => {
  const doc = abrirExemplo();
  const sim = new C.Sim(doc);
  sim.acionar('c-s2', true);
  sim.relogio(500);
  assert.strictEqual(sim.bobina['c-km1'].fechada, true);
  assert.strictEqual(sim.motor['c-m1'].estado, 'PARTINDO');
  assert.strictEqual(sim.correnteMotor('c-m1'), 80.5);
  sim.acionar('c-s2', false);
  sim.relogio(2000);
  assert.strictEqual(sim.bobina['c-km1'].fechada, true, 'o selo deveria manter');
  assert.strictEqual(sim.motor['c-m1'].estado, 'NOMINAL');
  assert.strictEqual(sim.correnteMotor('c-m1'), 11.5);
});

ok('S1 desliga e o circuito não religa sozinho', () => {
  const doc = abrirExemplo();
  const sim = new C.Sim(doc);
  sim.acionar('c-s2', true);
  sim.relogio(300);
  sim.acionar('c-s2', false);
  sim.relogio(300);
  sim.acionar('c-s1', true);
  sim.relogio(50);
  assert.strictEqual(sim.bobina['c-km1'].fechada, false);
  assert.strictEqual(sim.motor['c-m1'].estado, 'PARADO');
  sim.acionar('c-s1', false);
  sim.relogio(1000);
  assert.strictEqual(sim.bobina['c-km1'].fechada, false);
});

ok('Curto entre fase e neutro gera E001', () => {
  const doc = new C.Doc(base(
    [comp('src', 'fonte_comando', 'ALIM'), comp('f2', 'fuse', 'F2')],
    [fio('w0', 'src:L', 'f2:L'), fio('w1', 'src:L', 'src:N')]
  ));
  assert.ok(diags(doc, new C.Sim(doc)).includes('E001'));
});

ok('Lâmpada sem um fio gera E002 apontando o componente', () => {
  const doc = new C.Doc(semFio(mapaExemplo(), 'w18'));
  const e2 = C.erc(doc, new C.Sim(doc)).filter((d) => d.codigo === 'E002');
  assert.ok(e2.some((d) => d.componentes.includes('c-h1')), JSON.stringify(e2));
});

ok('Retenção em paralelo com a parada gera E005', () => {
  const mapa = mapaExemplo();
  const s = mapa.sheets[0];
  s.wires.forEach((w) => {
    if (w.id === 'w14') { w.from = 'c-km1s:13'; w.to = 'c-s1:11'; }
    if (w.id === 'w15') { w.from = 'c-km1s:14'; w.to = 'c-s1:12'; }
  });
  const doc = new C.Doc(mapa);
  assert.ok(diags(doc, new C.Sim(doc)).includes('E005'));
});

ok('Duas bobinas em série: W-SERIE e nenhuma energizada', () => {
  const doc = new C.Doc(base(
    [comp('src', 'fonte_comando', 'ALIM'), comp('f2', 'fuse', 'F2'),
      comp('k1', 'coil', 'K1'), comp('k2', 'coil', 'K2')],
    [fio('w0', 'src:L', 'f2:L'), fio('w1', 'f2:T', 'k1:A1'),
      fio('w2', 'k1:A2', 'k2:A1'), fio('w3', 'k2:A2', 'src:N')]
  ));
  const sim = new C.Sim(doc);
  assert.ok(diags(doc, sim).includes('W-SERIE'));
  assert.strictEqual(sim.bobina.k1.fechada, false);
  assert.strictEqual(sim.bobina.k2.fechada, false);
});

ok('TON de 500 ms dispara no passo certo e reseta ao cair', () => {
  const doc = new C.Doc(base(
    [comp('src', 'fonte_comando', 'ALIM'), comp('f2', 'fuse', 'F2'),
      comp('s2', 'pushbutton_no', 'S2'), comp('kt1', 'timer_ton', 'KT1', 'comando', { presetMs: 500 }),
      comp('kt1c', 'contact_ton_no', 'KT1', 'comando', { pai: 'kt1' }), comp('h1', 'lamp', 'H1')],
    [fio('w0', 'src:L', 'f2:L'), fio('w1', 'f2:T', 's2:13'), fio('w2', 's2:14', 'kt1:A1'),
      fio('w3', 'kt1:A2', 'src:N'), fio('w4', 'f2:T', 'kt1c:15'), fio('w5', 'kt1c:16', 'h1:A1'),
      fio('w6', 'h1:A2', 'src:N')]
  ));
  const sim = new C.Sim(doc);
  sim.acionar('s2', true);
  const t0 = sim.agora;
  let voltas = 0;
  while (!sim.timer.kt1.vencido && voltas++ < 300) sim.passo();
  assert.strictEqual(sim.timer.kt1.vencido, true);
  const dt = sim.agora - t0;
  assert.ok(dt >= 500 && dt <= 510, 'disparou em ' + dt + ' ms');
  sim.acionar('s2', false);
  sim.passo();
  assert.strictEqual(sim.timer.kt1.vencido, false);
});

ok('Mesma sequência produz diário idêntico (determinismo)', () => {
  function rodar() {
    const doc = abrirExemplo();
    const sim = new C.Sim(doc);
    sim.acionar('c-s2', true);
    sim.relogio(300);
    sim.acionar('c-s2', false);
    sim.relogio(700);
    sim.acionar('c-s1', true);
    sim.relogio(200);
    return sim.eventos.map((e) => e.tempo + '|' + e.texto).join('\n');
  }
  assert.strictEqual(rodar(), rodar());
});

function mapReversao(comIntertravamento) {
  const comps = [
    comp('src', 'fonte_comando', 'ALIM'), comp('f2', 'fuse', 'F2'),
    comp('s1', 'pushbutton_nc', 'S1'), comp('s2', 'pushbutton_no', 'S2'),
    comp('s3', 'pushbutton_no', 'S3'), comp('k1', 'coil', 'KM1'), comp('k2', 'coil', 'KM2'),
    comp('km1nc', 'contact_nc', 'KM1', 'comando', { pai: 'k1' }),
    comp('km2nc', 'contact_nc', 'KM2', 'comando', { pai: 'k2' }),
    comp('selo1', 'contact_no', 'KM1', 'comando', { pai: 'k1' }),
    comp('selo2', 'contact_no', 'KM2', 'comando', { pai: 'k2' }),
    comp('f1', 'fuse', 'F1', 'potencia'),
    comp('km1p', 'contactor_power', 'KM1', 'potencia', { pai: 'k1' }),
    comp('km2p', 'contactor_power', 'KM2', 'potencia', { pai: 'k2' }),
    comp('m1', 'motor3p', 'M1', 'potencia', { in: 11.5, ipIn: 7 })
  ];
  const fios = [
    fio('w0', 'src:L', 'f2:L'), fio('w1', 'f2:T', 's1:11'), fio('w2', 's1:12', 's2:13'),
    fio('w5', 's1:12', 's3:23'), fio('w8', 'k1:A2', 'src:N'), fio('w9', 'k2:A2', 'src:N')
  ];
  if (comIntertravamento) {
    fios.push(
      fio('w3', 's2:14', 'km2nc:21'), fio('w4', 'km2nc:22', 'k1:A1'),
      fio('w6', 's3:24', 'km1nc:31'), fio('w7', 'km1nc:32', 'k2:A1')
    );
  } else {
    fios.push(fio('w3', 's2:14', 'k1:A1'), fio('w6', 's3:24', 'k2:A1'));
  }
  fios.push(
    fio('w10', 'selo1:13', 's2:13'), fio('w11', 'selo1:14', 's2:14'),
    fio('w12', 'selo2:13', 's3:23'), fio('w13', 'selo2:14', 's3:24'),
    fio('p1', 'f1:T1', 'km1p:L1'), fio('p2', 'f1:T2', 'km1p:L2'), fio('p3', 'f1:T3', 'km1p:L3'),
    fio('p4', 'km1p:T1', 'm1:U'), fio('p5', 'km1p:T2', 'm1:V'), fio('p6', 'km1p:T3', 'm1:W'),
    fio('p7', 'f1:T1', 'km2p:L1'), fio('p8', 'f1:T2', 'km2p:L2'), fio('p9', 'f1:T3', 'km2p:L3'),
    fio('p10', 'km2p:T1', 'm1:W'), fio('p11', 'km2p:T2', 'm1:V'), fio('p12', 'km2p:T3', 'm1:U')
  );
  return base(comps, fios, ['f1:L1', 'f1:L2', 'f1:L3']);
}

ok('Reversão intertravada: E008 coerente e 60 ciclos sem fechamento simultâneo', () => {
  const doc = new C.Doc(mapReversao(true));
  const sim = new C.Sim(doc);
  assert.ok(!diags(doc, sim).includes('E008'));
  let violacoes = 0;
  for (let i = 0; i < 60; i++) {
    sim.acionar('s2', true); sim.relogio(30 + (i * 7) % 90); sim.acionar('s2', false); sim.relogio(i % 40);
    sim.acionar('s3', true); sim.relogio(30 + (i * 11) % 90); sim.acionar('s3', false); sim.relogio(i % 40);
    if (sim.bobina.k1.fechada && sim.bobina.k2.fechada) violacoes++;
  }
  assert.strictEqual(violacoes, 0);
  const sem = new C.Doc(mapReversao(false));
  assert.ok(diags(sem, new C.Sim(sem)).includes('E008'));
});

ok('Pressão simultânea avisa W-RACE e não passa de um passo', () => {
  const sim = new C.Sim(new C.Doc(mapReversao(true)));
  sim.acionar('s2', true);
  sim.acionar('s3', true);
  let seguidas = 0, pior = 0;
  for (let i = 0; i < 100; i++) {
    sim.passo();
    if (sim.bobina.k1.fechada && sim.bobina.k2.fechada) { seguidas++; pior = Math.max(pior, seguidas); }
    else seguidas = 0;
  }
  assert.ok(sim.eventos.some((e) => /W-RACE/.test(e.texto)));
  assert.ok(pior <= 1, 'pior caso: ' + pior);
});

ok('Tela: guardas de estado, tique e botões', () => {
  const tela = new C.Tela();
  assert.strictEqual(tela.estado, 'SEM_PROJETO');
  assert.strictEqual(tela.play(), 'SEM_PROJETO');
  assert.strictEqual(tela.passo(), 'SEM_PROJETO');
  assert.strictEqual(tela.abrir(textoExemplo()), 'PRONTO');
  const t0 = tela.sim.agora;
  tela.tique(16);
  assert.strictEqual(tela.sim.agora, t0, 'tique parado não avança');
  tela.play();
  tela.tique(16);
  assert.ok(tela.sim.agora > t0);
  assert.strictEqual(tela.pause(), 'PAUSADO');
  assert.strictEqual(tela.reset(), 'PRONTO');
  assert.strictEqual(tela.eventos.length, 0);
  const porId = {};
  tela.botoes().forEach((b) => { porId[b.id] = b.habilitado; });
  assert.deepStrictEqual(porId, { play: true, pause: false, passo: true, reset: true });
});

ok('Diário agrupa por segundo, usa vírgula e corta em 200 linhas', () => {
  const blocos = C.formatarDiario([[0, 'a'], [500, 'b'], [1000, 'c']]);
  assert.strictEqual(blocos.length, 2);
  assert.strictEqual(blocos[0].titulo, '0 s');
  assert.strictEqual(blocos[0].linhas[0].tempo, '0,00 s');
  assert.strictEqual(blocos[1].titulo, '1 s');
  const repetido = C.formatarDiario([[10, 'x'], [10, 'x']]);
  assert.strictEqual(repetido[0].linhas.length, 1, 'linha repetida no mesmo ms não duplica');

  const tela = new C.Tela();
  tela.abrir(textoExemplo());
  tela.play();
  for (let i = 0; i < 130; i++) {
    tela.acionar('c-s2', true); tela.tique(16);
    tela.acionar('c-s2', false); tela.tique(16);
  }
  assert.ok(tela.eventos.length <= 200, 'eventos: ' + tela.eventos.length);
  assert.strictEqual(tela.truncado, true);
});

ok('Explicação: fase interrompida, energizado e sem retorno', () => {
  const tela = new C.Tela();
  tela.abrir(textoExemplo());
  const antes = C.explicar(tela.doc, tela.sim);
  assert.strictEqual(antes.codigo, 'fase_interrompida');
  assert.ok(antes.suspeitos.includes('c-s2'));
  assert.ok(/S2/.test(antes.texto), antes.texto);

  tela.play();
  tela.acionar('c-s2', true);
  tela.passo();
  const depois = C.explicar(tela.doc, tela.sim);
  assert.strictEqual(depois.codigo, 'energizado');
  assert.ok(/KM1/.test(depois.texto), depois.texto);

  const doc = new C.Doc(base(
    [comp('src', 'fonte_comando', 'ALIM'), comp('f2', 'fuse', 'F2'), comp('k1', 'coil', 'KM1')],
    [fio('w0', 'src:L', 'f2:L'), fio('w1', 'f2:T', 'k1:A1')]
  ));
  assert.strictEqual(C.explicar(doc, new C.Sim(doc)).codigo, 'sem_retorno');
});

ok('Explicação prioriza curto e série antes de procurar interrupção', () => {
  const curto = new C.Doc(base(
    [comp('src', 'fonte_comando', 'ALIM')],
    [fio('w0', 'src:L', 'src:N')]
  ));
  assert.strictEqual(C.explicar(curto, new C.Sim(curto)).codigo, 'curto');
  const serie = new C.Doc(base(
    [comp('src', 'fonte_comando', 'ALIM'), comp('f2', 'fuse', 'F2'),
      comp('k1', 'coil', 'K1'), comp('k2', 'coil', 'K2')],
    [fio('w0', 'src:L', 'f2:L'), fio('w1', 'f2:T', 'k1:A1'),
      fio('w2', 'k1:A2', 'k2:A1'), fio('w3', 'k2:A2', 'src:N')]
  ));
  assert.strictEqual(C.explicar(serie, new C.Sim(serie)).codigo, 'serie');
});

ok('Selo só fica verificado com ERC limpo, roteiro rodado e hash igual', () => {
  const tela = new C.Tela();
  tela.abrir(mapaExemplo());
  assert.strictEqual(tela.selo().estado, 'não verificado');
  assert.ok(/ainda não rodou/.test(tela.selo().motivo));
  tela.passo();
  assert.strictEqual(tela.selo().estado, 'verificado');
  assert.strictEqual(tela.selo().solver, 'lógico (MVP)');

  // Mudança externa no documento aberto (edição fora da tela) invalida o selo.
  tela.mapa.meta.titulo = 'outro';
  assert.ok(/documento mudou/.test(tela.selo().motivo), tela.selo().motivo);

  const tela2 = new C.Tela();
  tela2.abrir(semFio(mapaExemplo(), 'w18'));
  tela2.passo();
  assert.strictEqual(tela2.selo().estado, 'não verificado');
  assert.ok(/erro/.test(tela2.selo().motivo), tela2.selo().motivo);
});

ok('Rota é ortogonal, gruda nos pinos e o snap escolhe terminal antes da grade', () => {
  const doc = abrirExemplo();
  let degenerados = 0;
  for (const w of doc.wires) {
    const pts = C.rota(doc, w.id);
    assert.ok(pts && pts.length >= 1, 'rota vazia em ' + w.id);
    const de = w.from.split(':'), para = w.to.split(':');
    const p1 = C.pinPos(doc, de[0], de[1]);
    const p2 = C.pinPos(doc, para[0], para[1]);
    assert.deepStrictEqual(pts[0], p1, 'início solto em ' + w.id);
    assert.deepStrictEqual(pts[pts.length - 1], p2, 'fim solto em ' + w.id);
    // Pinos que caem no mesmo ponto não têm o que desenhar: o exemplo golden
    // usa espaçamento de 40 px e o catálogo 60 px, então isso acontece.
    const coincidem = p1[0] === p2[0] && p1[1] === p2[1];
    assert.strictEqual(pts.length === 1, coincidem, 'comprimento inesperado em ' + w.id);
    if (coincidem) { degenerados++; continue; }
    for (let i = 0; i + 1 < pts.length; i++) {
      const a = pts[i], b = pts[i + 1];
      assert.ok(a[0] === b[0] || a[1] === b[1], 'segmento diagonal em ' + w.id);
    }
  }
  assert.ok(degenerados > 0, 'o exemplo deveria expor os fios degenerados');

  const alvo = C.pinPos(doc, 'c-km1', 'A1');
  const perto = C.snap(doc, [alvo[0] + 20, alvo[1] + 3]);
  assert.strictEqual(perto.tipo, 'terminal');
  assert.strictEqual(perto.terminal, 'c-km1:A1');
  const longe = C.snap(doc, [900, 900]);
  assert.strictEqual(longe.tipo, 'grade');
  assert.strictEqual(longe.ponto[0] % 10, 0);
});

ok('Projeto inválido é recusado com caminho, não "consertado" calado', () => {
  const ruim = mapaExemplo();
  ruim.sheets[0].wires.push({ id: 'wx', from: 'c-fantasma:L', to: 'c-km1:A1' });
  const r = C.abrir(ruim);
  assert.strictEqual(r.ok, false);
  assert.ok(/FIO_ORFAO/.test(r.erro), r.erro);
  const semSchema = C.abrir({ sheets: [] });
  assert.strictEqual(semSchema.ok, false);
  assert.ok(/SCHEMA_AUSENTE|SHEETS/.test(semSchema.erro), semSchema.erro);
  assert.strictEqual(C.abrir('{ nao é json').ok, false);
});

ok('Impressão de documento muda quando o conteúdo muda e ignora verification', () => {
  const a = mapaExemplo();
  const h1 = C.impressaoDocumento(a);
  a.sheets[0].components[0].pos.x += 10;
  const h2 = C.impressaoDocumento(a);
  assert.notStrictEqual(h1, h2);
  a.verification = { estado: 'verificado', docHash: 'x' };
  assert.strictEqual(C.impressaoDocumento(a), h2, 'verification não entra no hash');
});

if (falhas) {
  console.log('\n' + falhas + ' verificação(ões) do simulador falharam.');
  process.exit(1);
}
console.log('\nSimulador de circuitos: documento, solver, ERC, explicação e tela aprovados.');
