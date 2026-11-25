// Regras da Etapa 7 do PC: atualização assinada, sem rebaixamento e com o
// arquivo conferido; e as notas da versão que o app mostra.
//
// A assinatura é feita com chaves Ed25519 de verdade, geradas no teste: não há
// atalho nem "modo de teste" no módulo que o app usa.
'use strict';
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const A = require(path.join(__dirname, '..', 'atualizacao_pc.js'));

let falhas = 0;
function chk(nome, cond, detalhe) {
  if (cond) console.log('OK: ' + nome);
  else { falhas++; console.log('FALHA: ' + nome + (detalhe ? ' — ' + detalhe : '')); }
}

const raiz = path.join(__dirname, '..');
const { publicKey, privateKey } = crypto.generateKeyPairSync('ed25519');
const publicaPem = publicKey.export({ type: 'spki', format: 'pem' });
const privadaPem = privateKey.export({ type: 'pkcs8', format: 'pem' });
const outra = crypto.generateKeyPairSync('ed25519');

/* ---------- 1. JSON canônico e versões ---------- */
chk('JSON canônico ordena chaves', A.canonico({ b: 1, a: 2 }) === '{"a":2,"b":1}');
chk('JSON canônico aninha e mantém listas', A.canonico({ z: [{ y: 1, x: 2 }] }) === '{"z":[{"x":2,"y":1}]}');
chk('ordem de escrita não muda o canônico', A.canonico({ x: 1, y: 2 }) === A.canonico({ y: 2, x: 1 }));
chk('versão válida', A.versaoValida('1.109.0') && A.versaoValida('2.0.0-beta.1'));
chk('versão inválida recusada', !A.versaoValida('1.2') && !A.versaoValida('v1.2.3') && !A.versaoValida(''));
chk('compara maior', A.compararVersoes('1.109.0', '1.107.9') === 1);
chk('compara menor', A.compararVersoes('1.9.0', '1.10.0') === -1);
chk('compara igual', A.compararVersoes('1.109.0', '1.109.0') === 0);
chk('sufixo não faz versão maior', A.compararVersoes('1.109.0-beta.1', '1.109.0') === 0);

/* ---------- 2. Manifesto ---------- */
const manifesto = {
  app: A.APP,
  canal: 'estavel',
  versao: '1.109.0',
  arquivo: 'J.A.R.V.I.S. Nova Setup 1.109.0.exe',
  tamanho: 120000000,
  sha256: 'a'.repeat(64),
  data: '2026-11-25T12:00:00.000Z',
  notas: ['Instalador assinado', 'Atualização verificada']
};
chk('manifesto completo é válido', A.validarManifesto(manifesto).ok, JSON.stringify(A.validarManifesto(manifesto).erros));
chk('manifesto vazio é recusado', A.validarManifesto(null).ok === false && A.validarManifesto({}).ok === false);
const semHash = Object.assign({}, manifesto); delete semHash.sha256;
chk('campo ausente é listado', A.validarManifesto(semHash).erros.some((e) => /sha256/.test(e)));
chk('outro aplicativo é recusado',
  A.validarManifesto(Object.assign({}, manifesto, { app: 'outro' })).erros.some((e) => /outro aplicativo/.test(e)));
chk('canal desconhecido é recusado',
  A.validarManifesto(Object.assign({}, manifesto, { canal: 'noturno' })).ok === false);
chk('só .exe é aceito',
  A.validarManifesto(Object.assign({}, manifesto, { arquivo: 'pacote.zip' })).ok === false);
chk('sha256 precisa ter 64 hex',
  A.validarManifesto(Object.assign({}, manifesto, { sha256: 'abc' })).ok === false);
chk('tamanho zero é recusado',
  A.validarManifesto(Object.assign({}, manifesto, { tamanho: 0 })).ok === false);

/* ---------- 3. Assinatura ---------- */
const assinatura = A.assinar(manifesto, privadaPem);
chk('assina em base64', typeof assinatura === 'string' && assinatura.length > 60);
chk('assinatura confere', A.verificarAssinatura(manifesto, assinatura, publicaPem).ok);
chk('mesma assinatura de novo (Ed25519 é determinística)',
  A.assinar(manifesto, privadaPem) === assinatura);
chk('outra chave recusa',
  A.verificarAssinatura(manifesto, assinatura, outra.publicKey.export({ type: 'spki', format: 'pem' })).motivo === 'assinatura-invalida');
chk('manifesto alterado recusa',
  A.verificarAssinatura(Object.assign({}, manifesto, { versao: '9.9.9' }), assinatura, publicaPem).ok === false);
chk('nota alterada recusa',
  A.verificarAssinatura(Object.assign({}, manifesto, { notas: ['outra coisa'] }), assinatura, publicaPem).ok === false);
