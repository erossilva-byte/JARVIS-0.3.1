/* Projetista elétrico na interface, com o app inteiro no jsdom:
 * pede o circuito, confere o desenho, a verificação, o relatório, o ladder e o projeto salvo.
 */
'use strict';
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { JSDOM, VirtualConsole } = require('jsdom');

(async () => {
  const raiz = path.resolve(__dirname, '..');
  const html = fs.readFileSync(path.join(raiz, 'index.html'), 'utf8')
    .replace(/<script\b(?![^>]*\bsrc=)[^>]*>[\s\S]*?<\/script>/gi, '');
  const vc = new VirtualConsole();
  vc.on('jsdomError', () => {});
  const dom = new JSDOM(html, { url: 'http://localhost/', runScripts: 'outside-only', pretendToBeVisual: true, virtualConsole: vc });
  const w = dom.window;
  const d = w.document;
  w.matchMedia = w.matchMedia || (() => ({ matches: false, addListener() {}, removeListener() {}, addEventListener() {}, removeEventListener() {} }));
  w.scrollTo = () => {};
  w.alert = () => {};
  w.confirm = () => true;
  w.prompt = () => null;
  w.open = () => null;
  w.HTMLCanvasElement.prototype.getContext = function () {
    return new Proxy({}, { get: (t, k) => (k === 'measureText' ? () => ({ width: 10 }) : () => undefined), set: () => true });
  };
  const tags = [...html.matchAll(/<script\b[^>]*src="([^"]+)"[^>]*>/g)].map((m) => m[1]);
  for (const src of tags) w.eval(fs.readFileSync(path.join(raiz, src), 'utf8'));
  d.dispatchEvent(new w.Event('DOMContentLoaded', { bubbles: true }));
  const dormir = (ms) => new Promise((r) => setTimeout(r, ms));
  await dormir(2500);

  assert.ok(w.ProjetistaEletrico, 'o módulo do projetista deve carregar com o aplicativo');
  assert.ok(d.getElementById('proj-pedido'), 'a área do projetista deve existir no painel Arquivos');
  const campo = d.getElementById('proj-pedido');
  assert.ok(/partida direta/i.test(campo.value), 'o pedido de exemplo deve estar preenchido');

  // Criar o projeto de partida direta
  d.getElementById('proj-criar').click();
  await dormir(150);
  const statusInicial = d.getElementById('proj-status').textContent;
  assert.ok(/aprovado na verificação estrutural/.test(statusInicial), 'criar deve confirmar a verificação: ' + statusInicial);
  assert.ok(d.querySelectorAll('#proj-palco .proj-cartao').length >= 5, 'a vista deve desenhar os componentes: ' + d.querySelectorAll('#proj-palco .proj-cartao').length);
  assert.ok(d.querySelectorAll('#proj-palco .proj-fio').length >= 5, 'a vista deve desenhar os fios: ' + d.querySelectorAll('#proj-palco .proj-fio').length);
  const saida = d.getElementById('proj-saida').value;
  assert.ok(/PROJETO: Partida direta/.test(saida), 'a saída deve começar pelo projeto: ' + saida.slice(0, 120));
  assert.ok(/CADeSIMU: não aberto/.test(saida), 'a saída deve declarar que o CADeSIMU não foi aberto');
  assert.ok(/Simulação funcional: não executada/.test(saida), 'a saída deve declarar que não houve simulação');
  assert.ok(/Sequência de operação/.test(saida), 'a saída deve trazer a sequência de operação');
  assert.ok(d.querySelectorAll('#proj-lista .mem-nota').length >= 5, 'a lista deve mostrar os componentes');
  assert.ok(/Verificação estrutural: aprovado/.test(d.getElementById('proj-lista').textContent), 'a lista deve resumir a verificação');

  // Relatório e análise
  d.getElementById('proj-relatorio').click();
  await dormir(80);
  assert.ok(/RELATÓRIO TÉCNICO/.test(d.getElementById('proj-saida').value), 'o relatório deve ser gerado');
  assert.ok(/CADeSIMU: não aberto/.test(d.getElementById('proj-saida').value), 'o relatório deve declarar a limitação do CADeSIMU');
  d.getElementById('proj-analisar').click();
  await dormir(80);
  assert.ok(/Verificação estrutural: aprovado/.test(d.getElementById('proj-saida').value), 'analisar deve revalidar o projeto');

  // Corrigir num projeto já válido não inventa correção
  d.getElementById('proj-corrigir').click();
  await dormir(80);
  assert.ok(/Nenhuma correção necessária/.test(d.getElementById('proj-status').textContent), 'sem erro, a correção deve dizer que nada mudou: ' + d.getElementById('proj-status').textContent);

  // Salvar e listar
  d.getElementById('proj-salvar').click();
  await dormir(120);
  assert.ok(/Projeto salvo como/.test(d.getElementById('proj-status').textContent), 'salvar deve confirmar: ' + d.getElementById('proj-status').textContent);
  assert.ok(/partida_direta/.test(d.getElementById('proj-arquivos').textContent), 'o projeto salvo deve aparecer na lista');

  // Ladder de um projeto sem CLP é recusado com explicação
  d.getElementById('proj-ladder').click();
  await dormir(80);
  assert.ok(/não tem lógica de CLP/.test(d.getElementById('proj-saida').value), 'ladder sem CLP deve explicar a ausência');

  // Projeto com CLP: cria, valida e entrega ladder com endereços
  campo.value = 'Crie um sistema de controle de nível de água usando CLP, sensores e bomba.';
  d.getElementById('proj-criar').click();
  await dormir(150);
  assert.ok(/aprovado na verificação estrutural/.test(d.getElementById('proj-status').textContent), 'CLP deve ser aprovado: ' + d.getElementById('proj-status').textContent);
  d.getElementById('proj-ladder').click();
  await dormir(80);
  const ladder = d.getElementById('proj-saida').value;
  assert.ok(/%Q0\.0/.test(ladder) && /TABELA DE ENTRADAS\/SAÍDAS/.test(ladder), 'o ladder deve trazer saída e tabela de I/O: ' + ladder.slice(0, 200));

  // O projeto salvo reabre pela lista
  const abrir = d.querySelector('#proj-arquivos button');
  assert.ok(abrir, 'o projeto salvo deve ter botão Abrir');
  abrir.click();
  await dormir(100);
  assert.ok(/aberto/.test(d.getElementById('proj-status').textContent), 'abrir deve confirmar: ' + d.getElementById('proj-status').textContent);

  // Modificação, comparação, histórico e restauração
  d.getElementById('proj-mod').value = 'adicionar temporizador de 10 segundos';
  d.getElementById('proj-modificar').click();
  await dormir(150);
  assert.ok(/modificação\(ões\) aplicada/.test(d.getElementById('proj-status').textContent), 'modificar deve confirmar: ' + d.getElementById('proj-status').textContent);
  assert.ok(/Temporizador/.test(d.getElementById('proj-saida').value), 'a saída deve descrever o temporizador inserido');
  assert.ok(/COMPARAÇÃO DE PROJETOS/.test(d.getElementById('proj-saida').value), 'a saída deve trazer a comparação com o original');
  d.getElementById('proj-comparar').click();
  await dormir(80);
  assert.ok(/COMPARAÇÃO DE PROJETOS/.test(d.getElementById('proj-saida').value), 'comparar deve gerar a comparação');
  d.getElementById('proj-salvar').click();
  await dormir(120);
  d.getElementById('proj-versoes').click();
  await dormir(120);
  assert.ok(/Histórico de/.test(d.getElementById('proj-status').textContent), 'versões devem listar o histórico: ' + d.getElementById('proj-status').textContent);
  assert.ok(/VERSÕES DE/.test(d.getElementById('proj-saida').value), 'a saída deve listar as versões');
  const botaoRestaurar = Array.from(d.querySelectorAll('#proj-arquivos button')).find((b) => /Restaurar/.test(b.textContent));
  assert.ok(botaoRestaurar, 'o histórico deve oferecer Restaurar');
  botaoRestaurar.click();
  await dormir(150);
  assert.ok(/restaurada/.test(d.getElementById('proj-status').textContent), 'restaurar deve confirmar: ' + d.getElementById('proj-status').textContent);

  console.log('OK: projetista elétrico na interface — criar, desenhar, analisar, corrigir, relatório, ladder e projeto salvo');
  process.exit(0);
})().catch((e) => { console.error('FALHA: ' + e.message); process.exit(1); });
