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

// 7. Delegação entre agentes (Fase 3): quem delegou, para quem, e validação da cadeia.
const A2 = B;   // mesmo módulo recarregado (a loja foi zerada por limpar() acima)
const fs = require('node:fs');
const caminho = require('node:path').join(__dirname, '..', 'agentes.js');
assert.equal(A2.agenteDe('sandbox_js').id, 'programacao');
assert.equal(A2.agenteDe('patch_aplicar').id, 'programacao');
assert.equal(A2.agenteDe('projetista_ladder').id, 'engenharia');
assert.equal(A2.agenteDe('eletrica_dimensionar').id, 'engenharia');
assert.equal(A2.agenteDe('cadesimu_importar').id, 'eletronica');
assert.equal(A2.agenteDe('netlist_gerar').id, 'eletronica');
assert.equal(A2.agenteDe('status_dispositivo').id, 'dispositivo');
assert.equal(A2.agenteDe('acessibilidade_clicar').id, 'dispositivo');
assert.equal(A2.agenteDe('arquivo_editar').id, 'arquivos', 'arquivo não pode virar programação');
assert.equal(A2.agenteDe('projetista_potencia').id, 'engenharia');

const t = A2.abrirTarefa('organizar a tarde', 'plano');
assert.match(t.id, /^tr-/);
const p1 = A2.abrir('pesquisar', {}, { de: 'plano', tarefa: t.id });
assert.equal(p1.de, 'plano');
assert.equal(p1.para, 'pesquisa');
assert.equal(p1.tarefa, t.id);
const c1 = A2.fechar(p1.id, { verificado: true, info: '2 fontes' });
assert.equal(c1.tarefa, t.id, 'o recibo precisa guardar a tarefa delegada');

// Recibo ainda aberto já conta como pendência.
const p2 = A2.abrir('arquivo_criar', {}, { de: 'plano', tarefa: t.id });
let v = A2.verificarTarefa(t.id);
assert.equal(v.ok, false);
assert.equal(v.total, 2);
assert.equal(v.confirmados, 1);
assert.equal(v.pendencias[0].estado, 'aberto');
assert.deepEqual(v.agentes.slice().sort(), ['arquivos', 'pesquisa']);

// Fechado como incerto: continua não concluída, com o motivo.
A2.fechar(p2.id, { info: 'arquivo criado' });
v = A2.verificarTarefa(t.id);
assert.equal(v.ok, false);
assert.equal(v.pendencias[0].estado, 'incerto');
assert.ok(v.pendencias[0].motivo.length > 0);
assert.equal(A2.verificarTarefa('tr-inexistente').ok, false);
assert.equal(A2.verificarTarefa('tr-inexistente').total, 0);

// Só com todos os elos confirmados a tarefa passa.
const t2 = A2.abrirTarefa('duas etapas', 'plano');
A2.fechar(A2.abrir('pesquisar', {}, { de: 'plano', tarefa: t2.id }).id, { verificado: true, info: 'ok' });
A2.fechar(A2.abrir('arquivo_criar', {}, { de: 'plano', tarefa: t2.id }).id, { ok: true, info: 'arquivo criado e conferido' });
const v2 = A2.verificarTarefa(t2.id);
assert.equal(v2.ok, true);
assert.equal(v2.pendencias.length, 0);
assert.equal(v2.confirmados, 2);

// Cancelado pelo usuário não é conclusão.
const t3 = A2.abrirTarefa('cancelada', 'plano');
A2.cancelar(A2.abrir('abrir_app', {}, { de: 'plano', tarefa: t3.id }).id, 'desisti');
assert.equal(A2.verificarTarefa(t3.id).ok, false);
assert.equal(A2.verificarTarefa(t3.id).pendencias[0].estado, 'cancelado');

// Colaboração visível: desempenho por agente.
const pa = A2.porAgente();
assert.ok(pa.pesquisa && pa.pesquisa.total >= 2);
assert.ok(pa.arquivos && pa.arquivos.total >= 2);
assert.equal(pa.pesquisa.ok, pa.pesquisa.total);

// O app liga a delegação de verdade: abre a tarefa no plano, passa o contexto às etapas
// e valida a cadeia antes de dizer "concluído".
const appSrc = fs.readFileSync(require('node:path').join(__dirname, '..', 'app.js'), 'utf8');
assert.match(appSrc, /AGENTES\.abrirTarefa\(alvo, 'plano'\)/);
assert.match(appSrc, /AGENTES\.abrir\(nome, acao\.args, delegacao\)/);
assert.match(appSrc, /AGENTES\.verificarTarefa\(tarefaAgentes\.id\)/);
assert.match(appSrc, /Não considero a tarefa concluída/);
assert.match(appSrc, /'Agentes especializados'/);

const totalVerificacoes = (fs.readFileSync(__filename, 'utf8').match(/^assert\./gm) || []).length;
console.log('test_agentes: ' + totalVerificacoes + ' verificações aprovadas');
