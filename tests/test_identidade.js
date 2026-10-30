// Testes do núcleo de identificação (identidade.js): cadastro, foto, voz, consentimento,
// cifragem em repouso, identificação open-set, referência visual, histórico e migração.
const assert = require('assert');
const I = require('../identidade.js');
const V = require('../voz_motor.js');

function storeFalso() {
  const m = new Map();
  return {
    getItem: (k) => (m.has(k) ? m.get(k) : null),
    setItem: (k, v) => { m.set(k, String(v)); },
    removeItem: (k) => { m.delete(k); },
    _mapa: m
  };
}
const store = storeFalso();
let t = new Date('2026-10-30T12:00:00Z').getTime();
const relogio = () => (t += 1000);
I.configurar({ store, relogio, motor: V });

function vetor(seed) {
  const v = [];
  for (let i = 0; i < V.DIM; i++) v.push(+(Math.sin(seed + i * 0.7) * 0.12 + (i % 3) * 0.01).toFixed(6));
  return v;
}
function amostra(seed, extra) {
  return Object.assign({
    v: vetor(seed), dim: V.DIM, versao: V.VERSAO,
    qualidade: { ok: true, falaSeg: 2.4, snrDb: 22, clipping: 0.2, pausaRatio: 0.2, problemas: [] },
    metricas: { pitchHz: 118, pitchDesvio: 12, formantes: [520, 1400, 2500], falaSeg: 2.4 }
  }, extra || {});
}

