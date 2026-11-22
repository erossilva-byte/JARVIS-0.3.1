'use strict';
const assert = require('assert');
const Core = require('../core.js');

(async () => {
  try {
    const mem = new Map();
    const store = { get: (k, d) => (mem.has(k) ? mem.get(k) : d), set: (k, v) => mem.set(k, v) };
    const fakeSistema = {
      listarFerramentas: () => [{ id: 'calc', nome: 'Calculadora', descricao: 'teste', nivel: 'leitura', risco: 0 }],
      executar: async (id) => ({ ok: true, info: 'resultado de ' + id })
    };
    const core = Core.criarCore({ store, sistema: fakeSistema });

    assert.strictEqual(core.listarAgentes().length, 12);
    assert.strictEqual(core.selecionar('corrija este código Python').agente.id, 'programacao');
    const agenteSandbox = core.selecionar('execute este código no sandbox');
    assert.strictEqual(agenteSandbox.agente.id, 'programacao');
    assert.ok(agenteSandbox.agente.ferramentas.includes('sandbox_js'));
    assert.strictEqual(core.selecionar('qual o clima?').agente.id, 'pesquisa');
    assert.strictEqual(core.selecionar('bom dia').agente.id, 'principal');

    const p = core.criarProjeto('Projeto Teste', 'validar');
    assert.strictEqual(p.ok, true);
    assert.strictEqual(core.listarProjetos().length, 1);
    assert.strictEqual(core.projetoAtual().nome, 'Projeto Teste');
    assert.strictEqual(core.adicionarTarefaProjeto(null, 'primeira etapa').ok, true);
    assert.strictEqual(core.projetoAtual().tarefas.length, 1);

    core.observarPedido('implementar a etapa', 'programacao');
    const ref = core.resolverReferencia('continuar de onde paramos');
    assert.strictEqual(ref.ok, true);
    assert.ok(ref.fala.includes('Projeto Teste'));

    assert.strictEqual(core.verificarResultado('x', null).status, 'falhou');
    assert.strictEqual(core.verificarResultado('x', { ok: true, recibo: { estado: 'incerto', motivo: 'sem prova' } }).status, 'incerto');
    assert.strictEqual(core.verificarResultado('x', { ok: true, info: 'feito' }).status, 'confirmado');
    // O otimismo do adaptador não pode esconder uma falha escrita na própria resposta.
    assert.strictEqual(core.verificarResultado('x', { ok: true, info: 'Não consegui abrir a porta' }).status, 'falhou');
    assert.strictEqual(core.verificarResultado('x', { ok: true, info: 'Concluído sem falhas' }).status, 'confirmado');
    assert.strictEqual(core.verificarResultado('x', { ok: true, info: 'Não consegui', recibo: { estado: 'ok', motivo: 'recibo otimista' } }).status, 'falhou');

    const semExecutor = await core.delegar('diagnostique o sistema');
    assert.strictEqual(semExecutor.status, 'nao_configurado');
    assert.strictEqual(semExecutor.ok, false);
    core.registrarExecutor('diagnostico', async () => ({ ok: true, info: 'componentes verificados' }));
    const comExecutor = await core.delegar('diagnostique o sistema');
    assert.strictEqual(comExecutor.status, 'confirmado');
    assert.strictEqual(comExecutor.agente, 'diagnostico');

    core.registrarComponente({ id: 'bom', nome: 'Bom', checar: () => true });
    core.registrarComponente({ id: 'ruim', nome: 'Ruim', checar: () => ({ ok: false, detalhe: 'falha de teste' }) });
    const d = await core.diagnosticar();
    assert.strictEqual(d.status, 'degradado');
    assert.strictEqual(d.falhas, 1);

    assert.strictEqual(core.alternarHabilidade('calc', false).ok, true);
    const bloqueada = await core.executarHabilidade('calc', {});
    assert.strictEqual(bloqueada.bloqueado, true);
    core.alternarHabilidade('calc', true);
    const liberada = await core.executarHabilidade('calc', {});
    assert.strictEqual(liberada.ok, true);

    const retrato = core.exportar();
    assert.ok(retrato.includes('Projeto Teste'));
    const outro = Core.criarCore({ store: { get: () => '', set: () => {} }, sistema: fakeSistema });
    assert.strictEqual(outro.importar(retrato).ok, true);
    assert.strictEqual(outro.listarProjetos().length, 1);

    const vigia = core.iniciarVigia(30000);
    assert.strictEqual(vigia.ativo, true);
    assert.strictEqual(core.vigiaAtivo(), true);
    assert.strictEqual(core.pararVigia(), true);
    assert.strictEqual(core.vigiaAtivo(), false);

    // Recuperação real, com rechecagem do efeito e bloqueio contra loop.
    const memRec = new Map();
    const storeRec = { get: (k, d) => (memRec.has(k) ? memRec.get(k) : d), set: (k, v) => memRec.set(k, v) };
    const recCore = Core.criarCore({ store: storeRec, sistema: fakeSistema });
    let falharRec = true, tentativasRec = 0;
    recCore.registrarComponente({ id: 'transitorio', nome: 'Transitório', recuperacaoAutomatica: true,
      checar: () => falharRec ? { ok: false, detalhe: 'sem conexão', causa: 'temporaria' } : { ok: true, detalhe: 'conexão refeita' },
      recuperar: () => { tentativasRec++; falharRec = false; return { ok: true, detalhe: 'canal reaberto' }; } });
    const diagnosticoRec = await recCore.diagnosticar();
    assert.strictEqual(diagnosticoRec.itens[0].causa, 'temporaria');
    assert.strictEqual(diagnosticoRec.itens[0].recuperavel, true);
    const recuperado = await recCore.recuperarComponente('transitorio', { diagnostico: diagnosticoRec.itens[0] });
    assert.strictEqual(recuperado.status, 'recuperado');
    assert.strictEqual(recuperado.ok, true);
    assert.strictEqual(tentativasRec, 1);
    const repetida = await recCore.recuperarComponente('transitorio');
    assert.strictEqual(repetida.status, 'aguardando');
    assert.ok(recCore.listarRecuperacoes().length === 1);

    const memAuto = new Map();
    const autoCore = Core.criarCore({ store: { get: (k, d) => (memAuto.has(k) ? memAuto.get(k) : d), set: (k, v) => memAuto.set(k, v) }, sistema: fakeSistema });
    let falharAuto = true;
    autoCore.registrarComponente({ id: 'auto', nome: 'Automático', recuperacaoAutomatica: true,
      checar: () => falharAuto ? { ok: false, detalhe: 'falha temporária' } : { ok: true },
      recuperar: () => { falharAuto = false; return { ok: true }; } });
    const autoDiag = await autoCore.diagnosticar({ recuperarAutomatico: true });
    assert.strictEqual(autoDiag.status, 'ok');
    assert.strictEqual(autoDiag.recuperacao.recuperados, 1);

    const memPre = new Map();
    const preCore = Core.criarCore({ store: { get: (k, d) => (memPre.has(k) ? memPre.get(k) : d), set: (k, v) => memPre.set(k, v) }, sistema: fakeSistema });
    preCore.registrarComponente({ id: 'sistema', nome: 'Núcleo', essencial: true, checar: () => ({ ok: false, detalhe: 'catálogo vazio' }) });
    const pre = await preCore.preflight('diagnostique o sistema');
    assert.strictEqual(pre.ok, false);
    assert.strictEqual(pre.status, 'bloqueado');
    const bloqueadaPre = await preCore.delegar('diagnostique o sistema');
    assert.strictEqual(bloqueadaPre.status, 'bloqueado');
    assert.strictEqual(bloqueadaPre.ok, false);

    assert.ok(core.status().integracoes.mcp === 'nao_implementado');
    assert.ok(!/fetch\s*\(/.test(require('fs').readFileSync(require.resolve('../core.js'), 'utf8')));
    console.log('Core: 12 agentes, contexto, projetos, verificação, saúde, habilidades, importação e watchdog OK.');
  } catch (e) {
    console.error('FALHA NO CORE:', e && e.stack ? e.stack : e);
    process.exitCode = 1;
  }
})();