chk('assinatura ausente recusa', A.verificarAssinatura(manifesto, '', publicaPem).motivo === 'sem-assinatura');
chk('chave pública ausente recusa', A.verificarAssinatura(manifesto, assinatura, '').motivo === 'sem-chave');
chk('assinatura lixo recusa',
  A.verificarAssinatura(manifesto, Buffer.from('lixo').toString('base64'), publicaPem).ok === false);
chk('versão só do manifesto não basta quando o hash difere',
  A.verificarAtualizacao({
    manifesto, assinatura, chavePublica: publicaPem,
    sha256Arquivo: 'b'.repeat(64), tamanhoArquivo: manifesto.tamanho, versaoInstalada: '1.107.0'
  }).motivo === 'hash');

/* ---------- 4. Decisão completa ---------- */
const base = {
  manifesto, assinatura, chavePublica: publicaPem,
  sha256Arquivo: manifesto.sha256, tamanhoArquivo: manifesto.tamanho,
  versaoInstalada: '1.107.0'
};
const ok = A.verificarAtualizacao(base);
chk('atualização válida passa', ok.ok && ok.versao === '1.109.0');
chk('texto diz que assinatura e hash conferem', /assinatura e hash conferem/.test(ok.texto));
chk('notas acompanham a decisão', Array.isArray(ok.notas) && ok.notas.length === 2);
chk('sem hash do arquivo recusa',
  A.verificarAtualizacao(Object.assign({}, base, { sha256Arquivo: '' })).motivo === 'sem-arquivo');
chk('tamanho diferente recusa',
  A.verificarAtualizacao(Object.assign({}, base, { tamanhoArquivo: 1 })).motivo === 'tamanho');
chk('mesma versão recusa',
  A.verificarAtualizacao(Object.assign({}, base, { versaoInstalada: '1.109.0' })).motivo === 'mesma-versao');
chk('rebaixamento recusa',
  A.verificarAtualizacao(Object.assign({}, base, { versaoInstalada: '1.110.0' })).motivo === 'mais-antiga');
chk('versão instalada ilegível recusa',
  A.verificarAtualizacao(Object.assign({}, base, { versaoInstalada: '' })).motivo === 'versao-instalada');
const comMinima = Object.assign({}, manifesto, { minima: '1.110.0' });
chk('versão mínima respeitada',
  A.verificarAtualizacao(Object.assign({}, base, {
    manifesto: comMinima, chavePublica: publicaPem,
    assinatura: A.assinar(comMinima, privadaPem), versaoInstalada: '1.105.0'
  })).motivo === 'versao-minima');
chk('canal diferente recusa',
  A.verificarAtualizacao(Object.assign({}, base, { aceitaCanal: 'beta' })).motivo === 'canal');

/* ---------- 5. Plano de aplicar e reverter ---------- */
const plano = A.planoDeAtualizacao(ok, { instaladorAnterior: 'Setup 1.107.0.exe' });
chk('plano aplica em quatro passos', plano.aplicar.length === 4);
chk('plano manda fechar o app antes', /Fechar/.test(plano.aplicar[0]));
chk('plano confere a versão depois', plano.aplicar.some((p) => /Ajustes ▸ Sobre/.test(p)));
chk('reversão cita o instalador anterior', plano.reverter.join(' ').includes('Setup 1.107.0.exe'));
chk('reversão não apaga os dados', /mantendo a pasta de dados/.test(plano.reverter[0]));
chk('sem pacote verificado não há plano',
  A.planoDeAtualizacao({ ok: false }).aplicar.length === 0);

/* ---------- 6. Notas da versão no app ---------- */
const changelog = fs.readFileSync(path.join(raiz, 'CHANGELOG.md'), 'utf8');
const notas = A.notasDaVersao(changelog, '1.107.0');
chk('acha as notas da versão instalada', notas.ok && notas.titulo.indexOf('1.107.0') >= 0);
chk('as notas não vêm vazias', notas.notas.length > 3);
chk('as notas são desta versão', notas.notas.some((n) => /voz|escuta|tabela/i.test(n)));
chk('versão fora do arquivo devolve ok:false', A.notasDaVersao(changelog, '0.0.9').ok === false);
chk('changelog vazio não quebra', A.notasDaVersao('', '1.107.0').ok === false);
chk('notas não incluem o título seguinte', !notas.notas.some((n) => /^##/.test(n)));
chk('notas não vazam marcação do Markdown',
  !notas.notas.some((n) => /\*\*|`/.test(n)), notas.notas.find((n) => /\*\*|`/.test(n)));

/* ---------- 7. Ferramentas de release, de ponta a ponta ---------- */
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'jarvis-atualizacao-'));
const dist = path.join(tmp, 'dist');
const chaves = path.join(tmp, 'chaves');
fs.mkdirSync(dist, { recursive: true });
const gerou = spawnSync(process.execPath, [path.join(raiz, 'tools', 'chave_atualizacao.js'), chaves], { encoding: 'utf8' });
chk('ferramenta gera o par de chaves', gerou.status === 0 && fs.existsSync(path.join(chaves, 'atualizacao-privada.pem')));
if (process.platform !== 'win32') {
  const modo = fs.statSync(path.join(chaves, 'atualizacao-privada.pem')).mode & 0o777;
  chk('chave privada nasce 0600', modo === 0o600, modo.toString(8));
}
const segunda = spawnSync(process.execPath, [path.join(raiz, 'tools', 'chave_atualizacao.js'), chaves], { encoding: 'utf8' });
chk('não sobrescreve chave existente', segunda.status === 1 && /não sobrescrevo/.test(segunda.stderr));

