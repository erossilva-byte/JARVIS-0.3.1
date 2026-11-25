// Política do PIN, derivação e espera progressiva no PC (1.106.0).
//
// Portado de `flutter_app/tool/seguranca_test.dart`: as mesmas regras do
// celular, verificadas no módulo que o aplicativo do PC usa. O vetor fixo de
// PBKDF2 foi calculado fora do Node (hashlib do Python), para o teste não
// apenas repetir a própria implementação.
'use strict';
const assert = require('node:assert/strict');
const path = require('node:path');
const B = require(path.join(__dirname, '..', 'bloqueio.js'));

/* ---------- 1. Política do PIN recusa o que é adivinhado em segundos ---------- */
{
  const casos = [
    ['2583', 'ok'],
    ['123', 'curto'],
    ['123456789', 'longo'],
    ['12a4', 'naoNumerico'],
    ['', 'curto'],
    ['   ', 'curto'],
    ['0000', 'repetido'],
    ['777777', 'repetido'],
    ['1234', 'sequencia'],
    ['9876', 'sequencia'],
    ['2580', 'comum'],
    ['1122', 'comum']
  ];
  casos.forEach(([pin, esperado]) => {
    const r = B.avaliarPin(pin);
    assert.equal(r.codigo, esperado, `PIN ${JSON.stringify(pin)} deveria ser ${esperado}, veio ${r.codigo}`);
    assert.equal(r.ok, esperado === 'ok', `ok inconsistente para ${JSON.stringify(pin)}`);
    assert.ok(r.mensagem && r.mensagem.length > 10, 'mensagem vazia para ' + esperado);
  });
  Object.keys(B.MENSAGENS).forEach((codigo) => {
    assert.ok(B.mensagemPolitica(codigo), 'código sem mensagem: ' + codigo);
  });
  // Sem mensagem inventada para código desconhecido.
  assert.equal(B.mensagemPolitica('codigo-que-nao-existe'), B.MENSAGENS.curto);
}

/* ---------- 2. Derivação PBKDF2-HMAC-SHA256 com vetor fixo ---------- */
{
  const sal = Uint8Array.from([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]);
  // Vetor calculado com hashlib.pbkdf2_hmac('sha256', b'pin|2583', bytes(range(16)), 1000, 32).
  const esperado = '221b87bf269d950a4c012ac4d86c9bf8f6e759455f11e19d7c21fced23e8525d';
  assert.equal(B.hexDe(B.derivarPin('pin|2583', sal, { iteracoes: 1000 })), esperado,
    'derivação não bate com o vetor independente');
  assert.equal(B.hexDe(B.derivarPin('pin|2584', sal, { iteracoes: 1000 })),
    '53c30da8d682de07af674ba1377d7d9bdabaec4d1e03476fb1f7a27d8fcbf321',
    'PIN diferente deveria gerar digest diferente');

  const digest = B.derivarPin('pin|2583', sal);
  assert.equal(digest.length, B.BYTES_HASH, 'digest com tamanho errado');
  assert.equal(B.ITERACOES, 120000, 'iterações do app mudaram');
  assert.equal(B.hexDe(digest), '128a7fc62ab70c0dc9e593b98419c36e70e80941b5cf7c4554fc374e60294b2e',
    'derivação padrão não bate com o vetor independente');
  assert.ok(B.compararDigest(digest, B.derivarPin('pin|2583', sal)), 'mesma entrada gerou digest diferente');
  assert.ok(!B.compararDigest(digest, B.derivarPin('pin|2583', sal, { iteracoes: 119000 })), 'iterações não mudam o digest');
  assert.ok(!B.compararDigest(digest, digest.slice(0, 8)), 'tamanhos diferentes aceitos');
  assert.ok(!B.compararDigest(new Uint8Array(0), new Uint8Array(0)), 'digests vazios aceitos');
  assert.throws(() => B.derivarPin('2583', sal, { iteracoes: 0 }), /iterações/);
}

/* ---------- 3. Sal e digest sobrevivem ao formato salvo `pbkdf2$sal$hash` ---------- */
{
  const sal = B.novoSal();
  assert.equal(sal.length, B.BYTES_SAL, 'sal com tamanho errado');
  assert.ok(new Set(Array.from(sal)).size > 1, 'sal constante não é aleatório');
  const digest = B.derivarPin('pin|2583', sal, { iteracoes: 500 });
  const texto = B.empacotarDigest(B.hexDe(sal), B.hexDe(digest));
  assert.ok(texto.startsWith('pbkdf2$'), 'formato do app mudou');
  const partes = B.separarDigest(texto);
  assert.ok(partes, 'formato salvo não foi lido de volta');
  assert.equal(B.hexDe(partes.sal), B.hexDe(sal));
  assert.ok(B.compararDigest(partes.digest, digest), 'digest não voltou igual');
  assert.equal(B.separarDigest('pbkdf2$xyz$abc'), null, 'hex inválido foi aceito');
  assert.equal(B.separarDigest('pbkdf2$0011$22'), null, 'tamanho errado foi aceito');
  assert.equal(B.separarDigest('outra-coisa'), null, 'formato desconhecido foi aceito');
  assert.equal(B.bytesDeHex('abc'), null, 'hex ímpar foi aceito');
}

