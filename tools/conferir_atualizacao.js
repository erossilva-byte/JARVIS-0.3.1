// Confere, fora do app, o pacote de atualização que acabou de ser assinado.
//
// Roda no fim da esteira de release e também na mão: lê `atualizacao.json`,
// `atualizacao.json.sig` e o instalador de uma pasta, e verifica com a chave
// pública que vai embutida no app. Se não bater, sai com código 1 — release com
// assinatura errada não deve ser publicado.
//
// Uso: node tools/conferir_atualizacao.js <pasta> [versão-instalada] [canal]
//      [--publica caminho.pem]
//
// Sem `--publica`, usa a chave embutida no app: é a conferência que a esteira faz
// antes de publicar. Com `--publica`, dá para conferir um pacote assinado por
// outra chave (testes e chaves de desenvolvimento).
'use strict';
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const A = require(path.join(__dirname, '..', 'atualizacao_pc.js'));

const argumentos = process.argv.slice(2);
const posicaoPublica = argumentos.indexOf('--publica');
const publicaEscolhida = posicaoPublica >= 0 ? argumentos[posicaoPublica + 1] : '';
const livres = argumentos.filter((a, i) => !(posicaoPublica >= 0 && (a === '--publica' || i === posicaoPublica + 1)));
const pasta = path.resolve(livres[0] || 'dist');
const versaoInstalada = livres[1] || '0.0.1';
const canal = livres[2] || 'estavel';

function falhar(mensagem) {
  console.error('RECUSADO: ' + mensagem);
  process.exit(1);
}

const manifestoArquivo = path.join(pasta, 'atualizacao.json');
if (!fs.existsSync(manifestoArquivo)) falhar('não achei ' + manifestoArquivo);
const manifesto = JSON.parse(fs.readFileSync(manifestoArquivo, 'utf8'));
const assinaturaArquivo = manifestoArquivo + '.sig';
const assinatura = fs.existsSync(assinaturaArquivo) ? fs.readFileSync(assinaturaArquivo, 'utf8').trim() : '';
const arquivoChave = publicaEscolhida
  ? path.resolve(publicaEscolhida)
  : path.join(__dirname, '..', 'platforms', 'desktop', 'atualizacao-publica.pem');
const chave = fs.readFileSync(arquivoChave, 'utf8');
const arquivo = path.join(pasta, String(manifesto.arquivo || ''));
if (!manifesto.arquivo || !fs.existsSync(arquivo)) falhar('o instalador citado no manifesto não está em ' + pasta);

const bytes = fs.readFileSync(arquivo);
const resultado = A.verificarAtualizacao({
  manifesto: manifesto,
  assinatura: assinatura,
  chavePublica: chave,
  sha256Arquivo: crypto.createHash('sha256').update(bytes).digest('hex'),
  tamanhoArquivo: bytes.length,
  versaoInstalada: versaoInstalada,
  aceitaCanal: canal
});

if (!resultado.ok) falhar(resultado.texto);
const digital = crypto.createHash('sha256')
  .update(crypto.createPublicKey(chave).export({ type: 'spki', format: 'der' }))
  .digest('hex');
console.log('ok: ' + resultado.texto);
console.log('versão: ' + manifesto.versao + ' · canal ' + manifesto.canal + ' · ' + bytes.length + ' bytes');
console.log('sha256: ' + manifesto.sha256);
console.log('chave usada: ' + (publicaEscolhida ? arquivoChave : 'embutida no app'));
console.log('digital da chave pública: ' + digital.slice(0, 32) + '…');
