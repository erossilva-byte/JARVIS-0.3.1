'use strict';
/* Testes do motor de Desenvolvimento de Arquivos: formatos, análise e correções. */
const zlib = require('zlib');
const A = require('../arquivos_dev.js');

let falhas = 0;
function ok(nome, cond, det) {
  if (cond) console.log('OK: ' + nome);
  else { falhas++; console.log('FALHA: ' + nome + (det ? ' -> ' + det : '')); }
}
function inflate(b) { return zlib.inflateRawSync(Buffer.from(b)); }

ok('lista de formatos inclui os reais', ['pdf', 'docx', 'xlsx', 'zip', 'json', 'csv', 'py'].every((f) => A.formatos().some((x) => x.id === f)));

const docx = A.criar('docx', 'documento', 'Um\nDois');
ok('DOCX é ZIP', docx.bytes[0] === 0x50 && docx.bytes[1] === 0x4b);
const pdf = A.criar('pdf', 'relatorio', 'linha');
ok('PDF tem assinatura', A.textoDeBytes(pdf.bytes.slice(0, 8)).indexOf('%PDF-1.4') === 0);
const xlsx = A.criar('xlsx', 'planilha', 'a;b\n1;2');
ok('XLSX é ZIP', xlsx.bytes[0] === 0x50 && xlsx.bytes[1] === 0x4b);
ok('JSON inválido é recusado ao criar', (() => { try { A.criar('json', 'x', '{quebrado'); return false; } catch (e) { return /JSON inválido/.test(e.message); } })());
ok('CSV converte lista JSON', A.criar('csv', 'd', '[{"a":1,"b":2}]').texto.split('\n')[0] === 'a;b');

let erroZip = false;
try { A.criar('zip', 'p', '', { entradas: [{ nome: 'a.txt', texto: 'a' }] }); } catch (e) { erroZip = true; }
ok('ZIP de projeto é gerado', !erroZip);

(async () => {
  const pacote = A.criar('zip', 'p', '', { entradas: [
    { nome: 'a.txt', texto: 'conteúdo A' },
    { nome: 'dir/b.js', texto: 'const b = 1;' }
  ] });
  const lidos = await A.descompactar(pacote.bytes, inflate);
  ok('ZIP volta com duas entradas', lidos.length === 2, lidos.map((x) => x.nome).join(','));
  ok('ZIP preserva nome com pasta', lidos.some((x) => x.nome === 'dir/b.js'));
  ok('ZIP preserva o conteúdo', A.textoDeBytes(lidos.find((x) => x.nome === 'a.txt').bytes) === 'conteúdo A');
  let recusou = false;
  try { await A.descompactar(new Uint8Array([1, 2, 3]), inflate); } catch (e) { recusou = /ZIP válido/.test(e.message); }
  ok('lixo não é aceito como ZIP', recusou);

  const rel = A.analisar([
    { nome: 'a.json', texto: '{\n  "a": 1,\n}' },
    { nome: 'b.js', texto: "const api_key = 'abcdefgh12345';\nimport x from './nao-existe';\n<<<<<<< HEAD\n{{" },
    { nome: 'c.txt', texto: 'igual' },
    { nome: 'd.txt', texto: 'igual' }
  ]);
  const regras = rel.problemas.map((p) => p.regra);
  ok('detecta JSON inválido', regras.indexOf('json') >= 0);
  ok('detecta segredo no código', regras.indexOf('segredo') >= 0);
  ok('detecta importação ausente', regras.indexOf('importacao') >= 0);
  ok('detecta marcador de conflito', regras.indexOf('conflito') >= 0);
  ok('detecta duplicata', regras.indexOf('duplicado') >= 0);
  ok('detecta desequilíbrio de símbolos', regras.indexOf('equilibrio') >= 0);
  ok('problema aponta arquivo e linha', rel.problemas.every((p) => typeof p.arquivo === 'string') && rel.problemas.some((p) => p.linha === 3));

  ok('corrige JSON válido', JSON.parse(A.corrigir('{"a":1}', 'json').texto).a === 1);
  ok('não altera JSON inválido', A.corrigir('{x', 'json').erro && A.corrigir('{x', 'json').alterado === false);
  ok('normaliza CRLF', A.corrigir('a\r\nb', 'eol').texto === 'a\nb');
  ok('remove BOM', A.corrigir('\uFEFFabc', 'bom').texto === 'abc');
  ok('remove espaços finais', A.corrigir('a   \n\n\n\nb', 'espacos').texto === 'a\n\nb\n');

  const plano = A.instrucao('crie um projeto Python chamado controle-voz', []);
  ok('instrução reconhece criação', plano.acao === 'criar', JSON.stringify(plano));
  ok('instrução reconhece formato Python', plano.formato === 'py', JSON.stringify(plano));
  ok('instrução reconhece nome', plano.nome === 'controle-voz', JSON.stringify(plano));
  ok('instrução reconhece análise', A.instrucao('analise todos os arquivos e encontre conflitos', []).acao === 'analisar');
  ok('instrução reconhece correção', A.instrucao('corrija o JSON', []).acao === 'corrigir');

  ok('nome seguro remove barras', A.nomeSeguro('../x/y', 'txt') === '..-x-y.txt' || A.nomeSeguro('../x/y', 'txt').indexOf('/') < 0);
  ok('impressão é estável', A.impressao('abc') === A.impressao('abc') && A.impressao('abc') !== A.impressao('abd'));

  if (falhas) { console.log('\n' + falhas + ' verificação(ões) do motor de arquivos falharam.'); process.exit(1); }
  console.log('\nDesenvolvimento de arquivos: formatos, ZIP, análise, correções e instruções verificados.');
})();
