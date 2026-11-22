'use strict';
// Comportamento do motor de arquivos DENTRO do app (arquivos_dev.js).
// A validação não confia no próprio módulo: os bytes gerados são lidos de novo por um
// leitor de ZIP escrito aqui, com CRC recalculado aqui, e o CSV é reprocessado por um
// parser independente. Se as duas implementações discordarem, o teste falha.
const assert = require('node:assert/strict');
const path = require('node:path');
const zlib = require('node:zlib');
const A = require(path.join(__dirname, '..', 'arquivos_dev.js'));

const falhas = [];
const pendentes = [];
function teste(nome, fn) {
  try { fn(); console.log('OK: ' + nome); }
  catch (e) { falhas.push(nome); console.log('FALHA: ' + nome + ' -> ' + e.message); }
}
function testeAsync(nome, fn) { pendentes.push({ nome, fn }); }

/* ---------- leitor de ZIP independente (não usa o do módulo) ---------- */
function crc32Proprio(buf) {
  let c = ~0;
  for (let i = 0; i < buf.length; i++) {
    c ^= buf[i];
    for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (0xEDB88320 & -(c & 1));
  }
  return (~c) >>> 0;
}
function lerZip(bytes) {
  const b = Buffer.from(bytes);
  let eocd = -1;
  for (let i = b.length - 22; i >= 0 && i >= b.length - 65558; i--) {
    if (b.readUInt32LE(i) === 0x06054b50) { eocd = i; break; }
  }
  assert.ok(eocd >= 0, 'o arquivo tem diretório central (EOCD)');
  const total = b.readUInt16LE(eocd + 10);
  let p = b.readUInt32LE(eocd + 16);
  const entradas = [];
  for (let n = 0; n < total; n++) {
    assert.equal(b.readUInt32LE(p), 0x02014b50, 'cabeçalho central ' + n);
    const metodo = b.readUInt16LE(p + 10);
    const crc = b.readUInt32LE(p + 16);
    const tam = b.readUInt32LE(p + 24);
    const tamNome = b.readUInt16LE(p + 28);
    const off = b.readUInt32LE(p + 42);
    const nome = b.slice(p + 46, p + 46 + tamNome).toString('utf8');
    assert.equal(b.readUInt32LE(off), 0x04034b50, 'cabeçalho local de ' + nome);
    const inicio = off + 30 + b.readUInt16LE(off + 26) + b.readUInt16LE(off + 28);
    const bruto = b.slice(inicio, inicio + tam);
    const dados = metodo === 8 ? zlib.inflateRawSync(bruto) : bruto;
    assert.equal(dados.length, tam, 'tamanho declarado de ' + nome);
    assert.equal(crc32Proprio(dados), crc, 'CRC de ' + nome);
    entradas.push({ nome, texto: dados.toString('utf8') });
    p += 46 + tamNome + b.readUInt16LE(p + 30) + b.readUInt16LE(p + 32);
  }
  return entradas;
}

/* ---------- parser de CSV independente ---------- */
function lerCsv(texto) {
  const sep = texto.split('\n')[0].includes(';') ? ';' : ',';
  const linhas = [];
  let campo = '', linha = [], dentro = false;
  for (let i = 0; i < texto.length; i++) {
    const c = texto[i];
    if (dentro) {
      if (c === '"' && texto[i + 1] === '"') { campo += '"'; i++; }
      else if (c === '"') dentro = false;
      else campo += c;
      continue;
    }
    if (c === '"') { dentro = true; continue; }
    if (c === sep) { linha.push(campo); campo = ''; continue; }
    if (c === '\n') { linha.push(campo); linhas.push(linha); linha = []; campo = ''; continue; }
    campo += c;
  }
  if (campo || linha.length) { linha.push(campo); linhas.push(linha); }
  return linhas;
}

