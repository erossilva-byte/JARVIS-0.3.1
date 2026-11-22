// Testes do briefing: composição honesta, resumo de sessão, diff de monitoramento e rotina de casa.
const assert = require('assert');
const B = require('../briefing.js');
let ok = 0;
function t(nome, fn) { fn(); ok++; console.log('OK: ' + nome); }

t('saudação por horário', () => {
  assert.strictEqual(B.saudacao(4), 'Boa madrugada');
  assert.strictEqual(B.saudacao(9), 'Bom dia');
  assert.strictEqual(B.saudacao(15), 'Boa tarde');
  assert.strictEqual(B.saudacao(21), 'Boa noite');
  assert.strictEqual(B.saudacao('x'), 'Olá');
});

t('briefing só usa o que existe', () => {
  const r = B.montar({ nome: 'Ana Silva', hora: 8 });
  assert.ok(r.texto.startsWith('Bom dia, Ana.'));
  assert.ok(!/Tempo/.test(r.texto), 'não inventa clima');
  assert.ok(r.faltando.length >= 2);
  const cheio = B.montar({
    nome: 'Ana', hora: 9, clima: '24 °C e claro', manchetes: ['A', 'B'],
    tarefas: ['enviar relatório'], eventos: ['dentista 10h'], lembretes: ['pagar luz'],
    memoria: ['prefere café sem açúcar'], foco: 'fechar o orçamento',
  });
  ['Foco', 'Tempo', 'Agenda', 'Tarefas', 'Lembretes', 'Manchetes', 'Da memória'].forEach((k) => assert.ok(cheio.texto.includes(k), k));
  assert.ok(cheio.secoes.includes('clima') && cheio.secoes.includes('tarefas'));
});

t('resumo de sessão', () => {
  const r = B.resumirSessao([
    { role: 'user', content: 'cadê o arquivo do projeto?' },
    { role: 'assistant', content: 'abri o arquivo' },
    { role: 'user', content: 'depois eu vejo o clima' },
  ]);
  assert.strictEqual(r.pedidos, 2);
  assert.strictEqual(r.respostas, 1);
  assert.ok(r.temas.includes('arquivo'));
  assert.ok(r.pendencias.length >= 1);
  assert.ok(/2 pedido/.test(r.texto));
  assert.strictEqual(B.resumirSessao([]).texto, 'Ainda não há pedidos nesta sessão.');
});

t('relatório diário conta por tipo', () => {
  const r = B.relatorioDia([{ tipo: 'comando' }, { tipo: 'comando' }, { tipo: 'erro' }]);
  assert.strictEqual(r.total, 3);
  assert.strictEqual(r.contagem.comando, 2);
  assert.ok(r.texto.includes('comando (2)'));
  assert.strictEqual(B.relatorioDia(null).texto, 'Nenhum evento registrado hoje.');
});

t('monitoramento detecta novidades e saídas', () => {
  const igual = B.compararMonitoramento(['A', 'B'], ['a', 'b']);
  assert.strictEqual(igual.mudou, false);
  const novo = B.compararMonitoramento(['A'], ['A', 'C']);
  assert.deepStrictEqual(novo.novos, ['C']);
  assert.ok(novo.mudou && /novidade/.test(novo.resumo));
  const saiu = B.compararMonitoramento(['A', 'B'], ['A']);
  assert.deepStrictEqual(saiu.removidos, ['b']);
  assert.strictEqual(B.compararMonitoramento([], []).mudou, false);
});

t('sugestão de casa só na rede certa e com confirmação', () => {
  assert.ok(B.sugestaoCasa('Casa', 'Casa').confirmar, 'rede igual sugere a rotina, mas pede confirmação');
  const r = B.sugestaoCasa('casa-silva', 'Casa-Silva');
  assert.ok(r.confirmar && r.rotina === 'chegada em casa');
  assert.strictEqual(B.sugestaoCasa('Casa', 'Trabalho'), null);
  assert.strictEqual(B.sugestaoCasa('', 'Casa'), null);
});

t('registro de monitoramento tem forma estável', () => {
  const m = B.monitoramento('preço X', ['R$ 10', 'R$ 11'], '2026-11-05T10:00:00Z');
  assert.strictEqual(m.nome, 'preço X');
  assert.deepStrictEqual(m.itens, ['R$ 10', 'R$ 11']);
  assert.strictEqual(m.quando, '2026-11-05T10:00:00Z');
  assert.deepStrictEqual(B.monitoramento('', null).itens, []);
});

console.log('\nBriefing: ' + ok + ' grupos de verificação aprovados.');
