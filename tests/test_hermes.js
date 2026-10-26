// Comportamento do núcleo Hermes (1.12.0) — o motor de linguagem e decisão do assistente.
// O hermes.js roda sem DOM: aqui ele é carregado direto e alimentado com capacidades
// simuladas, que é exatamente o que app.js injeta em Hermes.instalar().
'use strict';
const assert = require('node:assert/strict');
const caminho = require('node:path').join(__dirname, '..', 'hermes.js');
delete require.cache[require.resolve(caminho)];
const Hermes = require(caminho);

let falhas = 0;
function ok(nome, fn) {
  try { fn(); console.log('OK: ' + nome); }
  catch (e) { falhas++; console.log('FALHA: ' + nome + ' — ' + (e && e.message ? e.message : e)); }
}
async function okAsync(nome, fn) {
  try { await fn(); console.log('OK: ' + nome); }
  catch (e) { falhas++; console.log('FALHA: ' + nome + ' — ' + (e && e.message ? e.message : e)); }
}

// --- Capacidades simuladas: tudo o que o núcleo pede ao aplicativo -------------
function montar(preferencias) {
  const gravado = Object.assign({}, preferencias || {});
  const falas = [];
  const registros = [];
  return {
    gravado, falas, registros,
    cap: {
      registrar: (t, d) => registros.push(t + ': ' + d),
      falar: async (texto, semMsg, opcoes, links) => { falas.push({ texto: String(texto), links: links || [] }); },
      trat: () => 'senhor',
      nomeUsuario: () => 'Eros',
      ler: (chave, padrao) => (chave in gravado ? gravado[chave] : padrao),
      gravar: (chave, valor) => { gravado[chave] = String(valor); },
      agora: () => new Date(2026, 9, 26, 8, 30),
      offline: () => gravado.offline === '1',
      comandoLocal: async () => false,
      clima: async () => ({ cidade: 'São Paulo', temp: 22, tempMin: 19, min: 19, max: 30, chuvaProx: 10, ceu: 'céu limpo' }),
      noticias: async () => ({ fala: 'O congresso votou o orçamento. O time venceu ontem. Terceira notícia qualquer.', links: [{ titulo: 'x', url: 'https://exemplo.com' }] }),
      frase: (chave) => (chave === 'briefingFecho' ? 'O resto do dia é com você.' : (chave === 'saudacaoCurta' ? 'Em que posso ajudar?' : '')),
      diagnosticoSistema: async () => ({
        itens: [
          { nome: 'Reconhecimento de voz', estado: 'ok', detalhe: 'ok' },
          { nome: 'Síntese de voz', estado: 'ok', detalhe: 'ok' },
          { nome: 'Rede', estado: 'fail', detalhe: 'Sem conexão com a internet.' }
        ]
      })
    }
  };
}
function novo(preferencias) {
  const m = montar(preferencias);
  Hermes.instalar(m.cap);
  Hermes.zerarMetricas();
  return m;
}

// --- 1. Tom do turno ----------------------------------------------------------
ok('tom detecta pressa', () => {
  const t = Hermes.tom('me diga rápido, estou com pressa');
  assert.equal(t.pressa, true);
  assert.equal(t.serio, false);
});
ok('tom detecta assunto sensível e zera o clima', () => {
  const t = Hermes.tom('meu pai foi para o hospital com febre alta');
  assert.equal(t.serio, true);
});
ok('tom de pergunta comum é neutro', () => {
  const t = Hermes.tom('qual é a capital da Austrália?');
  assert.deepEqual(t, { serio: false, pressa: false });
});

// --- 2. Roteamento -----------------------------------------------------------
ok('saudação é tratada por habilidade própria', () => {
  const p = Hermes.planejar('Bom dia, Jarvis!');
  assert.ok(p, 'a saudação precisa casar com uma habilidade');
  assert.equal(p.rota, 'hermes:saudacao');
});
ok('autodiagnóstico tem habilidade própria', () => {
  assert.equal(Hermes.planejar('verifique o sistema').rota, 'hermes:diagnostico');
  assert.equal(Hermes.planejar('faz um diagnóstico completo').rota, 'hermes:diagnostico');
});
ok('diagnóstico da escuta continua sendo comando nativo, não habilidade', () => {
  assert.equal(Hermes.planejar('diagnóstico do segundo plano'), null);
  assert.equal(Hermes.planejar('verificar a escuta'), null);
});
ok('status do núcleo tem habilidade própria', () => {
  assert.equal(Hermes.planejar('status do núcleo').rota, 'hermes:nucleo');
});
ok('pergunta comum não é capturada por nenhuma habilidade', () => {
  assert.equal(Hermes.planejar('explique a teoria da relatividade'), null);
});

