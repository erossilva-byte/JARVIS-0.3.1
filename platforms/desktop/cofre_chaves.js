/* J.A.R.V.I.S. Nova — Cofre de chaves do PC.
 *
 * As chaves de provedor (Groq, OpenRouter, Cerebras, Mistral, Gemini) são
 * cifradas pela proteção de credenciais do próprio sistema — DPAPI no Windows,
 * Keychain no macOS e secret service no Linux, expostos pelo Electron como
 * `safeStorage`. O arquivo guarda só o texto cifrado em base64.
 *
 * Regras:
 *  - sem `safeStorage` disponível, o cofre **recusa** gravar em vez de cair
 *    para texto puro;
 *  - o renderer nunca vê o arquivo: ele pede uma chave pelo nome;
 *  - gravação é atômica (temporário + rename) e o arquivo nasce com permissão
 *    de dono (0600);
 *  - arquivo ilegível não é sobrescrito: o erro sobe e nada é trocado.
 *
 * O `safeStorage` é injetado para o teste rodar sem Electron.
 */
'use strict';

const fs = require('node:fs');
const path = require('node:path');

const NOMES_VALIDOS = ['groq', 'openrouter', 'cerebras', 'mistral', 'gemini'];

function criarCofre(opcoes) {
  const o = opcoes || {};
  const dirDados = o.dirDados || '';
  const safeStorage = o.safeStorage || null;
  const arquivo = path.join(dirDados, 'jarvis-secrets.json');

  function disponivel() {
    try {
      return !!(safeStorage && typeof safeStorage.isEncryptionAvailable === 'function' &&
        safeStorage.isEncryptionAvailable() &&
        typeof safeStorage.encryptString === 'function' &&
        typeof safeStorage.decryptString === 'function');
    } catch (erro) {
      return false;
    }
  }

  function erroSemSistema() {
    return 'O armazenamento criptografado do sistema não está disponível; a chave não foi salva. ' +
      'O cofre não guarda chave de provedor em texto puro.';
  }

  function lerArquivo() {
    if (!fs.existsSync(arquivo)) return {};
    let bruto;
    try {
      bruto = JSON.parse(fs.readFileSync(arquivo, 'utf8'));
    } catch (erro) {
      throw new Error('O cofre local está ilegível. Nenhuma chave foi substituída.');
    }
    if (!bruto || typeof bruto !== 'object' || Array.isArray(bruto)) {
      throw new Error('O cofre local está ilegível. Nenhuma chave foi substituída.');
    }
    return bruto;
  }

  function gravarArquivo(dados) {
    fs.mkdirSync(path.dirname(arquivo), { recursive: true });
    const temporario = arquivo + '.tmp';
    fs.writeFileSync(temporario, JSON.stringify(dados), { mode: 0o600 });
    fs.renameSync(temporario, arquivo);
  }

  function nomeValido(nome) {
    return NOMES_VALIDOS.indexOf(String(nome == null ? '' : nome)) >= 0;
  }

  /** Nomes das chaves guardadas — nunca os valores. */
  function listar() {
    let dados;
    try {
      dados = lerArquivo();
    } catch (erro) {
      return { ok: false, disponivel: disponivel(), nomes: [], erro: erro.message };
    }
    return {
      ok: true,
      disponivel: disponivel(),
      nomes: Object.keys(dados).filter(nomeValido).sort()
    };
  }

  function guardar(dados) {
    const d = dados || {};
    if (!disponivel()) return { ok: false, erro: erroSemSistema() };
    if (!nomeValido(d.nome)) return { ok: false, erro: 'Nome de chave inválido.' };
    let atual;
    try {
      atual = lerArquivo();
    } catch (erro) {
      return { ok: false, erro: erro.message };
    }
    const valor = String(d.valor == null ? '' : d.valor);
    if (!valor) delete atual[d.nome];
    else atual[d.nome] = safeStorage.encryptString(valor).toString('base64');
    try {
      gravarArquivo(atual);
    } catch (erro) {
      return { ok: false, erro: 'Não foi possível gravar o cofre: ' + (erro && erro.message ? erro.message : erro) };
    }
    return { ok: true };
  }

  function ler(dados) {
    const d = dados || {};
    if (!disponivel()) return { ok: false, erro: erroSemSistema() };
    if (!nomeValido(d.nome)) return { ok: false, erro: 'Nome de chave inválido.' };
    let atual;
    try {
      atual = lerArquivo();
    } catch (erro) {
      return { ok: false, erro: erro.message };
    }
    const cifrado = atual[d.nome];
    if (!cifrado) return { ok: true, valor: '' };
    try {
      return { ok: true, valor: safeStorage.decryptString(Buffer.from(String(cifrado), 'base64')) };
    } catch (erro) {
      return { ok: false, erro: 'O sistema não conseguiu abrir esta chave; ela não foi alterada.' };
    }
  }

  function apagar(dados) {
    const d = dados || {};
    if (!nomeValido(d.nome)) return { ok: false, erro: 'Nome de chave inválido.' };
    let atual;
    try {
      atual = lerArquivo();
    } catch (erro) {
      return { ok: false, erro: erro.message };
    }
    if (!atual[d.nome]) return { ok: true, removida: false };
    delete atual[d.nome];
    try {
      gravarArquivo(atual);
    } catch (erro) {
      return { ok: false, erro: 'Não foi possível gravar o cofre: ' + (erro && erro.message ? erro.message : erro) };
    }
    return { ok: true, removida: true };
  }

  return {
    arquivo: arquivo,
    NOMES_VALIDOS: NOMES_VALIDOS,
    disponivel: disponivel,
    listar: listar,
    guardar: guardar,
    ler: ler,
    apagar: apagar
  };
}

module.exports = { criarCofre: criarCofre, NOMES_VALIDOS: NOMES_VALIDOS };
