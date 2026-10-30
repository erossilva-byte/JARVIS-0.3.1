// Testes dos agentes especializados e dos recibos de execução (agentes.js).
// Sem DOM, sem rede: loja em memória e resultados sintéticos.
const assert = require('assert');
const A = require('../agentes.js');

const dados = {};
const store = {
  get: (k, d) => (Object.prototype.hasOwnProperty.call(dados, k) ? dados[k] : d),
  set: (k, v) => { dados[k] = String(v); }
};
A.configurar({ store });

// 1. Cada ferramenta cai no agente certo.
assert.equal(A.agenteDe('pesquisar_web').id, 'pesquisa');
assert.equal(A.agenteDe('abrir_arquivo').id, 'arquivos');
assert.equal(A.agenteDe('nota_memoria').id, 'memoria');
assert.equal(A.agenteDe('reconhecer_pessoa').id, 'pessoas');
assert.equal(A.agenteDe('tirar_foto').id, 'visao');
assert.equal(A.agenteDe('pc_listar').id, 'pc');
assert.equal(A.agenteDe('verificar_atualizacao').id, 'sistema');
assert.equal(A.agenteDe('abrir_app').id, 'dispositivo');
assert.equal(A.agenteDe('hora').id, 'conversa');
assert.equal(A.agenteDe('desconhecida').id, 'conversa');

// 2. O recibo guarda nomes de argumentos, nunca valores sensíveis.
const r1 = A.abrir('pesquisar_web', { consulta: 'remédio secreto', telefone: '11999998888' });
assert.deepEqual(r1.argumentos, ['consulta', 'telefone']);
assert.equal(r1.estado, 'aberto');
const f1 = A.fechar(r1, { info: 'Solicitei a pesquisa na web.' });
assert.equal(f1.estado, 'incerto');
assert.ok(f1.motivo.indexOf('não confirmado') >= 0);
assert.ok(JSON.stringify(A.historico(10)).indexOf('remédio secreto') < 0);
assert.ok(JSON.stringify(A.historico(10)).indexOf('11999998888') < 0);

// 3. Classificação explícita: verificado, falha, bloqueio e cancelamento.
assert.equal(A.fechar(A.abrir('hora', {}), { info: 'Agora são 10 horas.', verificado: true }).estado, 'ok');
assert.equal(A.fechar(A.abrir('ligar', {}), { info: 'Não foi possível completar a chamada.' }).estado, 'falhou');
assert.equal(A.fechar(A.abrir('abrir_app', {}), { info: 'Bloqueado pelo modo seguro.', bloqueado: true }).estado, 'bloqueado');
assert.equal(A.cancelar(A.abrir('desligar_pc', {}), 'usuário recusou').estado, 'cancelado');
assert.equal(A.fechar(A.abrir('enviar_sms', {}), null).estado, 'cancelado');
assert.equal(A.classificar(undefined).estado, 'incerto');

// 4. Resumo reflete o que foi executado e a taxa de verificação.
let s = A.resumo();
assert.equal(s.total, 6);
assert.equal(s.ok, 1);
assert.equal(s.incerto, 1);
assert.equal(s.falhou, 1);
assert.equal(s.bloqueado, 1);
assert.equal(s.cancelado, 2);
assert.equal(s.abertos, 0);
assert.equal(s.taxaVerificacao, 25);
assert.equal(s.ultimo.acao, 'enviar_sms');

// 5. Persistência sobrevive a uma nova carga do módulo (mesma loja).
delete require.cache[require.resolve('../agentes.js')];
const B = require('../agentes.js');
B.configurar({ store });
assert.equal(B.resumo().total, 6);
assert.equal(B.historico(2).length, 2);

// 6. Histórico limitado e limpeza.
for (let i = 0; i < 95; i++) B.fechar(B.abrir('hora', {}), { info: 'ok', verificado: true });
assert.equal(B.historico(200).length, B.LIMITE);
assert.equal(B.resumo().total, B.LIMITE);
B.limpar();
assert.equal(B.resumo().total, 0);
assert.equal(B.historico(5).length, 0);

console.log('test_agentes: 30 verificações aprovadas');
