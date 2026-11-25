#!/usr/bin/env node
/* Pareamento do PC contra um celular simulado na própria máquina.
 *
 * O celular falso implementa o mesmo protocolo do `pareamento_service.dart`:
 * desafio em /jarvis/info, prova HMAC em /jarvis/parear, token de leitura em
 * /jarvis/status e revogação em /jarvis/esquecer. Nada sai de 127.0.0.1.
 */
'use strict';

const assert = require('assert');
const fs = require('fs');
const http = require('http');
const os = require('os');
const path = require('path');
const crypto = require('crypto');

const PAR = require('../platforms/desktop/pareamento.js');

function prova(codigo, desafio) {
  return crypto.createHmac('sha256', Buffer.from(codigo, 'utf8')).update(desafio, 'utf8').digest('hex');
}

function celularFalso({ codigo = '123456', desafio = 'desafio-de-teste' } = {}) {
  const estado = {
    oferta: { codigo, desafio, tentativas: 5 },
    registro: null,
    revogado: false,
    leituras: 0,
    esquecido: false,
  };
  const servidor = http.createServer((pedido, resposta) => {
    const url = new URL(pedido.url, 'http://127.0.0.1');
    const responder = (codigoHttp, corpo) => {
      resposta.writeHead(codigoHttp, { 'Content-Type': 'application/json' });
      resposta.end(JSON.stringify(corpo));
    };
    const autorizado = () => {
      const cabecalho = pedido.headers.authorization || '';
      return Boolean(estado.registro) &&
        !estado.revogado &&
        cabecalho === 'Bearer ' + estado.registro.token;
    };
    if (pedido.method === 'GET' && url.pathname === '/jarvis/info') {
      if (!estado.oferta || estado.oferta.tentativas <= 0) {
        return responder(409, { erro: 'sem oferta', precisaOferta: true });
      }
      return responder(200, { nome: 'Celular falso', versao: '1.104.0', desafio: estado.oferta.desafio });
    }
    if (pedido.method === 'POST' && url.pathname === '/jarvis/parear') {
      let corpo = '';
      pedido.on('data', (parte) => { corpo += parte; });
      pedido.on('end', () => {
        const dados = JSON.parse(corpo || '{}');
        if (!estado.oferta) return responder(409, { erro: 'sem oferta' });
        if (dados.prova !== prova(estado.oferta.codigo, estado.oferta.desafio)) {
          estado.oferta.tentativas -= 1;
          return responder(403, { erro: 'código incorreto', tentativasRestantes: estado.oferta.tentativas });
        }
        estado.registro = { token: crypto.randomBytes(32).toString('hex'), dispositivo: dados.dispositivo };
        estado.oferta = null;
        return responder(200, { token: estado.registro.token, dispositivo: dados.dispositivo, nome: 'Celular falso' });
      });
      return undefined;
    }
    if (pedido.method === 'GET' && url.pathname === '/jarvis/status') {
      if (!autorizado()) return responder(401, { erro: 'token inválido' });
      estado.leituras += 1;
      return responder(200, { nome: 'Celular falso', status: { bateria: 81, conexao: 'Wi-Fi' } });
    }
    if (pedido.method === 'POST' && url.pathname === '/jarvis/esquecer') {
      if (!autorizado()) return responder(401, { erro: 'token inválido' });
      estado.revogado = true;
      estado.esquecido = true;
      return responder(200, { esquecido: true });
    }
    return responder(404, { erro: 'rota desconhecida' });
  });
  return { servidor, estado };
}

