// Teste de comportamento do motor de arquivos do desktop, sem Electron:
// roda os mesmos módulos que o processo principal usa, numa pasta temporária.
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const ARQ = require('../platforms/desktop/arquivos.js');

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'jv-arq-'));
const raiz = path.join(tmp, 'home');
fs.mkdirSync(path.join(raiz, 'Jarvis'), { recursive: true });
const arq = ARQ.criarArquivos({ raiz });

let falhas = 0;
function ok(nome, fn) {
  try { fn(); console.log('OK: ' + nome); }
  catch (e) { falhas++; console.log('FALHA: ' + nome + ' -> ' + e.message); }
}
function escrever(rel, texto) { fs.writeFileSync(path.join(raiz, rel), texto); }
function ler(rel) { return fs.readFileSync(path.join(raiz, rel), 'utf8'); }

// ---------- Detecção por assinatura, não por extensão ----------
const png = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 13,
  0x49, 0x48, 0x44, 0x52, 0, 0, 0, 10, 0, 0, 0, 20, 8, 2, 0, 0, 0]);
fs.writeFileSync(path.join(raiz, 'Jarvis', 'disfarcado.txt'), png);
ok('PNG com extensão .txt é identificado como imagem', () => {
  const r = arq.ler('~/Jarvis/disfarcado.txt');
  assert.strictEqual(r.formato, 'png');
  assert.strictEqual(r.tipo, 'imagem');
  assert.ok(r.imagem.startsWith('data:image/png;base64,'));
  assert.strictEqual(r.medidas.largura, 10);
});

// ---------- Listagem e prévias ----------
escrever('Jarvis/nota.md', '# Nota\n\n- alfa\n- beta\n');
escrever('Jarvis/dados.csv', 'nome,idade\nAna,30\nBia,25\n');
escrever('Jarvis/config.json', '{"tema":"escuro","voz":true}');
ok('Lista com formato e tipo por arquivo', () => {
  const r = arq.listar('~/Jarvis');
  const porNome = {};
  r.itens.forEach((i) => { porNome[i.nome] = i; });
  assert.strictEqual(porNome['nota.md'].tipo, 'texto');
  assert.strictEqual(porNome['dados.csv'].tipo, 'planilha');
  assert.strictEqual(porNome['config.json'].tipo, 'dados');
  assert.strictEqual(r.relativo, '~' + path.sep + 'Jarvis');
});
ok('CSV vira tabela com separador e colunas', () => {
  const r = arq.ler('~/Jarvis/dados.csv');
  assert.strictEqual(r.tabela.separador, ',');
  assert.strictEqual(r.tabela.colunas, 2);
  assert.deepStrictEqual(r.tabela.linhas[1], ['Ana', '30']);
  assert.strictEqual(r.editavel, true);
});
ok('JSON inválido é explicado, não engolido', () => {
  escrever('Jarvis/quebrado.json', '{"a": }');
  const r = arq.ler('~/Jarvis/quebrado.json');
  assert.ok(/JSON inválido/i.test(r.resumo));
});

// ---------- Salvar com backup atômico ----------
ok('Salvar cria cópia .bak e grava conteúdo novo', () => {
  const antes = ler('Jarvis/nota.md');
  const r = arq.salvar({ caminho: '~/Jarvis/nota.md', texto: '# Nota nova\n', backup: true });
  assert.strictEqual(ler('Jarvis/nota.md'), '# Nota nova\n');
  assert.ok(r.backup.startsWith('~'), 'backup deveria ser caminho relativo: ' + r.backup);
  const nomeBak = r.backup.split(path.sep).pop();
  assert.ok(nomeBak.startsWith('nota.md.bak-'), 'nome do backup: ' + nomeBak);
  assert.strictEqual(fs.readFileSync(path.join(raiz, 'Jarvis', nomeBak), 'utf8'), antes);
});

// ---------- Comparação ----------
ok('Comparar mostra linha alterada', () => {
  escrever('Jarvis/a.txt', 'um\ndois\ntres\n');
  escrever('Jarvis/b.txt', 'um\nDOIS\ntres\n');
  const r = arq.comparar('~/Jarvis/a.txt', '~/Jarvis/b.txt');
  assert.strictEqual(r.iguais, false);
  assert.strictEqual(r.removidas, 1);
  assert.strictEqual(r.adicionadas, 1);
  assert.strictEqual(r.blocos[0].linha, 2);
});
ok('Comparar arquivos idênticos', () => {
  escrever('Jarvis/c.txt', 'igual\n');
  const r = arq.comparar('~/Jarvis/c.txt', '~/Jarvis/c.txt');
  assert.strictEqual(r.iguais, true);
});

