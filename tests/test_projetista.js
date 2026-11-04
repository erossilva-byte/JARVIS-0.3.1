/* Projetista elétrico: interpretação, projeto, verificação, correção e arquivo.
 * Roda em Node puro (o mesmo módulo que o aplicativo carrega no WebView).
 */
'use strict';
const assert = require('assert');
const path = require('path');
require(path.join(__dirname, '..', 'eletrica.js'));
const P = require(path.join(__dirname, '..', 'projetista.js'));
P.usarStore({ getItem: () => null, setItem: () => true });

let checks = 0;
function ok(nome) { checks++; return nome; }

// 1..6 — interpretação dos seis exemplos da missão
const pedidos = {
  direta: 'Crie uma partida direta para um motor trifásico de 5 CV, com proteção, botão de emergência, liga/desliga e sinalização.',
  reversao: 'Crie um circuito de reversão de motor trifásico com dois contatores e intertravamento elétrico e mecânico.',
  estrela: 'Desenvolva uma partida estrela-triângulo automática com temporizador de 8 segundos.',
  compensadora: 'Crie uma partida compensadora para motor trifásico de 15 CV.',
  clp: 'Crie um sistema de controle de nível de água usando CLP, sensores e bomba.',
  comando: 'Monte um comando liga/desliga com selo e sinaleiro em 24 V.'
};
const esperado = { direta: 'partida_direta', reversao: 'reversao', estrela: 'estrela_triangulo', compensadora: 'compensadora', clp: 'clp', comando: 'comando' };
Object.keys(pedidos).forEach((k) => {
  const i = P.interpretar(pedidos[k]);
  assert.ok(i.ok, ok('interpretar ' + k));
  assert.strictEqual(i.spec.tipo, esperado[k], 'tipo de ' + k + ': ' + i.spec.tipo);
  checks++;
});
assert.strictEqual(P.interpretar(pedidos.direta).spec.cv, 5, ok('CV lido do pedido'));
assert.strictEqual(P.interpretar(pedidos.compensadora).spec.cv, 15, ok('CV da compensadora'));
assert.strictEqual(P.interpretar(pedidos.estrela).spec.temporizador, 8, ok('temporizador lido'));
assert.strictEqual(P.interpretar(pedidos.comando).spec.tensaoComando, 24, ok('comando em 24 V'));
assert.strictEqual(P.interpretar('').ok, false, ok('pedido vazio é recusado'));

// 7 — todo pedido gera projeto que passa na verificação
const projetos = {};
Object.keys(pedidos).forEach((k) => {
  const r = P.projetar(pedidos[k]);
  assert.ok(r.ok, ok('projetar ' + k));
  const v = P.validar(r.projeto);
  assert.ok(v.ok, 'projeto ' + k + ' deveria passar: ' + v.erros.map((e) => e.codigo + ' ' + e.mensagem).join(' | '));
  assert.ok(r.projeto.componentes.length >= 4, 'componentes de ' + k);
  assert.ok(P.fios(r.projeto).length >= 3, 'fios de ' + k);
  assert.ok(r.projeto.sequencia.length >= 3, 'sequência de ' + k);
  projetos[k] = r.projeto;
  checks++;
});

// 8 — determinismo: mesmo pedido, mesmo projeto
assert.strictEqual(JSON.stringify(P.projetar(pedidos.direta).projeto), JSON.stringify(projetos.direta), ok('projeto determinístico'));

// 9 — relatório declara o que foi e o que não foi verificado
const rel = P.relatorio(projetos.direta);
['RELATÓRIO TÉCNICO', 'VERIFICAÇÃO', 'Simulação funcional: não executada', 'CADeSIMU: não aberto'].forEach((t) => {
  assert.ok(rel.includes(t), 'relatório deve conter "' + t + '"');
  checks++;
});

// 10 — ladder do CLP com endereços
const lad = P.ladder(projetos.clp);
assert.ok(lad.includes('%Q0.0') && lad.includes('TABELA DE ENTRADAS/SAÍDAS'), ok('ladder com saída e tabela de I/O'));
assert.ok(/não tem lógica de CLP/.test(P.ladder(projetos.direta)), ok('ladder recusa projeto sem CLP'));