/* ---------- 4. Tentativas: cinco erros, espera que cresce, acerto zera ---------- */
{
  const agora = Date.UTC(2026, 10, 19, 12, 0, 0);
  let config = Object.assign(B.configPadrao(), { ativo: true });

  const erro1 = B.avaliarTentativa({ config: config, pinCorreto: false, agora: agora });
  assert.equal(erro1.config.tentativas, 1, 'primeira falha não contou');
  assert.equal(erro1.esperaSeg, 0, 'primeira falha não deveria ter espera');
  assert.ok(/Restam 4 tentativas/.test(erro1.mensagem), erro1.mensagem);
  config = erro1.config;
  for (let i = 2; i < B.TENTATIVAS_ANTES_DE_ESPERA; i++) {
    config = B.avaliarTentativa({ config: config, pinCorreto: false, agora: agora }).config;
  }
  const limite = B.avaliarTentativa({ config: config, pinCorreto: false, agora: agora });
  assert.equal(limite.ok, false, 'limite de tentativas desbloqueou');
  assert.equal(limite.esperaSeg, 30, 'primeira espera deveria ser 30 s');
  assert.ok(B.bloqueadoEm(limite.config, agora), 'espera não foi aplicada');
  assert.ok(/Aguarde 30 s/.test(limite.mensagem), limite.mensagem);

  // Durante a espera, PIN certo não passa.
  const durante = B.avaliarTentativa({ config: limite.config, pinCorreto: true, agora: agora + 1000 });
  assert.equal(durante.ok, false, 'PIN certo passou durante a espera');
  assert.ok(durante.esperaSeg >= 28 && durante.esperaSeg <= 30, 'restante errado: ' + durante.esperaSeg);

  // Depois da espera, o segundo bloco de falhas espera o dobro.
  const depois = agora + 31000;
  let segundo = limite.config;
  for (let i = 0; i < B.TENTATIVAS_ANTES_DE_ESPERA - 1; i++) {
    segundo = B.avaliarTentativa({ config: segundo, pinCorreto: false, agora: depois }).config;
  }
  const segundoLimite = B.avaliarTentativa({ config: segundo, pinCorreto: false, agora: depois });
  assert.equal(segundoLimite.esperaSeg, 60, 'segunda espera deveria ser 60 s (progressiva)');

  // Acerto depois da espera zera falhas e a escala.
  const correto = B.avaliarTentativa({ config: segundoLimite.config, pinCorreto: true, agora: depois + 61000 });
  assert.equal(correto.ok, true, 'PIN certo não desbloqueou depois da espera');
  assert.equal(correto.config.tentativas, 0, 'acerto não zerou as falhas');
  assert.equal(correto.config.bloqueios, 0, 'acerto não zerou a escala de espera');
  assert.equal(B.bloqueadoEm(correto.config, depois + 61000), false, 'espera continuou depois do acerto');

  // O teto é 15 minutos.
  assert.equal(B.esperaDeBloqueios(0), 30);
  assert.equal(B.esperaDeBloqueios(1), 60);
  assert.equal(B.esperaDeBloqueios(2), 120);
  assert.equal(B.esperaDeBloqueios(20), B.ESPERA_MAX_SEG, 'espera passou do teto');
  assert.equal(B.formatarEspera(0), 'imediatamente');
  assert.equal(B.formatarEspera(30), '30 s');
  assert.equal(B.formatarEspera(60), '1 minuto');
  assert.equal(B.formatarEspera(120), '2 minutos');
}

/* ---------- 5. Configuração salva não inventa estado ---------- */
{
  const lida = B.normalizarConfig({ ativo: true, tentativas: 3, bloqueios: 2, bloqueadoAte: Date.now() + 5000 });
  assert.equal(lida.ativo, true);
  assert.equal(lida.tentativas, 3);
  assert.equal(lida.bloqueios, 2);
  assert.ok(B.bloqueadoEm(lida, Date.now()), 'espera futura ignorada');
  const vazia = B.normalizarConfig({});
  assert.equal(vazia.ativo, false, 'mapa vazio ligou o bloqueio');
  assert.equal(vazia.tentativas, 0);
  const expirada = B.normalizarConfig({ bloqueadoAte: Date.now() - 1000 });
  assert.equal(B.bloqueadoEm(expirada, Date.now()), false, 'espera no passado continuou valendo');
  assert.equal(B.restanteDeEspera(expirada, Date.now()), 0);
  assert.equal(B.normalizarConfig({ tentativas: 99 }).tentativas, B.TENTATIVAS_ANTES_DE_ESPERA,
    'tentativas fora da faixa não foram limitadas');
  assert.equal(B.normalizarConfig('lixo').ativo, false, 'entrada inválida virou configuração');
}

console.log('bloqueio: política do PIN, derivação com vetor fixo e espera progressiva — OK');
