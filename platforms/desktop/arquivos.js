'use strict';
/* J.A.R.V.I.S. Nova — motor de arquivos do computador (Windows, Linux e macOS).
 *
 * Vive no processo principal do Electron, sem interface: recebe um caminho, devolve
 * dados. Nenhuma função aqui executa shell, abre aplicativo ou escreve fora da pasta
 * autorizada. O renderer nunca escolhe caminho livre — `resolver()` recusa o que sai
 * da pasta do usuário.
 *
 * O que é real e o que não é (importante para não mentir na interface):
 *  - formato identificado por ASSINATURA (bytes), não pela extensão; a extensão só
 *    desempata formatos de texto;
 *  - ZIP/Office/3MF/FCStd são lidos pela tabela central do ZIP (é o que permite dizer
 *    "DOCX com 12 parágrafos" em vez de "arquivo binário");
 *  - PDF: leio o cabeçalho e as páginas de verdade (`/Type /Page`), mas NÃO renderizo
 *    PDF — a interface avisa e oferece abrir no programa do sistema;
 *  - DWG, RVT, RFA e outros binários proprietários são recusados com explicação;
 *  - conversão só existe para os pares implementados (md→html, csv↔json, json→csv,
 *    txt→md, html→txt). O resto é recusado em vez de gerar arquivo quebrado.
 */

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const crypto = require('crypto');

const LIMITE_TEXTO = 2 * 1024 * 1024;      // leitura de texto
const LIMITE_BINARIO = 32 * 1024 * 1024;    // leitura de binário (imagem, zip, cad)
const LIMITE_PREVIA = 120 * 1024;           // pedaço de texto devolvido à interface

const TEXTO_EXT = new Set([
  'txt', 'md', 'markdown', 'log', 'csv', 'tsv', 'json', 'jsonl', 'xml', 'svg', 'yaml', 'yml',
  'ini', 'cfg', 'conf', 'env', 'properties', 'gitignore', 'toml', 'sql', 'tex',
  'js', 'mjs', 'cjs', 'ts', 'tsx', 'jsx', 'html', 'htm', 'css', 'scss', 'less',
  'py', 'java', 'kt', 'kts', 'c', 'h', 'cpp', 'hpp', 'cs', 'go', 'rs', 'rb', 'php', 'swift',
  'sh', 'bat', 'ps1', 'gradle', 'sln', 'csproj', 'vcxproj', 'pro', 'diff', 'patch'
]);

function extensao(nome) {
  const m = String(nome || '').toLowerCase().match(/\.([a-z0-9]+)$/);
  return m ? m[1] : '';
}

function dentro(base, alvo) {
  const rel = path.relative(base, alvo);
  return rel === '' || (!rel.startsWith('..') && !path.isAbsolute(rel));
}

/* Impressão digital do conteúdo: é o que permite dizer "isto é o mesmo arquivo
 * que você abriu" em vez de confiar só no caminho. SHA-256 não é criptografia de
 * segurança aqui, é comparação de bytes. */
function hashBuf(buf) {
  return crypto.createHash('sha256').update(buf).digest('hex');
}

/* Nome de temporário único por operação: dois salvamentos simultâneos do mesmo
 * arquivo (ou duas janelas do app) não podem escrever no mesmo .tmp. */
let seqTmp = 0;
function nomeTemporario(alvo) {
  seqTmp += 1;
  return alvo + '.tmp-' + process.pid + '-' + Date.now().toString(36) + '-' + seqTmp + '-' + crypto.randomBytes(4).toString('hex');
}

/* CRC-32 da norma do ZIP (polinômio 0xEDB88320), em tabela preguiçosa. */
let tabelaCrc = null;
function crc32(buf) {
  if (!tabelaCrc) {
    tabelaCrc = new Int32Array(256);
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
      tabelaCrc[n] = c;
    }
  }
  let crc = -1;
  for (let i = 0; i < buf.length; i++) crc = (crc >>> 8) ^ tabelaCrc[(crc ^ buf[i]) & 0xFF];
  return (crc ^ -1) >>> 0;
}

/* ZIP sem compressão (método "store"): existe para empacotar arquivos que o próprio
 * app gerou. Não é compactador — o nome diz ZIP, o conteúdo é legível, e o teste
 * confere com o zipfile do Python, não com este mesmo código. */
function zipStore(entradas) {
  const locais = [];
  const centrais = [];
  let deslocamento = 0;
  for (const e of entradas) {
    const nome = Buffer.from(String(e.nome), 'utf8');
    const dados = Buffer.isBuffer(e.dados) ? e.dados : Buffer.from(String(e.dados == null ? '' : e.dados), 'utf8');
    const crc = crc32(dados);
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4);       // versão necessária
    local.writeUInt16LE(0x0800, 6);   // nomes em UTF-8
    local.writeUInt16LE(0, 8);        // store
    local.writeUInt16LE(0, 10);
    local.writeUInt16LE(0, 12);
    local.writeUInt32LE(crc, 14);
    local.writeUInt32LE(dados.length, 18);
    local.writeUInt32LE(dados.length, 22);
    local.writeUInt16LE(nome.length, 26);
    local.writeUInt16LE(0, 28);
    locais.push(local, nome, dados);
    const central = Buffer.alloc(46);
    central.writeUInt32LE(0x02014b50, 0);
    central.writeUInt16LE(20, 4);
    central.writeUInt16LE(20, 6);
    central.writeUInt16LE(0x0800, 8);
    central.writeUInt16LE(0, 10);
    central.writeUInt16LE(0, 12);
    central.writeUInt16LE(0, 14);
    central.writeUInt32LE(crc, 16);
    central.writeUInt32LE(dados.length, 20);
    central.writeUInt32LE(dados.length, 24);
    central.writeUInt16LE(nome.length, 28);
    central.writeUInt16LE(0, 30);
    central.writeUInt16LE(0, 32);
    central.writeUInt16LE(0, 34);
    central.writeUInt16LE(0, 36);
    central.writeUInt32LE(0, 38);
    central.writeUInt32LE(deslocamento, 42);
    centrais.push(central, nome);
    deslocamento += 30 + nome.length + dados.length;
  }
  const diretorio = Buffer.concat(centrais);
  const fim = Buffer.alloc(22);
  fim.writeUInt32LE(0x06054b50, 0);
  fim.writeUInt16LE(entradas.length, 8);
  fim.writeUInt16LE(entradas.length, 10);
  fim.writeUInt32LE(diretorio.length, 12);
  fim.writeUInt32LE(deslocamento, 16);
  return Buffer.concat([Buffer.concat(locais), diretorio, fim]);
}

