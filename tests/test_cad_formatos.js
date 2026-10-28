// Bateria da 1.19.0 — CAD de intercâmbio de verdade.
// Gera cada formato a partir do mesmo documento e devolve, em JSON, os números que o teste
// em Python confere por conta própria (zipfile, struct, XML): duas implementações diferentes
// olhando o mesmo arquivo é o que impede o teste de "concordar com o próprio bug".
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const CAD = require(path.join(__dirname, '..', 'cad.js'));

const destino = process.argv[2];
if (!destino) {
  console.error('uso: node tests/test_cad_formatos.js <pasta>');
  process.exit(2);
}
fs.mkdirSync(destino, { recursive: true });

function doc() {
  return CAD.criar({
    nome: 'peca-teste',
    unidades: 'mm',
    objetos: [
      { tipo: 'caixa', nome: 'base', posicao: [0, 0, 0], dimensoes: [100, 60, 20] },
      { tipo: 'cilindro', nome: 'pino', posicao: [0, 0, 30], raio: 8, altura: 40 },
      { tipo: 'esfera', nome: 'ponta', posicao: [40, 0, 0], raio: 12 },
      { tipo: 'cone', nome: 'bico', posicao: [-40, 0, 0], raio: 10, altura: 30 }
    ]
  });
}

const erros = [];
function conferir(nome, condicao, detalhe) {
  if (!condicao) erros.push(nome + (detalhe ? ': ' + detalhe : ''));
}

// 1. Volumes por primitiva contra a fórmula fechada (tolerância de tesselação inscrita).
const casos = [
  ['caixa', { dimensoes: [100, 60, 20] }, 120000, 0.001],
  ['cilindro', { raio: 8, altura: 40 }, Math.PI * 64 * 40, 0.03],
  ['esfera', { raio: 12 }, (4 / 3) * Math.PI * Math.pow(12, 3), 0.04],
  ['cone', { raio: 10, altura: 30 }, (Math.PI * 100 * 30) / 3, 0.03]
];
const volumes = {};
casos.forEach(([tipo, props, teorico, tolerancia]) => {
  const um = CAD.criar({ nome: tipo, objetos: [Object.assign(CAD.objetoPadrao(tipo), props)] });
  const m = CAD.malha(um);
  const v = CAD.volumeArea(m).volume;
  volumes[tipo] = Math.round(v * 100) / 100;
  conferir('volume de ' + tipo, Math.abs(v - teorico) / teorico <= tolerancia,
    v.toFixed(1) + ' contra ' + teorico.toFixed(1));
  conferir('malha fechada de ' + tipo, CAD.manifold(m).fechada);
});

// 2. Exportação e gravação de cada formato, com validação por reabertura.
const d = doc();
const gerados = {};
['cad', 'dxf', 'stl', '3mf', 'step', 'ifc'].forEach((formato) => {
  const r = CAD.exportar(d, formato);
  conferir('exportar ' + formato, r.ok, r.erro);
  if (!r.ok) return;
  conferir('validação por reabertura de ' + formato, !!(r.validacao && r.validacao.ok));
  const alvo = path.join(destino, r.nome);
  if (r.dados) fs.writeFileSync(alvo, Buffer.from(r.dados));
  else fs.writeFileSync(alvo, r.texto, 'utf8');
  gerados[formato] = {
    nome: r.nome,
    bytes: fs.statSync(alvo).size,
    declarado: r.bytes,
    triangulos: r.triangulos || 0,
    avisos: (r.avisos || []).length,
    perdas: (r.perdas || []).length
  };
  conferir('bytes de ' + formato + ' batem com o arquivo', gerados[formato].bytes >= Math.round(r.bytes * 0.9));
});

