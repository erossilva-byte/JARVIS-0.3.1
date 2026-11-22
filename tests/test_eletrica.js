/* Base técnica elétrica: dimensionamento, biblioteca, conferência e memória especializada. */
'use strict';
const assert = require('assert');
const path = require('path');
const E = require(path.join(__dirname, '..', 'eletrica.js'));

const memoria = {};
E.usarStore({ getItem: (k) => memoria[k] || null, setItem: (k, v) => { memoria[k] = v; return true; } });

let checks = 0;
function ok(nome) { checks++; console.log('OK: ' + nome); }

// 1 — corrente e escolhas para 5 CV / 380 V
const d5 = E.dimensionar({ cv: 5, trifasico: true, tensaoPotencia: 380 });
assert.ok(d5.ok, 'dimensionar 5 CV');
assert.ok(d5.correnteA > 7 && d5.correnteA < 10, 'In de 5 CV em 380 V (η 0,90 / fp 0,80): ' + d5.correnteA);
assert.ok(d5.contatorA >= d5.correnteA, 'contator >= In');
assert.ok(d5.disjuntorA >= d5.correnteA, 'disjuntor >= In');
assert.ok(d5.termicoFaixa.min <= d5.termicoA && d5.termicoA <= d5.termicoFaixa.max, 'ajuste dentro da faixa do térmico');
assert.ok(d5.caboMm2 >= 1.5 && d5.quedaV <= 4, 'cabo e queda: ' + d5.caboMm2 + ' mm2 / ' + d5.quedaV + '%');
assert.ok(d5.memoria.length >= 5, 'memória de cálculo com todas as etapas');
assert.ok(/não substitui|laborat|catálogo/i.test(d5.fonte), 'fonte declara o limite');
ok('dimensionamento de 5 CV');

// 2 — 15 CV pede contator e cabo maiores
const d15 = E.dimensionar({ cv: 15, trifasico: true, tensaoPotencia: 380 });
assert.ok(d15.correnteA > d5.correnteA * 2, '15 CV tem corrente maior');
assert.ok(d15.contatorA > d5.contatorA && d15.caboMm2 >= d5.caboMm2, 'contator e cabo acompanham');
ok('dimensionamento de 15 CV');

// 3 — monofásico 220 V usa outra fórmula
const d1 = E.dimensionar({ cv: 2, trifasico: false, tensaoPotencia: 220 });
assert.ok(d1.correnteA > d5.correnteA, 'monofásico de 2 CV puxa mais corrente que trifásico de 5 CV: ' + d1.correnteA);
ok('dimensionamento monofásico');

// 4 — sem potência não inventa número
assert.strictEqual(E.dimensionar({}).ok, false, 'sem CV recusa');
ok('recusa sem potência');

// 5 — conferência independente pega contator e cabo insuficientes
const projeto = {
  spec: { cv: 5, trifasico: true, tensaoPotencia: 380 },
  dimensionamento: { correnteA: d5.correnteA, contatorA: 6, disjuntorA: 10, termicoA: d5.termicoA, caboMm2: 0.5 }
};
const conferido = E.conferirDimensionamento(projeto);
assert.strictEqual(conferido.ok, false, 'conferência reprova contator de 6 A para 5 CV');
assert.ok(conferido.faltas.some((f) => f.codigo === 'contator_insuficiente'), 'aponta contator: ' + conferido.faltas.map((f) => f.codigo));
assert.ok(conferido.faltas.some((f) => f.codigo === 'cabo_insuficiente'), 'aponta cabo: ' + conferido.faltas.map((f) => f.codigo).join(','));
const projetoBom = { spec: projeto.spec, dimensionamento: d5 };
assert.ok(E.conferirDimensionamento(projetoBom).ok, 'conferência aprova o dimensionamento correto');
ok('conferência independente de dimensionamento');