(async () => {
  await I.iniciar();
  assert.strictEqual(I.listar().length, 0);
  assert.strictEqual(I.salvar({ nome: '  ' }).ok, false, 'nome é obrigatório');
  assert.ok(I.salvar({ nome: 'Bia', nascimento: '2010-13-40' }).ok, 'data inválida não impede o cadastro');
  assert.strictEqual(I.listar()[0].nascimento, '', 'data inválida é descartada, não inventada');
  I.limparTudo();
  console.log('OK: núcleo carrega e nome é o único campo obrigatório');

  const bia = I.salvar({
    nome: 'Beatriz Lima', apelido: 'Bia', nascimento: '1990-05-10', alturaCm: '172',
    profissao: 'arquiteta', relacao: 'irmã', telefone: '+55 11 99999-0000',
    email: 'bia@example.com', endereco: 'Rua das Flores, 10', cidade: 'São Paulo',
    descricao: 'Irmã mais velha, gosta de plantas.', preferencias: 'café sem açúcar',
    interesses: 'fotografia e corrida', observacoes: 'Aniversário em maio.',
    contexto: 'Nos falamos quase todos os dias.',
    campos: [{ rotulo: 'Time', valor: 'Corinthians' }, { rotulo: '', valor: 'ignorar' }]
  });
  assert.ok(bia.ok, bia.erro);
  assert.strictEqual(bia.perfil.campos.length, 1, 'campo sem rótulo é descartado');
  assert.strictEqual(I.idade('1990-05-10'), 36, 'idade calculada');
  assert.ok(/Beatriz Lima/.test(I.descrever(bia.perfil)));
  assert.ok(/36 anos/.test(I.descrever(bia.perfil)));
  const ctx = I.contexto();
  assert.ok(ctx.indexOf('Beatriz Lima') >= 0 && ctx.indexOf('São Paulo') >= 0);
  assert.ok(ctx.indexOf('99999') < 0 && ctx.indexOf('@example.com') < 0 && ctx.indexOf('Flores') < 0,
    'telefone, e-mail e endereço ficam fora do contexto da IA');
  console.log('OK: perfil completo, idade, campos personalizados e contexto sem contato');

  const foto = 'data:image/png;base64,' + 'A'.repeat(1200);
  assert.ok(I.definirFoto(bia.perfil.id, foto).ok);
  assert.strictEqual(I.obter(bia.perfil.id).foto.length, foto.length);
  assert.strictEqual(I.definirFoto(bia.perfil.id, 'data:image/png;base64,' + 'A'.repeat(400000)).ok, false,
    'foto acima do limite é recusada');
  assert.strictEqual(I.definirFoto(bia.perfil.id, 'javascript:alert(1)').ok, false, 'formato estranho é recusado');
  assert.ok(I.removerFoto(bia.perfil.id).ok);
  assert.strictEqual(I.obter(bia.perfil.id).foto, '');
  console.log('OK: foto aceita, limitada e removível');

  assert.strictEqual((await I.adicionarVoz(bia.perfil.id, amostra(1))).ok, false,
    'sem consentimento não há cadastro de voz');
  assert.ok(I.consentir(bia.perfil.id, 'voz', 'Autorizo a comparação da minha voz').ok);
  assert.strictEqual((await I.adicionarVoz(bia.perfil.id, amostra(1, { qualidade: { ok: false, problemas: ['ruído'], falaSeg: 0.4, snrDb: 3, clipping: 0 } }))).ok, false,
    'amostra de má qualidade é recusada');
  assert.strictEqual((await I.adicionarVoz(bia.perfil.id, { v: [1, 2, 3], qualidade: { ok: true, falaSeg: 2, snrDb: 20, clipping: 0 } })).ok, false,
    'vetor com dimensão errada é recusado');
  for (let i = 0; i < 3; i++) {
    const r = await I.adicionarVoz(bia.perfil.id, amostra(1));
    assert.ok(r.ok, r.erro);
  }
  assert.strictEqual(I.obter(bia.perfil.id).amostras, 3);
  assert.strictEqual(I.obter(bia.perfil.id).vozPronta, true);
  assert.strictEqual(I.perfisVoz().length, 1);
  console.log('OK: consentimento obrigatório, qualidade e dimensão validadas, três amostras prontas');

  const bruto = store.getItem(I.CHAVE_BIO);
  assert.ok(bruto && bruto.length > 50, 'biometria foi gravada');
  const pacote = JSON.parse(bruto);
  assert.strictEqual(pacote.cifrado, true, 'biometria cifrada');
  assert.ok(String(pacote.dados).indexOf('"v"') < 0 && String(pacote.dados).indexOf('0.0') < 0,
    'vetor não aparece em texto claro');
  I.configurar({ store, relogio, motor: V });
  assert.strictEqual(I.perfisVoz().length, 0, 'antes de iniciar, a biometria não está em memória');
  await I.iniciar();
  assert.strictEqual(I.perfisVoz().length, 1, 'biometria é decifrada após reiniciar');
  console.log('OK: biometria cifrada em repouso e recuperada após reinício');

  const igual = await I.identificar(amostra(1));
  assert.strictEqual(igual.estado, I.ESTADOS.IDENTIFICADO, JSON.stringify(igual));
  assert.strictEqual(igual.pessoa.id, bia.perfil.id);
  assert.ok(igual.confianca >= 78, 'confiança passa do limiar');
  const desconhecido = await I.identificar(amostra(9));
  assert.ok(desconhecido.estado === I.ESTADOS.NAO_IDENTIFICADO || desconhecido.estado === I.ESTADOS.INCONCLUSIVO,
    'voz diferente não é identificada como a pessoa cadastrada');
  const ruim = await I.identificar(amostra(1, { qualidade: { ok: false, problemas: ['curto'], falaSeg: 0.3, snrDb: 4, clipping: 0 } }));
  assert.strictEqual(ruim.estado, I.ESTADOS.INCONCLUSIVO, 'áudio ruim nunca vira identificação');
  assert.ok((ruim.motivos || []).length > 0);
  console.log('OK: identificação com confiança, desconhecido e áudio insuficiente');

  const carlos = I.salvar({ nome: 'Carlos', apelido: 'Cadu' });
  I.consentir(carlos.perfil.id, 'voz', 'autorizo');
  await I.adicionarVoz(carlos.perfil.id, amostra(1));
  const ambiguo = await I.identificar(amostra(1));
  assert.strictEqual(ambiguo.estado, I.ESTADOS.INCONCLUSIVO, 'dois perfis iguais resultam em inconclusivo');
  assert.ok(/próximos|adivinhar/i.test((ambiguo.motivos || []).join(' ')));
  console.log('OK: margem entre candidatos impede escolha por chute');

  assert.ok(I.consentir(bia.perfil.id, 'rosto', 'autorizo referência visual').ok);
  assert.strictEqual(I.definirRosto(bia.perfil.id, { dhash: 'zzz' }).ok, false, 'descritor inválido é recusado');
  assert.ok(I.definirRosto(bia.perfil.id, { dhash: '0123456789abcdef' }).ok);
  assert.strictEqual(I.compararRosto({ dhash: '0123456789abcdef' }).estado, I.ESTADOS.DESATIVADO,
    'referência visual desligada por padrão');
  I.salvarConfig({ rosto: true });
  const rostoOk = I.compararRosto({ dhash: '0123456789abcdef' });
  assert.strictEqual(rostoOk.estado, I.ESTADOS.IDENTIFICADO);
  assert.strictEqual(rostoOk.provaDeIdentidade, false, 'rosto nunca é prova de identidade');
  assert.ok(/não reconhecimento facial/i.test(rostoOk.aviso));
  console.log('OK: referência visual opcional, desligada por padrão e nunca prova de identidade');

  const menor = I.salvarConfig({ limiar: 0.1, margem: 9, falaMin: 99, snrMin: 0 });
  assert.strictEqual(menor.limiar, 0.68, 'limiar nunca abaixo do piso seguro');
  assert.strictEqual(menor.margem, 0.15);
  assert.strictEqual(menor.falaMin, 5);
  assert.strictEqual(menor.snrMin, 6);
  I.salvarConfig({ limiar: 0.8 });
  console.log('OK: limites de configuração são seguros e preservados');

  const texto = I.exportar({ fotos: true });
  assert.ok(texto.indexOf('jarvis-identidade-2') >= 0);
  assert.ok(texto.indexOf('vozes') < 0 && texto.indexOf('dhash') < 0, 'exportação padrão não leva biometria');
  assert.ok(texto.indexOf('Beatriz Lima') >= 0, 'dados civis são exportados');
  const hist = I.historico(bia.perfil.id);
  assert.ok(hist.length > 0 && hist.some((h) => h.campo === 'voz'), 'histórico registra alterações');
  console.log('OK: exportação sem biometria e histórico de alterações');

  const remover = await I.remover(bia.perfil.id);
  assert.ok(remover.ok);
  await I.iniciar();
  const restante = await I.identificar(amostra(1));
  assert.ok(restante.estado !== I.ESTADOS.IDENTIFICADO || restante.pessoa.nome !== 'Beatriz Lima',
    'perfil excluído não é mais identificado');
  console.log('OK: exclusão remove perfil e biometria associada');

  const store2 = storeFalso();
  I.configurar({ store: store2, relogio, motor: V });
  await I.iniciar();
  const mig = I.migrarDe([{ nome: 'Ana', apelido: 'Aninha', relacao: 'irmã', observacoes: 'legado' }]);
  assert.strictEqual(mig.migrados, 1);
  assert.strictEqual(I.listar()[0].nome, 'Ana');
  assert.strictEqual(I.migrarDe([{ nome: 'Ana', apelido: 'Aninha' }]).migrados, 0, 'migração não duplica');
  const exp = I.exportar({ fotos: false });
  const imp = I.importar(exp);
  assert.strictEqual(imp.ok, true);
  assert.strictEqual(imp.importados, 0, 'perfil já existente não é duplicado');
  assert.strictEqual(I.importar('{"perfis":[{"nome":"Novo"}]}').importados, 1);
  console.log('OK: migração do cadastro antigo e importação sem duplicar');

  console.log('\ntest_identidade: todos os grupos passaram');
})().catch((e) => { console.error('FALHA:', e && e.stack || e); process.exit(1); });
