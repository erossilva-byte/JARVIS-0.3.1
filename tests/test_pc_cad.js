// Teste de comportamento do CAD do desktop: identificação por assinatura, geometria
// para o visualizador, criação, versão nova e exportação validada por reabertura.
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const CADPC = require('../platforms/desktop/cad_pc.js');

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'jv-cad-'));
const raiz = path.join(tmp, 'home');
fs.mkdirSync(path.join(raiz, 'Jarvis'), { recursive: true });
const cad = CADPC.criarCad({ raiz });

let falhas = 0;
function ok(nome, fn) {
  try { fn(); console.log('OK: ' + nome); }
  catch (e) { falhas++; console.log('FALHA: ' + nome + ' -> ' + e.message); }
}
function bytes(rel) { return fs.readFileSync(path.join(raiz, 'Jarvis', rel)); }

let peca = '';
ok('Cria .cad com validação por reabertura', () => {
  const r = cad.criar({
    nome: 'peca', pasta: '~/Jarvis', unidades: 'mm',
    objetos: [
      { tipo: 'caixa', nome: 'base', posicao: [0, 0, 0], dimensoes: [100, 60, 20] },
      { tipo: 'cilindro', nome: 'pino', posicao: [0, 0, 25], raio: 6, altura: 30 }
    ]
  });
  assert.ok(fs.existsSync(r.arquivo));
  assert.strictEqual(r.nome, 'peca.cad');
  assert.strictEqual(r.objetos, 2);
  assert.ok(/reaberto/i.test(r.validacao));
  peca = r.arquivo;
});

ok('Abrir .cad devolve malha para o visualizador 3D', () => {
  const r = cad.abrir(peca);
  assert.strictEqual(r.ok, true);
  assert.strictEqual(r.formato, 'cad');
  assert.strictEqual(r.geometria.tipo, '3d');
  assert.ok(r.geometria.triangulos.length >= 20, 'triângulos: ' + r.geometria.triangulos.length);
  assert.strictEqual(r.propriedades.objetos, 2);
  assert.strictEqual(r.propriedades.unidades, 'mm');
});

ok('Exportar STL binário produz malha fechada', () => {
  const r = cad.exportar({ caminho: peca, formato: 'stl' });
  assert.ok(fs.existsSync(r.arquivo));
  assert.ok(bytes('peca.stl').length > 84);
  assert.strictEqual(r.validacao.ok, true);
  assert.strictEqual(r.validacao.fechada, true);
  const stl = cad.abrir(r.arquivo);
  assert.strictEqual(stl.ok, true);
  assert.strictEqual(stl.geometria.tipo, '3d');
});

ok('Exportar DXF gera geometria 2D com camadas', () => {
  const r = cad.exportar({ caminho: peca, formato: 'dxf' });
  const dxf = cad.abrir(r.arquivo);
  assert.strictEqual(dxf.ok, true, dxf.erro);
  assert.strictEqual(dxf.geometria.tipo, '2d');
  assert.ok(dxf.geometria.segmentos.length > 10);
  assert.ok(dxf.geometria.camadas.length >= 2, 'camadas: ' + dxf.geometria.camadas.join(','));
  // O exportador do núcleo declara camadas por objeto na tabela, mas desenha as faces
  // 3D todas em JARVIS-3D — o teste confere o que está de fato nas entidades.
  assert.ok(dxf.geometria.camadas.includes('JARVIS-3D'), dxf.geometria.camadas.join(','));
});

ok('Exportar STEP e IFC gera arquivos válidos e reabríveis', () => {
  const step = cad.exportar({ caminho: peca, formato: 'step' });
  assert.ok(/ISO-10303-21/.test(bytes('peca.step').toString('utf8')));
  const stepLido = cad.abrir(step.arquivo);
  assert.strictEqual(stepLido.ok, true, stepLido.erro);
  assert.ok(stepLido.propriedades.entidades > 0);

  const ifc = cad.exportar({ caminho: peca, formato: 'ifc' });
  const ifcLido = cad.abrir(ifc.arquivo);
  assert.strictEqual(ifcLido.ok, true, ifcLido.erro);
  assert.ok(ifcLido.propriedades.elementos.length > 0);
});

