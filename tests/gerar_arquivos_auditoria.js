'use strict';
// Gera arquivos REAIS pelo motor do desktop e devolve os fatos em JSON.
// Quem valida a estrutura é o teste em Python (zipfile, csv, json, ElementTree),
// não este mesmo código: duas implementações olhando o mesmo arquivo.
const fs = require('fs');
const path = require('path');
const ARQ = require('../platforms/desktop/arquivos.js');

const destino = process.argv[2];
if (!destino) { console.error('uso: node tests/gerar_arquivos_auditoria.js <pasta>'); process.exit(2); }
const raiz = path.join(destino, 'home');
fs.mkdirSync(path.join(raiz, 'Jarvis'), { recursive: true });
const arq = ARQ.criarArquivos({ raiz });
const saida = { raiz: raiz, arquivos: [], extras: {} };

function abs(rel) { return path.join(raiz, String(rel).replace(/^~[\\/]?/, '')); }
function criar(nome, texto) {
  const r = arq.salvar({ caminho: '~/Jarvis/' + nome, texto: texto });
  const l = arq.ler('~/Jarvis/' + nome);
  saida.arquivos.push({ nome: nome, rel: r.relativo, bytes: r.bytes, hash: r.hash, formato: l.formato, tipo: l.tipo, texto: texto });
  return r;
}

criar('nota.txt', 'Linha 1\nLinha 2\n');
criar('nota.md', '# Titulo\n\n- alfa\n- beta\n');
criar('dados.csv', 'nome,idade\nAna,30\nBia,25\n');
criar('dados.json', JSON.stringify([{ nome: 'Ana', idade: '30' }, { nome: 'Bia', idade: '25' }], null, 2));
criar('pagina.html', '<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><title>Teste</title></head><body><h1>Ola</h1></body></html>');
criar('estilo.css', 'body{color:#111;background:#fff}\n');
criar('script.js', 'function soma(a, b) { return a + b; }\nconsole.log(soma(2, 3));\n');
criar('modulo.py', 'def soma(a, b):\n    return a + b\n\nprint(soma(2, 3))\n');
criar('App.java', 'public class App { public static void main(String[] args) { System.out.println("ok"); } }\n');
criar('main.c', '#include <stdio.h>\nint main(void) { printf("ok\\n"); return 0; }\n');
criar('main.cpp', '#include <iostream>\nint main() { std::cout << "ok"; return 0; }\n');
criar('dados.xml', '<?xml version="1.0" encoding="UTF-8"?><raiz><item id="1">alfa</item></raiz>');
criar('documento.rtf', '{\\rtf1\\ansi\\deff0{\\fonttbl{\\f0 Arial;}}\\f0 Ola, senhor.\\par}');
criar('desenho.svg', '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><rect x="10" y="10" width="50" height="50"/></svg>');
criar('relatório ção #1.txt', 'acentos e espaços preservados\n');

// ZIP real (store) com três arquivos, validado depois pelo zipfile do Python.
const zip = arq.compactar({ destino: '~/Jarvis/pacote.zip', arquivos: [
  { caminho: '~/Jarvis/nota.txt' }, { caminho: '~/Jarvis/dados.csv' }, { caminho: '~/Jarvis/pagina.html' }
] });
saida.extras.zip = { rel: zip.relativo, bytes: zip.bytes, hash: zip.hash, entradas: zip.entradas };
saida.extras.verificarZip = arq.verificar('~/Jarvis/pacote.zip');
const bufZip = fs.readFileSync(abs(zip.relativo));
fs.writeFileSync(path.join(raiz, 'Jarvis', 'corrompido.zip'), bufZip.subarray(0, bufZip.length - 80));
saida.extras.verificarCorrompido = arq.verificar('~/Jarvis/corrompido.zip');
fs.writeFileSync(path.join(raiz, 'Jarvis', 'quebrado.json'), '{"a": }');
saida.extras.verificarJson = arq.verificar('~/Jarvis/quebrado.json');

// Conflito: o arquivo muda por fora depois de lido; salvar com o hash antigo deve recusar.
const base = arq.salvar({ caminho: '~/Jarvis/conflito.txt', texto: 'versao A\n' });
fs.writeFileSync(path.join(raiz, 'Jarvis', 'conflito.txt'), 'mudou por fora\n');
try {
  arq.salvar({ caminho: '~/Jarvis/conflito.txt', texto: 'versao B\n', hashEsperado: base.hash });
  saida.extras.conflito = 'NAO BLOQUEOU';
} catch (e) { saida.extras.conflito = e.message; }
saida.extras.conflitoConteudo = fs.readFileSync(path.join(raiz, 'Jarvis', 'conflito.txt'), 'utf8');

// Backup e conteúdo anterior preservados.
const bk = arq.salvar({ caminho: '~/Jarvis/backup.txt', texto: 'versao original\n' });
const bk2 = arq.salvar({ caminho: '~/Jarvis/backup.txt', texto: 'versao nova\n' });
saida.extras.backup = { rel: bk2.backup, existe: fs.existsSync(abs(bk2.backup)), anterior: fs.existsSync(abs(bk2.backup)) ? fs.readFileSync(abs(bk2.backup), 'utf8') : '' };

// Recusas: comparar binário, caminho fora da casa, conteúdo acima de 8 MB.
fs.writeFileSync(path.join(raiz, 'Jarvis', 'pixel.png'), Buffer.from([0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a,0,0,0,13,0x49,0x48,0x44,0x52,0,0,0,10,0,0,0,20,8,2,0,0,0]));
try { arq.comparar('~/Jarvis/pixel.png', '~/Jarvis/nota.txt'); saida.extras.compararBinario = 'ACEITOU'; }
catch (e) { saida.extras.compararBinario = e.message; }
try { arq.listar('/etc'); saida.extras.traversal = 'ACEITOU'; } catch (e) { saida.extras.traversal = e.message; }
try { arq.salvar({ caminho: '~/Jarvis/grande.txt', texto: 'x'.repeat(9 * 1024 * 1024) }); saida.extras.grande = 'ACEITOU'; }
catch (e) { saida.extras.grande = e.message; }

// Temporário órfão antigo é removido; temporário recente não.
const orfao = path.join(raiz, 'Jarvis', 'orfao.txt.tmp-1234-antigo');
fs.writeFileSync(orfao, 'lixo');
const velho = new Date(Date.now() - 48 * 3600 * 1000);
fs.utimesSync(orfao, velho, velho);
saida.extras.limpeza = arq.limparTemporarios('~/Jarvis', 24);

// Nenhum .tmp- deve sobrar depois das gravações.
saida.extras.temporariosRestantes = fs.readdirSync(path.join(raiz, 'Jarvis')).filter(function (n) { return /\.tmp-/.test(n); });
saida.ok = true;
console.log(JSON.stringify(saida));
