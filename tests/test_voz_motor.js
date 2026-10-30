'use strict';
/* Testes do motor de voz com sinais sintéticos: mesma "voz", outra "voz", ruído,
   clipping, pausas e identificação entre perfis. Não substitui teste com microfone. */
const V = require('../voz_motor.js');

let falhas = 0;
function ok(nome, cond, det) {
  if (cond) console.log('OK: ' + nome);
  else { falhas++; console.log('FALHA: ' + nome + (det !== undefined ? ' -> ' + det : '')); }
}

function ruido(n) {
  let s = 123456789;
  return () => { s = (1103515245 * s + 12345) & 0x7fffffff; return (s / 0x3fffffff) - 1; };
}

/* Voz sintética: harmônicos com envelope de formantes, vibrato, pausas e ruído. */
function voz(f0, formantes, segundos, opts) {
  const o = opts || {}, sr = o.sr || 16000, n = Math.floor(segundos * sr);
  const out = new Float32Array(n), rnd = ruido(n + 3);
  const pausas = o.pausas || [];
  for (let i = 0; i < n; i++) {
    const t = i / sr;
    let amp = 1;
    if (o.fade !== false) {
      const ataque = Math.min(1, t / 0.08), fim = Math.min(1, (segundos - t) / 0.08);
      amp = Math.max(0, Math.min(ataque, fim));
    }
    // Silêncio nas pontas DEPOIS do fade, como numa gravação real: dá piso ao VAD.
    if (t < 0.35 || t > segundos - 0.35) amp = 0;
    for (const p of pausas) if (t >= p[0] && t <= p[1]) amp = 0;
    const f = f0 * (1 + (o.vibrato == null ? 0.03 : o.vibrato) * Math.sin(2 * Math.PI * 4.5 * t));
    let s = 0;
    for (let h = 1; h <= 28; h++) {
      const hz = h * f;
      if (hz > sr / 2 - 200) break;
      let env = h === 1 ? 0.7 : 0.02;
      for (const fm of formantes) env += Math.exp(-Math.pow((hz - fm) / 220, 2));
      s += (env / Math.pow(h, 0.7)) * Math.sin(2 * Math.PI * hz * t + h);
    }
    out[i] = amp * s * (o.ganho || 0.12) + (rnd() * (o.ruido == null ? 0.0005 : o.ruido));
  }
  if (o.clip) for (let i = 0; i < n; i++) out[i] = Math.max(-1, Math.min(1, out[i] * 30));
  return { samples: out, sr };
}

const A1 = voz(115, [620, 1180, 2550], 3.2);
const A2 = voz(118, [640, 1200, 2500], 3.0, { pausas: [[1.2, 1.45]] });
const B1 = voz(215, [850, 1650, 2950], 3.2);
const Aruido = voz(115, [620, 1180, 2550], 3.2, { ruido: 0.02, ganho: 0.12 });
const Baixo = voz(115, [620, 1180, 2550], 3.2, { ganho: 0.02, ruido: 0.0002 });
const Curto = voz(115, [620, 1180, 2550], 0.5);
const Clipado = voz(115, [620, 1180, 2550], 3.0, { clip: true });

const pa = V.analisar(A1.samples, A1.sr);
const pa2 = V.analisar(A2.samples, A2.sr);
const pb = V.analisar(B1.samples, B1.sr);
const pn = V.analisar(Aruido.samples, Aruido.sr);
const pbaixo = V.analisar(Baixo.samples, Baixo.sr);
const pcurto = V.analisar(Curto.samples, Curto.sr);
const pclip = V.analisar(Clipado.samples, Clipado.sr);

ok('vetor tem a dimensão declarada', pa.v.length === V.DIM && V.DIM === 59, pa.v.length);
ok('análise limpa tem qualidade suficiente', pa.qualidade.ok, pa.qualidade.problemas);
ok('detecta fala de 3 s', pa.qualidade.falaSeg >= 2.0, pa.qualidade.falaSeg);
ok('estima pitch na faixa de voz grave', pa.metricas.pitchHz >= 90 && pa.metricas.pitchHz <= 170, pa.metricas.pitchHz);
ok('estima SNR alto no sinal limpo', pa.qualidade.snrDb > 25, pa.qualidade.snrDb);

const mesma = V.similaridade(pa, pa2);
const outra = V.similaridade(pa, pb);
ok('mesma voz fica acima de outra voz', mesma > outra + 0.08, { mesma, outra });
ok('mesma voz passa do limiar padrão', mesma >= 0.72, mesma);
ok('outra voz fica abaixo do limiar', outra < 0.72, outra);

const cMesma = V.comparar(pa, pa2);
const cOutra = V.comparar(pa, pb);
ok('comparação classifica mesma voz como compatível', cMesma.estado === 'compativel', cMesma);
ok('comparação nunca aceita outra voz', cOutra.estado !== 'compativel', cOutra);
ok('comparação com qualidade ruim é inconclusiva', V.comparar(pa, pcurto).estado === 'inconclusivo');
ok('curto é recusado pela qualidade', !pcurto.qualidade.ok, pcurto.qualidade);
ok('clipping é detectado', !pclip.qualidade.ok && pclip.qualidade.clipping > 0.5, pclip.qualidade);
ok('ruído reduz o SNR estimado', pn.qualidade.snrDb < pa.qualidade.snrDb, { limpo: pa.qualidade.snrDb, ruidoso: pn.qualidade.snrDb });
ok('voz baixa ainda é analisada', pbaixo.v.length === V.DIM && pbaixo.qualidade.falaSeg > 1.5, pbaixo.qualidade);

const perfis = [
  { id: 'eu', nome: 'Eu', v: pa.v },
  { id: 'bia', nome: 'Bia', v: pb.v }
];
const idEu = V.identificar(perfis, pa2);
const idBia = V.identificar(perfis, pb);
ok('identifica o perfil correto (eu)', idEu.estado === 'compativel' && idEu.id === 'eu', idEu);
ok('identifica o perfil correto (Bia)', idBia.estado === 'compativel' && idBia.id === 'bia', idBia);
const ambiguo = V.identificar([{ id: 'a', v: pa.v }, { id: 'b', v: pa.v }], pa2);
ok('perfis idênticos resultam em inconclusivo', ambiguo.estado === 'inconclusivo', ambiguo);
const desconhecido = V.identificar([{ id: 'eu', v: pa.v }], pb);
ok('voz desconhecida não é aceita', desconhecido.estado === 'diferente', desconhecido);

ok('pista de replay é apenas indicativa', typeof V.pistaReplay(pa).suspeita === 'boolean');
ok('similaridade fora de faixa é limitada', V.similaridade([1, 0], [-1, 0]) === 0 && V.similaridade([1, 0], [1, 0]) === 1);

if (falhas) { console.log('\n' + falhas + ' verificação(ões) do motor de voz falharam.'); process.exit(1); }
console.log('\nMotor de voz: VAD, pitch, embedding, comparação e identificação verificados com sinais sintéticos.');
