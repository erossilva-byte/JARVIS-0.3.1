#!/usr/bin/env node
/* Compatibilidade Android ↔ PC — protocolo jarvis/2, do lado do PC.
 *
 * O celular falso implementa o mesmo contrato do `pareamento_service.dart`:
 * negociação em /jarvis/info, token no pareamento, e /jarvis/comando com
 * protocolo, prazo de 60 s, id de uso único, lista fechada de ações e ritmo.
 * Nada sai de 127.0.0.1.
 */
'use strict';

const assert = require('assert');
const fs = require('fs');
const http = require('http');
const os = require('os');
const path = require('path');
const crypto = require('crypto');

const PAR = require('../platforms/desktop/pareamento.js');

const prova = (codigo, desafio) =>
  crypto.createHmac('sha256', Buffer.from(codigo, 'utf8')).update(desafio, 'utf8').digest('hex');

function celularFalso({ protocolo = 'jarvis/2', comando = true, intervaloMinimo = 0 } = {}) {
  const estado = {
    oferta: { codigo: '123456', desafio: 'desafio-de-teste' },
    registro: null,
    revogado: false,
    pedidosDeComando: 0,
    executados: [],
    ids: new Set(),
    ultimo: 0
  };
  const responder = (resposta, codigo, corpo) => {
    resposta.writeHead(codigo, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
    resposta.end(JSON.stringify(corpo));
  };
  const negociacao = () => {
    if (protocolo !== 'jarvis/2') return {};
    return { protocolo: 'jarvis/2', recursos: comando ? ['status', 'comando'] : ['status'] };
  };
  const autorizado = (pedido) => {
    const cabecalho = pedido.headers.authorization || '';
    return Boolean(estado.registro) && !estado.revogado && cabecalho === 'Bearer ' + estado.registro.token;
  };
  const servidor = http.createServer((pedido, resposta) => {
    const url = new URL(pedido.url, 'http://127.0.0.1');
    if (pedido.method === 'GET' && url.pathname === '/jarvis/info') {
      if (!estado.oferta) return responder(resposta, 409, { erro: 'sem oferta' });
      return responder(resposta, 200, Object.assign(
        { nome: 'Celular falso', versao: '1.109.0', desafio: estado.oferta.desafio },
        negociacao()
      ));
    }
    if (pedido.method === 'POST' && url.pathname === '/jarvis/parear') {
      let corpo = '';
      pedido.on('data', (parte) => { corpo += parte; });
      pedido.on('end', () => {
        const dados = JSON.parse(corpo || '{}');
        if (!estado.oferta) return responder(resposta, 409, { erro: 'sem oferta' });
        if (dados.prova !== prova(estado.oferta.codigo, estado.oferta.desafio)) {
          return responder(resposta, 403, { erro: 'código incorreto', tentativasRestantes: 4 });
        }
        estado.registro = { token: crypto.randomBytes(32).toString('hex'), dispositivo: dados.dispositivo };
        estado.oferta = null;
        return responder(resposta, 200, Object.assign(
          { token: estado.registro.token, dispositivo: dados.dispositivo, nome: 'Celular falso' },
          negociacao()
        ));
      });
      return undefined;
    }
    if (pedido.method === 'GET' && url.pathname === '/jarvis/status') {
      if (!autorizado(pedido)) return responder(resposta, 401, { erro: 'token inválido' });
      return responder(resposta, 200, { nome: 'Celular falso', status: { bateria: 77 } });
    }
    if (pedido.method === 'POST' && url.pathname === '/jarvis/comando') {
      estado.pedidosDeComando += 1;
      if (!autorizado(pedido)) return responder(resposta, 401, { ok: false, erro: 'token inválido' });
      if (!comando || protocolo !== 'jarvis/2') {
        return responder(resposta, 409, { ok: false, erro: 'canal só de leitura' });
      }
      let corpo = '';
      pedido.on('data', (parte) => { corpo += parte; });
      pedido.on('end', () => {
        const dados = JSON.parse(corpo || '{}');
        if (dados.protocolo !== 'jarvis/2') {
          return responder(resposta, 400, { ok: false, erro: 'protocolo desconhecido' });
        }
        if (!/^[0-9a-f]{32,64}$/.test(String(dados.id || ''))) {
          return responder(resposta, 400, { ok: false, erro: 'id inválido' });
        }
        const quando = Date.parse(String(dados.emitidoEm || ''));
        if (!Number.isFinite(quando) || Math.abs(Date.now() - quando) > 60000) {
          return responder(resposta, 409, { ok: false, erro: 'fora do prazo de 60 s' });
        }
        if (estado.ids.has(dados.id)) {
          return responder(resposta, 409, { ok: false, erro: 'comando já executado' });
        }
        const permitidos = PAR.ACOES_REMOTAS[String(dados.acao || '')];
        if (!permitidos) return responder(resposta, 422, { ok: false, erro: 'ação desconhecida' });
        const tela = String((dados.argumentos || {}).tela || '');
        if (!permitidos.includes(tela)) return responder(resposta, 422, { ok: false, erro: 'argumento recusado' });
        const agora = Date.now();
        if (intervaloMinimo && agora - estado.ultimo < intervaloMinimo) {
          return responder(resposta, 429, { ok: false, erro: 'comandos demais' });
        }
        estado.ultimo = agora;
        estado.ids.add(dados.id);
        estado.executados.push(dados.acao + ':' + tela);
        return responder(resposta, 200, { ok: true, id: dados.id, resultado: 'abri ' + tela + ' no celular' });
      });
      return undefined;
    }
    if (pedido.method === 'POST' && url.pathname === '/jarvis/esquecer') {
      if (!autorizado(pedido)) return responder(resposta, 401, { erro: 'token inválido' });
      estado.revogado = true;
      return responder(resposta, 200, { esquecido: true });
    }
    return responder(resposta, 404, { erro: 'rota desconhecida' });
  });
  return { servidor, estado };
}

async function subir(celular) {
  await new Promise((ok) => celular.servidor.listen(0, '127.0.0.1', ok));
  return '127.0.0.1:' + celular.servidor.address().port;
}

async function enviarCru(endereco, token, corpo) {
  const resposta = await fetch('http://' + endereco + '/jarvis/comando', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token },
    body: JSON.stringify(corpo)
  });
  return { status: resposta.status, corpo: await resposta.json() };
}