const stlAscii = CAD.paraStlAscii(d);
fs.writeFileSync(path.join(destino, 'peca-teste-ascii.stl'), stlAscii.texto, 'utf8');
conferir('STL ASCII exportado', stlAscii.ok && stlAscii.texto.indexOf('facet normal') > 0);
const relidoAscii = CAD.lerStl(fs.readFileSync(path.join(destino, 'peca-teste-ascii.stl')));
conferir('STL ASCII relido', relidoAscii.ok && relidoAscii.triangulos.length > 0 && relidoAscii.manifold.fechada);

// 3. Formatos proprietários precisam ser recusados com motivo, não gerar arquivo vazio.
const recusados = {};
['dwg', 'rvt', 'rfa', 'fcstd', 'xyz'].forEach((f) => {
  const r = CAD.exportar(d, f);
  conferir('recusa de ' + f, !r.ok && typeof r.erro === 'string' && r.erro.length > 20);
  recusados[f] = r.ok ? 'ACEITOU' : r.erro.slice(0, 80);
});

// 4. Entrada malformada não pode derrubar nada.
const invalidos = [
  ['stl-vazio', () => CAD.lerStl(new Uint8Array(0))],
  ['stl-lixo', () => CAD.lerStl(new Uint8Array([1, 2, 3, 4, 5]))],
  ['dxf-vazio', () => CAD.lerDxf('')],
  ['dxf-lixo', () => CAD.lerDxf('isto nao e um dxf')],
  ['step-lixo', () => CAD.lerStep('qualquer coisa')],
  ['ifc-lixo', () => CAD.lerIfc('ISO-10303-21;\nDATA;\n#1=X;\nENDSEC;')]
];
invalidos.forEach(([nome, fn]) => {
  let r = null;
  try { r = fn(); } catch (e) { erros.push(nome + ' lançou exceção: ' + e.message); return; }
  conferir(nome + ' devolve erro claro', r && r.ok === false && typeof r.erro === 'string');
});

// 5. 3MF precisa ser lido de volta (o formato é ZIP+XML).
(async () => {
  const bytes = fs.readFileSync(path.join(destino, gerados['3mf'].nome));
  const lido = await CAD.ler3mf(bytes);
  conferir('3MF relido', lido.ok && lido.triangulos > 0, lido.erro);
  const det = await CAD.analisarFormato(bytes, 'x.3mf');
  conferir('detecção automática de 3MF', det.ok && det.formato === '3mf');
  const auto = await CAD.analisarFormato(fs.readFileSync(path.join(destino, gerados.stl.nome)), 'x.stl');
  conferir('detecção automática de STL binário', auto.ok && auto.formato === 'stl' && auto.binario === true);
  const autoDxf = await CAD.analisarFormato(fs.readFileSync(path.join(destino, gerados.dxf.nome), 'utf8'), 'x.dxf');
  conferir('detecção automática de DXF', autoDxf.ok && autoDxf.formato === 'dxf');
  const autoStep = await CAD.analisarFormato(fs.readFileSync(path.join(destino, gerados.step.nome), 'utf8'), 'x.step');
  conferir('detecção automática de STEP', autoStep.ok && autoStep.formato === 'step');
  const autoIfc = await CAD.analisarFormato(fs.readFileSync(path.join(destino, gerados.ifc.nome), 'utf8'), 'x.ifc');
  conferir('detecção automática de IFC', autoIfc.ok && autoIfc.formato === 'ifc');

  const saida = {
    ok: erros.length === 0,
    erros: erros,
    volumes: volumes,
    gerados: gerados,
    recusados: recusados,
    leitura: {
      '3mf': { triangulos: lido.triangulos || 0, vertices: lido.vertices || 0 },
      stl: { triangulos: (auto.triangulos || []).length },
      dxf: { camadas: autoDxf.camadas || [] },
      step: { entidades: autoStep.entidades || 0, quebradas: autoStep.referenciasQuebradas },
      ifc: { entidades: autoIfc.entidades || 0, elementos: (autoIfc.elementos || []).length }
    }
  };
  console.log(JSON.stringify(saida));
  process.exit(erros.length ? 1 : 0);
})();