async function main() {
  // 1. Regras: código, prova e endereço.
  assert.strictEqual(PAR.normalizarCodigo('123 456'), '123456');
  assert.strictEqual(PAR.codigoUtilizavel('123-456'), '123456');
  assert.strictEqual(PAR.codigoUtilizavel('12345'), '');
  assert.strictEqual(PAR.codigoUtilizavel('1234567'), '');
  assert.strictEqual(
    PAR.provaDePareamento('123456', 'abc'),
    'f6ced6f4883ffc0981a6b9945819f680102b43097ad8ef7a0df9bde06fb3d2e4',
    'a prova do PC diverge do vetor do celular'
  );
  for (const bom of ['127.0.0.1', '10.1.2.3', '192.168.0.5', '172.20.1.1', '169.254.1.1', '::1', 'fd00::1']) {
    assert.ok(PAR.enderecoDaRedeLocal(bom), 'endereço local recusado: ' + bom);
  }
  for (const ruim of ['8.8.8.8', '172.32.0.1', 'exemplo.com', '']) {
    assert.ok(!PAR.enderecoDaRedeLocal(ruim), 'endereço público aceito: ' + ruim);
  }
  assert.deepStrictEqual(PAR.enderecoDoCelular('192.168.0.9'), { host: '192.168.0.9', porta: 47600 });
  assert.deepStrictEqual(PAR.enderecoDoCelular('10.0.0.2:5000'), { host: '10.0.0.2', porta: 5000 });
  assert.strictEqual(PAR.enderecoDoCelular('8.8.8.8'), null);

  // 2. Sem fetch para fora da LAN: a recusa acontece antes de qualquer rede.
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), 'jarvis-pareamento-'));
  const arquivo = path.join(pasta, 'pareamento.json');
  let tentativasDeRede = 0;
  const semRede = PAR.criarPareamento({
    arquivo: path.join(pasta, 'nunca.json'),
    buscar: async () => { tentativasDeRede += 1; throw new Error('não deveria chamar'); },
  });
  await assert.rejects(() => semRede.parear({ ip: '8.8.8.8', codigo: '123456' }), /fora da rede local/);
  await assert.rejects(() => semRede.parear({ ip: '192.168.0.5', codigo: '123' }), /6 dígitos/);
  assert.strictEqual(tentativasDeRede, 0, 'o cliente tentou falar fora da rede local');

  // 3. Registro corrompido não vira pareamento.
  fs.writeFileSync(arquivo, '{quebrado', 'utf8');
  const pc = PAR.criarPareamento({ arquivo, nome: 'PC de teste' });
  assert.deepStrictEqual(await pc.estado(), { pareado: false });

  const { servidor, estado } = celularFalso();
  await new Promise((ok) => servidor.listen(0, '127.0.0.1', ok));
  const porta = servidor.address().port;
  const endereco = '127.0.0.1:' + porta;

  try {
    // 4. Código errado é recusado e conta tentativa.
    await assert.rejects(
      () => pc.parear({ ip: endereco, codigo: '000000' }),
      (e) => /Código incorreto/.test(e.message) && e.codigo === 'codigo-errado'
    );
    assert.strictEqual(estado.oferta.tentativas, 4, 'tentativa não foi contada');
    assert.deepStrictEqual(await pc.estado(), { pareado: false });

    // 5. Código certo pareia e grava o registro no PC.
    const pareado = await pc.parear({ ip: endereco, codigo: '123 456' });
    assert.strictEqual(pareado.pareado, true);
    assert.strictEqual(pareado.ip, '127.0.0.1');
    assert.strictEqual(pareado.porta, porta);
    const gravado = JSON.parse(fs.readFileSync(arquivo, 'utf8'));
    assert.ok(gravado.registro.token && gravado.registro.token.length === 64, 'token não foi gravado');
    assert.strictEqual(gravado.registro.dispositivo, 'PC de teste');
    assert.strictEqual((await pc.estado()).pareado, true);

    // 6. Status usa o token e devolve os dados.
    const status = await pc.status();
    assert.strictEqual(status.status.bateria, 81);
    assert.strictEqual(estado.leituras, 1);

    // 7. Token revogado no celular vira erro explicado, sem apagar o registro sozinho.
    estado.revogado = true;
    await assert.rejects(() => pc.status(), /não reconhece mais este PC/);
    assert.strictEqual((await pc.estado()).pareado, true, 'o PC esqueceu sozinho');
    estado.revogado = false;

    // 8. Esquecer avisa o celular e apaga o registro local.
    await pc.esquecer();
    assert.strictEqual(estado.esquecido, true, 'o celular não foi avisado');
    assert.ok(!fs.existsSync(arquivo), 'o registro local ficou para trás');
    assert.deepStrictEqual(await pc.estado(), { pareado: false });
    await assert.rejects(() => pc.status(), /Nenhum celular pareado/);

    // 9. Celular sem oferta aberta é explicado, não vira erro genérico.
    const semOferta = PAR.criarPareamento({ arquivo, nome: 'PC de teste' });
    await assert.rejects(
      () => semOferta.parear({ ip: endereco, codigo: '123456' }),
      (e) => e.codigo === 'oferta' && /pareamento aberto/.test(e.message)
    );

    console.log('OK: pareamento do PC — regras, pareamento, status, revogação, esquecer e recusa fora da LAN.');
  } finally {
    servidor.close();
    fs.rmSync(pasta, { recursive: true, force: true });
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
