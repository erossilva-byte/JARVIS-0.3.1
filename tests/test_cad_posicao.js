/* Posição (x/y) no circuito: opcional, validada e preservada na ida e volta do .cad. */
'use strict';
const assert = require('assert');
const path = require('path');
const CAD = require(path.join(__dirname, '..', 'cad.js'));
CAD.usarStore({ listar: () => [], ler: () => null, gravar: () => true, apagar: () => true, espaco: () => ({}) });

const base = {
  componentes: [
    { tipo: 'fonte', id: 'V1', valor: 9, x: 40, y: 60 },
    { tipo: 'resistor', id: 'R1', valor: 330, x: 150, y: 60 }
  ],
  conexoes: [{ de: 'V1.1', para: 'R1.1' }, { de: 'R1.2', para: 'V1.2' }]
};
const ok = CAD.validarCircuito(base);
assert.ok(ok.ok, 'x/y válidos não podem invalidar: ' + JSON.stringify(ok.erros));

const semPosicao = JSON.parse(JSON.stringify(base));
delete semPosicao.componentes[0].x;
delete semPosicao.componentes[0].y;
assert.ok(CAD.validarCircuito(semPosicao).ok, 'componente sem x/y continua válido (compatibilidade)');

const ruim = JSON.parse(JSON.stringify(base));
ruim.componentes[1].y = 'fora';
const rRuim = CAD.validarCircuito(ruim);
assert.strictEqual(rRuim.ok, false, 'x/y não numérico precisa falhar');
assert.ok(rRuim.erros.some((e) => /x.*y|y.*x/i.test(e)), 'o erro deve citar x/y: ' + rRuim.erros.join(' | '));

const doc = CAD.criar({ nome: 'pos', objetos: [{ tipo: 'caixa', nome: 'placa', dimensoes: [120, 80, 2] }], circuito: base });
const lido = CAD.parse(CAD.serializar(doc));
assert.ok(lido.ok, 'documento com posição precisa reabrir: ' + lido.erro);
const volta = lido.doc.circuito.componentes;
assert.strictEqual(volta[0].x, 40, 'x precisa sobreviver à serialização');
assert.strictEqual(volta[1].y, 60, 'y precisa sobreviver à serialização');

console.log('OK: posição x/y do circuito é opcional, validada e preservada no .cad');