// --- 3. Despacho e telemetria -----------------------------------------------
okAsync('despacho marca a rota da habilidade própria', async () => {
  const m = novo({ briefing_auto: '0' });
  const r = await Hermes.despachar('boa tarde');
  assert.equal(r.tratado, true);
  assert.equal(r.rota, 'hermes:saudacao');
  assert.equal(m.falas.length, 1);
  assert.equal(Hermes.metricas().rotas['hermes:saudacao'], 1);
});
okAsync('despacho marca a rota local quando o aparelho resolve', async () => {
  const m = novo();
  Hermes.cap.comandoLocal = async (t) => /abrir (o )?spotify/.test(Hermes.norm(t));
  const r = await Hermes.despachar('abrir o spotify');
  assert.equal(r.rota, 'local');
  assert.equal(r.tratado, true);
  assert.equal(m.falas.length, 0);
});
okAsync('despacho devolve rota "ia" quando ninguém resolve', async () => {
  const m = novo();
  const r = await Hermes.despachar('quem inventou o violão de sete cordas?');
  assert.equal(r.tratado, false);
  assert.equal(r.rota, 'ia');
  assert.equal(Hermes.metricas().ia, 1);
});
okAsync('habilidade que falha cai para o próximo degrau sem derrubar o turno', async () => {
  const m = novo();
  let localChamado = false;
  Hermes.cap.diagnosticoSistema = async () => { throw new Error('sem microfone'); };
  Hermes.cap.comandoLocal = async () => { localChamado = true; return false; };
  const r = await Hermes.despachar('verifique o sistema');
  assert.equal(localChamado, true);
  assert.equal(r.tratado, false);
  assert.ok(m.registros.some((x) => /habilidade diagnostico/.test(x)), 'a falha precisa ficar registrada');
});

// --- 4. Briefing diário ------------------------------------------------------
okAsync('primeiro "bom dia" do dia fala temperatura e manchetes', async () => {
  const m = novo({ briefing_auto: '1' });
  const r = await Hermes.despachar('bom dia');
  assert.equal(r.resultado.briefing, true);
  const fala = m.falas[m.falas.length - 1];
  assert.match(fala.texto, /Bom dia, senhor\./);
  assert.match(fala.texto, /22 graus em São Paulo/);
  assert.match(fala.texto, /Nas notícias de agora:/);
  assert.match(fala.texto, /congresso votou o orçamento/);
  assert.ok(fala.links.length === 1, 'os links das notícias vão junto da fala');
  assert.equal(m.gravado.briefing_dia, '2026-10-26');
});
okAsync('o briefing não se repete no mesmo dia', async () => {
  const m = novo({ briefing_auto: '1', briefing_dia: '2026-10-26' });
  const r = await Hermes.despachar('bom dia');
  assert.equal(r.resultado.briefing, false);
  assert.equal(m.falas.length, 1);
  assert.match(m.falas[0].texto, /Bom dia, senhor\./);
  assert.doesNotMatch(m.falas[0].texto, /notícias/i);
});
okAsync('no modo offline o briefing avisa e não consulta nada', async () => {
  const m = novo({ briefing_auto: '1', offline: '1' });
  let consultou = false;
  Hermes.cap.clima = async () => { consultou = true; return null; };
  Hermes.cap.noticias = async () => { consultou = true; return null; };
  const r = await Hermes.despachar('bom dia');
  assert.equal(r.resultado.offline, true);
  assert.equal(consultou, false);
  assert.match(m.falas[0].texto, /modo offline/i);
});
okAsync('clima fora do ar não impede o briefing de sair', async () => {
  const m = novo({ briefing_auto: '1' });
  Hermes.cap.clima = async () => { throw new Error('sem rede'); };
  const r = await Hermes.despachar('bom dia');
  assert.equal(r.resultado.briefing, true);
  assert.match(m.falas[m.falas.length - 1].texto, /Não consegui consultar a temperatura/);
  assert.ok(m.registros.some((x) => /briefing: clima indisponível/.test(x)));
});

