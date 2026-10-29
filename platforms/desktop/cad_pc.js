'use strict';
/* J.A.R.V.I.S. Nova — CAD do computador.
 *
 * Esta camada NÃO reimplementa geometria: usa o mesmo `cad.js` do núcleo (o arquivo que
 * roda no Android), então um `.cad` criado aqui abre lá e vice-versa. O que é exclusivo
 * do desktop:
 *   - identificar o formato real pelo conteúdo (assinatura), não pela extensão;
 *   - extrair geometria para o visualizador (DXF em linhas e STL/3MF/`.cad` em malha);
 *   - gravar em disco com versão nova, validação por reabertura e nunca sobrescrever
 *     o original sem pedir;
 *   - exportar para os formatos que existem de verdade, devolvendo as perdas.
 *
 * Limites declarados de propósito:
 *   - DWG, RVT, RFA e FCStd não são lidos (binários proprietários / árvore paramétrica);
 *     a função `identificar` diz isso em vez de fingir suporte;
 *   - STEP e IFC são lidos como texto estruturado (contagem de entidades), não como
 *     geometria sólida: converter STEP→malha exigiria kernel B-rep, que não existe aqui;
 *   - PDF não é CAD e não entra aqui.
 */

const fs = require('fs');
const path = require('path');
const CAD = require('../../cad.js');
const ARQ = require('./arquivos.js');

const LIMITE_ARQUIVO = 64 * 1024 * 1024;
const LIMITE_TRIANGULOS = 200000;

function escapar(s) { return String(s == null ? '' : s).replace(/[^A-Za-z0-9._-]+/g, '-').replace(/^-+/, '') || 'modelo'; }

/** Pares código/valor do DXF, na ordem do arquivo. */
function paresDxf(texto) {
  const linhas = String(texto).replace(/\r\n?/g, '\n').split('\n');
  const pares = [];
  for (let i = 0; i + 1 < linhas.length; i += 2) {
    const codigo = parseInt(String(linhas[i]).trim(), 10);
    if (!Number.isFinite(codigo)) { i -= 1; continue; }
    pares.push([codigo, linhas[i + 1]]);
  }
  return pares;
}

/** Geometria 2D/3D do DXF: segmentos por camada. Não é o desenho renderizado por
 *  software CAD (sem hachuras, blocos nem cotas), mas é o que está de fato no arquivo. */
