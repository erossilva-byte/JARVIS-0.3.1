/* Ponte CADeSIMU e recusa de topologia trifásica em motor monofásico. */
'use strict';
const assert = require('assert');
const path = require('path');
require(path.join(__dirname, '..', 'eletrica.js'));
const P = require(path.join(__dirname, '..', 'projetista.js'));
P.usarStore({ getItem: () => null, setItem: () => true });

let checks = 0;
function ok(nome) { checks++; console.log('OK: ' + nome); }

const direta = P.projetar('Crie uma partida direta para um motor trifásico de 5 CV com emergência e sinalização.');
assert.ok(direta.ok, 'projeto base');
const ponte = P.conferirTrocaCadesimu(direta.projeto);
assert.ok(ponte.ok, 'ponte aprova projeto válido: ' + ponte.pendencias.join('; '));
assert.strictEqual(ponte.nativo, false, 'ponte não alega formato nativo');
assert.ok(/não é gerado nem lido/.test(ponte.aviso), 'aviso declara o limite');
assert.ok(ponte.verificacoes.length >= 6, 'checklist com verificações');
assert.ok(ponte.verificacoes.every((x) => x.item && typeof x.ok === 'boolean'), 'cada item tem nome e resultado');
ok('ponte aprova projeto válido');

const pac = P.exportarTrocaCadesimu(direta.projeto);
assert.strictEqual(pac.nativo, false, 'exportação não é nativa');
assert.ok(/^JARVIS-CADESIMU-TROCA$/.test(pac.dados.formato), 'formato identificado');
const lido = JSON.parse(pac.texto);
assert.strictEqual(lido.componentes.length, direta.projeto.componentes.length, 'todos os componentes exportados');
assert.ok(lido.componentes.every((c) => c.simbolo_iec && c.terminais), 'cada componente tem símbolo e terminais');
assert.ok(/NETLIST v1/.test(lido.netlist), 'netlist incluída');
assert.ok(pac.bytes > 100 && /\.cadesimu-troca\.json$/.test(pac.nome), 'nome e tamanho do pacote');
ok('pacote de intercâmbio');

const quebrado = JSON.parse(JSON.stringify(direta.projeto));
delete quebrado.componentes[0].pinos['1'];
const ponteQuebrada = P.conferirTrocaCadesimu(quebrado);
assert.strictEqual(ponteQuebrada.ok, false, 'terminal solto reprova a ponte');
assert.ok(ponteQuebrada.pendencias.some((p) => /soltos/.test(p)), 'pendência aponta terminal: ' + ponteQuebrada.pendencias.join('; '));
ok('ponte detecta terminal solto');

const monoRev = P.projetar('Crie uma reversão para motor monofásico de 2 CV.');
assert.strictEqual(monoRev.ok, false, 'reversão monofásica recusada');
assert.strictEqual(monoRev.codigo, 'topologia_trifasica', 'código da recusa');
assert.ok(/trifásico/.test(monoRev.erro), 'recusa explica: ' + monoRev.erro);
const monoDir = P.projetar('Crie uma partida direta para motor monofásico de 2 CV.');
assert.ok(monoDir.ok, 'partida direta monofásica continua válida');
assert.ok(P.validar(monoDir.projeto).ok, 'partida direta monofásica passa na verificação');
ok('topologia trifásica recusada no monofásico');

console.log('\nPonte CADeSIMU: ' + checks + ' grupos de verificação aprovados.');