const setup = path.join(dist, 'J.A.R.V.I.S. Nova Setup 1.109.0.exe');
fs.writeFileSync(setup, Buffer.alloc(21000000, 7));
const notasTxt = path.join(tmp, 'notas.txt');
fs.writeFileSync(notasTxt, 'Instalador assinado\nAtualização com assinatura conferida\n');
const assinou = spawnSync(process.execPath, [
  path.join(raiz, 'tools', 'assinar_atualizacao.js'),
  '--pasta', dist,
  '--chave', path.join(chaves, 'atualizacao-privada.pem'),
  '--versao', '1.109.0',
  '--notas', notasTxt
], { encoding: 'utf8' });
chk('ferramenta assina o pacote', assinou.status === 0, assinou.stderr.slice(0, 200));
const gerado = JSON.parse(fs.readFileSync(path.join(dist, 'atualizacao.json'), 'utf8'));
const sig = fs.readFileSync(path.join(dist, 'atualizacao.json.sig'), 'utf8').trim();
const publicaGerada = fs.readFileSync(path.join(chaves, 'atualizacao-publica.pem'), 'utf8');
const hashReal = crypto.createHash('sha256').update(fs.readFileSync(setup)).digest('hex');
chk('manifesto gerado tem o hash real', gerado.sha256 === hashReal);
chk('manifesto gerado tem o tamanho real', gerado.tamanho === 21000000);
chk('notas do arquivo entraram no manifesto', gerado.notas.length === 2);
chk('pacote assinado passa na verificação',
  A.verificarAtualizacao({
    manifesto: gerado, assinatura: sig, chavePublica: publicaGerada,
    sha256Arquivo: hashReal, tamanhoArquivo: gerado.tamanho, versaoInstalada: '1.107.0'
  }).ok);
chk('trocar um byte do instalador derruba a atualização',
  A.verificarAtualizacao({
    manifesto: gerado, assinatura: sig, chavePublica: publicaGerada,
    sha256Arquivo: 'c'.repeat(64), tamanhoArquivo: gerado.tamanho, versaoInstalada: '1.107.0'
  }).motivo === 'hash');

const conferiu = spawnSync(process.execPath, [
  path.join(raiz, 'tools', 'conferir_atualizacao.js'), dist, '1.107.0',
  '--publica', path.join(chaves, 'atualizacao-publica.pem')
], { encoding: 'utf8' });
chk('ferramenta de conferência aprova o pacote assinado', conferiu.status === 0, (conferiu.stderr || '').slice(0, 200));
const chaveDoApp = spawnSync(process.execPath, [
  path.join(raiz, 'tools', 'conferir_atualizacao.js'), dist, '1.107.0'
], { encoding: 'utf8' });
chk('a conferência padrão usa a chave embutida e recusa chave estranha',
  chaveDoApp.status === 1 && /assinatura não confere/i.test(chaveDoApp.stderr), (chaveDoApp.stderr || '').slice(0, 160));
fs.appendFileSync(setup, Buffer.from([1]));
const recusou = spawnSync(process.execPath, [
  path.join(raiz, 'tools', 'conferir_atualizacao.js'), dist, '1.107.0',
  '--publica', path.join(chaves, 'atualizacao-publica.pem')
], { encoding: 'utf8' });
chk('ferramenta de conferência recusa pacote alterado',
  recusou.status === 1 && /RECUSADO/.test(recusou.stderr), (recusou.stderr || '').slice(0, 200));

fs.rmSync(tmp, { recursive: true, force: true });

if (falhas) {
  console.log('\n' + falhas + ' falha(s) na atualização do PC.');
  process.exit(1);
}
console.log('\natualizacao_pc: assinatura Ed25519, hash, versão, plano e notas — OK');