ok('Índice de formato é honesto sobre o que não abre', () => {
  fs.writeFileSync(path.join(raiz, 'Jarvis', 'desenho.dwg'), Buffer.concat([Buffer.from('AC1027'), Buffer.alloc(200)]));
  const info = cad.identificar('~/Jarvis/desenho.dwg');
  assert.strictEqual(info.formato, 'dwg');
  assert.strictEqual(info.aberto, false);
  assert.ok(/propriet/i.test(info.obs));
  const r = cad.abrir('~/Jarvis/desenho.dwg');
  assert.strictEqual(r.ok, false);
  assert.ok(/não é legível/i.test(r.erro));
});

ok('FCStd desconhecido não é lido como CAD', () => {
  fs.writeFileSync(path.join(raiz, 'Jarvis', 'projeto.fcstd'), Buffer.concat([Buffer.from('PK\u0003\u0004'), Buffer.alloc(120)]));
  const info = cad.identificar('~/Jarvis/projeto.fcstd');
  const r = cad.abrir('~/Jarvis/projeto.fcstd');
  assert.strictEqual(r.ok, false);
  assert.ok(/não é legível|não é um formato CAD/i.test(r.erro));
});

ok('Alterar dimensões cria versão nova e preserva o original', () => {
  const antes = fs.readFileSync(peca, 'utf8');
  const r = cad.modificar({ caminho: peca, edicoes: [{ indice: 0, dimensoes: [120, 60, 20] }] });
  assert.notStrictEqual(r.arquivo, peca);
  assert.strictEqual(r.nome, 'peca-v2.cad');
  assert.strictEqual(fs.readFileSync(peca, 'utf8'), antes, 'o original não pode mudar');
  const v2 = cad.abrir(r.arquivo);
  assert.strictEqual(v2.ok, true);
  assert.deepStrictEqual(v2.propriedades.objetosDetalhe[0].dimensoes, [120, 60, 20]);
});

ok('Edição inválida é recusada sem tocar no arquivo', () => {
  const antes = fs.readFileSync(peca, 'utf8');
  assert.throws(() => cad.modificar({ caminho: peca, edicoes: [{ indice: 99, dimensoes: [10, 10, 10] }] }), /não existe/i);
  assert.throws(() => cad.modificar({ caminho: peca, edicoes: [{ indice: 0, dimensoes: [0, 10, 10] }] }), /maiores que zero/i);
  assert.strictEqual(fs.readFileSync(peca, 'utf8'), antes);
});

ok('Exportar a partir de STL é recusado com explicação', () => {
  assert.throws(() => cad.exportar({ caminho: '~/Jarvis/peca.stl', formato: 'dxf' }), /parte de um \.cad/i);
});

ok('Matriz de formatos marca o que cada um faz no PC', () => {
  const lista = cad.formatos();
  const porId = {};
  lista.forEach((f) => { porId[f.id] = f; });
  assert.ok(/abre, visualiza, cria, edita/.test(porId.cad.desktop));
  assert.ok(/recusa/.test(porId.dwg.desktop));
  assert.strictEqual(porId.step.le, true);
  assert.ok(/sem visualização/.test(porId.step.desktop), porId.step.desktop);
});

ok('Recusa caminho fora da pasta do usuário', () => {
  assert.throws(() => cad.abrir('/etc/hosts'), /fora da pasta do usuário/i);
});

fs.rmSync(tmp, { recursive: true, force: true });
if (falhas) { console.log('\n' + falhas + ' verificação(ões) do CAD do desktop falharam.'); process.exit(1); }
console.log('\nCAD do desktop validado.');