/* ------------------------------- ZIP interno ------------------------------- */
function eocd(buf) {
  const inicio = Math.max(0, buf.length - 66000);
  for (let i = buf.length - 22; i >= inicio; i--) {
    if (buf.readUInt32LE(i) === 0x06054b50) {
      return { total: buf.readUInt16LE(i + 10), offset: buf.readUInt32LE(i + 16) };
    }
  }
  return null;
}

function entradasZip(buf) {
  const fim = eocd(buf);
  if (!fim) return [];
  const lista = [];
  let p = fim.offset;
  for (let n = 0; n < fim.total && p + 46 <= buf.length; n++) {
    if (buf.readUInt32LE(p) !== 0x02014b50) break;
    const metodo = buf.readUInt16LE(p + 10);
    const comprimido = buf.readUInt32LE(p + 20);
    const tamanho = buf.readUInt32LE(p + 24);
    const nomeLen = buf.readUInt16LE(p + 28);
    const extraLen = buf.readUInt16LE(p + 30);
    const comLen = buf.readUInt16LE(p + 32);
    const local = buf.readUInt32LE(p + 42);
    const nome = buf.toString('utf8', p + 46, p + 46 + nomeLen);
    lista.push({ nome, metodo, comprimido, tamanho, local });
    p += 46 + nomeLen + extraLen + comLen;
    if (lista.length > 4000) break;
  }
  return lista;
}

function conteudoZip(buf, entrada) {
  if (!entrada) return null;
  const nomeLen = buf.readUInt16LE(entrada.local + 26);
  const extraLen = buf.readUInt16LE(entrada.local + 28);
  const inicio = entrada.local + 30 + nomeLen + extraLen;
  const dados = buf.subarray(inicio, inicio + entrada.comprimido);
  if (entrada.metodo === 0) return dados;
  if (entrada.metodo === 8) {
    try { return zlib.inflateRawSync(dados); } catch (_) { return null; }
  }
  return null;
}