async function main() {
  // 1. A lista de ações é a mesma do celular, e o PC sabe validá-la offline.
  assert.deepStrictEqual(PAR.ACOES_REMOTAS, {
    abrir_tela: ['memoria', 'pessoas', 'visao', 'historico', 'conversa']
  });
  assert.strictEqual(PAR.PROTOCOLO, 'jarvis/2');
  assert.throws(() => PAR.conferirPedidoDeComando({ acao: 'formatar_disco' }), /Ação desconhecida/);
  assert.throws(() => PAR.conferirPedidoDeComando({ acao: 'abrir_tela', argumentos: { tela: 'config' } }), /aceita:/);

  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), 'jarvis-comando-'));
  const arquivo = path.join(pasta, 'pareamento.json');

  // 2. Celular antigo (jarvis/1) continua pareando e lendo, sem comando.
  const antigo = celularFalso({ protocolo: 'jarvis/1', comando: false });
  const enderecoAntigo = await subir(antigo);
  const pcAntigo = PAR.criarPareamento({ arquivo: path.join(pasta, 'antigo.json'), nome: 'PC antigo' });
  const pareadoAntigo = await pcAntigo.parear({ ip: enderecoAntigo, codigo: '123456' });
  assert.strictEqual(pareadoAntigo.protocolo, PAR.PROTOCOLO_LEGADO, 'celular sem negociação virou jarvis/2');
  assert.strictEqual(pareadoAntigo.podeComandar, false);
  assert.deepStrictEqual((await pcAntigo.estado()).recursos, ['status']);
  let tentouRede = 0;
  const semRede = PAR.criarPareamento({
    arquivo: path.join(pasta, 'antigo.json'),
    buscar: async () => { tentouRede += 1; throw new Error('não deveria chamar'); }
  });
  await assert.rejects(
    () => semRede.enviarComando({ acao: 'abrir_tela', argumentos: { tela: 'memoria' } }),
    (e) => e.codigo === 'sem-recurso' && /só de leitura/.test(e.message)
  );
  assert.strictEqual(tentouRede, 0, 'o PC tentou mandar comando para canal de leitura');
  antigo.servidor.close();

  // 3. Celular jarvis/2: negociação, comando, recusas e revogação.
  const celular = celularFalso();
  const endereco = await subir(celular);
  const pc = PAR.criarPareamento({ arquivo, nome: 'PC de teste' });
  const pareado = await pc.parear({ ip: endereco, codigo: '123456' });
  assert.strictEqual(pareado.protocolo, 'jarvis/2');
  assert.deepStrictEqual(pareado.recursos, ['status', 'comando']);
  assert.strictEqual(pareado.podeComandar, true);
  const gravado = JSON.parse(fs.readFileSync(arquivo, 'utf8')).registro;
  assert.strictEqual(gravado.protocolo, 'jarvis/2', 'a negociação não foi gravada');
  assert.deepStrictEqual(gravado.recursos, ['status', 'comando']);

  const feito = await pc.enviarComando({ acao: 'abrir_tela', argumentos: { tela: 'memoria' } });
  assert.strictEqual(feito.ok, true);
  assert.match(feito.resultado, /abri memoria/);
  assert.deepStrictEqual(celular.estado.executados, ['abrir_tela:memoria']);
  assert.strictEqual(feito.id.length, 32, 'o id do comando deveria ter 32 caracteres hex');

  // Repetição: o mesmo id não executa duas vezes.
  const token = celular.estado.registro.token;
  const idFixo = crypto.randomBytes(16).toString('hex');
  const base = { protocolo: 'jarvis/2', id: idFixo, emitidoEm: new Date().toISOString(), acao: 'abrir_tela', argumentos: { tela: 'pessoas' } };
  const primeira = await enviarCru(endereco, token, base);
  const segunda = await enviarCru(endereco, token, base);
  assert.strictEqual(primeira.status, 200);
  assert.strictEqual(segunda.status, 409, 'comando repetido foi aceito');
  assert.match(segunda.corpo.erro, /já executado/);
  assert.strictEqual(celular.estado.executados.length, 2);

  // Prazo: comando com hora velha não executa.
  const atrasado = await enviarCru(endereco, token, Object.assign({}, base, {
    id: crypto.randomBytes(16).toString('hex'),
    emitidoEm: new Date(Date.now() - 5 * 60000).toISOString()
  }));
  assert.strictEqual(atrasado.status, 409);
  assert.match(atrasado.corpo.erro, /60 s/);

  // Protocolo errado e ação desconhecida são recusados no celular.
  assert.strictEqual((await enviarCru(endereco, token, Object.assign({}, base, {
    id: crypto.randomBytes(16).toString('hex'), protocolo: 'jarvis/1'
  }))).status, 400);
  assert.strictEqual((await enviarCru(endereco, token, Object.assign({}, base, {
    id: crypto.randomBytes(16).toString('hex'), acao: 'apagar_tudo'
  }))).status, 422);
  // Sem token, nada acontece.
  assert.strictEqual((await enviarCru(endereco, 'token-errado', Object.assign({}, base, {
    id: crypto.randomBytes(16).toString('hex')
  }))).status, 401);

  // 4. Revogar no celular vira erro explicado no PC.
  celular.estado.revogado = true;
  await assert.rejects(
    () => pc.enviarComando({ acao: 'abrir_tela', argumentos: { tela: 'visao' } }),
    (e) => e.codigo === 'revogado'
  );
  celular.estado.revogado = false;

  // 5. Ritmo: dois comandos em sequência sem espera recebem 429 explicado.
  celular.servidor.close();
  const apressado = celularFalso({ intervaloMinimo: 1000 });
  const enderecoApressado = await subir(apressado);
  const pcApressado = PAR.criarPareamento({ arquivo: path.join(pasta, 'apressado.json'), nome: 'PC apressado' });
  await pcApressado.parear({ ip: enderecoApressado, codigo: '123456' });
  await pcApressado.enviarComando({ acao: 'abrir_tela', argumentos: { tela: 'conversa' } });
  await assert.rejects(
    () => pcApressado.enviarComando({ acao: 'abrir_tela', argumentos: { tela: 'conversa' } }),
    (e) => e.codigo === 'ritmo' && /demais/.test(e.message)
  );
  apressado.servidor.close();

  fs.rmSync(pasta, { recursive: true, force: true });
  console.log('OK: protocolo jarvis/2 — negociação, comando, repetição, prazo, ritmo, revogação e recusa fora da LAN.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