/* ---------- PDF ---------- */
teste('PDF tem cabeçalho, páginas contadas e fim de arquivo', () => {
  const r = A.criar('pdf', 'relatorio', 'Parágrafo um com acento ção.\nParágrafo dois.\nParágrafo três.');
  const b = Buffer.from(r.bytes);
  assert.equal(b.slice(0, 8).toString('latin1'), '%PDF-1.4', 'assinatura PDF');
  assert.match(b.toString('latin1'), /%%EOF\s*$/, 'termina com %%EOF');
  const paginas = (b.toString('latin1').match(/\/Type \/Page[^s]/g) || []).length;
  assert.ok(paginas >= 1, 'pelo menos uma página declarada');
  const xref = b.toString('latin1').lastIndexOf('xref');
  assert.ok(xref > 0, 'tem tabela xref');
  assert.equal(r.texto, '', 'binário não devolve texto editável');
});

/* ---------- DOCX ---------- */
teste('DOCX é ZIP válido com as partes do Word e o texto preservado', () => {
  const texto = 'Título com acento\nSegunda linha com <tags> e & símbolo';
  const r = A.criar('docx', 'documento', texto);
  const entradas = lerZip(r.bytes);
  const nomes = entradas.map((e) => e.nome);
  assert.ok(nomes.includes('[Content_Types].xml'), 'tem [Content_Types].xml');
  assert.ok(nomes.includes('_rels/.rels'), 'tem _rels/.rels');
  assert.ok(nomes.includes('word/document.xml'), 'tem word/document.xml');
  const doc = entradas.find((e) => e.nome === 'word/document.xml').texto;
  assert.match(doc, /<w:document/, 'documento do Word');
  assert.match(doc, /Título com acento/, 'texto preservado');
  assert.match(doc, /&lt;tags&gt;/, 'texto escapado no XML');
  assert.match(doc, /&amp;/, 'e comercial escapado');
});

/* ---------- XLSX ---------- */
teste('XLSX é ZIP válido com planilha, aba nomeada e células com escape', () => {
  const r = A.criar('xlsx', 'planilha', 'nome;idade\nAna & Bia;30\n<João>;25', { aba: 'Dados & Cia' });
  const entradas = lerZip(r.bytes);
  const nomes = entradas.map((e) => e.nome);
  assert.ok(nomes.includes('xl/workbook.xml'), 'tem xl/workbook.xml');
  assert.ok(nomes.includes('xl/worksheets/sheet1.xml'), 'tem a folha 1');
  const wb = entradas.find((e) => e.nome === 'xl/workbook.xml').texto;
  assert.match(wb, /Dados &amp; Cia/, 'nome da aba escapado');
  const folha = entradas.find((e) => e.nome === 'xl/worksheets/sheet1.xml').texto;
  assert.match(folha, /<row r="1">/, 'primeira linha');
  assert.match(folha, /<c r="A1"/, 'célula A1');
  assert.match(folha, /Ana &amp; Bia/, 'valor com escape');
  assert.match(folha, /&lt;João&gt;/, 'menor e maior escapados');
  const colunas = (folha.match(/r="[A-Z]+1"/g) || []).map((x) => x.replace(/r="|"/g, ''));
  assert.deepEqual(colunas, ['A1', 'B1'], 'duas colunas na primeira linha');
});

/* ---------- CSV ---------- */
teste('CSV de JSON sobrevive a separador, aspas e quebra de linha', () => {
  const dados = [
    { nome: 'Silva, João', obs: 'disse "oi"', detalhe: 'linha1\nlinha2' },
    { nome: 'Ana; Paula', obs: '', detalhe: 'simples' }
  ];
  const csv = A.csvDeJson(JSON.stringify(dados));
  assert.ok(csv, 'converteu');
  const linhas = lerCsv(csv);
  assert.deepEqual(linhas[0], ['nome', 'obs', 'detalhe'], 'cabeçalho com as colunas');
  assert.deepEqual(linhas[1], ['Silva, João', 'disse "oi"', 'linha1\nlinha2'], 'aspas e vírgula preservadas');
  assert.deepEqual(linhas[2], ['Ana; Paula', '', 'simples'], 'ponto e vírgula dentro do campo não parte a linha');
});