// --- 5. Autodiagnóstico ------------------------------------------------------
okAsync('diagnóstico fala o resumo com as pendências', async () => {
  const m = novo();
  await Hermes.despachar('verificar o sistema');
  const fala = m.falas[m.falas.length - 1].texto;
  assert.match(fala, /uma com falha: Rede/);
  assert.match(fala, /Sem conexão com a internet/);
});
ok('resumo de tudo certo usa linguagem falada', () => {
  const r = Hermes.resumoDiagnostico([
    { nome: 'Reconhecimento de voz', estado: 'ok' }, { nome: 'Síntese de voz', estado: 'ok' }
  ], { tratamento: 'senhor' });
  assert.match(r, /Verificação concluída, senhor/);
  assert.match(r, /duas checagens e todas passaram/);
});
ok('resumo sem itens pede para tentar de novo', () => {
  assert.match(Hermes.resumoDiagnostico([], { tratamento: 'senhor' }), /Não recebi os resultados/);
});

// --- 6. Validação da decisão vinda da IA ------------------------------------
ok('ação inventada pela IA é descartada com aviso', () => {
  const d = Hermes.validarDecisao({ fala: '', acao: { nome: 'desligar_celular', args: {} } }, {
    acoes: { lanterna: {} }, disponiveis: ['lanterna'], frase: () => 'Essa ação não está disponível.'
  });
  assert.equal(d.acao, null);
  assert.equal(d.aviso, 'acao-invalida: desligar_celular');
  assert.equal(d.fala, 'Essa ação não está disponível.');
});
ok('ação real e disponível passa com os argumentos saneados', () => {
  const d = Hermes.validarDecisao({ fala: 'Acendendo a lanterna, senhor.', acao: { nome: 'lanterna', args: 'ligar' } }, {
    acoes: { lanterna: {} }, disponiveis: ['lanterna']
  });
  assert.deepEqual(d.acao, { nome: 'lanterna', args: {} });
  assert.equal(d.aviso, '');
});
ok('ação existente mas indisponível na plataforma não é executada', () => {
  const d = Hermes.validarDecisao({ fala: 'Ligando, senhor.', acao: { nome: 'ligar', args: { contato: 'X' } } }, {
    acoes: { ligar: {} }, disponiveis: ['lanterna'], frase: () => 'indisponível'
  });
  assert.equal(d.acao, null);
  assert.match(d.aviso, /acao-invalida: ligar/);
});
ok('resposta sem JSON vira texto falado, nunca vazio', () => {
  const d = Hermes.validarDecisao(null, { textoBruto: 'Bom dia! Tudo certo por aqui.', frase: () => 'vazio' });
  assert.equal(d.acao, null);
  assert.match(d.fala, /Bom dia! Tudo certo/);
});
ok('fala vazia recebe uma frase do aplicativo', () => {
  const d = Hermes.validarDecisao({ fala: '   ', acao: null }, { frase: () => 'Não consegui formular uma resposta agora.' });
  assert.equal(d.fala, 'Não consegui formular uma resposta agora.');
  assert.equal(d.aviso, 'fala-vazia');
});

// --- 7. Telemetria e relatório ----------------------------------------------
okAsync('relatório mostra a proporção resolvida no aparelho', async () => {
  const m = novo({ briefing_auto: '0' });
  Hermes.cap.comandoLocal = async (t) => /hora/.test(Hermes.norm(t));
  await Hermes.despachar('bom dia');
  await Hermes.despachar('que horas são');
  await Hermes.despachar('conte uma história longa sobre mapas antigos');
  const m2 = Hermes.metricas();
  assert.equal(m2.turnos, 3);
  assert.equal(m2.noAparelho, 2);
  assert.match(Hermes.relatorio(), /2 de 3|66%/);
  assert.equal(m.falas.length, 1);
});

// --- 8. Auxiliares ----------------------------------------------------------
ok('tempoFalado descreve o clima sem invenção', () => {
  assert.match(Hermes.tempoFalado({ cidade: 'Recife', temp: 31, ceu: 'nublado', chuvaProx: 70, max: 33, min: 25 }),
    /31 graus em Recife, com nublado e 70% de chance de chuva nas próximas horas\. Máxima de 33 e mínima de 25/);
});
ok('diaDeHoje usa a data local em formato de ordenação', () => {
  assert.equal(Hermes.diaDeHoje(new Date(2026, 0, 5)), '2026-01-05');
});
ok('periodo acompanha a hora do dia', () => {
  assert.equal(Hermes.periodo(new Date(2026, 0, 5, 8)), 'Bom dia');
  assert.equal(Hermes.periodo(new Date(2026, 0, 5, 20)), 'Boa noite');
});

console.log(falhas ? '\n' + falhas + ' verificação(ões) do núcleo Hermes falharam.' : '\nTodas as verificações do núcleo Hermes passaram.');
process.exit(falhas ? 1 : 0);