function geometriaDxf(texto) {
  const pares = paresDxf(texto);
  const segmentos = [];
  const camadas = {};
  const tipos = {};
  let atual = '';
  let camada = '0';
  let pontos = [];
  let mapa = {};
  let fechada = false;
  let raioCirculo = NaN;
  const min = [Infinity, Infinity], max = [-Infinity, -Infinity];

  function guardarSegmento(x1, y1, x2, y2) {
    if (![x1, y1, x2, y2].every(Number.isFinite)) return;
    segmentos.push({ x1: x1, y1: y1, x2: x2, y2: y2, camada: camada });
    atualizarCaixa(x1, y1);
    atualizarCaixa(x2, y2);
  }
  function atualizarCaixa(x, y) {
    if (!Number.isFinite(x) || !Number.isFinite(y)) return;
    if (x < min[0]) min[0] = x; if (x > max[0]) max[0] = x;
    if (y < min[1]) min[1] = y; if (y > max[1]) max[1] = y;
  }
  function fecharPoligono(lista) {
    for (let i = 0; i + 1 < lista.length; i++) guardarSegmento(lista[i][0], lista[i][1], lista[i + 1][0], lista[i + 1][1]);
    if (fechada && lista.length > 2) guardarSegmento(lista[lista.length - 1][0], lista[lista.length - 1][1], lista[0][0], lista[0][1]);
  }
  function concluir() {
    if (!atual) return;
    tipos[atual] = (tipos[atual] || 0) + 1;
    if (!pontos.length) {
      pontos = Object.keys(mapa).map(Number).sort(function (a, b) { return a - b; })
        .map(function (k) { return mapa[k]; })
        .filter(function (p) { return Number.isFinite(p[0]) && Number.isFinite(p[1]); });
    }
    if (atual === 'LINE' && pontos.length >= 2) {
      guardarSegmento(pontos[0][0], pontos[0][1], pontos[1][0], pontos[1][1]);
    } else if (atual === 'LWPOLYLINE' || atual === 'POLYLINE') {
      fecharPoligono(pontos);
    } else if (atual === '3DFACE' && pontos.length >= 3) {
      guardarSegmento(pontos[0][0], pontos[0][1], pontos[1][0], pontos[1][1]);
      guardarSegmento(pontos[1][0], pontos[1][1], pontos[2][0], pontos[2][1]);
      guardarSegmento(pontos[2][0], pontos[2][1], pontos[0][0], pontos[0][1]);
      if (pontos[3]) {
        guardarSegmento(pontos[3][0], pontos[3][1], pontos[0][0], pontos[0][1]);
        guardarSegmento(pontos[2][0], pontos[2][1], pontos[3][0], pontos[3][1]);
      }
    } else if (atual === 'CIRCLE' && pontos.length && Number.isFinite(raioCirculo) && raioCirculo > 0) {
      const cx = pontos[0][0], cy = pontos[0][1];
      let px = cx + raioCirculo, py = cy;
      for (let i = 1; i <= 48; i++) {
        const a = (i / 48) * Math.PI * 2;
        const x = cx + raioCirculo * Math.cos(a), y = cy + raioCirculo * Math.sin(a);
        guardarSegmento(px, py, x, y);
        px = x; py = y;
      }
    }
    atual = ''; pontos = []; mapa = {}; fechada = false; raioCirculo = NaN;
  }

  for (const par of pares) {
    const codigo = par[0];
    const valor = String(par[1]).trim();
    if (codigo === 0) {
      // VERTEX pertence à POLYLINE corrente; SEQEND só fecha a sequência.
      if (valor === 'VERTEX' || valor === 'SEQEND') continue;
      concluir();
      atual = valor;
      camada = '0';
      continue;
    }
    if (!atual) continue;
    if (codigo === 8) { camada = valor || '0'; camadas[camada] = (camadas[camada] || 0) + 1; continue; }
    if (codigo === 70 && (atual === 'POLYLINE' || atual === 'LWPOLYLINE')) { fechada = (Number(valor) & 1) === 1; continue; }
    if (codigo === 40 && atual === 'CIRCLE') { raioCirculo = Number(valor); continue; }
    if (atual === 'LWPOLYLINE' || atual === 'POLYLINE') {
      if (codigo === 10) { pontos.push([Number(valor), NaN]); continue; }
      if (codigo === 20 && pontos.length) { pontos[pontos.length - 1][1] = Number(valor); continue; }
      continue;
    }
    // Demais entidades: 10..13 são os X dos cantos, 20..23 os Y correspondentes.
    if (codigo >= 10 && codigo <= 13) {
      const k = codigo - 10;
      if (!mapa[k]) mapa[k] = [NaN, NaN];
      mapa[k][0] = Number(valor);
      continue;
    }
    if (codigo >= 20 && codigo <= 23) {
      const k = codigo - 20;
      if (!mapa[k]) mapa[k] = [NaN, NaN];
      mapa[k][1] = Number(valor);
      continue;
    }
  }
  concluir();

  const bbox = Number.isFinite(min[0])
    ? { min: [min[0], min[1], 0], max: [max[0], max[1], 0], tamanho: [max[0] - min[0], max[1] - min[1], 0] }
    : { min: [0, 0], max: [0, 0], tamanho: [0, 0, 0] };
  return {
    ok: segmentos.length > 0,
    tipo: '2d',
    segmentos: segmentos.slice(0, 60000),
    camadas: Object.keys(camadas),
    tipos: tipos,
    bbox: bbox,
    aviso: segmentos.length ? '' : 'O DXF não tem LINE/LWPOLYLINE/POLYLINE/CIRCLE/3DFACE legíveis para desenhar.'
  };
}

function malhaParaVisual(m) {
  const tris = m.triangulos.slice(0, LIMITE_TRIANGULOS);
  const usados = new Set();
  tris.forEach((t) => { usados.add(t[0]); usados.add(t[1]); usados.add(t[2]); });
  return {
    tipo: '3d',
    vertices: Array.from(m.vertices),
    triangulos: tris,
    totalTriangulos: m.triangulos.length,
    truncada: m.triangulos.length > tris.length,
    bbox: CAD.caixaMalha(m)
  };
}

