/* Circuito elétrico dentro do .cad: parse, validação, avisos e netlist.
 * Roda em Node puro (o mesmo cad.js do WebView), sem DOM e sem dependência nova.
 */
'use strict';
const assert = require('assert');
const path = require('path');
const CAD = require(path.join(__dirname, '..', 'cad.js'));

let total = 0;
function chk(nome, cond, detalhe) {
  if (!cond) throw new Error(nome + (detalhe ? ' :: ' + detalhe : ''));
  total++;
  console.log('OK: ' + nome);
}

function documento(circuito, objetos) {
  return JSON.stringify({
    formato: 'CadSimu CAD',
    versao: 1,
    nome: 'teste-circuito',
    unidades: 'mm',
    objetos: objetos || [{ tipo: 'caixa', nome: 'base', dimensoes: [10, 10, 10], posicao: [0, 0, 0] }],
    circuito: circuito
  });
}

const ledComResistor = {
  componentes: [
    { id: 'V1', tipo: 'fonte', valor: 9 },
    { id: 'R1', tipo: 'resistor', valor: 330 },
    { id: 'LED1', tipo: 'led', valor: 2 }
  ],
  conexoes: [
    { de: 'V1.1', para: 'R1.1' },
    { de: 'R1.2', para: 'LED1.1' },
    { de: 'LED1.2', para: 'V1.2' }
  ]
};

// 1. Circuito válido entra, é resumido e gera netlist.
const valido = CAD.parse(documento(ledComResistor));
chk('circuito válido é aceito', valido.ok && valido.doc.circuito, JSON.stringify(valido.erro || ''));
const analise = CAD.analisar(documento(ledComResistor));
chk('análise resume o circuito', analise.ok && /Circuito: 3 componente\(s\)/.test(analise.resumo), analise.resumo);
chk('análise lista os componentes', /R1/.test(analise.resumo) && /LED1/.test(analise.resumo), analise.resumo);
chk('circuito sem erros', analise.circuito && analise.circuito.ok === true, JSON.stringify(analise.circuito && analise.circuito.erros));
const net = CAD.netlist(CAD.parse(documento(ledComResistor)).doc);
chk('netlist tem fonte, resistor e LED', /^V1 \d+ \d+ 9$/m.test(net) && /^R1 \d+ \d+ 330$/m.test(net) && /^D1 \d+ \d+ 2$/m.test(net), net);
chk('netlist termina com .end', /\.end\s*$/.test(net), net);

// 2. Curto na fonte é erro de verdade.
const curto = JSON.parse(JSON.stringify(ledComResistor));
curto.conexoes.push({ de: 'V1.1', para: 'V1.2' });
const rCurto = CAD.parse(documento(curto));
chk('curto na fonte é recusado', !rCurto.ok && /curto/i.test(rCurto.erro), JSON.stringify(rCurto));

// 3. Componente inexistente na conexão é erro.
const fantasma = { componentes: [{ id: 'R1', tipo: 'resistor', valor: 10 }], conexoes: [{ de: 'R1.1', para: 'X9.1' }] };
const rFantasma = CAD.parse(documento(fantasma));
chk('conexão com componente inexistente é recusada', !rFantasma.ok && /não existe/i.test(rFantasma.erro), JSON.stringify(rFantasma));

// 4. Terminal fora da faixa é erro.
const terminalRuim = { componentes: [{ id: 'R1', tipo: 'resistor', valor: 10 }], conexoes: [{ de: 'R1.3', para: 'R1.1' }] };
const rTerminal = CAD.parse(documento(terminalRuim));
chk('terminal fora da faixa é recusado', !rTerminal.ok, JSON.stringify(rTerminal));

// 5. Componente solto vira aviso, não erro.
const solto = JSON.parse(JSON.stringify(ledComResistor));
solto.componentes.push({ id: 'C1', tipo: 'capacitor', valor: 100 });
const rSolto = CAD.parse(documento(solto));
chk('componente solto é avisado sem invalidar o arquivo',
  rSolto.ok && rSolto.avisos.some((a) => /solto/i.test(a)), JSON.stringify(rSolto));

// 6. LED sem resistor em série vira aviso.
const ledSozinho = { componentes: [{ id: 'V1', tipo: 'fonte', valor: 5 }, { id: 'LED1', tipo: 'led', valor: 2 }],
  conexoes: [{ de: 'V1.1', para: 'LED1.1' }, { de: 'LED1.2', para: 'V1.2' }] };
const rLed = CAD.parse(documento(ledSozinho));
chk('LED sem resistor é avisado',
  rLed.ok && rLed.avisos.some((a) => /resistor/i.test(a)), JSON.stringify(rLed));

// 7. Id repetido é erro.
const repetido = { componentes: [{ id: 'R1', tipo: 'resistor', valor: 10 }, { id: 'R1', tipo: 'resistor', valor: 20 }], conexoes: [] };
const rRepetido = CAD.parse(documento(repetido));
chk('id repetido é recusado', !rRepetido.ok && /repetido/i.test(rRepetido.erro), JSON.stringify(rRepetido));

// 8. Terra agrupa tudo em uma rede 0.
const comTerra = {
  componentes: [
    { id: 'V1', tipo: 'fonte', valor: 9 },
    { id: 'R1', tipo: 'resistor', valor: 470 },
    { id: 'G1', tipo: 'terra' }
  ],
  conexoes: [
    { de: 'V1.2', para: 'G1.1' },
    { de: 'R1.2', para: 'G1.1' },
    { de: 'V1.1', para: 'R1.1' }
  ]
};
const netTerra = CAD.netlist(CAD.parse(documento(comTerra)).doc);
chk('terra agrupa as redes em 0', /^R1 \d+ 0 470$/m.test(netTerra), netTerra);

// 9. Arquivo sem circuito continua válido (compatibilidade).
const antigo = CAD.parse(JSON.stringify({
  formato: 'CadSimu CAD', versao: 1, nome: 'sem-circuito', unidades: 'mm',
  objetos: [{ tipo: 'esfera', nome: 'e', posicao: [0, 0, 0], raio: 5 }]
}));
chk('arquivo sem circuito continua válido', antigo.ok && !antigo.doc.circuito);

// 10. Limite de componentes é respeitado.
const grande = { componentes: [], conexoes: [] };
for (let i = 0; i < CAD.LIMITE_COMPONENTES + 1; i++) grande.componentes.push({ id: 'R' + (i + 1), tipo: 'resistor', valor: 1 });
const rGrande = CAD.parse(documento(grande));
chk('limite de componentes é recusado com motivo', !rGrande.ok && /limite/i.test(rGrande.erro), JSON.stringify(rGrande));

console.log('\nCircuito no .cad: ' + total + ' verificações aprovadas.');