// 11 — arquivo do projeto volta pela reabertura
const texto = P.serializar(projetos.reversao);
const lido = P.parse(texto);
assert.ok(lido.ok, ok('projeto reabre'));
assert.strictEqual(lido.projeto.componentes.length, projetos.reversao.componentes.length, ok('componentes preservados'));
assert.strictEqual(P.parse('{"formato":"outro"}').ok, false, ok('formato errado é recusado'));

// 12 — partida direta tem proteção, emergência e selo de verdade
const direta = projetos.direta;
assert.ok(direta.componentes.some((c) => c.tipo === 'releTermico'), ok('tem relé térmico'));
assert.ok(direta.componentes.some((c) => c.papel === 'emergencia'), ok('tem emergência'));
const k1 = direta.componentes.find((c) => c.id === 'K1');
assert.ok(k1.pinos['13'] && k1.pinos['14'] && k1.pinos['13'] !== k1.pinos['14'], ok('contato de selo ligado em duas redes'));

// 13 — reversão perde o intertravamento e a correção devolve
function semIntertravamento(projeto) {
  const p = JSON.parse(JSON.stringify(projeto));
  const k2 = p.componentes.find((c) => c.id === 'K2');
  delete k2.pinos['21'];
  delete k2.pinos['22'];
  const s1 = p.componentes.find((c) => c.id === 'S1');
  s1.pinos['1'] = 'CI';
  const k1c = p.componentes.find((c) => c.id === 'K1');
  k1c.pinos['13'] = 'CI';
  k1c.pinos['14'] = 'K1A';
  return p;
}
const semTrava = semIntertravamento(projetos.reversao);
const vSemTrava = P.validar(semTrava);
assert.ok(vSemTrava.erros.some((e) => e.codigo === 'falta_intertravamento'), ok('detecta falta de intertravamento: ' + vSemTrava.erros.map((e) => e.codigo).join(',')));
const rTrava = P.corrigir(semTrava);
assert.ok(rTrava.ok, 'correção do intertravamento deveria fechar: ' + rTrava.validacao.erros.map((e) => e.codigo).join(','));
assert.ok(rTrava.correcoes.some((t) => /NF/.test(t)), ok('correção registra o NF incluído'));

// 14 — sem botoeira de emergência
const semEmergencia = JSON.parse(JSON.stringify(projetos.direta));
const emergenciaOriginal = semEmergencia.componentes.find((c) => c.papel === 'emergencia');
const alimentacaoComando = emergenciaOriginal.pinos['1'];
semEmergencia.componentes = semEmergencia.componentes.filter((c) => c.papel !== 'emergencia');
semEmergencia.componentes.find((c) => c.id === 'S2').pinos['1'] = alimentacaoComando;
const vSemEmergencia = P.validar(semEmergencia);
assert.ok(vSemEmergencia.erros.some((e) => e.codigo === 'falta_emergencia'), ok('detecta ausência de emergência'));
const rEmergencia = P.corrigir(semEmergencia);
assert.ok(rEmergencia.ok, 'correção da emergência deveria fechar: ' + rEmergencia.validacao.erros.map((e) => e.codigo).join(','));
assert.ok(rEmergencia.projeto.componentes.some((c) => c.papel === 'emergencia'), ok('emergência reinserida'));

// 15 — motor sem proteção
const semProtecao = JSON.parse(JSON.stringify(projetos.direta));
semProtecao.componentes = semProtecao.componentes.filter((c) => c.tipo !== 'releTermico');
const motor = semProtecao.componentes.find((c) => c.tipo === 'motor3');
motor.pinos = { U: 'S1', V: 'S2', W: 'S3', PE: 'PE' };
const vSemProtecao = P.validar(semProtecao);
assert.ok(vSemProtecao.erros.some((e) => e.codigo === 'falta_protecao'), ok('detecta motor sem proteção'));
const rProtecao = P.corrigir(semProtecao);
assert.ok(rProtecao.ok, 'correção da proteção deveria fechar: ' + rProtecao.validacao.erros.map((e) => e.codigo + ' ' + e.mensagem).join(' | '));
assert.ok(rProtecao.projeto.componentes.some((c) => c.tipo === 'releTermico'), ok('térmico reinserido'));

// 16 — bobina com tensão errada
const tensaoErrada = JSON.parse(JSON.stringify(projetos.reversao));
tensaoErrada.componentes.find((c) => c.id === 'K1').tensao = 110;
assert.ok(P.validar(tensaoErrada).erros.some((e) => e.codigo === 'tensao_bobina'), ok('detecta tensão de bobina incompatível'));
const rTensao = P.corrigir(tensaoErrada);
assert.ok(rTensao.ok, ok('correção ajusta a tensão da bobina'));

