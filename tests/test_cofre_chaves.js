// Cofre de chaves do PC (1.106.0): recusa sem proteção do sistema e cifra a chave.
//
// O cofre de verdade usa o safeStorage do Electron (DPAPI/Keychain/secret
// service). Aqui entra um safeStorage falso que faz o mesmo papel: o teste
// prova o contrato — falhar fechado sem proteção, nunca gravar em texto puro,
// listar só nomes e não sobrescrever arquivo ilegível.
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const COFRE = require(path.join(__dirname, '..', 'platforms', 'desktop', 'cofre_chaves.js'));

const raiz = fs.mkdtempSync(path.join(os.tmpdir(), 'jarvis-cofre-'));

/** Cifra reversível de mentira: só para provar que o valor não fica legível. */
function safeStorageFalso(disponivel) {
  return {
    isEncryptionAvailable: () => disponivel,
    encryptString: (texto) => Buffer.from('CIFRADO:' + texto, 'utf8'),
    decryptString: (buf) => String(buf).replace(/^CIFRADO:/, '')
  };
}

try {
  /* ---------- 1. Sem proteção do sistema: recusa gravar, não cria arquivo ---------- */
  {
    const cofre = COFRE.criarCofre({ dirDados: raiz, safeStorage: safeStorageFalso(false) });
    assert.equal(cofre.disponivel(), false, 'cofre disse estar disponível sem o sistema');
    const r = cofre.guardar({ nome: 'groq', valor: 'gsk_segredo' });
    assert.equal(r.ok, false, 'gravou sem proteção do sistema');
    assert.ok(/não está disponível/i.test(r.erro), r.erro);
    assert.ok(/texto puro/i.test(r.erro), 'erro não explica a recusa de texto puro');
    assert.equal(fs.existsSync(path.join(raiz, 'jarvis-secrets.json')), false, 'criou arquivo sem proteção');
    assert.equal(cofre.ler({ nome: 'groq' }).ok, false, 'leu sem proteção do sistema');
    const lista = cofre.listar();
    assert.equal(lista.ok, true);
    assert.equal(lista.disponivel, false);
    assert.deepEqual(lista.nomes, []);
  }

  /* ---------- 2. Sem safeStorage nenhum também recusa ---------- */
  {
    const cofre = COFRE.criarCofre({ dirDados: raiz, safeStorage: null });
    assert.equal(cofre.guardar({ nome: 'groq', valor: 'x' }).ok, false);
  }

  /* ---------- 3. Com proteção: grava cifrado, lê de volta e não vaza o valor ---------- */
  {
    const cofre = COFRE.criarCofre({ dirDados: raiz, safeStorage: safeStorageFalso(true) });
    assert.equal(cofre.disponivel(), true);
    assert.equal(cofre.guardar({ nome: 'groq', valor: 'gsk_segredo_de_teste' }).ok, true);
    const arquivo = path.join(raiz, 'jarvis-secrets.json');
    assert.ok(fs.existsSync(arquivo), 'não gravou o cofre');
    const bruto = fs.readFileSync(arquivo, 'utf8');
    assert.equal(bruto.indexOf('gsk_segredo_de_teste'), -1, 'a chave ficou em texto puro no disco');
    assert.ok(bruto.indexOf(Buffer.from('CIFRADO:gsk_segredo_de_teste').toString('base64')) > 0,
      'o arquivo não guarda o texto cifrado em base64');

    const lido = cofre.ler({ nome: 'groq' });
    assert.equal(lido.ok, true);
    assert.equal(lido.valor, 'gsk_segredo_de_teste', 'a chave não voltou igual');

    const lista = cofre.listar();
    assert.deepEqual(lista.nomes, ['groq'], 'a lista deveria trazer só o nome');

    // Nome fora da lista é recusado, para o renderer não gravar chave arbitrária.
    assert.equal(cofre.guardar({ nome: '../etc/passwd', valor: 'x' }).ok, false);
    assert.equal(cofre.guardar({ nome: 'qualquer', valor: 'x' }).ok, false);

    // Apagar remove só aquela chave.
    cofre.guardar({ nome: 'openrouter', valor: 'sk-or-teste' });
    assert.deepEqual(cofre.listar().nomes, ['groq', 'openrouter']);
    assert.equal(cofre.apagar({ nome: 'groq' }).ok, true);
    assert.deepEqual(cofre.listar().nomes, ['openrouter']);
    assert.equal(cofre.ler({ nome: 'groq' }).valor, '', 'chave apagada ainda voltou');
  }

  /* ---------- 4. Arquivo ilegível não é sobrescrito ---------- */
  {
    const outra = fs.mkdtempSync(path.join(os.tmpdir(), 'jarvis-cofre-'));
    const arquivo = path.join(outra, 'jarvis-secrets.json');
    fs.writeFileSync(arquivo, '{ isso não é json', 'utf8');
    const cofre = COFRE.criarCofre({ dirDados: outra, safeStorage: safeStorageFalso(true) });
    const r = cofre.guardar({ nome: 'groq', valor: 'nova' });
    assert.equal(r.ok, false, 'sobrescreveu cofre ilegível');
    assert.ok(/ilegível/i.test(r.erro), r.erro);
    assert.equal(fs.readFileSync(arquivo, 'utf8'), '{ isso não é json', 'o arquivo ilegível foi trocado');
    assert.equal(cofre.listar().ok, false, 'lista não avisou o arquivo ilegível');
    fs.rmSync(outra, { recursive: true, force: true });
  }

  console.log('cofre_chaves: recusa sem sistema, cifra, lista só nomes e preserva arquivo ilegível — OK');
} finally {
  fs.rmSync(raiz, { recursive: true, force: true });
}