// 6 — biblioteca de componentes tem terminais, função, limites e IEC
const c = E.consultar('contator');
assert.ok(c.ok && c.entradas.length >= 1, 'consulta contator');
assert.ok(c.entradas[0].terminais.A1 && c.entradas[0].funcao && c.entradas[0].limites && c.entradas[0].iec, 'entrada completa');
assert.ok(/IEC/.test(c.fonte), 'fonte dos símbolos');
assert.ok(E.consultar('cabo').tabela && E.consultar('cabo').tabela.dados.length >= 5, 'tabela de ampacidade');
assert.strictEqual(E.consultar('xyz inexistente').ok, false, 'assunto desconhecido é recusado');
assert.ok(Object.keys(E.COMPONENTES).length >= 10, 'biblioteca com pelo menos 10 componentes');
ok('biblioteca de componentes');

// 7 — endereçamento de CLP
assert.ok(E.enderecarClp({ I1: '%I0.0', Q1: '%Q0.0' }).ok, 'endereços válidos');
assert.strictEqual(E.enderecarClp({ I1: '%I0.0', I2: '%I0.0' }).ok, false, 'duplicado recusado');
assert.strictEqual(E.enderecarClp({ I1: 'I0.0' }).ok, false, 'formato inválido recusado');
ok('endereçamento de CLP');

// 8 — memória especializada com procedência, sem alegar treinamento
const r = E.registrarReferencia({ titulo: 'Partida direta verificada', texto: 'Contator K1 com selo 13/14; térmico ajustado em 11 A.', fonte: 'projeto validado 1.42.6', tipo: 'projeto', confianca: 'verificada' });
assert.ok(r.ok, 'registra referência');
assert.ok(/não treinamento/.test(r.aviso), 'aviso diferencia memória de treinamento');
assert.strictEqual(r.referencia.confianca, 'verificada', 'procedência guardada');
assert.strictEqual(E.buscarReferencias('selo').treinamento, false, 'busca não afirma treinamento');
assert.ok(E.buscarReferencias('selo').total >= 1, 'busca encontra');
assert.ok(E.apagarReferencia('Partida direta verificada').ok, 'apaga referência');
assert.strictEqual(E.buscarReferencias('').total, 0, 'lista vazia após apagar');
ok('memória especializada');

// 9 — séries ampliadas: 150 CV trifásico cabe e continua coerente
const d150 = E.dimensionar({ cv: 150, trifasico: true, tensaoPotencia: 380 });
assert.ok(d150.ok, '150 CV trifásico dimensiona: ' + d150.erro);
assert.ok(d150.contatorA >= d150.correnteA && d150.disjuntorA >= d150.correnteA,
  'contator/disjuntor >= In em 150 CV: ' + d150.contatorA + '/' + d150.disjuntorA + ' para ' + d150.correnteA);
assert.ok(d150.caboMm2 >= 95, 'cabo de 150 CV: ' + d150.caboMm2);
assert.ok(E.conferirDimensionamento({ spec: { cv: 150, trifasico: true, tensaoPotencia: 380 }, dimensionamento: d150 }).ok,
  'autoconferência de 150 CV');
ok('série ampliada até 150 CV');

// 10 — acima da tabela recusa em vez de entregar aparelho menor que a corrente
const dFora = E.dimensionar({ cv: 1000, trifasico: true, tensaoPotencia: 380 });
assert.strictEqual(dFora.ok, false, 'acima da tabela recusa');
assert.ok(/tabela|catálogo/i.test(dFora.erro), 'erro explica o limite: ' + dFora.erro);
const confFora = E.conferirDimensionamento({ spec: { cv: 1000, trifasico: true, tensaoPotencia: 380 }, dimensionamento: {} });
assert.strictEqual(confFora.ok, false, 'conferência propaga a recusa');
assert.ok(confFora.faltas.some((f) => f.codigo === 'fora_da_tabela'), 'código da falta: ' + confFora.faltas.map((f) => f.codigo));
ok('recusa acima da tabela');

console.log('\nBase elétrica: ' + checks + ' grupos de verificação aprovados.');
