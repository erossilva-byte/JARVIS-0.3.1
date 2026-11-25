// Gera o par de chaves Ed25519 que assina as atualizações do PC.
//
// A chave privada fica FORA do repositório (e fora do app): só a ferramenta de
// release a usa. A pública vai embutida no processo principal do JARVIS, em
// `platforms/desktop/chave_atualizacao.pem`.
//
// Uso: node tools/chave_atualizacao.js <pasta>
'use strict';
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const pasta = path.resolve(process.argv[2] || '.');
const { publicKey, privateKey } = crypto.generateKeyPairSync('ed25519');

const privado = path.join(pasta, 'atualizacao-privada.pem');
const publico = path.join(pasta, 'atualizacao-publica.pem');
if (fs.existsSync(privado)) {
  console.error('Já existe ' + privado + ' — não sobrescrevo chave de assinatura.');
  process.exit(1);
}
fs.mkdirSync(pasta, { recursive: true });
const privPem = privateKey.export({ type: 'pkcs8', format: 'pem' });
fs.writeFileSync(privado, privPem, { mode: 0o600 });
fs.writeFileSync(publico, publicKey.export({ type: 'spki', format: 'pem' }), { mode: 0o644 });

const digital = crypto.createHash('sha256').update(publicKey.export({ type: 'spki', format: 'der' })).digest('hex');
console.log('chave privada: ' + privado + ' (0600, nunca versionar)');
console.log('chave pública: ' + publico);
console.log('digital da chave (confira com a embutida no app): ' + digital.slice(0, 32) + '…');
console.log('Copie a pública para platforms/desktop/chave_atualizacao.pem.');