// 17 — endereço de CLP duplicado
const clpRuim = JSON.parse(JSON.stringify(projetos.clp));
clpRuim.componentes.find((c) => c.tipo === 'clp').enderecos.I2 = '%I0.0';
assert.ok(P.validar(clpRuim).erros.some((e) => e.codigo === 'clp_endereco_duplicado'), ok('detecta endereço duplicado'));

// 18 — curto entre dois terminais do mesmo componente
const curto = JSON.parse(JSON.stringify(projetos.direta));
curto.componentes.find((c) => c.id === 'K1').pinos['2'] = 'R1';
assert.ok(P.validar(curto).erros.some((e) => e.codigo === 'curto'), ok('detecta curto no componente'));

// 19 — terminal obrigatório solto
const solto = JSON.parse(JSON.stringify(projetos.direta));
delete solto.componentes.find((c) => c.id === 'K1').pinos['A2'];
assert.ok(P.validar(solto).erros.some((e) => e.codigo === 'terminal_solto'), ok('detecta terminal solto'));

// 20 — relatório de um projeto com erro aponta o erro e não finge aprovação
const relRuim = P.relatorio(semProtecao);
assert.ok(/ERRO \[falta_protecao\]/.test(relRuim), ok('relatório mostra o erro encontrado'));

// 21 — arquivo local: salvar, listar, ler e apagar
const memoria = {};
P.usarStore({ getItem: (k) => memoria[k] || null, setItem: (k, v) => { memoria[k] = v; return true; } });
const salvo = P.salvar('teste-reversao', projetos.reversao);
assert.ok(salvo.ok, 'salvar projeto: ' + (salvo.erro || ''));
assert.ok(P.listar().length === 1, ok('projeto aparece na lista'));
assert.ok(P.ler('teste-reversao').ok, ok('projeto salvo reabre'));
assert.ok(P.apagar('teste-reversao').ok, ok('projeto salvo apaga'));

// 22 — histórico de versões: a gravação anterior é preservada
const memoria2 = {};
P.usarStore({ getItem: (k) => memoria2[k] || null, setItem: (k, v) => { memoria2[k] = v; return true; } });
const baseHistorico = JSON.parse(JSON.stringify(projetos.direta));
const s1 = P.salvar('historico-direta', baseHistorico);
assert.ok(s1.ok && s1.substituiu === false, ok('primeira gravação não substitui'));
baseHistorico.componentes = baseHistorico.componentes.filter((c) => c.id !== 'H1');
const s2 = P.salvar('historico-direta', baseHistorico);
assert.ok(s2.ok && s2.substituiu === true, ok('segunda gravação registra substituição'));
const historico = P.versoes('historico-direta');
assert.strictEqual(historico.versoes.length, 2, 'duas versões no histórico: ' + historico.versoes.length);
assert.ok(P.lerVersao('historico-direta', 1).projeto.componentes.length > P.lerVersao('historico-direta', 0).projeto.componentes.length, ok('versão anterior guardada com mais componentes'));
const restaurado = P.restaurar('historico-direta', 1);
assert.ok(restaurado.ok && restaurado.projeto.componentes.length === projetos.direta.componentes.length, ok('restaurar devolve a versão anterior'));
assert.strictEqual(P.versoes('historico-direta').versoes.length, 3, ok('restaurar mantém a versão atual no histórico'));

// 23 — comparação aponta o que mudou
const diff = P.comparar(projetos.direta, baseHistorico);
assert.ok(diff.removidos.indexOf('H1') >= 0, ok('comparação aponta componente removido (H1)'));
assert.ok(/COMPARAÇÃO DE PROJETOS/.test(diff.resumo), ok('comparação gera resumo legível'));
assert.strictEqual(P.comparar(projetos.direta, projetos.direta).adicionados.length, 0, ok('comparação de projeto consigo mesmo não inventa diferença'));

