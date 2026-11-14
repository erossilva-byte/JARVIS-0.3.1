'use strict';
/* Autorização do modo de desenvolvimento (Fase 3).
 *
 * Teste de comportamento com loja e relógio falsos: nada de espera real, nada de mock de
 * rede. As últimas verificações são estáticas e existem para garantir que o app usa a porta
 * — um módulo correto que ninguém chama não protege nada.
 */
const fs = require('node:fs');
const assert = require('node:assert/strict');
const M = require('../modo_dev.js');

let ok = 0;
function ver(nome, fn) { fn(); ok++; }

function relogioFalso(inicio) {
  let t = inicio || 0;
  const f = () => t;
  f.avancar = (ms) => { t += ms; };
  return f;
}

function bancada() {
  const dados = {};
  const agora = relogioFalso(1000);
  const store = {
    get: (k, d) => (Object.prototype.hasOwnProperty.call(dados, k) ? dados[k] : d),
    set: (k, v) => { dados[k] = String(v); }
  };
  const mod = M.criar({ store, agora });
  return { mod, store, agora, dados };
}

/* ---------- Porta fechada por padrão ---------- */

ver('começa desligado', () => {
  const { mod } = bancada();
  const e = mod.estado();
  assert.equal(e.ativo, false);
  assert.equal(e.restanteMs, 0);
});

ver('escrita é negada com o modo desligado', () => {
  const { mod } = bancada();
  const d = mod.autorizar('corrigir');
  assert.equal(d.ok, false);
  assert.equal(d.classe, 'escrita');
  assert.match(d.motivo, /desligado ou expirado/);
});

ver('leitura é sempre livre', () => {
  const { mod } = bancada();
  ['analisar', 'testar', 'exportar', 'listar'].forEach((op) => {
    const d = mod.autorizar(op);
    assert.equal(d.ok, true, op + ' deveria ser livre');
    assert.equal(d.classe, 'leitura');
  });
});

ver('operação desconhecida é negada', () => {
  const { mod } = bancada();
  const d = mod.autorizar('apagar_tudo');
  assert.equal(d.ok, false);
  assert.equal(d.classe, 'desconhecida');
});

ver('negativa fica registrada no histórico', () => {
  const { mod } = bancada();
  mod.verificar('corrigir', 'app.js');
  const h = mod.historico(5);
  assert.equal(h.length, 1);
  assert.equal(h[0].permitido, false);
  assert.equal(h[0].operacao, 'corrigir');
  assert.match(h[0].detalhe, /app\.js/);
});

/* ---------- Autorização com prazo ---------- */

ver('ligar abre a escrita e devolve o prazo', () => {
  const { mod } = bancada();
  const e = mod.ligar(30);
  assert.equal(e.ativo, true);
  assert.ok(e.restanteMs > 29 * 60000 && e.restanteMs <= 30 * 60000);
  assert.equal(mod.autorizar('corrigir').ok, true);
  assert.equal(mod.autorizar('criar').ok, true);
  assert.equal(mod.autorizar('editar').ok, true);
});

ver('autorização expira sozinha', () => {
  const { mod, agora } = bancada();
  mod.ligar(10);
  agora.avancar(9 * 60000);
  assert.equal(mod.autorizar('corrigir').ok, true, 'aos 9 minutos ainda vale');
  agora.avancar(2 * 60000);
  assert.equal(mod.autorizar('corrigir').ok, false, 'aos 11 minutos já expirou');
  assert.equal(mod.estado().ativo, false);
});

ver('desligar encerra na hora', () => {
  const { mod } = bancada();
  mod.ligar(30);
  mod.desligar();
  assert.equal(mod.estado().ativo, false);
  assert.equal(mod.autorizar('criar').ok, false);
});

ver('prazo é limitado entre 5 e 240 minutos', () => {
  const { mod } = bancada();
  assert.equal(mod.ligar(1).minutos, 5);
  assert.equal(mod.ligar(9999).minutos, 240);
  assert.equal(mod.ligar('abc').minutos, 30);
});

ver('autorização sobrevive a recarregar o módulo com a mesma loja', () => {
  const { mod, store, agora } = bancada();
  mod.ligar(20);
  const outro = M.criar({ store, agora });
  assert.equal(outro.estado().ativo, true);
  assert.equal(outro.autorizar('corrigir').ok, true);
});