teste('criar csv a partir de JSON usa o conversor', () => {
  const r = A.criar('csv', 'tabela', JSON.stringify([{ a: 1, b: 'x;y' }]));
  assert.equal(r.texto, 'a;b\n1;"x;y"\n', 'texto final é o CSV');
  assert.ok(Buffer.from(r.bytes).toString('utf8').startsWith('a;b'), 'bytes iguais ao texto');
});

/* ---------- TXT / JSON ---------- */
teste('JSON inválido é recusado em vez de gerar arquivo quebrado', () => {
  assert.throws(() => A.criar('json', 'dados', '{quebrado'), /JSON inválido/, 'recusa JSON quebrado');
  const ok = A.criar('json', 'dados', '{"a":1}');
  assert.equal(ok.texto, '{"a":1}', 'JSON válido passa');
});

/* ---------- ZIP (assíncronos: rodam depois dos síncronos) ---------- */
testeAsync('ZIP do motor abre de volta com acento no nome e no conteúdo', async () => {
  const z = A.zip([
    { nome: 'ação.txt', texto: 'conteúdo ção' },
    { nome: 'b/nota.md', texto: '# Título' }
  ]);
  assert.ok(lerZip(z).length === 2, 'o ZIP gerado também abre no leitor independente');
  const lido = await A.descompactar(z);
  assert.equal(lido.length, 2, 'duas entradas');
  const porNome = {};
  lido.forEach((e) => { porNome[e.nome] = A.textoDeBytes(e.bytes); });
  assert.equal(porNome['ação.txt'], 'conteúdo ção', 'nome e conteúdo com acento');
  assert.equal(porNome['b/nota.md'], '# Título', 'caminho interno preservado');
});

testeAsync('ZIP truncado é recusado em vez de devolver lixo', async () => {
  const z = A.zip([{ nome: 'a.txt', texto: 'x' }]);
  await assert.rejects(() => A.descompactar(z.slice(0, z.length - 10)), /ZIP/, 'recusa sem EOCD');
});

/* ---------- Nomes e instruções ---------- */
teste('nomeSeguro não deixa subir pasta nem quebrar o nome', () => {
  assert.ok(!A.nomeSeguro('../../etc/passwd', '.txt').includes('/'), 'sem barra');
  assert.ok(!A.nomeSeguro('a\\b:c*d?e"f<g>h|i', '.txt').match(/[\\/:*?"<>|]/), 'sem caractere proibido');
  assert.equal(A.nomeSeguro('', 'txt'), 'arquivo.txt', 'nome vazio recebe padrão');
  assert.ok(A.nomeSeguro('sem-extensao', 'md').endsWith('.md'), 'extensão acrescentada');
  assert.ok(A.nomeSeguro('já-tem.md', 'txt').endsWith('.md'), 'não duplica extensão');
});

teste('instrucao separa ação, alvo e formato do pedido', () => {
  const r = A.instrucao('crie um pdf chamado relatorio a partir de nota.txt', [{ nome: 'nota.txt' }]);
  assert.equal(r.acao, 'criar', 'ação criar');
  assert.equal(r.formato, 'pdf', 'formato pdf');
  assert.equal(r.alvo, 'nota.txt', 'alvo é o arquivo citado');
  const z = A.instrucao('compacte todos os arquivos', [{ nome: 'a.txt' }]);
  assert.equal(z.acao, 'zip', 'compactação reconhecida');
  assert.equal(z.alvo, 'todos', 'todos os arquivos');
  const v = A.instrucao('verifique o arquivo b.md', [{ nome: 'a.txt' }, { nome: 'b.md' }]);
  assert.equal(v.acao, 'analisar', 'verificação vira análise');
  assert.equal(v.alvo, 'b.md', 'alvo correto');
});

(async () => {
  for (const { nome, fn } of pendentes) {
    try { await fn(); console.log('OK: ' + nome); }
    catch (e) { falhas.push(nome); console.log('FALHA: ' + nome + ' -> ' + e.message); }
  }
  console.log(falhas.length ? 'test_arquivos_dev: ' + falhas.length + ' falha(s)' : 'Motor de arquivos do app validado.');
  process.exit(falhas.length ? 1 : 0);
})();