// 24 — modificação de projeto existente
const modDir = P.projetar(pedidos.direta).projeto;
const comTimer = P.modificar(modDir, 'adicionar temporizador de 10 segundos');
assert.ok(comTimer.ok, 'modificação do temporizador: ' + comTimer.erro);
assert.strictEqual(comTimer.projeto.componentes.length, modDir.componentes.length + 2, ok('temporizador e sinaleiro adicionados'));
assert.ok(comTimer.validacao.ok, 'projeto com temporizador continua válido: ' + comTimer.validacao.erros.map((e) => e.codigo).join(','));
assert.ok(comTimer.mudancas.length >= 1 && /Temporizador/.test(comTimer.mudancas[0]), ok('modificação registrada na saída'));
assert.strictEqual(modDir.componentes.length, projetos.direta.componentes.length, ok('projeto original intacto após modificar'));
const semH1 = P.modificar(modDir, 'remover H1');
assert.ok(semH1.ok && !semH1.projeto.componentes.some((c) => c.id === 'H1'), ok('remoção de componente existente'));
assert.ok(P.modificar(modDir, 'remover ZZ9').ok === false, ok('remoção de componente inexistente é recusada'));
const comoReversao = P.modificar(modDir, 'converter para reversão');
assert.ok(comoReversao.ok && comoReversao.projeto.tipo === 'reversao', ok('conversão para reversão troca a topologia'));
assert.ok(comoReversao.validacao.ok, 'reversão resultante é válida: ' + comoReversao.validacao.erros.map((e) => e.codigo).join(','));
const em24 = P.modificar(modDir, 'comando em 24 V');
assert.ok(em24.ok && em24.projeto.spec.tensaoComando === 24, ok('troca de tensão de comando'));
assert.ok(P.modificar(modDir, 'fazer café').ok === false, ok('pedido de modificação desconhecido é recusado'));

console.log('OK: projetista elétrico — ' + checks + ' verificações (interpretação, 6 topologias, verificação, correção e arquivo)');

// Sequência de dois motores: o exemplo da missão, montado e conferido por regra independente
const pedidoSeq = 'Crie um circuito para controlar dois motores, onde o segundo só possa ligar depois que o primeiro estiver funcionando por cinco segundos.';
const iSeq = P.interpretar(pedidoSeq);
assert.ok(iSeq.ok && iSeq.spec.tipo === 'sequencia', 'tipo sequência: ' + (iSeq.spec && iSeq.spec.tipo));
assert.strictEqual(iSeq.spec.temporizador, 5, 'tempo lido da sequência');
const rSeq = P.projetar(pedidoSeq);
assert.ok(rSeq.ok, 'projetar sequência');
const vSeq = P.validar(rSeq.projeto);
assert.ok(vSeq.ok, 'sequência deveria passar: ' + vSeq.erros.map((e) => e.codigo + ' ' + e.mensagem).join(' | '));
assert.strictEqual(rSeq.projeto.componentes.filter((c) => /^motor/.test(c.tipo)).length, 2, 'dois motores');
assert.ok(rSeq.projeto.componentes.some((c) => c.tipo === 'temporizador' && Number(c.tempo) === 5), 'temporizador de 5 s');
const objSeq = P.conferirObjetivo(rSeq.projeto);
assert.ok(objSeq.ok, 'segunda análise aprova a sequência: ' + objSeq.faltas.join('; '));
checks += 3;

// Segunda análise pega a remoção do temporizador (o que validar() estrutural não veria sozinho)
const semTimer = JSON.parse(JSON.stringify(rSeq.projeto));
semTimer.componentes = semTimer.componentes.filter((c) => c.tipo !== 'temporizador');
assert.ok(!P.conferirObjetivo(semTimer).ok, 'segunda análise detecta falta do temporizador');
checks++;

// NETLIST: exporta, reimporta e preserva os pinos
const net = P.exportarNetlist(projetos.direta);
const imp = P.importarDiagramaTexto(net);
assert.ok(imp.ok, 'netlist reabre: ' + imp.erro);
assert.strictEqual(imp.projeto.componentes.length, projetos.direta.componentes.length, 'componentes da netlist');
const k1orig = projetos.direta.componentes.find((c) => c.id === 'K1');
const k1net = imp.projeto.componentes.find((c) => c.id === 'K1');
assert.deepStrictEqual(k1net.pinos, k1orig.pinos, 'pinos preservados na netlist');
assert.strictEqual(P.importarDiagramaTexto('lixo').ok, false, 'netlist inválida recusada');
checks += 3;

console.log('OK: sequência de dois motores, segunda análise e netlist — ' + checks + ' verificações no total');