ver('histórico é limitado e o mais novo vem primeiro', () => {
  const { mod } = bancada();
  for (let i = 0; i < 50; i++) mod.verificar('analisar', 'passo ' + i);
  const h = mod.historico(100);
  assert.equal(h.length, 40);
  assert.match(h[0].detalhe, /passo 49/);
});

ver('permitido é registrado como permitido', () => {
  const { mod } = bancada();
  mod.ligar(30);
  mod.verificar('corrigir', 'hermes.js');
  const h = mod.historico(1);
  assert.equal(h[0].permitido, true);
});

/* ---------- Código do próprio app ---------- */

ver('reconhece os arquivos do próprio app', () => {
  ['app.js', 'index.html', 'hermes.js', 'agentes.js', 'package.json', 'nucleo_v3.css', 'consumo_ia.js']
    .forEach((n) => assert.equal(M.ehCodigoDoProjeto(n), true, n));
  assert.equal(M.ehCodigoDoProjeto('C:\\Jarvis\\app.js'), true);
  assert.equal(M.ehCodigoDoProjeto('/tmp/tests/test_agentes.js'), true);
});

ver('não confunde documento do usuário com código do app', () => {
  ['notas.md', 'relatorio.txt', 'fotos/imagem.jpg', 'src/main.py', 'planilha.csv', 'test_agentes.js']
    .forEach((n) => assert.equal(M.ehCodigoDoProjeto(n), false, n));
  assert.equal(M.ehCodigoDoProjeto(''), false);
  assert.equal(M.ehCodigoDoProjeto(null), false);
});

/* ---------- O app usa a porta ---------- */

ver('o painel de desenvolvimento abre com a autorização', () => {
  const html = fs.readFileSync('index.html', 'utf8');
  assert.match(html, /id="dev-autorizar"/, 'falta o botão de autorizar');
  assert.match(html, /id="dev-revogar"/, 'falta o botão de encerrar');
  assert.match(html, /id="dev-modo-status"/, 'falta o estado do modo');
  assert.match(html, /<script src="modo_dev\.js"><\/script>/, 'o módulo precisa ser carregado');
});

ver('as operações que alteram arquivos passam pela autorização', () => {
  const app = fs.readFileSync('app.js', 'utf8');
  assert.match(app, /window\.ModoDev\.criar\(\{ store \}\)/, 'precisa criar a instância com a loja');
  assert.match(app, /function devAutorizado\(operacao, detalhe\)/, 'precisa da porta única');
  assert.match(app, /if \(!devAutorizado\('corrigir'/, 'corrigir precisa de autorização');
  assert.match(app, /if \(!devAutorizado\('criar', 'projeto'\)\.ok\) return;/, 'criar projeto precisa de autorização');
  assert.match(app, /if \(!devAutorizado\('criar', 'arquivo'\)\.ok\) return;/, 'criar arquivo precisa de autorização');
  assert.match(app, /MODO_DEV\.verificar\('editar', alvoCaminho\)/, 'editar código do app precisa de autorização');
  assert.match(app, /Editar o código do próprio app exige autorizar/, 'a recusa precisa ser explicada');
});

ver('o aviso de correção não é apagado pela análise refeita', () => {
  const app = fs.readFileSync('app.js', 'utf8');
  assert.match(app, /const avisoCorrecao = alterados \+ ' arquivo\(s\) corrigido\(s\)/);
  const bloco = app.slice(app.indexOf('function devCorrigir'), app.indexOf('function devProjeto'));
  assert.ok(bloco.indexOf('devStatus(avisoCorrecao)') > bloco.indexOf('devAnalisar();'),
    'a mensagem de correção precisa ser reescrita depois da análise');
});

ver('o módulo entra no pacote e na suíte', () => {
  const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
  assert.ok(pkg.build.files.includes('modo_dev.js'), 'build.files precisa incluir modo_dev.js');
  assert.match(pkg.scripts['test:all'], /node --check modo_dev\.js/);
  assert.match(pkg.scripts['test:all'], /node tests\/test_modo_dev\.js/);
});

console.log('Modo de desenvolvimento: ' + ok + ' verificações aprovadas.');
