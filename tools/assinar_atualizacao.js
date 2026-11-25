// Assina o pacote de atualização do PC: escreve `atualizacao.json` e
// `atualizacao.json.sig` ao lado do instalador.
//
// Só esta ferramenta vê a chave privada. O app verifica com a chave pública
// embutida — se o manifesto, o hash ou o tamanho mudarem depois da assinatura, a
// verificação falha (é o que os testes provam).
//
// Uso:
//   node tools/assinar_atualizacao.js --pasta dist --chave ~/chaves/atualizacao-privada.pem \
//     --versao 1.108.0 [--canal estavel] [--minima 1.100.0] [--notas notas.txt]
'use strict';
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const A = require(path.join(__dirname, '..', 'atualizacao_pc.js'));

function argumentos(argv) {
  const saida = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const chave = a.slice(2);
      const valor = argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[++i] : 'true';
      saida[chave] = valor;
    }
  }
  return saida;
}

const args = argumentos(process.argv.slice(2));
function sair(mensagem) {
  console.error(mensagem);
  process.exit(1);
}

if (!args.pasta) sair('Informe --pasta com o diretório do instalador.');
if (!args.chave) sair('Informe --chave com o caminho da chave privada (fora do repositório).');
if (!args.versao || !A.versaoValida(args.versao)) sair('Informe --versao no formato 1.2.3.');

const pasta = path.resolve(args.pasta);
const chave = fs.readFileSync(path.resolve(args.chave), 'utf8');
if (!/BEGIN PRIVATE KEY/.test(chave)) sair('A chave informada não é uma chave privada PKCS#8.');

const exes = fs.readdirSync(pasta).filter((f) => /\.exe$/i.test(f) && !/uninstall/i.test(f));
const setup = exes.find((f) => /setup/i.test(f));
if (!setup) sair('Não achei o instalador (…Setup….exe) em ' + pasta + '. Rode depois do electron-builder.');

const arquivo = path.join(pasta, setup);
const bytes = fs.readFileSync(arquivo);
// O electron-builder deixa um stub de ~160 kB quando falha no meio; assinar isso
// daria um "pacote oficial" que não instala nada.
if (bytes.length < 20000000) sair('Artefato pequeno demais (possível stub): ' + setup + ' · ' + bytes.length + ' bytes.');

const notasArquivo = args.notas ? fs.readFileSync(path.resolve(args.notas), 'utf8') : '';
const notas = notasArquivo
  ? notasArquivo.split(/\r?\n/).map((l) => l.trim()).filter(Boolean).slice(0, 12)
  : [];

const manifesto = {
  app: A.APP,
  canal: args.canal || 'estavel',
  versao: args.versao,
  arquivo: setup,
  tamanho: bytes.length,
  sha256: crypto.createHash('sha256').update(bytes).digest('hex'),
  data: new Date().toISOString(),
  ...(args.minima ? { minima: args.minima } : {}),
  ...(notas.length ? { notas } : {})
};

const valido = A.validarManifesto(manifesto);
if (!valido.ok) sair('Manifesto inválido: ' + valido.erros.join('; '));

const assinatura = A.assinar(manifesto, chave);
// Confere antes de gravar: assinar errado e só descobrir na hora de atualizar
// seria pior do que falhar aqui.
const conferida = A.verificarAssinatura(manifesto, assinatura, crypto.createPublicKey(chave));
if (!conferida.ok) sair('A assinatura não confere com a própria chave: ' + conferida.texto);

const destino = path.join(pasta, 'atualizacao.json');
fs.writeFileSync(destino, JSON.stringify(manifesto, null, 2) + '\n');
fs.writeFileSync(destino + '.sig', assinatura + '\n');
const digital = crypto.createHash('sha256')
  .update(crypto.createPublicKey(chave).export({ type: 'spki', format: 'der' }))
  .digest('hex');

console.log('assinado: ' + setup + ' (' + bytes.length + ' bytes)');
console.log('sha256: ' + manifesto.sha256);
console.log('versão: ' + manifesto.versao + ' · canal ' + manifesto.canal);
console.log('digital da chave: ' + digital.slice(0, 32) + '… (precisa ser a mesma da chave embutida no app)');
console.log('arquivos: ' + destino + ' e ' + destino + '.sig');