// ---------- Conversão real ----------
ok('CSV -> JSON preserva os valores', () => {
  const r = arq.converter({ caminho: '~/Jarvis/dados.csv', alvo: 'json' });
  const dados = JSON.parse(ler('Jarvis/dados.json'));
  assert.strictEqual(r.para, 'json');
  assert.deepStrictEqual(dados[0], { nome: 'Ana', idade: '30' });
});
ok('JSON -> CSV volta com cabeçalho', () => {
  arq.converter({ caminho: '~/Jarvis/dados.json', alvo: 'csv', sobrescrever: true });
  const voltou = ler('Jarvis/dados.csv');
  assert.ok(voltou.startsWith('nome,idade'), voltou);
});
ok('Markdown -> HTML gera documento completo', () => {
  escrever('Jarvis/leia.md', '# Titulo\n\n- item\n');
  const r = arq.converter({ caminho: '~/Jarvis/leia.md', alvo: 'html' });
  const html = ler('Jarvis/leia.html');
  assert.ok(r.perdas.length >= 1);
  assert.ok(/<h1>Titulo<\/h1>/.test(html));
  assert.ok(/<li>item<\/li>/.test(html));
});
ok('Conversão não implementada é recusada', () => {
  escrever('Jarvis/imagem.txt', 'texto\n');
  assert.throws(() => arq.converter({ caminho: '~/Jarvis/imagem.txt', alvo: 'pdf' }), /não implementada/i);
});
ok('Converter não sobrescreve sem confirmação', () => {
  // dados.json já existe (criado no teste anterior): a conversão precisa parar aqui.
  assert.throws(() => arq.converter({ caminho: '~/Jarvis/dados.csv', alvo: 'json' }), /Confirme a substituição/i);
});

// ---------- Pesquisa ----------
ok('Pesquisa encontra trecho e linha', () => {
  escrever('Jarvis/alvo.txt', 'linha um\nmarcador ZZBUSCA\n');
  const r = arq.pesquisar('ZZBUSCA', '~/Jarvis');
  assert.ok(r.achados.length >= 1, 'nenhum achado');
  assert.ok(r.achados[0].caminho.endsWith('alvo.txt'), r.achados[0].caminho);
  assert.strictEqual(r.achados[0].linha, 2);
});

// ---------- Organização: plano antes de mover ----------
ok('Organizar sem aplicar não move nada', () => {
  const antes = fs.readdirSync(path.join(raiz, 'Jarvis')).length;
  const r = arq.organizar({ pasta: '~/Jarvis' });
  assert.ok(r.mover > 0);
  assert.strictEqual(fs.readdirSync(path.join(raiz, 'Jarvis')).length, antes);
  assert.strictEqual(r.aplicado, false);
});
ok('Organizar aplicado move para subpasta por tipo', () => {
  const r = arq.organizar({ pasta: '~/Jarvis', aplicar: true });
  assert.strictEqual(r.aplicado, true);
  // A pasta segue a EXTENSÃO (.txt → documentos), não o conteúdo detectado.
  assert.ok(fs.existsSync(path.join(raiz, 'Jarvis', 'documentos', 'disfarcado.txt')));
  assert.ok(fs.existsSync(path.join(raiz, 'Jarvis', 'documentos')));
});

// ---------- Segurança de caminho ----------
ok('Recusa caminho fora da pasta do usuário', () => {
  assert.throws(() => arq.listar('/etc'), /fora da pasta do usuário/i);
  assert.throws(() => arq.listar('~/../../etc'), /fora da pasta do usuário/i);
  assert.throws(() => arq.salvar({ caminho: '/tmp/fora.txt', texto: 'x' }), /fora da pasta do usuário/i);
});
ok('Recusa apagar sem lixeira do sistema', () => {
  assert.throws(() => arq.apagar('~/Jarvis/nota.md'), /lixeira/i);
  assert.ok(fs.existsSync(path.join(raiz, 'Jarvis', 'nota.md')) || fs.existsSync(path.join(raiz, 'Jarvis', 'documentos', 'nota.md')));
});
ok('Binário desconhecido não é tratado como texto', () => {
  fs.writeFileSync(path.join(raiz, 'Jarvis', 'blob.bin'), Buffer.from([0, 1, 2, 3, 250, 251, 252, 0, 5, 6, 7]));
  const r = arq.ler('~/Jarvis/blob.bin');
  assert.strictEqual(r.binario, true);
  assert.strictEqual(r.texto, undefined);
});
ok('Nova pasta e recusa de duplicata', () => {
  const r = arq.criarPasta({ pasta: '~/Jarvis', nome: 'Projetos' });
  assert.ok(r.caminho.endsWith('Projetos'));
  assert.throws(() => arq.criarPasta({ pasta: '~/Jarvis', nome: 'Projetos' }), /Já existe/);
});

fs.rmSync(tmp, { recursive: true, force: true });
if (falhas) { console.log('\n' + falhas + ' verificação(ões) do motor de arquivos falharam.'); process.exit(1); }
console.log('\nMotor de arquivos do desktop validado.');