function xmlTexto(buf) {
  if (!buf) return '';
  return buf.toString('utf8')
    .replace(/<w:p\b[^>]*>/g, '\n')
    .replace(/<a:p\b[^>]*>/g, '\n')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"').replace(/&apos;/g, "'").replace(/&amp;/g, '&')
    .replace(/[ \t\u00a0]+/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

/* ------------------------------- Detecção -------------------------------- */
function detectar(buf, nome) {
  const ext = extensao(nome);
  const cabeca = buf && buf.length ? buf.subarray(0, 4096).toString('utf8') : '';
  if (!buf || !buf.length) return { formato: 'vazio', tipo: 'desconhecido', descricao: 'arquivo vazio' };

  if (buf.length > 3 && buf[0] === 0x50 && buf[1] === 0x4b && (buf[2] === 3 || buf[2] === 5)) {
    const entradas = entradasZip(buf);
    const nomes = entradas.map((e) => e.nome.toLowerCase());
    if (nomes.some((n) => n.endsWith('3d/3dmodel.model'))) return { formato: '3mf', tipo: 'cad', descricao: '3MF (modelo de impressão 3D)' };
    if (nomes.some((n) => n.endsWith('word/document.xml'))) return { formato: 'docx', tipo: 'documento', descricao: 'DOCX (Word)' };
    if (nomes.some((n) => n.endsWith('xl/workbook.xml'))) return { formato: 'xlsx', tipo: 'planilha', descricao: 'XLSX (Excel)' };
    if (nomes.some((n) => n.endsWith('ppt/presentation.xml'))) return { formato: 'pptx', tipo: 'apresentacao', descricao: 'PPTX (PowerPoint)' };
    if (nomes.some((n) => n.endsWith('document.xml')) && nomes.some((n) => n.endsWith('guidocument.xml'))) return { formato: 'fcstd', tipo: 'cad', descricao: 'FCStd (FreeCAD)' };
    if (nomes.some((n) => n.endsWith('content.xml'))) return { formato: 'odf', tipo: 'documento', descricao: 'OpenDocument' };
    if (nomes.some((n) => n.endsWith('manifest.json')) && nomes.length <= 2 && !ext) return { formato: 'zip', tipo: 'arquivo', descricao: 'ZIP' };
    return { formato: 'zip', tipo: 'arquivo', descricao: 'ZIP com ' + entradas.length + ' entrada(s)' };
  }
  if (cabeca.startsWith('%PDF-')) return { formato: 'pdf', tipo: 'documento', descricao: 'PDF ' + cabeca.slice(5, 8) };
  if (buf.length > 8 && buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47) return { formato: 'png', tipo: 'imagem', descricao: 'PNG' };
  if (buf[0] === 0xff && buf[1] === 0xd8) return { formato: 'jpg', tipo: 'imagem', descricao: 'JPEG' };
  if (cabeca.startsWith('GIF8')) return { formato: 'gif', tipo: 'imagem', descricao: 'GIF' };
  if (cabeca.startsWith('RIFF') && cabeca.slice(8, 12) === 'WEBP') return { formato: 'webp', tipo: 'imagem', descricao: 'WebP' };
  if (cabeca.startsWith('BM')) return { formato: 'bmp', tipo: 'imagem', descricao: 'BMP' };
  if (cabeca.startsWith('AC10')) return { formato: 'dwg', tipo: 'cad', descricao: 'DWG (Autodesk)' };
  if (buf[0] === 0xd0 && buf[1] === 0xcf) return { formato: 'ole', tipo: 'binario', descricao: 'documento composto OLE (RVT/RFA/DOC/XLS antigo)' };
  if (/^ISO-10303-21/.test(cabeca)) {
    if (/FILE_SCHEMA\s*\(\s*\(\s*'IFC/i.test(cabeca)) return { formato: 'ifc', tipo: 'cad', descricao: 'IFC (BIM)' };
    return { formato: 'step', tipo: 'cad', descricao: 'STEP (ISO 10303)' };
  }
  if (/\bSECTION\b/.test(cabeca) && /\bENTITIES\b|\bHEADER\b/.test(buf.toString('utf8'))) {
    if (/AutoCAD Binary DXF/i.test(cabeca)) return { formato: 'dxf-bin', tipo: 'cad', descricao: 'DXF binário' };
    return { formato: 'dxf', tipo: 'cad', descricao: 'DXF (ASCII)' };
  }
  if (buf.length >= 84) {
    const n = buf.readUInt32LE(80);
    if (n > 0 && buf.length === 84 + n * 50) return { formato: 'stl', tipo: 'cad', descricao: 'STL binário' };
  }
  if (/^\s*solid\b/i.test(cabeca) && /facet\s+normal/i.test(buf.toString('utf8', 0, Math.min(buf.length, 8192)))) {
    return { formato: 'stl', tipo: 'cad', descricao: 'STL ASCII' };
  }
  const texto = cabeca.replace(/^\uFEFF/, '').trimStart();
  if (/^[{[]/.test(texto)) {
    try {
      const json = JSON.parse(buf.toString('utf8'));
      if (json && typeof json === 'object' && /cad/i.test(String(json.formato || '')) && Array.isArray(json.objetos)) {
        // Formato próprio (JSON documentado em cad.js). NÃO é o .cad proprietário do
        // CADe SIMU: chamar de CadSimu aqui só confundia o usuário.
        return { formato: 'cad', tipo: 'cad', descricao: 'CAD do J.A.R.V.I.S. v' + (json.versao || '?') + ' (JSON próprio, não é o .cad do CADe SIMU)' };
      }
      return { formato: 'json', tipo: 'dados', descricao: 'JSON' };
    } catch (_) {
      return { formato: TEXTO_EXT.has(ext) ? ext : 'json', tipo: 'dados', descricao: 'JSON inválido' };
    }
  }
  if (/^<\?xml|^<svg|^<!doctype html|^<html/i.test(texto)) {
    if (/^<svg/i.test(texto)) return { formato: 'svg', tipo: 'imagem', descricao: 'SVG' };
    return { formato: /^<\?xml/i.test(texto) ? 'xml' : 'html', tipo: 'texto', descricao: /html/i.test(texto.slice(0, 200)) ? 'HTML' : 'XML' };
  }
  if (TEXTO_EXT.has(ext)) {
    const tipo = ['csv', 'tsv'].includes(ext) ? 'planilha' : ['json', 'jsonl', 'yaml', 'yml', 'ini', 'cfg', 'toml'].includes(ext) ? 'dados' : 'texto';
    return { formato: ext, tipo, descricao: ext.toUpperCase() };
  }
  // Sem assinatura reconhecida: só trato como texto se for decodificável e sem bytes de controle.
  const amostra = buf.subarray(0, 4096);
  let controle = 0;
  for (const b of amostra) if (b < 9 || (b > 13 && b < 32)) controle++;
  if (controle / Math.max(1, amostra.length) < 0.02) return { formato: ext || 'txt', tipo: 'texto', descricao: 'texto sem extensão conhecida' };
  return { formato: ext || 'binario', tipo: 'binario', descricao: 'binário não reconhecido' };
}

/* ------------------------------- Leitura --------------------------------- */
function tabelaCsv(texto, limite) {
  const linhas = [];
  const sep = texto.split('\n')[0].includes(';') && !texto.split('\n')[0].includes(',') ? ';' : ',';
  let campo = '';
  let linha = [];
  let dentro = false;
  for (let i = 0; i < texto.length; i++) {
    const c = texto[i];
    if (c === '"') {
      if (dentro && texto[i + 1] === '"') { campo += '"'; i++; }
      else dentro = !dentro;
    } else if (c === sep && !dentro) { linha.push(campo); campo = ''; }
    else if ((c === '\n' || c === '\r') && !dentro) {
      if (c === '\r' && texto[i + 1] === '\n') i++;
      linha.push(campo); campo = '';
      if (linha.length > 1 || linha[0] !== '') linhas.push(linha);
      linha = [];
      if (linhas.length >= limite) break;
    } else campo += c;
  }
  if (campo || linha.length) { linha.push(campo); linhas.push(linha); }
  const largura = linhas.reduce((m, l) => Math.max(m, l.length), 0);
  return { separador: sep, linhas: linhas.map((l) => l.slice(0, 40)), colunas: largura };
}

function paginasPdf(buf) {
  const t = buf.toString('latin1');
  const paginas = (t.match(/\/Type\s*\/Page[^s]/g) || []).length;
  const contagemDeclarada = /\/Count\s+(\d+)/.exec(t);
  const titulo = /\/Title\s*\(([^)]{0,120})\)/.exec(t);
  return {
    paginas,
    paginasDeclaradas: contagemDeclarada ? Number(contagemDeclarada[1]) : null,
    titulo: titulo ? titulo[1] : ''
  };
}

function lerPlanilhaXlsx(buf, entradas) {
  const compartilhadas = entradas.find((e) => e.nome.toLowerCase().endsWith('xl/sharedstrings.xml'));
  const strings = [];
  if (compartilhadas) {
    const xml = xmlTexto(conteudoZip(buf, compartilhadas));
    strings.push(...xml.split('\n').map((s) => s.trim()).filter(Boolean));
  }
  const planilhas = entradas.filter((e) => /^xl\/worksheets\/sheet\d+\.xml$/i.test(e.nome));
  const resumo = planilhas.map((p) => {
    const xml = (conteudoZip(buf, p) || Buffer.from('')).toString('utf8');
    const celulas = (xml.match(/<c\b[^>]*>/g) || []).length;
    return { nome: p.nome.split('/').pop(), celulas };
  });
  const livro = entradas.find((e) => e.nome.toLowerCase() === 'xl/workbook.xml');
  const nomes = livro ? ((conteudoZip(buf, livro) || Buffer.from('')).toString('utf8').match(/<sheet\b[^>]*name="([^"]+)"/g) || [])
    .map((s) => (/name="([^"]+)"/.exec(s) || [])[1]) : [];
  return { planilhas: resumo, nomes: nomes.filter(Boolean), strings: strings.length };
}

function fábrica({ raiz }) {
  if (!raiz) throw new Error('motor de arquivos precisa de uma raiz');

  function resolver(p) {
    const bruto = String(p == null ? '~' : p).trim() || '~';
    if (bruto === '~') return raiz;
    // O "~" pode vir seguido de barra normal ou invertida: no Windows relativo()
    // devolve "~" + barra invertida e a interface manda esse mesmo texto de volta.
    // Antes, "~" + barra invertida não era expandido: virava uma pasta literal "~"
    // e a organização não movia nada. Caminho absoluto continua absoluto (e é
    // recusado por dentro()), para não abrir brecha na checagem de segurança.
    let alvo;
    if (/^~(?=$|[\\/])/.test(bruto)) {
      const partes = bruto.slice(1).split(/[\\/]+/).filter(Boolean);
      alvo = partes.length ? path.resolve(raiz, partes.join(path.sep)) : raiz;
    } else {
      alvo = path.resolve(raiz, bruto);
    }
    if (!dentro(raiz, alvo)) throw new Error('Caminho fora da pasta do usuário.');
    return alvo;
  }

  function relativo(alvo) {
    const rel = path.relative(raiz, alvo);
    if (rel === '') return '~';
    // O separador vem do próprio Node (barra invertida no Windows, barra no Unix):
    // assim o caminho mostrado na interface é o que o usuário digita de verdade.
    return '~' + path.sep + rel.split(path.sep).join(path.sep);
  }

  function listar(caminho) {
    const alvo = resolver(caminho);
    const st = fs.statSync(alvo);
    if (!st.isDirectory()) throw new Error('Isso não é uma pasta.');
    const itens = fs.readdirSync(alvo, { withFileTypes: true })
      .filter((d) => !d.name.startsWith('.'))
      .map((d) => {
        const completo = path.join(alvo, d.name);
        let info = { nome: d.name, caminho: completo, pasta: d.isDirectory(), bytes: 0, modificado: 0, formato: '', tipo: d.isDirectory() ? 'pasta' : 'arquivo', descricao: d.isDirectory() ? 'pasta' : '' };
        try {
          const s = fs.statSync(completo);
          info.bytes = s.size;
          info.modificado = s.mtimeMs;
          if (!d.isDirectory()) {
            const fd = fs.openSync(completo, 'r');
            const cab = Buffer.alloc(Math.min(4096, s.size));
            if (cab.length) fs.readSync(fd, cab, 0, cab.length, 0);
            fs.closeSync(fd);
            const det = detectar(cab, d.name);
            info.formato = det.formato;
            info.tipo = det.tipo;
            info.descricao = det.descricao;
          }
        } catch (_) { /* item ilegível aparece com tamanho zero */ }
        return info;
      })
      .sort((a, b) => (b.pasta - a.pasta) || a.nome.localeCompare(b.nome))
      .slice(0, 500);
    return { caminho: alvo, relativo: relativo(alvo), pai: alvo === raiz ? '' : relativo(path.dirname(alvo)), itens };
  }

  function ler(caminho) {
    const alvo = resolver(caminho);
    const st = fs.statSync(alvo);
    if (st.isDirectory()) throw new Error('Isso é uma pasta: abra para ver o conteúdo.');
    if (st.size > LIMITE_BINARIO) throw new Error('Arquivo acima do limite de 32 MB para prévia neste painel.');
    const buf = fs.readFileSync(alvo);
    const det = detectar(buf, alvo);
    const base = { caminho: alvo, relativo: relativo(alvo), nome: path.basename(alvo), bytes: buf.length, modificado: st.mtimeMs, mtimeMs: st.mtimeMs, hash: hashBuf(buf), formato: det.formato, tipo: det.tipo, descricao: det.descricao };
    const limite = Math.max(1, LIMITE_PREVIA);

    if (det.tipo === 'imagem' && ['png', 'jpg', 'gif', 'webp', 'bmp'].includes(det.formato)) {
      const mime = { png: 'image/png', jpg: 'image/jpeg', gif: 'image/gif', webp: 'image/webp', bmp: 'image/bmp' }[det.formato];
      const medidas = det.formato === 'png' && buf.length > 24
        ? { largura: buf.readUInt32BE(16), altura: buf.readUInt32BE(20) } : null;
      return { ...base, imagem: 'data:' + mime + ';base64,' + buf.toString('base64'), medidas,
        resumo: det.descricao + (medidas ? ', ' + medidas.largura + '×' + medidas.altura + ' px' : '') + ', ' + Math.round(buf.length / 1024) + ' kB.' };
    }
    if (det.formato === 'svg') {
      const texto = buf.toString('utf8');
      const vb = /viewBox="([^"]+)"/.exec(texto);
      return { ...base, imagem: 'data:image/svg+xml;base64,' + buf.toString('base64'),
        resumo: 'SVG vetorial' + (vb ? ' (viewBox ' + vb[1] + ')' : '') + ', ' + texto.split('\n').length + ' linha(s).' };
    }
    if (det.formato === 'pdf') {
      const info = paginasPdf(buf);
      return { ...base, meta: info, binario: true,
        resumo: 'PDF ' + buf.toString('latin1', 5, 8) + ' com ' + (info.paginas || info.paginasDeclaradas || 0) + ' página(s)' +
          (info.titulo ? ', título "' + info.titulo + '"' : '') + '. A prévia de páginas não é renderizada aqui — use "Abrir no sistema".' };
    }
    if (det.formato === 'docx') {
      const entradas = entradasZip(buf);
      const doc = entradas.find((e) => e.nome.toLowerCase() === 'word/document.xml');
      const texto = xmlTexto(conteudoZip(buf, doc));
      return { ...base, texto: texto.slice(0, limite), editavel: false,
        resumo: 'DOCX com ' + (texto ? texto.split('\n').filter(Boolean).length + ' parágrafo(s) de texto' : 'documento sem texto legível') + '. Extraio o texto para leitura e resumo; a edição do .docx não é feita aqui.' };
    }
    if (det.formato === 'xlsx') {
      const info = lerPlanilhaXlsx(buf, entradasZip(buf));
      return { ...base, meta: info, editavel: false,
        resumo: 'XLSX com ' + (info.planilhas.length || 0) + ' planilha(s)' + (info.nomes.length ? ' (' + info.nomes.slice(0, 6).join(', ') + ')' : '') + ', ' + info.strings + ' texto(s) compartilhado(s). Leitura apenas.' };
    }
    if (det.formato === 'pptx') {
      const entradas = entradasZip(buf);
      const slides = entradas.filter((e) => /^ppt\/slides\/slide\d+\.xml$/i.test(e.nome));
      return { ...base, meta: { slides: slides.length }, editavel: false, resumo: 'PPTX com ' + slides.length + ' slide(s). Leitura apenas.' };
    }
    if (det.formato === 'fcstd') {
      const entradas = entradasZip(buf);
      return { ...base, meta: { entradas: entradas.length }, editavel: false,
        resumo: 'Documento do FreeCAD (' + entradas.length + ' partes). A árvore paramétrica exige o FreeCAD: não abro nem edito aqui.' };
    }
    if (det.formato === 'zip' || det.formato === 'odf') {
      const entradas = entradasZip(buf);
      const total = entradas.reduce((s, e) => s + e.tamanho, 0);
      return { ...base, meta: { entradas: entradas.slice(0, 200).map((e) => ({ nome: e.nome, bytes: e.tamanho })) },
        resumo: 'ZIP com ' + entradas.length + ' entrada(s), ' + Math.round(total / 1024) + ' kB descomprimidos.' };
    }
    if (det.tipo === 'cad') {
      return { ...base, binario: true, editavel: false,
        resumo: 'Arquivo CAD (' + det.descricao + '): use a aba CAD para identificar, visualizar, criar versão ou exportar.' };
    }
    if (det.tipo === 'binario') {
      return { ...base, binario: true, resumo: det.descricao + '. Não é texto: não exibo nem edito conteúdo binário.' };
    }

    const texto = buf.toString('utf8').replace(/^\uFEFF/, '');
    if (det.formato === 'csv' || det.formato === 'tsv') {
      const t = tabelaCsv(texto, 60);
      return { ...base, texto: texto.slice(0, limite), tabela: t, editavel: true,
        resumo: 'Tabela com ' + t.colunas + ' coluna(s), separador "' + t.separador + '", ' + texto.split('\n').length + ' linha(s).' };
    }
    if (det.formato === 'json' || det.formato === 'jsonl') {
      let info = 'JSON inválido: não consigo interpretar o conteúdo.';
      try {
        const dados = JSON.parse(texto);
        const chaves = Array.isArray(dados) ? ['[array de ' + dados.length + ']'] : Object.keys(dados).slice(0, 20);
        info = (Array.isArray(dados) ? 'Lista com ' + dados.length + ' item(ns)' : 'Objeto com ' + Object.keys(dados).length + ' chave(s)') + ': ' + chaves.join(', ') + '.';
      } catch (e) { info = 'JSON inválido: ' + String(e.message).slice(0, 120); }
      return { ...base, texto: texto.slice(0, limite), editavel: true, resumo: info };
    }
    return { ...base, texto: texto.slice(0, limite), editavel: det.tipo === 'texto' || det.tipo === 'dados',
      truncado: texto.length > limite,
      resumo: det.descricao + ', ' + texto.split('\n').length + ' linha(s)' + (texto.length > limite ? ' — prévia limitada a 120 kB' : '') + '.' };
  }

  /* Gravação segura: temporário único → fsync → renomeio atômico → releitura e
   * comparação de SHA-256. Se qualquer etapa falhar, o original (ou a cópia .bak) é
   * restaurado e a função lança erro: nunca devolve "salvo" sem conferir o disco. */
  function gravarBinario({ caminho, dados, backup = true, hashEsperado = '', forcar = false }) {
    const alvo = resolver(caminho);
    if (fs.existsSync(alvo) && fs.statSync(alvo).isDirectory()) throw new Error('O caminho é uma pasta.');
    const buf = Buffer.isBuffer(dados) ? dados : Buffer.from(String(dados == null ? '' : dados), 'utf8');
    if (buf.length > 8 * 1024 * 1024) throw new Error('Conteúdo acima de 8 MB: não salvo pelo painel.');
    const existia = fs.existsSync(alvo);
    let copia = '';
    if (existia) {
      const atual = fs.readFileSync(alvo);
      const hashAtual = hashBuf(atual);
      if (hashEsperado && hashAtual !== hashEsperado && !forcar) {
        throw new Error('O arquivo mudou desde que foi aberto (outra janela ou outro programa). Nada foi gravado; reabra e refaça a edição, ou confirme a substituição.');
      }
      if (!backup && !forcar) throw new Error('Substituir ' + relativo(alvo) + ' sem cópia de segurança exige confirmação explícita.');
    }
    fs.mkdirSync(path.dirname(alvo), { recursive: true });
    if (existia && backup) {
      copia = alvo + '.bak-' + new Date().toISOString().replace(/[:.]/g, '-');
      fs.copyFileSync(alvo, copia);
      if (fs.statSync(copia).size !== fs.statSync(alvo).size) throw new Error('A cópia de segurança saiu incompleta; nada foi gravado.');
    }
    const tmp = nomeTemporario(alvo);
    try {
      const fd = fs.openSync(tmp, 'w');
      try {
        fs.writeFileSync(fd, buf);
        fs.fsyncSync(fd);
      } finally { fs.closeSync(fd); }
      fs.renameSync(tmp, alvo);
    } catch (e) {
      try { fs.unlinkSync(tmp); } catch (_) { /* temporário já não existe */ }
      throw e;
    }
    const conferido = fs.readFileSync(alvo);
    const hash = hashBuf(conferido);
    if (conferido.length !== buf.length || hash !== hashBuf(buf)) {
      if (copia) { try { fs.copyFileSync(copia, alvo); } catch (_) { /* backup também falhou: erro abaixo */ } }
      throw new Error('A conferência depois da gravação falhou' + (copia ? '; o arquivo anterior foi restaurado de ' + relativo(copia) : '') + '. O conteúdo em disco não confere.');
    }
    return { caminho: alvo, relativo: relativo(alvo), bytes: buf.length, hash, mtimeMs: fs.statSync(alvo).mtimeMs, backup: copia ? relativo(copia) : '' };
  }

  function salvar({ caminho, texto, backup = true, hashEsperado = '', forcar = false }) {
    return gravarBinario({ caminho, dados: Buffer.from(String(texto == null ? '' : texto), 'utf8'), backup, hashEsperado, forcar });
  }

  /** ZIP de verdade (método store), com CRC conferido por quem abrir. */
  function compactar({ destino, arquivos }) {
    const lista = Array.isArray(arquivos) ? arquivos : [];
    if (!lista.length) throw new Error('Informe pelo menos um arquivo para compactar.');
    if (lista.length > 200) throw new Error('Compacto no máximo 200 arquivos por vez.');
    const entradas = [];
    let total = 0;
    const usados = new Set();
    for (const item of lista) {
      const origem = resolver(item && item.caminho ? item.caminho : item);
      const st = fs.statSync(origem);
      if (!st.isFile()) throw new Error('Só compacto arquivos: ' + relativo(origem) + ' é pasta.');
      if (st.size > LIMITE_BINARIO) throw new Error('Arquivo acima de 32 MB não entra no ZIP: ' + relativo(origem));
      let nome = String((item && item.nome) || path.basename(origem)).replace(/[\\/]+/g, '-');
      if (usados.has(nome)) nome = path.basename(origem, path.extname(origem)) + '-' + entradas.length + path.extname(origem);
      usados.add(nome);
      const dados = fs.readFileSync(origem);
      total += dados.length;
      if (total > 64 * 1024 * 1024) throw new Error('O ZIP passaria de 64 MB descompactados; reduza a seleção.');
      entradas.push({ nome, dados });
    }
    const buf = zipStore(entradas);
    const nomeZip = String(destino || 'arquivos.zip');
    const rel = /^~(?=$|[\\/])/.test(nomeZip) ? nomeZip : '~/' + nomeZip.replace(/^[\\/]+/, '');
    const alvo = resolver(/\.zip$/i.test(rel) ? rel : rel + '.zip');
    if (fs.existsSync(alvo)) throw new Error('Já existe ' + relativo(alvo) + '; escolha outro nome.');
    const salvo = gravarBinario({ caminho: relativo(alvo), dados: buf, backup: false });
    return { ...salvo, formato: 'zip', entradas: entradas.length, descompactado: total, resumo: 'ZIP com ' + entradas.length + ' arquivo(s), ' + Math.round(buf.length / 1024) + ' kB.' };
  }

  /** Auditoria de integridade: estrutura do formato, não só existência. */
  function verificar(caminho) {
    const alvo = resolver(caminho);
    const st = fs.statSync(alvo);
    if (!st.isFile()) throw new Error('Isso não é um arquivo.');
    if (st.size > LIMITE_BINARIO) throw new Error('Arquivo acima de 32 MB não é verificado aqui.');
    const buf = fs.readFileSync(alvo);
    const det = detectar(buf, alvo);
    const problemas = [];
    let detalhe = '';
    if (['zip', 'docx', 'xlsx', 'pptx', 'odf', '3mf', 'fcstd'].includes(det.formato)) {
      const fim = eocd(buf);
      if (!fim) problemas.push('sem diretório central: o ZIP/Office está truncado ou corrompido');
      else {
        const entradas = entradasZip(buf);
        if (!entradas.length) problemas.push('ZIP sem entradas legíveis');
        let quebradas = 0;
        for (const e of entradas) {
          if (buf.readUInt32LE(e.local) !== 0x04034b50) { quebradas++; continue; }
          if (e.metodo === 8 && conteudoZip(buf, e) === null) quebradas++;
        }
        if (quebradas) problemas.push(quebradas + ' entrada(s) com dados corrompidos');
        detalhe = entradas.length + ' entrada(s) no índice, ' + Math.round(fim.offset / 1024) + ' kB de diretório central';
      }
    } else if (det.formato === 'json' || det.formato === 'jsonl' || (det.formato === 'cad')) {
      try { JSON.parse(buf.toString('utf8')); } catch (e) { problemas.push('JSON inválido: ' + String(e.message).slice(0, 120)); }
    } else if (det.formato === 'pdf') {
      const texto = buf.toString('latin1');
      if (!/%%EOF\s*$/.test(texto)) problemas.push('sem marcador %%EOF: o PDF pode estar truncado');
      if (!/\/Type\s*\/Page/.test(texto)) problemas.push('nenhuma página encontrada');
    } else if (det.formato === 'csv' || det.formato === 'tsv') {
      const t = tabelaCsv(buf.toString('utf8'), 5);
      if (!t.linhas.length) problemas.push('tabela vazia');
    } else if (det.formato === 'stl') {
      if (buf.length >= 84) {
        const n = buf.readUInt32LE(80);
        if (n > 0 && buf.length !== 84 + n * 50) problemas.push('STL binário declara ' + n + ' triângulo(s) mas o tamanho não bate');
      }
    } else if (['png', 'jpg', 'gif', 'webp', 'bmp'].includes(det.formato)) {
      if (buf.length < 32) problemas.push('imagem menor que o cabeçalho mínimo');
    } else if (det.tipo === 'binario') {
      problemas.push('binário sem estrutura reconhecida: não há como validar o conteúdo aqui');
    }
    if (det.tipo === 'texto') {
      const texto = buf.toString('utf8');
      const ruins = (texto.match(/\uFFFD/g) || []).length;
      if (ruins > Math.max(4, texto.length * 0.01)) problemas.push('texto com ' + ruins + ' caractere(s) inválido(s): provável codificação não UTF-8');
    }
    return {
      caminho: alvo, relativo: relativo(alvo), nome: path.basename(alvo), formato: det.formato, descricao: det.descricao,
      bytes: buf.length, hash: hashBuf(buf), mtimeMs: st.mtimeMs, problemas, ok: problemas.length === 0,
      detalhe, resumo: problemas.length ? problemas.length + ' problema(s): ' + problemas.join('; ') : 'Estrutura de ' + det.formato.toUpperCase() + ' conferida, sem problema encontrado.'
    };
  }

  /** Remove temporários abandonados (de queda ou interrupção) sem tocar em .bak. */
  function limparTemporarios(pasta, horas) {
    const base = resolver(pasta || '~');
    if (!fs.statSync(base).isDirectory()) throw new Error('Isso não é uma pasta.');
    const idade = Math.max(0, Number(horas) || 24) * 3600 * 1000;
    const agora = Date.now();
    let removidos = 0;
    const nomes = [];
    for (const item of fs.readdirSync(base, { withFileTypes: true })) {
      if (!item.isFile() || !/\.tmp-\d+-/.test(item.name)) continue;
      const completo = path.join(base, item.name);
      try {
        if (agora - fs.statSync(completo).mtimeMs < idade) continue;
        fs.unlinkSync(completo);
        removidos++;
        nomes.push(item.name);
      } catch (_) { /* arquivo em uso ou sem permissão: fica para a próxima */ }
    }
    return { pasta: relativo(base), removidos, nomes: nomes.slice(0, 50) };
  }

  function comparar(a, b) {
    const pa = resolver(a);
    const pb = resolver(b);
    for (const p of [pa, pb]) {
      const st = fs.statSync(p);
      if (!st.isFile()) throw new Error('Comparo arquivos, não pastas: ' + relativo(p));
      if (st.size > LIMITE_TEXTO) throw new Error('Comparação de texto até 2 MB: ' + relativo(p) + ' tem ' + Math.round(st.size / 1024) + ' kB.');
      const cab = Buffer.alloc(Math.min(4096, st.size));
      const fd = fs.openSync(p, 'r');
      try { if (cab.length) fs.readSync(fd, cab, 0, cab.length, 0); } finally { fs.closeSync(fd); }
      const det = detectar(cab, p);
      if (det.tipo === 'binario' || (det.tipo === 'imagem' && det.formato !== 'svg') || det.tipo === 'cad' || det.tipo === 'apresentacao') {
        throw new Error('Não comparo ' + det.descricao + ' linha a linha: sem texto, a diferença seria inventada. Use "Abrir no sistema".');
      }
    }
    const la = fs.readFileSync(pa, 'utf8').replace(/\r\n/g, '\n').split('\n');
    const lb = fs.readFileSync(pb, 'utf8').replace(/\r\n/g, '\n').split('\n');
    let ini = 0;
    while (ini < la.length && ini < lb.length && la[ini] === lb[ini]) ini++;
    let fimA = la.length - 1, fimB = lb.length - 1;
    while (fimA >= ini && fimB >= ini && la[fimA] === lb[fimB]) { fimA--; fimB--; }
    const removidas = la.slice(ini, fimA + 1);
    const adicionadas = lb.slice(ini, fimB + 1);
    const blocos = [];
    for (let i = 0; i < removidas.length; i++) blocos.push({ tipo: 'removida', linha: ini + i + 1, texto: removidas[i].slice(0, 300) });
    for (let i = 0; i < adicionadas.length; i++) blocos.push({ tipo: 'adicionada', linha: ini + i + 1, texto: adicionadas[i].slice(0, 300) });
    return {
      a: relativo(pa), b: relativo(pb), iguais: !removidas.length && !adicionadas.length,
      linhasA: la.length, linhasB: lb.length, removidas: removidas.length, adicionadas: adicionadas.length,
      inicioComum: ini, blocos: blocos.slice(0, 400),
      resumo: (!removidas.length && !adicionadas.length)
        ? 'Os dois arquivos são idênticos.'
        : 'Diferença a partir da linha ' + (ini + 1) + ': ' + removidas.length + ' linha(s) só em ' + path.basename(pa) + ' e ' + adicionadas.length + ' só em ' + path.basename(pb) + '.'
    };
  }

  function pesquisar(termo, pasta, opcoes) {
    const o = opcoes || {};
    const busca = String(termo || '').trim();
    if (busca.length < 2) throw new Error('A busca precisa de pelo menos 2 caracteres.');
    const limite = Math.max(1, Math.min(200, Number(o.limite) || 60));
    const raizBusca = resolver(pasta || '~');
    const achados = [];
    const fila = [{ dir: raizBusca, nivel: 0 }];
    let varridos = 0;
    while (fila.length && achados.length < limite && varridos < 4000) {
      const atual = fila.shift();
      let itens = [];
      try { itens = fs.readdirSync(atual.dir, { withFileTypes: true }); } catch (_) { continue; }
      for (const item of itens) {
        if (item.name.startsWith('.') || item.name === 'node_modules') continue;
        const completo = path.join(atual.dir, item.name);
        if (item.isDirectory()) {
          if (atual.nivel < (Number(o.profundidade) || 4)) fila.push({ dir: completo, nivel: atual.nivel + 1 });
          continue;
        }
        varridos++;
        let st;
        try { st = fs.statSync(completo); } catch (_) { continue; }
        if (st.size > LIMITE_TEXTO) continue;
        let texto;
        try { texto = fs.readFileSync(completo, 'utf8'); } catch (_) { continue; }
        if (texto.includes('\u0000')) continue;
        const linhas = texto.split('\n');
        for (let i = 0; i < linhas.length; i++) {
          if (linhas[i].toLowerCase().includes(busca.toLowerCase())) {
            achados.push({ caminho: relativo(completo), linha: i + 1, trecho: linhas[i].trim().slice(0, 200), formato: extensao(completo) });
            if (achados.length >= limite) break;
          }
        }
        if (achados.length >= limite) break;
      }
    }
    return { termo: busca, pasta: relativo(raizBusca), varridos, achados, resumo: achados.length + ' ocorrência(s) em ' + varridos + ' arquivo(s) lido(s).' };
  }

  function converter({ caminho, alvo, sobrescrever = false }) {
    const origem = ler(caminho);
    const destinoFormato = String(alvo || '').toLowerCase().replace(/^\./, '');
    if (!origem.texto && !origem.tabela) throw new Error('Só converto arquivos de texto/tabela; este tipo não tem conversão confiável aqui.');
    const texto = origem.texto || '';
    let saida = '';
    let nome = path.basename(origem.caminho).replace(/\.[^.]+$/, '');
    const pares = origem.formato + '→' + destinoFormato;
    if (pares === 'csv→json') {
      const t = origem.tabela || tabelaCsv(texto, 5000);
      const cab = t.linhas[0] || [];
      const corpo = t.linhas.slice(1).map((l) => {
        const obj = {};
        cab.forEach((c, i) => { obj[c || 'coluna' + (i + 1)] = l[i] == null ? '' : l[i]; });
        return obj;
      });
      saida = JSON.stringify(corpo, null, 2) + '\n';
    } else if (pares === 'json→csv') {
      let dados;
      try { dados = JSON.parse(texto); } catch (e) { throw new Error('JSON inválido: ' + e.message); }
      const linhas = Array.isArray(dados) ? dados : [dados];
      if (!linhas.length || typeof linhas[0] !== 'object') throw new Error('Só converto JSON de objetos ou lista de objetos.');
      const chaves = [...new Set(linhas.flatMap((l) => Object.keys(l || {})))].slice(0, 60);
      const esc = (v) => {
        const s = v == null ? '' : typeof v === 'object' ? JSON.stringify(v) : String(v);
        return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
      };
      saida = [chaves.join(','), ...linhas.map((l) => chaves.map((k) => esc(l[k])).join(','))].join('\n') + '\n';
    } else if (pares === 'md→html') {
      saida = mdParaHtml(texto, nome);
    } else if (pares === 'html→txt' || pares === 'xml→txt') {
      saida = xmlTexto(Buffer.from(texto)) + '\n';
    } else if (/^txt→md$/.test(pares) || /→md$/.test(pares) && origem.tipo === 'texto') {
      saida = '# ' + nome + '\n\n' + texto;
    } else {
      throw new Error('Conversão ' + origem.formato + ' → ' + destinoFormato + ' não implementada. Disponíveis: csv→json, json→csv, md→html, html→txt, txt→md.');
    }
    const ext = destinoFormato === 'txt' ? 'txt' : destinoFormato;
    const destino = resolver(path.join(path.dirname(origem.caminho), nome + '.' + ext));
    if (!sobrescrever && fs.existsSync(destino) && destino !== origem.caminho) {
      throw new Error('Já existe ' + relativo(destino) + '. Confirme a substituição para continuar.');
    }
    const salvo = salvar({ caminho: destino, texto: saida, backup: true });
    return { ...salvo, de: origem.formato, para: destinoFormato, perdas: destinoFormato === 'html' || destinoFormato === 'txt' ? ['formatação do documento original não é reconstruída'] : [] };
  }

  function mdParaHtml(md, titulo) {
    const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    const linhas = String(md).split('\n');
    const out = [];
    let lista = false;
    for (const linha of linhas) {
      const item = /^\s*[-*]\s+(.*)$/.exec(linha);
      const tit = /^(#{1,6})\s+(.*)$/.exec(linha);
      if (item) { if (!lista) { out.push('<ul>'); lista = true; } out.push('<li>' + inline(esc(item[1])) + '</li>'); continue; }
      if (lista) { out.push('</ul>'); lista = false; }
      if (tit) { out.push('<h' + tit[1].length + '>' + inline(esc(tit[2])) + '</h' + tit[1].length + '>'); continue; }
      if (!linha.trim()) { out.push(''); continue; }
      out.push('<p>' + inline(esc(linha)) + '</p>');
    }
    if (lista) out.push('</ul>');
    return '<!doctype html>\n<html lang="pt-BR"><head><meta charset="utf-8"><title>' + esc(titulo) +
      '</title><style>body{font:16px/1.6 system-ui,sans-serif;max-width:46rem;margin:2rem auto;padding:0 1rem;color:#111}code{background:#f4f4f5;padding:.1em .35em;border-radius:4px}</style></head><body>\n' +
      out.join('\n') + '\n</body></html>\n';
    function inline(s) {
      return s.replace(/`([^`]+)`/g, '<code>$1</code>')
        .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
        .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
    }
  }

  const PASTAS_PADRAO = {
    imagens: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'svg'],
    documentos: ['pdf', 'docx', 'odt', 'rtf', 'txt', 'md'],
    planilhas: ['xlsx', 'ods', 'csv', 'tsv'],
    cad: ['cad', 'dxf', 'dwg', 'stl', '3mf', 'step', 'stp', 'ifc', 'fcstd', 'obj'],
    codigo: ['js', 'ts', 'py', 'java', 'kt', 'c', 'cpp', 'cs', 'go', 'rs', 'html', 'css', 'json', 'xml', 'yml', 'yaml'],
    compactados: ['zip', '7z', 'rar', 'gz', 'tar'],
    audio: ['mp3', 'wav', 'ogg', 'flac', 'm4a'],
    video: ['mp4', 'mkv', 'avi', 'mov', 'webm']
  };

  /** Plano de organização: nunca move nada aqui; devolve o que FARIA. */
  function organizar({ pasta, regras, aplicar = false }) {
    const base = resolver(pasta || '~/Jarvis');
    if (!fs.existsSync(base) || !fs.statSync(base).isDirectory()) throw new Error('Pasta inexistente: ' + relativo(base));
    const mapa = regras && typeof regras === 'object' ? regras : PASTAS_PADRAO;
    const itens = fs.readdirSync(base, { withFileTypes: true }).filter((d) => d.isFile() && !d.name.startsWith('.'));
    const plano = [];
    for (const item of itens) {
      const ext = extensao(item.name);
      const destino = Object.keys(mapa).find((k) => Array.isArray(mapa[k]) && mapa[k].includes(ext));
      if (!destino) { plano.push({ arquivo: item.name, de: relativo(base), para: '', acao: 'manter' }); continue; }
      plano.push({ arquivo: item.name, de: relativo(path.join(base, item.name)), para: relativo(path.join(base, destino, item.name)), acao: 'mover', pasta: destino });
    }
    const mover = plano.filter((p) => p.acao === 'mover');
    const aviso = {
      plano, mover: mover.length, manter: plano.length - mover.length, aplicado: false,
      resumo: mover.length ? mover.length + ' arquivo(s) seriam movidos para subpastas por tipo; ' + (plano.length - mover.length) + ' ficariam onde estão.' : 'Nada a organizar: nenhum arquivo com tipo reconhecido.'
    };
    if (!aplicar) return aviso;
    if (!mover.length) return { ...aviso, aplicado: true };
    let feitos = 0;
    const erros = [];
    for (const p of mover) {
      const origem = resolver(p.de);
      const destino = resolver(p.para);
      try {
        fs.mkdirSync(path.dirname(destino), { recursive: true });
        if (fs.existsSync(destino)) { erros.push(p.arquivo + ': já existe no destino'); continue; }
        fs.renameSync(origem, destino);
        feitos++;
      } catch (e) { erros.push(p.arquivo + ': ' + e.message); }
    }
    return { ...aviso, aplicado: true, movidos: feitos, erros, resumo: feitos + ' arquivo(s) movidos' + (erros.length ? '; ' + erros.length + ' falha(s)' : '') + '.' };
  }

  function mover({ de, para }) {
    const origem = resolver(de);
    const destino = resolver(para);
    if (!fs.existsSync(origem)) throw new Error('Origem não existe: ' + relativo(origem));
    if (fs.existsSync(destino)) throw new Error('O destino já existe; nada foi sobrescrito.');
    fs.mkdirSync(path.dirname(destino), { recursive: true });
    fs.renameSync(origem, destino);
    return { de: relativo(origem), para: relativo(destino) };
  }

  function criarPasta({ pasta, nome }) {
    const base = resolver(pasta || '~');
    const limpo = String(nome || '').replace(/[\\/:*?"<>|\u0000-\u001f]/g, '-').replace(/^\.+/, '').trim();
    if (!limpo) throw new Error('Informe o nome da pasta.');
    const alvo = path.join(base, limpo.slice(0, 80));
    if (fs.existsSync(alvo)) throw new Error('Já existe ' + relativo(alvo) + '.');
    fs.mkdirSync(alvo);
    return { caminho: relativo(alvo) };
  }

  function apagar(caminho, lixeira) {
    const alvo = resolver(caminho);
    if (alvo === raiz) throw new Error('Não apago a pasta do usuário.');
    if (typeof lixeira === 'function') lixeira(alvo);
    else throw new Error('Exclusão exige a lixeira do sistema; operação cancelada.');
    return { caminho: relativo(alvo) };
  }

  return { raiz, resolver, relativo, listar, ler, salvar, salvarBinario: gravarBinario, gravarBinario, comparar, pesquisar, converter, compactar, verificar, limparTemporarios, organizar, mover, criarPasta, apagar, detectar, PASTAS_PADRAO };
}

module.exports = { criarArquivos: fábrica, criar: fábrica, detectar, entradasZip, xmlTexto, tabelaCsv, zipStore, crc32, organizarPadrao: {
  imagens: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'svg'],
  documentos: ['pdf', 'docx', 'odt', 'rtf', 'txt', 'md'],
  planilhas: ['xlsx', 'ods', 'csv', 'tsv'],
  cad: ['cad', 'dxf', 'dwg', 'stl', '3mf', 'step', 'stp', 'ifc', 'fcstd', 'obj'],
  codigo: ['js', 'ts', 'py', 'java', 'kt', 'c', 'cpp', 'cs', 'go', 'rs', 'html', 'css', 'json', 'xml', 'yml', 'yaml'],
  compactados: ['zip', '7z', 'rar', 'gz', 'tar'],
  audio: ['mp3', 'wav', 'ogg', 'flac', 'm4a'],
  video: ['mp4', 'mkv', 'avi', 'mov', 'webm']
} };
