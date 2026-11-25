/* Cliente de pareamento do PC — Node puro, sem Electron.
 *
 * Espelha `flutter_app/lib/core/pareamento.dart` e `pareamento_service.dart`:
 * o PC lê o desafio em `/jarvis/info`, prova que sabe o código de 6 dígitos com
 * HMAC-SHA256, guarda o token de leitura e usa esse token só para pedir status.
 *
 * O que este arquivo não faz: descobrir sozinho (a escolha da Etapa 3 é IP
 * manual), falar com endereço fora da rede local e enviar comando ao celular.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const PORTA_PADRAO = 47600;
const TEMPO_LIMITE_MS = 5000;

function normalizarCodigo(valor) {
  return String(valor === null || valor === undefined ? '' : valor).replace(/\D/g, '');
}

function codigoUtilizavel(valor) {
  const limpo = normalizarCodigo(valor);
  return limpo.length === 6 ? limpo : '';
}

function provaDePareamento(codigo, desafio) {
  return crypto
    .createHmac('sha256', Buffer.from(normalizarCodigo(codigo), 'utf8'))
    .update(String(desafio || ''), 'utf8')
    .digest('hex');
}

function enderecoDaRedeLocal(host) {
  const h = String(host || '').trim().toLowerCase().replace(/\[|\]/g, '');
  if (!h) return false;
  if (h === 'localhost' || h === '::1') return true;
  const ipv4 = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec(h);
  if (ipv4) {
    const p = [1, 2, 3, 4].map((i) => Number(ipv4[i]));
    if (p.some((n) => n > 255)) return false;
    if (p[0] === 127 || p[0] === 10) return true;
    if (p[0] === 192 && p[1] === 168) return true;
    if (p[0] === 172 && p[1] >= 16 && p[1] <= 31) return true;
    if (p[0] === 169 && p[1] === 254) return true;
    return false;
  }
  if (h.includes(':')) {
    return /^(fe8|fe9|fea|feb|fc|fd)/.test(h);
  }
  return false;
}

function enderecoDoCelular(bruto, portaPadrao = PORTA_PADRAO) {
  let texto = String(bruto || '').trim();
  if (!texto) return null;
  texto = texto.replace(/^https?:\/\//i, '').replace(/\/+$/, '');
  let host = texto;
  let porta = portaPadrao;
  const ipv6 = /^\[([^\]]+)\](?::(\d+))?$/.exec(texto);
  if (ipv6) {
    host = ipv6[1];
    if (ipv6[2]) porta = Number(ipv6[2]);
  } else if (/^[^:]+:\d+$/.test(texto)) {
    const partes = texto.split(':');
    host = partes[0];
    porta = Number(partes[partes.length - 1]);
  }
  if (!Number.isInteger(porta) || porta <= 0 || porta > 65535) return null;
  if (!enderecoDaRedeLocal(host)) return null;
  return { host: host, porta: porta };
}

function erro(mensagem, codigo) {
  const e = new Error(mensagem);
  if (codigo) e.codigo = codigo;
  return e;
}

async function comTempoLimite(fetchImpl, url, opcoes = {}, ms = TEMPO_LIMITE_MS) {
  const controle = new AbortController();
  const relogio = setTimeout(() => controle.abort(), ms);
  try {
    return await fetchImpl(url, Object.assign({}, opcoes, { signal: controle.signal }));
  } catch (e) {
    if (e && e.name === 'AbortError') {
      throw erro('O celular não respondeu em ' + Math.round(ms / 1000) + ' s. Confira se ele está na mesma rede e com o pareamento aberto.', 'tempo');
    }
    throw erro('Não consegui falar com o celular em ' + url + '. Confira o IP e a rede local.', 'rede');
  } finally {
    clearTimeout(relogio);
  }
}

function normalizarRegistro(dados) {
  if (!dados || typeof dados !== 'object') return null;
  const dispositivo = String(dados.dispositivo || '').trim();
  const ip = String(dados.ip || '').trim();
  const token = String(dados.token || '').trim();
  const porta = Number(dados.porta);
  if (!dispositivo || !ip || !token) return null;
  if (!Number.isInteger(porta) || porta <= 0 || porta > 65535) return null;
  return {
    dispositivo: dispositivo,
    ip: ip,
    porta: porta,
    token: token,
    criadoEm: String(dados.criadoEm || '')
  };
}

function criarPareamento(opcoes = {}) {
  const arquivo = opcoes.arquivo;
  if (!arquivo) throw erro('criarPareamento precisa de um arquivo de registro');
  const buscar = opcoes.buscar || (typeof fetch === 'function' ? fetch : null);
  if (!buscar) throw erro('este Node não tem fetch');
  const nome = String(opcoes.nome || 'JARVIS no PC').slice(0, 80);
  const portaPadrao = Number(opcoes.portaPadrao) || PORTA_PADRAO;

  function ler() {
    try {
      const bruto = JSON.parse(fs.readFileSync(arquivo, 'utf8'));
      return normalizarRegistro(bruto && bruto.registro);
    } catch (_) {
      return null;
    }
  }

  function salvar(registro) {
    fs.mkdirSync(path.dirname(arquivo), { recursive: true });
    const temporario = arquivo + '.' + process.pid + '.tmp';
    fs.writeFileSync(temporario, JSON.stringify({ registro: registro }, null, 2), 'utf8');
    fs.renameSync(temporario, arquivo);
  }

  function credenciais(registro) {
    return { Authorization: 'Bearer ' + registro.token };
  }

  async function info(ip) {
    const alvo = enderecoDoCelular(ip, portaPadrao);
    if (!alvo) {
      throw erro('Endereço fora da rede local. Use o IP que aparece no celular (192.168.x.x, 10.x.x.x ou 172.16–31.x.x).', 'endereco');
    }
    const url = 'http://' + alvo.host + ':' + alvo.porta + '/jarvis/info';
    const resposta = await comTempoLimite(buscar, url);
    if (resposta.status === 409) {
      throw erro('O celular não está com o pareamento aberto. Abra “Pareamento Windows” no aparelho e toque em “Abrir pareamento”.', 'oferta');
    }
    if (!resposta.ok) {
      throw erro('O celular respondeu HTTP ' + resposta.status + ' ao pedido de informações.', 'http');
    }
    return resposta.json();
  }

  async function estado() {
    const registro = ler();
    if (!registro) return { pareado: false };
    return {
      pareado: true,
      dispositivo: registro.dispositivo,
      ip: registro.ip,
      porta: registro.porta,
      endereco: registro.ip + ':' + registro.porta,
      desde: registro.criadoEm
    };
  }

  async function parear(pedido = {}) {
    const codigo = codigoUtilizavel(pedido.codigo);
    if (!codigo) throw erro('Digite os 6 dígitos que aparecem no celular.', 'codigo');
    const alvo = enderecoDoCelular(pedido.ip, portaPadrao);
    if (!alvo) throw erro('Endereço fora da rede local. Use o IP que aparece no celular.', 'endereco');
    const dados = await info(pedido.ip);
    const desafio = String((dados && dados.desafio) || '');
    if (!desafio) throw erro('O celular não devolveu desafio de pareamento.', 'protocolo');

    const url = 'http://' + alvo.host + ':' + alvo.porta + '/jarvis/parear';
    const resposta = await comTempoLimite(buscar, url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ dispositivo: nome, prova: provaDePareamento(codigo, desafio) })
    });
    let corpo = {};
    try { corpo = await resposta.json(); } catch (_) { corpo = {}; }
    if (resposta.status === 403) {
      const restam = corpo.tentativasRestantes;
      throw erro('Código incorreto.' + (typeof restam === 'number'
        ? ' Tentativas restantes: ' + restam + '.'
        : ' Gere outro código no celular.'), 'codigo-errado');
    }
    if (resposta.status === 410) {
      throw erro('O código expirou. Toque em “Gerar novo código” no celular.', 'expirado');
    }
    if (!resposta.ok || !corpo.token) {
      throw erro('O celular não concluiu o pareamento (HTTP ' + resposta.status + ').', 'http');
    }
    const registro = {
      dispositivo: String(corpo.dispositivo || nome),
      ip: alvo.host,
      porta: alvo.porta,
      token: String(corpo.token),
      criadoEm: new Date().toISOString()
    };
    salvar(registro);
    return {
      pareado: true,
      dispositivo: registro.dispositivo,
      nomeCelular: String(corpo.nome || ''),
      ip: registro.ip,
      porta: registro.porta,
      endereco: registro.ip + ':' + registro.porta
    };
  }

  async function status() {
    const registro = ler();
    if (!registro) throw erro('Nenhum celular pareado.', 'sem-pareamento');
    const url = 'http://' + registro.ip + ':' + registro.porta + '/jarvis/status';
    const resposta = await comTempoLimite(buscar, url, { headers: credenciais(registro) });
    if (resposta.status === 401) {
      throw erro('O celular não reconhece mais este PC. Esqueça o pareamento e pareie de novo.', 'revogado');
    }
    if (!resposta.ok) throw erro('O celular respondeu HTTP ' + resposta.status + ' ao pedido de status.', 'http');
    return resposta.json();
  }

  async function esquecer() {
    const registro = ler();
    if (registro) {
      // Avisa o celular; se ele não estiver na rede, o registro local sai do mesmo jeito.
      const url = 'http://' + registro.ip + ':' + registro.porta + '/jarvis/esquecer';
      try {
        await comTempoLimite(buscar, url, {
          method: 'POST',
          headers: credenciais(registro)
        }, 2000);
      } catch (_) { /* melhor esforço: o esquecimento local não depende disso */ }
    }
    try { fs.unlinkSync(arquivo); } catch (_) { /* já não existia */ }
    return { esquecido: true };
  }

  return { ler, estado, info, parear, status, esquecer };
}

module.exports = {
  PORTA_PADRAO,
  normalizarCodigo,
  codigoUtilizavel,
  provaDePareamento,
  enderecoDaRedeLocal,
  enderecoDoCelular,
  criarPareamento
};