function fábricaCad({ raiz }) {
  if (!raiz) throw new Error('CAD do desktop precisa de uma raiz');

  function resolver(p) {
    const bruto = String(p == null ? '' : p).trim();
    // "~/x" e "~" são atalhos da pasta do usuário, iguais aos do resto do app.
    const alvo = bruto === '~' ? raiz : bruto.startsWith('~') ? path.join(raiz, bruto.slice(1)) : path.resolve(bruto);
    const rel = path.relative(raiz, alvo);
    if (rel.startsWith('..') || path.isAbsolute(rel)) throw new Error('Caminho fora da pasta do usuário.');
    return alvo;
  }

  function bytesDe(caminho) {
    const st = fs.statSync(caminho);
    if (st.size > LIMITE_ARQUIVO) throw new Error('Arquivo CAD acima de 64 MB: não abro no visualizador.');
    return fs.readFileSync(caminho);
  }

  function identificar(caminho) {
    const alvo = resolver(caminho);
    const buf = bytesDe(alvo);
    const det = ARQ.detectar(buf, alvo);
    const nome = path.basename(alvo);
    const mapa = {
      cad: { aberto: true, visualiza: true, cria: true, edita: true, exporta: true, obs: 'formato nativo do aplicativo; edição paramétrica por objeto' },
      dxf: { aberto: true, visualiza: true, cria: true, edita: false, exporta: true, obs: 'desenho em linhas e faces; edição estrutural exige software CAD' },
      stl: { aberto: true, visualiza: true, cria: true, edita: false, exporta: true, obs: 'malha para impressão 3D; sem unidades no arquivo' },
      '3mf': { aberto: true, visualiza: true, cria: true, edita: false, exporta: true, obs: 'modelo de impressão 3D em ZIP+XML' },
      step: { aberto: true, visualiza: false, cria: true, edita: false, exporta: true, obs: 'leio as entidades do arquivo; STEP→malha exigiria kernel B-rep' },
      ifc: { aberto: true, visualiza: false, cria: true, edita: false, exporta: true, obs: 'leio o esquema e os elementos; geometria BIM completa não é reconstruída' },
      dwg: { aberto: false, visualiza: false, cria: false, edita: false, exporta: false, obs: 'DWG é binário proprietário (ODA/RealDWG): abra no software de origem ou peça um DXF' },
      fcstd: { aberto: false, visualiza: false, cria: false, edita: false, exporta: false, obs: 'FCStd guarda a árvore do FreeCAD; abra no FreeCAD' },
      ole: { aberto: false, visualiza: false, cria: false, edita: false, exporta: false, obs: 'Documento composto OLE (RVT/RFA/DOC antigo): sem leitor livre' },
      'dxf-bin': { aberto: false, visualiza: false, cria: false, edita: false, exporta: false, obs: 'DXF binário: peça a versão ASCII' }
    };
    const info = mapa[det.formato] || { aberto: false, visualiza: false, cria: false, edita: false, exporta: false, obs: 'não é um formato CAD reconhecido' };
    return { caminho: alvo, nome, formato: det.formato, descricao: det.descricao, bytes: buf.length, ...info };
  }

  function abrir(caminho) {
    const alvo = resolver(caminho);
    const info = identificar(alvo);
    if (!info.aberto) return { ok: false, ...info, erro: info.descricao + ' não é legível aqui: ' + info.obs + '.' };
    const buf = fs.readFileSync(alvo);
    const texto = ['dxf', 'step', 'ifc', 'cad'].includes(info.formato) ? buf.toString('utf8') : '';
    let geo = null;
    let resumo = '';
    let propriedades = {};
    if (info.formato === 'dxf') {
      geo = geometriaDxf(texto);
      resumo = 'DXF com ' + geo.segmentos.length + ' segmento(s) em ' + geo.camadas.length + ' camada(s); extensão ' +
        geo.bbox.tamanho[0].toFixed(1) + ' × ' + geo.bbox.tamanho[1].toFixed(1) + '.';
      propriedades = { entidades: geo.tipos, camadas: geo.camadas };
      if (!geo.ok) return { ok: false, ...info, erro: geo.aviso };
    } else if (info.formato === 'stl') {
      const r = CAD.lerStl(buf);
      if (!r.ok) return { ok: false, ...info, erro: r.erro };
      geo = malhaParaVisual({ vertices: r.vertices, triangulos: r.triangulos });
      resumo = r.resumo;
      propriedades = { volume: r.volume, area: r.area, fechada: r.manifold.fechada, arestasAbertas: r.manifold.arestasAbertas };
    } else if (info.formato === '3mf') {
      return { ok: false, ...info, erro: '3MF exige leitura assíncrona da malha; use a aba CAD ▸ Exportar a partir de um .cad.' };
    } else if (info.formato === 'cad') {
      const r = CAD.analisar(texto);
      if (!r.ok) return { ok: false, ...info, erro: r.erro };
      const m = CAD.malha(r.doc);
      geo = malhaParaVisual(m);
      resumo = r.resumo;
      propriedades = { objetos: r.doc.objetos.length, unidades: r.doc.unidades, contagem: r.contagem, objetosDetalhe: r.doc.objetos.slice(0, 200) };
    } else if (info.formato === 'step') {
      const r = CAD.lerStep(texto);
      if (!r.ok) return { ok: false, ...info, erro: r.erro };
      resumo = r.resumo;
      propriedades = { entidades: r.entidades, tipos: r.tipos, referenciasQuebradas: r.referenciasQuebradas };
    } else if (info.formato === 'ifc') {
      const r = CAD.lerIfc(texto);
      if (!r.ok) return { ok: false, ...info, erro: r.erro };
      resumo = r.resumo;
      propriedades = { esquema: r.esquema, entidades: r.entidades, elementos: r.elementos };
    }
    return {
      ok: true, ...info, resumo, geometria: geo, propriedades,
      limitacoes: info.visualiza ? [] : [info.obs]
    };
  }

  function nomeLivre(pasta, base, ext) {
    let nome = escapar(base) + ext;
    let n = 2;
    while (fs.existsSync(path.join(pasta, nome))) {
      nome = escapar(base) + '-v' + n + ext;
      n++;
      if (n > 999) throw new Error('Não consegui achar um nome livre para o arquivo.');
    }
    return path.join(pasta, nome);
  }

  function criar({ nome, objetos, unidades, pasta }) {
    const base = resolver(pasta || path.join(raiz, 'Jarvis'));
    fs.mkdirSync(base, { recursive: true });
    const doc = CAD.criar({ nome: nome || 'modelo', objetos: objetos || undefined, unidades: unidades || 'mm' });
    const texto = CAD.serializar(doc);
    const conf = CAD.parse(texto);
    if (!conf.ok) throw new Error('O modelo gerado não passou na validação: ' + conf.erro);
    const alvo = nomeLivre(base, nome || doc.nome, '.cad');
    fs.writeFileSync(alvo, texto, 'utf8');
    const reaberto = CAD.analisar(fs.readFileSync(alvo, 'utf8'));
    if (!reaberto.ok) throw new Error('Gravei o arquivo mas ele não reabriu: ' + reaberto.erro);
    return {
      arquivo: alvo, nome: path.basename(alvo), bytes: Buffer.byteLength(texto, 'utf8'),
      objetos: doc.objetos.length, unidades: doc.unidades, resumo: reaberto.resumo,
      validacao: 'reaberto e analisado após a gravação'
    };
  }

  function modificar({ caminho, edicoes, nomeVersao }) {
    const alvo = resolver(caminho);
    if (!/\.cad$/i.test(alvo)) throw new Error('Só modifico .cad do aplicativo; para STL/DXF use exportar e edite no software de origem.');
    const original = fs.readFileSync(alvo, 'utf8');
    const r = CAD.parse(original);
    if (!r.ok) throw new Error('O .cad original não abre: ' + r.erro);
    const doc = r.doc;
    const lista = Array.isArray(edicoes) ? edicoes : [];
    if (!lista.length) throw new Error('Nenhuma edição informada.');
    const aplicadas = [];
    for (const e of lista) {
      const i = Number(e.indice);
      if (!Number.isInteger(i) || i < 0 || i >= doc.objetos.length) throw new Error('Objeto ' + (e.indice + 1) + ' não existe no arquivo.');
      const obj = doc.objetos[i];
      if (e.posicao) {
        if (!Array.isArray(e.posicao) || e.posicao.length !== 3 || !e.posicao.every((v) => Number.isFinite(Number(v)))) {
          throw new Error('Posição precisa de 3 números.');
        }
        obj.posicao = e.posicao.map(Number);
      }
      if (e.dimensoes) {
        if (!Array.isArray(e.dimensoes) || !e.dimensoes.every((v) => Number(v) > 0)) throw new Error('Dimensões precisam ser maiores que zero.');
        obj.dimensoes = e.dimensoes.map(Number);
      }
      if (e.raio != null) { if (!(Number(e.raio) > 0)) throw new Error('Raio precisa ser maior que zero.'); obj.raio = Number(e.raio); }
      if (e.altura != null) { if (!(Number(e.altura) > 0)) throw new Error('Altura precisa ser maior que zero.'); obj.altura = Number(e.altura); }
      if (e.nome) obj.nome = String(e.nome).slice(0, 60);
      aplicadas.push(i);
    }
    const texto = CAD.serializar(doc);
    const conf = CAD.parse(texto);
    if (!conf.ok) throw new Error('A edição deixaria o arquivo inválido (' + conf.erro + '); o original não foi tocado.');
    const pasta = path.dirname(alvo);
    const base = path.basename(alvo, '.cad');
    const destino = nomeLivre(pasta, nomeVersao || base, '.cad');
    fs.writeFileSync(destino, texto, 'utf8');
    const reaberto = CAD.analisar(fs.readFileSync(destino, 'utf8'));
    if (!reaberto.ok) throw new Error('A nova versão não reabriu: ' + reaberto.erro + '. O original continua intacto.');
    return {
      arquivo: destino, nome: path.basename(destino), original: path.basename(alvo),
      objetosEditados: aplicadas, resumo: reaberto.resumo, validacao: 'nova versão reaberta; original não foi alterado'
    };
  }

  function exportar({ caminho, formato, ascii }) {
    const alvo = resolver(caminho);
    if (!/\.cad$/i.test(alvo)) throw new Error('A exportação parte de um .cad do aplicativo; para converter STL/DXF→outro formato, reimporte no software de origem.');
    const r = CAD.analisar(fs.readFileSync(alvo, 'utf8'));
    if (!r.ok) throw new Error('O .cad não abre: ' + r.erro);
    const ext = String(formato || '').toLowerCase().replace(/^\./, '');
    const res = CAD.exportar(r.doc, ext, { ascii: !!ascii });
    if (!res.ok) throw new Error(res.erro);
    const pasta = path.dirname(alvo);
    const base = path.basename(alvo, '.cad');
    const destino = nomeLivre(pasta, base, '.' + (res.nome ? res.nome.split('.').pop() : ext));
    if (res.dados) fs.writeFileSync(destino, Buffer.from(res.dados));
    else fs.writeFileSync(destino, res.texto, 'utf8');
    return {
      arquivo: destino, nome: path.basename(destino), formato: ext, bytes: fs.statSync(destino).size,
      perdas: res.perdas || [], avisos: res.avisos || [], validacao: res.validacao,
      resumo: 'Exportado para ' + ext.toUpperCase() + ' (' + Math.round(fs.statSync(destino).size / 1024) + ' kB)' +
        (res.perdas && res.perdas.length ? '; perdas: ' + res.perdas.join(' ') : '')
    };
  }

  function formatos() {
    return CAD.FORMATOS.map((f) => ({
      ...f,
      desktop: {
        cad: 'abre, visualiza, cria, edita e exporta',
        dxf: 'abre e visualiza (linhas/camadas), cria e exporta',
        stl: 'abre e visualiza a malha, cria e exporta',
        '3mf': 'gera e exporta; visualização pelo .cad de origem',
        step: 'gera e lê entidades; sem visualização de sólido',
        ifc: 'gera e lê entidades/estrutura; sem visualização BIM',
        dwg: 'identifica pelo cabeçalho AC10xx e recusa explicando o motivo',
        rvt: 'identifica como OLE e recusa',
        rfa: 'identifica como OLE e recusa',
        fcstd: 'identifica pelo ZIP e recusa (precisa do FreeCAD)'
      }[f.id] || 'não suportado'
    }));
  }

  return { raiz, resolver, identificar, abrir, criar, modificar, exportar, formatos };
}

module.exports = { criarCad: fábricaCad, criar: fábricaCad, geometriaDxf, paresDxf };
